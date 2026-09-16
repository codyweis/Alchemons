// lib/games/planet_dungeon/planet_dungeon_game_light.dart
//
// SOLARIN — the Beacon Archive. Light's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart` (the treatment every planet after the Air
// pilot gets). The layout, the sill graph, the beacons, the effigies, the
// slips and the whole occlusion arithmetic live in
// planet_dungeon_layout_light.dart; this file is the rules that drive them.
//
// World rule: *the statues lie; their shadows cannot — and every lumen you
// spend is seen.* See the layout header for the full statement of the hall,
// the arithmetic, the vault trick, and why this planet needs no reset valve.
//
//  • Entry — the archive's own shutter is folded across the doorway. LIGHT
//    draws it back and the hall opens (§5.5, the eased entry reveal).
//  • Star 0 (Shadow) — THE FOUR EFFIGIES, on the shadow court's balustrade.
//    An effigy reads only while the stone STANDS IN LIGHT and the niche it
//    throws its shadow into stands in SHADOW: occlusion at object scale, and
//    the tutorial for everything else here. ELEMENT-ONLY, all three elements
//    used: this is the star §4 guarantees to any trio of the right elements
//    on a first descent.
//  • Star 1 (Hush) — THE THREE SLIPS (§6's Dark Stacks). A Spirit PIP goes
//    behind the shelves (the planet's one star-level family gate), and a slip
//    only comes out while the whole archive is under the HUSH of two lumens.
//    Every slip lies in a bay that cannot be reached in the dark, so the road
//    to it is made of the very thing that stops it being drawn.
//  • Rite (Reading Floor) — conduit A is the Crystal+MASK prism oriel (§6 put
//    this gate on Star 0; §4's first-descent guarantee wins, so it moved
//    here); the shutter-ring is element-only Light with **Crystal+Spirit→
//    Light** as the braid.
//  • Star 2 (Corona) — MYS16 SOLARIN. §7: the guardian fights WITH the
//    planet's rule. It is wounded light and it BLINDS wherever it looks — its
//    glare sweeps its own floor, nothing can touch it from inside the glare,
//    and its lull exists only for a party standing in the shadow one of the
//    three pillars is throwing.
//  • Lost Maxim — AFRAID OF THE LIGHT (§6): cross the whole archive from the
//    doorway to the reliquary revealing NOTHING — not one lumen, start to
//    finish.
//
// NON-STRANDABILITY (see `solveBeaconArchive`): a hall whose floor is made of
// light is the most direct stranding machine in the set — the ground you are
// standing on can stop existing. The Beacon Archive answers it not with a
// valve and not with a lucky geometry but by construction: **every move here
// has an inverse.** A step is invertible because nothing but a hand on a
// beacon changes the light and every beacon stands out on the rim, so the
// world cannot move while the party is walking; a press is invertible because
// it cycles one beacon DARK → 1 → 2 → 3 → 4 → DARK with the party standing at
// it; the only one-way edits (the door-shutter, the rite) are purely ADDITIVE;
// and Solarin's glare is arena-local and cannot reach a beacon. A move
// relation whose every edge has an inverse makes reachability an EQUIVALENCE,
// so nothing can be lost. The measurement agrees: **0 strandable of 963
// reachable states, with no reset valve** — against a non-zero count the
// moment a beacon LATCHES (one throw and no second), and another the moment
// Solarin's glare is allowed out onto the rim.

part of 'planet_dungeon_game.dart';

/// Light's lost maxim discovery id (the screen pays 20 gold on first find).
const String kLightAfraidEggId = 'egg:light_afraid';

// ── Device-tunable knobs ───────────────────────────────────
// Light has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a beacon, an effigy, a slip, the
/// door-shutter or the shutter-ring to act on it.
const double _kArchiveReach = 70.0;

/// How close the second body of a Crystal+Spirit braid must stand (§6's
/// recipe — it substitutes the ELEMENT, never a family).
const double _kArchiveBraidReach = 150.0;

/// Seconds a kindle's bloom takes to open. Purely visual.
const double _kArchiveBloomSeconds = 0.4;

/// Moth-wardens woken when the archive goes over the hush. Light is seen, and
/// this is the whole consequence of being seen (§7 — one per star).
const int _kWardensPerFlare = 2;

/// Wardens woken by reading an effigy (Star 0's consequence): you have thrown
/// a light on a grave-marker and something has noticed.
const int _kWardensPerEffigy = 2;

/// How wide Solarin's glare is, in radians either side of where it looks.
const double _kGlareHalfAngle = 0.42;

/// How fast the glare sweeps, in radians per second.
const double _kGlareSweep = 0.85;

/// How wide a pillar's shadow is, in radians either side of the pillar. The
/// only safe places in the chamber, and the fight's whole geometry.
const double _kPillarShadowHalf = 0.20;

/// Damage per second to a body standing in Solarin's glare.
const double _kGlareBurn = 5.0;

extension BeaconArchiveDungeon on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetArchiveState() {
    if (!_isArchive) return;
    // A death re-folds no shutter and puts no beacon out by itself — the
    // archive is puzzle state like every other planet's, so it resets with
    // the run.
    archive.reset();
  }

  // ── The map, in the state the archive is in ──────────────

  /// The sill a door IS. One room pair, one sill (pinned by the tests), so the
  /// door the player walks and the edge the proof walks are the same object
  /// and can never drift apart.
  HallSill? _archiveSillFor(DungeonRoom room, DungeonDoor door) =>
      archiveSillBetween(room.id, door.targetRoomId);

  /// A GLASS LEAF with no light in it is not a door you have not opened — the
  /// glass is invisible and what you are looking at is a hole down into the
  /// stacks. Hidden, because there is nothing there to meet.
  bool _archiveDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isArchive) return false;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) {
      // The shutter is folded across every way out of the doorway.
      return true;
    }
    final sill = _archiveSillFor(room, door);
    if (sill == null) return false;
    return sill.cut == SillCut.glassLeaf && !archive.sillOpen(sill);
  }

  /// A MIRROR SHELF under light is the opposite: you can see it perfectly
  /// well, and it is a sheet of white glare nobody walks into. Visible and
  /// refused, because being told what the light has taken is the whole
  /// teaching layer of this planet (§5.6 BLOCKED).
  bool _archiveDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isArchive) return false;
    final sill = _archiveSillFor(room, door);
    if (sill == null) return false;
    return !archive.sillOpen(sill);
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How to re-shape the light is Mask's earned reading.
  String _archiveDoorHint(DungeonRoom room, DungeonDoor door) {
    final sill = _archiveSillFor(room, door)!;
    final where = sectorWord(sill.cell!.sector);
    return sill.cut == SillCut.glassLeaf
        ? 'Nothing in the glass, $where is dark'
        : 'Glare off the whole shelf, $where is lit';
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Light verb, in priority order. Returns true when one was consumed.
  /// Nothing here outranks the guardian's own catch, because Solarin's
  /// chamber holds no verb of the archive's at all — the pillars are scenery
  /// you stand behind, not objects you press.
  bool _tryArchiveVerb(DungeonCreature a) {
    if (!_isArchive) return false;
    return _tryDoorShutter(a) ||
        _tryBeacon(a) ||
        _tryEffigy(a) ||
        _tryHushSlip(a) ||
        _tryShutterRing(a);
  }

  /// The planet's verb is element-only LIGHT (§4), and **Crystal+Spirit→
  /// Light** (§6) stands in as a BRAID — two bodies at the same spot — for a
  /// party whose Light hand is down. A recipe substitutes the ELEMENT, never
  /// a family, so it is never accepted at the oriel or behind the shelves.
  bool _archiveHasSunHand(DungeonCreature a) {
    final el = a.member.element;
    if (el == 'Light') return true;
    if (el != 'Crystal' && el != 'Spirit') return false;
    final want = el == 'Crystal' ? 'Spirit' : 'Crystal';
    return creatures.any(
      (c) =>
          !identical(c, a) &&
          c.alive &&
          c.member.element == want &&
          (c.position - a.position).distance < _kArchiveBraidReach,
    );
  }

  /// The entry rite: Light unfolds the archive's own shutter.
  bool _tryDoorShutter(DungeonCreature a) {
    final pos = currentRoom.hall?.doorShutter;
    if (pos == null || entryDoorRevealed) return false;
    if ((a.position - pos).distance > _kArchiveReach) return false;
    if (a.member.element != 'Light') {
      _setBlockedHint('Only Light unfolds the archive\'s own shutter');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The shutter folds back, and the archive is one room, all of it');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Light',
      reagentElements: const ['Crystal', 'Spirit'],
      particleCount: 30,
      intensity: 1.25,
    );
    return true;
  }

  /// A BEACON — the only place in the archive the light moves, and the
  /// planet's whole verb. Element-only Light (braid allowed): a hall you
  /// cannot re-light is a softlock, so this is never gated, never one-way and
  /// never on a cooldown. One press walks the beacon DARK → 1 → 2 → 3 → 4 →
  /// DARK, so four more presses put it back exactly — reason 2 of the
  /// no-strand proof.
  bool _tryBeacon(DungeonCreature a) {
    final b = archiveBeaconIn(currentRoomId);
    if (b == null) return false;
    if ((a.position - b.post).distance > _kArchiveReach) return false;
    if (!_archiveHasSunHand(a)) {
      _setBlockedHint('Only Light takes hold of a beam');
      return true;
    }
    final before = archive.lumens;
    final now = archive.press(b.id);
    archive.bloom = _kArchiveBloomSeconds;
    _spawnAlchemyBurst(
      b.post,
      producedElement: 'Light',
      reagentElements: const ['Crystal', 'Spirit'],
      particleCount: now == null ? 12 : 22,
      intensity: now == null ? 0.7 : 1.1,
    );
    _setHint(
      now == null
          ? 'The pan goes out, and the hall comes back'
          : 'It throws ${now.look}',
    );
    _wakeWardens(before, b.post);
    return true;
  }

  /// THE CONSEQUENCE (§7, one per star, and the planet's whole cost model):
  /// every lumen is seen. Crossing the hush from under it wakes the wardens
  /// that roost in the gallery — edge-triggered, so sitting in a bright
  /// archive is expensive once rather than forever.
  void _wakeWardens(int before, Offset at) {
    final after = archive.lumens;
    if (after <= kArchiveHush || before > kArchiveHush) return;
    spawnWispWave(
      element: 'Light',
      center: at,
      count: _kWardensPerFlare,
      unstable: true,
      announce: false,
    );
  }

  // ── Star 0 · THE SHADOW COURT ────────────────────────────

  DungeonRoom? get _courtStarRoom {
    for (final r in layout.rooms.values) {
      if (r.hall?.balustrade != null) return r;
    }
    return null;
  }

  /// An EFFIGY. §6: the statue claims one thing and its shadow says another,
  /// so the reading needs BOTH halves of the planet's rule at once — the stone
  /// in light, and the niche it throws into in shadow. Element-only (§4), and
  /// the four are spread across all three entry elements so any correct trio
  /// finishes the court on a first descent.
  bool _tryEffigy(DungeonCreature a) {
    if (currentRoom.hall?.balustrade == null) return false;
    for (final e in kCourtEffigies) {
      if ((a.position - e.position).distance > _kArchiveReach) continue;
      if (archive.effigiesRead.contains(e.id)) {
        _setHint('Read already, ${e.truth}');
        return true;
      }
      if (a.member.element != e.element) {
        _setBlockedHint('This one answers ${e.element}');
        return true;
      }
      if (archive.isDark(e.stand)) {
        _setBlockedHint(
          'No light on it, ${sectorWord(e.stand.sector)} is dark',
        );
        return true;
      }
      if (archive.isLit(e.niche)) {
        _setBlockedHint(
          'Nowhere for its shadow, ${sectorWord(e.niche.sector)} is lit',
        );
        return true;
      }
      archive.effigiesRead.add(e.id);
      _spawnAlchemyBurst(
        e.position,
        producedElement: 'Light',
        reagentElements: [e.element],
        particleCount: 26,
        intensity: 1.15,
      );
      // Reading one means having thrown a light on it, and light is seen.
      spawnWispWave(
        element: 'Light',
        center: e.position,
        count: _kWardensPerEffigy,
        unstable: true,
        announce: false,
      );
      if (!archive.courtRead) {
        _setHint('The stone says ${e.stone}. ${e.truth}');
        return true;
      }
      final idx = _courtStarRoom?.hall?.starIndex;
      if (idx != null && !hasStar(idx)) {
        _setHint('Four stones read by what they throw, and every one a liar');
        earnStar(idx);
      }
      return true;
    }
    return false;
  }

  // ── Star 1 · THE DARK STACKS ─────────────────────────────

  DungeonRoom? get _hushStarRoom {
    for (final r in layout.rooms.values) {
      if (r.hall?.starIndex == 1) return r;
    }
    return null;
  }

  /// A SLIP behind the shelves. Two things gate it, in this order: a **Spirit
  /// PIP** — the star's ONE hard family gate (§4) — is the only body small
  /// enough to reach in; and the whole archive must be under the HUSH, because
  /// the reading cannot be done while the wardens can see the reader.
  ///
  /// Nothing here edits the map, which is why the star cannot strand: the
  /// exposure rule refuses an ACT, never a passage.
  bool _tryHushSlip(DungeonCreature a) {
    for (final s in archiveSlipsIn(currentRoomId)) {
      if ((a.position - s.position).distance > _kArchiveReach) continue;
      if (archive.slipsDrawn.contains(s.id)) return false;
      final gate = layout.familyGateFor('hush_slip')!;
      if (a.member.element != gate.element) {
        _setBlockedHint('This reaches back further than ${a.member.element}');
        return true;
      }
      if (abilityForFamily(a.member.family) != abilityForFamily(gate.family)) {
        _stampFamilyGate(gate);
        _setBlockedHint(gate.hintLine);
        return true;
      }
      _stampFamilyGate(gate);
      if (!archive.underHush) {
        _setBlockedHint(
          'Too much of you showing, ${archive.lumens} lumens on the hall',
        );
        return true;
      }
      archive.slipsDrawn.add(s.id);
      _spawnAlchemyBurst(
        s.position,
        producedElement: 'Light',
        reagentElements: const ['Spirit'],
        particleCount: 24,
        intensity: 1.0,
      );
      if (!archive.everySlipDrawn) {
        _setHint('Out it comes, ${s.line}', 3.4);
        return true;
      }
      final idx = _hushStarRoom?.hall?.starIndex;
      if (idx != null && !hasStar(idx)) {
        _setHint('Three slips drawn, and the archive never saw you take one');
        earnStar(idx);
      }
      return true;
    }
    return false;
  }

  // ── The rite · THE READING FLOOR ─────────────────────────

  /// The rite's second half — the shutter-ring, which throws the oculus's own
  /// light down onto the floor. Element-only Light with the Crystal+Spirit
  /// braid, so a party missing the Mask meets exactly ONE refusal on this
  /// floor rather than two.
  bool _tryShutterRing(DungeonCreature a) {
    final pos = currentRoom.hall?.shutterRing;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kArchiveReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (!_archiveHasSunHand(a)) {
      _setBlockedHint('Only Light turns the ring');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The ring will not turn, it answers only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
    _setHint('The ring comes round, and the oculus lands on the floor at last');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Light',
      reagentElements: const ['Crystal', 'Spirit'],
      particleCount: 30,
      intensity: 1.2,
    );
    return true;
  }

  // ── Star 2 · SOLARIN ─────────────────────────────────────

  /// §7 — the guardian fights WITH the planet's rule. Solarin is wounded
  /// light: it BLINDS wherever it looks. Its glare is a cone sweeping its own
  /// floor; a body caught in it burns and nothing in it can reach the mystic,
  /// and its lull exists only for a party standing in the shadow one of the
  /// three pillars is throwing. Occlusion, at the scale of a fight.
  ///
  /// What it deliberately does NOT do is touch the archive outside — see the
  /// layout header, reason 4, and the counterfactual that pins it.
  void _updateSolarin(DungeonRoom room, double dt) {
    if (room.guardian == null) return;
    if (!guardianAwake) {
      archive.glare = 0;
      return;
    }
    archive.glare = (archive.glare + _kGlareSweep * dt) % (2 * pi);
    final eye = room.guardian!.position;
    // The lull is not a timer here — it is a PLACE. Solarin stops being
    // touchable the moment the party steps out of a pillar's shadow.
    if (guardianVulnerable && !_inPillarShadow(room, eye)) {
      guardianVulnerable = false;
    }
    // The glare burns whatever it lands on. Blinding is the consequence, and
    // the pillars are the answer — the planet's own rule, in the fight.
    for (final c in creatures) {
      if (!c.alive) continue;
      if (!_inGlare(eye, c.position)) continue;
      // _handleDowns resolves a KO, exactly as the shared hazard check does.
      c.hp = max(0, c.hp - _kGlareBurn * dt);
    }
  }

  /// Whether [p] stands inside the cone Solarin is currently looking down.
  bool _inGlare(Offset eye, Offset p) {
    final d = p - eye;
    if (d.distance < 32) return false;
    var diff = (atan2(d.dy, d.dx) - archive.glare) % (2 * pi);
    if (diff > pi) diff -= 2 * pi;
    return diff.abs() < _kGlareHalfAngle;
  }

  /// Whether the ACTIVE body stands behind one of the chamber's three pillars
  /// — the only shadows in the room, and the only place the mystic can be
  /// reached from.
  bool _inPillarShadow(DungeonRoom room, Offset eye) {
    final pillars = room.hall?.gazePillars ?? const <Offset>[];
    if (pillars.isEmpty) return true;
    final a = active;
    if (a == null || !a.alive) return false;
    final d = a.position - eye;
    final bearing = atan2(d.dy, d.dx);
    for (final pil in pillars) {
      final pd = pil - eye;
      if (d.distance <= pd.distance) continue; // in front of the pillar
      var diff = (bearing - atan2(pd.dy, pd.dx)) % (2 * pi);
      if (diff > pi) diff -= 2 * pi;
      if (diff.abs() < _kPillarShadowHalf) return true;
    }
    return false;
  }

  // ── The Lost Maxim · AFRAID OF THE LIGHT ─────────────────

  /// §6's "Afraid of the Light": cross the blinding maze revealing NOTHING.
  /// Armed at the doorway with the whole archive dark, killed by the first
  /// lumen (see [BeaconArchive.press]), and paid off on arriving at the
  /// reliquary — which is the same walk the vault's essence wants (§6 says so
  /// outright), and the one crossing the run spends its whole length teaching
  /// you not to make.
  void _updateHushWalk(DungeonRoom room) {
    if (archive.hushWalked || discoveredClouds.contains(kLightAfraidEggId)) {
      return;
    }
    if (archive.lumens > 0) {
      archive.hushWalk = false;
      return;
    }
    if (room.id == layout.entranceRoomId) {
      archive.hushWalk = true;
      return;
    }
    if (!archive.hushWalk || room.vaultCache == null) return;
    archive.hushWalk = false;
    archive.hushWalked = true;
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    beginMaximRite(kLightAfraidEggId, room.vaultCache!);
    _spawnAlchemyBurst(
      room.vaultCache!,
      producedElement: 'Light',
      reagentElements: const ['Crystal', 'Spirit'],
      particleCount: 44,
      intensity: 1.5,
    );
  }

  // ── Per-frame ────────────────────────────────────────────

  void _updateArchive(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isArchive) return;
    if (archive.bloom > 0) archive.bloom = max(0.0, archive.bloom - dt);
    _updateHushWalk(room);
    _updateSolarin(room, dt);
  }

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): the counters live beside the star
  /// tracker, per room, never as prose that fades. LUMENS is the default,
  /// because on this planet it is the one number every decision turns on, and
  /// it is drawn against the hush so "too bright" reads at a glance.
  DungeonProgressReadout? _archiveProgressReadout() {
    final hall = layout.rooms[currentRoomId]?.hall;
    if (hall?.balustrade != null && !hasStar(hall!.starIndex!)) {
      final n = archive.effigiesRead.length;
      return DungeonProgressReadout(
        label: 'READ',
        value: '$n/${kCourtEffigies.length}',
        fraction: n / kCourtEffigies.length,
      );
    }
    if (archiveSlipsIn(currentRoomId).isNotEmpty && !hasStar(1)) {
      final n = archive.slipsDrawn.length;
      return DungeonProgressReadout(
        label: 'SLIPS',
        value: '$n/${kArchiveSlips.length}',
        fraction: n / kArchiveSlips.length,
      );
    }
    final l = archive.lumens;
    return DungeonProgressReadout(
      label: 'LUMENS',
      value: '$l/$kArchiveHush',
      fraction: (l / BeaconArchive.allCells.length).clamp(0.0, 1.0),
    );
  }

  String _archiveRoomWord(String roomId) => switch (roomId) {
    'lumen_threshold' => 'the Lumen Threshold',
    'shadow_court' => 'the Shadow Court',
    'moth_gallery' => 'the Moth Gallery',
    'dark_stacks' => 'the Dark Stacks',
    'catalogue_walk' => 'the Catalogue Walk',
    'oculus_stair' => 'the Oculus Stair',
    'reading_floor' => 'the Reading Floor',
    'sunless_reliquary' => 'a shrine you have been able to see all along',
    _ => 'somewhere under the oculus',
  };

  /// WHAT, never HOW (§5.6). Every method here is Mask's to give.
  String? _archiveObjectiveHint(DungeonRoom room) {
    if (room.guardian != null) {
      return 'Solarin\'s Oculus, the last star is behind a thing that looks '
          'at you';
    }
    if (room.hall?.shutterRing != null) {
      return 'The Reading Floor, the rite waits on the oriel and the ring';
    }
    if (room.hall?.balustrade != null) {
      return hasStar(room.hall!.starIndex!)
          ? null
          : 'The Shadow Court, four effigies, and every one of them lying';
    }
    if (room.hall?.starIndex == 1) {
      return hasStar(1)
          ? null
          : 'The Dark Stacks, something is filed where the light does not go';
    }
    if (room.vaultCache != null) {
      return 'The Sunless Reliquary, the essence has been in plain sight the '
          'whole run';
    }
    if (archiveSlipsIn(room.id).isNotEmpty && !hasStar(1)) {
      return '${_archiveRoomWord(room.id)}, a slip lies behind the shelves';
    }
    if (archiveBeaconIn(room.id) != null) {
      return 'A beacon stands here, and the hall is whatever it says';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Lumen Threshold, three ways on, and no two of them the same '
                'kind of floor'
          : 'The Lumen Threshold, the doorway is folded shut';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _archiveAmbientHint(DungeonCreature a, DungeonRoom room) {
    final b = archiveBeaconIn(room.id);
    if (b != null && (a.position - b.post).distance < 110) {
      _setAmbientHint('The pan is warm, and there is a moth in it');
      return;
    }
    if (room.hall?.balustrade != null) {
      _setAmbientHint('They were carved to be looked at, and they know it');
      return;
    }
    final sector = room.hall?.sector;
    if (sector == null) return;
    _setAmbientHint(
      sectorHasStack(sector)
          ? 'Something enormous is standing between you and the far wall'
          : 'There is nothing in here but the floor and how far you can see',
    );
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), and it is
  /// tiered by Intelligence.
  void _archiveReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    if (room.hall?.balustrade != null) {
      _setInsightHint(switch (tier) {
        0 => 'Four of them, and the stone on each one is a lie',
        1 =>
          'A shadow is the true shape. Put a light on the stone and leave '
              'the place it falls into dark',
        _ =>
          'You will not read all four in one light. The moth wants the '
              'doorway\'s inner shelf dark and the sun wants the doorway lit, '
              'and nothing stands in the doorway to keep a shadow, so come '
              'back with the hall thrown differently',
      });
      return;
    }
    if (archiveSlipsIn(room.id).isNotEmpty) {
      _setInsightHint(switch (tier) {
        0 => 'There is something filed back there, and it is not on any shelf',
        1 =>
          'The reading cannot be done while the wardens can count you. '
              'Two lumens on the whole hall, no more',
        _ =>
          'A beam breaking on a great stack costs one; an empty bay costs '
              'two. Out here past the stacks there is nothing to break on, so '
              'set the far beacon first and come at these shelves from behind, '
              'through the dark',
      });
      return;
    }
    if (archiveBeaconIn(room.id) != null) {
      _setInsightHint(switch (tier) {
        0 => 'It throws a fan, and it can be thrown flatter',
        1 =>
          'Low, it breaks on the stacks and leaves the inner shelves dark. '
              'High, it goes over them and fills them in',
        _ =>
          'Everything you light on the glass you take away on the mirror, '
              'and the reverse. The stacks are the only shadows in this hall, '
              'so a low beam is the only way to have a road and a shadow at '
              'once, and it is half the lumens besides',
      });
      return;
    }
    if (room.vaultCache != null || room.id == 'oculus_stair') {
      _setInsightHint(switch (tier) {
        0 => 'You have been able to see that shrine since the door',
        1 => 'The shelf onto it is mirror-stone, and glare is not a floor',
        _ =>
          'It lies in the court bay, which is the one bay the rim cannot '
              'be opened without. There is no arrangement that gives you both. '
              'Put the archive out and walk here in the dark',
      });
      return;
    }
    // Anywhere in the hall, insight reads the LIGHT — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'There are no walls in here. There is only how far you can see',
      1 =>
        'Glass is a floor with light in it and a hole without. Mirror-stone '
            'is a floor without light and glare with. Nothing else is a door',
      _ =>
        'Five bays, two bands, two great stacks. A low beam lights the '
            'outer walk of a bay and stops; a high one goes all the way in. '
            'Plan the smallest light that is still a road',
    });
  }

  /// Per-room mood — the doorway is full daylight and the heart is the inside
  /// of a shut book, but the real driver is the light: a bay you have lit
  /// comes up bright, and one you have not stays as dark as the heart.
  double get _archiveMoodTarget {
    final base = switch (currentRoomId) {
      'lumen_threshold' => 0.72,
      'shadow_court' => 0.56,
      'moth_gallery' => 0.50,
      'dark_stacks' => 0.34,
      'catalogue_walk' => 0.46,
      'oculus_stair' => 0.20,
      'reading_floor' => 0.30,
      'sunless_reliquary' => 0.16,
      _ => guardianAwake ? 0.86 : 0.26,
    };
    final sector = layout.rooms[currentRoomId]?.hall?.sector;
    if (sector == null) return base;
    final lit = archive.isLit(HallCell(sector, HallBand.rim));
    return lit ? (base + 0.28).clamp(0.0, 1.0) : base;
  }

  // ── THE NO-STRAND PROOF ──────────────────────────────────

  /// Exhaustive reachability over the archive's whole state graph.
  ///
  /// A state is (which bay you stand in) × (what each of the three beacons is
  /// set to). Every legal move is expanded: walking any sill that is a floor
  /// in that arrangement, and pressing the beacon in the bay you stand in.
  /// Nothing else in the world edits the map — reading an effigy, drawing a
  /// slip, taking the essence and finding the maxim all leave every sill
  /// exactly as it was, and the two one-way edits (the door-shutter and the
  /// rite) only ever OPEN a passage, so an audit run with them already open is
  /// the strictest case.
  ///
  /// Five answers, all by construction rather than by argument:
  ///
  ///  1. `strandable` — states from which some bay is no longer reachable.
  ///     **It must be zero, and it is zero WITHOUT a reset valve.**
  ///     "Reachable" is checked for EVERY room in the layout, which is
  ///     stronger than the brief asks: not just the exit and the unearned
  ///     stars, but the reliquary and the arena as well. It is zero for a
  ///     structural reason and not a lucky one — every move here has an
  ///     inverse (a press is a five-cycle taken from where you stand, and a
  ///     step cannot be interrupted because nothing but a press changes the
  ///     light), so reachability is an equivalence relation.
  ///  2. `strandableWithRatchet` — the same audit with a kindled beacon made
  ///     a RATCHET: it may be re-aimed and re-pitched but never put out
  ///     again, which is a very natural reading of "every lumen you spend is
  ///     seen". This one comes back ZERO, and the reason is worth keeping:
  ///     the four settings of a beacon remain mutually reachable, so the
  ///     press has an inverse even without DARK in the cycle. The archive has
  ///     margin here, and the number is pinned so a future edit that eats the
  ///     margin is visible.
  ///  3. `strandableWithLatchedBeacons` — the counterfactual that DOES bite,
  ///     and the fork the design actually took: a beacon that latches. One
  ///     press, one throw, and that is the archive for the rest of the run —
  ///     which is the other, harsher way to author "every lumen you spend is
  ///     seen". It deletes the inverse of the only world-editing move there
  ///     is, and it must be non-zero.
  ///  4. `strandableWithSolarinLoose` — the counterfactual for the one
  ///     authoring decision the safety actually rests on: let Solarin's glare
  ///     reach out of its chamber and kindle a rim beacon on the beat, so the
  ///     world can move while the party is not standing at one. It must be
  ///     non-zero.
  ///  5. `hushBays` — the bays that can be STOOD IN while the archive is
  ///     under the hush, which is Star 1 measured rather than asserted. All
  ///     three slip bays must be in it.
  ///  6. `hushBaysWithoutStacks` — the same set with the two great
  ///     stacks taken out of the hall, i.e. with occlusion deleted. It must be
  ///     strictly smaller, and it must lose slip bays: without something to
  ///     break the beam on, a lit bay always costs two lumens plus whatever
  ///     else the arc catches, and the exposure star stops being winnable.
  ///     This is what says the stacks are the planet and not scenery.
  ({
    int states,
    int arrangements,
    int strandable,
    int strandableWithRatchet,
    int strandableWithLatchedBeacons,
    int strandableWithSolarinLoose,
    Set<String> hushBays,
    Set<String> hushBaysWithoutStacks,
  })
  solveBeaconArchive() {
    final rooms = layout.rooms.keys.toList()..sort();
    final guardianRoom = layout.rooms.values
        .firstWhere((r) => r.guardian != null)
        .id;

    /// A configuration is one state index per beacon, in [kArchiveBeacons]
    /// order: 0 is DARK and 1..4 index that beacon's settings.
    String enc(String room, List<int> cfg) => '$room|${cfg.join()}';

    /// The SAME occlusion rule [BeamSetting.reaches] applies, restated over a
    /// plain list so the search never has to mutate live state — and
    /// [stacks] is a parameter so the occlusion counterfactual can empty the
    /// hall without touching the shipped layout.
    bool litIn(List<int> cfg, HallCell cell, Set<HallSector> stacks) {
      for (var i = 0; i < kArchiveBeacons.length; i++) {
        final b = kArchiveBeacons[i];
        final n = cfg[i];
        if (n <= 0) continue;
        final s = b.settings[n - 1];
        if (!s.covers(cell.sector)) continue;
        if (cell.band == HallBand.rim) return true;
        if (s.pitch == BeamPitch.high || !stacks.contains(cell.sector)) {
          return true;
        }
      }
      return false;
    }

    int lumensIn(List<int> cfg, Set<HallSector> stacks) {
      var n = 0;
      for (final c in BeaconArchive.allCells) {
        if (litIn(cfg, c, stacks)) n++;
      }
      return n;
    }

    bool open(HallSill s, List<int> cfg, Set<HallSector> stacks) =>
        switch (s.cut) {
          SillCut.stone => true,
          SillCut.glassLeaf => litIn(cfg, s.cell!, stacks),
          SillCut.mirrorSill => !litIn(cfg, s.cell!, stacks),
        };

    /// Which doors are a floor. Derived from the SAME sills the engine gates
    /// real doors with, via the room's own door list, so the proof can never
    /// drift from the floor the player actually walks.
    List<String> exits(String room, List<int> cfg, Set<HallSector> stacks) {
      final out = <String>[];
      for (final d in layout.rooms[room]!.doors) {
        final s = archiveSillBetween(room, d.targetRoomId);
        if (s == null || open(s, cfg, stacks)) out.add(d.targetRoomId);
      }
      return out;
    }

    List<(String, List<int>)> moves(
      String room,
      List<int> cfg, {
      required Set<HallSector> stacks,
      required bool ratchet,
      required bool latched,
      required bool solarinLoose,
    }) {
      final out = <(String, List<int>)>[];
      for (final t in exits(room, cfg, stacks)) {
        out.add((t, cfg));
      }
      // Pressing a beacon. Invertible by construction: the party does not
      // move, so four more presses of the very same move undo it — this is
      // reason 2 of the no-strand proof, expressed as code. Under `ratchet`
      // the cycle skips DARK once lit, and that one deletion is all it takes.
      for (var i = 0; i < kArchiveBeacons.length; i++) {
        final b = kArchiveBeacons[i];
        if (b.roomId != room) continue;
        // A latched beacon is thrown once and never touched again.
        if (latched && cfg[i] != 0) continue;
        var next = (cfg[i] + 1) % b.stateCount;
        if (ratchet && cfg[i] != 0 && next == 0) next = 1;
        final n = [...cfg];
        n[i] = next;
        out.add((room, n));
      }
      // Solarin's glare, loosed onto the rim — the world's move, never the
      // player's, and only ever from inside the arena. The shipped mystic
      // cannot do this; that is the point of the number.
      if (solarinLoose && room == guardianRoom) {
        for (var i = 0; i < kArchiveBeacons.length; i++) {
          if (cfg[i] == kArchiveBeacons[i].stateCount - 1) continue;
          final n = [...cfg];
          n[i] = cfg[i] + 1;
          out.add((room, n));
        }
      }
      return out;
    }

    ({int strandable, int states, int arrangements, Set<String> hush}) audit({
      required Set<HallSector> stacks,
      required bool ratchet,
      required bool latched,
      required bool solarinLoose,
    }) {
      final startCfg = [
        for (final b in kArchiveBeacons) archive.lamp[b.id] ?? 0,
      ]..length = kArchiveBeacons.length;
      final first = (layout.entranceRoomId, startCfg);
      final live = <String, (String, List<int>)>{};
      live[enc(first.$1, first.$2)] = first;
      final queue = [first];
      while (queue.isNotEmpty) {
        final (rm, cfg) = queue.removeLast();
        for (final m in moves(
          rm,
          cfg,
          stacks: stacks,
          ratchet: ratchet,
          latched: latched,
          solarinLoose: solarinLoose,
        )) {
          final k = enc(m.$1, m.$2);
          if (live.containsKey(k)) continue;
          live[k] = m;
          queue.add(m);
        }
      }
      var strandable = 0;
      final hush = <String>{};
      for (final st in live.values) {
        if (lumensIn(st.$2, stacks) <= kArchiveHush) hush.add(st.$1);
        final seen = <String>{enc(st.$1, st.$2)};
        final hit = <String>{st.$1};
        final q = [st];
        while (q.isNotEmpty) {
          final (rm, cfg) = q.removeLast();
          // Audited using ONLY the moves the player controls: the glare is
          // expanded above (making the enumerated set a strict superset of
          // what play alone reaches) but never counted as an escape.
          for (final m in moves(
            rm,
            cfg,
            stacks: stacks,
            ratchet: ratchet,
            latched: latched,
            solarinLoose: false,
          )) {
            final k = enc(m.$1, m.$2);
            if (!seen.add(k)) continue;
            hit.add(m.$1);
            q.add(m);
          }
        }
        if (hit.length < rooms.length) strandable++;
      }
      final cfgs = {for (final s in live.values) s.$2.join(): s.$2};
      return (
        strandable: strandable,
        states: live.length,
        arrangements: cfgs.length,
        hush: hush,
      );
    }

    final shipped = audit(
      stacks: kGreatStacks,
      ratchet: false,
      latched: false,
      solarinLoose: false,
    );
    final bare = audit(
      stacks: const <HallSector>{},
      ratchet: false,
      latched: false,
      solarinLoose: false,
    );
    return (
      states: shipped.states,
      arrangements: shipped.arrangements,
      strandable: shipped.strandable,
      strandableWithRatchet: audit(
        stacks: kGreatStacks,
        ratchet: true,
        latched: false,
        solarinLoose: false,
      ).strandable,
      strandableWithLatchedBeacons: audit(
        stacks: kGreatStacks,
        ratchet: false,
        latched: true,
        solarinLoose: false,
      ).strandable,
      strandableWithSolarinLoose: audit(
        stacks: kGreatStacks,
        ratchet: false,
        latched: false,
        solarinLoose: true,
      ).strandable,
      hushBays: shipped.hush,
      hushBaysWithoutStacks: bare.hush,
    );
  }

  // ── Rendering ────────────────────────────────────────────
  // VISUAL GRAMMAR (§5.5): Light's soft volumetric cones must read NOTHING
  // like Lightning's jagged bolts, so nothing on this planet is drawn as a
  // stroke of light. A lit bay is a WEDGE — a filled fan of pale gold laid on
  // the floor, soft along its length and hard across its arc, because the edge
  // of a shadow is the only sharp thing in this vocabulary. A stack's shadow
  // is the fan's BITE: the wedge simply stops, and the shelf behind it is bare
  // warm grey. Glass leaves glow from inside when lit and are an empty outline
  // when not; mirror shelves are solid slate in the dark and a flat sheet of
  // white glare in the light. No bolts, no rays, no flares, and no blur
  // filters anywhere (the game's known jank source).
  //
  // WHAT THE PLACE IS, AND WHY IT IS DRAWN THIS WAY. Every bay used to stand
  // on the shared tinted lozenge with the beacon and the effigies floating on
  // it, which made the archive read as a diagram of its own light rule rather
  // than a library. It is a LIBRARY now, and the fiction already said exactly
  // which one: the floor of the rim is GLASS laid over lightwells, the floor
  // of the heart is BLACK MIRROR-STONE, and between them stand the stacks the
  // whole planet is built on. Three materials and one kind of furniture, and
  // the light lands on all of it.
  //
  // The one thing it must never be is a bookshelf TEXTURE. Real shelving is
  // regular, which makes an archive the easiest room in the set to tile by
  // accident, and a tiled room reads as graph paper every time. So no run in
  // here is straight (each one has taken a set and bows), no two runs share an
  // angle, the bays inside a run are of unequal width, a fifth of them are
  // empty, and the ones that are full are full to different depths with books
  // that slump at the end of the row. What you should be able to read at a
  // glance is a place three centuries deep that nobody has catalogued in one.
  //
  // COST. All of it is baked ONCE per room into a `ui.Picture`, keyed on the
  // room's own id and bounds and generated from an LCG seeded off them, so a
  // frame costs one `drawPicture`, the wedge, and about twenty motes. Nothing
  // here allocates per frame and nothing here animates except the dust.

  static const Color _kArchiveNight = Color(0xFF14120E);
  static const Color _kArchiveGold = Color(0xFFFFE082);
  static const Color _kArchiveGlare = Color(0xFFFFF6DC);
  static const Color _kArchiveSlate = Color(0xFF5A5F66);
  static const Color _kArchiveStone = Color(0xFF9A9182);

  void _renderArchive(Canvas canvas, DungeonRoom room) {
    final g = _archiveGroundFor(room);
    canvas.save();
    // Clipped to the stage the shared floor already laid, so the bay keeps the
    // sky-island silhouette every other planet has and the archive's own
    // material simply replaces what is inside it.
    canvas.clipRRect(g.clip);
    canvas.drawPicture(g.fabric);
    _renderArchiveLight(canvas, room, g);
    canvas.restore();
    _renderArchiveSills(canvas, room);
    _renderArchiveObjects(canvas, room);
    _renderArchiveGlare(canvas, room);
  }

  _ArchiveGround _archiveGroundFor(DungeonRoom room) {
    final b = room.bounds;
    final key =
        '${room.id}|${b.width.toStringAsFixed(0)}x${b.height.toStringAsFixed(0)}';
    return _archiveGroundCache.putIfAbsent(
      key,
      () => _buildArchiveGround(room.id, b),
    );
  }

  /// THE WEDGE, and the dark. What the beacons have done to this bay, laid
  /// over the fabric — so the light falls on the tops of the stacks as well as
  /// the floor, which is the only way the bite reads as a shadow rather than a
  /// hole in a wash.
  void _renderArchiveLight(Canvas canvas, DungeonRoom room, _ArchiveGround g) {
    final b = room.bounds;
    final sector = room.hall?.sector;
    if (sector == null) return;
    final rimLit = archive.isLit(HallCell(sector, HallBand.rim));
    final inLit = archive.isLit(HallCell(sector, HallBand.inward));

    if (!rimLit) {
      // Nothing thrown into this bay. The fabric is already dark; this is the
      // depth of the dark, and it is deepest away from the outer wall because
      // the oculus still reaches the rim a little even with every pan out.
      canvas.drawRect(
        b,
        Paint()
          ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
            _kArchiveNight.withValues(alpha: 0.26),
            _kArchiveNight.withValues(alpha: 0.58),
          ]),
      );
      return;
    }

    // The beacons stand on the rim and throw INWARD, so the fan opens off the
    // bay's outer wall and runs down the room. Where the inward band is in
    // shadow it stops at the stack that is keeping it — the stack this room
    // actually has drawn in it, not a line invented for the wedge.
    //
    // THE SHAPE HAD TO CHANGE. A narrow fan out of a high apex came back as a
    // giant pale TRIANGLE laid over the bay, with two hard diagonals that read
    // as the edges of a torch beam — which is Lightning's vocabulary and not
    // this planet's. A kindled beacon lights the BAY; what the player is being
    // shown is where the light STOPS. So the fan is now wider than the room
    // and its side edges leave through the side walls: the only edge of it
    // anyone ever sees is the hard one across the arc, which is the shadow,
    // which is the planet.
    final apex = Offset(b.center.dx, b.top - b.height * 0.34);
    final stop = inLit
        ? b.bottom + 10
        : (g.stackLine ?? (b.top + b.height * 0.52));
    final full = b.bottom + 10 - apex.dy;
    final depth = stop - apex.dy;
    final spread = b.width * (inLit ? 1.15 : 0.98);

    Path fanTo(double d) {
      final k = d / full;
      return Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(apex.dx - spread * k, apex.dy + d)
        ..lineTo(apex.dx + spread * k, apex.dy + d)
        ..close();
    }

    // Falloff done with GEOMETRY, not a blur: four nested fans of decreasing
    // reach, so the light is strongest where it comes in and thins out along
    // its length without a MaskFilter anywhere near it.
    canvas.drawPath(
      fanTo(depth),
      Paint()..color = _kArchiveGold.withValues(alpha: 0.055),
    );
    canvas.drawPath(
      fanTo(depth * 0.80),
      Paint()..color = _kArchiveGold.withValues(alpha: 0.05),
    );
    canvas.drawPath(
      fanTo(depth * 0.55),
      Paint()..color = _kArchiveGold.withValues(alpha: 0.05),
    );
    canvas.drawPath(
      fanTo(depth * 0.28),
      Paint()..color = _kArchiveGlare.withValues(alpha: 0.05),
    );

    if (!inLit) {
      // THE HARD EDGE ACROSS THE ARC — the only sharp thing in this planet's
      // vocabulary, and the reason the bite reads as a cast shadow.
      final k = depth / full;
      canvas.drawLine(
        Offset(apex.dx - spread * k, stop),
        Offset(apex.dx + spread * k, stop),
        Paint()
          ..color = _kArchiveGlare.withValues(alpha: 0.30)
          ..strokeWidth = 2.5,
      );
      // And the shelf behind it goes darker than the rest of the bay, because
      // a shadow with light all round it is the darkest thing in the room.
      canvas.drawRect(
        Rect.fromLTRB(b.left, stop, b.right, b.bottom),
        Paint()..color = _kArchiveNight.withValues(alpha: 0.30),
      );
    }

    // DUST IN THE BEAM — the whole of what animates on this floor. Twenty
    // points on a slow vertical drift, phase-offset off their own index, and
    // culled to the fan so the dark half of the bay stays dead still.
    final dust = Paint()..color = _kArchiveGlare.withValues(alpha: 0.30);
    for (var i = 0; i < g.motes.length; i++) {
      final m = g.motes[i];
      final y = apex.dy + ((m.dy - apex.dy) + _time * 7 + i * 31) % depth;
      final k = (y - apex.dy) / full;
      if ((m.dx - apex.dx).abs() > spread * k) continue;
      final x = m.dx + sin(_time * 0.5 + i) * 6;
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.4 : 1.0, dust);
    }
  }

  /// A glyph at every sill the bay can see, so what the light has done is
  /// legible before you walk into it: a live glass leaf glows from inside, a
  /// dead one is an empty outline, a walkable mirror shelf is flat slate and a
  /// glared one is a solid white sheet. Glass leaves with no light in them are
  /// not drawn at all — they are a hole (see `_archiveDoorHidden`).
  void _renderArchiveSills(Canvas canvas, DungeonRoom room) {
    for (final d in room.doors) {
      if (isDoorHidden(room, d)) continue;
      final sill = _archiveSillFor(room, d);
      if (sill == null || sill.cut == SillCut.stone) continue;
      final at = d.rect.center;
      final live = archive.sillOpen(sill);
      final plate = Rect.fromCenter(center: at, width: 38, height: 15);
      if (sill.cut == SillCut.glassLeaf) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(plate, const Radius.circular(3)),
          Paint()..color = _kArchiveGold.withValues(alpha: live ? 0.55 : 0.06),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(plate, const Radius.circular(3)),
          Paint()
            ..color = _kArchiveGold.withValues(alpha: live ? 0.85 : 0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawRect(
          plate,
          Paint()
            ..color = live
                ? _kArchiveSlate.withValues(alpha: 0.70)
                : _kArchiveGlare.withValues(alpha: 0.92),
        );
      }
    }
  }

  void _renderArchiveObjects(Canvas canvas, DungeonRoom room) {
    final hall = room.hall;
    if (hall == null) return;

    // THE BEACON: a brass pan on a tripod of black iron. The legs are drawn
    // because a pan on its own was a floating coin — and they are what says
    // the thing is a piece of equipment somebody carried in and set down,
    // rather than a button in the floor.
    final b = archiveBeaconIn(room.id);
    if (b != null) {
      final lit = archive.settingOf(b.id);
      final leg = Paint()
        ..color = _kArchiveNight.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final a = -pi / 2 + i * 2 * pi / 3 + 0.4;
        canvas.drawLine(b.post, b.post + Offset(cos(a), sin(a)) * 26, leg);
        canvas.drawCircle(
          b.post + Offset(cos(a), sin(a)) * 26,
          3,
          Paint()..color = _kArchiveNight.withValues(alpha: 0.9),
        );
      }
      if (lit != null) {
        // The fan off the pan, and the pitch is legible in it: a low beam is
        // short and narrow and a high one reaches.
        final high = lit.pitch == BeamPitch.high;
        final len = high ? 84.0 : 48.0;
        final half = high ? 30.0 : 19.0;
        final fan = Path()
          ..moveTo(b.post.dx, b.post.dy)
          ..lineTo(b.post.dx - half, b.post.dy + len)
          ..lineTo(b.post.dx + half, b.post.dy + len)
          ..close();
        canvas.drawPath(
          fan,
          Paint()
            ..color = _kArchiveGold.withValues(
              alpha: 0.22 + 0.22 * (archive.bloom / _kArchiveBloomSeconds),
            ),
        );
      }
      canvas.drawCircle(
        b.post,
        13,
        Paint()..color = const Color(0xFF4A3A22).withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        b.post,
        9,
        Paint()
          ..color = lit == null
              ? _kArchiveStone.withValues(alpha: 0.45)
              : _kArchiveGold.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        b.post,
        14,
        Paint()
          ..color = _kArchiveStone.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // THE DOOR-SHUTTER: folded leaves across the doorway until Light draws it.
    final shutter = hall.doorShutter;
    if (shutter != null && !entryDoorRevealed) {
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromCenter(
            center: shutter + Offset(0, -18 + i * 12.0),
            width: 52,
            height: 7,
          ),
          Paint()..color = _kArchiveStone.withValues(alpha: 0.8),
        );
      }
    }

    // THE EFFIGIES: the stone, and the SHADOW it is throwing drawn as a hard
    // black wedge on the floor beside it — filled, never outlined, because the
    // shadow is the true shape and the stone is the lie. (The plinths each one
    // stands on are part of the court's fabric and are baked with it.)
    if (hall.balustrade != null) {
      for (final e in kCourtEffigies) {
        final read = archive.effigiesRead.contains(e.id);
        // A carved figure, not a token: a shouldered block with a head.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: e.position + const Offset(0, 3),
              width: 15,
              height: 20,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = _kArchiveStone.withValues(alpha: read ? 0.40 : 0.80),
        );
        canvas.drawCircle(
          e.position - const Offset(0, 8),
          5.5,
          Paint()..color = _kArchiveStone.withValues(alpha: read ? 0.45 : 0.92),
        );
        if (!archive.isLit(e.stand)) continue;
        final shadow = Path()
          ..moveTo(e.position.dx + 8, e.position.dy + 8)
          ..lineTo(e.position.dx + 52, e.position.dy + 24)
          ..lineTo(e.position.dx + 52, e.position.dy - 8)
          ..close();
        canvas.drawPath(
          shadow,
          Paint()
            ..color = _kArchiveNight.withValues(
              alpha: archive.isDark(e.niche) ? 0.85 : 0.22,
            ),
        );
      }
    }

    // THE SLIPS: a pale corner sticking out of the dark behind the shelves.
    for (final s in archiveSlipsIn(room.id)) {
      if (archive.slipsDrawn.contains(s.id)) continue;
      final corner = Path()
        ..moveTo(s.position.dx - 6, s.position.dy - 9)
        ..lineTo(s.position.dx + 6, s.position.dy - 9)
        ..lineTo(s.position.dx + 6, s.position.dy + 9)
        ..lineTo(s.position.dx - 2, s.position.dy + 9)
        ..close();
      canvas.drawPath(
        corner,
        Paint()..color = _kArchiveGlare.withValues(alpha: 0.62),
      );
      canvas.drawLine(
        Offset(s.position.dx - 3, s.position.dy - 3),
        Offset(s.position.dx + 3, s.position.dy - 3),
        Paint()
          ..color = _kArchiveNight.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }

    // THE SHUTTER-RING: a ring on the reading floor, closed until the rite.
    final ring = hall.shutterRing;
    if (ring != null) {
      final live = (conduitEnergy['B'] ?? 0) > 0;
      canvas.drawCircle(
        ring,
        16,
        Paint()
          ..color = live
              ? _kArchiveGold.withValues(alpha: 0.85)
              : _kArchiveStone.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      // The teeth it comes round on — twelve of them, which is what tells you
      // the ring is a mechanism and not a painted circle.
      final tooth = Paint()
        ..color = _kArchiveStone.withValues(alpha: live ? 0.7 : 0.45)
        ..strokeWidth = 2;
      for (var i = 0; i < 12; i++) {
        final a = i * pi / 6;
        canvas.drawLine(
          ring + Offset(cos(a), sin(a)) * 17,
          ring + Offset(cos(a), sin(a)) * 22,
          tooth,
        );
      }
    }

    // THE ARENA PILLARS: the only shadows in Solarin's chamber, so they are
    // drawn as things that could throw one — a square base, a drum, and the
    // flutes that catch the glare as it goes past.
    for (final p in hall.gazePillars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 50, height: 50),
          const Radius.circular(4),
        ),
        Paint()..color = _kArchiveNight.withValues(alpha: 0.62),
      );
      canvas.drawCircle(
        p,
        19,
        Paint()..color = _kArchiveStone.withValues(alpha: 0.82),
      );
      // A lit side and a dark one. Radial flutes were tried first and every
      // pillar came back as a SPOKED WHEEL lying on the floor — which is the
      // wrong object entirely in a room whose whole subject is what a round
      // thing does to light.
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: 15),
        pi * 1.15,
        pi * 0.7,
        false,
        Paint()
          ..color = _kArchiveGlare.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: 15),
        pi * 0.15,
        pi * 0.7,
        false,
        Paint()
          ..color = _kArchiveNight.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
      canvas.drawCircle(
        p,
        19,
        Paint()
          ..color = _kArchiveNight.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Solarin's glare: one filled wedge swept off the mystic, and the three
  /// pillar shadows drawn as the bites out of it. Two paths, once a frame,
  /// arena only.
  void _renderArchiveGlare(Canvas canvas, DungeonRoom room) {
    final g = room.guardian;
    if (g == null || !guardianAwake) return;
    final eye = g.position;
    const reach = 720.0;
    final fan = Path()..moveTo(eye.dx, eye.dy);
    for (var i = 0; i <= 6; i++) {
      final t =
          archive.glare - _kGlareHalfAngle + 2 * _kGlareHalfAngle * (i / 6);
      fan.lineTo(eye.dx + cos(t) * reach, eye.dy + sin(t) * reach);
    }
    fan.close();
    canvas.drawPath(
      fan,
      Paint()..color = _kArchiveGlare.withValues(alpha: 0.22),
    );
    for (final p in room.hall?.gazePillars ?? const <Offset>[]) {
      final d = p - eye;
      final bearing = atan2(d.dy, d.dx);
      final wedge = Path()..moveTo(p.dx, p.dy);
      for (var i = 0; i <= 4; i++) {
        final t =
            bearing - _kPillarShadowHalf + 2 * _kPillarShadowHalf * (i / 4);
        wedge.lineTo(eye.dx + cos(t) * reach, eye.dy + sin(t) * reach);
      }
      wedge.close();
      canvas.drawPath(
        wedge,
        Paint()..color = _kArchiveNight.withValues(alpha: 0.55),
      );
    }
  }
}

// ═════════════════════════════════════════════════════════
// THE ARCHIVE'S FABRIC — built once per bay, drawn as a Picture
// ═════════════════════════════════════════════════════════
//
// Everything below is STATIC geometry. It is generated from an LCG seeded off
// the room's own id and bounds — so it is identical on every device and every
// run, and it never has to be regenerated — and baked straight into a
// `ui.Picture`. The live half of the planet (the wedge, the sills, the
// beacons, the glare) is drawn over the top of it in the extension above.

/// Keyed on room id + bounds. Populated on a bay's first frame and then read.
final Map<String, _ArchiveGround> _archiveGroundCache = {};

/// The lightwell under the glass floor of the rim: the archive's own basement,
/// and the reason a dark leaf is a hole rather than a closed door.
const Color _kArchWell = Color(0xFF04060B);

/// The glass itself, which has almost no colour of its own — what you see in
/// it is whatever is under it or on it.
const Color _kArchGlass = Color(0xFF272A26);

/// The lead the panes are set in.
const Color _kArchLead = Color(0xFF8A8272);

/// The heart's black mirror-stone.
const Color _kArchMirror = Color(0xFF1B1A1B);

/// Oak: every stack, case, desk and cabinet in the building.
const Color _kArchOak = Color(0xFF3A2E21);
const Color _kArchOakLip = Color(0xFF7A6449);

/// The masonry — piers, plinths, kerbs, balustrades.
const Color _kArchLime = Color(0xFF8C8374);

/// Six leathers. Books are bound in whatever the binder had, and a shelf of
/// one colour is a shelf nobody ever added to.
const List<Color> _kArchSpines = [
  Color(0xFF7E3C2B),
  Color(0xFF6B5B2E),
  Color(0xFF3E4C3B),
  Color(0xFF59452F),
  Color(0xFF8F8165),
  Color(0xFF2C3844),
];

/// The stage the shared floor lays under every plain room. Matched here so the
/// archive's own material sits exactly inside it.
const double _kArchStageRadius = 34;

/// A tiny LCG. Deterministic, seeded from the room's own id and bounds, so two
/// devices draw the same archive and a rebuild is never needed.
class _ArchRng {
  _ArchRng(int seed) : _s = (seed & 0x7fffffff) | 1;
  int _s;

  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }

  double range(double a, double b) => a + next() * (b - a);
  int pick(int n) => (next() * n).floor().clamp(0, n - 1);
  bool chance(double p) => next() < p;
}

/// One bay's baked fabric.
class _ArchiveGround {
  const _ArchiveGround({
    required this.clip,
    required this.fabric,
    required this.stackLine,
    required this.motes,
  });

  /// The stage, as the shared floor drew it.
  final RRect clip;

  /// Floor, furniture, architecture — everything that never changes.
  final ui.Picture fabric;

  /// Where the bay's great stack actually stands, so the wedge's bite lands on
  /// the thing that is casting it instead of at an invented fraction of the
  /// room. Null in a bay with nothing tall enough to keep a shadow.
  final double? stackLine;

  /// Seed positions for the dust in the beam.
  final List<Offset> motes;
}

/// Accumulator. Everything is collected into a handful of Paths first and
/// painted in one pass at the end, so the baked Picture holds a dozen draw
/// calls rather than a thousand.
class _ArchDraft {
  final Path field = Path(); // the floor material itself
  final Path wells = Path(); // voids: lightwells under glass, spall in stone
  final Path sheen = Path(); // broad pale washes (polish, a reflected oculus)
  final Path joint = Path(); // cames and slab joints
  final Path gleam = Path(); // the pale edge on glass and polished stone
  final Path cast = Path(); // the hard shadows the furniture throws
  final Path castLine = Path(); // the same, for anything drawn as a line
  final Path scorch = Path(); // burnt-in sweeps, thin and old
  final Path stoneFill = Path(); // piers, plinths, kerbs, steps
  final Path stoneEdge = Path(); // their outlines, arcade arches, balustrades
  final Path timber = Path(); // shelving carcasses, cases, desks
  final Path timberLip = Path(); // uprights, shelf boards, drawer fronts
  final Path litter = Path(); // fallen books, spilled cards, moth wings
  final List<Path> spines = [
    for (var i = 0; i < _kArchSpines.length; i++) Path(),
  ];
}

// ── Primitives ───────────────────────────────────────────

void _archQuad(Path into, Offset c, double w, double h, double ang) {
  final ca = cos(ang), sa = sin(ang);
  Offset p(double x, double y) =>
      Offset(c.dx + x * ca - y * sa, c.dy + x * sa + y * ca);
  final a = p(-w / 2, -h / 2);
  final b = p(w / 2, -h / 2);
  final d = p(w / 2, h / 2);
  final e = p(-w / 2, h / 2);
  into
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(d.dx, d.dy)
    ..lineTo(e.dx, e.dy)
    ..close();
}

/// An irregular closed blob. Used for everything that was never built to a
/// shape: a lightwell, a patch of spall, a scorch.
void _archBlob(
  Path into,
  _ArchRng rng,
  Offset c,
  double rx,
  double ry, {
  int sides = 7,
}) {
  for (var k = 0; k <= sides; k++) {
    final a = k * 2 * pi / sides + rng.range(-0.18, 0.18);
    final w = rng.range(0.66, 1.3);
    final pt = Offset(c.dx + cos(a) * rx * w, c.dy + sin(a) * ry * w);
    k == 0 ? into.moveTo(pt.dx, pt.dy) : into.lineTo(pt.dx, pt.dy);
  }
  into.close();
}

/// THE GLASS FLOOR OF THE RIM. Panes of glass set in lead over the archive's
/// lightwells — the material that makes a lit leaf a floor and a dark one a
/// hole, and the reason this planet can say "glass is nothing until there is
/// light in it" and mean something you can see.
///
/// IT TOOK TWO GOES TO GET THE RIGHT KIND OF IRREGULAR. The first cut avoided
/// a lattice by drawing WANDERING LEADS — a dozen lines crossing the bay at
/// their own angles, with ties thrown off them. It has no grid in it anywhere
/// and it was worse: nothing closed, so the floor read as a sheet of random
/// SCRATCHES. The lesson is that "not a grid" is not the goal — glazing is a
/// mesh, and a mesh with nothing in common between one cell and the next is
/// exactly as far from graph paper as scribble is, and legible besides.
///
/// So it is a mesh, and every single thing about it is unequal: the rows are
/// of different depths, the columns of different widths, every vertex is
/// thrown a quarter of a cell off where it should be, and no pane in the bay
/// has the same shape as its neighbour. Some are dark (the glass is gone and
/// you are looking down the lightwell), a few still catch a gleam, and one has
/// been boarded over with a plank by somebody who gave up.
void _archGlazing(_ArchDraft d, _ArchRng rng, Rect r) {
  d.field.addRect(r);

  final cols = 4 + rng.pick(3);
  final rows = 3 + rng.pick(3);
  // Unequal divisions first, then every joint pushed off its own line.
  final xs = <double>[0];
  for (var i = 0; i < cols; i++) {
    xs.add(xs.last + rng.range(0.6, 1.6));
  }
  final ys = <double>[0];
  for (var i = 0; i < rows; i++) {
    ys.add(ys.last + rng.range(0.6, 1.6));
  }
  final grid = <List<Offset>>[];
  for (var j = 0; j <= rows; j++) {
    final row = <Offset>[];
    for (var i = 0; i <= cols; i++) {
      // Bleed a little past the bay so no pane ends neatly at the wall.
      final x = r.left - 30 + (r.width + 60) * xs[i] / xs.last;
      final y = r.top - 30 + (r.height + 60) * ys[j] / ys.last;
      row.add(
        Offset(
          x + rng.range(-1, 1) * (r.width / cols) * 0.22,
          y + rng.range(-1, 1) * (r.height / rows) * 0.22,
        ),
      );
    }
    grid.add(row);
  }

  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < cols; i++) {
      final a = grid[j][i], b = grid[j][i + 1];
      final c = grid[j + 1][i + 1], e = grid[j + 1][i];
      final pane = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(e.dx, e.dy)
        ..close();
      d.joint.addPath(pane, Offset.zero);
      final roll = rng.next();
      if (roll < 0.14) {
        // The glass has gone: this pane is the lightwell, open.
        d.wells.addPath(pane, Offset.zero);
      } else if (roll < 0.40) {
        // One still holding a gleam, inset so it reads as glass in a rebate.
        final g = Path()
          ..moveTo((a.dx + b.dx) / 2, (a.dy + b.dy) / 2)
          ..lineTo((b.dx + c.dx) / 2, (b.dy + c.dy) / 2)
          ..lineTo((c.dx + e.dx) / 2, (c.dy + e.dy) / 2);
        d.gleam.addPath(g, Offset.zero);
      }
    }
  }

  // And a pane boarded over by somebody who gave up on finding glass.
  _archQuad(
    d.timber,
    Offset(
      rng.range(r.left + 60, r.right - 60),
      rng.range(r.top + 60, r.bottom - 60),
    ),
    rng.range(60, 110),
    rng.range(34, 56),
    rng.range(-0.4, 0.4),
  );
}

/// THE HEART'S FLOOR — black mirror-stone in courses. Real masonry IS laid in
/// courses, so this one is allowed its rows; what keeps it off graph paper is
/// that no two courses are the same depth, no slab is the same length as its
/// neighbour, the joints never line up between courses, and the polish is only
/// on the slabs that still have any.
///
/// The first cut ruled ONE LINE THE WHOLE WIDTH of the room per course, which
/// is what a bricklayer's diagram does and not what a floor does: it read as a
/// brick wall lying down. A course line is drawn per SLAB now, with its own
/// half-pixel of drift, and roughly a fifth of them are simply not there —
/// because the joint you can see is the one that has opened, and they do not
/// all open.
void _archPaving(_ArchDraft d, _ArchRng rng, Rect r) {
  d.field.addRect(r);
  var y = r.top - rng.range(0, 40);
  while (y < r.bottom) {
    final h = rng.range(40, 84);
    var x = r.left - rng.range(0, 120);
    while (x < r.right) {
      final w = rng.range(80, 240);
      final drift = rng.range(-2.5, 2.5);
      // The joint down the right-hand end of this slab. Drawn, never the slab
      // — a joint is a line of shadow and the slab is the floor.
      if (rng.chance(0.82)) {
        d.joint
          ..moveTo(x + w, y + drift)
          ..lineTo(x + w + rng.range(-2, 2), y + h + drift);
      }
      // The course joint, per slab and only where it has opened.
      if (rng.chance(0.72)) {
        d.joint
          ..moveTo(x, y + drift)
          ..lineTo(
            x + w * rng.range(0.7, 1.0),
            y + drift + rng.range(-1.5, 1.5),
          );
      }
      // Polish: a single bright edge along one side of about half the slabs,
      // which is what makes a floor read as mirror-stone rather than tile.
      if (rng.chance(0.45)) {
        final inset = rng.range(4, 12);
        d.gleam
          ..moveTo(x + inset, y + drift + inset)
          ..lineTo(x + w - rng.range(8, 60), y + drift + inset);
      }
      if (rng.chance(0.07)) {
        // A slab that has spalled through to whatever is under the archive.
        _archBlob(
          d.wells,
          rng,
          Offset(x + w / 2, y + h / 2),
          w * 0.24,
          h * 0.26,
          sides: 6,
        );
      }
      x += w;
    }
    y += h;
  }
}

/// ONE RUN OF SHELVING, seen from above: the thing this whole planet is about.
///
/// It is deliberately not a tidy object. The carcass BOWS (three centuries of
/// load), the bays inside it are of unequal width, roughly a fifth of them
/// hold nothing at all, the full ones are full to different depths, and the
/// last books in a half-empty bay have slumped over. Every run also throws a
/// hard shadow toward the heart, because the beacons all stand on the rim and
/// throw inward, and that shadow is the only reason the archive is solvable.
void _archStackRun(
  _ArchDraft d,
  _ArchRng rng,
  Offset from,
  Offset to, {
  required double depth,
  double filled = 0.80,
}) {
  final v = to - from;
  final len = v.distance;
  if (len < 30) return;
  final dir = v / len;
  final nrm = Offset(-dir.dy, dir.dx);
  final ang = atan2(dir.dy, dir.dx);
  final sag = rng.range(-9, 9);
  final mid = from + dir * (len / 2) + nrm * sag;

  Offset at(double t, double off) {
    final u = 1 - t;
    final p = from * (u * u) + mid * (2 * u * t) + to * (t * t);
    return p + nrm * off;
  }

  final body = Path();
  var p0 = at(0, -depth / 2);
  body.moveTo(p0.dx, p0.dy);
  for (var k = 1; k <= 8; k++) {
    final p = at(k / 8, -depth / 2);
    body.lineTo(p.dx, p.dy);
  }
  for (var k = 8; k >= 0; k--) {
    final p = at(k / 8, depth / 2);
    body.lineTo(p.dx, p.dy);
  }
  body.close();
  // The shadow first, offset toward the heart. It is a copy of the carcass,
  // not a soft smear — a hard edge is the archive's whole vocabulary.
  d.cast.addPath(body, Offset(4, depth * 0.75));
  d.timber.addPath(body, Offset.zero);

  // The shelf boards down each face.
  for (final lane in const [-0.40, 0.40]) {
    final board = Path();
    p0 = at(0, depth * lane);
    board.moveTo(p0.dx, p0.dy);
    for (var k = 1; k <= 8; k++) {
      final p = at(k / 8, depth * lane);
      board.lineTo(p.dx, p.dy);
    }
    d.timberLip.addPath(board, Offset.zero);
  }

  var t = 0.0;
  while (t < 0.999) {
    final bay = rng.range(40, 92) / len;
    final t1 = (t + bay).clamp(0.0, 1.0);
    // The upright between this bay and the next.
    final u0 = at(t1, -depth / 2), u1 = at(t1, depth / 2);
    d.timberLip
      ..moveTo(u0.dx, u0.dy)
      ..lineTo(u1.dx, u1.dy);
    if (rng.chance(filled)) {
      final full = rng.range(0.30, 1.0);
      for (final lane in const [-0.26, 0.26]) {
        var s = t;
        final end = t + (t1 - t) * full;
        while (s < end) {
          final w = rng.range(4.0, 11.0);
          _archQuad(
            d.spines[rng.pick(_kArchSpines.length)],
            at(s + (w / 2) / len, depth * lane),
            w,
            depth * 0.30,
            ang,
          );
          s += (w + rng.range(0.8, 3.0)) / len;
        }
        // The last few in a half-empty bay have gone over.
        if (full < 0.75 && rng.chance(0.6)) {
          for (var k = 0; k < 3; k++) {
            _archQuad(
              d.spines[rng.pick(_kArchSpines.length)],
              at(end + (k * 5.0) / len, depth * lane),
              rng.range(7, 13),
              depth * 0.28,
              ang + rng.range(0.5, 1.1),
            );
          }
        }
      }
    }
    t = t1;
  }
}

/// A case, a cabinet, a press or a desk: one low box of oak, standing at its
/// own angle, with its front divided unevenly and a hard shadow under it.
void _archCase(
  _ArchDraft d,
  _ArchRng rng,
  Offset c,
  double w,
  double h,
  double ang, {
  int fronts = 3,
  bool shuttered = false,
}) {
  _archQuad(d.cast, c + Offset(3, h * 0.55), w, h, ang);
  _archQuad(d.timber, c, w, h, ang);
  final ca = cos(ang), sa = sin(ang);
  Offset p(double x, double y) =>
      Offset(c.dx + x * ca - y * sa, c.dy + x * sa + y * ca);
  if (shuttered) {
    // A case kept SHUT. The batten across it is the whole reading of this
    // building: what it owns, it owns in the dark.
    final a = p(-w / 2 + 3, -h / 2 + 3), b = p(w / 2 - 3, h / 2 - 3);
    final e = p(w / 2 - 3, -h / 2 + 3), f = p(-w / 2 + 3, h / 2 - 3);
    d.timberLip
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..moveTo(e.dx, e.dy)
      ..lineTo(f.dx, f.dy);
    return;
  }
  // Unequal fronts, because nothing in here was made in one shop.
  var x = -w / 2;
  for (var i = 0; i < fronts; i++) {
    x += w / fronts * rng.range(0.7, 1.3);
    if (x > w / 2 - 4) break;
    final a = p(x, -h / 2 + 2), b = p(x, h / 2 - 2);
    d.timberLip
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy);
  }
  // One drawer left hanging out, somewhere.
  if (rng.chance(0.35)) {
    _archQuad(
      d.timber,
      p(rng.range(-w / 3, w / 3), h * rng.range(0.5, 0.8)),
      w / fronts * 0.9,
      h * 0.55,
      ang + rng.range(-0.2, 0.2),
    );
  }
}

/// A pier, a column, a plinth. Base, drum, and the hard little shadow that
/// says the thing has height.
void _archPier(_ArchDraft d, _ArchRng rng, Offset c, double r) {
  _archQuad(
    d.cast,
    c + Offset(3, r * 1.0),
    r * 2.1,
    r * 2.1,
    rng.range(-0.1, 0.1),
  );
  _archQuad(d.stoneFill, c, r * 2.1, r * 2.1, rng.range(-0.08, 0.08));
  d.stoneEdge.addOval(Rect.fromCircle(center: c, radius: r));
  d.stoneFill.addOval(Rect.fromCircle(center: c, radius: r * 0.82));
}

/// A run of arcading along a wall: piers at unequal intervals with an arch
/// springing between each pair.
///
/// The first cut spaced them evenly and drew them all the same size, and the
/// gallery came back as a ROW OF IDENTICAL GREY SQUARES down each long wall —
/// the graph-paper failure in its other costume, because a regular row is a
/// grid one cell deep. Every pier now has its own girth, sits its own distance
/// off the wall line, and about a fifth of them have gone entirely (with the
/// arch that sprang from them taken with it).
void _archArcade(
  _ArchDraft d,
  _ArchRng rng,
  Offset from,
  Offset to,
  double bulge,
) {
  final v = to - from;
  final len = v.distance;
  final dir = v / len;
  final nrm = Offset(-dir.dy, dir.dx) * bulge.sign;
  var s = rng.range(10, 46);
  Offset? prev;
  while (s < len - 20) {
    final at = from + dir * s + nrm * rng.range(-9, 9);
    if (rng.chance(0.80)) {
      _archPier(d, rng, at, rng.range(8, 23));
      if (prev != null) {
        final m = (prev + at) / 2 + nrm * bulge.abs() * rng.range(0.6, 1.4);
        d.stoneEdge
          ..moveTo(prev.dx, prev.dy)
          ..quadraticBezierTo(m.dx, m.dy, at.dx, at.dy);
      }
      prev = at;
    } else {
      // A bay of the arcade that has come down: its springing stone only.
      d.litter.addOval(Rect.fromCircle(center: at, radius: rng.range(5, 11)));
      prev = null;
    }
    s += rng.range(58, 148);
  }
}

/// Fallen books, spilled cards, moth wings — the floor of a place nobody has
/// swept. Scattered, never on a grid, and kept out of [keepClear].
void _archLitter(
  _ArchDraft d,
  _ArchRng rng,
  Rect r,
  int n, {
  double size = 8,
  Rect? keepClear,
}) {
  for (var i = 0; i < n; i++) {
    final c = Offset(rng.range(r.left, r.right), rng.range(r.top, r.bottom));
    if (keepClear != null && keepClear.contains(c)) continue;
    _archQuad(
      d.litter,
      c,
      size * rng.range(0.6, 1.6),
      size * rng.range(0.4, 1.0),
      rng.range(0, pi),
    );
  }
}

// ── The nine bays ────────────────────────────────────────

_ArchiveGround _buildArchiveGround(String roomId, Rect bounds) {
  // Seeded off the room's own size and name: deterministic everywhere, and
  // different in every bay.
  final seed =
      (bounds.width.round() * 73856093) ^
      (bounds.height.round() * 19349663) ^
      roomId.codeUnits.fold<int>(7, (a, c) => a * 131 + c);
  final rng = _ArchRng(seed);
  final stage = bounds.deflate(8);
  final d = _ArchDraft();
  final inner = stage.deflate(4);
  double? stackLine;

  // The rim bays stand on glass over the lightwells; the heart on black
  // mirror-stone. That is not decoration — it is what every sill in the hall
  // is made of, and the floor should say so before a hint does.
  const heart = {
    'oculus_stair',
    'sunless_reliquary',
    'reading_floor',
    'solarin_oculus',
  };
  final glass = !heart.contains(roomId);
  if (glass) {
    _archGlazing(d, rng, inner);
  } else {
    _archPaving(d, rng, inner);
  }

  switch (roomId) {
    // ── THE LUMEN THRESHOLD ──────────────────────────────
    // A porch, not a room: the great door behind you, the fallen lintel on the
    // floor, and the archive opening out past it. Nothing stands in sector 0,
    // so there is deliberately NO stack here — the bay that teaches you what a
    // shadow costs is the one bay that cannot make one.
    case 'lumen_threshold':
      // The threshold band, worn hollow by everyone who ever came in.
      _archQuad(
        d.stoneFill,
        Offset(inner.center.dx, inner.top + 34),
        inner.width * 0.92,
        58,
        0,
      );
      d.wells.addOval(
        Rect.fromCenter(
          center: Offset(inner.center.dx, inner.top + 40),
          width: inner.width * 0.42,
          height: 26,
        ),
      );
      // The door jambs, either end of the fallen lintel.
      _archPier(d, rng, Offset(232, 96), 19);
      _archPier(d, rng, Offset(470, 96), 19);
      // Book presses chained along the side walls, well clear of the beacon.
      _archCase(d, rng, const Offset(70, 120), 46, 104, 0.06, fronts: 4);
      _archCase(d, rng, const Offset(66, 380), 44, 92, -0.09, fronts: 3);
      _archCase(d, rng, const Offset(660, 120), 44, 96, -0.05, fronts: 3);
      _archCase(d, rng, const Offset(668, 392), 48, 84, 0.11, fronts: 4);
      // The returns cart, abandoned mid-round.
      _archCase(d, rng, const Offset(190, 400), 74, 38, 0.5, fronts: 3);
      // THE WORN WAYS. Three centuries of feet have polished the glass pale
      // between the door and the three ways out of this bay — which is the
      // one thing in the archive that will tell a first-time player where the
      // room's exits are before a single beacon has been touched.
      for (final way in const [
        [360.0, 470.0, 120.0], // in through the undercroft
        [660.0, 250.0, 104.0], // east, onto the rim
        [60.0, 250.0, 104.0], // west, round the lightwell
      ]) {
        final from = const Offset(360, 96);
        final to = Offset(way[0], way[1]);
        final v = to - from;
        final n = Offset(-v.dy, v.dx) / v.distance * (way[2] / 2);
        d.sheen
          ..moveTo(from.dx + n.dx * 0.55, from.dy + n.dy * 0.55)
          ..lineTo(to.dx + n.dx, to.dy + n.dy)
          ..lineTo(to.dx - n.dx, to.dy - n.dy)
          ..lineTo(from.dx - n.dx * 0.55, from.dy - n.dy * 0.55)
          ..close();
      }
      // Two more presses down the sides, and the benches nobody sits on.
      _archCase(d, rng, const Offset(72, 250), 40, 88, -0.03, fronts: 3);
      _archCase(d, rng, const Offset(650, 250), 38, 80, 0.04, fronts: 3);
      _archCase(d, rng, const Offset(216, 296), 66, 22, 0.07, fronts: 1);
      _archCase(d, rng, const Offset(512, 304), 72, 22, -0.05, fronts: 1);
      _archLitter(d, rng, const Rect.fromLTWH(60, 300, 560, 160), 26);
      _archLitter(d, rng, const Rect.fromLTWH(250, 110, 220, 60), 12, size: 6);
      break;

    // ── THE SHADOW COURT ─────────────────────────────────
    // The court under the first great stack: a balustraded reading court with
    // four effigies standing on its rail, a broken oriel in the east wall with
    // the beacon set in it, and the court's own shelving collapsed into the
    // south-west corner where the slip lies.
    case 'shadow_court':
      // THE GREAT STACK of sector 1. It stands across the bay's inward half,
      // which is exactly what the arithmetic says it does: light broken on
      // this is what keeps the heartway open.
      stackLine = 380; // the stack's inward face, where its shadow begins
      _archStackRun(
        d,
        rng,
        const Offset(40, 356),
        const Offset(430, 348),
        depth: 40,
        filled: 0.85,
      );
      _archStackRun(
        d,
        rng,
        const Offset(452, 366),
        const Offset(676, 344),
        depth: 34,
        filled: 0.6,
      );
      // THE BALUSTRADE — an ellipse of rail round the court, with the four
      // effigies standing on it. Two stretches of it have gone.
      final bc = const Offset(330, 228);
      const brx = 208.0, bry = 118.0;
      var a = rng.range(0, 1.0);
      while (a < 2 * pi) {
        final step = rng.range(0.13, 0.26);
        // Two stretches of it have gone over the edge, which is why the walk
        // round the court is a walk and not a lap.
        if (!rng.chance(0.22)) {
          Offset on(double t) =>
              Offset(bc.dx + cos(t) * brx, bc.dy + sin(t) * bry);
          final at = on(a), nx = on(a + step);
          d.stoneFill.addOval(
            Rect.fromCircle(center: at, radius: rng.range(5, 8)),
          );
          // The RAIL, as a filled band between the balusters. Stroked, it came
          // back as a dotted necklace with nothing joining the beads.
          final v = nx - at;
          final n = Offset(-v.dy, v.dx) / v.distance * 2.6;
          d.stoneFill
            ..moveTo(at.dx + n.dx, at.dy + n.dy)
            ..lineTo(nx.dx + n.dx, nx.dy + n.dy)
            ..lineTo(nx.dx - n.dx, nx.dy - n.dy)
            ..lineTo(at.dx - n.dx, at.dy - n.dy)
            ..close();
        }
        a += step;
      }
      // The plinths the effigies stand on. They are const positions, so the
      // stone under each one can be part of the court's own fabric.
      for (final e in kCourtEffigies) {
        _archQuad(d.cast, e.position + const Offset(4, 16), 34, 22, 0);
        _archQuad(d.stoneFill, e.position + const Offset(0, 12), 32, 20, 0);
        _archQuad(d.stoneEdge, e.position + const Offset(0, 12), 32, 20, 0);
      }
      // THE ORIEL — the broken window the oriel beacon is set in, splayed into
      // the east wall beside the beacon's post.
      _archQuad(d.stoneFill, const Offset(680, 260), 44, 150, 0);
      d.wells.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(682, 260),
            width: 26,
            height: 122,
          ),
          const Radius.circular(9),
        ),
      );
      d.gleam
        ..moveTo(672, 206)
        ..lineTo(672, 314);
      // The court's own shelving, gone over into the south-west corner, which
      // is where the slip is filed.
      _archStackRun(
        d,
        rng,
        const Offset(54, 430),
        const Offset(230, 392),
        depth: 30,
        filled: 0.35,
      );
      _archLitter(d, rng, Rect.fromLTWH(46, 340, 260, 110), 26);
      break;

    // ── THE MOTH GALLERY ─────────────────────────────────
    // The arcade under the second great stack, where the wardens roost. Two
    // runs of arcading along the long walls, the great stack filling the
    // gallery's inward side, and moth-scale over everything.
    case 'moth_gallery':
      _archArcade(d, rng, const Offset(40, 60), const Offset(760, 52), 26);
      _archArcade(d, rng, const Offset(40, 448), const Offset(760, 456), -26);
      stackLine = 390; // as the court: the far side of the books
      _archStackRun(
        d,
        rng,
        const Offset(60, 366),
        const Offset(390, 352),
        depth: 42,
        filled: 0.7,
      );
      _archStackRun(
        d,
        rng,
        const Offset(420, 358),
        const Offset(752, 372),
        depth: 38,
        filled: 0.55,
      );
      // A shorter run up under the north arcade, where the gallery's own
      // slip is filed.
      _archStackRun(
        d,
        rng,
        const Offset(540, 128),
        const Offset(756, 140),
        depth: 34,
        filled: 0.5,
      );
      // THE ROOST. Cocoons hung off the arcading, and a floor of wings.
      for (var i = 0; i < 14; i++) {
        final c = Offset(
          rng.range(60, 750),
          rng.chance(0.5) ? rng.range(66, 92) : rng.range(420, 448),
        );
        d.litter.addOval(
          Rect.fromCenter(
            center: c,
            width: rng.range(7, 14),
            height: rng.range(12, 22),
          ),
        );
      }
      // Two carrels off the walk, a case gone over, and the gallery's own
      // lectern — all of it well clear of the line between the two leaves,
      // because the arcade is a bay you can only be in while a light is
      // holding it and it must stay quick to cross.
      _archCase(d, rng, const Offset(150, 140), 96, 40, 0.14, fronts: 2);
      _archCase(d, rng, const Offset(276, 148), 30, 30, 0.0, fronts: 1);
      _archCase(d, rng, const Offset(158, 398), 104, 38, -0.11, fronts: 2);
      _archCase(d, rng, const Offset(392, 414), 58, 44, 0.92, fronts: 3);
      _archCase(d, rng, const Offset(690, 268), 40, 96, -0.04, fronts: 3);
      _archLitter(d, rng, const Rect.fromLTWH(50, 100, 700, 300), 34, size: 7);
      break;

    // ── THE DARK STACKS ──────────────────────────────────
    // Out past both great stacks, where nothing occludes for you any more —
    // and the densest room in the archive. Runs on both sides of one aisle, at
    // their own angles, of their own lengths, leaning into each other where
    // the floor has moved. No stack in here is the same as any other stack,
    // because a stack that matched its neighbour would put the whole room back
    // on graph paper.
    case 'dark_stacks':
      // No stackLine: sector 3 has nothing standing in it, so low and high
      // are the same beam here and the inward band is never in shadow while
      // the rim is lit. There is no bite to place, which is the lesson of the
      // room — out past both great stacks nothing occludes for you any more.
      for (final band in const [
        [46.0, 186.0],
        [334.0, 482.0],
      ]) {
        var x = rng.range(56, 96);
        while (x < 740) {
          final lean = rng.range(-0.19, 0.19);
          final top = band[0] + rng.range(0, 26);
          final bot = band[1] - rng.range(0, 34);
          final h = bot - top;
          // A run that has gone over leans hard into its neighbour.
          final over = rng.chance(0.18);
          _archStackRun(
            d,
            rng,
            Offset(x, top),
            Offset(x + sin(lean) * h + (over ? rng.range(26, 46) : 0), bot),
            depth: rng.range(26, 40),
            filled: over ? 0.3 : rng.range(0.55, 0.9),
          );
          x += rng.range(58, 128);
        }
      }
      // The aisle, worn pale by three centuries of feet.
      d.sheen.addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(30, 214, 720, 94),
          const Radius.circular(30),
        ),
      );
      // Books off the shelves, thickest where the light never comes.
      _archLitter(d, rng, Rect.fromLTWH(40, 40, 700, 150), 30, size: 9);
      _archLitter(d, rng, Rect.fromLTWH(40, 330, 700, 150), 34, size: 9);
      break;

    // ── THE CATALOGUE WALK ───────────────────────────────
    // What the archive knows ABOUT itself: banks of card cabinets along both
    // walls, a ledger counter down the east end, and a drift of spilled cards
    // where somebody pulled a drawer in a hurry and never came back for them.
    case 'catalogue_walk':
      var x = rng.range(40, 80);
      while (x < 700) {
        final w = rng.range(70, 150);
        _archCase(
          d,
          rng,
          Offset(x + w / 2, rng.range(58, 78)),
          w,
          rng.range(40, 56),
          rng.range(-0.07, 0.07),
          fronts: 3 + rng.pick(3),
        );
        x += w + rng.range(8, 46);
      }
      x = rng.range(40, 90);
      while (x < 690) {
        final w = rng.range(64, 140);
        _archCase(
          d,
          rng,
          Offset(x + w / 2, rng.range(424, 446)),
          w,
          rng.range(38, 54),
          rng.range(-0.08, 0.08),
          fronts: 3 + rng.pick(3),
        );
        x += w + rng.range(10, 52);
      }
      // One bank toppled right over into the walk.
      _archCase(d, rng, const Offset(140, 168), 132, 46, 1.24, fronts: 5);
      // The ledger counter, and the lectern on it.
      _archCase(d, rng, const Offset(684, 250), 46, 200, 0.03, fronts: 2);
      _archCase(d, rng, const Offset(612, 168), 64, 44, -0.35, fronts: 1);
      // The cards, out of the drawers and all over the floor.
      _archLitter(d, rng, Rect.fromLTWH(70, 110, 560, 90), 46, size: 6);
      _archLitter(d, rng, Rect.fromLTWH(70, 360, 600, 70), 34, size: 6);
      break;

    // ── THE OCULUS STAIR ─────────────────────────────────
    // The middle of the hall, and the one bay light has never been thrown
    // into. It is the bottom of the archive: a stepped ring of mirror-stone
    // falling away to a landing, with the oculus itself far overhead and only
    // the ghost of it reaching the floor.
    case 'oculus_stair':
      final c = inner.center;
      // The flight: three shallow rings of step, spalled and broken, drawn as
      // step NOSINGS rather than concentric circles — a stair is read off its
      // edges.
      // Four flights, and no two of them struck from quite the same centre or
      // squashed by quite the same amount — four perfect concentric ellipses
      // is a target, not a stair.
      for (var ring = 0; ring < 4; ring++) {
        final rr = 300.0 - ring * 52 + rng.range(-14, 14);
        final squash = rng.range(0.66, 0.80);
        final off = Offset(rng.range(-10, 10), rng.range(-8, 8));
        var ang = rng.range(0, 1.0);
        while (ang < 2 * pi) {
          final arc = rng.range(0.5, 1.2);
          if (!rng.chance(0.16)) {
            // A stair is read off its NOSINGS, so what is drawn is the edge of
            // each tread and the shadow the tread below it is in. Both are
            // STROKES: pushing an open arc into a filled path closes it across
            // the chord, and the first cut of this room came back as a black
            // whirlpool because of exactly that.
            const steps = 10;
            final p = Path();
            for (var k = 0; k <= steps; k++) {
              final t = ang + arc * k / steps;
              final pt = Offset(
                c.dx + off.dx + cos(t) * rr,
                c.dy + off.dy + sin(t) * rr * squash,
              );
              k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
            }
            d.stoneEdge.addPath(p, Offset.zero);
            d.castLine.addPath(p, const Offset(0, 6));
          }
          ang += arc + rng.range(0.04, 0.2);
        }
      }
      // The ghost of the oculus on the landing — the only light in the heart,
      // and it is not enough to read by.
      d.sheen.addOval(Rect.fromCenter(center: c, width: 250, height: 170));
      d.gleam.addOval(Rect.fromCenter(center: c, width: 250, height: 170));
      // The hall's own plan, inlaid in brass at the foot of the stair: five
      // sectors and two bands, worn to nothing on the side people walk.
      for (var i = 0; i < 5; i++) {
        final t = -pi / 2 + i * 2 * pi / 5;
        if (rng.chance(0.3)) continue;
        d.gleam
          ..moveTo(c.dx + cos(t) * 42, c.dy + sin(t) * 30)
          ..lineTo(c.dx + cos(t) * 116, c.dy + sin(t) * 82);
      }
      d.gleam.addOval(Rect.fromCenter(center: c, width: 90, height: 64));
      _archLitter(d, rng, inner.deflate(30), 18, size: 8);
      break;

    // ── THE SUNLESS RELIQUARY ────────────────────────────
    // A shrine standing in plain sight, and a ring of cases round it with
    // their shutters shut. The whole room is the archive's own answer to its
    // own rule: what it values, it keeps where the light cannot get at it.
    case 'sunless_reliquary':
      final shrine = const Offset(260, 170);
      _archQuad(d.cast, shrine + const Offset(5, 12), 152, 116, 0);
      _archQuad(d.stoneFill, shrine, 148, 112, 0);
      _archQuad(d.stoneEdge, shrine, 148, 112, 0);
      _archQuad(d.stoneEdge, shrine, 112, 82, 0);
      // The four colonnettes of the canopy, at the corners of the step.
      for (final o in const [
        Offset(-62, -46),
        Offset(62, -46),
        Offset(-62, 46),
        Offset(62, 46),
      ]) {
        _archPier(d, rng, shrine + o, 10);
      }
      // The cases, shut. Unequal, at their own angles, all round the wall.
      _archCase(d, rng, const Offset(60, 48), 76, 34, 0.10, shuttered: true);
      _archCase(d, rng, const Offset(58, 290), 66, 32, -0.13, shuttered: true);
      _archCase(d, rng, const Offset(196, 36), 84, 30, 0.05, shuttered: true);
      _archCase(d, rng, const Offset(330, 42), 70, 32, -0.07, shuttered: true);
      _archCase(d, rng, const Offset(392, 160), 34, 92, 0.04, shuttered: true);
      _archCase(d, rng, const Offset(222, 306), 92, 30, 0.08, shuttered: true);
      _archCase(d, rng, const Offset(352, 296), 62, 34, -0.16, shuttered: true);
      _archLitter(d, rng, Rect.fromLTWH(30, 80, 380, 200), 14, size: 7);
      break;

    // ── THE READING FLOOR ────────────────────────────────
    // The room the archive was built for: desks round the walls, stools, the
    // chains the books are still on, the prism oriel in the west wall and the
    // shutter-ring's own gear housing sunk into the floor by the east.
    case 'reading_floor':
      for (final desk in const [
        [120.0, 90.0, 190.0, 44.0, 0.06],
        [380.0, 74.0, 160.0, 42.0, -0.05],
        [640.0, 120.0, 46.0, 190.0, 0.03],
        [660.0, 420.0, 170.0, 44.0, -0.09],
        [360.0, 470.0, 200.0, 44.0, 0.04],
        [110.0, 430.0, 150.0, 42.0, 0.12],
        [96.0, 268.0, 44.0, 150.0, -0.03],
      ]) {
        final c = Offset(desk[0], desk[1]);
        _archCase(d, rng, c, desk[2], desk[3], desk[4], fronts: 2);
        // The stools, and one of them pushed back.
        final along = desk[2] > desk[3];
        for (var k = 0; k < 3; k++) {
          final off = (k - 1) * (along ? desk[2] : desk[3]) * 0.33;
          final at = along
              ? c + Offset(off, desk[3] * rng.range(0.75, 1.15))
              : c + Offset(desk[2] * rng.range(0.75, 1.15), off);
          d.timber.addOval(
            Rect.fromCircle(center: at, radius: rng.range(8, 11)),
          );
        }
        // A chained book, and the chain.
        if (rng.chance(0.7)) {
          final at = c + Offset(rng.range(-20, 20), rng.range(-8, 8));
          _archQuad(
            d.spines[rng.pick(_kArchSpines.length)],
            at,
            20,
            14,
            rng.range(-0.4, 0.4),
          );
          // The chain, to the ROD ON THIS DESK. Run to the desk's far end it
          // came out as a diagonal line across the room, which read as a
          // scratch rather than as the thing holding the book down.
          d.timberLip
            ..moveTo(at.dx, at.dy)
            ..lineTo(at.dx + rng.range(-18, 18), at.dy + rng.range(-14, 14));
        }
        // The desk's own slope, which is what makes it a reading desk and not
        // a table.
        d.timberLip
          ..moveTo(c.dx - desk[2] * 0.42, c.dy)
          ..lineTo(c.dx + desk[2] * 0.42, c.dy);
      }
      // THE PRISM ORIEL — a splayed window reveal in the west wall, with its
      // mullion still standing. Conduit A is set in it.
      _archQuad(d.stoneFill, const Offset(226, 280), 58, 160, 0);
      d.wells.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(230, 280),
            width: 34,
            height: 132,
          ),
          const Radius.circular(10),
        ),
      );
      d.gleam
        ..moveTo(214, 214)
        ..lineTo(214, 346)
        ..moveTo(230, 214)
        ..lineTo(230, 346);
      // THE RING'S HOUSING: the track it turns in, sunk flush in the floor.
      d.stoneEdge.addOval(
        Rect.fromCircle(center: const Offset(560, 280), radius: 44),
      );
      d.stoneEdge.addOval(
        Rect.fromCircle(center: const Offset(560, 280), radius: 30),
      );
      d.cast.addOval(
        Rect.fromCircle(center: const Offset(560, 280), radius: 30),
      );
      // The winch post that drives it.
      _archPier(d, rng, const Offset(628, 316), 13);
      _archLitter(d, rng, Rect.fromLTWH(160, 150, 560, 260), 20, size: 8);
      break;

    // ── SOLARIN'S OCULUS ─────────────────────────────────
    // A drum under the hall's one eye. The CENTRE IS EMPTY on purpose — it is
    // the only arena on this planet and the fight is a fight about where you
    // stand — so everything drawn is either round the wall or under foot: the
    // oculus ring inlaid in the floor, the three pillars' own footings, and
    // the burnt arcs of every sweep the glare has ever made.
    case 'solarin_oculus':
      final o = Offset(inner.center.dx, inner.center.dy - 10);
      // THE DRUM WALL. Twenty-six evenly-spaced piers came back as a necklace
      // of identical grey beads — the same regularity failure the arcade had,
      // bent into a circle, and if anything worse for being closed. What is
      // drawn now is the WALL: two rings of masonry with the voussoir joints
      // ticked across them at unequal intervals, and only seven piers standing
      // against it, each its own size and none of them opposite another.
      final drum = Rect.fromCenter(
        center: o,
        width: inner.width * 0.96,
        height: inner.height * 0.96,
      );
      d.stoneEdge.addOval(drum);
      d.stoneEdge.addOval(drum.deflate(28));
      var vt = rng.range(0, 0.4);
      while (vt < 2 * pi) {
        d.stoneEdge
          ..moveTo(
            o.dx + cos(vt) * drum.width / 2,
            o.dy + sin(vt) * drum.height / 2,
          )
          ..lineTo(
            o.dx + cos(vt) * (drum.width / 2 - 28),
            o.dy + sin(vt) * (drum.height / 2 - 28),
          );
        vt += rng.range(0.11, 0.30);
      }
      for (var i = 0; i < 7; i++) {
        final t = rng.range(0, 2 * pi);
        _archPier(
          d,
          rng,
          Offset(
            o.dx + cos(t) * drum.width * rng.range(0.40, 0.46),
            o.dy + sin(t) * drum.height * rng.range(0.40, 0.46),
          ),
          rng.range(11, 26),
        );
      }
      // THE OCULUS, inlaid: the eye overhead, as a ring of pale stone in the
      // floor directly under it.
      d.sheen.addOval(Rect.fromCenter(center: o, width: 330, height: 250));
      d.gleam.addOval(Rect.fromCenter(center: o, width: 330, height: 250));
      d.gleam.addOval(Rect.fromCenter(center: o, width: 274, height: 206));
      // THE PILLARS' FOOTINGS — the three the fight is about, drawn as stone
      // in the floor so they read as part of the building.
      for (final p in const [
        Offset(200, 430),
        Offset(450, 500),
        Offset(700, 430),
      ]) {
        _archQuad(d.stoneEdge, p, 62, 62, 0);
        _archQuad(d.stoneEdge, p, 46, 46, 0.78);
      }
      // THE SCORCH. Every sweep the glare has made, burnt into the mirror-
      // stone as broken arcs at their own radii — the room's history, and the
      // only warning it gives.
      for (var i = 0; i < 26; i++) {
        final rr = rng.range(90, 400);
        final from = rng.range(0, 2 * pi);
        final arc = rng.range(0.3, 1.5);
        final p = Path();
        for (var k = 0; k <= 10; k++) {
          final t = from + arc * k / 10;
          final pt = Offset(
            o.dx + cos(t) * rr * rng.range(0.97, 1.03),
            o.dy + sin(t) * rr * 0.74,
          );
          k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        // STROKED, and thin. Filled, each of these came out as a black lens
        // the size of a pillar; heavy, they read as claw marks. A scorch is a
        // stain a floor has half forgotten.
        d.scorch.addPath(p, Offset.zero);
      }
      _archLitter(d, rng, inner.deflate(40), 16, size: 9);
      break;
  }

  // ── Bake it ────────────────────────────────────────────
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  // Alphas hold the FLOOR TRANSLUCENCY RULE: the sky shader is this planet's
  // mood and has to keep showing through the archive's floor.
  canvas.drawPath(
    d.field,
    Paint()
      ..color = (glass ? _kArchGlass : _kArchMirror).withValues(alpha: 0.58),
  );
  canvas.drawPath(d.wells, Paint()..color = _kArchWell.withValues(alpha: 0.40));
  canvas.drawPath(
    d.sheen,
    Paint()..color = const Color(0xFFFFF6DC).withValues(alpha: 0.055),
  );
  canvas.drawPath(
    d.joint,
    Paint()
      ..color = _kArchLead.withValues(alpha: glass ? 0.15 : 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glass ? 1.7 : 1.1,
  );
  canvas.drawPath(
    d.gleam,
    Paint()
      ..color = const Color(0xFFFFF6DC).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );
  canvas.drawPath(
    d.cast,
    Paint()..color = const Color(0xFF14120E).withValues(alpha: 0.44),
  );
  canvas.drawPath(
    d.castLine,
    Paint()
      ..color = const Color(0xFF14120E).withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    d.scorch,
    Paint()
      ..color = const Color(0xFF2A1A0E).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    d.stoneFill,
    Paint()..color = _kArchLime.withValues(alpha: 0.47),
  );
  canvas.drawPath(d.timber, Paint()..color = _kArchOak.withValues(alpha: 0.82));
  for (var i = 0; i < d.spines.length; i++) {
    canvas.drawPath(
      d.spines[i],
      Paint()..color = _kArchSpines[i].withValues(alpha: 0.72),
    );
  }
  canvas.drawPath(
    d.timberLip,
    Paint()
      ..color = _kArchOakLip.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4,
  );
  canvas.drawPath(
    d.stoneEdge,
    Paint()
      ..color = _kArchLime.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  canvas.drawPath(
    d.litter,
    Paint()..color = const Color(0xFFB6A98C).withValues(alpha: 0.26),
  );

  return _ArchiveGround(
    clip: RRect.fromRectAndRadius(
      stage,
      const Radius.circular(_kArchStageRadius),
    ),
    fabric: rec.endRecording(),
    stackLine: stackLine,
    motes: [
      for (var i = 0; i < 20; i++)
        Offset(
          rng.range(bounds.left, bounds.right),
          rng.range(bounds.top, bounds.bottom),
        ),
    ],
  );
}
