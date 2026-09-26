// lib/games/planet_dungeon/planet_dungeon_game_dark.dart
//
// NYTHRALOR — the Eclipse Vault. Dark's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart` (the treatment every planet after the Air
// pilot gets). The layout, the span graph, the gnomons, the anchors and the
// eclipse algebra all live in planet_dungeon_layout_dark.dart; this file is
// the rules that drive them.
//
// World rule: *a lamp here does not light the room; it turns it inside out.*
// See the layout header for the full statement of the quarters, the gnomon's
// promise, the vault trick, and why this planet needs no reset valve.
//
//  • Entry — the pall is knotted across the arch. DARK draws its own cloth
//    and the vault opens (§5.5, the eased entry reveal).
//  • Star 0 (Analemma) — THE FOUR SHADOW-STONES, on the court's floor dial.
//    A stone seats only while its OWN quarter lies in shadow, and the eclipse
//    never leaves all four quarters in shadow at once — so the dial cannot be
//    finished in one shape of the vault. ELEMENT-ONLY, all three elements
//    used: this is the star §4 guarantees to any trio of the right elements
//    on a first descent.
//  • Star 1 (Anchor) — THE SHADOW-PORTALS (§6's S2). A Poison PIP eats the
//    rust out of a ring (the planet's one star-level family gate); a Spirit
//    hand reads where the far end comes out; and a portal only carries you
//    while BOTH its ends lie in shadow. The star is the three TRANSITS, not
//    the three unlocks — which makes it a planning problem over the eclipse.
//  • Rite (Eclipse Nave) — conduit A is the Dark+MASK reredos (§6 put this
//    gate on Star 1; §4's first-descent guarantee wins, so it moved here);
//    the snuffer is element-only Dark with **Poison+Spirit→Dark** as the
//    braid, and it is §6's "extinguish every light".
//  • Star 2 (Totality) — MYS15 NOCTRYOS. §7: the guardian fights WITH the
//    planet's rule. It throws the vault's shadow: every strike beat turns the
//    stair gnomon, so the maze outside inverts while you fight, and its lull
//    exists only while the DEEP lies in shadow — the one arrangement its own
//    beat keeps taking away. The arena's floor-vane is your hand on the same
//    finger.
//  • Lost Maxim — THE ABYSS: THE FOURTH FINGER. The font's hole has a bottom,
//    and it shows only while the DEEP stands in LIGHT — the one arrangement
//    the whole lower vault punishes, and one you can only make from the
//    arena's vane. On it lies a gnomon that fell an age ago, chained to a
//    rusted ring at the rim: Spirit reads the chain, a Poison pip eats the
//    rust, and Dark hauls it up a length a press.
//
// NON-STRANDABILITY (see `solveEclipseVault`): a global flip that swaps walls
// and doors is the purest stranding machine in the set — a flip can close the
// corridor you are standing in. Nythralor answers it with geometry rather
// than a valve, and the answer has four parts, all in the layout header: a
// turn is its own undo · a gnomon-less room cannot be shut on you · every
// gnomon stands in the UPPER of its two quarters, never behind the door it
// opens · and the arena, the one place the world flips the vault without you,
// is proofed twice (a phase-free rood door and the floor-vane). The measured
// result agrees: **0 strandable of 392 reachable states, with no reset
// valve** — against 124 if the fingers are dropped behind the doors they
// open, and 22 if the arena loses its two belts.

part of 'planet_dungeon_game.dart';

/// Dark's lost maxim discovery id (the screen pays 20 gold on first find).
const String kDarkAbyssEggId = 'egg:dark_abyss';

// ── Device-tunable knobs ───────────────────────────────────
// Dark has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a gnomon, a stone, a ring, the pall,
/// the snuffer, the abyss or the vane to act on it.
const double _kVaultReach = 70.0;

/// How close the second body of a Poison+Spirit braid must stand (§6's
/// recipe — it substitutes the ELEMENT, never a family).
const double _kVaultBraidReach = 150.0;

/// Seconds an inversion's WIPE takes to cross the room. Purely visual.
const double _kVaultWipeSeconds = 0.8;

/// Shades a seated stone wakes (Star 0's one consequence). Reading the vault
/// is not free — the stones are grave-markers.
const int _kStoneShades = 2;

/// Shades a portal transit wakes (Star 1's one consequence). Something else
/// comes through the hole with you.
const int _kPortalShades = 2;

extension EclipseVaultDungeon on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetVaultState() {
    if (!_isVault) return;
    // A death re-hangs no pall and turns no finger back by itself — the vault
    // is puzzle state like every other planet's, so it resets with the run.
    vault.reset();
    // A WON STAR DRAWS WON (the Dust lesson): the dial stays seated and the
    // rings stay clean and read after a death or on a new descent. Both are
    // additive — seated stones and open portals only ever add roads — so
    // the no-strand proof is untouched.
    if (hasStar(0)) {
      vault.stonesSeated.addAll(kShadowStones.map((s) => s.id));
    }
    if (hasStar(1)) {
      for (final an in kVaultAnchors) {
        vault.anchorsOpen.add(an.id);
        vault.anchorsRead.add(an.id);
        vault.portalsWalked.add(an.id);
      }
    }
  }

  // ── The map, in the state the vault is in ────────────────

  /// The span a door IS. One room pair, one span (pinned by the tests), so
  /// the door the player walks and the edge the proof walks are the same
  /// object and can never drift apart.
  VaultSpan? _vaultSpanFor(DungeonRoom room, DungeonDoor door) =>
      vaultSpanBetween(room.id, door.targetRoomId);

  /// Which quarter every room lies in. Derived from the layout once per call
  /// rather than duplicated, so the module, the render and the proof can
  /// never disagree.
  Map<String, EclipseLeaf> get _vaultLeaves => vaultLeafOfRoom(layout);

  EclipseLeaf? _leafOf(String roomId) => layout.rooms[roomId]?.eclipse?.leaf;

  /// A SHADOW-WAY in a lit quarter is not a door you have not opened — there
  /// is nothing there at all, and the wall it would be in is blank. That is
  /// the vault trick stated as a general rule rather than a special case for
  /// the reliquary (§5.5).
  bool _vaultDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isVault) return false;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) {
      // The pall hangs across every way out of the porch.
      return true;
    }
    final span = _vaultSpanFor(room, door);
    if (span == null) return false;
    return span.cut == SpanCut.shadowWay && !vault.spanOpen(span);
  }

  /// A LIGHT-WALK in a shadowed quarter is the opposite: you can see the
  /// causeway perfectly well, and there is no light on it to walk. Visible
  /// and refused, because being told what the eclipse has taken is the whole
  /// teaching layer of this planet (§5.6 BLOCKED).
  bool _vaultDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isVault) return false;
    final span = _vaultSpanFor(room, door);
    if (span == null) return false;
    return !vault.spanOpen(span);
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How to re-shape the vault is Mask's earned reading.
  String _vaultDoorHint(DungeonRoom room, DungeonDoor door) {
    final span = _vaultSpanFor(room, door)!;
    final where = leafWord(span.leaf!);
    return span.cut == SpanCut.lightWalk
        ? 'No floor here while $where is in shadow'
        : 'Solid wall while $where is in light';
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Dark verb, in priority order. Returns true when one was consumed.
  /// The arena's floor-vane outranks the guardian's own catch (Ice's pillar,
  /// Lightning's spike and Plant's root-gall set that precedent) — the
  /// fight's errand must never be eaten by a strike.
  bool _tryVaultVerb(DungeonCreature a) {
    if (!_isVault) return false;
    return _tryPallCurtain(a) ||
        _tryShadowVane(a) ||
        _tryGnomon(a) ||
        _tryShadowStone(a) ||
        _tryShadowAnchor(a) ||
        _tryAbyss(a) ||
        _trySnuffer(a);
  }

  /// The planet's verb is element-only DARK (§4), and **Poison+Spirit→Dark**
  /// (§6) stands in as a BRAID — two bodies at the same spot — for a party
  /// whose Dark hand is down. A recipe substitutes the ELEMENT, never a
  /// family, so it is never accepted at the reredos or at a rusted ring.
  bool _vaultHasNightHand(DungeonCreature a) {
    final el = a.member.element;
    if (el == 'Dark') return true;
    if (el != 'Poison' && el != 'Spirit') return false;
    final want = el == 'Poison' ? 'Spirit' : 'Poison';
    return creatures.any(
      (c) =>
          !identical(c, a) &&
          c.alive &&
          c.member.element == want &&
          (c.position - a.position).distance < _kVaultBraidReach,
    );
  }

  /// The entry rite: Dark draws its own cloth off the arch.
  bool _tryPallCurtain(DungeonCreature a) {
    final pos = currentRoom.eclipse?.pallCurtain;
    if (pos == null || entryDoorRevealed) return false;
    if ((a.position - pos).distance > _kVaultReach) return false;
    if (a.member.element != 'Dark') {
      _setBlockedHint('Only Dark can pull this cloth down');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _cue(SoundCue.dungeonGateOpen);
    _setHint('The pall comes off the arch, and Nythralor is not one shape');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Dark',
      reagentElements: const ['Poison', 'Spirit'],
      particleCount: 30,
      intensity: 1.25,
    );
    return true;
  }

  /// A GNOMON — the only place in the vault a shadow moves, and the planet's
  /// whole verb. Element-only Dark (braid allowed): a maze you cannot
  /// re-shape is a softlock, so this is never gated, never one-way, and never
  /// on a cooldown. Turning it back is always legal, which is reason 1 of the
  /// no-strand proof.
  bool _tryGnomon(DungeonCreature a) {
    final g = vaultGnomonIn(currentRoomId);
    if (g == null) return false;
    if ((a.position - g.shaft).distance > _kVaultReach) return false;
    if (!_vaultHasNightHand(a)) {
      _setBlockedHint('This needs Dark, or Poison and Spirit together');
      return true;
    }
    _throwShadow(g, g.shaft);
    return true;
  }

  /// The arena's floor-vane: the same finger, turned from the bottom of the
  /// vault. The deep quarter carries no gnomon of its own on purpose (a
  /// gnomon behind its own door is a one-way trip — see the layout header),
  /// so this is both the fight's verb and the arena's safety belt.
  bool _tryShadowVane(DungeonCreature a) {
    final pos = currentRoom.eclipse?.shadowVane;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kVaultReach) return false;
    if (!_vaultHasNightHand(a)) {
      _setBlockedHint('This needs Dark, or Poison and Spirit together');
      return true;
    }
    final g = vaultGnomonById('gn_stair');
    if (g == null) return false;
    _throwShadow(g, pos);
    return true;
  }

  /// The one place a shadow is moved. Everything that has to happen when the
  /// vault turns over happens here, once — including the door reveals, so a
  /// passage that has just come into existence gets the engine's flourish
  /// rather than appearing silently.
  void _throwShadow(Gnomon g, Offset at) {
    final left = vault.shadowOf(g.id);
    final wasOpen = {
      for (final d in currentRoom.doors)
        if (_vaultSpanFor(currentRoom, d) case final sp?)
          if (vault.spanOpen(sp)) d.targetRoomId,
    };
    final entered = vault.turn(g.id)!;
    vault.wipe = _kVaultWipeSeconds;
    _cue(SoundCue.dungeonSwitch);
    _cue(SoundCue.elementDark);
    // A CONSEQUENCE, not narration (§5.7): a turn has just shut every passage
    // cut through the quarter the shadow left, somewhere you cannot see.
    speakConsequence(
      'The shadow moves from ${leafWord(left)} to ${leafWord(entered)}',
      3.0,
    );
    _spawnAlchemyBurst(
      at,
      producedElement: 'Dark',
      reagentElements: const ['Spirit'],
      particleCount: 34,
      intensity: 1.3,
    );
    // Every passage that has just come into being in this room deserves the
    // reveal flourish (and only those — one that was already open does not
    // open again); the ones that just stopped existing close over on screen.
    for (final d in currentRoom.doors) {
      final span = _vaultSpanFor(currentRoom, d);
      if (span == null || !vault.spanOpen(span)) continue;
      if (wasOpen.contains(d.targetRoomId)) continue;
      _queueDoorReveal(currentRoom.id, d.targetRoomId);
      _queueDoorReveal(d.targetRoomId, currentRoom.id);
    }
  }

  // ── Star 0 · THE ANALEMMA ────────────────────────────────

  /// The room the Analemma Star banks in, wherever it is (the tally reads it
  /// without walking there).
  DungeonRoom? get _analemmaStarRoom {
    for (final r in layout.rooms.values) {
      if (r.eclipse?.starIndex == 0) return r;
    }
    return null;
  }

  /// A shadow-stone on the court's dial. Element-only (§4) — and the stone
  /// only seats while its own quarter lies in shadow, which is the whole
  /// star: four seatings, and the eclipse can never offer more than three of
  /// them at a time.
  bool _tryShadowStone(DungeonCreature a) {
    if (currentRoom.eclipse?.analemma == null) return false;
    for (final s in kShadowStones) {
      if ((a.position - s.position).distance > _kVaultReach) continue;
      if (vault.stonesSeated.contains(s.id)) {
        _setAmbientHint('Seated, and cold to the touch');
        return true;
      }
      if (a.member.element != s.element) {
        _setBlockedHint('This stone needs ${s.element}');
        return true;
      }
      if (!vault.isDark(s.leaf)) {
        _setBlockedHint(
          '${leafWord(s.leaf)} is in light. This stone needs it in shadow',
        );
        return true;
      }
      vault.stonesSeated.add(s.id);
      _cue(SoundCue.dungeonStepStone);
      _spawnAlchemyBurst(
        s.position,
        producedElement: 'Dark',
        reagentElements: [s.element],
        particleCount: 26,
        intensity: 1.15,
      );
      // THE CONSEQUENCE (§7, one per star): these are grave-markers, and
      // reading one wakes what it marks.
      spawnWispWave(
        element: 'Dark',
        center: s.position,
        count: _kStoneShades,
        unstable: true,
        announce: false,
      );
      if (!vault.analemmaWoken) {
        _setHint('The stone goes down, and something comes up off the dial');
        return true;
      }
      final idx = _analemmaStarRoom?.eclipse?.starIndex;
      if (idx != null && !hasStar(idx)) {
        _setHint(
          'Four stones seated, and never two of them in the same '
          'vault',
        );
        earnStar(idx);
      }
      return true;
    }
    return false;
  }

  // ── Star 1 · THE SHADOW-PORTALS ──────────────────────────

  DungeonRoom? get _anchorStarRoom {
    for (final r in layout.rooms.values) {
      if (r.eclipse?.starIndex == 1) return r;
    }
    return null;
  }

  /// A shadow-anchor. Three things happen at a ring, in this order: a Poison
  /// PIP eats the rust (the star's ONE hard family gate, §4); a Spirit hand
  /// reads where the far end comes out (element-only, and purely
  /// informational — an unread portal still carries you); and anyone at all
  /// walks it, but only while BOTH its ends lie in shadow.
  bool _tryShadowAnchor(DungeonCreature a) {
    for (final an in vaultAnchorsIn(currentRoomId)) {
      final ring = an.ringIn(currentRoomId)!;
      if ((a.position - ring).distance > _kVaultReach) continue;

      if (!vault.anchorsOpen.contains(an.id)) {
        // VERB-ONLY: the anchor is a narrow opening and the requirement is
        // fitting through it. Poison was never doing anything to it.
        const req = DungeonInteractionRequirement(
          element: kAnyElement,
          requiredFamily: DungeonAbility.smallAccess,
        );
        switch (evaluateInteraction(a.member, req)) {
          case InteractionResult.passed:
          case InteractionResult.passedViaRecipe:
            break;
          case InteractionResult.blockedFamily:
            // "The seal remembers" (§4): the chip stamps on first refusal.
            final gate = layout.familyGateFor('anchor_ring');
            if (gate != null) {
              _stampFamilyGate(gate);
            } else {
              _setBlockedHint('Only a Pip is small enough to clear this ring');
            }
            return true;
          case InteractionResult.blockedElement:
          case InteractionResult.blockedStat:
            _setBlockedHint('Only a Pip is small enough to clear this ring');
            return true;
        }
        vault.anchorsOpen.add(an.id);
        _cue(SoundCue.elementPoison);
        _setHint('The rust goes off the ring, and the ring goes through');
        _spawnAlchemyBurst(
          ring,
          producedElement: 'Poison',
          reagentElements: const ['Dark'],
          particleCount: 24,
          intensity: 1.1,
        );
        return true;
      }

      if (a.member.element == 'Spirit' && !vault.anchorsRead.contains(an.id)) {
        vault.anchorsRead.add(an.id);
        _cue(SoundCue.dungeonInteract);
        final far = an.other(currentRoomId)!;
        _setInsightHint('This portal comes out in ${_roomWord(far)}', 4.0);
        return true;
      }

      if (!vault.portalOpen(an, _vaultLeaves)) {
        final far = an.other(currentRoomId)!;
        final farLeaf = _leafOf(far)!;
        final mine = _leafOf(currentRoomId)!;
        _setBlockedHint(
          vault.isLit(mine)
              ? 'The portal is closed while ${leafWord(mine)} is in light'
              : 'The far end of this portal is in light',
        );
        // Name the far quarter only once the scout has read it: an unread
        // ring is supposed to be a hole into somewhere.
        if (vault.anchorsRead.contains(an.id)) {
          _setBlockedHint(
            'The ring is clear, but ${leafWord(farLeaf)} is in light',
          );
        }
        return true;
      }

      _walkPortal(an);
      return true;
    }
    return false;
  }

  /// Step through a shadow-portal. The whole party goes: three creatures
  /// share one vault, and leaving a body on the far side of a hole that can
  /// close is exactly the softlock this planet is built not to have.
  void _walkPortal(ShadowAnchor an) {
    final far = an.other(currentRoomId)!;
    final arrive = an.ringIn(far)!;
    final first = !vault.portalsWalked.contains(an.id);
    vault.portalsWalked.add(an.id);
    currentRoomId = far;
    _spreadCreaturesAround(arrive);
    _doorCooldown = 0.5;
    _clearHints();
    _cue(SoundCue.cosmicPortalOpen);
    _spawnAlchemyBurst(
      arrive,
      producedElement: 'Dark',
      reagentElements: const ['Spirit'],
      particleCount: 30,
      intensity: 1.25,
    );
    // THE CONSEQUENCE (§7): a hole in the dark does not only take you.
    spawnWispWave(
      element: 'Dark',
      center: arrive,
      count: _kPortalShades,
      unstable: true,
      announce: false,
    );
    if (!vault.everyPortalWalked) {
      // The first transit is a consequence — something came through with
      // you — and says so; every later one is the animation's to carry.
      if (first) {
        speakConsequence(
          'You come out somewhere else, and something follows you through',
          3.0,
        );
      }
      return;
    }
    final idx = _anchorStarRoom?.eclipse?.starIndex;
    if (idx != null && !hasStar(idx)) {
      _setHint('Three holes walked, and the dark holds them open');
      earnStar(idx);
    }
  }

  // ── The rite · THE ECLIPSE NAVE ──────────────────────────

  /// The rite's second half — §6's "extinguish every light". Element-only
  /// Dark with the Poison+Spirit braid, so a party missing the Mask meets
  /// exactly ONE refusal in this nave rather than two.
  bool _trySnuffer(DungeonCreature a) {
    final pos = currentRoom.eclipse?.snuffer;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kVaultReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (!_vaultHasNightHand(a)) {
      _setBlockedHint('This needs Dark, or Poison and Spirit together');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The lamps need the ${layout.starName(0)} and '
        '${layout.starName(1)} first',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
    _cue(SoundCue.dungeonSwitch);
    _setHint('Every lamp in the nave goes out at once, and stays out');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Dark',
      reagentElements: const ['Poison', 'Spirit'],
      particleCount: 30,
      intensity: 1.2,
    );
    return true;
  }

  // ── Star 2 · NOCTRYOS ────────────────────────────────────

  /// §7 — the guardian fights WITH the planet's rule. Noctryos does not
  /// darken the arena; it THROWS THE VAULT'S SHADOW. Its lull exists only
  /// while the DEEP lies in shadow, and every strike beat turns the stair
  /// gnomon — which is the one arrangement its own beat keeps taking away. The
  /// floor-vane is your hand on the same finger, so the fight is a tug on one
  /// shadow rather than a damage race.
  void _updateNoctryos(DungeonRoom room, double dt) {
    if (room.guardian == null || !guardianAwake) return;
    if (!vault.isDark(EclipseLeaf.deep)) {
      guardianVulnerable = false;
      return;
    }
    if (guardianVulnerable && !_noctryosBitLastFrame) {
      // The window opened: totality, and the thing in it stops moving.
      _noctryosBitLastFrame = true;
      return;
    }
    if (!guardianVulnerable && _noctryosBitLastFrame) {
      _noctryosBitLastFrame = false;
      final g = vaultGnomonById('gn_stair')!;
      if (vault.shadowOf(g.id) == EclipseLeaf.deep) {
        vault.turn(g.id);
        vault.wipe = _kVaultWipeSeconds;
        _cue(SoundCue.dungeonHazardTrigger);
        // A closing announces itself (§5.7): this runs from update, where a
        // plain line is dropped unasked, and the beat has just shut the gulf
        // and the slot above you.
        speakConsequence(
          'Noctryos pulls the shadow off the Deep, and the vault flips above '
          'you',
        );
      }
    }
  }

  // ── The Lost Maxim · THE ABYSS ───────────────────────────
  //
  // THE FOURTH FINGER (2026-09-19; the §7 maxim standard, and Mud's lesson
  // that the best place to hide a secret is the state your own stars punish).
  //
  // It used to be a WAIT: a full minute standing still in the dark font. A
  // condition, not a puzzle, and §7's table graded it exactly that. It is a
  // CHAIN now, and every link is a thing this planet already taught:
  //
  //   1. LIGHT THE DEEP FROM INSIDE IT. Every objective in the lower vault
  //      wants the Deep in shadow — the gulf, the slot, the causeway, the
  //      reliquary's very existence, Noctryos' lull. The one hand that can
  //      light it from below is the arena's vane, behind the rood door. Turn
  //      it, and the slot and the gulf are gone; walk back to the font by the
  //      undercroft, which is a light-walk and is there now.
  //   2. THE HOLE HAS A BOTTOM. Light falls into the abyss for the first time
  //      and shows what lies on it: a gnomon, fallen an age ago, chained to a
  //      rusted ring at the rim. Nothing is pressed for this; the room is the
  //      clue.
  //   3. SPIRIT READS THE CHAIN — the job it does at every anchor here:
  //      three lengths, and the finger at the end of them.
  //   4. A POISON PIP EATS THE RUST off the rim's ring — the same verb, the
  //      same declared gate, as every anchor ring on the planet.
  //   5. DARK HAULS, a length a press — the repeated beat. Three, and the
  //      finger stands at the rim: the rite of three over it.
  //
  // Nothing here asks for a family the riddle did not name (the Pip gate is
  // the anchors' own), a wrong hand answers with a puff and a sentence, and
  // the star path never passes it: every star wants the Deep dark down here.

  /// Light on the bottom of the well: the whole secret exists only now.
  bool get abyssLit => vault.isLit(EclipseLeaf.deep);

  /// The rusted ring the chain runs to, on the rim of the well.
  Offset _abyssRing(Offset abyss) => abyss + const Offset(62, -30);

  /// The abyss, in the light. Spirit reads, Poison frees, Dark hauls.
  bool _tryAbyss(DungeonCreature a) {
    final pos = currentRoom.eclipse?.abyss;
    if (pos == null) return false;
    if (discoveredClouds.contains(kDarkAbyssEggId)) return false;
    final ring = _abyssRing(pos);
    final atRing = (a.position - ring).distance <= _kVaultReach;
    final atWell = (a.position - pos).distance <= _kVaultReach + 20;
    if (!atRing && !atWell) return false;
    if (!abyssLit) {
      // In the dark the hole is a hole. WHAT is missing, in one clause.
      _setBlockedHint('Too dark to see the bottom');
      return true;
    }
    final el = a.member.element;

    // ── 3 · the chain, read ──
    // (A Spirit hand that has already read falls through to the haul, where
    // it may stand as half of the Poison+Spirit braid.)
    if (el == 'Spirit' && !vault.abyssRead) {
      vault.abyssRead = true;
      _cue(SoundCue.dungeonInteract);
      _spawnAlchemyBurst(
        pos,
        producedElement: 'Spirit',
        particleCount: 14,
        intensity: 0.7,
      );
      _setInsightHint('Three lengths of chain, with a gnomon on the end', 4.0);
      return true;
    }

    // ── 4 · the rust, eaten ──
    // (A Poison hand once the ring is clean falls through to the haul, as
    // the other half of the braid.)
    if (el == 'Poison' && !vault.abyssChainFree) {
      // The anchors' own gate, declared on the layout: a ring is a ring.
      const req = DungeonInteractionRequirement(
        element: kAnyElement,
        requiredFamily: DungeonAbility.smallAccess,
      );
      switch (evaluateInteraction(a.member, req)) {
        case InteractionResult.passed:
        case InteractionResult.passedViaRecipe:
          vault.abyssChainFree = true;
          _cue(SoundCue.elementPoison);
          _spawnAlchemyBurst(
            ring,
            producedElement: 'Poison',
            reagentElements: const ['Dark'],
            particleCount: 22,
            intensity: 1.0,
          );
          return true;
        default:
          _spawnAlchemyBurst(
            ring,
            producedElement: 'Poison',
            particleCount: 8,
            intensity: 0.5,
          );
          _setBlockedHint('Only a Pip is small enough to clear this ring');
          return true;
      }
    }

    // ── 5 · the hauls ──
    if (!_vaultHasNightHand(a)) {
      _spawnAlchemyBurst(
        pos,
        producedElement: el,
        particleCount: 8,
        intensity: 0.5,
      );
      _setBlockedHint('Only Dark can haul this chain');
      return true;
    }
    if (!vault.abyssRead) {
      _spawnAlchemyBurst(
        pos,
        producedElement: 'Dark',
        particleCount: 8,
        intensity: 0.5,
      );
      _setBlockedHint('No telling how long this chain is');
      return true;
    }
    if (!vault.abyssChainFree) {
      _spawnAlchemyBurst(
        ring,
        producedElement: 'Dark',
        particleCount: 8,
        intensity: 0.5,
      );
      _setBlockedHint('Rust has the ring locked. The chain won\'t move');
      return true;
    }
    if (vault.abyssRaised) return false;
    vault.abyssHauls++;
    _cue(SoundCue.dungeonBlockMove);
    _spawnAlchemyBurst(
      ring,
      producedElement: 'Dark',
      reagentElements: const ['Spirit'],
      particleCount: 16,
      intensity: 0.9,
    );
    if (!vault.abyssRaised) return true;
    // The finger stands. THE RITE OF THREE pays this out (see
    // `beginMaximRite`).
    _cue(SoundCue.dungeonGateOpen);
    beginMaximRite(kDarkAbyssEggId, pos);
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Dark',
      reagentElements: const ['Spirit', 'Poison'],
      particleCount: 44,
      intensity: 1.5,
    );
    return true;
  }

  // ── Per-frame ────────────────────────────────────────────

  void _updateVault(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isVault) return;
    if (vault.wipe > 0) vault.wipe = max(0.0, vault.wipe - dt);
    _updateNoctryos(room, dt);
  }

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): the counters live beside the star
  /// tracker, per room, never as prose that fades. THE ECLIPSE is the default,
  /// because on this planet it is the one thing every decision turns on — and
  /// it is drawn as four marks in quarter order so it reads at a glance.
  DungeonProgressReadout? _vaultProgressReadout() {
    final hall = layout.rooms[currentRoomId]?.eclipse;
    if (hall?.analemma != null && !hasStar(hall!.starIndex!)) {
      final n = vault.stonesSeated.length;
      return DungeonProgressReadout(
        label: 'STONES',
        value: '$n/${kShadowStones.length}',
        fraction: n / kShadowStones.length,
      );
    }
    if (hall?.starIndex == 1 && !hasStar(1)) {
      final n = vault.portalsWalked.length;
      return DungeonProgressReadout(
        label: 'PORTALS',
        value: '$n/${kVaultAnchors.length}',
        fraction: n / kVaultAnchors.length,
      );
    }
    final marks = [
      for (final l in EclipseLeaf.values) vault.isDark(l) ? '■' : '□',
    ].join();
    final dark = EclipseLeaf.values.where(vault.isDark).length;
    return DungeonProgressReadout(
      label: 'ECLIPSE',
      value: marks,
      fraction: dark / EclipseLeaf.values.length,
    );
  }

  String _roomWord(String roomId) => switch (roomId) {
    'pall_porch' => 'the Pall Porch',
    'analemma_court' => 'the Analemma Court',
    'shade_gallery' => 'the Shade Gallery',
    'penumbral_walk' => 'the Penumbral Walk',
    'gnomon_stair' => 'the Gnomon Stair',
    'ossuary_ring' => 'the Ossuary Ring',
    'abyssal_font' => 'the Abyssal Font',
    'umbral_reliquary' => 'a room with no door on it',
    'eclipse_nave' => 'the Eclipse Nave',
    _ => 'somewhere under the rood',
  };

  /// WHAT, never HOW (§5.6). Every method here is Mask's to give.
  String? _vaultObjectiveHint(DungeonRoom room) {
    if (room.guardian != null) {
      return 'Noctryos\' Totality. The last star is here';
    }
    if (room.eclipse?.snuffer != null) {
      return 'The Eclipse Nave. The rite happens here';
    }
    if (room.eclipse?.analemma != null) {
      return hasStar(room.eclipse!.starIndex!)
          ? null
          : 'The Analemma Court. Four stones need seating on the dial';
    }
    if (room.eclipse?.starIndex == 1) {
      return hasStar(1) ? null : 'The Ossuary Ring. Three rusted portal rings';
    }
    if (room.vaultCache != null) {
      return 'A hidden room. Something is stored here';
    }
    if (room.eclipse?.abyss != null) {
      return 'The Abyssal Font';
    }
    if (vaultGnomonIn(room.id) != null) {
      return 'A gnomon. Turning it moves a shadow';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Pall Porch'
          : 'The Pall Porch. A cloth hangs over the arch';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _vaultAmbientHint(DungeonCreature a, DungeonRoom room) {
    final g = vaultGnomonIn(room.id);
    if (g != null && (a.position - g.shaft).distance < 110) {
      _setAmbientHint('It has not moved in an age, and it is warm');
      return;
    }
    for (final an in vaultAnchorsIn(room.id)) {
      final ring = an.ringIn(room.id)!;
      if ((a.position - ring).distance > 110) continue;
      _setAmbientHint(
        vault.anchorsOpen.contains(an.id)
            ? 'A draught comes out of it that has not been outside'
            : 'Old iron, and it is weeping rust',
      );
      return;
    }
    final leaf = room.eclipse?.leaf;
    if (leaf == null) return;
    _setAmbientHint(
      vault.isDark(leaf)
          ? 'Somewhere behind you a wall stops being a wall'
          : 'The light in here is the colour of a coin',
    );
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), and it is
  /// tiered by Intelligence.
  void _vaultReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    if (room.eclipse?.analemma != null) {
      _setInsightHint(switch (tier) {
        0 => 'Each stone belongs to one quarter of the vault',
        1 => 'A stone only seats while its quarter is in shadow',
        _ =>
          'You can\'t shadow all four quarters at once. Seat the stones '
              'you can, turn the gnomons, then come back for the rest',
      });
      return;
    }
    if (vaultAnchorsIn(room.id).isNotEmpty) {
      _setInsightHint(switch (tier) {
        0 => 'Each ring is a portal, rusted shut',
        1 => 'A portal only works while both of its ends are in shadow',
        _ =>
          'A Pip can clear the rust. Then put both ends in shadow and '
              'step through. Each of the three rings needs a different '
              'arrangement',
      });
      return;
    }
    if (vaultGnomonIn(room.id) != null) {
      final g = vaultGnomonIn(room.id)!;
      _setInsightHint(switch (tier) {
        0 => 'This gnomon casts one shadow',
        1 =>
          'It moves its shadow between ${leafWord(g.upper)} and '
              '${leafWord(g.lower)}',
        _ =>
          'Its shadow is on ${leafWord(vault.shadowOf(g.id))} now. Turning it '
              'opens paths on one side and closes them on the other',
      });
      return;
    }
    if (room.eclipse?.abyss != null &&
        !discoveredClouds.contains(kDarkAbyssEggId)) {
      // ONE OBLIQUE LINE and nothing after it (the §7 maxim standard). It
      // does not tier and it does not track progress.
      _setInsightHint(
        'Nobody has ever seen the bottom of this. It would take light to '
        'find it',
      );
      return;
    }
    if (room.vaultCache != null || room.eclipse?.abyss != null) {
      _setInsightHint(switch (tier) {
        0 => 'That wall changes with the shadows',
        1 =>
          'There\'s a room through there, but only while the Deep is in '
              'shadow',
        _ =>
          'Getting down here needs the Ossuary in shadow, and the room needs '
              'the Deep in shadow. One gnomon can\'t do both, so use the '
              'other gnomon for the Ossuary first',
      });
      return;
    }
    // Anywhere in the vault, insight reads the ECLIPSE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'Turning a gnomon flips which paths are open',
      1 =>
        'Paths between quarters only open in shadow. Paths inside a quarter '
            'only open in light',
      _ =>
        'Three gnomons, four quarters, one shadow each. Plan which quarters '
            'you need in shadow before you walk',
    });
  }

  /// Per-room mood — the porch is grey daylight and the deep is the inside of
  /// a closed eye, but the real driver is the eclipse: a shadowed quarter
  /// goes darker than the room it is.
  double get _vaultMoodTarget {
    // A LOT DARKER (2026-09-19, from the author). The porch and the court
    // sat ABOVE the shader's baseline (0.5), so the top of the vault read as
    // a blue dusk; nothing on this planet is brighter than baseline now, and
    // the deep is as far toward black as the shader's shaping allows.
    final base = switch (currentRoomId) {
      'pall_porch' => 0.34,
      'analemma_court' => 0.30,
      'shade_gallery' => 0.26,
      'penumbral_walk' => 0.24,
      'gnomon_stair' => 0.20,
      'ossuary_ring' => 0.16,
      'abyssal_font' => 0.06,
      'umbral_reliquary' => 0.08,
      'eclipse_nave' => 0.12,
      _ => guardianAwake ? 0.04 : 0.10,
    };
    final leaf = layout.rooms[currentRoomId]?.eclipse?.leaf;
    if (leaf == null) return base;
    return vault.isDark(leaf) ? base * 0.55 : base;
  }

  // ── THE NO-STRAND PROOF ──────────────────────────────────

  /// Exhaustive reachability over the vault's whole state graph.
  ///
  /// A state is (which room you stand in) × (where each gnomon's shadow lies)
  /// × (which anchors are open). Every legal move is expanded: walking any
  /// span open in that arrangement, turning any gnomon in the room you stand
  /// in (including the arena's vane, which turns the stair gnomon from the
  /// bottom of the vault), eating the rust out of a ring you are standing at,
  /// stepping through an open portal — and Noctryos' beat, which throws the
  /// shadow off the Deep and is not a move the player chooses at all.
  /// Including the beat makes the enumerated set a strict SUPERSET of what
  /// play alone can reach, and reachability is then audited using only the
  /// moves the PLAYER controls. That is the honest form of the question: from
  /// anywhere the world can put you, can you still get out.
  ///
  /// Four answers, all by construction rather than by argument:
  ///
  ///  1. `strandable` — states from which some room is no longer reachable.
  ///     **It must be zero, and it is zero WITHOUT a reset valve** — this is
  ///     the first planet since Crystal to carry none. "Reachable" is checked
  ///     for EVERY room in the layout, which is stronger than the brief asks:
  ///     not just the exit and the unearned stars, but the vault as well.
  ///  2. `strandableWithoutVane` — the same audit with the arena's floor-vane
  ///     deleted and the rood door phase-cut. It must be NON-ZERO: the arena
  ///     is the one place the world turns the vault while the party is not
  ///     standing at a gnomon, and this number is what says its two safety
  ///     belts are load-bearing rather than decorative.
  ///  3. `strandableWithGnomonBelowItsDoor` — the counterfactual for the
  ///     placement rule: move the walk and stair gnomons down one quarter, so
  ///     each stands BEHIND the passage it commands. It must be catastrophic,
  ///     because a gnomon you can only reach through the door it opens turns
  ///     the descent into a one-way trip.
  ///  4. `maxQuartersLit` / `allQuartersDarkStates` — the eclipse algebra,
  ///     measured rather than asserted. Two and zero: never more than two
  ///     quarters in the light, and never all four in shadow, which is what
  ///     makes Star 0 a journey instead of a button.
  ({
    int states,
    int arrangements,
    int strandable,
    int strandableWithoutVane,
    int strandableWithGnomonBelowItsDoor,
    int maxQuartersLit,
    int allQuartersDarkStates,
  })
  solveEclipseVault() {
    final rooms = layout.rooms.keys.toList()..sort();
    final leafOf = _vaultLeaves;
    final gnIds = [for (final g in kVaultGnomons) g.id];
    final anIds = [for (final a in kVaultAnchors) a.id];
    final guardianRoom = layout.rooms.values
        .firstWhere((r) => r.guardian != null)
        .id;
    final vaneRoom = layout.rooms.entries
        .firstWhere((e) => e.value.eclipse?.shadowVane != null)
        .key;

    /// A configuration is one leaf per gnomon, in [kVaultGnomons] order.
    String enc(String room, List<EclipseLeaf> cfg, int open) =>
        '$room|${cfg.map((l) => l.index).join()}|$open';

    bool darkIn(List<EclipseLeaf> cfg, EclipseLeaf l) => cfg.contains(l);

    /// The SAME rule [EclipseVault.spanOpen] applies, restated over a plain
    /// list so the search never has to mutate live state.
    bool open(VaultSpan s, List<EclipseLeaf> cfg) => switch (s.cut) {
      SpanCut.unmoved => true,
      SpanCut.shadowWay => darkIn(cfg, s.leaf!),
      SpanCut.lightWalk => !darkIn(cfg, s.leaf!),
    };

    /// Which doors are walkable. Derived from the SAME spans the engine gates
    /// real doors with, via the room's own door list, so the proof can never
    /// drift from the doors the player actually meets.
    List<String> exits(String room, List<EclipseLeaf> cfg) {
      final out = <String>[];
      for (final d in layout.rooms[room]!.doors) {
        final s = vaultSpanBetween(room, d.targetRoomId);
        if (s == null || open(s, cfg)) out.add(d.targetRoomId);
      }
      return out;
    }

    /// [gnomonRoom] is a parameter so the placement counterfactual can move
    /// the fingers without touching the shipped layout.
    List<(String, List<EclipseLeaf>, int)> moves(
      String room,
      List<EclipseLeaf> cfg,
      int openMask, {
      required Map<String, String> gnomonRoom,
      required bool vane,
      required bool roodPhaseCut,
      required bool beat,
    }) {
      final out = <(String, List<EclipseLeaf>, int)>[];
      for (final t in exits(room, cfg)) {
        // The counterfactual phase-cuts the rood door through the Deep.
        if (roodPhaseCut &&
            ((room == guardianRoom) || (t == guardianRoom)) &&
            !darkIn(cfg, EclipseLeaf.deep)) {
          continue;
        }
        out.add((t, cfg, openMask));
      }
      // Turning a finger. Involutive by construction: the party does not
      // move, so the very same move is available again and undoes it — this
      // is reason 1 of the no-strand proof, expressed as code.
      for (var i = 0; i < gnIds.length; i++) {
        final g = kVaultGnomons[i];
        final here = gnomonRoom[g.id] == room;
        final byVane = vane && room == vaneRoom && g.id == 'gn_stair';
        if (!here && !byVane) continue;
        final next = [...cfg];
        next[i] = cfg[i] == g.upper ? g.lower : g.upper;
        out.add((room, next, openMask));
      }
      // Eating the rust: irreversible, but purely ADDITIVE — it only ever
      // grows the edge set, so it cannot shrink reachability.
      for (var i = 0; i < anIds.length; i++) {
        if (openMask & (1 << i) != 0) continue;
        if (!kVaultAnchors[i].touches(room)) continue;
        out.add((room, cfg, openMask | (1 << i)));
      }
      // Stepping through an open hole.
      for (var i = 0; i < anIds.length; i++) {
        if (openMask & (1 << i) == 0) continue;
        final an = kVaultAnchors[i];
        final far = an.other(room);
        if (far == null) continue;
        if (!darkIn(cfg, leafOf[room]!) || !darkIn(cfg, leafOf[far]!)) continue;
        out.add((far, cfg, openMask));
      }
      // Noctryos' beat — the world's move, never the player's, and only ever
      // inside the arena.
      if (beat && room == guardianRoom) {
        final i = gnIds.indexOf('gn_stair');
        if (cfg[i] == EclipseLeaf.deep) {
          final next = [...cfg];
          next[i] = EclipseLeaf.ossuary;
          out.add((room, next, openMask));
        }
      }
      return out;
    }

    int audit({
      required Map<String, String> gnomonRoom,
      required bool vane,
      required bool roodPhaseCut,
      void Function(int states, int arrangements, int maxLit, int allDark)?
      report,
    }) {
      final startCfg = [for (final g in kVaultGnomons) g.upper];
      final first = (layout.entranceRoomId, startCfg, 0);
      final live = <String, (String, List<EclipseLeaf>, int)>{};
      live[enc(first.$1, first.$2, first.$3)] = first;
      final queue = [first];
      while (queue.isNotEmpty) {
        final (rm, cfg, op) = queue.removeLast();
        for (final m in moves(
          rm,
          cfg,
          op,
          gnomonRoom: gnomonRoom,
          vane: vane,
          roodPhaseCut: roodPhaseCut,
          beat: true,
        )) {
          final k = enc(m.$1, m.$2, m.$3);
          if (live.containsKey(k)) continue;
          live[k] = m;
          queue.add(m);
        }
      }
      var strandable = 0;
      for (final st in live.values) {
        final seen = <String>{enc(st.$1, st.$2, st.$3)};
        final hit = <String>{st.$1};
        final q = [st];
        while (q.isNotEmpty) {
          final (rm, cfg, op) = q.removeLast();
          for (final m in moves(
            rm,
            cfg,
            op,
            gnomonRoom: gnomonRoom,
            vane: vane,
            roodPhaseCut: roodPhaseCut,
            beat: false,
          )) {
            final k = enc(m.$1, m.$2, m.$3);
            if (!seen.add(k)) continue;
            hit.add(m.$1);
            q.add(m);
          }
        }
        if (hit.length < rooms.length) strandable++;
      }
      if (report != null) {
        final cfgs = {
          for (final s in live.values) s.$2.map((l) => l.index).join(): s.$2,
        };
        var maxLit = 0;
        var allDark = 0;
        for (final c in cfgs.values) {
          final lit = EclipseLeaf.values.where((l) => !darkIn(c, l)).length;
          if (lit > maxLit) maxLit = lit;
          if (lit == 0) allDark++;
        }
        report(live.length, cfgs.length, maxLit, allDark);
      }
      return strandable;
    }

    final shipped = {for (final g in kVaultGnomons) g.id: g.roomId};
    // Each finger dropped into the quarter BELOW it — i.e. standing behind
    // the very passage it commands.
    final belowItsDoor = {
      ...shipped,
      'gn_walk': 'gnomon_stair',
      'gn_stair': 'abyssal_font',
    };

    var states = 0;
    var arrangements = 0;
    var maxLit = 0;
    var allDark = 0;
    final strandable = audit(
      gnomonRoom: shipped,
      vane: true,
      roodPhaseCut: false,
      report: (s, a, m, d) {
        states = s;
        arrangements = a;
        maxLit = m;
        allDark = d;
      },
    );
    return (
      states: states,
      arrangements: arrangements,
      strandable: strandable,
      strandableWithoutVane: audit(
        gnomonRoom: shipped,
        vane: false,
        roodPhaseCut: true,
      ),
      strandableWithGnomonBelowItsDoor: audit(
        gnomonRoom: belowItsDoor,
        vane: true,
        roodPhaseCut: false,
      ),
      maxQuartersLit: maxLit,
      allQuartersDarkStates: allDark,
    );
  }

  // ── Rendering ────────────────────────────────────────────
  // VISUAL GRAMMAR (§5.5): the inversion is drawn as a change of SUBSTANCE,
  // never as a light going out. A quarter in UMBRA is negative space — its
  // architecture is edges only, drawn in a cold violet outline on nothing, and
  // its shadow-ways are notches with no threshold. A quarter in CORONA is
  // solid: a pewter floor with hard-edged joints, and its light-walks are pale
  // causeways you can see the boards of. The turn itself animates as a WIPE
  // across the room so it reads as the world turning over rather than a lamp
  // dying. Nothing here is drawn like Lightning's jagged bolts, Water's tide
  // line or Plant's canopy, and there are no blur filters anywhere (the game's
  // known jank source).

  static const Color _kVaultVoid = Color(0xFF0B0A12);
  static const Color _kVaultViolet = Color(0xFF7A4FB5);
  static const Color _kVaultPewter = Color(0xFF8E93A8);
  static const Color _kVaultBone = Color(0xFFD9D2BC);
  static const Color _kVaultEmber = Color(0xFFE0B15C);

  void _renderVault(Canvas canvas, DungeonRoom room) {
    final leaf = room.eclipse?.leaf;
    final dark = leaf != null && vault.isDark(leaf);
    final was = leaf != null && vault.wipeFrom.contains(leaf);
    if (vault.wipe > 0 && leaf != null && was != dark) {
      // THE WIPE: behind the edge the room is already turned over, ahead of
      // it it is still what it was. Two grounds, one clip each.
      final b = room.bounds;
      final x = b.left + b.width * _vaultWipeT;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(b.left, b.top, x, b.bottom));
      _renderVaultGround(canvas, room, dark: dark);
      canvas.restore();
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(x, b.top, b.right, b.bottom));
      _renderVaultGround(canvas, room, dark: was);
      canvas.restore();
    } else {
      _renderVaultGround(canvas, room);
    }
    // The vault's walls, baked (planet_dungeon_game_dark_art.dart).
    _renderVaultShell(canvas, room);
    _renderGlassDoorPlugs(canvas, room);
    _renderVaultSpans(canvas, room);
    _renderVaultObjects(canvas, room);
    _renderVaultWipe(canvas, room);
  }

  /// What a shadowed room's dust falls into: the thing the room is for, or
  /// its middle.
  Offset _vaultFocus(DungeonRoom room) {
    final h = room.eclipse;
    return vaultGnomonIn(room.id)?.shaft ??
        h?.analemma ??
        h?.abyss ??
        h?.snuffer ??
        h?.shadowVane ??
        room.vaultCache ??
        room.bounds.center;
  }

  /// THE CHANGE OF SUBSTANCE, over the void (the black hole pass,
  /// 2026-09-25). Nythralor hangs in front of an event horizon (see
  /// dark.src.frag) and its floor is a floor of black glass flags laid over
  /// that. The two states of a quarter are the two things a black hole has:
  ///
  ///  · CORONA — the quarter stands in the disc's LIGHT: lit obsidian,
  ///    warmest on the side the hole hangs on and dying across the room.
  ///    (A turning swirl of light arms was tried and read as a screensaver.)
  ///  · UMBRA — the quarter is inside the SHADOW. The floor thins until the
  ///    hole behind the vault shows through it, the flags are violet
  ///    hairlines, and a little dust falls in slow spirals toward the focus
  ///    and goes out. Sixteen sprite blits.
  ///
  /// No blur anywhere; nothing else animates.
  void _renderVaultGround(Canvas canvas, DungeonRoom room, {bool? dark}) {
    final b = room.bounds;
    final leaf = room.eclipse?.leaf;
    if (leaf == null) return;
    final g = _vaultGroundFor(room, layout);
    dark ??= vault.isDark(leaf);
    final focus = _vaultFocus(room);
    final reach = max(b.width, b.height) * 0.62;

    canvas.save();
    canvas.clipRect(b);

    if (dark) {
      // ── UMBRA · inside the shadow ────────────────────────
      canvas.drawRect(b, Paint()..color = _kVaultVoid.withValues(alpha: 0.30));
      canvas.drawPath(
        g.flags,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = _kVaultViolet.withValues(alpha: 0.10),
      );
      canvas.drawPath(
        g.shadows,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.45),
      );
      canvas.drawPath(
        g.bodies,
        Paint()..color = const Color(0xFF14111E).withValues(alpha: 0.92),
      );
      canvas.drawPath(
        g.mouths,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.9),
      );
      canvas.drawPath(
        g.bodies,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _kVaultViolet.withValues(alpha: 0.35),
      );
      canvas.drawPath(
        g.edges,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = _kVaultViolet.withValues(alpha: 0.18),
      );
      canvas.drawPath(
        g.caps,
        Paint()..color = const Color(0xFFBCB0DE).withValues(alpha: 0.30),
      );
      // THE INFALL: dust spiralling into the focus, fading as it goes.
      const motes = 16;
      for (var i = 0; i < motes; i++) {
        final ph = (_time * 0.05 + i / motes) % 1.0;
        final fall = pow(1 - ph, 1.4).toDouble();
        final rr = 18 + reach * fall;
        final a = i * 2.39996 + (1 - fall) * 5.0 + _time * 0.08;
        final at = focus + Offset(cos(a), sin(a) * 0.72) * rr;
        final o = sin(ph * pi) * 0.55;
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.mote!,
            at,
            2.6 + 1.4 * (1 - fall),
            const Color(0xFFD9C8FF).withValues(alpha: o),
          );
        } else {
          canvas.drawCircle(
            at,
            1.6,
            Paint()..color = const Color(0xFFD9C8FF).withValues(alpha: o),
          );
        }
      }
    } else {
      // ── CORONA · in the disc's light ─────────────────────
      // Held under the translucency rule: the void still shows, warmed.
      canvas.drawRect(
        b,
        Paint()..color = const Color(0xFF2B2440).withValues(alpha: 0.34),
      );
      // The disc's light, falling in from the side the hole hangs on (high
      // and to the right in every room, as in the sky) and dying across the
      // floor. Nothing is drawn on the floor; the floor is only lit.
      canvas.drawRect(
        b,
        Paint()
          ..shader = ui.Gradient.linear(
            b.topRight,
            b.bottomLeft,
            [
              const Color(0xFFE8C9A0).withValues(alpha: 0.10),
              const Color(0xFF7A5CB0).withValues(alpha: 0.05),
              const Color(0xFF7A5CB0).withValues(alpha: 0.0),
            ],
            const [0.0, 0.45, 0.9],
          ),
      );
      canvas.drawPath(
        g.flags,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFE8D2A8).withValues(alpha: 0.12),
      );
      canvas.drawPath(
        g.shadows,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.46),
      );
      canvas.drawPath(
        g.bodies,
        Paint()..color = const Color(0xFF191526).withValues(alpha: 0.88),
      );
      canvas.drawPath(
        g.caps,
        Paint()..color = const Color(0xFFE8D2A8).withValues(alpha: 0.26),
      );
      canvas.drawPath(
        g.mouths,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.85),
      );
      canvas.drawPath(
        g.edges,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFE8D2A8).withValues(alpha: 0.22),
      );
    }
    canvas.restore();
  }

  /// THE LIGHT-WALKS' FLOOR. A light-walk is a doorway whose floor is made of
  /// light: a short causeway of pale flags runs in from the sill while its
  /// quarter is lit, and in shadow its middle flags are simply gone, a gap of
  /// nothing between the first and the last. The glass above stays a doorway
  /// either way — it is never locked, it has no floor. Shadow-ways need no
  /// mark: they are glass or they are wall (see `_renderGlassDoorPlugs`).
  /// The flags fall and come back on the same eased clock as the walls.
  void _renderVaultSpans(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    for (final d in room.doors) {
      final span = _vaultSpanFor(room, d);
      if (span == null || span.cut != SpanCut.lightWalk) continue;
      final r = d.rect;
      // Inward from the wall the door is cut through, and across it.
      final Offset inward;
      final Offset sill;
      if (r.left <= b.left + 1) {
        inward = const Offset(1, 0);
        sill = Offset(b.left + kGlassWallTop, r.center.dy);
      } else if (r.right >= b.right - 1) {
        inward = const Offset(-1, 0);
        sill = Offset(b.right - kGlassWallTop, r.center.dy);
      } else if (r.top <= b.top + 1) {
        inward = const Offset(0, 1);
        sill = Offset(r.center.dx, b.top + _glassFaceDepth);
      } else {
        inward = const Offset(0, -1);
        sill = Offset(r.center.dx, b.bottom - kGlassWallTop);
      }
      final across = Offset(-inward.dy, inward.dx);
      final half = (inward.dx != 0 ? r.height : r.width) * 0.5 - 12;
      final open = _worldDoorOpen(room, d);
      const flags = 4;
      const depth = 15.0;
      if (open < 0.99) {
        // THE HOLE the middle flags leave: a ragged pit with a pale broken
        // lip on its near side, so the gap reads as missing floor even on
        // the umbra's dark ground.
        final n0 = sill + inward * (1 * (depth + 3));
        final n1 = sill + inward * (2 * (depth + 3) + depth + 4);
        final w = half - 4;
        Offset at(Offset o, double t) => o + across * (w * t);
        final hole = Path()
          ..moveTo(at(n0, 1).dx, at(n0, 1).dy);
        for (final t in const [0.6, 0.25, -0.2, -0.55, -1.0]) {
          final j = n0 + inward * (t * 7 % 3 - 1.5);
          hole.lineTo(at(j, t).dx, at(j, t).dy);
        }
        for (final t in const [-1.0, -0.5, -0.1, 0.35, 0.7, 1.0]) {
          final j = n1 + inward * (t * 5 % 3 - 1.5);
          hole.lineTo(at(j, t).dx, at(j, t).dy);
        }
        hole.close();
        final gone = 1 - open;
        canvas.drawPath(
          hole.shift(-inward * 2.5),
          Paint()..color = _kVaultBone.withValues(alpha: 0.22 * gone),
        );
        canvas.drawPath(
          hole,
          Paint()..color = const Color(0xFF050409).withValues(alpha: 0.95 * gone),
        );
      }
      for (var i = 0; i < flags; i++) {
        final near = sill + inward * (i * (depth + 3) + 2);
        final far = near + inward * depth;
        // Each flag narrows a little and sits a little off true, so the
        // causeway reads as laid stone and not as a stripe.
        final w = half - i * 3.0;
        final skew = across * ((i.isEven ? 1.5 : -1.5));
        final flag = Path()
          ..moveTo(near.dx + across.dx * w, near.dy + across.dy * w)
          ..lineTo(near.dx - across.dx * w, near.dy - across.dy * w)
          ..lineTo(
            far.dx - across.dx * w + skew.dx,
            far.dy - across.dy * w + skew.dy,
          )
          ..lineTo(
            far.dx + across.dx * w + skew.dx,
            far.dy + across.dy * w + skew.dy,
          )
          ..close();
        // The middle two are the ones that go; the end flags only dim.
        final middle = i == 1 || i == 2;
        final there = middle ? open : 0.45 + 0.55 * open;
        if (there <= 0.01) continue;
        final mid = (near + far) / 2;
        canvas.drawPath(
          flag,
          Paint()
            ..shader = ui.Gradient.linear(
              mid + across * w,
              mid - across * w,
              [
                _kVaultBone.withValues(alpha: 0.40 * there),
                _kVaultBone.withValues(alpha: 0.22 * there),
              ],
            ),
        );
        // The flag's shadowed far edge, so it is a slab and not a decal.
        canvas.drawLine(
          far + across * w + skew,
          far - across * w + skew,
          Paint()
            ..strokeWidth = 2.4
            ..color = _kVaultVoid.withValues(alpha: 0.6 * there),
        );
      }
    }
  }

  static const Color _kVaultRust = Color(0xFF9A5A2C);
  static const Color _kVaultBronze = Color(0xFF6B5A2E);

  /// A stone finger: a tapered obelisk on a collar, drawn the same way as a
  /// gnomon and as the abyss's raised fourth finger.
  void _drawFinger(Canvas canvas, Offset at, {double h = 60, double w = 16}) {
    canvas.drawOval(
      Rect.fromCenter(
        center: at + Offset(0, h * 0.34),
        width: w * 2.6,
        height: w,
      ),
      Paint()..color = _kVaultBronze.withValues(alpha: 0.9),
    );
    // Black glass, leaded: two facets, the lit one catching violet (§7.11).
    _drawGlassFinger(canvas, at, h, w, lit: 0);
  }

  /// The shadow a finger throws: a hard wedge lying away from its base toward
  /// the quarter it is holding. Direction is the whole read.
  Path _shadowWedge(Offset at, bool down, double length) {
    final sgn = down ? 1.0 : -1.0;
    final base = at.dy + sgn * 22;
    final tip = base + sgn * length;
    return Path()
      ..moveTo(at.dx - 10, base)
      ..lineTo(at.dx + 10, base)
      ..lineTo(at.dx + 4, tip)
      ..lineTo(at.dx - 4, tip)
      ..close();
  }

  void _renderVaultObjects(Canvas canvas, DungeonRoom room) {
    final hall = room.eclipse;
    if (hall == null) return;

    // THE OBSTACLES: slabs of obsidian lying on the void — a black body, a
    // bevelled top catching the disc's violet, and a thin line of its gold
    // along the edge nearest the room's light.
    for (final w in room.walls) {
      canvas.drawRect(
        w.translate(0, 6).inflate(2),
        Paint()..color = Colors.black.withValues(alpha: 0.5),
      );
      canvas.drawRect(
        w,
        Paint()
          ..shader = ui.Gradient.linear(w.topCenter, w.bottomCenter, [
            const Color(0xFF2A2340),
            const Color(0xFF0C0A14),
          ]),
      );
      final top = Rect.fromLTWH(w.left + 4, w.top + 3, w.width - 8, w.height * 0.4);
      canvas.drawRect(
        top,
        Paint()
          ..shader = ui.Gradient.linear(top.centerLeft, top.centerRight, [
            _kVaultViolet.withValues(alpha: 0.10),
            _kVaultViolet.withValues(alpha: 0.38),
            _kVaultViolet.withValues(alpha: 0.08),
          ], const [0, 0.55, 1]),
      );
      canvas.drawLine(
        w.topLeft + const Offset(2, 1),
        w.topRight + const Offset(-2, 1),
        Paint()
          ..strokeWidth = 1.4
          ..color = const Color(0xFFF2C98E).withValues(alpha: 0.35),
      );
    }

    // THE GNOMON: a finger of black glass on a bronze collar, and the hard
    // wedge of shadow it throws toward the quarter it is holding — up the
    // room for its upper quarter, down for its lower. WHERE YOU STAND TELLS
    // YOU WHAT THE PRESS WILL DO: with a night-hand in reach the OTHER wedge
    // is ghosted in, so the turn can be read before it is made.
    final g = vaultGnomonIn(room.id);
    if (g != null) {
      final at = g.shaft;
      final down = vault.shadowOf(g.id) == g.lower;
      final a = active;
      final inReach =
          a != null &&
          (a.position - at).distance <= _kVaultReach &&
          _vaultHasNightHand(a);
      // The wedge swings over on the turn's own wipe: it shortens into the
      // collar on the side it leaves and grows out on the side it enters.
      var grow = 1.0;
      if (vault.wipe > 0) grow = _vaultWipeT;
      if (grow < 1) {
        final leaving = _shadowWedge(at, !down, 78 * (1 - grow));
        canvas.drawPath(
          leaving,
          Paint()..color = _kVaultVoid.withValues(alpha: 0.85 * (1 - grow)),
        );
      }
      final wedge = _shadowWedge(at, down, 78 * grow);
      canvas.drawPath(
        wedge,
        Paint()
          ..shader = ui.Gradient.linear(
            at,
            at + Offset(0, down ? 100 : -100),
            [
              _kVaultVoid.withValues(alpha: 0.92),
              const Color(0xFF2A1E44).withValues(alpha: 0.8),
            ],
          ),
      );
      if (inReach && vault.wipe <= 0) {
        // Where the shadow would go: a faint violet wedge, breathing.
        final ghost = _shadowWedge(at, !down, 78);
        canvas.drawPath(
          ghost,
          Paint()
            ..color = _kVaultViolet.withValues(
              alpha: 0.16 + 0.08 * sin(_time * 3),
            ),
        );
      }
      _drawFinger(canvas, at);
    }

    // THE ANALEMMA: the figure-of-eight dial cut into the floor with its hour
    // ticks, and four stone plinths standing on it — a top face and a near
    // face, so a stone is a block and not an index card. See
    // `_drawShadowStone` for how each one says what it needs.
    if (hall.analemma != null) {
      final c = hall.analemma!;
      // The figure of eight is a GROOVE cut into the pavement with a bronze
      // inlay laid in it, and its hour marks are bronze studs — a floor
      // instrument, not two hairline circles.
      final groove = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = _kVaultVoid.withValues(alpha: 0.55);
      final inlay = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = _kVaultBronze.withValues(alpha: 0.75);
      final stud = Paint()..color = _kVaultBronze.withValues(alpha: 0.9);
      for (final dy in [-34.0, 34.0]) {
        final cc = c + Offset(0, dy);
        canvas.drawCircle(cc, 46, groove);
        canvas.drawCircle(cc, 46, inlay);
        for (var i = 0; i < 12; i++) {
          final t = i * pi / 6;
          canvas.drawCircle(
            cc + Offset(cos(t), sin(t)) * 38,
            i % 3 == 0 ? 2.6 : 1.6,
            stud,
          );
        }
      }
      for (final s in kShadowStones) {
        _drawShadowStone(canvas, s);
      }
    }

    // THE ANCHORS: an iron ring set in a dark socket. Rusted, it weeps rust
    // down the stone; eaten clean it is violet; and once the hole on the far
    // side is actually open the socket goes to nothing with a slow turn in it.
    for (final an in vaultAnchorsIn(room.id)) {
      _drawIronRing(
        canvas,
        an.ringIn(room.id)!,
        vault.anchorsOpen.contains(an.id),
        through:
            vault.anchorsOpen.contains(an.id) &&
            vault.portalOpen(an, _vaultLeaves),
      );
    }

    // THE SNUFFER: three lamps on brackets, alight until the rite puts them
    // out. A flame is a shape that moves, not a yellow dot.
    if (hall.snuffer != null) {
      final lit = (conduitEnergy['B'] ?? 0) <= 0;
      for (var i = 0; i < 3; i++) {
        final at = hall.snuffer! + Offset(-40.0 + i * 40.0, 0);
        canvas.drawLine(
          at + const Offset(0, 26),
          at + const Offset(0, 8),
          Paint()
            ..color = _kVaultBronze
            ..strokeWidth = 3,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: at + const Offset(0, 28),
            width: 18,
            height: 6,
          ),
          Paint()..color = _kVaultBronze.withValues(alpha: 0.8),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: at + const Offset(0, 4),
              width: 16,
              height: 12,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = (lit ? _kVaultBronze : _kVaultVoid),
        );
        if (lit) {
          final f = 0.8 + 0.2 * sin(_time * 9 + i * 2.1);
          final flame = Path()
            ..moveTo(at.dx, at.dy - 22 * f)
            ..quadraticBezierTo(at.dx + 7, at.dy - 8, at.dx, at.dy - 2)
            ..quadraticBezierTo(at.dx - 7, at.dy - 8, at.dx, at.dy - 22 * f)
            ..close();
          canvas.drawPath(
            flame,
            Paint()..color = _kVaultEmber.withValues(alpha: 0.9),
          );
          canvas.drawCircle(
            at + const Offset(0, -8),
            3,
            Paint()..color = Colors.white.withValues(alpha: 0.8),
          );
          for (var k = 2; k >= 1; k--) {
            canvas.drawCircle(
              at + const Offset(0, -10),
              14.0 * k,
              Paint()..color = _kVaultEmber.withValues(alpha: 0.06),
            );
          }
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: at + const Offset(0, 4),
                width: 16,
                height: 12,
              ),
              const Radius.circular(3),
            ),
            Paint()
              ..color = _kVaultViolet.withValues(alpha: 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        }
      }
    }

    // THE PALL: a cloth knotted across the arch, in folds, while it hangs.
    if (hall.pallCurtain != null && !entryDoorRevealed) {
      final at = hall.pallCurtain!;
      final cloth = Rect.fromCenter(center: at, width: 58, height: 100);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cloth, const Radius.circular(6)),
        Paint()..color = _kVaultVoid.withValues(alpha: 0.92),
      );
      for (var i = 0; i < 5; i++) {
        final x = cloth.left + 8 + i * 10.5;
        canvas.drawPath(
          Path()
            ..moveTo(x, cloth.top + 10)
            ..quadraticBezierTo(
              x + (i.isEven ? 5 : -5),
              cloth.center.dy,
              x,
              cloth.bottom - 4,
            ),
          Paint()
            ..color = _kVaultViolet.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(at.dx, cloth.top + 8),
          width: 22,
          height: 12,
        ),
        Paint()..color = _kVaultViolet.withValues(alpha: 0.7),
      );
    }

    // THE ABYSS: a well with a bone rim. In the dark it is a hole with nothing
    // drawn in it. In the LIGHT it has a bottom — courses of pewter stepping
    // down, and on the floor of it the fourth finger, fallen, on its chain to
    // the rusted ring at the rim. Read, the chain shows its three lengths;
    // freed, the ring is clean; hauled, the finger rises a length a press and
    // finally stands at the rim.
    if (hall.abyss != null) {
      final at = hall.abyss!;
      final found = discoveredClouds.contains(kDarkAbyssEggId);
      final lit = abyssLit || found;
      canvas.drawCircle(at, 58, Paint()..color = _kVaultVoid);
      canvas.drawCircle(
        at,
        58,
        Paint()
          ..color = _kVaultBone.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final ring = _abyssRing(at);
      if (lit) {
        // Courses stepping down: the well has a bottom.
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            at + Offset(0, 4.0 * i),
            48.0 - i * 12,
            Paint()
              ..color = _kVaultPewter.withValues(alpha: 0.18 - i * 0.04)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8,
          );
        }
        canvas.drawCircle(
          at + const Offset(0, 12),
          16,
          Paint()..color = _kVaultPewter.withValues(alpha: 0.22),
        );
        final raised = found || vault.abyssRaised;
        if (!raised) {
          // Where the finger lies, by how much chain is in: on the floor of
          // the well, then a course up per haul.
          final t = vault.abyssHauls / EclipseVault.abyssChainLengths;
          final lie = Offset.lerp(
            at + const Offset(0, 12),
            ring + const Offset(-22, 14),
            t,
          )!;
          final len = 34 + 12 * t;
          canvas.save();
          canvas.translate(lie.dx, lie.dy);
          canvas.rotate(-0.9 + 0.9 * t);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: len,
                height: 10 + 3 * t,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = _kVaultVoid,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: len,
                height: 10 + 3 * t,
              ),
              const Radius.circular(2),
            ),
            Paint()
              ..color = _kVaultViolet.withValues(alpha: 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
          canvas.restore();
          // The chain, from the finger up to the ring.
          final chain = Paint()
            ..color = (vault.abyssChainFree ? _kVaultBone : _kVaultRust)
                .withValues(alpha: 0.75)
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round;
          const seg = 7.0;
          final d = ring - lie;
          final n = (d.distance / seg).floor();
          for (var i = 0; i < n; i += 2) {
            canvas.drawLine(
              lie + d * (i / n),
              lie + d * (min(n, i + 1) / n),
              chain,
            );
          }
          if (vault.abyssRead) {
            // Three lengths, read: the marks a walker leaves along a road.
            for (var i = 1; i <= EclipseVault.abyssChainLengths; i++) {
              final q = lie + d * (i / (EclipseVault.abyssChainLengths + 1));
              canvas.drawCircle(
                q,
                3.5,
                Paint()..color = _kVaultViolet.withValues(alpha: 0.9),
              );
            }
          }
        } else {
          // THE FOURTH FINGER, stood: rising at the rim as the rite binds,
          // and lit violet for good (planet_dungeon_game_dark_art.dart).
          _drawFourthFinger(canvas, ring + const Offset(-4, -24));
        }
        _drawIronRing(
          canvas,
          ring,
          vault.abyssChainFree || found,
          through: false,
          small: true,
        );
      }
    }

    // THE VANE: a floor disc with a graduated rim, and a handle lying to the
    // quarter the stair gnomon's shadow is in — the arena's hand on the same
    // finger.
    if (hall.shadowVane != null) {
      final at = hall.shadowVane!;
      final down = vault.shadowOf('gn_stair') == EclipseLeaf.deep;
      canvas.drawCircle(
        at,
        26,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        at,
        26,
        Paint()
          ..color = _kVaultViolet.withValues(alpha: down ? 0.85 : 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      for (var i = 0; i < 8; i++) {
        final t = i * pi / 4;
        canvas.drawLine(
          at + Offset(cos(t), sin(t)) * 26,
          at + Offset(cos(t), sin(t)) * 21,
          Paint()
            ..color = _kVaultBone.withValues(alpha: 0.45)
            ..strokeWidth = 1.2,
        );
      }
      final tip = at + Offset(0, down ? 22 : -22);
      canvas.drawLine(
        at,
        tip,
        Paint()
          ..color = _kVaultViolet
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        tip,
        5,
        Paint()..color = _kVaultBone.withValues(alpha: 0.9),
      );
      canvas.drawCircle(at, 4, Paint()..color = _kVaultBronze);
    }
  }

  /// One shadow-stone on the dial. It says three things without a word:
  ///
  ///  · WHO seats it — a leaded pane in its element's glass set in its top;
  ///  · WHETHER it can go now — the court's floor under it is its QUARTER'S
  ///    light: a pool of umbra while that quarter is in shadow (it will
  ///    seat), a hard coin-coloured patch while it is lit (it will not). The
  ///    pool changes over on the wipe of the turn that changed it, so from
  ///    the court you can watch a turn made anywhere land on its stone;
  ///  · and that it is DONE — seated, it has sunk to its shoulders in the
  ///    dial and its pane burns steady.
  void _drawShadowStone(Canvas canvas, ShadowStone s) {
    final seated = vault.stonesSeated.contains(s.id) || hasStar(0);
    final nowDark = vault.isDark(s.leaf);
    var shade = nowDark ? 1.0 : 0.0;
    if (vault.wipe > 0 && vault.wipeFrom.contains(s.leaf) != nowDark) {
      final t = _vaultWipeT;
      shade = nowDark ? t : 1 - t;
    }
    final at = s.position;
    if (!seated) {
      // The quarter's light, on the floor round the stone.
      final pool = Rect.fromCenter(
        center: at + const Offset(0, 6),
        width: 64,
        height: 40,
      );
      if (shade > 0.01) {
        canvas.drawOval(
          pool,
          Paint()
            ..shader = ui.Gradient.radial(pool.center, 32, [
              const Color(0xFF2A1E44).withValues(alpha: 0.85 * shade),
              const Color(0xFF2A1E44).withValues(alpha: 0),
            ]),
        );
      }
      if (shade < 0.99) {
        canvas.drawOval(
          pool.deflate(4),
          Paint()
            ..shader = ui.Gradient.radial(pool.center, 28, [
              _kVaultBone.withValues(alpha: 0.30 * (1 - shade)),
              _kVaultBone.withValues(alpha: 0.10 * (1 - shade)),
              _kVaultBone.withValues(alpha: 0),
            ], const [0, 0.7, 1]),
        );
      }
    }
    // Seated, the stone sits lower in the dial: a shorter near face.
    final faceH = seated ? 4.0 : 9.0;
    final top = Rect.fromCenter(
      center: at + Offset(0, seated ? -1 : -5),
      width: 26,
      height: 17,
    );
    final face = Rect.fromLTWH(top.left, top.bottom, top.width, faceH);
    canvas.drawRect(
      face,
      Paint()..color = seated ? _kVaultVoid : const Color(0xFF3A3848),
    );
    canvas.drawRect(
      top,
      Paint()
        ..color = seated
            ? const Color(0xFF15121E)
            : Color.lerp(
                const Color(0xFF6D6C7C),
                const Color(0xFF3E3654),
                shade,
              )!,
    );
    // The pane: the element's own planet glass (venom green, wraith pale,
    // umbra violet — the element colours proper are three purples), muted
    // toward the vault's dark, lit by being available and burning once
    // seated.
    final el = (_glassPalettes[s.element] ?? _kUmbraGlass).live;
    final pane = Path()
      ..addRRect(
        RRect.fromRectAndRadius(top.deflate(4.5), const Radius.circular(2)),
      );
    final heat = seated ? 0.95 : 0.35 + 0.35 * shade;
    paintPane(
      canvas,
      pane,
      Color.lerp(const Color(0xFF15121E), el, heat)!,
      _kUmbraGlass,
      lead: 1.6,
    );
    if (seated || shade > 0.5) {
      final breathe = seated ? 0.8 : 0.55 + 0.25 * sin(_time * 2.4);
      canvas.drawRect(
        top.deflate(7),
        Paint()
          ..color = Color.lerp(el, Colors.white, 0.5)!.withValues(
            alpha: 0.35 * breathe * (seated ? 1 : shade),
          ),
      );
    }
  }

  /// An iron ring in a socket. Rusted (weeping down the stone), eaten clean
  /// (violet), or [through]: a hole in the dark, with a slow turn in it.
  void _drawIronRing(
    Canvas canvas,
    Offset at,
    bool clean, {
    required bool through,
    bool small = false,
  }) {
    final r = small ? 11.0 : 15.0;
    canvas.drawCircle(
      at,
      r + 5,
      Paint()..color = _kVaultVoid.withValues(alpha: 0.75),
    );
    if (through) {
      canvas.drawCircle(at, r - 3, Paint()..color = _kVaultVoid);
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: r - 6),
        _time * 1.6,
        2.2,
        false,
        Paint()
          ..color = _kVaultViolet.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..color = clean ? _kVaultViolet : _kVaultRust.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = small ? 3 : 4,
    );
    if (!clean) {
      for (var i = 0; i < 3; i++) {
        final x = at.dx - 6 + i * 6.0;
        canvas.drawLine(
          Offset(x, at.dy + r),
          Offset(x + 1, at.dy + r + 9 + (i == 1 ? 6 : 0)),
          Paint()
            ..color = _kVaultRust.withValues(alpha: 0.55)
            ..strokeWidth = 2,
        );
      }
    }
  }

  /// How far the wipe has crossed the room, eased: 0 → 1.
  double get _vaultWipeT => Curves.easeInOut.transform(
    (1.0 - vault.wipe / _kVaultWipeSeconds).clamp(0.0, 1.0),
  );

  /// The turn's edge crossing the room: a band of violet light, brightest at
  /// the edge and falling off behind it, so the world reads as turning over
  /// rather than as a bar sliding past. Nothing is drawn when it is still.
  void _renderVaultWipe(Canvas canvas, DungeonRoom room) {
    if (vault.wipe <= 0) return;
    final t = _vaultWipeT;
    final b = room.bounds;
    final x = b.left + b.width * t;
    final fade = sin(t * pi).clamp(0.0, 1.0);
    final band = Rect.fromLTRB(x - 90, b.top, x + 6, b.bottom).intersect(b);
    if (band.width <= 0) return;
    canvas.drawRect(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x - 90, 0),
          Offset(x + 6, 0),
          [
            _kVaultViolet.withValues(alpha: 0),
            _kVaultViolet.withValues(alpha: 0.18 * fade),
            _kVaultViolet.withValues(alpha: 0.42 * fade),
            _kVaultViolet.withValues(alpha: 0),
          ],
          const [0, 0.7, 0.94, 1],
        ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// THE VAULT'S GROUND — built once, drawn forever
// ═══════════════════════════════════════════════════════════
//
// Nythralor is a place you travel by shadow, so the only honest way to draw it
// is to draw THE THINGS THAT CAST and the floor the shadow lands on. All of
// that geometry is static: it is a function of the room's own bounds and its
// id, so it is built once, cached, and thereafter costs a handful of drawPath
// calls. The only per-frame arithmetic on this planet's ground is a guttering
// flame phase.

/// Every room's masonry, keyed by room id and bounds. A top-level map rather
/// than a field because the extension that renders it cannot carry state.
final Map<String, _VaultGround> _vaultGroundCache = {};



/// One room's static architecture, pre-flattened into as few paths as the
/// drawing needs. Merging each class of shape into ONE path is not only
/// cheaper — it is what stops overlapping cast shadows from double-darkening
/// where two pillars stand close together, because a single path fills once.
class _VaultGround {
  /// The ashlar seams and the long cracks across them (stroke).
  final Path flags;

  /// Flags that have dropped out of the floor (fill).
  final Path sunken;

  /// Every cast shadow in the room, unioned (fill). In UMBRA this is the only
  /// lit floor there is.
  final Path shadows;

  /// The bars of light a pierced screen lets past, cut back through its own
  /// shadow (fill).
  final Path stripes;

  /// The footprints of everything that casts (fill in CORONA, stroked for its
  /// contours in UMBRA).
  final Path bodies;

  /// The faces turned toward the light — drum tops, the nosing of a stair
  /// tread, the bone in a loculus (fill).
  final Path caps;

  /// Contours that are not a body's own outline: tread risers, the font's
  /// rings, jambs, joint lines (stroke).
  final Path edges;

  /// Openings — niches, loculi, the throat of a well (fill, void).
  final Path mouths;

  /// The fissure light lying across the floor (fill). Inverted in UMBRA.
  final Path shaftLight;

  /// Lamp flames, for the one thing here that animates.
  final List<Offset> lamps;

  const _VaultGround({
    required this.flags,
    required this.sunken,
    required this.shadows,
    required this.stripes,
    required this.bodies,
    required this.caps,
    required this.edges,
    required this.mouths,
    required this.shaftLight,
    required this.lamps,
  });
}

/// A tiny LCG. Deliberately not `dart:math`'s Random: the vault must look the
/// same every time the room is entered, in the same process or a later one, so
/// the seed is the room's own geometry and nothing else.
class _VaultRng {
  int _s;
  _VaultRng(int seed) : _s = (seed.abs() * 2 + 1) & 0x7FFFFFFF;

  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7FFFFFFF;
    return _s / 0x7FFFFFFF;
  }

  double range(double a, double b) => a + next() * (b - a);
  int pick(int n) => (next() * n).floor().clamp(0, n - 1);
  bool chance(double p) => next() < p;
}

_VaultGround _vaultGroundFor(DungeonRoom room, DungeonLayout layout) {
  final b = room.bounds;
  final key = '${room.id}|${b.width.toInt()}x${b.height.toInt()}';
  return _vaultGroundCache.putIfAbsent(
    key,
    () => _buildVaultGround(room, layout),
  );
}

List<Offset> _rectCorners(Rect r) => [
  r.topLeft,
  r.topRight,
  r.bottomRight,
  r.bottomLeft,
];

/// The corners of a rect turned through [a] about [c] — for anything that has
/// fallen over, which is most of what is left standing down here.
List<Offset> _tiltedCorners(
  Offset c,
  double halfLen,
  double halfWid,
  double a,
) {
  final co = cos(a), si = sin(a);
  return [
    for (final s in const [(-1, -1), (1, -1), (1, 1), (-1, 1)])
      Offset(
        c.dx + s.$1 * halfLen * co - s.$2 * halfWid * si,
        c.dy + s.$1 * halfLen * si + s.$2 * halfWid * co,
      ),
  ];
}

/// Throw [corners]' shadow [len] along [dir].
///
/// The two corners that matter are the ones furthest apart PERPENDICULAR to
/// the light — the silhouette edge — so the quad is stretched from those and
/// nothing else. That is the whole of the shadow model, and it is why an
/// oblique room still gets shadows that agree with one another: every object
/// in a room uses the same [dir].
///
/// [taper] narrows the far end. The first version did not, and every drum in
/// the room came out as a LOZENGE — body and shadow the same width and the
/// same darkness, reading as one solid object lying on the floor rather than
/// as a pillar and the dark it throws. A shadow that closes toward its tip is
/// the cheapest thing that makes the difference legible.
void _castShadow(
  Path into,
  List<Offset> corners,
  Offset dir,
  double len, {
  double taper = 0.62,
}) {
  final nx = -dir.dy, ny = dir.dx;
  var lo = corners.first, hi = corners.first;
  var loV = double.infinity, hiV = -double.infinity;
  for (final c in corners) {
    final v = c.dx * nx + c.dy * ny;
    if (v < loV) {
      loV = v;
      lo = c;
    }
    if (v > hiV) {
      hiV = v;
      hi = c;
    }
  }
  final far = Offset((lo.dx + hi.dx) / 2, (lo.dy + hi.dy) / 2) + dir * len;
  final half = (hi - lo) * 0.5 * taper;
  into
    ..moveTo(lo.dx, lo.dy)
    ..lineTo(hi.dx, hi.dy)
    ..lineTo(far.dx + half.dx, far.dy + half.dy)
    ..lineTo(far.dx - half.dx, far.dy - half.dy)
    ..close();
}

_VaultGround _buildVaultGround(DungeonRoom room, DungeonLayout layout) {
  final b = room.bounds;
  // Seeded from the room's own bounds, plus a content hash of its id so two
  // rooms that happen to be the same size are not the same room. Computed by
  // hand rather than via String.hashCode so it can never depend on anything
  // outside this function.
  var idHash = 7;
  for (final u in room.id.codeUnits) {
    idHash = (idHash * 31 + u) & 0xFFFFF;
  }
  final rng = _VaultRng(
    b.width.toInt() * 733 + b.height.toInt() * 191 + idHash,
  );

  final flags = Path();
  final sunken = Path();
  final shadows = Path();
  final stripes = Path();
  final bodies = Path();
  final caps = Path();
  final edges = Path();
  final mouths = Path();
  final shaftLight = Path();
  final lamps = <Offset>[];

  // ── THE LIGHT ──────────────────────────────────────────
  // One direction for the whole room, always with a downward component, so the
  // source reads as a fissure high in the north wall and every shadow in the
  // room agrees with every other. Which way it leans varies per room; that
  // variation is most of why the ten rooms do not look like one room.
  final ang = rng.chance(0.5) ? rng.range(1.06, 1.42) : rng.range(1.72, 2.08);
  final dir = Offset(cos(ang), sin(ang));

  /// Everything standing in a room is sized against the room. Without this the
  /// reliquary — 420×320, the smallest room on the planet — got full-size
  /// screens whose shadows crossed the whole floor, and read as three enormous
  /// objects in a cupboard.
  final sizeScale = (min(b.width, b.height) / 470).clamp(0.62, 1.12);

  // ── THE FLOOR ──────────────────────────────────────────
  // Ashlar, not a lattice. Course heights vary by nearly two to one, the flags
  // in a course vary by three to one, each course starts at a different offset
  // and the seam itself is broken into runs with gaps — so no two joints ever
  // line up into a column and the eye cannot find a repeat.
  var y = b.top + rng.range(18, 54) * sizeScale;
  while (y < b.bottom - 12) {
    // A course seam, in runs. A continuous line across the room would read as
    // a stripe, which is the lattice problem wearing a different hat.
    var sx = b.left;
    while (sx < b.right) {
      final run = rng.range(110, 340) * sizeScale;
      final ex = min(sx + run, b.right);
      flags
        ..moveTo(sx, y)
        ..lineTo(ex, y);
      sx = ex + (rng.chance(0.34) ? rng.range(34, 96) : 0.0);
    }
    final h = rng.range(46, 88) * sizeScale;
    // The flags within the course.
    var x = b.left + rng.range(-80, -10);
    while (x < b.right) {
      final w = rng.range(62, 196) * sizeScale;
      final fx = x + w;
      if (fx > b.left + 6 && fx < b.right - 6) {
        flags
          ..moveTo(fx, y + 2)
          ..lineTo(fx, min(y + h, b.bottom) - 2);
      }
      // A flag that has dropped out of the floor. Twice this read wrong before
      // it read right. A clean dark RECTANGLE — outlined or not — sits ON a
      // floor like a hatch, it does not sink into one, so the hole is an
      // irregular polygon now. And it got a lit lip for a while, which turned
      // it into a small standing BLOCK in the umbra, where the hole itself is
      // invisible and only the lip showed. A hole in a dark floor is nothing
      // at all; that is the point of it.
      x = fx;
    }
    y += h;
  }
  // ── WHAT EACH ROOM ACTUALLY IS ─────────────────────────
  // THE BLACK HOLE PASS (2026-09-25, from the author: "unused clutter", and
  // it should read as a black-hole mystical level). Every room used to be
  // ringed with fallen columns, drums, pierced screens, loculi, lamp
  // brackets, rubble and bars of fissure light, none of which you could
  // use. They are gone. What stays is what the room is FOR: the stair down
  // to the gulf, the kerb of the abyss, the reliquary's plinth, and the
  // plinths the gnomons and the vane stand on. The floor is flags over the
  // void, and the light on it comes from the disc (`_renderVaultGround`).
  switch (room.id) {
    case 'gnomon_stair':
      // A STAIR, descending to the gulf under the last step (the door at
      // x 200–310 on the south wall). Treads narrow as they go down and each
      // carries a lit nosing and a riser shadow, which is what makes a flight
      // read as a flight from above.
      var w = 330.0;
      var ty = b.bottom - 214;
      for (var i = 0; i < 7; i++) {
        final r = Rect.fromCenter(
          center: Offset(255, ty),
          width: w,
          height: 24,
        );
        shadows.addRect(Rect.fromLTWH(r.left, r.bottom - 7, r.width, 9));
        caps.addRect(Rect.fromLTWH(r.left + 6, r.top, r.width - 12, 3));
        edges.addRect(r);
        ty += 27;
        w -= 26;
      }

    case 'abyssal_font':
      // A KERB round the abyss: one course of stone blocks, filled, with the
      // side toward the light catching it. It used to be three broken
      // contour rings stepping out from the well, which read as a target
      // painted on the floor.
      final c = room.eclipse!.abyss!;
      final kerb = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: c, radius: 74)),
        Path()..addOval(Rect.fromCircle(center: c, radius: 60)),
      );
      _castShadow(
        shadows,
        _rectCorners(Rect.fromCircle(center: c, radius: 74)),
        dir,
        22,
        taper: 0.7,
      );
      bodies.addPath(kerb, Offset.zero);
      // Joints between the blocks, short and uneven.
      var ka = rng.range(0, 0.6);
      while (ka < pi * 2) {
        edges
          ..moveTo(c.dx + cos(ka) * 60, c.dy + sin(ka) * 60)
          ..lineTo(c.dx + cos(ka) * 74, c.dy + sin(ka) * 74);
        ka += rng.range(0.34, 0.62);
      }
      for (var k = -3; k <= 3; k++) {
        final aa = ang + pi + k * 0.2;
        caps.addPolygon(
          _tiltedCorners(
            c + Offset(cos(aa), sin(aa)) * 70,
            7.0,
            2.6,
            aa + pi / 2,
          ),
          true,
        );
      }

    case 'umbral_reliquary':
      // The room that is only here in the dark. Whatever the vault is keeping
      // stands on a stepped plinth rather than on the bare floor — the same
      // rule the rest of this pass follows: everything is standing ON
      // something.
      final c = room.vaultCache;
      if (c != null) {
        // Drawn as SOLID steps, not as outlines. The first attempt was three
        // nested stroked rectangles and it read as a selection box sitting on
        // the floor — an interface element, in the one room whose whole point
        // is that it is a real room you can only be in half the time.
        final base = Rect.fromCenter(center: c, width: 84, height: 60);
        _castShadow(shadows, _rectCorners(base), dir, 34, taper: 0.55);
        for (var i = 0; i < 2; i++) {
          final r = Rect.fromCenter(
            center: c + Offset(0, i * 3.0),
            width: 84 - i * 24,
            height: 60 - i * 18,
          );
          bodies.addRect(r);
          caps.addRect(Rect.fromLTWH(r.left + 3, r.top, r.width - 6, 3.0));
        }
      }
  }

  // ── SOCKETS ────────────────────────────────────────────
  // A gnomon is the one piece of architecture on this planet that the player
  // actually handles, and it was standing on nothing. It gets a collar and a
  // plinth in the floor — the shadow bar itself stays where it belongs, in
  // `_renderVaultObjects`, because that bar is the mechanic and not scenery.
  final gn = vaultGnomonIn(room.id);
  if (gn != null) {
    // A squared plinth the collar stands on, lit on its light side. (It was
    // two rings with spokes between them, which read as a dial the gnomon
    // was the hand of.)
    final plinth = Rect.fromCenter(
      center: gn.shaft + const Offset(0, 20),
      width: 58,
      height: 30,
    );
    _castShadow(shadows, _rectCorners(plinth), dir, 18, taper: 0.6);
    bodies.addRect(plinth);
    caps.addRect(Rect.fromLTWH(plinth.left + 3, plinth.top, plinth.width - 6, 3));
  }
  final vane = room.eclipse?.shadowVane;
  if (vane != null) {
    // The arena's vane is set into a floor plate, squared so it does not read
    // as one more ring in a room full of them. It has to be a PLATE and not
    // two stroked squares — the outline version read as a selection box drawn
    // over the floor, which on the one object the guardian fight is fought
    // around is the worst place to look like interface.
    final plate = Rect.fromCenter(center: vane, width: 86, height: 86);
    bodies.addRect(plate);
    mouths.addRect(Rect.fromCenter(center: vane, width: 58, height: 58));
    edges.addRect(plate.deflate(6));
    for (final c in _rectCorners(plate.deflate(9))) {
      caps.addOval(Rect.fromCircle(center: c, radius: 3.2));
    }
  }

  return _VaultGround(
    flags: flags,
    sunken: sunken,
    shadows: shadows,
    stripes: stripes,
    bodies: bodies,
    caps: caps,
    edges: edges,
    mouths: mouths,
    shaftLight: shaftLight,
    lamps: lamps,
  );
}
