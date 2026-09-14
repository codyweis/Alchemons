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
        ? 'No floor under it, $where lies in shadow'
        : 'Solid stone, $where stands in the light';
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
          '${leafWord(s.leaf)} stands in the light, the stone '
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
              ? 'No hole here, ${leafWord(mine)} stands in the light'
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
        'The lamps will not gutter, they answer only a bearer of the '
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
          'Noctryos takes the shadow off the Deep, and the vault turns over '
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
    // THE RITE OF THREE pays this out (see `beginMaximRite`) — the reaction
    // is built from the trio that came down and hands over the gold itself.
    beginMaximRite(kDarkAbyssEggId, room.eclipse!.abyss!);
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
      return 'Noctryos\' Totality, the eclipse keeps the last star';
    }
    if (room.eclipse?.snuffer != null) {
      return 'The Eclipse Nave, the rite waits on the lamps';
    }
    if (room.eclipse?.analemma != null) {
      return hasStar(room.eclipse!.starIndex!)
          ? null
          : 'The Analemma Court, four stones, and none of them seated';
    }
    if (room.eclipse?.starIndex == 1) {
      return hasStar(1)
          ? null
          : 'The Ossuary Ring, three rings, and every one of them rusted';
    }
    if (room.vaultCache != null) {
      return 'A room that is not here in the light, something is bottled '
          'against the wall';
    }
    if (room.eclipse?.abyss != null) {
      return 'The Abyssal Font, the floor stops being a floor';
    }
    if (vaultGnomonIn(room.id) != null) {
      return 'A gnomon stands here, and its shadow is somewhere';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Pall Porch, one way out, and the other one is not there'
          : 'The Pall Porch, the arch is hung shut';
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
              'always somewhere, so come back with the vault turned',
      });
      return;
    }
    if (vaultAnchorsIn(room.id).isNotEmpty) {
      _setInsightHint(switch (tier) {
        0 => 'The rings go somewhere, and the rust says nobody has',
        1 =>
          'A hole wants dark at both ends, it is a hole in the dark, and '
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
              'Deep dark, and one finger cannot hold both. Bring the '
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
            'always dark and never more than two are lit, and never two that '
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

  /// The change of substance, drawn over a REAL PLACE.
  ///
  /// This used to be the whole ground: a flat tint plus four evenly spaced
  /// ribs in the dark state and a 5×4 lattice in the light one. It scored well
  /// on edge-pixels — a regular lattice is nothing but edges — and it was
  /// graph paper. Nythralor is a buried vault whose entire subject matter is
  /// *things that cast and the floor they fall on*, and it had neither.
  ///
  /// What is here now is an ashlar floor with a colonnade, pierced screens,
  /// lamp brackets, loculi and fallen shafts standing in the margins, and the
  /// HARD-EDGED SHADOW each of them throws from the room's own light. The
  /// geometry is built once per room from an LCG seeded on the room's bounds
  /// and cached in [_vaultGroundCache]; per frame this is a clip, a dozen
  /// drawPath calls over pre-built paths and a guttering flame. No
  /// `MaskFilter.blur` anywhere — every soft edge in here is geometry and
  /// alpha, which is the only way this planet could have been drawn at 60fps.
  ///
  /// THE INVERSION IS IN THE GROUND ITSELF. A quarter in CORONA is stone: a
  /// pewter floor, the shafts of light lying pale across it, the cast shadows
  /// dark. A quarter in UMBRA is the same room TURNED INSIDE OUT — the light
  /// shafts are bars of nothing, the cast shadows are the only lit floor left,
  /// and the architecture is edges on emptiness. Same geometry, exchanged
  /// substance, which is the world rule stated as paint rather than as a lamp
  /// going out.
  void _renderVaultGround(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final leaf = room.eclipse?.leaf;
    if (leaf == null) return;
    final g = _vaultGroundFor(room, layout);
    final dark = vault.isDark(leaf);

    // Everything is clipped to the stage the engine already laid down, so the
    // vault's masonry ends where the island ends rather than running out over
    // the sky (the plain floor is `b.deflate(8)` at radius 34).
    final stage = RRect.fromRectAndRadius(b.deflate(8), const Radius.circular(34));
    canvas.save();
    canvas.clipRRect(stage);

    if (dark) {
      // ── UMBRA · the room as an absence ───────────────────
      canvas.drawRect(b, Paint()..color = _kVaultVoid.withValues(alpha: 0.52));
      // The exchange: what the architecture shaded is now the only floor with
      // anything on it, and the fissure's light is a bar of nothing.
      canvas.drawPath(
        g.shadows,
        Paint()..color = const Color(0xFF6E5E96).withValues(alpha: 0.22),
      );
      canvas.drawPath(
        g.stripes,
        Paint()..color = _kVaultViolet.withValues(alpha: 0.17),
      );
      canvas.drawPath(
        g.shaftLight,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.30),
      );
      // Floor texture, barely — enough that the eye can tell there is stone
      // under it and not a hole. Contrast, not brightness.
      canvas.drawPath(
        g.flags,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = _kVaultViolet.withValues(alpha: 0.22),
      );
      canvas.drawPath(
        g.sunken,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.75),
      );
      // The architecture, on nothing. A thin fill first so a silhouette has
      // MASS — an outline alone made the umbral rooms read as wireframe, which
      // is a different failure from graph paper but the same disease.
      canvas.drawPath(
        g.bodies,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.55),
      );
      canvas.drawPath(
        g.mouths,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.9),
      );
      // Stroking the FILL paths is what gives an umbral room its contours for
      // free — one path, one call, every edge in the room.
      canvas.drawPath(
        g.bodies,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = _kVaultViolet.withValues(alpha: 0.72),
      );
      canvas.drawPath(
        g.mouths,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _kVaultViolet.withValues(alpha: 0.5),
      );
      canvas.drawPath(
        g.edges,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = _kVaultViolet.withValues(alpha: 0.5),
      );
      // The bone in a loculus, a drum's top, the nosing of a stair: the few
      // things down here that still catch light. This is the difference
      // between a dark place with things in it and a dark rectangle.
      canvas.drawPath(
        g.caps,
        Paint()..color = const Color(0xFFBCB0DE).withValues(alpha: 0.34),
      );
      // A cold ring where a lamp would be. Nothing burns in the umbra.
      for (final at in g.lamps) {
        canvas.drawCircle(
          at,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _kVaultViolet.withValues(alpha: 0.5),
        );
      }
      canvas.drawRRect(
        stage.deflate(5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _kVaultViolet.withValues(alpha: 0.4),
      );
    } else {
      // ── CORONA · the room as stone ───────────────────────
      // Alpha held low on every big fill: the FLOOR TRANSLUCENCY RULE means
      // the sky shader is still the room's mood and has to come through.
      canvas.drawRect(
        b,
        Paint()..color = _kVaultPewter.withValues(alpha: 0.30),
      );
      canvas.drawPath(
        g.flags,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _kVaultBone.withValues(alpha: 0.13),
      );
      canvas.drawPath(
        g.sunken,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.38),
      );
      canvas.drawPath(
        g.shaftLight,
        Paint()..color = _kVaultBone.withValues(alpha: 0.075),
      );
      canvas.drawPath(
        g.shadows,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.46),
      );
      // The bars of light a pierced screen lets past. Drawn AFTER the shadow
      // so they cut it, which is what makes the screen read as pierced.
      canvas.drawPath(
        g.stripes,
        Paint()..color = _kVaultBone.withValues(alpha: 0.10),
      );
      canvas.drawPath(
        g.bodies,
        Paint()..color = const Color(0xFF1B1826).withValues(alpha: 0.85),
      );
      canvas.drawPath(
        g.caps,
        Paint()..color = _kVaultBone.withValues(alpha: 0.20),
      );
      canvas.drawPath(
        g.mouths,
        Paint()..color = _kVaultVoid.withValues(alpha: 0.85),
      );
      canvas.drawPath(
        g.edges,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = _kVaultBone.withValues(alpha: 0.26),
      );
      // THE LAMPS. Three nested discs instead of a blur — the repo's one
      // banned filter is exactly what a lamp wants, so it is faked with
      // geometry — and the flame gutters on a cheap phase, which is the only
      // thing in this whole ground that changes between frames.
      for (var i = 0; i < g.lamps.length; i++) {
        final at = g.lamps[i];
        final gut = 0.86 + 0.14 * sin(_time * 3.1 + i * 2.2);
        canvas.drawCircle(
          at,
          46 * gut,
          Paint()..color = _kVaultEmber.withValues(alpha: 0.045),
        );
        canvas.drawCircle(
          at,
          22 * gut,
          Paint()..color = _kVaultEmber.withValues(alpha: 0.075),
        );
        canvas.drawCircle(
          at,
          3.4 * gut,
          Paint()..color = _kVaultEmber.withValues(alpha: 0.9),
        );
      }
      canvas.drawRRect(
        stage.deflate(5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _kVaultBone.withValues(alpha: 0.16),
      );
    }
    canvas.restore();
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
  return _vaultGroundCache.putIfAbsent(key, () => _buildVaultGround(room, layout));
}

List<Offset> _rectCorners(Rect r) => [
  r.topLeft,
  r.topRight,
  r.bottomRight,
  r.bottomLeft,
];

/// The corners of a rect turned through [a] about [c] — for anything that has
/// fallen over, which is most of what is left standing down here.
List<Offset> _tiltedCorners(Offset c, double halfLen, double halfWid, double a) {
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
  final rng = _VaultRng(b.width.toInt() * 733 + b.height.toInt() * 191 + idHash);

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
  final ang = rng.chance(0.5)
      ? rng.range(1.06, 1.42)
      : rng.range(1.72, 2.08);
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
      if (rng.chance(0.055) && w > 90) {
        final hole = Rect.fromLTWH(
          x + 14,
          y + 10,
          min(w - 30, 58),
          min(h - 22, 28),
        ).intersect(b.deflate(18));
        if (hole.width > 14 && hole.height > 10) {
          final cx = hole.center;
          sunken.addPolygon([
            for (var k = 0; k < 6; k++)
              cx +
                  Offset(
                    cos(k * pi / 3 + 0.3) * hole.width * rng.range(0.36, 0.54),
                    sin(k * pi / 3 + 0.3) * hole.height * rng.range(0.36, 0.56),
                  ),
          ], true);
        }
      }
      x = fx;
    }
    y += h;
  }
  // Long cracks, crossing the courses at an angle so the floor has a history
  // that the masonry grid does not explain.
  for (var i = 0; i < 3; i++) {
    var p = Offset(b.left + rng.range(0, b.width), b.top + rng.range(0, 40));
    flags.moveTo(p.dx, p.dy);
    var a = rng.range(1.1, 2.0);
    for (var k = 0; k < 7; k++) {
      a += rng.range(-0.34, 0.34);
      p += Offset(cos(a), sin(a)) * rng.range(40, 92);
      flags.lineTo(p.dx, p.dy);
    }
  }

  // ── WHERE NOTHING MAY STAND ────────────────────────────
  // Fixtures, doorways and — the lesson that cost this project a polish pass
  // before — ARRIVALS. A body landing on a pillar is a bug, so every spawn
  // any other room aims at this one is kept clear as well.
  final reserved = <(Offset, double)>[];
  void reserve(Offset? p, double r) {
    if (p != null) reserved.add((p, r));
  }

  final hall = room.eclipse;
  reserve(hall?.analemma, 120);
  reserve(hall?.snuffer, 80);
  reserve(hall?.pallCurtain, 64);
  reserve(hall?.abyss, 110);
  reserve(hall?.shadowVane, 56);
  reserve(room.vaultCache, 56);
  reserve(room.guardian?.position, 140);
  reserve(vaultGnomonIn(room.id)?.shaft, 62);
  if (hall?.analemma != null) {
    for (final s in kShadowStones) {
      reserve(s.position, 40);
    }
  }
  for (final an in vaultAnchorsIn(room.id)) {
    reserve(an.ringIn(room.id), 46);
  }
  for (final c in room.conduits) {
    reserve(c.position, 56);
  }
  if (room.id == layout.entranceRoomId) reserve(layout.entranceSpawn, 48);
  for (final r in layout.rooms.values) {
    for (final d in r.doors) {
      if (d.targetRoomId == room.id) reserve(d.targetSpawn, 46);
    }
  }

  bool blocked(Offset p, double r) {
    if (!b.deflate(10).contains(p)) return true;
    for (final (c, rr) in reserved) {
      if ((p - c).distance < rr + r) return true;
    }
    for (final w in room.walls) {
      if (w.inflate(r + 12).contains(p)) return true;
    }
    for (final d in room.doors) {
      if (d.rect.inflate(r + 48).contains(p)) return true;
    }
    return false;
  }

  // ── THE THINGS THAT CAST ───────────────────────────────

  /// A drum — one course of a column, the commonest thing standing in a vault
  /// this far gone. The cap is offset INTO the light so it reads as a top face
  /// rather than a ring.
  void drum(Offset at, double r) {
    final n = Offset(-dir.dy, dir.dx);
    _castShadow(shadows, [at + n * r, at - n * r], dir, r * 3.0 + 18);
    bodies.addOval(Rect.fromCircle(center: at, radius: r));
    caps.addOval(
      Rect.fromCircle(center: at - dir * (r * 0.3), radius: r * 0.58),
    );
    edges.addOval(Rect.fromCircle(center: at, radius: r));
  }

  /// A charnel stack — long bones laid up like cordwood, which is what an
  /// ossuary actually is. Pale, so it is the one thing in the bone quarter
  /// that catches light in BOTH states.
  void boneStack(Offset at, bool horizontal) {
    final n = 3 + rng.pick(3);
    final spread = rng.range(24, 42);
    for (var i = 0; i < n; i++) {
      final t = (i / max(1, n - 1) - 0.5) * spread;
      // Staggered ALONG the bone and spaced ACROSS it, with almost no angular
      // jitter. The first version jittered the angle by a fifth of a radian
      // and the stack came out as a pale scribble — bones lie parallel,
      // because that is how anyone stacks them.
      final c = horizontal
          ? at + Offset(rng.range(-11, 11), t)
          : at + Offset(t, rng.range(-11, 11));
      final len = rng.range(19, 27) * sizeScale;
      final bar = _tiltedCorners(
        c,
        len,
        2.1,
        (horizontal ? 0.0 : pi / 2) + rng.range(-0.07, 0.07),
      );
      caps.addPolygon(bar, true);
    }
    final foot = Rect.fromCenter(
      center: at,
      width: horizontal ? 56 : spread + 22,
      height: horizontal ? spread + 22 : 56,
    );
    _castShadow(shadows, _rectCorners(foot), dir, 22, taper: 0.5);
  }

  /// A squared pier. Shorter and heavier than a drum; what a vault puts under
  /// the springing of an arch.
  void pier(Offset at, double w, double h) {
    final r = Rect.fromCenter(center: at, width: w, height: h);
    _castShadow(shadows, _rectCorners(r), dir, (w + h) * 0.9 + 14);
    bodies.addRect(r);
    caps.addRect(Rect.fromLTWH(r.left + 2, r.top, r.width - 4, 3.5));
  }

  /// Spall. Two or three chips, because a floor with nothing loose on it has
  /// never had anything happen to it.
  void rubble(Offset at) {
    for (var i = 0; i < 2 + rng.pick(2); i++) {
      final c = at + Offset(rng.range(-26, 26), rng.range(-18, 18));
      final r = rng.range(4, 11);
      final pts = [
        for (var k = 0; k < 4; k++)
          c +
              Offset(
                cos(k * pi / 2 + 0.4) * r * rng.range(0.6, 1.3),
                sin(k * pi / 2 + 0.4) * r * rng.range(0.6, 1.3),
              ),
      ];
      _castShadow(shadows, pts, dir, r * 1.6);
      bodies.addPolygon(pts, true);
    }
  }

  /// A PIERCED SCREEN, and the reason this planet needed one: the bars of
  /// light between its slots are the most unambiguous way to say *this object
  /// is casting* without drawing a diagram of it. The slab is drawn as the
  /// pieces between the slots, and its shadow is cut by them.
  void screen(Offset at, bool horizontal) {
    // Clamped to the room it stands in, or a screen near a corner gets half of
    // itself sliced off by the stage clip and reads as a broken wall.
    final room2edge = horizontal
        ? min(at.dx - b.left, b.right - at.dx)
        : min(at.dy - b.top, b.bottom - at.dy);
    final span = min(rng.range(62, 118) * sizeScale, room2edge * 1.7);
    if (span < 42) {
      rubble(at);
      return;
    }
    final th = rng.range(9, 14) * sizeScale;
    final len = span * 1.15 + 40;
    final full = horizontal
        ? Rect.fromCenter(center: at, width: span, height: th)
        : Rect.fromCenter(center: at, width: th, height: span);
    _castShadow(shadows, _rectCorners(full), dir, len);
    // Slots, unevenly spaced — a screen carved by hand, not stamped.
    final n = 3 + rng.pick(3);
    var t = 0.0;
    final pieces = <double>[];
    for (var i = 0; i < n; i++) {
      final solid = rng.range(0.06, 0.20);
      final slot = rng.range(0.05, 0.13);
      pieces..add(t)..add(t + solid);
      t += solid + slot;
      if (t > 0.94) break;
    }
    pieces..add(min(t, 0.96))..add(1.0);
    for (var i = 0; i + 1 < pieces.length; i += 2) {
      final a0 = pieces[i], a1 = pieces[i + 1];
      final part = horizontal
          ? Rect.fromLTRB(
              full.left + full.width * a0,
              full.top,
              full.left + full.width * a1,
              full.bottom,
            )
          : Rect.fromLTRB(
              full.left,
              full.top + full.height * a0,
              full.right,
              full.top + full.height * a1,
            );
      bodies.addRect(part);
      caps.addRect(Rect.fromLTWH(part.left + 1, part.top, part.width - 2, 2.5));
    }
    // And the light between them.
    for (var i = 1; i + 1 < pieces.length; i += 2) {
      final a0 = pieces[i], a1 = pieces[i + 1];
      final gap = horizontal
          ? Rect.fromLTRB(
              full.left + full.width * a0,
              full.top,
              full.left + full.width * a1,
              full.bottom,
            )
          : Rect.fromLTRB(
              full.left,
              full.top + full.height * a0,
              full.right,
              full.top + full.height * a1,
            );
      _castShadow(stripes, _rectCorners(gap), dir, len);
    }
  }

  /// A shaft that came down. A long tilted body with a drum still attached at
  /// one end, and a low shadow, because it is lying on the floor.
  void fallen(Offset at) {
    final a = rng.range(0, pi);
    final hl = rng.range(38, 74) * sizeScale;
    final hw = rng.range(7, 12) * sizeScale;
    final c = _tiltedCorners(at, hl, hw, a);
    _castShadow(shadows, c, dir, rng.range(16, 30));
    bodies.addPolygon(c, true);
    edges.addPolygon(c, true);
    final end = at + Offset(cos(a), sin(a)) * hl;
    bodies.addOval(Rect.fromCircle(center: end, radius: hw + 3));
    caps.addOval(Rect.fromCircle(center: end, radius: hw * 0.55));
  }

  /// A LOCULUS — a mouth in the wall with something in it. An absence, so it
  /// casts nothing; what it does instead is give a wall a depth, which is the
  /// one thing a top-down room usually cannot say.
  void loculus(Offset at, bool horizontal) {
    final w = horizontal ? rng.range(38, 62) : rng.range(22, 30);
    final h = horizontal ? rng.range(22, 30) : rng.range(38, 62);
    final r = Rect.fromCenter(center: at, width: w, height: h);
    mouths.addRect(r);
    // JAMBS. A mouth drawn as a void rect on a void floor is invisible in the
    // umbra — which is exactly the trap a dark planet sets — so the opening
    // gets built sides, and they are real bodies with real contours.
    if (horizontal) {
      bodies
        ..addRect(Rect.fromLTWH(r.left - 5, r.top - 4, 5, r.height + 8))
        ..addRect(Rect.fromLTWH(r.right, r.top - 4, 5, r.height + 8));
    } else {
      bodies
        ..addRect(Rect.fromLTWH(r.left - 4, r.top - 5, r.width + 8, 5))
        ..addRect(Rect.fromLTWH(r.left - 4, r.bottom, r.width + 8, 5));
    }
    edges.addRect(r.inflate(3));
    // Bone, catching what little light reaches in.
    for (var i = 0; i < 2; i++) {
      caps.addRect(
        horizontal
            ? Rect.fromLTWH(r.left + 5, r.top + 6 + i * 8.0, r.width - 10, 2.8)
            : Rect.fromLTWH(r.left + 6 + i * 8.0, r.top + 5, 2.8, r.height - 10),
      );
    }
  }

  /// A wall bracket with a lamp in it. Corona burns it; umbra leaves the ring.
  void bracket(Offset at) {
    if (lamps.length >= 4) {
      rubble(at);
      return;
    }
    lamps.add(at);
    final stem = Rect.fromCenter(center: at, width: 7, height: 16);
    bodies.addRect(stem);
    edges.addOval(Rect.fromCircle(center: at, radius: 9));
  }

  // ── PLACING THEM ───────────────────────────────────────
  // Along the four walls, in the MARGIN, so the middle of every room stays
  // walkable — the guardian's arena and the hub-ish courts most of all. The
  // step is irregular, the depth into the room is irregular, and one station
  // in five is skipped outright: cluster and gap, never a rank.
  final palette = switch (room.id) {
    // The threshold. Arch piers, a screen or two, and what is left of the
    // tympanum that is already authored as a wall.
    'pall_porch' => const [0, 0, 1, 2, 3, 4, 6],
    // The court keeps a wide floor for the dial; only the perimeter is built.
    'analemma_court' => const [0, 0, 0, 1, 4, 6],
    // The long gallery, and the mercy shrine. Screens everywhere.
    'shade_gallery' => const [0, 0, 2, 2, 3, 5, 6],
    // "Leaning where the colonnade breaks" — drums, and the ones that fell.
    'penumbral_walk' => const [0, 0, 0, 3, 3, 4, 6],
    'gnomon_stair' => const [0, 1, 1, 3, 4, 4, 6],
    // The bone quarter: loculi in every wall, and the bones out of them.
    'ossuary_ring' => const [5, 5, 7, 7, 1, 3, 4, 6],
    'abyssal_font' => const [1, 1, 2, 4, 4, 6],
    // A vault for reliquaries: mouths and screens, in a small room.
    'umbral_reliquary' => const [5, 5, 7, 2, 1, 6],
    'eclipse_nave' => const [0, 0, 2, 2, 4, 6, 6],
    // The arena. Heavy piers only, and they stand well back.
    'noctryos_totality' => const [1, 1, 0, 3, 4, 6],
    _ => const [0, 1, 2, 4, 6],
  };

  void place(int type, Offset at, bool horizontal) {
    switch (type) {
      case 0:
        drum(at, rng.range(11, 20) * sizeScale);
      case 1:
        pier(at, rng.range(24, 42) * sizeScale, rng.range(20, 34) * sizeScale);
      case 2:
        screen(at, horizontal);
      case 3:
        fallen(at);
      case 4:
        rubble(at);
      case 5:
        loculus(at, horizontal);
      case 7:
        boneStack(at, horizontal);
      default:
        bracket(at);
    }
  }

  for (var wall = 0; wall < 4; wall++) {
    final horizontal = wall.isEven;
    final len = horizontal ? b.width : b.height;
    // Small rooms get a proportionally tighter step, or the reliquary ends up
    // with three objects in it.
    final scale = (len / 700).clamp(0.52, 1.15);
    var t = rng.range(34, 110) * scale;
    while (t < len - 30) {
      final type = palette[rng.pick(palette.length)];
      // Loculi and lamp brackets belong ON the wall — but not so far onto it
      // that the stage's rounded clip eats them, which is what 7px did.
      final onWall = type == 5 || type == 6;
      final depth = onWall ? rng.range(17, 26) : rng.range(26, 70);
      final at = switch (wall) {
        0 => Offset(b.left + t, b.top + depth),
        1 => Offset(b.right - depth, b.top + t),
        2 => Offset(b.left + t, b.bottom - depth),
        _ => Offset(b.left + depth, b.top + t),
      };
      t += rng.range(62, 158) * scale;
      if (rng.chance(0.15)) continue; // skip cells
      if (blocked(at, onWall ? 20 : 34)) continue;
      reserved.add((at, onWall ? 20 : 26));
      place(type, at, horizontal);
    }
  }

  // A SECOND PASS, out on the open floor — but only ever things that are
  // LYING DOWN. Nothing in this dungeon's interior collides, so a standing
  // pillar in the middle of a room would be a pillar the party walks straight
  // through; a toppled shaft and a scatter of spall are walked OVER, which is
  // what a player expects of them anyway. It is also what stops the rooms
  // reading as a built rim around an empty middle.
  final loose = switch (room.id) {
    'noctryos_totality' => 0, // the arena fights in its middle
    'eclipse_nave' => 3, // the rite happens in the aisle
    'abyssal_font' => 3,
    'umbral_reliquary' => 5,
    _ => 5 + rng.pick(5),
  };
  var placed = 0;
  // Three tries per piece: a room whose middle is mostly reserved (the font,
  // the court) would otherwise come out empty simply because the first dart
  // landed on the fixture.
  for (var i = 0; i < loose * 3 && placed < loose; i++) {
    final at = Offset(
      b.left + rng.range(70, b.width - 70),
      b.top + rng.range(70, b.height - 70),
    );
    if (blocked(at, 46)) continue;
    reserved.add((at, 40));
    placed++;
    // Weighted toward the big form. An even split filled every room with
    // confetti — a dozen little chip clusters and nothing to read at distance.
    if (rng.chance(0.72)) {
      fallen(at);
    } else {
      rubble(at);
    }
  }

  // ── WHAT EACH ROOM ACTUALLY IS ─────────────────────────
  // The perimeter pass gives every room a built edge; this gives each one the
  // single piece of architecture it is named after.
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
      // Three steps down to the abyss — a font is a basin, and a basin is
      // rings. Each step is a PAIR of contours (tread and riser) with a break
      // in it, which is what makes a ring read as stone rather than as a
      // target painted on the floor.
      //
      // The first version put the lit lip into `caps`, which is a FILL path:
      // `Path.addArc` on a fill closes the arc into a chord, so every step
      // came out as a big pale crescent smeared across the room. Anything arc
      // shaped has to live in a stroked path.
      final c = room.eclipse!.abyss!;
      for (var i = 0; i < 3; i++) {
        final r = 86.0 + i * 42;
        final gap = rng.range(0, pi * 2);
        final sweep = pi * 2 - rng.range(0.35, 0.9);
        edges
          ..addArc(Rect.fromCircle(center: c, radius: r), gap, sweep)
          ..addArc(Rect.fromCircle(center: c, radius: r - 9), gap, sweep);
        // Joints in the tread, unevenly spaced round the ring.
        var a = gap + 0.2;
        while (a < gap + sweep - 0.2) {
          edges
            ..moveTo(c.dx + cos(a) * (r - 9), c.dy + sin(a) * (r - 9))
            ..lineTo(c.dx + cos(a) * r, c.dy + sin(a) * r);
          a += rng.range(0.34, 0.78);
        }
        // The nosing the light actually reaches, as a short lit bar rather
        // than a filled arc.
        for (var k = -2; k <= 2; k++) {
          final aa = ang + pi + k * 0.22;
          caps.addPolygon(
            _tiltedCorners(
              c + Offset(cos(aa), sin(aa)) * (r - 4.5),
              5.5,
              2.0,
              aa + pi / 2,
            ),
            true,
          );
        }
      }

    case 'eclipse_nave':
      // A NAVE: two arcades running the length of the room with the aisle
      // between them left open, because the rite happens in it. Spacing is
      // deliberately uneven and two bays are missing — a colonnade at even
      // pitch is the graph-paper failure with capitals on.
      for (final row in const [138.0, 430.0]) {
        var x = 78.0;
        while (x < b.right - 60) {
          final at = Offset(x, row + rng.range(-7, 7));
          x += rng.range(88, 138);
          if (rng.chance(0.22)) continue;
          if (blocked(at, 26)) continue;
          if (rng.chance(0.18)) {
            fallen(at);
          } else {
            drum(at, rng.range(14, 21));
          }
        }
      }

    case 'noctryos_totality':
      // The arena's ring of piers, standing on an ellipse well outside the
      // fighting floor. Angles are jittered and the north sector is left out
      // for the rood door, so it reads as a ruined ring rather than a dial.
      final c = Offset(b.center.dx, b.center.dy + 18);
      for (var i = 0; i < 11; i++) {
        final a = -pi / 2 + 0.62 + (i / 11) * (pi * 2 - 1.24) + rng.range(-0.1, 0.1);
        final at = c + Offset(cos(a) * (b.width * 0.42), sin(a) * (b.height * 0.40));
        if (blocked(at, 30)) continue;
        reserved.add((at, 26));
        if (rng.chance(0.24)) {
          fallen(at);
        } else {
          pier(at, rng.range(28, 44), rng.range(26, 40));
        }
      }

    case 'shade_gallery':
      // The dry well shaft goes down from this room's south wall; the well
      // itself stands in the floor beside it as a throat with a stone kerb —
      // coursed, because a well is built out of small blocks.
      final at = Offset(b.left + b.width * 0.18, b.bottom - 128);
      mouths.addOval(Rect.fromCircle(center: at, radius: 29));
      edges
        ..addOval(Rect.fromCircle(center: at, radius: 30))
        ..addOval(Rect.fromCircle(center: at, radius: 41));
      var wa = rng.range(0, 1.0);
      while (wa < pi * 2) {
        edges
          ..moveTo(at.dx + cos(wa) * 30, at.dy + sin(wa) * 30)
          ..lineTo(at.dx + cos(wa) * 41, at.dy + sin(wa) * 41);
        wa += rng.range(0.44, 0.86);
      }
      // The kerb catches the light on one side only.
      for (var k = -2; k <= 2; k++) {
        final aa = ang + pi + k * 0.3;
        caps.addPolygon(
          _tiltedCorners(
            at + Offset(cos(aa), sin(aa)) * 35.5,
            6.0,
            2.6,
            aa + pi / 2,
          ),
          true,
        );
      }
      _castShadow(
        shadows,
        _rectCorners(Rect.fromCircle(center: at, radius: 41)),
        dir,
        26,
        taper: 0.5,
      );

    case 'pall_porch':
      // THE ARCH. The porch is the first room of the planet and the only one
      // whose fiction is a doorway, and it had no doorway in it — just debris
      // on a floor. Two great piers flank the pall arch on the east wall with
      // a lintel across their heads, so arriving reads as standing in front of
      // a way in. Placed by hand rather than by the perimeter walk, because
      // this is the one thing in the room whose position means something.
      for (final py in const [126.0, 336.0]) {
        final r = Rect.fromCenter(center: Offset(632, py), width: 46, height: 62);
        _castShadow(shadows, _rectCorners(r), dir, 62, taper: 0.58);
        bodies.addRect(r);
        caps.addRect(Rect.fromLTWH(r.left + 4, r.top, r.width - 8, 4.5));
        edges.addRect(r.deflate(7));
      }
      // The lintel that used to sit across them, down on the floor well clear
      // of the doorway — it must NOT be drawn between the piers, because the
      // party walks that line to reach the arch and a bar across it reads as
      // "shut" in a room whose whole first beat is the pall coming off.
      final lintel = _tiltedCorners(const Offset(534, 392), 88, 12, 0.42);
      _castShadow(shadows, lintel, dir, 24, taper: 0.5);
      bodies.addPolygon(lintel, true);
      edges.addPolygon(lintel, true);
      // The threshold: worn paving laid across the approach, so the way out
      // has a floor that is different from the floor around it.
      for (var i = 0; i < 4; i++) {
        edges.addRect(
          Rect.fromLTWH(648.0 + i * 13, 168.0 + i * 4, 11, 124 - i * 8.0),
        );
      }

    case 'ossuary_ring':
      // A CHARNEL WALL. The perimeter pass alone left the bone quarter as the
      // barest room on the planet and the darkest — the exact trap a dark
      // planet sets, where "atmospherically sparse" and "nothing is drawn" are
      // the same picture. What it wanted was the thing it is named after:
      // loculi stacked in tiers, with the bones out of half of them.
      for (final side in const [true, false]) {
        final y0 = side ? b.top + 30 : b.bottom - 30;
        var x = b.left + rng.range(40, 130);
        while (x < b.right - 50) {
          final tiers = 1 + rng.pick(3);
          for (var t = 0; t < tiers; t++) {
            final at = Offset(x, y0 + (side ? 1 : -1) * (t * 34.0 + 8));
            x += rng.range(-6, 6);
            if (blocked(at, 20)) continue;
            if (rng.chance(0.22)) continue;
            reserved.add((at, 18));
            if (rng.chance(0.42)) {
              boneStack(at, true);
            } else {
              loculus(at, true);
            }
          }
          x += rng.range(64, 128);
        }
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
      // THE RACKS. This is the room §5.5 calls the vault trick — a room that
      // is not there while the Deep stands in light — and after the perimeter
      // pass it was still the barest room on the planet, because a small room
      // gets few stations. What it wanted was the one thing it is FOR:
      // somewhere to keep things.
      //
      // Drawn as a continuous stone rack with cells cut into it, rather than
      // as loose dark squares (which is what the first attempt was, and it
      // read as buckshot). The cells are of two or three different heights and
      // one in five is solid, so a columbarium — which really is a grid —
      // still does not come out as graph paper.
      for (final west in const [true, false]) {
        final rack = west
            ? Rect.fromLTWH(b.left + 12, b.top + 46, 46, b.height - 108)
            : Rect.fromLTWH(b.left + 76, b.top + 12, b.width - 190, 40);
        if (rack.width < 40 || rack.height < 40) continue;
        bodies.addRect(rack);
        _castShadow(shadows, _rectCorners(rack), dir, 26, taper: 0.5);
        var t = (west ? rack.top : rack.left) + 6;
        final end = (west ? rack.bottom : rack.right) - 6;
        while (t < end - 14) {
          final cell = rng.range(20, 40);
          if (t + cell > end) break;
          if (!rng.chance(0.2)) {
            final r = west
                ? Rect.fromLTWH(rack.left + 6, t, rack.width - 12, cell)
                : Rect.fromLTWH(t, rack.top + 6, cell, rack.height - 12);
            mouths.addRect(r);
            edges.addRect(r);
            // What is still in it, catching the little light there is.
            if (rng.chance(0.5)) {
              caps.addRect(
                Rect.fromCenter(
                  center: r.center,
                  width: min(r.width - 8, 13),
                  height: min(r.height - 8, 13),
                ),
              );
            }
          }
          t += cell + rng.range(5, 12);
        }
      }

    case 'analemma_court':
      // The dial's own pavement: a wide ring of radial joints under the
      // analemma, which is the one place in the vault where the FLOOR is the
      // instrument. It stays a joint pattern, never a fill, so the star's four
      // stones keep the contrast.
      final c = room.eclipse!.analemma!;
      edges.addOval(Rect.fromCircle(center: c, radius: 150));
      edges.addOval(Rect.fromCircle(center: c, radius: 162));
      for (var i = 0; i < 24; i++) {
        // Hour marks, deliberately UNEVEN in length — an analemma is a figure
        // of eight, not a clock face.
        final a = i * pi / 12;
        final inner = 150.0;
        final outer = 162.0 + (i % 3 == 0 ? 9 : 0);
        edges
          ..moveTo(c.dx + cos(a) * inner, c.dy + sin(a) * inner)
          ..lineTo(c.dx + cos(a) * outer, c.dy + sin(a) * outer);
      }
  }

  // ── SOCKETS ────────────────────────────────────────────
  // A gnomon is the one piece of architecture on this planet that the player
  // actually handles, and it was standing on nothing. It gets a collar and a
  // plinth in the floor — the shadow bar itself stays where it belongs, in
  // `_renderVaultObjects`, because that bar is the mechanic and not scenery.
  final gn = vaultGnomonIn(room.id);
  if (gn != null) {
    edges
      ..addOval(Rect.fromCircle(center: gn.shaft, radius: 34))
      ..addOval(Rect.fromCircle(center: gn.shaft, radius: 24));
    var ga = rng.range(0, 1.0);
    while (ga < pi * 2) {
      edges
        ..moveTo(gn.shaft.dx + cos(ga) * 24, gn.shaft.dy + sin(ga) * 24)
        ..lineTo(gn.shaft.dx + cos(ga) * 34, gn.shaft.dy + sin(ga) * 34);
      ga += rng.range(0.5, 1.0);
    }
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

  // ── THE FISSURE ────────────────────────────────────────
  // One or two bands of light lying across the floor from high in the wall the
  // light comes from. This is the whole reason the floor texture is visible at
  // all in a corona room, and in an umbra room it is the bar of nothing that
  // says the vault has been turned over.
  final shafts = sizeScale < 0.8 ? 1 : 1 + rng.pick(2);
  for (var i = 0; i < shafts; i++) {
    final w = rng.range(58, 132) * sizeScale;
    // Walk the band back up the light direction until it is off the room, so
    // it always enters through a wall rather than starting in mid-floor.
    final hit = Offset(
      b.left + rng.range(b.width * 0.15, b.width * 0.85),
      b.top + rng.range(b.height * 0.1, b.height * 0.5),
    );
    final start = hit - dir * (b.height + 200);
    final end = hit + dir * (b.height + 400);
    final n = Offset(-dir.dy, dir.dx);
    shaftLight.addPolygon([
      start + n * (w * 0.38),
      start - n * (w * 0.38),
      end - n * (w * 0.5),
      end + n * (w * 0.5),
    ], true);
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
