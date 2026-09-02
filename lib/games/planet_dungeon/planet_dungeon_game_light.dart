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
        ? 'Nothing in the glass — $where is dark'
        : 'Glare off the whole shelf — $where is lit';
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
    _setHint('The shutter folds back — and the archive is one room, all of it');
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
        _setHint('Read already — ${e.truth}');
        return true;
      }
      if (a.member.element != e.element) {
        _setBlockedHint('This one answers ${e.element}');
        return true;
      }
      if (archive.isDark(e.stand)) {
        _setBlockedHint(
          'No light on it — ${sectorWord(e.stand.sector)} is dark',
        );
        return true;
      }
      if (archive.isLit(e.niche)) {
        _setBlockedHint(
          'Nowhere for its shadow — ${sectorWord(e.niche.sector)} is lit',
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
          'Too much of you showing — ${archive.lumens} lumens on the hall',
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
        _setHint('Out it comes — ${s.line}', 3.4);
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
        'The ring will not turn — it answers only a bearer of the '
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
      return 'Solarin\'s Oculus — the last star is behind a thing that looks '
          'at you';
    }
    if (room.hall?.shutterRing != null) {
      return 'The Reading Floor — the rite waits on the oriel and the ring';
    }
    if (room.hall?.balustrade != null) {
      return hasStar(room.hall!.starIndex!)
          ? null
          : 'The Shadow Court — four effigies, and every one of them lying';
    }
    if (room.hall?.starIndex == 1) {
      return hasStar(1)
          ? null
          : 'The Dark Stacks — something is filed where the light does not go';
    }
    if (room.vaultCache != null) {
      return 'The Sunless Reliquary — the essence has been in plain sight the '
          'whole run';
    }
    if (archiveSlipsIn(room.id).isNotEmpty && !hasStar(1)) {
      return '${_archiveRoomWord(room.id)} — a slip lies behind the shelves';
    }
    if (archiveBeaconIn(room.id) != null) {
      return 'A beacon stands here, and the hall is whatever it says';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Lumen Threshold — three ways on, and no two of them the same '
                'kind of floor'
          : 'The Lumen Threshold — the doorway is folded shut';
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
              'and nothing stands in the doorway to keep a shadow — so come '
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
              'two. Out here past the stacks there is nothing to break on — so '
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
              'once — and it is half the lumens besides',
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

  static const Color _kArchiveNight = Color(0xFF14120E);
  static const Color _kArchiveGold = Color(0xFFFFE082);
  static const Color _kArchiveGlare = Color(0xFFFFF6DC);
  static const Color _kArchiveSlate = Color(0xFF5A5F66);
  static const Color _kArchiveStone = Color(0xFF9A9182);

  void _renderArchive(Canvas canvas, DungeonRoom room) {
    _renderArchiveGround(canvas, room);
    _renderArchiveSills(canvas, room);
    _renderArchiveObjects(canvas, room);
    _renderArchiveGlare(canvas, room);
  }

  /// The bay's own floor, and the wedge on it. Cheap by construction: at most
  /// two filled paths and a handful of lines derived from the room's own
  /// bounds, no allocation per frame beyond the paints, and nothing that
  /// scales with the party or the enemies.
  void _renderArchiveGround(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final sector = room.hall?.sector;
    if (sector == null) return;
    final rimLit = archive.isLit(HallCell(sector, HallBand.rim));
    final inLit = archive.isLit(HallCell(sector, HallBand.inward));
    canvas.drawRect(
      b,
      Paint()..color = _kArchiveNight.withValues(alpha: rimLit ? 0.20 : 0.46),
    );
    if (!rimLit) {
      // Unlit: bare warm stone, and the joints of it barely visible.
      final joint = Paint()
        ..color = _kArchiveStone.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = 1; i < 5; i++) {
        final x = b.left + b.width * i / 5;
        canvas.drawLine(Offset(x, b.top), Offset(x, b.bottom), joint);
      }
      return;
    }
    // THE WEDGE. A fan opening from the bay's outer wall across the floor,
    // stopping short at the stack line when the inner shelf is in shadow —
    // that stop IS the occlusion, drawn.
    final apex = Offset(b.center.dx, b.top + 6);
    final depth = inLit ? b.height * 0.98 : b.height * 0.52;
    final spread = b.width * (inLit ? 0.46 : 0.34);
    final fan = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(apex.dx - spread, apex.dy + depth)
      ..lineTo(apex.dx + spread, apex.dy + depth)
      ..close();
    canvas.drawPath(
      fan,
      Paint()..color = _kArchiveGold.withValues(alpha: inLit ? 0.22 : 0.15),
    );
    canvas.drawPath(
      fan,
      Paint()
        ..color = _kArchiveGold.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (!inLit) {
      // The hard edge across the arc: the shadow's own line, and the only
      // sharp thing in the room.
      canvas.drawLine(
        Offset(apex.dx - spread, apex.dy + depth),
        Offset(apex.dx + spread, apex.dy + depth),
        Paint()
          ..color = _kArchiveGlare.withValues(alpha: 0.34)
          ..strokeWidth = 2.5,
      );
      // The great stack that is throwing it.
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(apex.dx, apex.dy + depth + 14),
          width: spread * 1.1,
          height: 16,
        ),
        Paint()..color = _kArchiveNight.withValues(alpha: 0.7),
      );
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

    // THE BEACON: a pan on a tripod, with its current fan drawn as a short
    // filled wedge off the pan and NOTHING when it is out.
    final b = archiveBeaconIn(room.id);
    if (b != null) {
      final lit = archive.settingOf(b.id);
      canvas.drawCircle(
        b.post,
        11,
        Paint()
          ..color = lit == null
              ? _kArchiveStone.withValues(alpha: 0.55)
              : _kArchiveGold.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        b.post,
        15,
        Paint()
          ..color = _kArchiveStone.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (lit != null) {
        final high = lit.pitch == BeamPitch.high;
        final len = high ? 74.0 : 44.0;
        final half = high ? 26.0 : 18.0;
        final fan = Path()
          ..moveTo(b.post.dx, b.post.dy)
          ..lineTo(b.post.dx - half, b.post.dy + len)
          ..lineTo(b.post.dx + half, b.post.dy + len)
          ..close();
        canvas.drawPath(
          fan,
          Paint()
            ..color = _kArchiveGold.withValues(
              alpha: 0.30 + 0.25 * (archive.bloom / _kArchiveBloomSeconds),
            ),
        );
      }
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
    // shadow is the true shape and the stone is the lie.
    if (hall.balustrade != null) {
      for (final e in kCourtEffigies) {
        final read = archive.effigiesRead.contains(e.id);
        canvas.drawCircle(
          e.position,
          10,
          Paint()..color = _kArchiveStone.withValues(alpha: read ? 0.45 : 0.85),
        );
        if (!archive.isLit(e.stand)) continue;
        final shadow = Path()
          ..moveTo(e.position.dx + 8, e.position.dy + 6)
          ..lineTo(e.position.dx + 46, e.position.dy + 20)
          ..lineTo(e.position.dx + 46, e.position.dy - 6)
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
      canvas.drawRect(
        Rect.fromCenter(center: s.position, width: 13, height: 17),
        Paint()..color = _kArchiveGlare.withValues(alpha: 0.62),
      );
    }

    // THE SHUTTER-RING: a ring on the reading floor, closed until the rite.
    final ring = hall.shutterRing;
    if (ring != null) {
      canvas.drawCircle(
        ring,
        16,
        Paint()
          ..color = (conduitEnergy['B'] ?? 0) > 0
              ? _kArchiveGold.withValues(alpha: 0.85)
              : _kArchiveStone.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // THE ARENA PILLARS: the only shadows in Solarin's chamber.
    for (final p in hall.gazePillars) {
      canvas.drawCircle(
        p,
        18,
        Paint()..color = _kArchiveStone.withValues(alpha: 0.75),
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
