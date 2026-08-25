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
//  • Lost Maxim — KNOW THYSELF: stand all three bodies inside the split the
//    Shard Hearth throws when it is standing in the lit row.
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
// THE ANNEAL is the one valve, and it is here for a narrow reason: a chamber
// whose facets happen to face nothing walkable, with the hollow out of reach,
// and Prismalith's beats moving the keep while you are downstairs in the
// choir. A Crystal hand on any tuning boss rings the keep back to its opening
// arrangement. A do-over, never a shortcut.

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

  void reset() {
    field.reset();
    clock = 0;
    shear = 0;
    shearFrom = Offset.zero;
    choirHollow = 8;
    bitLastFrame = false;
  }
}

extension PrismLabyrinthKeep on PlanetDungeonGame {
  PrismKeepField get _keep => prism.field;

  /// The oriel's declaration of the two non-guardian stars.
  PrismKeep? get _keepStars =>
      layout.rooms[layout.entranceRoomId]?.prism?.keep;

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
    _checkKnowThyself(room);
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

  /// THE LOST MAXIM (§6 easter eggs #11) — KNOW THYSELF. The Shard Hearth is
  /// the only chamber that SPLITS a beam rather than merely bending it, so the
  /// split exists in exactly the arrangements Star 0 forbids. Stand all three
  /// bodies in it at once and the keep throws back three shapes. No hint
  /// anywhere teaches this.
  void _checkKnowThyself(DungeonRoom room) {
    if (discoveredClouds.contains(kCrystalKnowThyselfEgg)) return;
    final cell = _cellOf(room);
    if (cell == null || !kKeepBeamRow.contains(cell)) return;
    final f = _keep;
    if (!f.beamLive) return;
    if (f.chamberAt(cell)?.id != 'hearth') return;
    final live = creatures.where((c) => c.alive).toList();
    if (live.length < 3) return;
    for (final c in live) {
      if (!kBeamBand.contains(c.position)) return;
    }
    _discoverCloud(kCrystalKnowThyselfEgg);
    _setHint(kCrystalKnowThyselfMaxim, 7.0);
    _spawnAlchemyBurst(
      kChamberHeart,
      producedElement: 'Light',
      reagentElements: const ['Crystal', 'Spirit'],
      particleCount: 42,
      intensity: 1.5,
    );
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
      _setHint('Prismalith rings — the floor goes over, and the keep with it');
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
    // are cut in the keep's own stone, so they ask only that something stands
    // there to be walked onto.
    final frameCell = from ?? to;
    if (frameCell == null) return false;
    return !f.frameArchOpen(frameCell);
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How the keep is moved is the planet's earned reading (Mask).
  String _keepDoorHint(DungeonRoom room, DungeonDoor door) {
    final f = _keep;
    final from = _cellOf(room);
    final to = layout.rooms[door.targetRoomId]?.prism?.cell?.index;
    if (from != null && to != null) {
      if (f.chamberAt(to) == null) {
        return 'The arch opens on the hollow — nothing to step onto';
      }
      return 'The glass does not meet here';
    }
    return 'The keep stands empty on this arch';
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
        _tryShunt(a);
  }

  /// The entry rite: the keep's south face is one unbroken sheet, and
  /// Lightning is the only thing in the party that cracks glass.
  bool _tryGlassFace(DungeonCreature a) {
    final face = currentRoom.prism?.glassFace;
    if (face == null || entryDoorRevealed) return false;
    if ((a.position - face).distance > _kKeepReach) return false;
    if (a.member.element != 'Lightning') {
      _setBlockedHint('Only Lightning cracks this sheet');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The face crazes open — a threshold, and a keep behind it');
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
      _setBlockedHint('The lamp is already burning');
      return true;
    }
    final direct = a.member.element == 'Light';
    final braid = _keepBraidReady(a);
    if (!direct && !braid) {
      _setBlockedHint('The lamp answers only Light');
      return true;
    }
    f.lampLit = true;
    _setHint('The lamp takes — and a light lies down the middle of the keep');
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
      _setBlockedHint('The font answers Crystal alone');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The font refuses the offering — it answers only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
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
      _setBlockedHint('The chain answers only Crystal');
      return true;
    }
    if (f.facetStanding) {
      if (!f.withdrawFacet(cell)) return true;
      _setHint('The facet slides out, and the hollow comes back in');
      _spawnAlchemyBurst(
        kBerthChain,
        producedElement: 'Crystal',
        particleCount: 18,
        intensity: 0.8,
      );
      return true;
    }
    if (!f.canCallFacet(cell)) {
      _setBlockedHint('The chain is slack — the berth has nowhere to send it');
      return true;
    }
    f.callFacet(cell);
    _setHint(
      'Something comes in out of the east wall — and the keep sets solid',
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
    final pos = cell != null
        ? kCellTuningBoss
        : currentRoom.prism?.annealRing;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kKeepReach) return false;
    if (a.member.element != 'Crystal') {
      _setBlockedHint('Only Crystal rings this boss');
      return true;
    }
    final f = _keep;
    if (cell == null && !f.hollowBerthed && _keepAtOpening) {
      _setBlockedHint('The keep already stands as it opened');
      return true;
    }
    final landed = f.anneal(cell ?? -1);
    if (cell != null) currentRoomId = kKeepCellRooms[landed];
    prism.shear = _kKeepShearSeconds;
    prism.shearFrom = Offset.zero;
    _clearHints();
    _setHint(
      'The whole keep rings back to true — and every slide you made is gone',
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
    if (!keepNeighbours(prism.choirHollow).contains(standing)) return false;
    _slideChoirPlate(standing);
    _spawnAlchemyBurst(
      a.position,
      producedElement: 'Crystal',
      particleCount: 14,
      intensity: 0.7,
    );
    return true;
  }

  /// THE SHUNT — the planet's only verb, and its whole grammar. A Crystal hand
  /// on the shove-plate facing the hollow pushes THIS chamber that way and
  /// rides it: the screen slides and your feet do not move on the floor.
  bool _tryShunt(DungeonCreature a) {
    final cell = _cellOf(currentRoom);
    if (cell == null) return false;
    final f = _keep;
    for (final facet in const [kFacetN, kFacetE, kFacetS, kFacetW]) {
      final target = keepNeighbourToward(cell, facet);
      if (target < 0) continue; // an outer wall carries no plate
      if ((a.position - keepPlateFor(facet)).distance > _kKeepReach) continue;
      if (a.member.element != 'Crystal') {
        _setBlockedHint('Only Crystal moves this glass');
        return true;
      }
      if (f.facetStanding) {
        _setBlockedHint('The keep is full — nothing has anywhere to go');
        return true;
      }
      if (f.hollowCell != target) {
        _setBlockedHint('Glass on glass — there is nothing to give');
        return true;
      }
      _rideShunt(cell, target, facet);
      return true;
    }
    return false;
  }

  /// The ride itself.
  void _rideShunt(int from, int target, int facet) {
    final f = _keep;
    final landed = f.shunt(from);
    if (landed < 0) return;
    currentRoomId = kKeepCellRooms[landed];
    prism.shear = _kKeepShearSeconds;
    prism.shearFrom = switch (facet) {
      kFacetN => const Offset(0, 1),
      kFacetS => const Offset(0, -1),
      kFacetE => const Offset(-1, 0),
      _ => const Offset(1, 0),
    };
    _clearHints();
    _setHint('The chamber goes over — and takes you with it', 2.2);
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
    if (target < 0 || _keep.hollowCell != target) return false;
    _rideShunt(cell, target, facet);
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
      return DungeonProgressReadout(
        label: 'SHUNTS',
        value: '${f.shunts}',
      );
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
          ? 'The keep stands above you, and it does not stand still'
          : 'The keep\'s face is one unbroken sheet';
    }
    if (room.prism?.facetFont != null) {
      return 'The tuning hall waits on a crack and a font';
    }
    if (room.guardian != null) {
      return 'Prismalith stands on a floor with a piece missing';
    }
    final cell = _cellOf(room);
    if (cell == null) return null;
    final chamber = f.chamberAt(cell);
    if (chamber == null) return null;
    if (chamber.id == 'waiting') return 'Something was kept in here';
    if (chamber.id == 'hearth' && !f.hearthKindled) {
      return 'The hearth\'s shard is stone cold';
    }
    if (cell == kKeepBeamRow.first && !f.lampLit) {
      return 'The west lamp is out, and the rose has nothing to read';
    }
    if (chamber.throne) return '${chamber.name} sits unserved';
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
        0 => 'It is standing on something it does not want moved',
        1 => 'Nothing reaches it through glass — only through the gap',
        _ => 'Bring the gap under it and strike; it will ring the floor out '
            'from under itself every time you land one',
      });
      return;
    }
    if (room.prism?.facetFont != null) {
      _setInsightHint(switch (tier) {
        0 => 'Two notes, and the hall wants both',
        1 => 'One is a crack too fine for a hand; the other is a font',
        _ => 'The crack takes only the smallest body in your party; the font '
            'answers any Crystal, once both stars are yours',
      });
      return;
    }
    final cell = _cellOf(room);
    if (cell != null && kKeepBeamRow.contains(cell)) {
      _setInsightHint(switch (tier) {
        0 => 'The rose was cut for one colour and it is not this one',
        1 => 'A light only crosses glass that is cut on BOTH the west and the '
            'east — and each one it crosses bends it further round',
        _ => 'Five of the eight let a light through, and their bends add: '
            'the rose reads $kRoseHue, and exactly one set of three makes it. '
            'The hearth is not in that set',
      });
      return;
    }
    if (cell != null && f.chamberAt(cell)?.id == 'hearth') {
      _setInsightHint(switch (tier) {
        0 => 'The thrones were cut to face a hearth',
        1 => 'All three at once, and only the middle cell has faces enough',
        _ => 'Put the hearth in the middle and bring the crimson, the verdant '
            'and the azure onto three open faces of it — and note what that '
            'costs the rose',
      });
      return;
    }
    // Anywhere in the keep, insight reads the RULE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'The keep is nine sockets and eight rooms. One socket is empty',
      1 => 'A room only goes where the hollow is, and it takes you with it. '
          'A doorway is only a doorway when the glass on both sides agrees',
      _ => 'Every slide is undone by sliding back, so nothing here is lost — '
          'but half of all the ways these rooms could lie, they never will. '
          'The frame rings back to true from any boss, at the price of every '
          'slide you made',
    });
  }

  double get _keepMoodTarget {
    if (currentRoom.guardian != null) return 0.22;
    if (_cellOf(currentRoom) != null) return _keep.beamLive ? 0.66 : 0.46;
    return 0.52;
  }

  // ── Rendering (§5.5 visual grammar) ──────────────────────
  // Nothing here may read like Water's tide regating: no level, no gauge, no
  // dissolve, no water. A chamber is a slab of coloured glass in a stone
  // socket; a slide is a HARD TRANSLATION with a bright shear at its leading
  // edge; and the keep's whole state is legible from an index plate cut into
  // every cell's frame. No MaskFilter.blur anywhere (the game's known jank
  // source) — everything is flat fills, strokes and one gradient-free glow
  // built from concentric strokes.

  static const Color _keepStone = Color(0xFF241F2B);
  static const Color _keepMortar = Color(0xFF3A3345);
  static const Color _keepVoid = Color(0xFF0B0910);
  static const Color _keepBrass = Color(0xFFE4C16A);
  static const Color _keepSheen = Color(0xFFBFD4E4);

  void _renderKeep(Canvas canvas, DungeonRoom room) {
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

    // The socket: stone the chamber sits in, and never moves.
    canvas.drawRect(room.bounds, Paint()..color = _keepStone);
    canvas.drawRect(
      room.bounds.deflate(14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _keepMortar,
    );

    if (chamber == null) {
      _renderHollow(canvas, room);
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
      canvas.restore();
      if (prism.shear > 0) _renderShearEdge(canvas, room);
    }

    _renderCellFrame(canvas, room, cell);
    _renderIndexPlate(canvas, cell);
  }

  void _renderHollow(Canvas canvas, DungeonRoom room) {
    final r = room.bounds.deflate(26);
    canvas.drawRect(r, Paint()..color = _keepVoid);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _keepMortar.withValues(alpha: 0.7);
    for (var i = 1; i < 5; i++) {
      canvas.drawRect(r.deflate(i * 9.0), p);
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
    canvas.drawRect(r, Paint()..color = glass.withValues(alpha: 0.30));
    // Facet cuts: a bright notch on every wall the chamber is cut through.
    final cut = Paint()..color = glass.withValues(alpha: 0.85);
    if (chamber.cut(kFacetN)) {
      canvas.drawRect(Rect.fromLTWH(r.left + 129, r.top, 110, 10), cut);
    }
    if (chamber.cut(kFacetS)) {
      canvas.drawRect(
        Rect.fromLTWH(r.left + 129, r.bottom - 10, 110, 10),
        cut,
      );
    }
    if (chamber.cut(kFacetW)) {
      canvas.drawRect(Rect.fromLTWH(r.left, r.top + 102, 10, 110), cut);
    }
    if (chamber.cut(kFacetE)) {
      canvas.drawRect(Rect.fromLTWH(r.right - 10, r.top + 102, 10, 110), cut);
    }
    // The grain: three long facet lines, so a chamber is recognisable at a
    // glance when it turns up in a different socket.
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = glass.withValues(alpha: 0.5);
    for (var i = 1; i <= 3; i++) {
      final x = r.left + r.width * i / 4;
      canvas.drawLine(Offset(x, r.top + 8), Offset(x - 26, r.bottom - 8), grain);
    }

    if (chamber.id == 'hearth') _renderShardHearth(canvas);
    if (chamber.throne) _renderThrone(canvas, glass);
    if (chamber.id == 'waiting') _renderWaitingFacet(canvas);
    _renderBeamThrough(canvas, cell, chamber);
  }

  void _renderShardHearth(Canvas canvas) {
    final f = _keep;
    final warm = f.hearthKindled;
    final base = warm ? _keepBrass : const Color(0xFF6A6070);
    // A standing shard, drawn as a hard prism — never a soft glow.
    final path = Path()
      ..moveTo(kChamberHeart.dx, kChamberHeart.dy - 46)
      ..lineTo(kChamberHeart.dx + 24, kChamberHeart.dy + 12)
      ..lineTo(kChamberHeart.dx, kChamberHeart.dy + 34)
      ..lineTo(kChamberHeart.dx - 24, kChamberHeart.dy + 12)
      ..close();
    canvas.drawPath(path, Paint()..color = base.withValues(alpha: 0.9));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: warm ? 0.55 : 0.2),
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

  void _renderThrone(Canvas canvas, Color glass) {
    final seat = Rect.fromCenter(
      center: kChamberHeart + const Offset(0, 8),
      width: 66,
      height: 40,
    );
    canvas.drawRect(seat, Paint()..color = glass.withValues(alpha: 0.9));
    canvas.drawRect(
      Rect.fromLTWH(seat.left, seat.top - 48, seat.width, 48),
      Paint()..color = glass.withValues(alpha: 0.55),
    );
    canvas.drawRect(
      seat,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _keepBrass.withValues(alpha: 0.6),
    );
  }

  void _renderWaitingFacet(Canvas canvas) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _keepBrass.withValues(alpha: 0.7);
    canvas.drawRect(
      Rect.fromCenter(center: kChamberHeart, width: 120, height: 96),
      p,
    );
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
      Color(0xFFE05A4A), Color(0xFFE0864A), Color(0xFFE0B84A),
      Color(0xFFC8E04A), Color(0xFF7CE04A), Color(0xFF4AE08A),
      Color(0xFF4AE0D6), Color(0xFF4AAEE0), Color(0xFF4A6EE0),
      Color(0xFF804AE0), Color(0xFFC44AE0), Color(0xFFE04A96),
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
      canvas.drawLine(Offset(x, room.bounds.top + 26),
          Offset(x, room.bounds.bottom - 26), p);
    } else if (d.dy != 0) {
      final y = d.dy > 0 ? room.bounds.top + 26 : room.bounds.bottom - 26;
      canvas.drawLine(Offset(room.bounds.left + 26, y),
          Offset(room.bounds.right - 26, y), p);
    }
  }

  /// The FRAME's own furniture. It belongs to the socket, not the chamber, so
  /// it stays exactly where it is while the world slides past it — which is
  /// the clearest possible statement of the planet's rule.
  void _renderCellFrame(Canvas canvas, DungeonRoom room, int cell) {
    final f = _keep;
    final plate = Paint()..color = _keepMortar;
    final live = Paint()..color = _keepBrass.withValues(alpha: 0.75);
    for (final facet in const [kFacetN, kFacetE, kFacetS, kFacetW]) {
      final n = keepNeighbourToward(cell, facet);
      if (n < 0) continue;
      final at = keepPlateFor(facet);
      final ready = !f.facetStanding && f.hollowCell == n;
      canvas.drawRect(
        Rect.fromCenter(center: at, width: 40, height: 40),
        ready ? live : plate,
      );
      canvas.drawRect(
        Rect.fromCenter(center: at, width: 40, height: 40),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _keepBrass.withValues(alpha: 0.35),
      );
    }
    // The tuning boss (THE ANNEAL).
    canvas.drawCircle(kCellTuningBoss, 15, Paint()..color = _keepMortar);
    canvas.drawCircle(
      kCellTuningBoss,
      15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _keepBrass.withValues(alpha: 0.55),
    );
    // The berth chain, in the three sockets that can see the berth's mouth.
    if (keepNeighbours(kKeepMouthCell).contains(cell) ||
        cell == kKeepMouthCell) {
      final taut = f.facetStanding || f.hollowCell == kKeepMouthCell;
      canvas.drawRect(
        Rect.fromCenter(center: kBerthChain, width: 16, height: 34),
        Paint()
          ..color = (taut ? _keepBrass : _keepMortar).withValues(alpha: 0.9),
      );
    }
    // The west lamp and the east rose, on the outer frame of the middle row.
    if (cell == kKeepBeamRow.first) {
      canvas.drawCircle(
        kWestLamp,
        13,
        Paint()
          ..color = (f.lampLit ? _keepBrass : _keepMortar).withValues(
            alpha: 0.95,
          ),
      );
    }
    if (cell == kKeepBeamRow.last) {
      final want = _wheelColour(kRoseHue);
      canvas.drawCircle(kEastRose, 17, Paint()..color = want.withValues(alpha: 0.35));
      canvas.drawCircle(
        kEastRose,
        17,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = want.withValues(alpha: 0.9),
      );
    }
  }

  /// THE INDEX PLATE — a 3×3 diagram cut into every socket's frame. A sliding
  /// puzzle is unplayable if the player cannot see the board, and this planet
  /// deliberately never shows it from above; the plate is the board.
  void _renderIndexPlate(Canvas canvas, int here) {
    const origin = Offset(18, 18);
    const pip = 26.0;
    final f = _keep;
    canvas.drawRect(
      Rect.fromLTWH(origin.dx - 5, origin.dy - 5, pip * 3 + 10, pip * 3 + 10),
      Paint()..color = _keepVoid.withValues(alpha: 0.8),
    );
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
              : Color(ch.argb).withValues(alpha: 0.85),
      );
      if (i == here) {
        canvas.drawRect(
          r.inflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.85),
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
    canvas.drawRect(
      berth,
      Paint()
        ..color = f.facetStanding
            ? _keepVoid
            : Color(kPrismChambers[kWaitingFacet].argb).withValues(alpha: 0.7),
    );
  }

  void _renderOriel(Canvas canvas, DungeonRoom room) {
    canvas.drawRect(room.bounds, Paint()..color = _keepStone);
    final face = room.prism!.glassFace!;
    final pane = Rect.fromCenter(center: face, width: 240, height: 92);
    canvas.drawRect(
      pane,
      Paint()
        ..color = (entryDoorRevealed ? _keepVoid : _keepSheen).withValues(
          alpha: entryDoorRevealed ? 0.9 : 0.35,
        ),
    );
    if (!entryDoorRevealed) {
      canvas.drawRect(
        pane,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _keepSheen.withValues(alpha: 0.6),
      );
    }
    final ring = room.prism!.annealRing!;
    canvas.drawCircle(ring, 22, Paint()..color = _keepMortar);
    canvas.drawCircle(
      ring,
      22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _keepBrass.withValues(alpha: 0.7),
    );
    // The whole keep, seen from the balcony — the only overview in the game.
    _renderKeepChart(canvas, const Offset(470, 150), 62);
  }

  void _renderKeepChart(Canvas canvas, Offset origin, double pip) {
    final f = _keep;
    for (var i = 0; i < 9; i++) {
      final r = Rect.fromLTWH(
        origin.dx + (i % 3) * pip,
        origin.dy + (i ~/ 3) * pip,
        pip - 6,
        pip - 6,
      );
      final ch = f.chamberAt(i);
      canvas.drawRect(
        r,
        Paint()
          ..color = ch == null
              ? _keepVoid
              : Color(ch.argb).withValues(alpha: 0.8),
      );
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _keepMortar,
      );
    }
  }

  void _renderTuningHall(Canvas canvas, DungeonRoom room) {
    canvas.drawRect(room.bounds, Paint()..color = _keepStone);
    final font = room.prism!.facetFont!;
    final live = (conduitEnergy['B'] ?? 0) > 0;
    canvas.drawCircle(
      font,
      26,
      Paint()..color = (live ? _keepBrass : _keepMortar).withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      font,
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _keepSheen.withValues(alpha: 0.5),
    );
    final ring = room.prism!.annealRing!;
    canvas.drawCircle(ring, 18, Paint()..color = _keepMortar);
    canvas.drawCircle(
      ring,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _keepBrass.withValues(alpha: 0.6),
    );
  }

  void _renderChoirFloor(Canvas canvas, DungeonRoom room) {
    canvas.drawRect(room.bounds, Paint()..color = _keepVoid);
    final floor = room.prism!.choir!;
    for (var i = 0; i < 9; i++) {
      final r = floor.plateRect(i).deflate(6);
      if (i == prism.choirHollow) {
        canvas.drawRect(r, Paint()..color = _keepVoid);
        canvas.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _keepBrass.withValues(alpha: 0.6),
        );
        continue;
      }
      canvas.drawRect(r, Paint()..color = _keepStone);
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _keepMortar,
      );
    }
    final ring = room.prism!.annealRing!;
    canvas.drawCircle(ring, 16, Paint()..color = _keepMortar);
    canvas.drawCircle(
      ring,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _keepBrass.withValues(alpha: 0.6),
    );
  }
}
