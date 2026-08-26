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
//  • Lost Maxim — THE ABYSS (§6): stand utterly still in the abyssal font, in
//    total darkness, for a full minute, doing nothing at all.
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

/// What the vault was built to say.
const String kDarkAbyssMaxim =
    '"When you gaze long into the abyss, the abyss gazes also into you."';

// ── Device-tunable knobs ───────────────────────────────────
// Dark has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a gnomon, a stone, a ring, the pall,
/// the snuffer, the abyss or the vane to act on it.
const double _kVaultReach = 70.0;

/// How close the second body of a Poison+Spirit braid must stand (§6's
/// recipe — it substitutes the ELEMENT, never a family).
const double _kVaultBraidReach = 150.0;

/// A full minute (§6, "The Abyss"). The maxim is meant to be hard to stumble
/// into; this is the whole difficulty.
const double _kAbyssSeconds = 60.0;

/// How far a body may drift and still count as standing utterly still. A few
/// pixels of joystick noise must not cost the vigil.
const double _kAbyssDrift = 6.0;

/// Seconds an inversion's WIPE takes to cross the room. Purely visual.
const double _kVaultWipeSeconds = 0.45;

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
        ? 'No floor under it — $where lies in shadow'
        : 'Solid stone — $where stands in the light';
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Dark verb, in priority order. Returns true when one was consumed.
  /// The arena's floor-vane outranks the guardian's own catch (Ice's pillar,
  /// Lightning's spike and Plant's root-gall set that precedent) — the
  /// fight's errand must never be eaten by a strike.
  bool _tryVaultVerb(DungeonCreature a) {
    if (!_isVault) return false;
    final took =
        _tryPallCurtain(a) ||
        _tryShadowVane(a) ||
        _tryGnomon(a) ||
        _tryShadowStone(a) ||
        _tryShadowAnchor(a) ||
        _trySnuffer(a);
    // Any act at all breaks the vigil — the abyss answers a party that does
    // nothing, and "nothing" includes turning the world inside out.
    if (took) _breakVigil();
    return took;
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
      _setBlockedHint('Only Dark takes hold of its own cloth');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The pall comes off the arch — and Nythralor is not one shape');
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
      _setBlockedHint('Only Dark takes hold of a shadow');
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
      _setBlockedHint('Only Dark takes hold of a shadow');
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
    final entered = vault.turn(g.id)!;
    vault.wipe = _kVaultWipeSeconds;
    _setHint(
      'The shadow leaves ${leafWord(left)} and lies down over '
      '${leafWord(entered)}',
      3.0,
    );
    _spawnAlchemyBurst(
      at,
      producedElement: 'Dark',
      reagentElements: const ['Spirit'],
      particleCount: 34,
      intensity: 1.3,
    );
    // Every shadow-way that has just come into being in this room deserves
    // the reveal flourish; the ones that just stopped existing announce
    // themselves by not being there.
    for (final d in currentRoom.doors) {
      final span = _vaultSpanFor(currentRoom, d);
      if (span == null || !vault.spanOpen(span)) continue;
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
        _setBlockedHint('This stone answers ${s.element}');
        return true;
      }
      if (!vault.isDark(s.leaf)) {
        _setBlockedHint(
          '${leafWord(s.leaf)} stands in the light — the stone '
          'has nothing to read',
        );
        return true;
      }
      vault.stonesSeated.add(s.id);
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
        _setHint('The stone goes down — and something comes up off the dial');
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
              _setBlockedHint(
                'Only a Poison small enough to work inside the ring eats this '
                'rust',
              );
            }
            return true;
          case InteractionResult.blockedElement:
          case InteractionResult.blockedStat:
            _setBlockedHint('The rust in the ring answers Poison');
            return true;
        }
        vault.anchorsOpen.add(an.id);
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
        final far = an.other(currentRoomId)!;
        _setInsightHint('The far end comes out in ${_roomWord(far)}', 4.0);
        return true;
      }

      if (!vault.portalOpen(an, _vaultLeaves)) {
        final far = an.other(currentRoomId)!;
        final farLeaf = _leafOf(far)!;
        final mine = _leafOf(currentRoomId)!;
        _setBlockedHint(
          vault.isLit(mine)
              ? 'No hole here — ${leafWord(mine)} stands in the light'
              : 'The far side stands in the light',
        );
        // Name the far quarter only once the scout has read it: an unread
        // ring is supposed to be a hole into somewhere.
        if (vault.anchorsRead.contains(an.id)) {
          _setBlockedHint(
            'The ring is open, but ${leafWord(farLeaf)} stands in the light',
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
      _setHint(
        first
            ? 'You come out somewhere else, and something comes out with you'
            : 'Through, and out again',
        3.0,
      );
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
      _setBlockedHint('Only Dark puts out a light for good');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The lamps will not gutter — they answer only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
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
        _setHint(
          'Noctryos takes the shadow off the Deep — and the vault turns over '
          'above you',
        );
      }
    }
  }

  // ── The Lost Maxim · THE ABYSS ───────────────────────────

  /// §6's "The Abyss": stand utterly still in the total-darkness chamber for
  /// a full minute, casting no light. Deliberately beyond what the stars
  /// demand (§ "Easter eggs") — it wants the deep in shadow, the whole party
  /// in the font, and a full minute of doing NOTHING, which is the one thing
  /// a dungeon never asks for.
  ///
  /// "Casting no light" is approximated the only honest way the engine can
  /// today: any successful vault verb breaks the vigil (see `_tryVaultVerb`),
  /// as does any body moving more than [_kAbyssDrift].
  void _updateAbyss(DungeonRoom room, double dt) {
    if (room.eclipse?.abyss == null ||
        vault.abyssGazed ||
        discoveredClouds.contains(kDarkAbyssEggId) ||
        !vault.isDark(EclipseLeaf.deep)) {
      _breakVigil();
      return;
    }
    final now = [for (final c in creatures) c.position];
    final marks = vault.abyssMarks;
    var still = marks.length == now.length;
    if (still) {
      for (var i = 0; i < now.length; i++) {
        if ((now[i] - marks[i]).distance > _kAbyssDrift) {
          still = false;
          break;
        }
      }
    }
    if (!still) {
      vault.abyssMarks = now;
      vault.abyssStillness = 0;
      return;
    }
    vault.abyssStillness += dt;
    if (vault.abyssStillness < _kAbyssSeconds) return;
    vault.abyssGazed = true;
    _discoverCloud(kDarkAbyssEggId); // the screen pays the 20 gold
    _setHint('THE ABYSS — $kDarkAbyssMaxim', 7.5);
    _spawnAlchemyBurst(
      room.eclipse!.abyss!,
      producedElement: 'Dark',
      reagentElements: const ['Spirit', 'Poison'],
      particleCount: 44,
      intensity: 1.5,
    );
  }

  void _breakVigil() {
    if (!_isVault) return;
    vault.abyssStillness = 0;
    vault.abyssMarks = const [];
  }

  // ── Per-frame ────────────────────────────────────────────

  void _updateVault(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isVault) return;
    if (vault.wipe > 0) vault.wipe = max(0.0, vault.wipe - dt);
    _updateAbyss(room, dt);
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
    if (hall?.abyss != null && vault.abyssStillness > 0) {
      return DungeonProgressReadout(
        label: 'STILL',
        value: '${vault.abyssStillness.floor()}s',
        fraction: (vault.abyssStillness / _kAbyssSeconds).clamp(0.0, 1.0),
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
      return 'Noctryos\' Totality — the eclipse keeps the last star';
    }
    if (room.eclipse?.snuffer != null) {
      return 'The Eclipse Nave — the rite waits on the lamps';
    }
    if (room.eclipse?.analemma != null) {
      return hasStar(room.eclipse!.starIndex!)
          ? null
          : 'The Analemma Court — four stones, and none of them seated';
    }
    if (room.eclipse?.starIndex == 1) {
      return hasStar(1)
          ? null
          : 'The Ossuary Ring — three rings, and every one of them rusted';
    }
    if (room.vaultCache != null) {
      return 'A room that is not here in the light — something is bottled '
          'against the wall';
    }
    if (room.eclipse?.abyss != null) {
      return 'The Abyssal Font — the floor stops being a floor';
    }
    if (vaultGnomonIn(room.id) != null) {
      return 'A gnomon stands here, and its shadow is somewhere';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Pall Porch — one way out, and the other one is not there'
          : 'The Pall Porch — the arch is hung shut';
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
        0 => 'Four stones, and the dial under them is a figure of eight',
        1 =>
          'Each stone reads one quarter of the vault, and it will only '
              'read a quarter that is dark',
        _ =>
          'You will not seat all four in one shape of this place. There '
              'are three shadows for four quarters, and every one of them is '
              'always somewhere — so come back with the vault turned',
      });
      return;
    }
    if (vaultAnchorsIn(room.id).isNotEmpty) {
      _setInsightHint(switch (tier) {
        0 => 'The rings go somewhere, and the rust says nobody has',
        1 =>
          'A hole wants dark at both ends — it is a hole in the dark, and '
              'nowhere else',
        _ =>
          'Rust first, and only something small enough to work inside the '
              'ring gets it off. Then both ends in shadow at once, and no two '
              'of these three rings want the same shape of the vault',
      });
      return;
    }
    if (vaultGnomonIn(room.id) != null) {
      final g = vaultGnomonIn(room.id)!;
      _setInsightHint(switch (tier) {
        0 => 'The finger holds a shadow, and it is only holding the one',
        1 =>
          'It stands between ${leafWord(g.upper)} and ${leafWord(g.lower)}. '
              'Turn it and the shadow crosses over',
        _ =>
          'Whatever you open with it, you shut something else. The shadow '
              'is in ${leafWord(vault.shadowOf(g.id))} now, and the moment it '
              'is not, everything cut through there is stone',
      });
      return;
    }
    if (room.vaultCache != null || room.eclipse?.abyss != null) {
      _setInsightHint(switch (tier) {
        0 => 'The wall on that side is not the same wall twice',
        1 =>
          'There is a room through there, and only while the Deep lies in '
              'shadow',
        _ =>
          'The way down here wants the Ossuary dark and the slot wants the '
              'Deep dark, and one finger cannot hold both — bring the '
              'Ossuary\'s shadow off the other one before you come down',
      });
      return;
    }
    // Anywhere in the vault, insight reads the ECLIPSE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'Nothing here is where the light says it is',
      1 =>
        'Every way between two quarters is a hole in the dark; every way '
            'inside one is a walk in the light. Nothing else is a door',
      _ =>
        'Three gnomons, four quarters, one shadow each. Two quarters are '
            'always dark and never more than two are lit — and never two that '
            'share a finger. Plan the shape before you walk it',
    });
  }

  /// Per-room mood — the porch is grey daylight and the deep is the inside of
  /// a closed eye, but the real driver is the eclipse: a shadowed quarter
  /// goes darker than the room it is.
  double get _vaultMoodTarget {
    final base = switch (currentRoomId) {
      'pall_porch' => 0.70,
      'analemma_court' => 0.60,
      'shade_gallery' => 0.50,
      'penumbral_walk' => 0.46,
      'gnomon_stair' => 0.40,
      'ossuary_ring' => 0.34,
      'abyssal_font' => 0.16,
      'umbral_reliquary' => 0.20,
      'eclipse_nave' => 0.30,
      _ => guardianAwake ? 0.12 : 0.24,
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
    _renderVaultGround(canvas, room);
    _renderVaultSpans(canvas, room);
    _renderVaultObjects(canvas, room);
    _renderVaultWipe(canvas, room);
  }

  /// The change of substance. Cheap by construction: a fixed handful of
  /// strokes derived from the room's own bounds, no allocation per frame
  /// beyond the paints, and nothing that scales with the party or the enemies.
  void _renderVaultGround(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final leaf = room.eclipse?.leaf;
    if (leaf == null) return;
    if (vault.isDark(leaf)) {
      // Negative space: the room is drawn as the edges of what is not there.
      canvas.drawRect(b, Paint()..color = _kVaultVoid.withValues(alpha: 0.55));
      final edge = Paint()
        ..color = _kVaultViolet.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(b.deflate(10), edge);
      final rib = Paint()
        ..color = _kVaultViolet.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = 1; i < 5; i++) {
        final x = b.left + b.width * i / 5;
        canvas.drawLine(Offset(x, b.top + 24), Offset(x, b.bottom - 24), rib);
      }
    } else {
      // Solid: a pewter floor with hard joints, the colour of a coin.
      canvas.drawRect(
        b,
        Paint()..color = _kVaultPewter.withValues(alpha: 0.13),
      );
      final joint = Paint()
        ..color = _kVaultBone.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = 1; i < 5; i++) {
        final x = b.left + b.width * i / 5;
        canvas.drawLine(Offset(x, b.top), Offset(x, b.bottom), joint);
      }
      for (var i = 1; i < 4; i++) {
        final y = b.top + b.height * i / 4;
        canvas.drawLine(Offset(b.left, y), Offset(b.right, y), joint);
      }
    }
  }

  /// A glyph at every passage the room can see, so what the eclipse has done
  /// is legible before you walk into it: an open shadow-way is a notch of
  /// nothing, an open light-walk is a pale causeway, and a light-walk whose
  /// quarter has gone dark is the same causeway drawn in bone with its middle
  /// missing. Shadow-ways that do not exist are not drawn at all — they are
  /// not there (see `_vaultDoorHidden`).
  void _renderVaultSpans(Canvas canvas, DungeonRoom room) {
    for (final d in room.doors) {
      if (isDoorHidden(room, d)) continue;
      final span = _vaultSpanFor(room, d);
      if (span == null || span.cut == SpanCut.unmoved) continue;
      final at = d.rect.center;
      final live = vault.spanOpen(span);
      if (span.cut == SpanCut.shadowWay) {
        final paint = Paint()..color = _kVaultVoid.withValues(alpha: 0.85);
        final notch = Path()
          ..moveTo(at.dx - 17, at.dy + 10)
          ..lineTo(at.dx - 6, at.dy - 11)
          ..lineTo(at.dx + 5, at.dy + 3)
          ..lineTo(at.dx + 17, at.dy - 10)
          ..lineTo(at.dx + 17, at.dy + 10)
          ..close();
        canvas.drawPath(notch, paint);
        canvas.drawPath(
          notch,
          Paint()
            ..color = _kVaultViolet.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        final paint = Paint()
          ..color = live
              ? _kVaultBone.withValues(alpha: 0.8)
              : _kVaultBone.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = live ? 4 : 2;
        if (live) {
          canvas.drawLine(
            at + const Offset(-18, 6),
            at + const Offset(18, 6),
            paint,
          );
          canvas.drawLine(
            at + const Offset(-12, -2),
            at + const Offset(12, -2),
            paint,
          );
        } else {
          // The boards, with the middle of them gone.
          canvas.drawLine(
            at + const Offset(-18, 6),
            at + const Offset(-7, 6),
            paint,
          );
          canvas.drawLine(
            at + const Offset(7, 6),
            at + const Offset(18, 6),
            paint,
          );
        }
      }
    }
  }

  void _renderVaultObjects(Canvas canvas, DungeonRoom room) {
    final hall = room.eclipse;
    if (hall == null) return;

    // THE GNOMON: a finger with its shadow drawn as a hard bar lying toward
    // the quarter it is holding — up the room for its upper quarter, down for
    // its lower. The shadow's DIRECTION is the whole read.
    final g = vaultGnomonIn(room.id);
    if (g != null) {
      final at = g.shaft;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 14, height: 46),
          const Radius.circular(4),
        ),
        Paint()..color = _kVaultVoid,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 14, height: 46),
          const Radius.circular(4),
        ),
        Paint()
          ..color = _kVaultViolet
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final down = vault.shadowOf(g.id) == g.lower;
      final bar = Rect.fromLTWH(
        at.dx - 7,
        down ? at.dy + 23 : at.dy - 79,
        14,
        56,
      );
      canvas.drawRect(bar, Paint()..color = _kVaultVoid.withValues(alpha: 0.8));
      canvas.drawRect(
        bar,
        Paint()
          ..color = _kVaultViolet.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // THE ANALEMMA: the figure-of-eight dial and its four stones. A seated
    // stone is a filled square, an unseated one an outline — and one whose
    // quarter is dark right now gets a violet ring, so the court tells you
    // what is available without telling you how.
    if (hall.analemma != null) {
      final c = hall.analemma!;
      final ring = Paint()
        ..color = _kVaultBone.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(c + const Offset(0, -34), 46, ring);
      canvas.drawCircle(c + const Offset(0, 34), 46, ring);
      for (final s in kShadowStones) {
        final seated = vault.stonesSeated.contains(s.id);
        final r = Rect.fromCenter(center: s.position, width: 20, height: 20);
        canvas.drawRect(
          r,
          Paint()
            ..color = seated ? _kVaultVoid : _kVaultBone.withValues(alpha: 0.25)
            ..style = seated ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        if (!seated && vault.isDark(s.leaf)) {
          canvas.drawCircle(
            s.position,
            16,
            Paint()
              ..color = _kVaultViolet.withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }

    // THE ANCHORS: an iron ring, rusted (bone) or eaten clean (violet), with
    // a filled centre once the hole on the far side is actually open.
    for (final an in vaultAnchorsIn(room.id)) {
      final at = an.ringIn(room.id)!;
      final unlocked = vault.anchorsOpen.contains(an.id);
      canvas.drawCircle(
        at,
        14,
        Paint()
          ..color = unlocked
              ? _kVaultViolet
              : _kVaultBone.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      if (unlocked && vault.portalOpen(an, _vaultLeaves)) {
        canvas.drawCircle(at, 10, Paint()..color = _kVaultVoid);
      }
    }

    // THE SNUFFER: three lamps, alight until the rite puts them out.
    if (hall.snuffer != null) {
      final lit = (conduitEnergy['B'] ?? 0) <= 0;
      for (var i = 0; i < 3; i++) {
        final at = hall.snuffer! + Offset(-34.0 + i * 34.0, 0);
        canvas.drawCircle(
          at,
          9,
          Paint()
            ..color = lit ? _kVaultEmber : _kVaultBone.withValues(alpha: 0.22),
        );
      }
    }

    // THE PALL: the cloth over the arch, while it is still there.
    if (hall.pallCurtain != null && !entryDoorRevealed) {
      final at = hall.pallCurtain!;
      canvas.drawRect(
        Rect.fromCenter(center: at, width: 54, height: 96),
        Paint()..color = _kVaultVoid.withValues(alpha: 0.9),
      );
    }

    // THE ABYSS: a hole with nothing drawn inside it, and a bone rim.
    if (hall.abyss != null) {
      canvas.drawCircle(hall.abyss!, 54, Paint()..color = _kVaultVoid);
      canvas.drawCircle(
        hall.abyss!,
        54,
        Paint()
          ..color = _kVaultBone.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (vault.abyssStillness > 0) {
        canvas.drawCircle(
          hall.abyss!,
          54 * (vault.abyssStillness / _kAbyssSeconds).clamp(0.0, 1.0),
          Paint()
            ..color = _kVaultViolet.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }

    // THE VANE: the arena's hand on the stair gnomon.
    if (hall.shadowVane != null) {
      final at = hall.shadowVane!;
      final down = vault.shadowOf('gn_stair') == EclipseLeaf.deep;
      canvas.drawCircle(
        at,
        22,
        Paint()
          ..color = _kVaultViolet.withValues(alpha: down ? 0.85 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawLine(
        at,
        at + Offset(0, down ? 22 : -22),
        Paint()
          ..color = _kVaultViolet
          ..strokeWidth = 4,
      );
    }
  }

  /// The turn, as a hard edge crossing the room. One rect per frame while it
  /// runs, and nothing at all when it does not.
  void _renderVaultWipe(Canvas canvas, DungeonRoom room) {
    if (vault.wipe <= 0) return;
    final t = 1.0 - (vault.wipe / _kVaultWipeSeconds);
    final b = room.bounds;
    final x = b.left + b.width * t;
    canvas.drawRect(
      Rect.fromLTWH(x - 8, b.top, 16, b.height),
      Paint()..color = _kVaultViolet.withValues(alpha: 0.55),
    );
  }
}
