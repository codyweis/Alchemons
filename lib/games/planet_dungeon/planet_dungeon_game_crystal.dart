// lib/games/planet_dungeon/planet_dungeon_game_crystal.dart
//
// VITREA — THE PRISM LABYRINTH. Crystal's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart` (the treatment every planet after the Air
// pilot gets). The layout, the chamber roster and the pure sliding rules live
// in planet_dungeon_layout_crystal.dart; this file is the engine.
//
// World rule: *the keep rearranges — and it takes you with it.* See the layout
// file's header for the full statement of the lattice/chamber split, the
// parity hazard, the ledger distinctions and the vault trick.
//
//  • Entry — the keep's south face is one unbroken sheet of glass. LIGHTNING
//    cracks it and the threshold shows (docs §5.5, the eased entry reveal).
//  • Star 0 (Prism) — THE ROSE. The west lamp is kindled by the planet's own
//    braid **Crystal+Spirit→Light** (§6.10) and its beam crosses the middle
//    ROW, west to east, bending as it goes. Only five of the eight chambers
//    are cut on both the west and east faces, so which three stand in that row
//    is the whole question — and exactly one set of three bends the light to
//    the hue the east rose was cut for. Bends ADD, so order is unobservable:
//    a deliberate order-independence that keeps this out of Air's ordering
//    seat and Fire's sequence seat. UNGATED — this is the star §4 guarantees
//    to any trio of Crystal/Lightning/Spirit.
//  • Star 1 (Throne) — THE THREE THRONES. The Shard Hearth must stand in the
//    heart cell with its shard struck warm, and all three shard thrones must
//    stand on faces of it that are OPEN at the same moment. The heart is the
//    only cell with four neighbours; three served at once is the tightest
//    thing this keep can be asked for, and it demands the hearth in the middle
//    row — which Star 0 forbids. You cannot hold both. You do not have to.
//    The hearth's shard is the planet's Lightning+HORN gate (§4).
//  • Star 2 (Prismalith) — MYS11. §7: the guardian fights WITH the planet's
//    rule. The choir floor is the keep in miniature, nine plates and one gap;
//    the mystic's root only shows over the gap, so the lull opens when the gap
//    stands beneath it — and every strike beat the floor shunts itself out
//    from under it AND the keep upstairs shunts with it.
//  • Vault — THE WAITING FACET, drawn in from its berth when the hollow comes
//    to rest in the mouth cell (see `_tryBerthChain`).
//  • Lost Maxim — KNOW THYSELF: THE BLACK CELL, WEDGED. Ride the Black Cell
//    into the one corner where both its doorways meet the frame — the jam
//    the keep's whole valve exists to rescue you from — and its glass shows
//    nothing but the three of you. The smallest body finds the flaw, Lightning
//    runs it three times, and Crystal reads the three shapes. The anneal is
//    the way back out, as it always was.
//
// PARITY, NOT STRANDING (the design's one real danger — see the layout
// header and test/planet_dungeon_crystal_keep_test.dart). Because every slide
// is reversible this planet cannot strand you the way Ice, Mud and Dust can,
// and it needs no conservation ledger. Its danger is arithmetic: half of the
// 3×3 grid's 362,880 arrangements are unreachable from any given start, so
// every arrangement the stars, the vault and the exit require is PROVED
// reachable by exhaustive BFS over the real state graph — with the player's
// own position and the facet-gated walking included, because an arrangement
// nobody can be standing in the right place to finish is no better than an
// unreachable one.
//
// THE ANNEAL is the one valve, and it is here for a narrow, MEASURED reason:
// 7,404 of the 1,592,585 reachable states are jams — a body on glass that
// faces nothing, with the hollow out of reach. A Crystal hand on any tuning
// boss rings the keep back to its opening arrangement AND puts the ringer out
// on the oriel; carrying them with their own chamber instead would set them
// back down in the same trap forever, which is what the search caught. A
// do-over, never a shortcut.

part of 'planet_dungeon_game.dart';

/// Vitrea's lost maxim discovery id (the screen pays 20 gold on first find).
const String kCrystalKnowThyselfEgg = kCrystalKnowThyselfEggId;

// ── Device-tunable knobs ───────────────────────────────────
// Crystal has never been on a device; every number the feel depends on is
// named here so a tuning pass is edit-one-block.

/// How close a creature must stand to a shove-plate, a tuning boss, the berth
/// chain, the hearth shard, the lamp, the glass face or the font to work it.
const double _kKeepReach = 64.0;

/// Seconds the shear runs when a chamber goes over. Short: the slide must read
/// as a hard translation of architecture, never as a fade or a tide (§5.5's
/// visual grammar rule — nothing here may look like Water's regating).
const double _kKeepShearSeconds = 0.34;

/// One shard is rung loose out of the frame every this-many shunts. The
/// keep's consequence layer (§7: core + consequence + success). It is NOT a
/// budget — nothing runs out, and a run can shunt forever; thrashing simply
/// draws company.
const int _kShuntsPerShard = 3;

/// How many shards a ring looses.
const int _kShardsPerRing = 1;

/// Everything one Vitrea run tracks. ONE field on the engine (the Lava/Poison/
/// Mud pattern): the pure keep rules plus the handful of live/visual timers
/// the rules themselves have no business knowing about.
class PrismLabyrinth {
  /// The keep, and everything the player has done to it.
  final PrismKeepField field = PrismKeepField();

  double clock = 0;

  /// The slide animation: seconds left, and which way the chamber came from.
  double shear = 0;
  Offset shearFrom = Offset.zero;

  /// Prismalith's floor: which of the nine plates is missing.
  int choirHollow = 8;

  /// The beat-edge the mystic's strike is detected on.
  bool bitLastFrame = false;

  /// THE BLACK CELL (the Lost Maxim): the flaw found in its glass, and how
  /// many times Lightning has run it. Per run, like every slide.
  bool knowCrack = false;
  int knowStrikes = 0;

  /// Strikes it takes to craze the black glass clear.
  static const int knowStrikesToClear = 3;

  void reset() {
    field.reset();
    clock = 0;
    shear = 0;
    shearFrom = Offset.zero;
    choirHollow = 8;
    bitLastFrame = false;
    knowCrack = false;
    knowStrikes = 0;
  }
}

extension PrismLabyrinthKeep on PlanetDungeonGame {
  PrismKeepField get _keep => prism.field;

  /// The oriel's declaration of the two non-guardian stars.
  PrismKeep? get _keepStars => layout.rooms[layout.entranceRoomId]?.prism?.keep;

  /// The lattice cell [room] is, or null for the oriel/tuning hall/choir.
  int? _cellOf(DungeonRoom room) => room.prism?.cell?.index;

  // ── Lifecycle ────────────────────────────────────────────

  void _resetKeepState() {
    if (!_isKeep) return;
    // A death un-slides nothing by itself — the keep is puzzle state like
    // every other planet's, so it resets with the run.
    prism.reset();
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updateKeep(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isKeep) return;
    prism.clock += dt;
    if (prism.shear > 0) prism.shear = max(0.0, prism.shear - dt);
    _checkKeepStars();
    _updatePrismalith(room, dt);
  }

  /// Both stars are facts about the ARRANGEMENT, not about a room, so they are
  /// re-asked whenever anything could have moved — including Prismalith's own
  /// beats, which shunt the keep from two rooms away.
  void _checkKeepStars() {
    final spec = _keepStars;
    if (spec == null) return;
    final f = _keep;
    if (f.spectrumSolved && !hasStar(spec.spectrumStarIndex)) {
      earnStar(spec.spectrumStarIndex);
    }
    if (f.thronesServed && !hasStar(spec.throneStarIndex)) {
      earnStar(spec.throneStarIndex);
    }
  }

  // ── The Lost Maxim · KNOW THYSELF ────────────────────────
  //
  // THE BLACK CELL, WEDGED (2026-09-19; the §7 maxim standard, and Mud's
  // lesson that the best place to hide a secret is the state your own stars
  // punish).
  //
  // It used to be positional and one beat: stand all three bodies in the
  // split the hearth throws, in an arrangement Star 0 forbids. No chain, and
  // nothing anywhere taught it. It is a CHAIN now, and it lives in the one
  // state this planet was built to rescue you from:
  //
  //   1. WEDGE YOURSELF. The Black Cell is cut on two faces, north and west.
  //      Ride it into the north-west socket and both its doorways meet the
  //      keep's own frame: a sealed glass box with you inside, the jam the
  //      reachability search counted 7,404 times and the anneal exists for.
  //      Nothing is pressed for this; inside, every wall is black glass and
  //      the only thing in it is the three of you.
  //   2. THE SMALLEST FINDS THE FLAW — the rite's own declared Pip gate, the
  //      body that slips a crack, finds the hairline in the east face.
  //   3. LIGHTNING RUNS IT, three strikes — the entry rite's verb, the one
  //      hand in the party that cracks glass. The repeated beat; the glass
  //      crazes further with each, and at the third it goes clear.
  //   4. CRYSTAL READS THE GLASS — the mask's own job on this planet — and
  //      the three shapes on the far wall resolve into one. The rite of three.
  //
  // Then the anneal, which rings you out onto the oriel: the way out of a
  // wedge has always been the way out of a wedge. Nothing here asks for a
  // family the riddle did not name, a wrong hand answers with a puff and a
  // sentence, and the star path never passes it — no star wants a body in
  // the Black Cell, least of all in a corner.

  /// Every doorway of [chamber], standing in [cell], meets the outer frame:
  /// no way in and no doorway out. (Not a strand — the plate you rode in on
  /// rides you back, and the anneal is always there — but a sealed box.)
  bool _chamberSealed(int cell, PrismChamber chamber) {
    for (final facet in const [kFacetN, kFacetE, kFacetS, kFacetW]) {
      if (!chamber.cut(facet)) continue;
      if (keepNeighbourToward(cell, facet) >= 0) return false;
    }
    return true;
  }

  /// The party stands inside the Black Cell with both its doorways against
  /// the frame.
  bool get blackCellSealed {
    final cell = _cellOf(currentRoom);
    if (cell == null) return false;
    final ch = _keep.chamberAt(cell);
    return ch != null && ch.id == 'onyx' && _chamberSealed(cell, ch);
  }

  /// Inside the Black Cell: the flaw, the strikes, the reading.
  bool _tryBlackCell(DungeonCreature a) {
    final cell = _cellOf(currentRoom);
    if (cell == null) return false;
    final ch = _keep.chamberAt(cell);
    if (ch == null || ch.id != 'onyx') return false;
    if (discoveredClouds.contains(kCrystalKnowThyselfEgg)) return false;
    if ((a.position - kChamberHeart).distance > _kKeepReach + 30) return false;
    if (!_chamberSealed(cell, ch)) {
      // WHAT is missing (§5.6): a doorway is still in this glass somewhere.
      _setBlockedHint('One of this room\'s doorways still meets another');
      return true;
    }
    final el = a.member.element;
    // ── 2 · the flaw ──
    if (!prism.knowCrack) {
      if (abilityForFamily(a.member.family) != DungeonAbility.smallAccess) {
        _spawnAlchemyBurst(
          kChamberHeart,
          producedElement: el,
          particleCount: 8,
          intensity: 0.5,
        );
        _setBlockedHint('Only a small creature can find the flaw');
        return true;
      }
      prism.knowCrack = true;
      _cue(SoundCue.dungeonInteract);
      _spawnAlchemyBurst(
        kChamberHeart,
        producedElement: el,
        particleCount: 14,
        intensity: 0.7,
      );
      return true;
    }
    // ── 3 · three strikes ──
    if (prism.knowStrikes < PrismLabyrinth.knowStrikesToClear) {
      if (el != 'Lightning') {
        _spawnAlchemyBurst(
          kChamberHeart,
          producedElement: el,
          particleCount: 8,
          intensity: 0.5,
        );
        _setBlockedHint('Something needs to run through this flaw');
        return true;
      }
      prism.knowStrikes++;
      _cue(SoundCue.elementLightning);
      _spawnAlchemyBurst(
        kChamberHeart,
        producedElement: 'Crystal',
        reagentElements: const ['Lightning'],
        particleCount: 16 + prism.knowStrikes * 4,
        intensity: 0.8 + prism.knowStrikes * 0.15,
      );
      return true;
    }
    // ── 4 · the reading ──
    if (el != 'Crystal') {
      _spawnAlchemyBurst(
        kChamberHeart,
        producedElement: el,
        particleCount: 8,
        intensity: 0.5,
      );
      _setBlockedHint('Three shapes in the glass. Only Crystal can read them');
      return true;
    }
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    _cue(SoundCue.dungeonGateOpen);
    beginMaximRite(kCrystalKnowThyselfEgg, kChamberHeart);
    _spawnAlchemyBurst(
      kChamberHeart,
      producedElement: 'Light',
      reagentElements: const ['Crystal', 'Spirit'],
      particleCount: 42,
      intensity: 1.5,
    );
    return true;
  }

  /// §7 — the guardian fights WITH the planet's rule. Prismalith stands over
  /// the choir's heart plate and its root only shows through the GAP, so the
  /// lull opens when the gap is beneath it. Every strike beat rings the floor
  /// over — the gap slides out from under the mystic — and rings the keep
  /// upstairs over with it, so the arrangement you spent the run building is
  /// spent again in the fight.
  void _updatePrismalith(DungeonRoom room, double dt) {
    if (room.guardian == null || !guardianAwake) return;
    if (prism.choirHollow != kKeepHeartCell) {
      guardianVulnerable = false;
      return;
    }
    if (guardianVulnerable && !prism.bitLastFrame) {
      prism.bitLastFrame = true;
      return;
    }
    if (!guardianVulnerable && prism.bitLastFrame) {
      prism.bitLastFrame = false;
      _shuntChoirFloor();
      _keep.guardianShunt();
      _cue(SoundCue.dungeonHazardTrigger);
      // A closing announces itself (§5.7): this runs from update, where a
      // plain line is dropped unasked, and the keep upstairs has just moved.
      speakConsequence(
        'Prismalith rings. The floor shifts, and the keep with it',
      );
    }
  }

  /// The floor shunts itself: the lowest-indexed plate beside the gap slides
  /// into it. Deterministic, so the fight is testable and the player can learn
  /// its habit rather than fight a die roll.
  void _shuntChoirFloor() {
    final gap = prism.choirHollow;
    final into = keepNeighbours(gap).first;
    _slideChoirPlate(into);
  }

  /// Move the plate in [from] into the gap — and carry whoever is standing on
  /// it, because that is what this planet's verb does everywhere.
  void _slideChoirPlate(int from) {
    final floor = layout.rooms['prismalith_choir']?.prism?.choir;
    if (floor == null) return;
    final gap = prism.choirHollow;
    final delta = floor.plateCentre(gap) - floor.plateCentre(from);
    for (final c in creatures) {
      if (!c.alive) continue;
      if (floor.cellAt(c.position) != from) continue;
      c.position += delta;
    }
    prism.choirHollow = from;
  }

  // ── The lattice, as the engine sees it ───────────────────

  /// An arch is walkable only when the two chambers meeting at it are both cut
  /// on that face. Nothing here opens or closes a door — the twelve arches are
  /// constants; a slide only aligns or mis-aligns them.
  bool _keepDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isKeep) return false;
    final f = _keep;
    final from = _cellOf(room);
    final to = layout.rooms[door.targetRoomId]?.prism?.cell?.index;
    if (from != null && to != null) return !f.passable(from, to);
    // The frame arches (the oriel's threshold and the north arch to the rite)
    // are cut in the keep's own stone, not in any chamber's glass, so they
    // never shut — chamber or bare socket, the arch opens onto whatever is
    // there. That is what makes it impossible for Prismalith's beats to lock
    // the party out of the keep while they are downstairs in the choir.
    return false;
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How the keep is moved is the planet's earned reading (Mask).
  String _keepDoorHint(DungeonRoom room, DungeonDoor door) {
    final f = _keep;
    final from = _cellOf(room);
    final to = layout.rooms[door.targetRoomId]?.prism?.cell?.index;
    if (from != null && to != null) {
      if (f.chamberAt(from) == null || f.chamberAt(to) == null) {
        return 'No doorway on this wall';
      }
      return 'The doorways on the two sides don\'t line up';
    }
    return 'This arch is shut';
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Crystal verb, in priority order. Returns true when one was
  /// consumed. The shove-plates come LAST so a fixture standing near one
  /// always wins the press.
  bool _tryKeepVerb(DungeonCreature a) {
    if (!_isKeep) return false;
    return _tryGlassFace(a) ||
        _tryWestLamp(a) ||
        _tryHearthShard(a) ||
        _tryFacetFont(a) ||
        _tryBerthChain(a) ||
        _tryAnneal(a) ||
        _tryChoirPlate(a) ||
        _tryBlackCell(a) ||
        _tryShunt(a);
  }

  /// The entry rite: the keep's south face is one unbroken sheet, and
  /// Lightning is the only thing in the party that cracks glass.
  bool _tryGlassFace(DungeonCreature a) {
    final face = currentRoom.prism?.glassFace;
    if (face == null || entryDoorRevealed) return false;
    if ((a.position - face).distance > _kKeepReach) return false;
    if (a.member.element != 'Lightning') {
      _setBlockedHint('Only Lightning can crack this glass');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _cue(SoundCue.dungeonGateOpen);
    _cue(SoundCue.elementLightning);
    _setHint('The face crazes open, a threshold, and a keep behind it');
    _spawnAlchemyBurst(
      face,
      producedElement: 'Crystal',
      reagentElements: const ['Lightning'],
      particleCount: 32,
      intensity: 1.25,
    );
    return true;
  }

  /// THE WEST LAMP — Star 0's precondition. It takes LIGHT, which this party
  /// does not carry: **Crystal+Spirit→Light** is the planet's own braid
  /// (§6.10), and any trio of the three entry elements can make it, which is
  /// what keeps the Prism Star inside §4's first-descent guarantee.
  bool _tryWestLamp(DungeonCreature a) {
    if (_cellOf(currentRoom) != kKeepBeamRow.first) return false;
    if ((a.position - kWestLamp).distance > _kKeepReach) return false;
    final f = _keep;
    if (f.lampLit) {
      _setBlockedHint('The lamp is already lit');
      return true;
    }
    final direct = a.member.element == 'Light';
    final braid = _keepBraidReady(a);
    if (!direct && !braid) {
      _setBlockedHint(
        'The lamp needs Light. Crystal and Spirit together can make it',
      );
      return true;
    }
    f.lampLit = true;
    _cue(SoundCue.elementLight);
    _setHint('The lamp takes, and a light lies down the middle of the keep');
    _spawnAlchemyBurst(
      kWestLamp,
      producedElement: 'Light',
      reagentElements: direct ? const [] : const ['Crystal', 'Spirit'],
      unstable: braid && !direct,
      particleCount: 30,
      intensity: 1.2,
    );
    _checkKeepStars();
    return true;
  }

  /// Does this creature carry the keep's braid **Crystal+Spirit→Light**?
  bool _keepBraidReady(DungeonCreature a) {
    final e = a.member.element;
    if (e != 'Crystal' && e != 'Spirit') return false;
    final want = e == 'Crystal' ? 'Spirit' : 'Crystal';
    return creatures.any(
      (c) => c.alive && !identical(c, a) && c.member.element == want,
    );
  }

  /// THE SHARD HEARTH — Star 1's other half, and the planet's Lightning+HORN
  /// hard gate (§4). The shard is cold glass; only a horn's strike wakes it,
  /// and a wrong family gets one clean refusal and a stamped chip.
  bool _tryHearthShard(DungeonCreature a) {
    final cell = _cellOf(currentRoom);
    if (cell == null) return false;
    final f = _keep;
    if (f.chamberAt(cell)?.id != 'hearth') return false;
    if ((a.position - kChamberHeart).distance > _kKeepReach) return false;
    if (f.hearthKindled) {
      _setBlockedHint('The shard is already warm');
      return true;
    }
    final gate = layout.familyGateFor('shard_hearth');
    if (gate != null &&
        (a.member.element != gate.element ||
            abilityForFamily(a.member.family) !=
                abilityForFamily(gate.family))) {
      _stampFamilyGate(gate);
      return true;
    }
    f.hearthKindled = true;
    _cue(SoundCue.elementLightning);
    _setHint('The shard takes the strike and holds the heat', 3.4);
    _spawnAlchemyBurst(
      kChamberHeart,
      producedElement: 'Crystal',
      reagentElements: const ['Lightning'],
      particleCount: 30,
      intensity: 1.2,
    );
    _checkKeepStars();
    return true;
  }

  /// The rite's second half — element-only Crystal, so a party missing the Pip
  /// meets exactly ONE refusal at the crack rather than two (Ice's precedent).
  bool _tryFacetFont(DungeonCreature a) {
    final pos = currentRoom.prism?.facetFont;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kKeepReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (a.member.element != 'Crystal') {
      _setBlockedHint('Only Crystal can use the font');
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
    _setHint('The font rings true and holds the note');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Crystal',
      reagentElements: const ['Light'],
      particleCount: 28,
      intensity: 1.1,
    );
    return true;
  }

  /// THE BERTH CHAIN — the vault (§5.5: "a room that only ENTERS the grid in
  /// one configuration"). It bites only when the HOLLOW has come to rest in
  /// the mouth cell, which means you shunted OUT of the mouth to get here; the
  /// waiting facet comes in and the hollow goes out to the berth, and the keep
  /// is set solid until the chain is pulled again. The facet is cut with one
  /// doorway, on its west face — so of the three cells that can pull the
  /// chain, only the middle one can then walk in.
  bool _tryBerthChain(DungeonCreature a) {
    final cell = _cellOf(currentRoom);
    if (cell == null) return false;
    if (!keepNeighbours(kKeepMouthCell).contains(cell) &&
        cell != kKeepMouthCell) {
      return false;
    }
    if ((a.position - kBerthChain).distance > _kKeepReach) return false;
    final f = _keep;
    if (a.member.element != 'Crystal') {
      _setBlockedHint('Only Crystal can pull the chain');
      return true;
    }
    if (f.facetStanding) {
      if (!f.withdrawFacet(cell)) return true;
      _cue(SoundCue.dungeonBlockMove);
      speakConsequence('The facet slides out, and the empty slot is back');
      _spawnAlchemyBurst(
        kBerthChain,
        producedElement: 'Crystal',
        particleCount: 18,
        intensity: 0.8,
      );
      return true;
    }
    if (!f.canCallFacet(cell)) {
      _setBlockedHint('The chain is slack. The empty slot has to be here');
      return true;
    }
    f.callFacet(cell);
    _cue(SoundCue.dungeonBlockMove);
    // A CONSEQUENCE (§5.7): the whole keep has just been set solid.
    speakConsequence(
      'A room slides in from the east wall and fills the keep',
      4.0,
    );
    _spawnAlchemyBurst(
      kBerthChain,
      producedElement: 'Crystal',
      reagentElements: const ['Light'],
      particleCount: 34,
      intensity: 1.3,
    );
    return true;
  }

  /// THE ANNEAL — the valve. The keep's frame is one tuned instrument and
  /// every room has a boss on it; a Crystal hand rings the whole thing back to
  /// the arrangement it opened in, carrying the ringer with their own chamber
  /// and pushing the waiting facet back to its berth. Always available, from
  /// any state, which is what makes a wedged lattice a nuisance rather than a
  /// lost run (and what makes Prismalith's beats survivable from the choir).
  bool _tryAnneal(DungeonCreature a) {
    final cell = _cellOf(currentRoom);
    final pos = cell != null ? kCellTuningBoss : currentRoom.prism?.annealRing;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kKeepReach) return false;
    if (a.member.element != 'Crystal') {
      _setBlockedHint('Only Crystal can ring this boss');
      return true;
    }
    final f = _keep;
    if (cell == null && !f.hollowBerthed && _keepAtOpening) {
      _setBlockedHint('The keep is already in its starting layout');
      return true;
    }
    f.anneal();
    // Out, onto the oriel. See PrismKeepField.anneal: a ring that carried you
    // with your own chamber would set you back down in the same trap forever.
    currentRoomId = layout.entranceRoomId;
    _spreadCreaturesAround(layout.entranceSpawn);
    prism.shear = 0;
    prism.shearFrom = Offset.zero;
    _clearHints();
    _cue(SoundCue.dungeonWallBreak);
    // A closing announces itself (§5.7): every slide you made is gone.
    speakConsequence(
      'The keep resets to its starting layout, and you\'re back outside',
      4.2,
    );
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Crystal',
      reagentElements: const ['Light'],
      particleCount: 36,
      intensity: 1.35,
    );
    _checkKeepStars();
    onChanged();
    return true;
  }

  bool get _keepAtOpening {
    final c = _keep.cells;
    for (var i = 0; i < 9; i++) {
      if (c[i] != kKeepOpeningCells[i]) return false;
    }
    return true;
  }

  /// Prismalith's floor, worked by hand. In the choir there are no plates to
  /// aim at — the fight is too busy for precision — so a Crystal hand standing
  /// anywhere on a plate beside the gap shoves THAT plate into it, and rides.
  bool _tryChoirPlate(DungeonCreature a) {
    final floor = currentRoom.prism?.choir;
    if (floor == null) return false;
    final standing = floor.cellAt(a.position);
    if (standing < 0) return false;
    if (a.member.element != 'Crystal') return false;
    // The lull outranks the shove. Once the gap is under the mystic and its
    // root is showing, a Crystal hand's press is a STRIKE — otherwise the one
    // party member who can open the window is the one member who can never
    // use it, and the fight is unwinnable with the §6.10 ideal trio.
    if (guardianAwake && guardianVulnerable) return false;
    if (!keepNeighbours(prism.choirHollow).contains(standing)) return false;
    _slideChoirPlate(standing);
    _cue(SoundCue.dungeonBlockMove);
    _spawnAlchemyBurst(
      a.position,
      producedElement: 'Crystal',
      particleCount: 14,
      intensity: 0.7,
    );
    return true;
  }

  /// THE SHUNT — the planet's only verb, and its whole grammar. A Crystal hand
  /// on a shove-plate makes the chamber and the hollow beyond it TRADE PLACES,
  /// and the hand trades with them: the screen slides and your feet do not
  /// move on the floor they are standing on.
  ///
  /// It works from either side of the pair, and the difference is the whole
  /// feel of the verb. From inside a chamber you RIDE it across. From inside
  /// the bare socket you HAUL a neighbour in and stay with the hollow — which
  /// is what makes the socket the keep's one free-moving place, and what keeps
  /// a first descent from being locked into two arrangements.
  bool _tryShunt(DungeonCreature a) {
    final cell = _cellOf(currentRoom);
    if (cell == null) return false;
    final f = _keep;
    final inSocket = f.chamberAt(cell) == null;
    for (final facet in const [kFacetN, kFacetE, kFacetS, kFacetW]) {
      final target = keepNeighbourToward(cell, facet);
      if (target < 0) continue; // an outer wall carries no plate
      if ((a.position - keepPlateFor(facet)).distance > _kKeepReach) continue;
      if (a.member.element != 'Crystal') {
        _setBlockedHint('Only Crystal moves this glass');
        return true;
      }
      if (f.facetStanding) {
        _setBlockedHint('The keep is full. Nothing can slide');
        return true;
      }
      if (inSocket) {
        if (f.chamberAt(target) == null) continue;
      } else if (f.hollowCell != target) {
        _setBlockedHint('That side isn\'t the empty slot');
        return true;
      }
      _rideShunt(inSocket ? target : cell, target, facet);
      return true;
    }
    return false;
  }

  /// The ride itself. [chamberCell] is the cell the moving chamber starts in;
  /// [target] is always where the body ends up, because the pair exchanges and
  /// the body exchanges with it.
  void _rideShunt(int chamberCell, int target, int facet) {
    final f = _keep;
    if (f.shunt(chamberCell) < 0) return;
    _cue(SoundCue.dungeonBlockMove);
    currentRoomId = kKeepCellRooms[target];
    prism.shear = _kKeepShearSeconds;
    prism.shearFrom = switch (facet) {
      kFacetN => const Offset(0, 1),
      kFacetS => const Offset(0, -1),
      kFacetE => const Offset(-1, 0),
      _ => const Offset(1, 0),
    };
    _clearHints();
    _setHint('The chamber goes over, and takes you with it', 2.2);
    // THE CONSEQUENCE (§7). The frame rings on every shove, and now and then
    // the ringing shakes a shard loose. Nothing is spent; the keep simply gets
    // less pleasant to thrash.
    if (f.shunts % _kShuntsPerShard == 0) {
      spawnWispWave(
        element: 'Crystal',
        center: kChamberHeart,
        count: _kShardsPerRing,
        unstable: true,
        announce: false,
      );
    }
    _checkKeepStars();
    onChanged();
  }

  /// Test seam: shunt without walking a body onto a 64px plate.
  bool keepShuntForTest(int facet) {
    final cell = _cellOf(currentRoom);
    if (cell == null) return false;
    final target = keepNeighbourToward(cell, facet);
    if (target < 0) return false;
    final f = _keep;
    final inSocket = f.chamberAt(cell) == null;
    if (inSocket) {
      if (f.chamberAt(target) == null) return false;
    } else if (f.hollowCell != target) {
      return false;
    }
    _rideShunt(inSocket ? target : cell, target, facet);
    return true;
  }

  // ── The vault's one configuration ────────────────────────

  /// The bottled essence rides in the WAITING FACET, so it is only there to be
  /// found while the facet is standing in the mouth cell. Guarded in the
  /// engine's own cache check and glow so the cell cannot be farmed by walking
  /// through it with an ordinary chamber in place.
  bool get _keepVaultLive =>
      _keep.facetStanding && _cellOfId(currentRoomId) == kKeepMouthCell;

  int? _cellOfId(String roomId) => layout.rooms[roomId]?.prism?.cell?.index;

  /// Test seam for the vault gate — the cache's whole trick is that the cell
  /// only holds it in one configuration, so the proof has to be able to ask.
  bool get keepVaultLiveForTest => _keepVaultLive;

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): counters live beside the star tracker.
  DungeonProgressReadout? _keepProgressReadout() {
    final spec = _keepStars;
    final f = _keep;
    if (spec != null && !hasStar(spec.throneStarIndex) && f.hearthKindled) {
      return DungeonProgressReadout(
        label: 'THRONES',
        value: '${f.thronesStanding}/3',
        fraction: f.thronesStanding / 3,
      );
    }
    if (spec != null && !hasStar(spec.spectrumStarIndex) && f.lampLit) {
      return DungeonProgressReadout(
        label: 'HUE',
        value: f.beamLive ? '${f.beamHue} of $kRoseHue' : 'stopped',
        fraction: f.beamLive ? f.beamHue / 12 : 0,
      );
    }
    if (f.shunts > 0) {
      return DungeonProgressReadout(label: 'SHUNTS', value: '${f.shunts}');
    }
    return null;
  }

  /// GOAL only, never method (§5.6's solution-leak rule). How the keep is
  /// moved, which glass passes a light and what the berth chain is for are all
  /// Mask-insight content.
  String? _keepObjectiveHint(DungeonRoom room) {
    final f = _keep;
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The keep is above you. Its rooms slide around'
          : 'The keep\'s entrance is sealed behind a sheet of glass';
    }
    if (room.prism?.facetFont != null) {
      return 'The tuning hall. The rite needs the crack and the font';
    }
    if (room.guardian != null) {
      return 'Prismalith\'s hall. The last star is here';
    }
    final cell = _cellOf(room);
    if (cell == null) return null;
    final chamber = f.chamberAt(cell);
    if (chamber == null) return 'The empty slot. Rooms can slide into it';
    if (chamber.id == 'waiting') {
      return 'The waiting facet. Something is stored here';
    }
    if (chamber.id == 'hearth' && !f.hearthKindled) {
      return 'The Shard Hearth. Its shard is cold';
    }
    if (cell == kKeepBeamRow.first && !f.lampLit) {
      return 'The west lamp is out, so no light reaches the rose';
    }
    if (chamber.throne) return '${chamber.name}, not yet facing the hearth';
    return null;
  }

  /// AMBIENT — atmosphere only, no mechanics, no families, no requirements.
  void _keepAmbientHint(DungeonCreature a, DungeonRoom room) {
    final cell = _cellOf(room);
    if (cell == null) {
      if (room.guardian != null) {
        _setAmbientHint('The choir holds its breath in nine pieces');
      }
      return;
    }
    if (blackCellSealed) {
      _setAmbientHint(
        'Three of you on the far wall, and every one looking back',
      );
      return;
    }
    switch ((prism.clock ~/ 17) % 3) {
      case 0:
        _setAmbientHint('Somewhere in the walls, stone slides on stone');
      case 1:
        _setAmbientHint('The glass keeps a colour it was never given');
      default:
        _setAmbientHint('Your own shape walks the far wall, a moment late');
    }
  }

  /// INSIGHT — Mask's earned how-to, and the only channel allowed to teach
  /// method (§5.6). §6.10 gave Crystal's Mask the job of reading glass; §4
  /// forbids gating the first-descent star, so it reads glass HERE instead of
  /// standing at a lock (see the layout's familyGates note).
  void _keepReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    final f = _keep;
    if (room.guardian != null) {
      _setInsightHint(switch (tier) {
        0 => 'Prismalith can only be hit over the gap in the floor',
        1 => 'Slide the gap under Prismalith, then strike',
        _ =>
          'Slide the gap under it and strike. Each hit shifts the floor, so '
              'move the gap back under it after every one',
      });
      return;
    }
    if (room.prism?.facetFont != null) {
      _setInsightHint(switch (tier) {
        0 => 'The rite needs the crack and the font',
        1 => 'The crack needs a small creature. The font needs Crystal',
        _ =>
          'A Pip can work the crack. Any Crystal can use the font once you '
              'have both stars',
      });
      return;
    }
    final cell = _cellOf(room);
    if (cell != null &&
        f.chamberAt(cell)?.id == 'onyx' &&
        !discoveredClouds.contains(kCrystalKnowThyselfEgg)) {
      // ONE OBLIQUE LINE and nothing after it (the §7 maxim standard). It
      // does not tier and it does not track progress.
      _setInsightHint(
        'The black glass only shows whoever is inside it. Slide it to where '
        'none of its doorways meet another, and look',
      );
      return;
    }
    if (cell != null && kKeepBeamRow.contains(cell)) {
      _setInsightHint(switch (tier) {
        0 => 'The rose is a dial. The gold mark is where the light has to land',
        1 =>
          'Each room turns the light by its lit notches. Light only passes '
              'rooms with doorways on both the west and east',
        _ =>
          'The three rooms in this row add their notches. The rose wants '
              '$kRoseHue, and only one set of three makes it. The hearth is '
              'not in that set',
      });
      return;
    }
    if (cell != null && f.chamberAt(cell)?.id == 'hearth') {
      _setInsightHint(switch (tier) {
        0 => 'The three thrones need to face the hearth',
        1 =>
          'All three at once, and only the middle slot has enough sides for '
              'that',
        _ =>
          'Put the hearth in the middle slot, then slide the crimson, verdant '
              'and azure thrones against three of its open doorways',
      });
      return;
    }
    // Anywhere in the keep, insight reads the RULE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'Nine slots, eight rooms, one empty slot',
      1 =>
        'A room can only slide into the empty slot, and you ride with it. '
            'You can only walk through where both rooms have a doorway',
      _ =>
        'Any slide can be undone by sliding back. If you get stuck, Crystal '
            'can ring any tuning boss to reset the keep',
    });
  }

  double get _keepMoodTarget {
    if (currentRoom.guardian != null) return 0.22;
    if (_cellOf(currentRoom) != null) return _keep.beamLive ? 0.66 : 0.46;
    return 0.52;
  }

  // ── Rendering (§5.5 visual grammar) ──────────────────────
  // Nothing here may read like Water's tide regating: no level, no gauge, no
  // dissolve, no water. A slide is a HARD TRANSLATION with a bright shear at
  // its leading edge, and the keep's whole state is legible from an index
  // plate cut into every cell's frame. No MaskFilter.blur anywhere (the
  // game's known jank source) — everything is flat fills, strokes and glows
  // built from concentric strokes.
  //
  // ─── WHAT THIS PLACE IS ───
  // Vitrea is not a crystal cave, and nothing in it grew. It is a KEEP OF SET
  // GLASS: dressed stone cut into nine sockets, and slabs of ground glass
  // leaded up out of irregular panes, shoved about on bearing runways by a
  // rack sunk under the floor. So the room vocabulary is masonry, ironwork
  // and glaziery — courses and arrises, sunk channels and rack teeth, rail
  // chairs, cames and shims, ground bevels, and the swarf that a few
  // centuries of glass grinding across stone leaves in the corners.
  //
  // A BUILDING THAT MOVES HAS TO SHOW ITS BEARINGS. Everything the player is
  // standing on says so: the runways the slab rides, the wear scored into
  // them, the seam where a chamber does not quite touch its socket, the
  // wedges someone drove into that seam to stop it ringing.
  //
  // THE TRAP THIS PLANET SETS FOR ITS OWN ART, and what was done about it: a
  // 3×3 mechanic must not be drawn as a 3×3. The first attempt laid four
  // identical runways crossing in a square and nine identical plates in the
  // choir, and every room read as its own floor plan. The two runway axes are
  // DIFFERENT OBJECTS at different heights now — sunk rack channels east-west,
  // raised rail on chairs north-south — and no two plates in the choir are
  // cut, chipped or bedded alike. The only 3×3 left in the game is the index
  // plate, which is a diagram on purpose.

  // Painted with alpha so the prism sky shows through the keep (FLOOR
  // TRANSLUCENCY RULE, §8). These were laid down opaque, which flattened
  // every cell into the same slab of purple-grey and hid the dispersion the
  // whole planet is named for.
  static const double _keepFloorAlpha = 0.58;
  static const double _keepVoidAlpha = 0.46;
  static const Color _keepStone = Color(0xFF241F2B);
  static const Color _keepMortar = Color(0xFF3A3345);
  static const Color _keepVoid = Color(0xFF0B0910);
  static const Color _keepBrass = Color(0xFFE4C16A);
  static const Color _keepSheen = Color(0xFFBFD4E4);
  // The masonry palette. Two tones and an arris is all a dressed face needs;
  // the variation that stops it reading as brickwork is in the COURSING.
  static const Color _keepStoneLit = Color(0xFF3C3450);
  static const Color _keepStoneDim = Color(0xFF17131F);
  static const Color _keepIron = Color(0xFF4E4A5E);
  static const Color _keepRail = Color(0xFF9AA0B8);
  static const Color _keepSwarf = Color(0xFFCBD6E6);

  /// The two sunk rack channels (east-west) and the two raised rails
  /// (north-south) every socket is bedded with. Deliberately NOT a symmetric
  /// cross: they are two different pieces of machinery at two different
  /// heights, which is what keeps the bearing bed from reading as a lattice.
  static const List<double> _kChannelY = [92, 250];
  static const List<double> _kRailX = [104, 312];

  void _renderKeep(Canvas canvas, DungeonRoom room) {
    _renderGlassDoorPlugs(canvas, room);
    final cell = _cellOf(room);
    if (cell != null) {
      _renderKeepCell(canvas, room, cell);
      return;
    }
    if (room.prism?.choir != null) {
      _renderChoirFloor(canvas, room);
      return;
    }
    if (room.prism?.glassFace != null) {
      _renderOriel(canvas, room);
      return;
    }
    if (room.prism?.facetFont != null) _renderTuningHall(canvas, room);
  }

  void _renderKeepCell(Canvas canvas, DungeonRoom room, int cell) {
    final f = _keep;
    final chamber = f.chamberAt(cell);
    // Seeded per CELL as well as per bounds: all nine sockets are the same
    // 420×340 cut, and nine identical floors would tell the player they had
    // not moved when the whole planet's verb is that they have.
    final g = _keepGroundFor<_KeepFloor>(
      'socket:$cell:${room.bounds.width}x${room.bounds.height}',
      () => _buildSocketBed(room.bounds, cell),
    );

    _renderSocketBed(canvas, room, g);

    if (chamber == null) {
      _renderHollow(canvas, room, g);
    } else {
      canvas.save();
      // THE SHEAR: the chamber arrives from the side it was pushed from.
      if (prism.shear > 0) {
        final t = 1.0 - (prism.shear / _kKeepShearSeconds);
        final e = 1.0 - (1.0 - t) * (1.0 - t); // ease-out, no allocation
        final dx = prism.shearFrom.dx * room.bounds.width * (1 - e);
        final dy = prism.shearFrom.dy * room.bounds.height * (1 - e);
        canvas.translate(dx, dy);
      }
      _renderChamber(canvas, room, cell, chamber);
      if (chamber.id == 'onyx' && _chamberSealed(cell, chamber)) {
        _renderBlackCellMirror(canvas, room);
      }
      canvas.restore();
      if (prism.shear > 0) _renderShearEdge(canvas, room);
      // The seam belongs to the SOCKET, so it is drawn after the restore and
      // stays put while the chamber slides through it.
      _renderSeam(canvas, room, g);
    }

    _renderCellFrame(canvas, room, cell);
    _renderIndexPlate(canvas, cell);
  }

  /// THE BLACK CELL, WEDGED: black glass on every wall and nothing in it but
  /// the party — each body thrown back off the east and the south faces, a
  /// moment late. The flaw, once found, is a hairline in the east face; each
  /// strike crazes it further, and at the third the black goes clear.
  void _renderBlackCellMirror(Canvas canvas, DungeonRoom room) {
    final inner = room.bounds.deflate(16);
    final struck = prism.knowStrikes;
    final clear = struck >= PrismLabyrinth.knowStrikesToClear;
    final found = discoveredClouds.contains(kCrystalKnowThyselfEgg);
    canvas.drawRect(
      inner,
      Paint()
        ..color = _keepVoid.withValues(alpha: clear || found ? 0.18 : 0.46),
    );
    // Reflections: off the east face and off the south face, a beat behind.
    for (final c in creatures) {
      if (!c.alive) continue;
      final p = c.position;
      final east = Offset(2 * inner.right - p.dx - 12, p.dy);
      final south = Offset(p.dx, 2 * inner.bottom - p.dy - 12);
      for (final r in [east, south]) {
        if (!inner.inflate(30).contains(r)) continue;
        canvas.drawCircle(
          r,
          11,
          Paint()..color = _keepVoid.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          r,
          11,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _keepSheen.withValues(alpha: clear ? 0.8 : 0.55),
        );
        // The eye of it, looking back.
        canvas.drawCircle(
          r,
          3.5,
          Paint()..color = _keepSheen.withValues(alpha: clear ? 0.9 : 0.6),
        );
      }
    }
    if (!prism.knowCrack && !found) return;
    // The flaw, and the craze that runs out of it with every strike.
    final flaw = Offset(inner.right, inner.center.dy - 10);
    canvas.drawLine(
      flaw,
      flaw + const Offset(-34, 14),
      Paint()
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    final n = found ? PrismLabyrinth.knowStrikesToClear : struck;
    for (var k = 0; k < n; k++) {
      for (var i = 0; i < 4; i++) {
        final a = pi + (i - 1.5) * 0.35 + k * 0.18;
        final len = 60.0 + k * 55 + i * 9;
        canvas.drawLine(
          flaw,
          flaw + Offset(cos(a) * len, sin(a) * len),
          Paint()
            ..strokeWidth = 1.0
            ..color = _keepSheen.withValues(alpha: 0.45),
        );
      }
    }
  }

  /// THE SOCKET BED — what a room-sized slab of glass is actually shoved
  /// across. Dressed stone in courses of unequal height (the joints never
  /// line up, which is the difference between masonry and graph paper), two
  /// sunk channels with the driving rack in them, two raised rails on chairs
  /// crossing over the channels, and the ground-glass swarf that all of it
  /// leaves behind.
  void _renderSocketBed(Canvas canvas, DungeonRoom room, _KeepFloor g) {
    final b = room.bounds;
    canvas.drawRect(
      b,
      Paint()..color = _keepStone.withValues(alpha: _keepFloorAlpha),
    );
    _renderDressedStone(canvas, g);
    _renderRunways(canvas, b, g);
    _renderSwarf(canvas, g);
    // The socket's own cut reveal — the frame's inner edge, all the way round.
    canvas.drawRect(
      b.deflate(14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _keepMortar,
    );
  }

  /// Dressed courses. One fill, one joint, one lit arris per block — the
  /// arris is what makes a flat rectangle read as a stone with a top face.
  void _renderDressedStone(Canvas canvas, _KeepFloor g) {
    final face = Paint();
    final joint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _keepVoid.withValues(alpha: 0.45);
    final arris = Paint()
      ..strokeWidth = 1.0
      ..color = _keepSheen.withValues(alpha: 0.07);
    for (final blk in g.blocks) {
      canvas.drawRect(blk.r, face..color = blk.color);
      canvas.drawRect(blk.r, joint);
      canvas.drawLine(
        Offset(blk.r.left + 1.5, blk.r.top + 0.5),
        Offset(blk.r.right - 1.5, blk.r.top + 0.5),
        arris,
      );
    }
  }

  void _renderRunways(Canvas canvas, Rect b, _KeepFloor g) {
    // EAST-WEST: sunk channels, with the rack that drives a chamber across.
    final well = Paint()..color = _keepVoid.withValues(alpha: 0.62);
    final tooth = Paint()..color = _keepIron.withValues(alpha: 0.55);
    final lip = Paint()
      ..strokeWidth = 1.2
      ..color = _keepSheen.withValues(alpha: 0.10);
    for (final cy in _kChannelY) {
      final y = b.top + cy;
      final ch = Rect.fromLTRB(b.left + 10, y - 12, b.right - 10, y + 12);
      canvas.drawRect(ch, well);
      for (var x = ch.left + 7; x < ch.right - 9; x += 18) {
        canvas.drawRect(Rect.fromLTWH(x, y - 4, 9, 8), tooth);
      }
      canvas.drawLine(Offset(ch.left, ch.top), Offset(ch.right, ch.top), lip);
      // The shoe at each end, where the run stops.
      for (final x in [ch.left, ch.right]) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 14, height: 30),
          Paint()..color = _keepIron.withValues(alpha: 0.8),
        );
      }
    }
    // NORTH-SOUTH: rail laid on chairs ON TOP of the channels, so the two
    // axes cross at different heights and never read as one grid.
    final chair = Paint()..color = _keepIron.withValues(alpha: 0.85);
    final web = Paint()
      ..strokeWidth = 7
      ..color = _keepStoneDim.withValues(alpha: 0.85);
    final crown = Paint()
      ..strokeWidth = 2.6
      ..color = _keepRail.withValues(alpha: 0.42);
    for (final rx in _kRailX) {
      final x = b.left + rx;
      for (final cy in g.chairs) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, b.top + cy), width: 26, height: 13),
          chair,
        );
      }
      canvas.drawLine(Offset(x, b.top + 12), Offset(x, b.bottom - 12), web);
      canvas.drawLine(Offset(x, b.top + 12), Offset(x, b.bottom - 12), crown);
    }
    // WEAR. Glass has been ground over this bed for a very long time; the
    // scoring is what says the building has really been moving.
    final score = Paint()..color = _keepSwarf.withValues(alpha: 0.055);
    for (final s in g.scores) {
      canvas.drawRect(s.translate(b.left, b.top), score);
    }
  }

  void _renderSwarf(Canvas canvas, _KeepFloor g) {
    final dust = Paint()..color = _keepSwarf.withValues(alpha: 0.055);
    for (final p in g.swarf) {
      canvas.drawPath(p, dust);
    }
    final chip = Paint()..color = _keepSheen.withValues(alpha: 0.1);
    for (final p in g.shards) {
      canvas.drawPath(p, chip);
    }
  }

  /// THE HOLLOW — "an empty socket, and the keep's works below". It used to
  /// be four concentric rectangles, which read as a target painted on the
  /// floor rather than as the one cell with no glass in it. The socket has no
  /// slab, so what you stand on is the bare iron grating over the works: bars
  /// one way only (never a mesh), the gearing showing black between them, and
  /// every shard the keep has ever shaken loose lying in the bottom.
  void _renderHollow(Canvas canvas, DungeonRoom room, _KeepFloor g) {
    final r = room.bounds.deflate(26);
    canvas.drawRect(r, Paint()..color = _keepVoid.withValues(alpha: 0.66));
    // The works, seen a long way down: two gear rims and the drive shaft.
    final gear = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = _keepIron.withValues(alpha: 0.95);
    for (final c in [
      r.center + const Offset(-58, 26),
      r.center + const Offset(74, -34),
    ]) {
      canvas.drawCircle(c, 34, gear);
      canvas.drawCircle(c, 21, gear);
      for (var i = 0; i < 9; i++) {
        final a = i * 0.698;
        canvas.drawLine(
          c + Offset(cos(a), sin(a)) * 21,
          c + Offset(cos(a), sin(a)) * 34,
          gear,
        );
      }
    }
    canvas.drawRect(
      Rect.fromLTRB(
        r.left + 20,
        r.center.dy - 5,
        r.right - 20,
        r.center.dy + 5,
      ),
      Paint()..color = _keepIron.withValues(alpha: 0.45),
    );
    // The grating: heavy bars ONE WAY, because a mesh is a grid and this
    // planet has to stop drawing grids. The first pass laid them at a 21px
    // pitch and the socket came out looking like a barcode; they are half as
    // many, twice as heavy, and lit on top so they have thickness.
    final bar = Paint()..color = _keepStoneDim.withValues(alpha: 0.95);
    final barLit = Paint()
      ..strokeWidth = 1.6
      ..color = _keepSheen.withValues(alpha: 0.17);
    for (var y = r.top + 8; y < r.bottom - 8; y += 42) {
      final h = min(24.0, r.bottom - 8 - y);
      canvas.drawRect(Rect.fromLTWH(r.left, y, r.width, h), bar);
      canvas.drawLine(Offset(r.left, y + 1), Offset(r.right, y + 1), barLit);
      canvas.drawLine(
        Offset(r.left, y + h - 1),
        Offset(r.right, y + h - 1),
        Paint()
          ..strokeWidth = 1.4
          ..color = _keepVoid.withValues(alpha: 0.7),
      );
    }
    // Two bearers holding the bars, and the socket's cut lip.
    for (final x in [r.left + r.width * 0.3, r.left + r.width * 0.72]) {
      canvas.drawRect(
        Rect.fromLTRB(x - 7, r.top, x + 7, r.bottom),
        Paint()..color = _keepIron.withValues(alpha: 0.5),
      );
    }
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _keepMortar,
    );
    for (final p in g.shards) {
      canvas.drawPath(p, Paint()..color = _keepSheen.withValues(alpha: 0.12));
    }
  }

  /// THE SEAM. A chamber never quite touches its socket — there is a finger's
  /// width of dark all round it, with wedges driven in at a few places to
  /// stop the whole keep ringing. It is the single clearest statement that
  /// the thing you are standing in is a loose part of a bigger machine.
  void _renderSeam(Canvas canvas, DungeonRoom room, _KeepFloor g) {
    final r = room.bounds.deflate(26);
    canvas.drawRect(
      r.inflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = _keepVoid.withValues(alpha: 0.55),
    );
    canvas.drawRect(
      r.inflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _keepSheen.withValues(alpha: 0.12),
    );
    final wedge = Paint()..color = _keepBrass.withValues(alpha: 0.42);
    for (final w in g.shims) {
      canvas.drawPath(w.shift(room.bounds.topLeft), wedge);
    }
  }

  void _renderChamber(
    Canvas canvas,
    DungeonRoom room,
    int cell,
    PrismChamber chamber,
  ) {
    final glass = Color(chamber.argb);
    final r = room.bounds.deflate(26);
    // The leadwork is cached per CHAMBER, not per cell, so a chamber is
    // recognisable at a glance when it turns up in a different socket — which
    // is the only way a player can track eight objects round nine holes.
    final gl = _keepGroundFor<_KeepGlass>(
      'glass:${chamber.id}',
      () => _buildChamberGlass(r, chamber),
    );

    // The glass never changes: baked once per chamber (§7.11), and carried
    // through the shear by the translate round this call.
    canvas.drawPicture(
      _chamberGlassCache.putIfAbsent(
        '${chamber.id}|${r.left},${r.top},${r.width}x${r.height}',
        () {
          final rec = ui.PictureRecorder();
          _paintChamberGlass(Canvas(rec), r, chamber, gl, glass);
          return rec.endRecording();
        },
      ),
    );

    // KNOW THYSELF, kept: the Black Cell's medallion silvered for good
    // (planet_dungeon_game_crystal_art.dart).
    if (chamber.id == 'onyx') {
      _drawKnowThyselfMirror(canvas, r.deflate(22).center);
    }
    if (chamber.id == 'hearth') _renderShardHearth(canvas);
    if (chamber.throne) _renderThrone(canvas, glass);
    if (chamber.id == 'waiting') _renderWaitingFacet(canvas, glass);
    _renderBeamThrough(canvas, cell, chamber);
  }

  void _paintChamberGlass(
    Canvas c,
    Rect r,
    PrismChamber chamber,
    _KeepGlass gl,
    Color glass,
  ) {
    // The slab, bedded. One faint body tone, then the panes over it, so a
    // dropped pane never leaves a hole in the glass.
    //
    // THE ALPHAS ARE LOW ON PURPOSE, and the first attempt got them wrong:
    // at 0.22 body plus 0.2–0.4 panes the hearth's chamber came out as one
    // flat slab of brown with scratches on it — the runways underneath it
    // vanished, and with them the whole reason to have drawn a bearing bed.
    // You are meant to see the machinery THROUGH the glass.
    c.drawRect(r, Paint()..color = glass.withValues(alpha: 0.12));
    final fill = Paint();
    // Every pane colour, jamb colour and bevel colour is resolved at BUILD
    // time, so the render loop allocates no Colors and does no lerping.

    // The cames carry the whole read for a PALE or a BLACK chamber: the Pale
    // Cell and the Black Cell have almost no colour to spend, so what tells
    // the player a slab of glass is standing in the socket at all is its
    // leadwork and its ground edges, not its hue. They are dark and definite.
    final came = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = _keepVoid.withValues(alpha: 0.46);
    final lead = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _keepSheen.withValues(alpha: 0.1);
    // The lattice is glazed in light came, so its diamonds read as a screen
    // over the bed rather than as bars across it.
    final latticeCame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _keepVoid.withValues(alpha: 0.16);
    for (var i = 0; i < gl.panes.length; i++) {
      final light = i >= gl.latticeFrom && i < gl.latticeTo;
      c.drawPath(gl.panes[i], fill..color = gl.paneColours[i]);
      c.drawPath(gl.panes[i], light ? latticeCame : came);
      if (!light) c.drawPath(gl.panes[i], lead);
    }
    // The arris the grinding wheel left on each pane. These were long white
    // diagonals crossing the whole slab and read as somebody had keyed it
    // with a nail; they are short, dim and pane-sized now.
    final wheelMark = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.09);
    for (final s in gl.arrises) {
      c.drawLine(s.$1, s.$2, wheelMark);
    }
    // THE RIM BEVEL — the slab's edge is ground off all round. One clip, not
    // one per pane: this is the cost-conscious version of the same read.
    c.save();
    c.clipRect(r);
    c.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = gl.bevel,
    );
    c.drawRect(
      r.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _keepSheen.withValues(alpha: 0.18),
    );
    c.restore();
    // Chips out of the corners, because a slab that has been shoved into
    // stone a few thousand times is not still sharp.
    for (final p in gl.chips) {
      c.drawPath(p, Paint()..color = _keepVoid.withValues(alpha: 0.5));
    }

    for (final facet in const [kFacetN, kFacetE, kFacetS, kFacetW]) {
      if (chamber.cut(facet)) _renderFacetDoorway(c, r, facet, gl.jamb);
      // HOW FAR THIS GLASS BENDS THE LIGHT (2026-09-25): a ring of twelve
      // notches round the medallion, as many lit as the chamber bends a beam
      // round the keep's twelve-step wheel — the same wheel the east rose is a
      // dial of. Bends add, so three chambers in the beam row send the light
      // round by the sum of their notches. It was nowhere on screen.
      if (chamber.id != 'waiting') {
        final mc = r.deflate(22).center;
        for (var k = 0; k < 12; k++) {
          final a = -pi / 2 + k * 2 * pi / 12;
          final lit = k < chamber.bend;
          c.drawLine(
            mc + Offset(cos(a), sin(a)) * 56,
            mc + Offset(cos(a), sin(a)) * (lit ? 68 : 62),
            Paint()
              ..strokeWidth = lit ? 4 : 2
              ..strokeCap = StrokeCap.round
              ..color = lit
                  ? _wheelColour(k + 1).withValues(alpha: 0.95)
                  : _keepVoid.withValues(alpha: 0.55),
          );
        }
      }
    }
  }

  /// A CUT FACE IS A DOORWAY, NOT A BADGE. This used to be a bright bar
  /// filling the opening — which read as the wall being PLUGGED at exactly
  /// the place the player can walk through, the wrong way round. The glass is
  /// removed there now: the socket bed shows through the gap, and the two
  /// ground edges either side stand as jambs with the wheel's arris on them.
  void _renderFacetDoorway(Canvas canvas, Rect r, int facet, Color ground) {
    // Aligned with the authored door rects in the layout (110px wide on the
    // north/south walls, 110px tall on the east/west).
    //
    // DEPTH 34, NOT 10 — a shallow notch sat entirely underneath the 44px
    // shove-plate that stands at the middle of every wall, so on the rendered
    // room you could not tell a cut face from a blind one, which is the
    // single most important thing to be able to see in this keep. A reveal
    // this deep puts both jambs out where the plate cannot cover them.
    const d = 34.0;
    final gap = switch (facet) {
      kFacetN => Rect.fromLTWH(r.left + 129, r.top - 4, 110, d),
      kFacetS => Rect.fromLTWH(r.left + 129, r.bottom + 4 - d, 110, d),
      kFacetW => Rect.fromLTWH(r.left - 4, r.top + 102, d, 110),
      _ => Rect.fromLTWH(r.right + 4 - d, r.top + 102, d, 110),
    };
    // The opening: the glass simply is not there, so the socket bed shows.
    canvas.drawRect(gap, Paint()..color = _keepVoid.withValues(alpha: 0.5));
    final horizontal = facet == kFacetN || facet == kFacetS;
    final jamb = Paint()..color = ground;
    final arris = Paint()
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.32);
    for (final near in const [true, false]) {
      final j = horizontal
          ? Rect.fromLTWH(
              near ? gap.left - 11 : gap.right,
              gap.top,
              11,
              gap.height,
            )
          : Rect.fromLTWH(
              gap.left,
              near ? gap.top - 11 : gap.bottom,
              gap.width,
              11,
            );
      canvas.drawRect(j, jamb);
      // Outlined, so a pale jamb still reads against pale stone.
      canvas.drawRect(
        j,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _keepVoid.withValues(alpha: 0.7),
      );
      canvas.drawLine(
        horizontal ? j.topCenter : j.centerLeft,
        horizontal ? j.bottomCenter : j.centerRight,
        arris,
      );
    }
    // The sill: a ground lip on the inner side of the opening, so a body
    // steps over something on the way through.
    final sill = Paint()
      ..strokeWidth = 2.2
      ..color = ground.withValues(alpha: 0.65);
    switch (facet) {
      case kFacetN:
        canvas.drawLine(gap.bottomLeft, gap.bottomRight, sill);
      case kFacetS:
        canvas.drawLine(gap.topLeft, gap.topRight, sill);
      case kFacetW:
        canvas.drawLine(gap.topRight, gap.bottomRight, sill);
      default:
        canvas.drawLine(gap.topLeft, gap.bottomLeft, sill);
    }
  }

  void _renderShardHearth(Canvas canvas) {
    final f = _keep;
    final warm = f.hearthKindled;
    final base = warm ? _keepBrass : const Color(0xFF6A6070);
    // It stands on something. A shard this size resting on nothing was the
    // clearest "floating fixture" left in the keep: there is a stepped stone
    // pad under it now, and the shard is socketed into a bronze collar.
    canvas.drawRect(
      Rect.fromCenter(
        center: kChamberHeart + const Offset(0, 40),
        width: 108,
        height: 26,
      ),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.6),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: kChamberHeart + const Offset(0, 31),
        width: 82,
        height: 16,
      ),
      Paint()..color = _keepStoneLit.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: kChamberHeart + const Offset(0, 22),
        width: 56,
        height: 13,
      ),
      Paint()..color = _keepIron.withValues(alpha: 0.95),
    );
    // A standing shard, drawn as a hard prism — never a soft glow. Three
    // ground faces, so it has a body rather than an outline.
    final left = Path()
      ..moveTo(kChamberHeart.dx, kChamberHeart.dy - 52)
      ..lineTo(kChamberHeart.dx, kChamberHeart.dy + 28)
      ..lineTo(kChamberHeart.dx - 25, kChamberHeart.dy + 10)
      ..close();
    final right = Path()
      ..moveTo(kChamberHeart.dx, kChamberHeart.dy - 52)
      ..lineTo(kChamberHeart.dx + 25, kChamberHeart.dy + 10)
      ..lineTo(kChamberHeart.dx, kChamberHeart.dy + 28)
      ..close();
    canvas.drawPath(left, Paint()..color = base.withValues(alpha: 0.95));
    canvas.drawPath(right, Paint()..color = base.withValues(alpha: 0.62));
    canvas.drawLine(
      Offset(kChamberHeart.dx, kChamberHeart.dy - 52),
      Offset(kChamberHeart.dx, kChamberHeart.dy + 28),
      Paint()
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: warm ? 0.5 : 0.22),
    );
    if (!warm) return;
    // Concentric strokes stand in for a glow — no blur.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        kChamberHeart,
        40.0 + i * 8,
        ring..color = _keepBrass.withValues(alpha: 0.20 - i * 0.05),
      );
    }
  }

  /// A THRONE IS CUT, NOT STACKED. Two rectangles read as a crate; a throne
  /// cut out of a block of glass has a dais, a chamfered seat, arms, and a
  /// tall back with an arch taken out of it.
  void _renderThrone(Canvas canvas, Color glass) {
    final c = kChamberHeart;
    // Dais — two steps, so it is standing on the chamber's own floor.
    canvas.drawRect(
      Rect.fromCenter(center: c + const Offset(0, 42), width: 126, height: 22),
      Paint()..color = glass.withValues(alpha: 0.42),
    );
    canvas.drawRect(
      Rect.fromCenter(center: c + const Offset(0, 32), width: 98, height: 16),
      Paint()..color = glass.withValues(alpha: 0.55),
    );
    // The back, with an arch cut through it.
    final back = Rect.fromLTWH(c.dx - 31, c.dy - 60, 62, 76);
    canvas.drawRect(back, Paint()..color = glass.withValues(alpha: 0.72));
    canvas.drawPath(
      Path()
        ..moveTo(back.left + 13, back.bottom)
        ..lineTo(back.left + 13, back.top + 30)
        ..quadraticBezierTo(c.dx, back.top + 2, back.right - 13, back.top + 30)
        ..lineTo(back.right - 13, back.bottom)
        ..close(),
      Paint()..color = _keepVoid.withValues(alpha: 0.32),
    );
    // Seat and arms.
    canvas.drawRect(
      Rect.fromCenter(center: c + const Offset(0, 14), width: 78, height: 22),
      Paint()..color = glass.withValues(alpha: 0.95),
    );
    for (final dx in const [-43.0, 43.0]) {
      canvas.drawRect(
        Rect.fromCenter(center: c + Offset(dx, 2), width: 13, height: 44),
        Paint()..color = glass.withValues(alpha: 0.8),
      );
    }
    // The ground arris along the seat's front edge, and a brass strap.
    canvas.drawLine(
      c + const Offset(-39, 3),
      c + const Offset(39, 3),
      Paint()
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.24),
    );
    canvas.drawRect(
      Rect.fromCenter(center: c + const Offset(0, 25), width: 86, height: 4),
      Paint()..color = _keepBrass.withValues(alpha: 0.55),
    );
  }

  /// THE WAITING FACET — the vault chamber, and the only one that has spent
  /// its life in a berth rather than a socket. A bare stroked rectangle said
  /// nothing; it is a crated slab now, still strapped, standing on the
  /// berth's own runners with the packing straw of ground glass around it.
  void _renderWaitingFacet(Canvas canvas, Color glass) {
    final crate = Rect.fromCenter(
      center: kChamberHeart,
      width: 150,
      height: 112,
    );
    canvas.drawRect(crate, Paint()..color = glass.withValues(alpha: 0.3));
    canvas.drawRect(
      crate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _keepBrass.withValues(alpha: 0.6),
    );
    // Straps, on the diagonal so they never make a frame of their own.
    final strap = Paint()
      ..strokeWidth = 5
      ..color = _keepIron.withValues(alpha: 0.8);
    canvas.drawLine(crate.topLeft, crate.bottomRight, strap);
    canvas.drawLine(crate.bottomLeft, crate.topRight, strap);
    canvas.drawCircle(
      crate.center,
      11,
      Paint()..color = _keepBrass.withValues(alpha: 0.7),
    );
    // The berth's runners, still under it.
    for (final dy in const [-46.0, 46.0]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: kChamberHeart + Offset(0, dy),
          width: 178,
          height: 7,
        ),
        Paint()..color = _keepIron.withValues(alpha: 0.55),
      );
    }
  }

  /// The lamp's light, lying down the middle row. Drawn as a hard-edged band
  /// with a bright core line — architecture lit, not water moving.
  void _renderBeamThrough(Canvas canvas, int cell, PrismChamber chamber) {
    final f = _keep;
    if (!f.beamLive || !kKeepBeamRow.contains(cell)) return;
    // How far round the wheel the light has been bent by the time it is here.
    var hue = 0;
    for (final c in kKeepBeamRow) {
      hue += f.chamberAt(c)?.bend ?? 0;
      if (c == cell) break;
    }
    final tone = _wheelColour(hue % 12);
    canvas.drawRect(kBeamBand, Paint()..color = tone.withValues(alpha: 0.22));
    canvas.drawLine(
      Offset(kBeamBand.left, kBeamBand.center.dy),
      Offset(kBeamBand.right, kBeamBand.center.dy),
      Paint()
        ..strokeWidth = 3
        ..color = tone.withValues(alpha: 0.85),
    );
    // The only thing in a cell that animates: one glint travelling the beam,
    // because light in glass is the one thing here that should not sit still.
    final gx = kBeamBand.left + (prism.clock * 118) % kBeamBand.width;
    canvas.drawCircle(
      Offset(gx, kBeamBand.center.dy),
      4.5,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    if (chamber.id != 'hearth') return;
    // The hearth SPLITS rather than bends — three shapes, which is the maxim.
    for (final dy in const [-22.0, 0.0, 22.0]) {
      canvas.drawLine(
        Offset(kChamberHeart.dx, kBeamBand.center.dy),
        Offset(kBeamBand.right, kBeamBand.center.dy + dy),
        Paint()
          ..strokeWidth = 1.6
          ..color = tone.withValues(alpha: 0.6),
      );
    }
  }

  static Color _wheelColour(int step) {
    const wheel = [
      Color(0xFFE05A4A),
      Color(0xFFE0864A),
      Color(0xFFE0B84A),
      Color(0xFFC8E04A),
      Color(0xFF7CE04A),
      Color(0xFF4AE08A),
      Color(0xFF4AE0D6),
      Color(0xFF4AAEE0),
      Color(0xFF4A6EE0),
      Color(0xFF804AE0),
      Color(0xFFC44AE0),
      Color(0xFFE04A96),
    ];
    return wheel[step % 12];
  }

  void _renderShearEdge(Canvas canvas, DungeonRoom room) {
    final t = prism.shear / _kKeepShearSeconds;
    final p = Paint()
      ..strokeWidth = 3
      ..color = _keepSheen.withValues(alpha: 0.5 * t);
    final d = prism.shearFrom;
    if (d.dx != 0) {
      final x = d.dx > 0 ? room.bounds.left + 26 : room.bounds.right - 26;
      canvas.drawLine(
        Offset(x, room.bounds.top + 26),
        Offset(x, room.bounds.bottom - 26),
        p,
      );
    } else if (d.dy != 0) {
      final y = d.dy > 0 ? room.bounds.top + 26 : room.bounds.bottom - 26;
      canvas.drawLine(
        Offset(room.bounds.left + 26, y),
        Offset(room.bounds.right - 26, y),
        p,
      );
    }
  }

  /// The FRAME's own furniture. It belongs to the socket, not the chamber, so
  /// it stays exactly where it is while the world slides past it — which is
  /// the clearest possible statement of the planet's rule.
  void _renderCellFrame(Canvas canvas, DungeonRoom room, int cell) {
    final f = _keep;
    for (final facet in const [kFacetN, kFacetE, kFacetS, kFacetW]) {
      final n = keepNeighbourToward(cell, facet);
      if (n < 0) continue;
      final inSocket = f.chamberAt(cell) == null;
      final ready =
          !f.facetStanding &&
          (inSocket ? f.chamberAt(n) != null : f.hollowCell == n);
      _renderShovePlate(canvas, keepPlateFor(facet), facet, ready);
    }
    _renderTuningBoss(canvas, kCellTuningBoss, 15);
    // The berth chain, in the three sockets that can see the berth's mouth.
    if (keepNeighbours(kKeepMouthCell).contains(cell) ||
        cell == kKeepMouthCell) {
      _renderBerthChain(
        canvas,
        f.facetStanding || f.hollowCell == kKeepMouthCell,
      );
    }
    if (cell == kKeepBeamRow.first) _renderWestLamp(canvas, f.lampLit);
    if (cell == kKeepBeamRow.last) _renderEastRose(canvas);
  }

  /// A SHOVE-PLATE IS A TREAD-PLATE SET IN THE STONE. It was a 40px square in
  /// two colours — the verb the player uses more than any other on this
  /// planet, drawn as a swatch. There is a chamfered rebate, a cast plate
  /// bedded in it on two hold-down bolts, and a chevron cast into the tread
  /// pointing at the wall this plate sends the chamber through, so which way
  /// a plate takes you is read off the floor and never off a legend.
  void _renderShovePlate(Canvas canvas, Offset at, int facet, bool ready) {
    canvas.drawRect(
      Rect.fromCenter(center: at, width: 56, height: 56),
      Paint()..color = _keepVoid.withValues(alpha: 0.42),
    );
    final plate = Rect.fromCenter(center: at, width: 44, height: 44);
    canvas.drawRect(
      plate,
      Paint()..color = ready ? const Color(0xFF6E5628) : _keepMortar,
    );
    // Chamfer: lit on the top and left, shadowed on the bottom and right.
    canvas.drawLine(
      plate.topLeft,
      plate.topRight,
      Paint()
        ..strokeWidth = 2
        ..color = _keepBrass.withValues(alpha: ready ? 0.7 : 0.26),
    );
    canvas.drawLine(
      plate.bottomLeft,
      plate.bottomRight,
      Paint()
        ..strokeWidth = 2
        ..color = _keepVoid.withValues(alpha: 0.55),
    );
    for (final c in [
      plate.topLeft + const Offset(6, 6),
      plate.bottomRight - const Offset(6, 6),
    ]) {
      canvas.drawCircle(c, 2.6, Paint()..color = _keepIron);
      canvas.drawCircle(
        c - const Offset(0.6, 0.6),
        1.2,
        Paint()..color = _keepSheen.withValues(alpha: 0.3),
      );
    }
    final d = switch (facet) {
      kFacetN => const Offset(0, -1),
      kFacetS => const Offset(0, 1),
      kFacetE => const Offset(1, 0),
      _ => const Offset(-1, 0),
    };
    final side = Offset(-d.dy, d.dx);
    final tread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = (ready ? _keepBrass : _keepSheen).withValues(
        alpha: ready ? 0.85 : 0.22,
      );
    for (var i = 0; i < 2; i++) {
      final tip = at + d * (4.0 + i * 9);
      canvas.drawPath(
        Path()
          ..moveTo(
            tip.dx - d.dx * 8 + side.dx * 10,
            tip.dy - d.dy * 8 + side.dy * 10,
          )
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(
            tip.dx - d.dx * 8 - side.dx * 10,
            tip.dy - d.dy * 8 - side.dy * 10,
          ),
        tread,
      );
    }
    if (!ready) return;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 1; i <= 3; i++) {
      canvas.drawRect(
        plate.inflate(4.0 + i * 5),
        glow..color = _keepBrass.withValues(alpha: 0.22 - i * 0.05),
      );
    }
  }

  /// THE ANNEAL, wherever it is struck. The keep's frame is one tuned
  /// instrument, so the boss is a bell: a stone plinth, a bronze dome turned
  /// in concentric rings, and the bright crescent a few thousand strikes have
  /// worn into one side of it. (It was a flat circle with a ring round it,
  /// which read as a button.)
  void _renderTuningBoss(Canvas canvas, Offset at, double r) {
    canvas.drawRect(
      Rect.fromCenter(
        center: at + Offset(0, r * 0.72),
        width: r * 2.7,
        height: r * 0.9,
      ),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.9),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: at + Offset(0, r * 0.45),
        width: r * 2.1,
        height: r * 0.7,
      ),
      Paint()..color = _keepStoneLit.withValues(alpha: 0.9),
    );
    canvas.drawCircle(at, r, Paint()..color = _keepIron);
    final turn = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        at,
        r * i / 3.6,
        turn..color = _keepBrass.withValues(alpha: 0.16 + i * 0.06),
      );
    }
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _keepBrass.withValues(alpha: 0.65),
    );
    canvas.drawArc(
      Rect.fromCircle(center: at, radius: r - 2.5),
      -2.5,
      1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Colors.white.withValues(alpha: 0.24),
    );
  }

  /// THE BERTH CHAIN — an actual chain, hung off a bracket in the east frame,
  /// with a ring pull on the end. It was a 16×34 rectangle.
  void _renderBerthChain(Canvas canvas, bool taut) {
    final tone = (taut ? _keepBrass : _keepIron).withValues(alpha: 0.92);
    canvas.drawRect(
      Rect.fromCenter(
        center: kBerthChain + const Offset(0, -54),
        width: 34,
        height: 10,
      ),
      Paint()..color = _keepIron,
    );
    final link = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = tone;
    // Slack chain hangs off to one side; taut chain hangs straight.
    for (var i = 0; i < 5; i++) {
      final sag = taut ? 0.0 : (i.isEven ? 4.0 : -4.0) * (i / 4);
      canvas.drawOval(
        Rect.fromCenter(
          center: kBerthChain + Offset(sag, -44.0 + i * 11),
          width: 11,
          height: 14,
        ),
        link,
      );
    }
    canvas.drawCircle(
      kBerthChain + Offset(taut ? 0 : 4, 14),
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..color = tone,
    );
  }

  /// THE WEST LAMP, in its bracket on the outer frame. A filled circle said
  /// "indicator"; a lantern with a hood, a lens and a bracket says the beam
  /// comes from somewhere.
  void _renderWestLamp(Canvas canvas, bool lit) {
    canvas.drawRect(
      Rect.fromCenter(
        center: kWestLamp + const Offset(-8, 0),
        width: 16,
        height: 46,
      ),
      Paint()..color = _keepIron.withValues(alpha: 0.95),
    );
    final hood = Path()
      ..moveTo(kWestLamp.dx - 4, kWestLamp.dy - 22)
      ..lineTo(kWestLamp.dx + 18, kWestLamp.dy - 13)
      ..lineTo(kWestLamp.dx + 18, kWestLamp.dy + 13)
      ..lineTo(kWestLamp.dx - 4, kWestLamp.dy + 22)
      ..close();
    canvas.drawPath(
      hood,
      Paint()..color = _keepStoneDim.withValues(alpha: 0.95),
    );
    canvas.drawPath(
      hood,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _keepBrass.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      kWestLamp + const Offset(9, 0),
      9,
      Paint()..color = (lit ? _keepBrass : _keepMortar).withValues(alpha: 0.95),
    );
    if (!lit) return;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        kWestLamp + const Offset(9, 0),
        9.0 + i * 7,
        glow..color = _keepBrass.withValues(alpha: 0.22 - i * 0.05),
      );
    }
  }

  /// THE EAST ROSE — a rose window, which is radial and therefore the one
  /// piece of regular geometry on this planet that is allowed to be regular.
  /// THE EAST ROSE, AS A DIAL (2026-09-25): the keep's twelve-step wheel in
  /// glass, the step it was cut to read marked in gold, and — while the lamp
  /// burns — a pointer on the step the beam actually reaches. When they
  /// meet, the whole rose lights. It was a small tinted disc that named the
  /// target colour and nothing else.
  void _renderEastRose(Canvas canvas) {
    final f = _keep;
    final c = kEastRose - const Offset(28, 0);
    const outer = 34.0, inner = 14.0;
    final solved = f.spectrumSolved;
    canvas.drawCircle(c, outer + 6, Paint()..color = _keepStoneDim);
    if (solved && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        70,
        _wheelColour(kRoseHue).withValues(alpha: 0.5),
      );
    }
    for (var k = 0; k < 12; k++) {
      final a0 = -pi / 2 + k * 2 * pi / 12;
      final pane = Path()
        ..moveTo(c.dx + cos(a0) * inner, c.dy + sin(a0) * inner)
        ..arcTo(
          Rect.fromCircle(center: c, radius: outer),
          a0,
          2 * pi / 12,
          false,
        )
        ..lineTo(
          c.dx + cos(a0 + 2 * pi / 12) * inner,
          c.dy + sin(a0 + 2 * pi / 12) * inner,
        )
        ..close();
      canvas.drawPath(
        pane,
        Paint()
          ..color = _wheelColour(
            k,
          ).withValues(alpha: solved || k == kRoseHue ? 0.9 : 0.35),
      );
      canvas.drawPath(
        pane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _keepVoid,
      );
    }
    // The step it was cut to read, ringed in gold.
    final ta = -pi / 2 + (kRoseHue + 0.5) * 2 * pi / 12;
    canvas.drawCircle(
      c + Offset(cos(ta), sin(ta)) * (outer + 6),
      4.5,
      Paint()..color = const Color(0xFFE4C16A),
    );
    // Where the light lands now.
    if (f.beamLive) {
      final ba = -pi / 2 + (f.beamHue + 0.5) * 2 * pi / 12;
      canvas.drawLine(
        c,
        c + Offset(cos(ba), sin(ba)) * (outer - 2),
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.95),
      );
    }
    canvas.drawCircle(c, inner - 3, Paint()..color = _keepStoneDim);
  }

  /// THE INDEX PLATE — a 3×3 diagram cut into every socket's frame. A sliding
  /// puzzle is unplayable if the player cannot see the board, and this planet
  /// deliberately never shows it from above; the plate is the board. It is
  /// the ONE grid allowed in Vitrea, and it is dressed as what it is: a brass
  /// plate screwed into a stone rebate, with the chambers as glass tokens.
  void _renderIndexPlate(Canvas canvas, int here) {
    const origin = Offset(20, 20);
    // 20, not 26: at full size and full saturation the plate was the loudest
    // thing in the room — a colour swatch card hung in the corner of a keep.
    // It has to be readable, not dominant.
    const pip = 20.0;
    final f = _keep;
    final board = Rect.fromLTWH(
      origin.dx - 8,
      origin.dy - 8,
      pip * 3 + 16,
      pip * 3 + 16,
    );
    canvas.drawRect(
      board.inflate(5),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.9),
    );
    canvas.drawRect(board, Paint()..color = _keepVoid.withValues(alpha: 0.7));
    canvas.drawRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _keepBrass.withValues(alpha: 0.3),
    );
    for (final c in [
      board.topLeft + const Offset(3.5, 3.5),
      board.topRight + const Offset(-3.5, 3.5),
      board.bottomLeft + const Offset(3.5, -3.5),
      board.bottomRight + const Offset(-3.5, -3.5),
    ]) {
      canvas.drawCircle(
        c,
        1.8,
        Paint()..color = _keepBrass.withValues(alpha: 0.5),
      );
    }
    for (var i = 0; i < 9; i++) {
      final r = Rect.fromLTWH(
        origin.dx + (i % 3) * pip,
        origin.dy + (i ~/ 3) * pip,
        pip - 3,
        pip - 3,
      );
      final ch = f.chamberAt(i);
      canvas.drawRect(
        r,
        Paint()
          ..color = ch == null
              ? _keepVoid
              : Color(ch.argb).withValues(alpha: 0.62),
      );
      if (ch != null) {
        canvas.drawLine(
          r.topLeft + const Offset(1.5, 1.5),
          r.topRight + const Offset(-1.5, 1.5),
          Paint()
            ..strokeWidth = 1.0
            ..color = Colors.white.withValues(alpha: 0.16),
        );
      }
      if (i == here) {
        canvas.drawRect(
          r.inflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.6),
        );
      }
    }
    // The berth, hanging off the east frame of the middle row.
    final berth = Rect.fromLTWH(
      origin.dx + 3 * pip + 3,
      origin.dy + pip,
      pip - 3,
      pip - 3,
    );
    canvas.drawLine(
      Offset(origin.dx + 3 * pip - 3, berth.center.dy),
      Offset(berth.left, berth.center.dy),
      Paint()
        ..strokeWidth = 1.4
        ..color = _keepBrass.withValues(alpha: 0.45),
    );
    canvas.drawRect(
      berth,
      Paint()
        ..color = f.facetStanding
            ? _keepVoid
            : Color(kPrismChambers[kWaitingFacet].argb).withValues(alpha: 0.5),
    );
  }

  // ── THE ORIEL ────────────────────────────────────────────

  /// A stone balcony hung under the keep's south face. The whole north end of
  /// the room IS the face — one unbroken sheet of glass in a dressed surround
  /// with the nine cells showing dim behind it, which makes the only overview
  /// in the game a thing you are looking THROUGH rather than a chart someone
  /// left lying about. The rest is a balcony: flagged, parapeted, with the
  /// bell-boss at the west end and glass swarf blown into the foot of the
  /// glass.
  void _renderOriel(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final g = _keepGroundFor<_KeepFloor>(
      'oriel:${b.width}x${b.height}',
      () => _buildOrielGround(b),
    );
    canvas.drawRect(
      b,
      Paint()..color = _keepStone.withValues(alpha: _keepFloorAlpha),
    );
    _renderDressedStone(canvas, g);

    // THE FACE. Stone jambs and a sill, and one sheet between them.
    final face = Rect.fromLTRB(
      b.left + 34,
      b.top + 6,
      b.right - 34,
      b.top + 172,
    );
    canvas.drawRect(face, Paint()..color = _keepVoid.withValues(alpha: 0.62));
    // The keep behind the glass — dim, because you are seeing it through a
    // sheet, and small, because it is the whole building.
    _renderKeepChart(canvas, Offset(face.right - 158, face.top + 14), 48);
    // THE SHEET ITSELF, laid OVER the keep. Drawn under it, the chart read as
    // nine bright swatches pinned to a wall; over it, the whole north end of
    // the room is one plane of glass with a building dimly inside it.
    canvas.drawRect(face, Paint()..color = _keepSheen.withValues(alpha: 0.09));
    canvas.drawRect(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _keepSheen.withValues(alpha: 0.2),
    );
    // Surround: a heavy sill along the bottom and two jambs, so the sheet is
    // set in masonry rather than floating on the floor.
    canvas.drawRect(
      Rect.fromLTRB(
        face.left - 16,
        face.bottom,
        face.right + 16,
        face.bottom + 16,
      ),
      Paint()..color = _keepStoneLit.withValues(alpha: 0.95),
    );
    for (final x in [face.left, face.right]) {
      canvas.drawRect(
        Rect.fromLTRB(x - 16, face.top - 6, x + 16, face.bottom + 16),
        Paint()..color = _keepStoneDim.withValues(alpha: 0.95),
      );
      canvas.drawLine(
        Offset(x - 15, face.top - 6),
        Offset(x - 15, face.bottom + 16),
        Paint()
          ..strokeWidth = 1.4
          ..color = _keepSheen.withValues(alpha: 0.12),
      );
    }

    // THE THRESHOLD. Unbroken, it is one more stretch of the same sheet with
    // only a faint scribed outline where the mason meant it to go; cracked,
    // it is a hole with the crazing running away from it into the rest of the
    // glass.
    final at = room.prism!.glassFace!;
    final pane = Rect.fromCenter(center: at, width: 240, height: 92);
    if (entryDoorRevealed) {
      canvas.drawRect(pane, Paint()..color = _keepVoid.withValues(alpha: 0.92));
      // CLIPPED TO THE SHEET. Unclipped, the crazing radiated straight off
      // the top of the screen and across the balcony floor — cracks running
      // through stone the lightning never touched.
      canvas.save();
      canvas.clipRect(face);
      final craze = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _keepSheen.withValues(alpha: 0.42);
      for (final p in g.cracks) {
        canvas.drawPath(p, craze);
      }
      canvas.restore();
      canvas.drawRect(
        pane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = _keepSheen.withValues(alpha: 0.55),
      );
    } else {
      canvas.drawRect(
        pane,
        Paint()..color = _keepSheen.withValues(alpha: 0.16),
      );
      canvas.drawRect(
        pane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _keepSheen.withValues(alpha: 0.3),
      );
      // A slow sheen crossing the sheet, so the one thing barring the way
      // reads as glass and not as a painted panel.
      final sx = face.left + (prism.clock * 54) % face.width;
      canvas.drawRect(
        Rect.fromLTRB(sx, face.top, sx + 26, face.bottom),
        Paint()..color = Colors.white.withValues(alpha: 0.045),
      );
    }

    // THE PARAPET. This is a balcony over a long drop; the detail belongs on
    // the rim, and the middle stays clear to walk and to be revived in.
    _renderParapet(canvas, g);
    _renderSwarf(canvas, g);
    _renderTuningBoss(canvas, room.prism!.annealRing!, 22);
  }

  /// A low parapet of dressed stone with turned balusters standing in it at
  /// uneven spacing (built once, from the room's own width).
  void _renderParapet(Canvas canvas, _KeepFloor g) {
    for (final p in g.props) {
      canvas.drawPath(p.path, Paint()..color = p.color);
    }
  }

  /// THE KEEP, SEEN THROUGH ITS OWN FACE — the only overview in the game.
  ///
  /// This was nine saturated swatches laid side by side, and from three feet
  /// away it read as a paint card someone had pinned to the wall. What it is
  /// meant to be is a BUILDING: a lit stone facade with nine glazed cells in
  /// it, one of them dark. So the stone piers between the cells are drawn
  /// heavy and lit, the cells are dimmer than the piers, and the sheet's own
  /// leading runs across the whole thing — which is what says you are looking
  /// at this through a window rather than at a diagram of it.
  void _renderKeepChart(Canvas canvas, Offset origin, double pip) {
    final f = _keep;
    final facade = Rect.fromLTWH(
      origin.dx - 9,
      origin.dy - 9,
      pip * 3 + 12,
      pip * 3 + 12,
    );
    canvas.drawRect(
      facade,
      Paint()..color = _keepStoneLit.withValues(alpha: 0.95),
    );
    canvas.drawRect(
      facade,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _keepStoneDim.withValues(alpha: 0.95),
    );
    for (var i = 0; i < 9; i++) {
      final r = Rect.fromLTWH(
        origin.dx + (i % 3) * pip,
        origin.dy + (i ~/ 3) * pip,
        pip - 9,
        pip - 9,
      );
      final ch = f.chamberAt(i);
      canvas.drawRect(
        r,
        Paint()
          ..color = ch == null
              ? _keepVoid
              : Color(ch.argb).withValues(alpha: 0.62),
      );
      // A reveal, so each cell is a hole in a thick wall.
      canvas.drawLine(
        r.topLeft,
        r.topRight,
        Paint()
          ..strokeWidth = 2.4
          ..color = _keepVoid.withValues(alpha: 0.5),
      );
      canvas.drawLine(
        r.bottomLeft + const Offset(0, -1),
        r.bottomRight + const Offset(0, -1),
        Paint()
          ..strokeWidth = 1.6
          ..color = _keepSheen.withValues(alpha: 0.16),
      );
    }
    // The berth, off the east frame, so the vault's one configuration is
    // visible from the balcony before the player has ever heard of it.
    final berth = Rect.fromLTWH(
      facade.right + 4,
      origin.dy + pip,
      pip - 12,
      pip - 9,
    );
    canvas.drawLine(
      Offset(facade.right, berth.center.dy),
      Offset(berth.left, berth.center.dy),
      Paint()
        ..strokeWidth = 2
        ..color = _keepIron.withValues(alpha: 0.9),
    );
    canvas.drawRect(
      berth,
      Paint()
        ..color = f.facetStanding
            ? _keepVoid
            : Color(kPrismChambers[kWaitingFacet].argb).withValues(alpha: 0.45),
    );
    // The sheet's leading, over the lot.
    final lead = Paint()
      ..strokeWidth = 2
      ..color = _keepSheen.withValues(alpha: 0.14);
    for (var i = 1; i < 3; i++) {
      final x = facade.left + facade.width * i / 3 + 7;
      canvas.drawLine(
        Offset(x, facade.top - 22),
        Offset(x, facade.bottom + 26),
        lead,
      );
    }
    canvas.drawLine(
      Offset(facade.left - 30, facade.center.dy + 11),
      Offset(berth.right + 14, facade.center.dy + 11),
      lead,
    );
  }

  // ── THE TUNING HALL ──────────────────────────────────────

  /// The room the keep is TUNED in — the frame's own ribs come down the east
  /// and west walls into the floor here, collared and turnbuckled, and the
  /// glaziers' rack and grinding bench stand under them. It was the emptiest
  /// room on the planet: a stone box with two circles and a crack in it.
  void _renderTuningHall(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final g = _keepGroundFor<_KeepFloor>(
      'hall:${b.width}x${b.height}',
      () => _buildTuningHallGround(b),
    );
    canvas.drawRect(
      b,
      Paint()..color = _keepStone.withValues(alpha: _keepFloorAlpha),
    );
    _renderDressedStone(canvas, g);

    // THE RIBS. Two of the keep's own frame members, brought down the side
    // walls to where they can be reached, with iron collars at uneven heights
    // and a turnbuckle on each. Edges only — the middle of the hall is where
    // the party works.
    for (final side in const [true, false]) {
      final x = side ? b.left + 44 : b.right - 44;
      canvas.drawRect(
        Rect.fromLTRB(x - 22, b.top + 10, x + 22, b.bottom - 10),
        Paint()..color = _keepStoneDim.withValues(alpha: 0.92),
      );
      canvas.drawLine(
        Offset(x - 21, b.top + 10),
        Offset(x - 21, b.bottom - 10),
        Paint()
          ..strokeWidth = 1.6
          ..color = _keepSheen.withValues(alpha: 0.13),
      );
      for (final t
          in side ? const [0.16, 0.44, 0.78] : const [0.24, 0.58, 0.86]) {
        final y = b.top + b.height * t;
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 52, height: 15),
          Paint()..color = _keepIron.withValues(alpha: 0.95),
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 20, height: 27),
          Paint()..color = _keepBrass.withValues(alpha: 0.45),
        );
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()..color = _keepStoneDim.withValues(alpha: 0.9),
        );
      }
    }

    // The glaziers' props: the hanging rack of graduated tuning bars and the
    // grinding bench, both built once and both against a wall.
    for (final p in g.props) {
      canvas.drawPath(p.path, Paint()..color = p.color);
    }

    // THE CRACK — the Pip gate. Three strokes on top of each other: a wide
    // soft shatter halo in the stone, the fissure itself, and the cold light
    // of the far side showing in the deepest part of it. Drawn as one
    // hairline it read as somebody's biro on the floor.
    for (final p in g.cracks) {
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeJoin = StrokeJoin.round
          ..color = _keepStoneDim.withValues(alpha: 0.75),
      );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round
          ..color = _keepVoid.withValues(alpha: 0.92),
      );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _keepSheen.withValues(alpha: 0.4),
      );
    }

    _renderFacetFont(canvas, room.prism!.facetFont!);
    _renderSwarf(canvas, g);
    _renderTuningBoss(canvas, room.prism!.annealRing!, 18);
  }

  /// THE FACET FONT — a basin on a fluted pedestal with a ground-glass brim,
  /// not a filled circle. When it holds the note, the note is drawn as
  /// concentric rings standing in the bowl.
  void _renderFacetFont(Canvas canvas, Offset at) {
    final live = (conduitEnergy['B'] ?? 0) > 0;
    canvas.drawRect(
      Rect.fromCenter(center: at + const Offset(0, 40), width: 86, height: 18),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.92),
    );
    // Pedestal, fluted: five shafts, so it has a round body rather than a
    // stick's silhouette.
    for (final dx in const [-22.0, -11.0, 0.0, 11.0, 22.0]) {
      canvas.drawRect(
        Rect.fromCenter(center: at + Offset(dx, 24), width: 10, height: 42),
        Paint()
          ..color = (dx.abs() < 6 ? _keepStoneLit : _keepStoneDim).withValues(
            alpha: 0.96,
          ),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 84, height: 40),
      Paint()..color = _keepStoneLit.withValues(alpha: 0.98),
    );
    // The bowl. A black interior made the whole font read as a ring lying on
    // a stick; it is a shallow dish with a lit far wall now.
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(0, 1), width: 62, height: 26),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.98),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(0, 3), width: 54, height: 20),
      Paint()
        ..color = (live ? _keepBrass : _keepSwarf).withValues(
          alpha: live ? 0.88 : 0.3,
        ),
    );
    canvas.drawArc(
      Rect.fromCenter(center: at + const Offset(0, 1), width: 62, height: 26),
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _keepSheen.withValues(alpha: 0.24),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 84, height: 40),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = _keepSheen.withValues(alpha: 0.45),
    );
    if (!live) return;
    final note = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 1; i <= 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 76.0 + i * 16, height: 36.0 + i * 8),
        note..color = _keepBrass.withValues(alpha: 0.26 - i * 0.06),
      );
    }
  }

  // ── PRISMALITH'S CHOIR ───────────────────────────────────

  /// The keep in miniature — nine plates and a gap — and therefore the room
  /// most at risk of being drawn as graph paper. It WAS: nine identical
  /// outlined rectangles on a flat wash, the most schematic picture in the
  /// game. Every plate is its own slab of ground glass now, cut and chipped
  /// and bedded differently from its neighbours, sitting over an open well;
  /// what the player reads at a glance is nine slabs hung over a drop, and
  /// the gap is a hole rather than a highlighted square. The middle stays
  /// bare, because a guardian is fought on it.
  void _renderChoirFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final floor = room.prism!.choir!;
    final g = _keepGroundFor<_KeepFloor>(
      'choir:${b.width}x${b.height}',
      () => _buildChoirGround(b, floor),
    );
    canvas.drawRect(
      b,
      Paint()..color = _keepVoid.withValues(alpha: _keepVoidAlpha),
    );
    // The choir's own rim: a ledge round the drop, and the stalls standing on
    // it — a ring of ground prisms of assorted height, which is the one place
    // in the room detail can go without getting in the fight's way.
    canvas.drawRect(
      Rect.fromLTRB(b.left, b.top, b.right, floor.plateRect(0).top - 4),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.75),
    );
    canvas.drawRect(
      Rect.fromLTRB(b.left, floor.plateRect(6).bottom + 4, b.right, b.bottom),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.75),
    );
    canvas.drawRect(
      Rect.fromLTRB(b.left, b.top, floor.plateRect(0).left - 4, b.bottom),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.75),
    );
    canvas.drawRect(
      Rect.fromLTRB(floor.plateRect(2).right + 4, b.top, b.right, b.bottom),
      Paint()..color = _keepStoneDim.withValues(alpha: 0.75),
    );
    for (final p in g.props) {
      canvas.drawPath(p.path, Paint()..color = p.color);
    }

    for (var i = 0; i < 9; i++) {
      if (i == prism.choirHollow) {
        _renderChoirWell(canvas, floor.plateRect(i).deflate(6));
        continue;
      }
      // NO TWO PLATES ARE THE SAME PLATE. The first pass deflated all nine by
      // the same six pixels, gave them one stone tone and outlined them, and
      // got nine identical tiles with lines scratched on them — graph paper
      // again, in the one room on the planet where a 3×3 is unavoidable. Each
      // slab now has its own seating depth, its own body tone, its own
      // leadwork, its own chipped corners and its own worn face, so what the
      // player reads is nine pieces of glass and not nine cells of a table.
      final seat = g.plateSeats[i];
      final r = floor.plateRect(i).deflate(seat.$1);
      // The well it hangs over, offset so the slab has real thickness and a
      // drop underneath it.
      canvas.drawRect(
        r.translate(seat.$2, seat.$3),
        Paint()..color = _keepVoid.withValues(alpha: 0.9),
      );
      canvas.drawRect(r, Paint()..color = g.plateTones[i]);
      // Its own leadwork.
      final came = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _keepVoid.withValues(alpha: 0.66);
      final glint = Paint()
        ..strokeWidth = 1.0
        ..color = _keepSheen.withValues(alpha: 0.16);
      for (final seg in g.plateCuts[i]) {
        canvas.drawLine(seg.$1, seg.$2, came);
        canvas.drawLine(
          seg.$1 + const Offset(1.5, 1.5),
          seg.$2 + const Offset(1.5, 1.5),
          glint,
        );
      }
      // Wear: where the choir has stood and where the floor has ground on
      // itself. Cheap, and it is what makes an old slab look old.
      for (final w in g.plateWear[i]) {
        canvas.drawPath(
          w,
          Paint()..color = _keepSwarf.withValues(alpha: 0.032),
        );
      }
      // The lead bed, on TWO sides only. A 4px stroke all the way round every
      // plate put a box outline on each of the nine, which is the exact
      // reading this room must not have; a plate is bedded heavily where it
      // bears and merely ground where it does not.
      final bed = Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.square
        ..color = _keepIron.withValues(alpha: 0.66);
      final arris = Paint()
        ..strokeWidth = 1.8
        ..color = _keepSheen.withValues(alpha: 0.24);
      if (i.isEven) {
        canvas.drawLine(r.topLeft, r.topRight, bed);
        canvas.drawLine(r.topLeft, r.bottomLeft, bed);
        canvas.drawLine(
          r.bottomLeft + const Offset(3, -2.5),
          r.bottomRight + const Offset(-3, -2.5),
          arris,
        );
        canvas.drawLine(
          r.topRight + const Offset(-2.5, 3),
          r.bottomRight + const Offset(-2.5, -3),
          arris,
        );
      } else {
        canvas.drawLine(r.bottomLeft, r.bottomRight, bed);
        canvas.drawLine(r.topRight, r.bottomRight, bed);
        canvas.drawLine(
          r.topLeft + const Offset(3, 2.5),
          r.topRight + const Offset(-3, 2.5),
          arris,
        );
        canvas.drawLine(
          r.topLeft + const Offset(2.5, 3),
          r.bottomLeft + const Offset(2.5, -3),
          arris,
        );
      }
      // Chipped corners — the damage a floor that shunts itself does to its
      // own edges.
      for (final c in g.plateChips[i]) {
        canvas.drawPath(c, Paint()..color = _keepVoid.withValues(alpha: 0.85));
      }
    }
    // The chips knocked off every plate edge by a floor that keeps shunting
    // itself, drawn over the whole floor so the damage is not per-plate.
    for (final p in g.shards) {
      canvas.drawPath(p, Paint()..color = _keepVoid.withValues(alpha: 0.55));
    }
    _renderTuningBoss(canvas, room.prism!.annealRing!, 16);
  }

  /// THE GAP. The mystic's root only shows through it, so it must read as a
  /// hole and not as a highlighted tile: the plate is gone, the bearers it
  /// sat on are bare, and the works are a long way down.
  void _renderChoirWell(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = _keepVoid);
    // PERSPECTIVE, NOT CONCENTRIC RINGS. The first attempt nested three
    // rectangles inside the gap and produced a bullseye — a target painted on
    // the floor, the exact failure the hollow socket upstairs already had.
    // Four walls converging on one off-centre floor read as a shaft.
    final far = Rect.fromCenter(
      center: r.center + const Offset(16, 22),
      width: r.width * 0.4,
      height: r.height * 0.36,
    );
    final wall = Paint();
    final corners = <(Offset, Offset, Offset, Offset, double)>[
      (r.topLeft, r.topRight, far.topRight, far.topLeft, 0.34),
      (r.bottomLeft, r.bottomRight, far.bottomRight, far.bottomLeft, 0.1),
      (r.topLeft, r.bottomLeft, far.bottomLeft, far.topLeft, 0.24),
      (r.topRight, r.bottomRight, far.bottomRight, far.topRight, 0.16),
    ];
    for (final c in corners) {
      canvas.drawPath(
        Path()
          ..moveTo(c.$1.dx, c.$1.dy)
          ..lineTo(c.$2.dx, c.$2.dy)
          ..lineTo(c.$3.dx, c.$3.dy)
          ..lineTo(c.$4.dx, c.$4.dy)
          ..close(),
        wall..color = _keepStoneDim.withValues(alpha: c.$5),
      );
    }
    canvas.drawRect(far, Paint()..color = _keepVoid);
    // The bearers the missing plate was sitting on, still spanning the hole.
    for (final t in const [0.32, 0.71]) {
      final y = r.top + r.height * t;
      canvas.drawRect(
        Rect.fromLTRB(r.left, y - 5, r.right, y + 5),
        Paint()..color = _keepIron.withValues(alpha: 0.62),
      );
      canvas.drawLine(
        Offset(r.left, y - 4),
        Offset(r.right, y - 4),
        Paint()
          ..strokeWidth = 1.4
          ..color = _keepSheen.withValues(alpha: 0.14),
      );
    }
    // The lead bed the plate was set in, left empty and catching the light.
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = _keepBrass.withValues(alpha: 0.55),
    );
  }

  // ── Static geometry, built once ──────────────────────────

  T _keepGroundFor<T extends _KeepGround>(String key, T Function() build) =>
      _keepGroundCache.putIfAbsent(key, build) as T;

  _KeepFloor _buildSocketBed(Rect b, int cell) {
    final rng = _KeepRng((b.width * 31 + b.height * 17).toInt() + cell * 977);
    final blocks = _dressedCourses(b, rng, minH: 52, maxH: 88);
    // Rail chairs at uneven spacing: real ones are set where the bed needs
    // them, not on a pitch.
    final chairs = <double>[];
    var y = 24.0;
    while (y < b.height - 20) {
      chairs.add(y);
      y += rng.range(48, 84);
    }
    // Wear scored along the runs. Short, thin, parallel to the direction of
    // travel and clustered where the slab actually bears.
    final scores = <Rect>[];
    for (final cy in _kChannelY) {
      for (var i = 0; i < 9; i++) {
        final x = rng.range(18, b.width - 70);
        scores.add(
          Rect.fromLTWH(x, cy + rng.range(-16, 16), rng.range(24, 62), 1.6),
        );
      }
    }
    for (final rx in _kRailX) {
      for (var i = 0; i < 7; i++) {
        final yy = rng.range(18, b.height - 60);
        scores.add(
          Rect.fromLTWH(rx + rng.range(-14, 14), yy, 1.6, rng.range(20, 54)),
        );
      }
    }
    // Swarf blown into the socket margin, and the shards that never got swept.
    final swarf = <Path>[];
    for (final c in [
      Offset(b.width * 0.08, b.height * 0.1),
      Offset(b.width * 0.93, b.height * 0.16),
      Offset(b.width * 0.12, b.height * 0.9),
      Offset(b.width * 0.86, b.height * 0.92),
    ]) {
      swarf.add(
        _blob(b.topLeft + c, rng.range(26, 54), rng.range(12, 26), rng),
      );
    }
    final shards = <Path>[];
    for (var i = 0; i < 10; i++) {
      shards.add(
        _shard(
          b.topLeft +
              Offset(rng.range(10, b.width - 10), rng.range(10, b.height - 10)),
          rng.range(3, 8),
          rng,
        ),
      );
    }
    // Wedges driven into the seam to stop the keep ringing. Irregular, and
    // never one per side.
    final shims = <Path>[];
    final seam = Rect.fromLTWH(26, 26, b.width - 52, b.height - 52);
    for (var i = 0; i < 6; i++) {
      final t = rng.next();
      final along = rng.next() < 0.5;
      final at = along
          ? Offset(
              seam.left + t * seam.width,
              rng.next() < 0.5 ? seam.top : seam.bottom,
            )
          : Offset(
              rng.next() < 0.5 ? seam.left : seam.right,
              seam.top + t * seam.height,
            );
      shims.add(
        Path()
          ..moveTo(at.dx - 7, at.dy - 4)
          ..lineTo(at.dx + 7, at.dy - 2)
          ..lineTo(at.dx + 6, at.dy + 4)
          ..lineTo(at.dx - 7, at.dy + 3)
          ..close(),
      );
    }
    return _KeepFloor(
      blocks: blocks,
      swarf: swarf,
      shards: shards,
      chairs: chairs,
      scores: scores,
      shims: shims,
    );
  }

  _KeepFloor _buildOrielGround(Rect b) {
    final rng = _KeepRng((b.width * 7 + b.height * 3).toInt() + 401);
    final blocks = _dressedCourses(b, rng, minH: 58, maxH: 96);
    final props = <_KeepProp>[];
    // THE PARAPET — a coping along the three open sides with balusters under
    // it at uneven spacing. The keep is above and behind; everything else out
    // there is a long way down.
    final coping = _keepStoneLit.withValues(alpha: 0.95);
    final shadow = _keepStoneDim.withValues(alpha: 0.95);
    props.add(
      _KeepProp(
        Path()..addRect(Rect.fromLTRB(b.left, b.bottom - 8, b.right, b.bottom)),
        shadow,
      ),
    );
    var x = b.left + rng.range(14, 30);
    while (x < b.right - 14) {
      final w = rng.range(8, 14);
      final h = rng.range(15, 22);
      final top = b.bottom - 26 - h;
      props.add(
        _KeepProp(
          Path()
            ..moveTo(x - 2, top + h)
            ..lineTo(x, top + h * 0.62)
            ..lineTo(x + w * 0.34, top + h * 0.4)
            ..lineTo(x + w * 0.34, top + h * 0.2)
            ..lineTo(x, top)
            ..lineTo(x + w, top)
            ..lineTo(x + w * 0.66, top + h * 0.2)
            ..lineTo(x + w * 0.66, top + h * 0.4)
            ..lineTo(x + w, top + h * 0.62)
            ..lineTo(x + w + 2, top + h)
            ..close(),
          _keepStoneLit.withValues(alpha: 0.75),
        ),
      );
      x += w + rng.range(11, 22);
    }
    // The coping goes on last, over the heads of the posts.
    props.add(
      _KeepProp(
        Path()..addRect(
          Rect.fromLTRB(b.left, b.bottom - 26, b.right, b.bottom - 16),
        ),
        coping,
      ),
    );
    props.add(
      _KeepProp(
        Path()..addRect(
          Rect.fromLTRB(b.left, b.bottom - 16, b.right, b.bottom - 12),
        ),
        shadow,
      ),
    );
    for (final side in const [true, false]) {
      final px = side ? b.left : b.right - 16;
      props.add(
        _KeepProp(
          Path()..addRect(Rect.fromLTWH(px, b.top + 190, 16, b.height - 214)),
          shadow,
        ),
      );
      var y = b.top + 206.0;
      while (y < b.bottom - 40) {
        props.add(
          _KeepProp(
            Path()..addRect(Rect.fromLTWH(px + 3, y, 10, rng.range(16, 30))),
            _keepSheen.withValues(alpha: 0.08),
          ),
        );
        y += rng.range(34, 58);
      }
    }
    // A shadow under the sighting bench, so the wall the shared renderer
    // draws is standing on this floor rather than hovering over it.
    props.add(
      _KeepProp(
        Path()..addRect(const Rect.fromLTWH(284, 216, 200, 12)),
        _keepVoid.withValues(alpha: 0.4),
      ),
    );
    // Swarf at the foot of the face — this is where the keep is ground.
    final swarf = <Path>[];
    for (var i = 0; i < 6; i++) {
      swarf.add(
        _blob(
          Offset(
            b.left + rng.range(60, b.width - 60),
            b.top + rng.range(186, 236),
          ),
          rng.range(30, 74),
          rng.range(9, 20),
          rng,
        ),
      );
    }
    final shards = <Path>[];
    for (var i = 0; i < 14; i++) {
      shards.add(
        _shard(
          Offset(
            b.left + rng.range(50, b.width - 50),
            b.top + rng.range(180, b.height - 40),
          ),
          rng.range(3, 9),
          rng,
        ),
      );
    }
    // The crazing, radiating from the threshold and running away into the
    // rest of the sheet — built once so the crack is the same crack forever.
    final cracks = <Path>[];
    const face = Offset(380, 70);
    for (var i = 0; i < 11; i++) {
      final a = rng.range(0, pi * 2);
      final p = Path()..moveTo(face.dx, face.dy);
      var at = face;
      var dir = a;
      for (var k = 0; k < 4; k++) {
        dir += rng.range(-0.5, 0.5);
        at += Offset(cos(dir), sin(dir)) * rng.range(22, 62);
        p.lineTo(at.dx, at.dy);
      }
      cracks.add(p);
    }
    return _KeepFloor(
      blocks: blocks,
      swarf: swarf,
      shards: shards,
      props: props,
      cracks: cracks,
    );
  }

  _KeepFloor _buildTuningHallGround(Rect b) {
    final rng = _KeepRng((b.width * 11 + b.height * 5).toInt() + 733);
    final blocks = _dressedCourses(b, rng, minH: 48, maxH: 82);
    final props = <_KeepProp>[];
    // THE RACK — graduated tuning bars hanging from a beam on the north-west
    // wall. Their lengths grade, which is what a tuned set looks like; their
    // spacing does not, which is what keeps it off the graph paper.
    const beamY = 44.0;
    props.add(
      _KeepProp(
        Path()..addRect(const Rect.fromLTWH(74, beamY - 7, 214, 12)),
        _keepIron.withValues(alpha: 0.95),
      ),
    );
    var x = 84.0;
    var n = 0;
    while (x < 280) {
      final len = 100.0 - n * 9 + rng.range(-6, 6);
      props.add(
        _KeepProp(
          Path()..addRect(Rect.fromLTWH(x, beamY + 5, 7, len)),
          _keepSheen.withValues(alpha: 0.16 + (n % 3) * 0.05),
        ),
      );
      props.add(
        _KeepProp(
          Path()..addRect(Rect.fromLTWH(x - 1, beamY + 5 + len, 9, 5)),
          _keepBrass.withValues(alpha: 0.4),
        ),
      );
      x += rng.range(17, 29);
      n++;
    }
    // THE GRINDING BENCH — north-east. A stone bed, the wheel on its spindle,
    // and the boxes of abrasive it is fed from.
    props.add(
      _KeepProp(
        Path()..addRect(const Rect.fromLTWH(372, 52, 204, 62)),
        _keepStoneLit.withValues(alpha: 0.95),
      ),
    );
    props.add(
      _KeepProp(
        Path()..addRect(const Rect.fromLTWH(372, 114, 204, 14)),
        _keepStoneDim.withValues(alpha: 0.95),
      ),
    );
    props.add(
      _KeepProp(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(428, 80), radius: 27)),
        _keepIron.withValues(alpha: 0.95),
      ),
    );
    props.add(
      _KeepProp(
        Path()
          ..addOval(Rect.fromCircle(center: const Offset(428, 80), radius: 9)),
        _keepBrass.withValues(alpha: 0.6),
      ),
    );
    for (var i = 0; i < 4; i++) {
      final bx = 478.0 + i * 24 + rng.range(-5, 5);
      props.add(
        _KeepProp(
          Path()..addRect(Rect.fromLTWH(bx, 60 + rng.range(0, 22), 19, 22)),
          _keepSwarf.withValues(alpha: 0.1 + (i % 2) * 0.05),
        ),
      );
    }
    // THE BLANKS. Uncut slabs leaning against the south-east wall, waiting to
    // be ground — of assorted height and lean, because a stack of glass in a
    // workshop is never stacked square. This corner was the last bare floor
    // in the hall.
    var bx = 424.0;
    while (bx < 592) {
      final h = rng.range(54, 96);
      final w = rng.range(15, 27);
      final lean = rng.range(-9, 9);
      props.add(
        _KeepProp(
          Path()
            ..moveTo(bx, 424)
            ..lineTo(bx + w, 424)
            ..lineTo(bx + w + lean, 424 - h)
            ..lineTo(bx + lean, 424 - h)
            ..close(),
          _keepSheen.withValues(alpha: 0.07 + rng.next() * 0.09),
        ),
      );
      props.add(
        _KeepProp(
          Path()
            ..moveTo(bx + lean, 424 - h)
            ..lineTo(bx + w + lean, 424 - h)
            ..lineTo(bx + w + lean * 1.3, 425 - h - 4)
            ..lineTo(bx + lean * 1.3, 425 - h - 4)
            ..close(),
          _keepSwarf.withValues(alpha: 0.16),
        ),
      );
      bx += w + rng.range(4, 16);
    }
    // Wedges and shims scattered on the bench's floor — the glaziers' litter.
    for (var i = 0; i < 9; i++) {
      final at = Offset(rng.range(340, 600), rng.range(140, 210));
      props.add(
        _KeepProp(
          Path()
            ..moveTo(at.dx, at.dy)
            ..lineTo(at.dx + rng.range(9, 17), at.dy + rng.range(-3, 3))
            ..lineTo(at.dx + rng.range(6, 12), at.dy + rng.range(4, 8))
            ..close(),
          _keepBrass.withValues(alpha: 0.3),
        ),
      );
    }
    // THE CRACK. It runs out of the west wall, through the floor, and ENDS ON
    // THE CONDUIT — the walk was originally free to wander off wherever the
    // die sent it, which left the one gap in the fabric that a Pip can slip
    // and the fissure that is supposed to be it in two different places.
    // Every branch is now walked toward the conduit and lands on it.
    const target = Offset(200, 250);
    final cracks = <Path>[];
    for (var i = 0; i < 3; i++) {
      final from = Offset(b.left + rng.range(0, 18), 250 + rng.range(-58, 58));
      final p = Path()..moveTo(from.dx, from.dy);
      const steps = 6;
      for (var k = 1; k <= steps; k++) {
        final t = k / steps;
        final on = Offset(
          from.dx + (target.dx - from.dx) * t,
          from.dy + (target.dy - from.dy) * t,
        );
        // Jitter dies away to nothing as the branch closes on the conduit.
        final j = (1 - t) * 22;
        p.lineTo(on.dx + rng.range(-j, j), on.dy + rng.range(-j, j));
      }
      cracks.add(p);
    }
    final swarf = <Path>[];
    for (var i = 0; i < 5; i++) {
      swarf.add(
        _blob(
          Offset(rng.range(360, 600), rng.range(120, 190)),
          rng.range(26, 58),
          rng.range(10, 22),
          rng,
        ),
      );
    }
    final shards = <Path>[];
    for (var i = 0; i < 16; i++) {
      shards.add(
        _shard(
          Offset(rng.range(30, b.width - 30), rng.range(30, b.height - 30)),
          rng.range(3, 8),
          rng,
        ),
      );
    }
    return _KeepFloor(
      blocks: blocks,
      swarf: swarf,
      shards: shards,
      props: props,
      cracks: cracks,
    );
  }

  _KeepFloor _buildChoirGround(Rect b, ChoirFloor floor) {
    final rng = _KeepRng((b.width * 3 + b.height * 13).toInt() + 191);
    // THE STALLS — standing prisms round the rim of the drop, of assorted
    // height and lean. A choir is a ring of things that sing; nine of them
    // would have been another 3×3, so there are as many as the rim holds and
    // no two are the same size.
    final props = <_KeepProp>[];
    final inner = Rect.fromLTRB(
      floor.plateRect(0).left - 4,
      floor.plateRect(0).top - 4,
      floor.plateRect(2).right + 4,
      floor.plateRect(6).bottom + 4,
    );
    void stall(Offset foot, double h, double w, double lean) {
      props.add(
        _KeepProp(
          Path()
            ..moveTo(foot.dx - w / 2, foot.dy)
            ..lineTo(foot.dx - w / 2 + lean, foot.dy - h)
            ..lineTo(foot.dx + w / 2 + lean, foot.dy - h)
            ..lineTo(foot.dx + w / 2, foot.dy)
            ..close(),
          _keepSheen.withValues(alpha: 0.07 + rng.next() * 0.1),
        ),
      );
      props.add(
        _KeepProp(
          Path()
            ..moveTo(foot.dx - w / 2 + lean, foot.dy - h)
            ..lineTo(foot.dx + w / 2 + lean, foot.dy - h)
            ..lineTo(foot.dx + w / 2 + lean * 1.4, foot.dy - h - 5)
            ..close(),
          _keepBrass.withValues(alpha: 0.22),
        ),
      );
    }

    var x = b.left + 12;
    while (x < b.right - 16) {
      stall(
        Offset(x, inner.top - 2),
        rng.range(16, 46),
        rng.range(9, 20),
        rng.range(-3, 3),
      );
      x += rng.range(26, 52);
    }
    x = b.left + 20;
    while (x < b.right - 16) {
      stall(
        Offset(x, b.bottom - 4),
        rng.range(14, 38),
        rng.range(8, 18),
        rng.range(-3, 3),
      );
      x += rng.range(30, 60);
    }
    for (final side in const [true, false]) {
      var y = inner.top + 30;
      while (y < inner.bottom) {
        final sx = side ? b.left + 24 : b.right - 24;
        stall(
          Offset(sx, y),
          rng.range(18, 44),
          rng.range(9, 19),
          rng.range(-3, 3),
        );
        y += rng.range(52, 96);
      }
    }
    // Per-plate everything. Seating depth, body tone, leadwork, chipped
    // corners and worn patches are all rolled from the plate's own index, so
    // the floor is nine different pieces of glass rather than nine copies of
    // one — which is the only defence this room has against reading as the
    // diagram of its own mechanic.
    final plateCuts = <List<(Offset, Offset)>>[];
    final plateSeats = <(double, double, double)>[];
    final plateTones = <Color>[];
    final plateChips = <List<Path>>[];
    final plateWear = <List<Path>>[];
    for (var i = 0; i < 9; i++) {
      final pr = _KeepRng(9001 + i * 613);
      final inset = 5.0 + pr.range(0, 5);
      plateSeats.add((inset, pr.range(2, 7), pr.range(4, 10)));
      plateTones.add(
        Color.lerp(
          _keepStoneDim,
          _keepStoneLit,
          pr.next(),
        )!.withValues(alpha: 0.78 + pr.next() * 0.2),
      );
      final r = floor.plateRect(i).deflate(inset);
      final cuts = <(Offset, Offset)>[];
      final n = 2 + pr.i(3);
      for (var k = 0; k < n; k++) {
        final a = pr.range(0, pi);
        final c = Offset(
          r.left + pr.range(0.2, 0.8) * r.width,
          r.top + pr.range(0.2, 0.8) * r.height,
        );
        final d = Offset(cos(a), sin(a)) * (r.width + r.height);
        final seg = _clipSegment(r, c - d, c + d);
        if (seg != null) cuts.add(seg);
      }
      plateCuts.add(cuts);
      // Chips: two or three corners of each plate, never all four.
      final chips = <Path>[];
      final corners = [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight];
      for (var k = 0; k < 2 + pr.i(2); k++) {
        final c = corners[pr.i(4)];
        final sx = c.dx == r.left ? 1.0 : -1.0;
        final sy = c.dy == r.top ? 1.0 : -1.0;
        final w = pr.range(9, 26);
        chips.add(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(c.dx + sx * w, c.dy + sy * pr.range(2, 7))
            ..lineTo(c.dx + sx * pr.range(2, 7), c.dy + sy * w * 0.7)
            ..close(),
        );
      }
      plateChips.add(chips);
      final wear = <Path>[];
      for (var k = 0; k < 2 + pr.i(3); k++) {
        wear.add(
          _blob(
            Offset(
              r.left + pr.range(0.15, 0.85) * r.width,
              r.top + pr.range(0.15, 0.85) * r.height,
            ),
            pr.range(18, 52),
            pr.range(10, 30),
            pr,
          ),
        );
      }
      plateWear.add(wear);
    }
    // The chips a floor that keeps shunting itself knocks off its own edges.
    final shards = <Path>[];
    for (var i = 0; i < 26; i++) {
      shards.add(
        _shard(
          Offset(
            rng.range(inner.left, inner.right),
            rng.range(inner.top, inner.bottom),
          ),
          rng.range(3, 9),
          rng,
        ),
      );
    }
    return _KeepFloor(
      blocks: const [],
      shards: shards,
      props: props,
      plateCuts: plateCuts,
      plateSeats: plateSeats,
      plateTones: plateTones,
      plateChips: plateChips,
      plateWear: plateWear,
    );
  }

  /// Dressed courses covering [b]. Courses are of unequal height, every
  /// course starts off the left edge by a different amount and the blocks in
  /// it are of unequal width — which is the whole difference between masonry
  /// and graph paper, and the fault this planet is most prone to.
  List<_KeepBlock> _dressedCourses(
    Rect b,
    _KeepRng rng, {
    required double minH,
    required double maxH,
  }) {
    final out = <_KeepBlock>[];
    var y = b.top;
    while (y < b.bottom - 1) {
      final h = min(rng.range(minH, maxH), b.bottom - y);
      var x = b.left - rng.range(10, 110);
      while (x < b.right) {
        final w = rng.range(52, 138);
        final r = Rect.fromLTRB(max(x, b.left), y, min(x + w, b.right), y + h);
        if (r.width > 7) {
          out.add(
            _KeepBlock(
              r,
              Color.lerp(
                _keepStoneDim,
                _keepStoneLit,
                rng.next(),
              )!.withValues(alpha: 0.42),
            ),
          );
        }
        x += w;
      }
      y += h;
    }
    return out;
  }

  /// A chamber's leadwork, as a WINDOW rather than a shattered sheet
  /// (docs/dungeons.md §7.11). Five free cuts ran long black lines across
  /// every slab and read as cracks; the chamber is now glazed the way a
  /// glazier would: a border of its own colour in quarries round the edge,
  /// a faint diamond lattice over the middle you can see the bed through, and
  /// a medallion at the heart whose petal count is the chamber's own — so
  /// colour AND shape say which of the eight has arrived. Cached per chamber
  /// id, never per cell.
  _KeepGlass _buildChamberGlass(Rect slab, PrismChamber chamber) {
    final glass = Color(chamber.argb);
    final rng = _KeepRng(_keepHash(chamber.id));
    final panes = <Path>[];
    final paneColours = <Color>[];
    final arrises = <(Offset, Offset)>[];
    const band = 22.0;
    final inner = slab.deflate(band);

    // THE BORDER: quarries of the chamber's colour, the strongest glass on it.
    void quarry(Rect q) {
      panes.add(Path()..addRect(q));
      paneColours.add(
        Color.lerp(
          glass,
          _keepSheen,
          rng.next() * 0.25,
        )!.withValues(alpha: 0.34 + rng.next() * 0.14),
      );
      final c = q.center;
      final len = min(q.width, q.height) * 0.28;
      arrises.add((c + Offset(-len, -len * 0.52), c + Offset(len, len * 0.52)));
    }

    final nx = max(3, (slab.width / 64).round());
    for (var k = 0; k < nx; k++) {
      final x0 = slab.left + slab.width * k / nx;
      final x1 = slab.left + slab.width * (k + 1) / nx;
      quarry(Rect.fromLTRB(x0, slab.top, x1, inner.top));
      quarry(Rect.fromLTRB(x0, inner.bottom, x1, slab.bottom));
    }
    final ny = max(2, (inner.height / 64).round());
    for (var k = 0; k < ny; k++) {
      final y0 = inner.top + inner.height * k / ny;
      final y1 = inner.top + inner.height * (k + 1) / ny;
      quarry(Rect.fromLTRB(slab.left, y0, inner.left, y1));
      quarry(Rect.fromLTRB(inner.right, y0, slab.right, y1));
    }

    // THE LATTICE: diamond quarries over the middle, thin and pale — the
    // machinery underneath is meant to show through (§ the alphas note).
    final latticeFrom = panes.length;
    final field = Path()..addRect(inner);
    const hx = 34.0, hy = 26.0;
    var row = 0;
    for (var y = inner.top; y < inner.bottom + hy; y += hy, row++) {
      for (
        var x = inner.left + (row.isOdd ? hx : 0);
        x < inner.right + hx;
        x += hx * 2
      ) {
        final d = Path()
          ..moveTo(x, y - hy)
          ..lineTo(x + hx, y)
          ..lineTo(x, y + hy)
          ..lineTo(x - hx, y)
          ..close();
        final cut = Path.combine(PathOperation.intersect, d, field);
        if (cut.getBounds().isEmpty) continue;
        panes.add(cut);
        paneColours.add(
          Color.lerp(
            glass,
            _keepSheen,
            0.45 + rng.next() * 0.2,
          )!.withValues(alpha: 0.05 + rng.next() * 0.07),
        );
      }
    }

    final latticeTo = panes.length;

    // THE MEDALLION: the chamber's mark, in its full colour.
    final c = inner.center;
    final n = _kChamberPetals[chamber.id] ?? 6;
    for (var k = 0; k < n; k++) {
      final a0 = -pi / 2 + k * 2 * pi / n;
      panes.add(sectorPath(c, 16, 50, a0, a0 + 2 * pi / n));
      paneColours.add(
        Color.lerp(
          glass,
          _keepSheen,
          k.isEven ? 0.05 : 0.22,
        )!.withValues(alpha: 0.58),
      );
    }
    panes.add(Path()..addOval(Rect.fromCircle(center: c, radius: 16)));
    paneColours.add(_keepSheen.withValues(alpha: 0.42));

    // Chips out of the slab's corners.
    final chips = <Path>[];
    for (final c in [
      slab.topLeft,
      slab.topRight,
      slab.bottomLeft,
      slab.bottomRight,
    ]) {
      final s = rng.range(7, 18);
      chips.add(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + (c.dx == slab.left ? s : -s),
            c.dy + (c.dy == slab.top ? s * 0.4 : -s * 0.4),
          )
          ..lineTo(
            c.dx + (c.dx == slab.left ? s * 0.4 : -s * 0.4),
            c.dy + (c.dy == slab.top ? s : -s),
          )
          ..close(),
      );
    }
    return _KeepGlass(
      panes: panes,
      paneColours: paneColours,
      arrises: arrises,
      chips: chips,
      latticeFrom: latticeFrom,
      latticeTo: latticeTo,
      // A ground edge is always lighter than the body it was cut out of, so
      // the jambs and the rim bevel are the chamber's own colour lifted.
      jamb: Color.lerp(glass, _keepSheen, 0.34)!,
      bevel: Color.lerp(glass, _keepSheen, 0.22)!.withValues(alpha: 0.34),
    );
  }

  Path _blob(Offset at, double rx, double ry, _KeepRng rng) {
    final p = Path();
    for (var i = 0; i < 9; i++) {
      final a = i * pi * 2 / 9;
      final k = 0.65 + rng.next() * 0.55;
      final v = at + Offset(cos(a) * rx * k, sin(a) * ry * k);
      if (i == 0) {
        p.moveTo(v.dx, v.dy);
      } else {
        p.lineTo(v.dx, v.dy);
      }
    }
    return p..close();
  }

  Path _shard(Offset at, double s, _KeepRng rng) {
    final a = rng.range(0, pi * 2);
    return Path()
      ..moveTo(at.dx + cos(a) * s, at.dy + sin(a) * s)
      ..lineTo(at.dx + cos(a + 2.2) * s * 0.8, at.dy + sin(a + 2.2) * s * 0.8)
      ..lineTo(at.dx + cos(a + 4.1) * s * 1.2, at.dy + sin(a + 4.1) * s * 1.2)
      ..close();
  }
}

// ─────────────────────────────────────────────────────────
// STATIC GEOMETRY — BUILT ONCE, KEPT FOREVER
// ─────────────────────────────────────────────────────────
// Every stone course, drift of swarf, rail chair, wedge, stall, crack and
// leaded pane in Vitrea is derived deterministically from its room's own
// bounds and built the first time that room is drawn. Nothing in here is
// re-rolled per frame: this planet renders at 60fps on a phone, and the only
// things allowed to move are a beam glint and a sheen crossing the face.

final Map<String, _KeepGround> _keepGroundCache = {};

/// Each chamber's glass, baked (§7.11).
final Map<String, ui.Picture> _chamberGlassCache = {};

/// A chamber's medallion petal count: its mark, alongside its colour.
const Map<String, int> _kChamberPetals = {
  'hearth': 8,
  'cinnabar': 3,
  'beryl': 4,
  'lazuli': 5,
  'citrine': 6,
  'selenite': 7,
  'amethyst': 9,
  'onyx': 10,
  'waiting': 12,
};

abstract class _KeepGround {}

class _KeepBlock {
  final Rect r;
  final Color color;
  const _KeepBlock(this.r, this.color);
}

class _KeepProp {
  final Path path;
  final Color color;
  const _KeepProp(this.path, this.color);
}

class _KeepFloor extends _KeepGround {
  final List<_KeepBlock> blocks;
  final List<Path> swarf;
  final List<Path> shards;
  final List<double> chairs;
  final List<Rect> scores;
  final List<Path> shims;
  final List<_KeepProp> props;
  final List<Path> cracks;
  final List<List<(Offset, Offset)>> plateCuts;

  /// Per choir plate: how far it is seated in, and how far its well is offset.
  final List<(double, double, double)> plateSeats;
  final List<Color> plateTones;
  final List<List<Path>> plateChips;
  final List<List<Path>> plateWear;

  _KeepFloor({
    required this.blocks,
    this.swarf = const [],
    this.shards = const [],
    this.chairs = const [],
    this.scores = const [],
    this.shims = const [],
    this.props = const [],
    this.cracks = const [],
    this.plateCuts = const [],
    this.plateSeats = const [],
    this.plateTones = const [],
    this.plateChips = const [],
    this.plateWear = const [],
  });
}

class _KeepGlass extends _KeepGround {
  final List<Path> panes;

  /// Fully resolved per-pane colours — the render loop allocates nothing.
  final List<Color> paneColours;
  final List<(Offset, Offset)> arrises;
  final List<Path> chips;

  /// The chamber's colour lifted toward the sheen: what a ground edge looks
  /// like, and the only thing that lets the Black Cell show a doorway.
  final Color jamb;
  final Color bevel;

  /// The lattice's panes, [latticeFrom] up to [latticeTo] — glazed light.
  final int latticeFrom;
  final int latticeTo;

  _KeepGlass({
    required this.panes,
    required this.paneColours,
    required this.arrises,
    required this.chips,
    required this.latticeFrom,
    required this.latticeTo,
    required this.jamb,
    required this.bevel,
  });
}

/// A tiny LCG. Deterministic from a seed and nothing else, so a room looks
/// the same on every machine, in every run, and in the render audit.
class _KeepRng {
  int _s;
  _KeepRng(int seed) : _s = (seed & 0x7fffffff) | 1;

  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }

  double range(double a, double b) => a + next() * (b - a);
  int i(int n) => (next() * n).floor() % n;
}

int _keepHash(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h = ((h ^ s.codeUnitAt(i)) * 16777619) & 0x7fffffff;
  }
  return h;
}

/// Clip the segment [a]–[b] to [r], or null when it misses. Used to lay a
/// free-angle came across a plate without it running off the glass.
(Offset, Offset)? _clipSegment(Rect r, Offset a, Offset b) {
  var t0 = 0.0;
  var t1 = 1.0;
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  for (var side = 0; side < 4; side++) {
    final double p;
    final double q;
    switch (side) {
      case 0:
        p = -dx;
        q = a.dx - r.left;
      case 1:
        p = dx;
        q = r.right - a.dx;
      case 2:
        p = -dy;
        q = a.dy - r.top;
      default:
        p = dy;
        q = r.bottom - a.dy;
    }
    if (p == 0) {
      if (q < 0) return null;
      continue;
    }
    final t = q / p;
    if (p < 0) {
      if (t > t1) return null;
      if (t > t0) t0 = t;
    } else {
      if (t < t0) return null;
      if (t < t1) t1 = t;
    }
  }
  return (
    Offset(a.dx + dx * t0, a.dy + dy * t0),
    Offset(a.dx + dx * t1, a.dy + dy * t1),
  );
}
