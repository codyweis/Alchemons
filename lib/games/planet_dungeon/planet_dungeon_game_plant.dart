// lib/games/planet_dungeon/planet_dungeon_game_plant.dart
//
// VERDANTHOS — the Verdant Crypt. Plant's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart` (the treatment every planet after the Air
// pilot gets). The layout, the span graph, the seed beds and the scale rule
// all live in planet_dungeon_layout_plant.dart; this file is the rules that
// drive them.
//
// World rule: *the crypt never changes size; you do.* See the layout file's
// header for the full statement of the span sizes, the bed trade
// (bare / creeper / trunk), the vault trick, and the strategic question.
//
//  • Entry — the lich-gate is knotted shut with dead briar. PLANT unknots its
//    own element and the crypt opens (§5.5, the eased entry reveal).
//  • Star 0 (Lamp) — THE GRAVE-LAMPS. Three dead wicks: two giant wall
//    sconces no small body reaches, and one thumb-sized wick in a niche no
//    large hand fits. Lighting all three means changing size on the way, and
//    nothing else — no bed committed, no vine grown. ELEMENT-ONLY, all three
//    elements used: this is the star §4 guarantees to any trio of the right
//    elements on a first descent.
//  • Star 1 (Bloom) — THE GROWTH ALTAR, on the islet (§6's Tiny-Huge Island).
//    Three steps, and the crypt fixes the size of each: loam (Mud, huge),
//    seed (Plant, tiny), sun (Light+MASK, huge — the marquee gate). The islet
//    carries NO bole, so each step is a separate arrival at a separate size,
//    and the tiny one has no road until b_root's creeper is grown for it.
//  • Rite (Bloom Hall) — conduit A is the Plant+MANE rood screen (§6 put this
//    gate on Star 1; §4's first-descent guarantee wins, so it moved here);
//    the sepulchre's clay is element-only Mud.
//  • Star 2 (Shade) — MYS12 BOTANICA. §7: the guardian fights WITH the
//    planet's rule. It does not shrink the crypt — it SWELLS YOU. Every strike
//    beat bursts spores that put the party back in its own body and rots one
//    vine out in the crypt, so it un-makes your roads while you fight it. Its
//    lull exists only while you are small enough to be at the stem.
//  • Lost Maxim — THE UNSEEN SHADE: tend the seed under the giant root with
//    all three elements while TINY, then come back at your own size to see
//    what it became.
//
// NON-STRANDABILITY (the design's one real danger — see `solveVerdantCrypt`):
// a trunk fills the fissure it grew in, and the crypt's small graph is made of
// fissures, so this is a stranding machine of the same family as Ice's flues
// and Mud's fords. THE WITHERING is the valve: a Mud creature turns any mulch
// pit twice and the crypt's season turns — every vine sloughs to mould, every
// bed is bare, and the garden puts you out at its own gate in your own body.
// Costly (every road you grew), always available, and it is what
// `solveVerdantCrypt().strandable == 0` rests on.

part of 'planet_dungeon_game.dart';

/// Plant's lost maxim discovery id (the screen pays 20 gold on first find).
const String kPlantUnseenShadeEggId = 'egg:plant_unseen_shade';

// ── Device-tunable knobs ───────────────────────────────────
// Plant has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to a bole, a mulch pit, a lamp, the briar,
/// the altar, the sepulchre, the hidden seed or a bed to act on it.
const double _kCryptReach = 70.0;

/// How close the second body of a Mud+Light braid must stand (§6's recipe —
/// it substitutes the ELEMENT, never a family).
const double _kBraidReach = 150.0;

/// Seconds a turned mulch pit stays armed for its second touch. The withering
/// is the most expensive verb on the planet, so it is never one careless
/// press: the first touch turns the litter and says what it will cost.
const double _kMulchArmSeconds = 4.0;

/// Grave-moths a relit lamp wakes (Star 0's one consequence). Light in a crypt
/// is not free — something in the dark has been waiting for it.
const int _kLampMoths = 2;

/// Wisps the heart-seed's planting wakes out of the loam (Star 1's
/// consequence).
const int _kSeedWisps = 2;

extension VerdantCryptDungeon on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetCryptState() {
    if (!_isCrypt) return;
    // A death regrows nothing and unshrinks nothing by itself — the crypt is
    // puzzle state like every other planet's, so it resets with the run.
    crypt.reset();
  }

  // ── The map, at the size you are ─────────────────────────

  /// The span a door IS. One room pair, one span (pinned by the tests), so
  /// the door the player walks and the edge the proof walks are the same
  /// object and can never drift apart.
  CryptSpan? _cryptSpanFor(DungeonRoom room, DungeonDoor door) =>
      cryptSpanBetween(room.id, door.targetRoomId);

  /// A vine that has not been grown is not a passage at all — there is
  /// nothing there to see. Everything else the crypt SHOWS you, even when
  /// your body is the wrong one for it: being told what you cannot fit
  /// through is the whole teaching layer of this planet (§5.6 BLOCKED).
  bool _cryptDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isCrypt) return false;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) {
      // The briar knots the gate: every way out of this room is shut with it.
      return true;
    }
    final span = _cryptSpanFor(room, door);
    if (span == null) return false;
    if (span.need == SpanNeed.creeper || span.need == SpanNeed.trunk) {
      return !crypt.spanExists(span);
    }
    return false;
  }

  /// Blocked, and visibly so: either your body is the wrong size for this
  /// passage, or a trunk has grown up through the crack that used to be one.
  bool _cryptDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isCrypt) return false;
    final span = _cryptSpanFor(room, door);
    if (span == null) return false;
    if (!crypt.spanExists(span)) return true; // a fissure filled by its trunk
    return !crypt.spanFits(span, crypt.scale);
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. How the crypt got this way is Mask's earned reading.
  String _cryptDoorHint(DungeonRoom room, DungeonDoor door) {
    final span = _cryptSpanFor(room, door)!;
    if (!crypt.spanExists(span)) {
      return 'Grown shut, a trunk stands where the crack was';
    }
    return span.size == SpanSize.tinyOnly
        ? 'Too big by far, ${span.look} takes a smaller body'
        : 'Too small by far, ${span.look} wants a longer leg';
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Plant verb, in priority order. Returns true when one was consumed.
  /// The arena's root-gall outranks the guardian's own catch (Ice's pillar and
  /// Lightning's spike set that precedent) — the fight's errand must never be
  /// eaten by a strike.
  bool _tryCryptVerb(DungeonCreature a) {
    if (!_isCrypt) return false;
    return _tryBriarGate(a) ||
        _tryRootBole(a) ||
        _tryMulchPit(a) ||
        _trySeedGall(a) ||
        _tryGraveLamp(a) ||
        _tryGrowthAltar(a) ||
        _trySepulchre(a) ||
        _tryShadeSeed(a) ||
        _trySeedBed(a);
  }

  /// The planet's growing verb is element-only PLANT (§4), and Mud+Light→Plant
  /// (§6) stands in as a BRAID — two bodies at the same spot — for a party
  /// whose Plant hand is down. A recipe substitutes the ELEMENT, never a
  /// family, so it is never accepted at the rood screen or the altar's sun.
  bool _cryptHasGreenHand(DungeonCreature a) {
    final el = a.member.element;
    if (el == 'Plant') return true;
    if (el != 'Mud' && el != 'Light') return false;
    final want = el == 'Mud' ? 'Light' : 'Mud';
    return creatures.any(
      (c) =>
          !identical(c, a) &&
          c.alive &&
          c.member.element == want &&
          (c.position - a.position).distance < _kBraidReach,
    );
  }

  /// The entry rite: Plant unknots the dead briar off the lich-gate.
  bool _tryBriarGate(DungeonCreature a) {
    final pos = currentRoom.grove?.briarGate;
    if (pos == null || entryDoorRevealed) return false;
    if ((a.position - pos).distance > _kCryptReach) return false;
    if (a.member.element != 'Plant') {
      _setBlockedHint('Only Plant unknots its own briar');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The briar lets go of the gate, Verdanthos opens both its ways');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Plant',
      reagentElements: const ['Mud', 'Light'],
      particleCount: 30,
      intensity: 1.25,
    );
    return true;
  }

  /// A BOLE — a hollow seed-gall, and the only place in the crypt the party
  /// changes size. Element-only Plant (braid allowed): the planet's whole
  /// grammar has to work for any trio of the right elements (§4), and a size
  /// you cannot undo is a softlock, so this verb is never gated and never
  /// one-way.
  bool _trySeedGall(DungeonCreature a) {
    final pos = currentRoom.grove?.bole;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kCryptReach) return false;
    if (!_cryptHasGreenHand(a)) {
      _setBlockedHint('Only Plant wakes a seed-gall');
      return true;
    }
    _shiftScale(otherScale(crypt.scale), pos);
    return true;
  }

  /// The one place a size is written. Everything that has to happen when the
  /// party's body changes happens here, once.
  void _shiftScale(PlantScale to, Offset at) {
    if (crypt.scale == to) return;
    crypt.scale = to;
    _setHint(
      to == PlantScale.tiny
          ? 'The gall takes you in, and the moss stands up into a forest'
          : 'The gall lets you go, and the forest lies back down as moss',
      3.0,
    );
    _spawnAlchemyBurst(
      at,
      producedElement: 'Plant',
      reagentElements: const ['Light'],
      particleCount: 36,
      intensity: 1.3,
    );
  }

  /// THE WITHERING — the anti-strand valve, in two touches.
  ///
  /// The first turns the litter and says the price out loud; the second turns
  /// the crypt's season. Element-only Mud: a party without the ideal trio
  /// still has to be able to undo itself.
  bool _tryMulchPit(DungeonCreature a) {
    final pos = currentRoom.grove?.mulchPit;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kCryptReach) return false;
    if (a.member.element != 'Mud') {
      _setBlockedHint('Only Mud turns this litter');
      return true;
    }
    if (crypt.isFallow) {
      _setBlockedHint('Nothing to turn, the crypt already lies fallow');
      return true;
    }
    if (crypt.armedPitRoom != currentRoomId) {
      crypt.armedPitRoom = currentRoomId;
      crypt.armedPitTimer = _kMulchArmSeconds;
      // Attempt-edged and explicit: the most expensive verb on the planet
      // never fires on one careless press.
      _setHint(
        'The litter steams. Turn it again and the season takes back every '
        'road you have grown',
        _kMulchArmSeconds,
      );
      return true;
    }
    crypt.wither();
    // The season sloughs the party out with the leaf-fall. Without this the
    // valve could not save a small body on the islet, whose only small road
    // is the very creeper the withering takes away — see the no-strand proof.
    currentRoomId = layout.entranceRoomId;
    _spreadCreaturesAround(layout.entranceSpawn);
    _doorCooldown = 0.5;
    _clearHints();
    _setHint(
      'The whole crypt goes brown at once, every vine down to mould, and the '
      'gate puts you out in your own body',
      4.6,
    );
    _spawnAlchemyBurst(
      layout.entranceSpawn,
      producedElement: 'Mud',
      reagentElements: const ['Plant'],
      particleCount: 44,
      intensity: 1.4,
    );
    return true;
  }

  // ── Star 0 · THE GRAVE-LAMPS ─────────────────────────────

  GraveLamp? _lampIn(DungeonRoom room) {
    final id = room.grove?.lampId;
    if (id == null) return null;
    for (final l in kGraveLamps) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// The room the Lamp Star banks in, wherever it is (the solver and the
  /// tally read it without walking there).
  DungeonRoom? get _lampStarRoom {
    for (final r in layout.rooms.values) {
      if (r.grove?.starIndex == 0) return r;
    }
    return null;
  }

  /// A dead wick. Element-only Light — and the lamp only answers a body of
  /// the size it was cut for, which is the whole star.
  bool _tryGraveLamp(DungeonCreature a) {
    final lamp = _lampIn(currentRoom);
    if (lamp == null || crypt.lampsLit.contains(lamp.id)) return false;
    if ((a.position - lamp.position).distance > _kCryptReach) return false;
    if (a.member.element != 'Light') {
      _setBlockedHint('Only Light takes in a dead wick');
      return true;
    }
    if (crypt.scale != lamp.reach) {
      _setBlockedHint(
        lamp.reach == PlantScale.huge
            ? 'The sconce stands a whole world above your head'
            : 'No hand this size goes into a wick that small',
      );
      return true;
    }
    crypt.lampsLit.add(lamp.id);
    _spawnAlchemyBurst(
      lamp.position,
      producedElement: 'Light',
      reagentElements: const ['Plant'],
      particleCount: 26,
      intensity: 1.15,
    );
    // THE CONSEQUENCE (§7, one per star): a crypt is dark for a reason.
    spawnWispWave(
      element: 'Plant',
      center: lamp.position,
      count: _kLampMoths,
      unstable: true,
      announce: false,
    );
    if (!crypt.allLampsLit) {
      _setHint('The wick catches, and something comes off the ceiling');
      return true;
    }
    final room = _lampStarRoom;
    final idx = room?.grove?.starIndex;
    if (idx != null && !hasStar(idx)) {
      _setHint('Three graves lit, and none of them by the same body');
      earnStar(idx);
    }
    return true;
  }

  // ── Star 1 · THE GROWTH ALTAR ────────────────────────────

  /// The crypt's heart-seed, on the islet. Three steps, and the crypt fixes
  /// the size of each — so the star is not three verbs, it is three arrivals
  /// (§6: "relic needs both scales").
  bool _tryGrowthAltar(DungeonCreature a) {
    final pos = currentRoom.grove?.growthAltar;
    final idx = currentRoom.grove?.starIndex;
    if (pos == null || idx == null || hasStar(idx)) return false;
    if ((a.position - pos).distance > _kCryptReach) return false;
    final step = crypt.nextBloomStep;
    if (step == null) return false;
    if (crypt.scale != bloomStepScale(step)) {
      // A GOAL, not a method (§5.6): what is wrong, in one clause.
      _setBlockedHint(switch (step) {
        BloomStep.loam => 'No hand this size carries loam enough for this bowl',
        BloomStep.seed =>
          'The bowl is a walled field, no body this big gets '
              'down into it',
        BloomStep.sun => 'A light held this low never reaches over the rim',
      });
      return true;
    }
    switch (step) {
      case BloomStep.loam:
        if (a.member.element != 'Mud') {
          _setBlockedHint('The dry bowl answers Mud');
          return true;
        }
        _setHint('Loam goes in over the old ash, and settles');
      case BloomStep.seed:
        if (!_cryptHasGreenHand(a)) {
          _setBlockedHint('Only Plant sets a seed');
          return true;
        }
        _setHint('The seed goes down into the dark, and the dark stirs');
        // THE CONSEQUENCE: something else was sleeping in that loam.
        spawnWispWave(
          element: 'Plant',
          center: pos,
          count: _kSeedWisps,
          unstable: true,
          announce: false,
        );
      case BloomStep.sun:
        // The planet's marquee family gate (§4) — a Light that can show what
        // is not there. A recipe can never stand in for a family.
        const req = DungeonInteractionRequirement(
          element: 'Light',
          requiredFamily: DungeonAbility.insight,
        );
        switch (evaluateInteraction(a.member, req)) {
          case InteractionResult.passed:
          case InteractionResult.passedViaRecipe:
            _setHint('A sun that was never there comes over the rim');
          case InteractionResult.blockedFamily:
            // "The seal remembers" (§4): the chip stamps on first refusal.
            final gate = layout.familyGateFor('altar_sun');
            if (gate != null) {
              _stampFamilyGate(gate);
            } else {
              _setBlockedHint(
                'Only a Light that can show what is not there passes for a sun',
              );
            }
            return true;
          case InteractionResult.blockedElement:
          case InteractionResult.blockedStat:
            _setBlockedHint('The seed wants a sun, it answers Light');
            return true;
        }
    }
    crypt.bloomStep++;
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Plant',
      reagentElements: [bloomStepElement(step)],
      particleCount: 28,
      intensity: 1.2,
    );
    if (crypt.bloomWoken) {
      _setHint('The heart-seed opens, and the whole crypt smells of spring');
      earnStar(idx);
    }
    return true;
  }

  // ── The rite · THE BLOOM HALL ────────────────────────────

  /// The rite's second half — element-only Mud, so a party missing the Mane
  /// meets exactly ONE refusal in this hall rather than two.
  bool _trySepulchre(DungeonCreature a) {
    final pos = currentRoom.grove?.sepulchre;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kCryptReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (a.member.element != 'Mud') {
      _setBlockedHint('The baked clay answers Mud alone');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The clay will not slake, it answers only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
    _setHint(
      'The clay slumps off the sepulchre, and the hall lets out a '
      'breath',
    );
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Mud',
      reagentElements: const ['Plant'],
      particleCount: 30,
      intensity: 1.2,
    );
    return true;
  }

  // ── The beds — the planet's world edit ───────────────────

  /// One seed, and the crypt decides what it becomes from the size of the
  /// hand that set it. See the layout header: a shallow seed set by a giant
  /// comes up a creeper (a road for a small body); a deep seed set by a small
  /// body comes up a trunk (a road for a giant) and fills the fissure it grew
  /// in. Both are permanent for the run; only the withering empties a bed.
  bool _trySeedBed(DungeonCreature a) {
    for (final b in cryptBedsIn(currentRoomId)) {
      if ((a.position - b.crown).distance > _kCryptReach) continue;
      if (!crypt.canPlant(b.id)) {
        _setBlockedHint(
          crypt.stateOf(b.id) == VineState.trunk
              ? 'A trunk owns this ground now'
              : 'A creeper owns this ground now',
        );
        return true;
      }
      if (!_cryptHasGreenHand(a)) {
        _setBlockedHint('Only Plant sets a seed');
        return true;
      }
      final grown = crypt.plant(b.id)!;
      _setHint(_bedGrowthLine(b, grown), 3.4);
      _spawnAlchemyBurst(
        b.crown,
        producedElement: 'Plant',
        reagentElements: [a.member.element],
        particleCount: grown == VineState.trunk ? 40 : 24,
        intensity: grown == VineState.trunk ? 1.35 : 1.0,
      );
      // The road it just made (and, for a trunk, the one it just took) both
      // deserve the reveal flourish the engine gives new doors.
      for (final s in kCryptSpans) {
        if (s.bedId != b.id) continue;
        if (s.need == SpanNeed.fissure) continue;
        if (!crypt.spanExists(s)) continue;
        _queueDoorReveal(s.from, s.to);
        _queueDoorReveal(s.to, s.from);
      }
      return true;
    }
    return false;
  }

  String _bedGrowthLine(SeedBed bed, VineState grown) {
    if (grown == VineState.creeper) {
      return 'A green thread runs out of ${bed.look}. Hardly anything at all, '
          'at this size';
    }
    return 'It comes up wood, and it comes up fast, and ${bed.look} is not '
        'there any more';
  }

  // ── Star 2 · BOTANICA ────────────────────────────────────

  /// The arena's own root-gall. Element-only Plant (braid allowed), and it
  /// only ever shrinks: at your own size there is nothing to hit in among
  /// those roots.
  bool _tryRootBole(DungeonCreature a) {
    final pos = currentRoom.grove?.rootBole;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kCryptReach) return false;
    if (crypt.isTiny) return false;
    if (!_cryptHasGreenHand(a)) {
      _setBlockedHint('Only Plant wakes a seed-gall');
      return true;
    }
    _shiftScale(PlantScale.tiny, pos);
    return true;
  }

  /// §7 — the guardian fights WITH the planet's rule. Botanica does not
  /// shrink the crypt; it SWELLS YOU. Its lull exists only while the party is
  /// small enough to be in among the roots at the stem, and every strike beat
  /// bursts spores that put you back in your own body AND rots one vine out
  /// in the crypt — it un-makes your roads while you fight it.
  void _updateBotanica(DungeonRoom room, double dt) {
    if (room.guardian == null || !guardianAwake) return;
    if (!crypt.isTiny) {
      guardianVulnerable = false;
      return;
    }
    if (guardianVulnerable && !_botanicaBitLastFrame) {
      // The window opened: the flower answers by breathing out.
      _botanicaBitLastFrame = true;
      return;
    }
    if (!guardianVulnerable && _botanicaBitLastFrame) {
      _botanicaBitLastFrame = false;
      crypt.scale = PlantScale.huge;
      final rotted = _rotOneVine();
      _setHint(
        rotted == null
            ? 'Spores burst, and you come up out of the roots at your own size'
            : 'Spores burst, you come up at your own size, and somewhere out '
                  'there a vine goes black',
      );
    }
  }

  /// The blight takes one road back. Deterministic (the first bed still
  /// holding anything, in authored order) so a fight reads the same twice.
  /// Returns the bed it emptied, or null when there is nothing to rot.
  String? _rotOneVine() {
    for (final b in kCryptBeds) {
      if (crypt.stateOf(b.id) == VineState.bare) continue;
      crypt.bed[b.id] = VineState.bare;
      return b.id;
    }
    return null;
  }

  // ── The Lost Maxim · THE UNSEEN SHADE ────────────────────

  /// The seed nobody planted, under the giant root. Deliberately beyond what
  /// the stars demand (§ "Easter eggs"): it only exists for a body small
  /// enough to be under there, it wants all three of the crypt's elements,
  /// and the thing it becomes can only be seen from your own size — which
  /// means one last trip back to a gall to look at it.
  bool _tryShadeSeed(DungeonCreature a) {
    if (discoveredClouds.contains(kPlantUnseenShadeEggId)) return false;
    final pos = currentRoom.grove?.shadeSeed;
    if (pos == null || crypt.shadeRisen) return false;
    if ((a.position - pos).distance > _kCryptReach) return false;
    const wants = ['Mud', 'Light', 'Plant'];
    if (crypt.tendedBy.length < wants.length) {
      // A huge body cannot even see under the root, let alone tend anything.
      if (!crypt.isTiny) return false;
      final el = a.member.element;
      if (!wants.contains(el) || crypt.tendedBy.contains(el)) return false;
      crypt.tendedBy.add(el);
      _setHint(
        crypt.tendedBy.length < wants.length
            ? 'The little seed takes it, and asks for the rest'
            : 'The seed has everything it wants, and nothing here can see it '
                  'grow',
        4.0,
      );
      _spawnAlchemyBurst(
        pos,
        producedElement: 'Plant',
        reagentElements: [el],
        particleCount: 16,
      );
      return true;
    }
    // Tended three ways, and now it wants to be LOOKED at from above.
    if (crypt.isTiny) return false;
    crypt.shadeRisen = true;
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    beginMaximRite(kPlantUnseenShadeEggId, pos);
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Plant',
      reagentElements: const ['Mud', 'Light'],
      particleCount: 44,
      intensity: 1.5,
    );
    return true;
  }

  // ── Per-frame ────────────────────────────────────────────

  void _updateCrypt(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isCrypt) return;
    if (crypt.armedPitTimer > 0) {
      crypt.armedPitTimer = max(0.0, crypt.armedPitTimer - dt);
      if (crypt.armedPitTimer == 0) crypt.armedPitRoom = null;
    }
    _updateBotanica(room, dt);
  }

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): the counters live beside the star
  /// tracker, per room, never as prose that fades. SIZE is the default,
  /// because on this planet it is the one number every decision turns on.
  DungeonProgressReadout? _cryptProgressReadout() {
    final room = layout.rooms[currentRoomId];
    final grove = room?.grove;
    if (grove?.growthAltar != null && !hasStar(grove!.starIndex!)) {
      final n = crypt.bloomStep;
      return DungeonProgressReadout(
        label: 'BLOOM',
        value: '$n/${BloomStep.values.length}',
        fraction: n / BloomStep.values.length,
      );
    }
    if (grove?.lampId != null && !hasStar(0)) {
      final n = crypt.lampsLit.length;
      return DungeonProgressReadout(
        label: 'LAMPS',
        value: '$n/${kGraveLamps.length}',
        fraction: n / kGraveLamps.length,
      );
    }
    return DungeonProgressReadout(
      label: 'SIZE',
      value: scaleWord(crypt.scale),
      fraction: crypt.isTiny ? 0.25 : 1.0,
    );
  }

  /// WHAT, never HOW (§5.6). Every method here is Mask's to give.
  String? _cryptObjectiveHint(DungeonRoom room) {
    if (room.guardian != null) {
      return 'Botanica\'s Heart, the flower keeps the last star';
    }
    if (room.grove?.sepulchre != null) {
      return 'The Bloom Hall, the rite waits on the sepulchre';
    }
    if (room.grove?.growthAltar != null) {
      return hasStar(room.grove!.starIndex!)
          ? null
          : 'The Islet, the heart-seed has slept a long age';
    }
    if (room.vaultCache != null) {
      return 'Inside the altar\'s own rim, something is bottled here';
    }
    if (room.grove?.lampId != null && !hasStar(0)) {
      return crypt.lampsLit.contains(room.grove!.lampId)
          ? null
          : 'A grave-lamp stands dead here';
    }
    if (room.id == 'crypt_niche') {
      return 'The Crypt Niche, nothing this deep was built for you';
    }
    if (room.id == 'pollen_stair') {
      return 'The Pollen Stair, a gall hangs at the turn of it';
    }
    if (room.id == 'fern_gallery') {
      return 'The Fern Gallery, one root has swallowed half the wall';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Root Porch, the crypt runs west, and under itself'
          : 'The Root Porch, the lich-gate is knotted shut';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _cryptAmbientHint(DungeonCreature a, DungeonRoom room) {
    for (final b in cryptBedsIn(room.id)) {
      if ((a.position - b.crown).distance > _kCryptReach) continue;
      _setAmbientHint(switch (crypt.stateOf(b.id)) {
        VineState.bare => 'Old soil, and it still smells like soil',
        VineState.creeper => 'Something fine is moving along the ground here',
        VineState.trunk => 'Bark, and a slow creak somewhere above it',
      });
      return;
    }
    final gall = room.grove?.bole;
    if (gall != null && (a.position - gall).distance < 110) {
      _setAmbientHint('The gall breathes in, and does not breathe out');
      return;
    }
    final pit = room.grove?.mulchPit;
    if (pit != null && (a.position - pit).distance < 110) {
      _setAmbientHint('Warm, and turning over on its own');
    }
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), and it is
  /// tiered by Intelligence.
  void _cryptReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    if (room.grove?.growthAltar != null) {
      _setInsightHint(switch (tier) {
        0 => 'The bowl has been dry so long the ash in it has set',
        1 =>
          'It wants three things, and it will only take them in the order '
              'the ground puts them in',
        _ =>
          'Loam first, and only a big hand carries enough; then the seed, '
              'and only a small body gets down there to set it; then a sun, '
              'and this crypt has none, someone must show it one',
      });
      return;
    }
    if (room.grove?.lampId != null) {
      _setInsightHint(switch (tier) {
        0 =>
          'Three of these are dead, and they were not all cut for the same '
              'mourner',
        1 =>
          'Two hang at a mourner\'s eye and one is a thumb\'s width deep in '
              'a wall',
        _ =>
          'You will not light all three in one body. The niche is cracks '
              'all the way in, and the sconces are a whole world above them',
      });
      return;
    }
    if (room.vaultCache != null || room.grove?.growthAltar != null) {
      _setInsightHint('The rim is cut with a door, and it is a hand high');
      return;
    }
    if (cryptBedsIn(room.id).isNotEmpty) {
      _setInsightHint(switch (tier) {
        0 => 'Something could still be made to grow here',
        1 =>
          'What comes up depends on how deep the seed goes, and that '
              'depends on the hand',
        _ =>
          'A big hand only presses a seed into the surface and gets a '
              'thread; a small one climbs down and sets it at the root, and '
              'gets wood, and the wood fills the crack it came out of',
      });
      return;
    }
    // Anywhere in the crypt, insight reads the SIZE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'Half of this place was built for something else',
      1 =>
        'Cracks and grates take a small body; rills and treads and boughs '
            'want a long leg. The galls are the only place that changes',
      _ =>
        'There are three galls in the whole crypt, and nothing else on this '
            'planet will change your size. Plan the road at both sizes before '
            'you plant anything, and the litter is the only take-back, and it '
            'takes back all of it at once',
    });
  }

  /// Per-room mood — the porch is grey daylight, the crypt is deep green, and
  /// the niche is the dark inside a wall.
  double get _cryptMoodTarget => switch (currentRoomId) {
    'root_porch' => 0.74,
    'mosswalk' => 0.6,
    'fern_gallery' => 0.5,
    'pollen_stair' => 0.44,
    'lantern_court' => crypt.allLampsLit ? 0.66 : 0.34,
    'crypt_niche' => 0.18,
    'islet' => 0.62,
    'gourd_hollow' => 0.22,
    'bloom_hall' => 0.4,
    _ => guardianAwake ? 0.36 : 0.46,
  };

  // ── THE NO-STRAND PROOF ──────────────────────────────────

  /// Exhaustive reachability over the crypt's whole state graph.
  ///
  /// A state is (which room you stand in) × (what SIZE you are) × (what each
  /// bed holds). Every legal move is expanded: walking any span open at that
  /// size in that arrangement, planting any bare bed in the room you stand in
  /// (the product fixed by your size, exactly as the verb fixes it), waking a
  /// gall, turning a mulch pit — and Botanica's spore burst, which swells you
  /// and rots a vine and is not a move the player chooses at all. Including
  /// the burst makes the enumerated set a strict SUPERSET of what play alone
  /// can reach, and reachability is then audited using only the moves the
  /// PLAYER controls. That is the honest form of the question: from anywhere
  /// the world can put you, can you still get out.
  ///
  /// Four answers, all by construction rather than by argument:
  ///
  ///  1. `strandable` — states from which some room is no longer reachable.
  ///     **It must be zero.** "Reachable" is checked for EVERY room in the
  ///     layout, which is stronger than the brief asks: not just the exit and
  ///     the unearned stars, but the vault as well.
  ///  2. `strandableWithoutWithering` — the same audit with the mulch pits
  ///     deleted. It is expected to be LARGE: the withering is load-bearing,
  ///     not decoration, and if this ever drops to zero someone has quietly
  ///     made a trunk reversible and the planet has lost its identity.
  ///  3. `vaultLosable` — states from which the gourd hollow can no longer be
  ///     entered WITHOUT paying a withering. It must be non-zero, because
  ///     that cost is what makes the vault trick a trick (§5.5).
  ///  4. `sizeLocked` — states from which the party can never be the OTHER
  ///     size again without a withering. Being stuck at the wrong scale is
  ///     this planet's own named hazard, so it is measured separately rather
  ///     than folded into the room count.
  ({
    int states,
    int arrangements,
    int strandable,
    int strandableWithoutWithering,
    int vaultLosable,
    int sizeLocked,
  })
  solveVerdantCrypt() {
    final rooms = layout.rooms.keys.toList()..sort();
    final ids = [for (final b in kCryptBeds) b.id];
    final start = List.filled(ids.length, VineState.bare);
    final gallRooms = {
      for (final e in layout.rooms.entries)
        if (e.value.grove?.bole != null) e.key,
    };
    final pitRooms = {
      for (final e in layout.rooms.entries)
        if (e.value.grove?.mulchPit != null) e.key,
    };
    final guardianRoom = layout.rooms.values
        .firstWhere((r) => r.guardian != null)
        .id;
    final vaultRoom = layout.rooms.values
        .firstWhere((r) => r.vaultCache != null)
        .id;

    String enc(String room, PlantScale s, List<VineState> v) =>
        '$room|${s.index}|${v.map((x) => x.index).join()}';

    VineState at(List<VineState> v, String id) => v[ids.indexOf(id)];

    /// Whether a span exists in arrangement [v] — the SAME rule
    /// [VerdantCrypt.spanExists] applies, restated over a plain list so the
    /// search never has to mutate live state.
    bool exists(CryptSpan s, List<VineState> v) {
      final id = s.bedId;
      if (id == null) return true;
      return switch (s.need!) {
        SpanNeed.fissure => at(v, id) != VineState.trunk,
        SpanNeed.creeper => at(v, id) == VineState.creeper,
        SpanNeed.trunk => at(v, id) == VineState.trunk,
      };
    }

    bool fits(CryptSpan s, PlantScale size) => switch (s.size) {
      SpanSize.both => true,
      SpanSize.tinyOnly => size == PlantScale.tiny,
      SpanSize.hugeOnly => size == PlantScale.huge,
    };

    /// Which doors are walkable. Derived from the SAME spans the engine gates
    /// real doors with, via the room's own door list, so the proof can never
    /// drift from the doors the player actually meets.
    List<String> exits(String room, PlantScale size, List<VineState> v) {
      final out = <String>[];
      for (final d in layout.rooms[room]!.doors) {
        final s = cryptSpanBetween(room, d.targetRoomId);
        if (s == null) {
          out.add(d.targetRoomId);
          continue;
        }
        if (exists(s, v) && fits(s, size)) out.add(d.targetRoomId);
      }
      return out;
    }

    List<(String, PlantScale, List<VineState>)> moves(
      String room,
      PlantScale size,
      List<VineState> v, {
      required bool witheringEnabled,
      required bool spores,
    }) {
      final out = <(String, PlantScale, List<VineState>)>[];
      for (final t in exits(room, size, v)) {
        out.add((t, size, v));
      }
      // Planting: the product is fixed by the size standing at the bed.
      for (final b in cryptBedsIn(room)) {
        if (at(v, b.id) != VineState.bare) continue;
        final next = [...v];
        next[ids.indexOf(b.id)] = size == PlantScale.huge
            ? VineState.creeper
            : VineState.trunk;
        out.add((room, size, next));
      }
      // A gall flips the size, both ways, always.
      if (gallRooms.contains(room)) out.add((room, otherScale(size), v));
      // The arena's root-gall only ever shrinks.
      if (layout.rooms[room]!.grove?.rootBole != null &&
          size == PlantScale.huge) {
        out.add((room, PlantScale.tiny, v));
      }
      // THE WITHERING: everything bare, your own body, out at the gate.
      if (witheringEnabled && pitRooms.contains(room)) {
        final fallow =
            size == PlantScale.huge && v.every((x) => x == VineState.bare);
        if (!fallow) {
          out.add((layout.entranceRoomId, PlantScale.huge, start));
        }
      }
      // Botanica's spore burst — the world's move, never the player's, and
      // only ever inside the arena.
      if (spores && room == guardianRoom) {
        for (var i = 0; i < v.length; i++) {
          if (v[i] == VineState.bare) continue;
          final next = [...v];
          next[i] = VineState.bare;
          out.add((room, PlantScale.huge, next));
        }
        if (size != PlantScale.huge) out.add((room, PlantScale.huge, v));
      }
      return out;
    }

    ({Set<String> rooms, Set<int> sizes}) reach(
      String room,
      PlantScale size,
      List<VineState> v, {
      required bool witheringEnabled,
    }) {
      final seen = <String>{enc(room, size, v)};
      final hitRooms = <String>{room};
      final hitSizes = <int>{size.index};
      final queue = [(room, size, v)];
      while (queue.isNotEmpty) {
        final (rm, sz, st) = queue.removeLast();
        for (final m in moves(
          rm,
          sz,
          st,
          witheringEnabled: witheringEnabled,
          spores: false,
        )) {
          final k = enc(m.$1, m.$2, m.$3);
          if (!seen.add(k)) continue;
          hitRooms.add(m.$1);
          hitSizes.add(m.$2.index);
          queue.add(m);
        }
      }
      return (rooms: hitRooms, sizes: hitSizes);
    }

    // Every state the world can put the party in — player moves AND the
    // flower's.
    final live = <String, (String, PlantScale, List<VineState>)>{};
    final first = (layout.entranceRoomId, PlantScale.huge, start);
    live[enc(first.$1, first.$2, first.$3)] = first;
    final queue = [first];
    while (queue.isNotEmpty) {
      final (rm, sz, st) = queue.removeLast();
      for (final m in moves(rm, sz, st, witheringEnabled: true, spores: true)) {
        final k = enc(m.$1, m.$2, m.$3);
        if (live.containsKey(k)) continue;
        live[k] = m;
        queue.add(m);
      }
    }

    var strandable = 0;
    var without = 0;
    var vaultLosable = 0;
    var sizeLocked = 0;
    for (final st in live.values) {
      if (reach(st.$1, st.$2, st.$3, witheringEnabled: true).rooms.length <
          rooms.length) {
        strandable++;
      }
      final bare = reach(st.$1, st.$2, st.$3, witheringEnabled: false);
      if (bare.rooms.length < rooms.length) without++;
      if (!bare.rooms.contains(vaultRoom)) vaultLosable++;
      if (bare.sizes.length < 2) sizeLocked++;
    }
    return (
      states: live.length,
      arrangements: {
        for (final s in live.values) s.$3.map((x) => x.index).join(),
      }.length,
      strandable: strandable,
      strandableWithoutWithering: without,
      vaultLosable: vaultLosable,
      sizeLocked: sizeLocked,
    );
  }

  // ── Rendering ────────────────────────────────────────────
  // VISUAL GRAMMAR (§5.5): scale is drawn as a change of REFERENCE, never as a
  // change to the world. At huge the crypt's furniture is trim — a moss verge,
  // a joint in the paving, a bead of dew. At tiny the SAME furniture is
  // redrawn as terrain: the verge becomes a canopy of fronds, the joint a
  // ravine with its section showing, the dew standing water. Nothing here is
  // drawn like Dust's mound heights or Water's tide line, and there are no
  // blur filters anywhere (the game's known jank source).

  static const Color _kCryptGreen = Color(0xFF4E8B4A);
  static const Color _kCryptDeep = Color(0xFF1D2E1E);
  static const Color _kCryptBark = Color(0xFF6B4E33);
  static const Color _kCryptBone = Color(0xFFD9D2BC);
  static const Color _kCryptLamp = Color(0xFFF2D287);

  void _renderCrypt(Canvas canvas, DungeonRoom room) {
    _renderCryptGround(canvas, room);
    _renderCryptSpans(canvas, room);
    _renderCryptBeds(canvas, room);
    _renderCryptObjects(canvas, room);
  }

  // Stone, soil and green. The crypt is limestone being eaten by a garden, so
  // nothing in it is one colour: the paving runs from a pale weathered course
  // to a slab so lichened it is nearly moss.
  static const Color _kCryptStone = Color(0xFFA1977C);
  static const Color _kCryptStoneCold = Color(0xFF333B2C);
  static const Color _kCryptSeam = Color(0xFF11150F);
  static const Color _kCryptSoil = Color(0xFF2A2115);
  static const Color _kCryptMoss = Color(0xFF5A7A39);
  static const Color _kCryptWater = Color(0xFF20403C);
  static const Color _kCryptSheen = Color(0xFF9FD8C4);

  /// THE GROUND. One geometry, two readings.
  ///
  /// The whole planet rests on a sentence — *the crypt never changes size; you
  /// do* — and the art has to be able to carry it on its own, because the
  /// player meets the picture before they meet the rule. So the room's ground
  /// is built ONCE at its true world size and then rendered twice over: the
  /// same ledger stones, the same joints between them, the same seeps and the
  /// same moss, drawn as TRIM at your own size and as TERRAIN at a small one.
  /// A joint is a hairline up here and a lit-walled ravine down there. A seep
  /// is a bead of dew up here and standing water down there. Nothing moves
  /// between the two pictures, which is what makes "this is the room I just
  /// left" legible without a word of text.
  ///
  /// Cost: everything irregular is cached (see `_cryptGroundCache`). Per frame
  /// this is fills and strokes over a fixed list, plus three phases — the fern
  /// sway, the sheen on standing water, and a drift of spores.
  void _renderCryptGround(Canvas canvas, DungeonRoom room) {
    final g = _cryptGround(room);
    final b = room.bounds.deflate(10);
    final tiny = crypt.isTiny;
    final t = _time;

    // The gourd is not a room of the crypt at all — it is the inside of a
    // seed. It gets its own ground and none of the masonry below.
    if (_cryptHas(room.id, 'shell')) {
      _renderGourdShell(canvas, room, g, tiny, t);
      return;
    }

    // THE ISLET STANDS IN WATER. Drawn first and OUTSIDE the paving, so the
    // island reads as a thing the water surrounds rather than a blue frame
    // painted on the floor (which is how the first attempt read).
    if (_cryptHas(room.id, 'water')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          room.bounds.deflate(8),
          const Radius.circular(30),
        ),
        Paint()..color = const Color(0xFF0E2A34).withValues(alpha: 0.62),
      );
      // Two slow rings on the water. The islet read as a stone lozenge on a
      // green floor until the water had something moving in it.
      for (var k = 0; k < 2; k++) {
        final ph = ((t * 0.10 + k * 0.5) % 1.0);
        canvas.drawOval(
          Rect.fromCenter(
            center: room.bounds.center,
            width: b.width * (0.94 + ph * 0.10),
            height: b.height * (0.94 + ph * 0.10),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = _kCryptSheen.withValues(alpha: 0.10 * (1 - ph)),
        );
      }
      canvas.drawPath(
        g.shore,
        Paint()..color = _kCryptSoil.withValues(alpha: 0.62),
      );
      // A wet line where the water meets the bank, not a drawn ellipse.
      canvas.drawPath(
        g.shore,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _kCryptSheen.withValues(alpha: 0.16),
      );
    } else {
      // Grave soil under the paving. Everything the stones do not cover is
      // this, so a missing slab is a hole down to earth and not a hole in the
      // floor. Alpha holds the FLOOR TRANSLUCENCY RULE.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          room.bounds.deflate(8),
          const Radius.circular(30),
        ),
        Paint()..color = _kCryptSoil.withValues(alpha: 0.42),
      );
    }

    // ── the ledger stones ──────────────────────────────────
    // A funerary floor is grave slabs, every one cut for a different body and
    // laid at a different century, so no two are the same size and none of
    // them line up. They come out of a recursive split of the room (see
    // `_buildCryptGround`) precisely so that they CANNOT tile.
    final shadow = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.30);
    for (var i = 0; i < g.slabs.length; i++) {
      final tone = g.slabTone[i];
      // At tiny each slab is a mesa you stand on top of, so it throws a real
      // shadow into the joint beside it; at huge it is flush paving and the
      // shadow is only a suggestion of a lip.
      canvas.save();
      canvas.translate(1.5, tiny ? 6 : 2.5);
      canvas.drawPath(g.slabs[i], shadow);
      canvas.restore();
      canvas.drawPath(
        g.slabs[i],
        Paint()
          ..color = Color.lerp(
            _kCryptStoneCold,
            _kCryptStone,
            tone,
          )!.withValues(alpha: 0.36),
      );
      // The lit upper edge. One stroke, clipped to the slab so it reads as
      // the top face catching the light rather than an outline round it.
      canvas.save();
      canvas.clipPath(g.slabs[i]);
      canvas.translate(0, tiny ? 3 : 1.2);
      canvas.drawPath(
        g.slabs[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = tiny ? 4 : 1.6
          ..color = _kCryptBone.withValues(alpha: 0.13 + 0.10 * tone),
      );
      canvas.restore();
    }

    // ── the joints, which are the crypt's small graph ──────
    // This is the load-bearing drawing on the planet. The cracks a small body
    // walks are the SAME lines a large one steps over without noticing, so
    // they are one cached set of polylines rendered at two depths.
    for (var i = 0; i < g.seams.length; i++) {
      final w = g.seamWidth[i];
      if (tiny) {
        // A ravine: banked rim, black section, and a fringe of moss where the
        // light stops. The rim goes down first and wider, so the crack reads
        // as something cut INTO the ground.
        canvas.drawPath(
          g.seams[i],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = w + 5
            ..color = _kCryptSoil.withValues(alpha: 0.85),
        );
        canvas.drawPath(
          g.seams[i],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = w
            ..color = _kCryptSeam.withValues(alpha: 0.88),
        );
        if (w > 12) {
          // Only the big ones get a lit wall — otherwise every hairline in
          // the room sprouted a highlight and the floor turned to tinsel.
          canvas.save();
          canvas.translate(0, -w * 0.30);
          canvas.drawPath(
            g.seams[i],
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = _kCryptMoss.withValues(alpha: 0.35),
          );
          canvas.restore();
        }
      } else {
        canvas.drawPath(
          g.seams[i],
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w > 12 ? 2.4 : 1.2
            ..color = _kCryptSeam.withValues(alpha: 0.42),
        );
      }
    }

    // ── worn epitaphs ──────────────────────────────────────
    // Two or three strokes of a name nobody can read any more. At your own
    // size they are shallow scratches; at tiny they are trenches you could
    // lose a leg in, which is the joke the whole planet is built on.
    for (var i = 0; i < g.carvings.length; i++) {
      final c = g.carvings[i];
      final a = g.carvingAngle[i];
      final len = g.carvingLen[i];
      final dx = cos(a) * len, dy = sin(a) * len;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = tiny ? 5 : 1.4
        ..color = _kCryptSeam.withValues(alpha: tiny ? 0.55 : 0.26);
      for (var k = -1; k <= 1; k++) {
        final o = Offset(
          -dy / len * k * (tiny ? 13 : 7),
          dx / len * k * (tiny ? 13 : 7),
        );
        canvas.drawLine(
          c + o - Offset(dx / 2, dy / 2),
          c + o + Offset(dx / 2, dy / 2),
          p,
        );
      }
    }

    // ── the seeps ──────────────────────────────────────────
    for (var i = 0; i < g.seeps.length; i++) {
      final c = g.seeps[i];
      final r = g.seepR[i];
      if (tiny) {
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 2.6, height: r * 1.5),
          Paint()..color = _kCryptWater.withValues(alpha: 0.72),
        );
        final ph = sin(t * 0.6 + i * 1.7);
        canvas.drawLine(
          Offset(c.dx - r * 0.8, c.dy + ph * r * 0.3),
          Offset(c.dx + r * 0.9, c.dy + ph * r * 0.3 - 1),
          Paint()
            ..strokeWidth = 1.3
            ..color = _kCryptSheen.withValues(alpha: 0.20),
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 0.9, height: r * 0.5),
          Paint()..color = _kCryptWater.withValues(alpha: 0.50),
        );
      }
    }

    // ── moss ───────────────────────────────────────────────
    // The same blotches both ways: a stain you walk over, or a canopy you
    // walk under. The fronds are only drawn at tiny — up there moss has no
    // silhouette, and drawing one anyway is what made the old render look
    // like a lawn instead of a crypt.
    for (var i = 0; i < g.moss.length; i++) {
      canvas.drawPath(
        g.moss[i],
        Paint()..color = _kCryptMoss.withValues(alpha: tiny ? 0.30 : 0.26),
      );
      if (tiny) {
        final c = g.mossCentre[i];
        final r = g.mossR[i];
        for (var k = 0; k < 5; k++) {
          final a = -pi / 2 + (k - 2) * 0.42;
          final h = r * (1.5 + 0.35 * ((i + k) % 3));
          final sway = sin(t * 0.8 + i + k * 0.6) * 3;
          canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy)
              ..quadraticBezierTo(
                c.dx + cos(a) * h * 0.4,
                c.dy + sin(a) * h * 0.5,
                c.dx + cos(a) * h * 0.8 + sway,
                c.dy + sin(a) * h,
              ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.4
              ..color = _kCryptGreen.withValues(alpha: 0.44),
          );
        }
      }
    }

    // ── the roots that are taking the building apart ───────
    _renderCryptRoots(canvas, g, tiny);

    // ── the built edge ─────────────────────────────────────
    _renderCryptMasonry(canvas, room, g, tiny, t);

    // ── what this room in particular is ────────────────────
    _renderCryptFixtures(canvas, room, g, tiny, t);

    // The air of the place: spores off the fern, going nowhere in particular.
    // The pollen stair is named for its air, so it gets three times as much
    // of it and nothing else changes. A dozen circles at worst — the only
    // thing in here that is genuinely per-frame.
    final motes = _cryptHas(room.id, 'stair') ? 18 : 6;
    for (var i = 0; i < motes; i++) {
      final ph = (t * 0.05 + i * 0.17) % 1.0;
      final x = b.left + 30 + ((i * 197) % (b.width.toInt() - 60));
      final y = b.bottom - 20 - ph * (b.height - 60);
      canvas.drawCircle(
        Offset(x, y + sin(t * 0.7 + i * 2.1) * 9),
        tiny ? 3.2 : 1.7,
        Paint()
          ..color = const Color(
            0xFFE8E2A8,
          ).withValues(alpha: 0.20 * (1 - ph) + 0.05),
      );
    }
  }

  /// Roots reaching in under the wall course.
  ///
  /// FIRST ATTEMPT READ AS SCAFFOLDING: they were constant-width strokes that
  /// ran clean across the room from one wall to the opposite one, so every
  /// chamber had two brown scaffold poles laid over it in an X. A root is not
  /// a beam — it comes in under the masonry and TAPERS to nothing, so these
  /// are filled polygons that start thick at the wall and end at a point,
  /// they curve hard, and they stop short of the middle of the room.
  void _renderCryptRoots(Canvas canvas, _CryptGround g, bool tiny) {
    for (var i = 0; i < g.roots.length; i++) {
      canvas.save();
      canvas.translate(2, 5);
      canvas.drawPath(
        g.roots[i],
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.28),
      );
      canvas.restore();
      canvas.drawPath(
        g.roots[i],
        Paint()..color = const Color(0xFF2E2113).withValues(alpha: 0.92),
      );
      // The lit crest along the back of the root, so it reads as round.
      canvas.drawPath(
        g.rootCrests[i],
        Paint()..color = _kCryptBark.withValues(alpha: 0.42),
      );
      // Feeder rootlets — a root with no branches is a pipe, and the first
      // pass looked exactly like plumbing.
      for (var k = 0; k < g.rootlets[i].length; k++) {
        final a = g.rootlets[i][k];
        canvas.drawLine(
          a.$1,
          a.$2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = tiny ? 3.4 : 2.0
            ..color = const Color(0xFF3A2A19).withValues(alpha: 0.8),
        );
      }
    }
  }

  /// The wall course, its burial niches and its column stumps. This is the
  /// architecture: a crypt seen from above is a band of ashlar with the
  /// loculi cut into it, and the room's whole edge used to be a rounded
  /// rectangle with a green lip.
  void _renderCryptMasonry(
    Canvas canvas,
    DungeonRoom room,
    _CryptGround g,
    bool tiny,
    double t,
  ) {
    for (var i = 0; i < g.masonry.length; i++) {
      final r = g.masonry[i];
      final tone = g.masonryTone[i];
      canvas.drawRect(
        r.translate(1, 2),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.26),
      );
      // The course is deliberately DARKER and colder than the paving. When
      // the two shared a palette the wall vanished into the floor and the
      // whole room read as one quilt of stone with no edge to it.
      canvas.drawRect(
        r,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF20261C),
            const Color(0xFF6C6754),
            tone,
          )!.withValues(alpha: 0.80),
      );
      canvas.drawRect(
        Rect.fromLTRB(r.left, r.top, r.right, r.top + 3),
        Paint()..color = _kCryptBone.withValues(alpha: 0.14),
      );
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _kCryptSeam.withValues(alpha: 0.55),
      );
    }
    // LOCULI — the shelves the crypt was built to hold. Dark slots of
    // different depths; a few still have their slab, most do not.
    for (var i = 0; i < g.loculi.length; i++) {
      final r = g.loculi[i];
      canvas.drawRect(r, Paint()..color = _kCryptSeam.withValues(alpha: 0.9));
      if (g.loculiSlab[i]) {
        canvas.drawRect(
          r.deflate(2.5),
          Paint()..color = _kCryptBone.withValues(alpha: 0.30),
        );
        canvas.drawLine(
          Offset(r.left + 5, r.center.dy),
          Offset(r.right - 5, r.center.dy),
          Paint()
            ..strokeWidth = 1
            ..color = _kCryptSeam.withValues(alpha: 0.4),
        );
      }
    }
    // Column stumps: broken at different heights, because a colonnade with
    // every drum the same height is a fence.
    for (var i = 0; i < g.columns.length; i++) {
      final c = g.columns[i];
      final h = g.columnH[i];
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(3, 4), width: 30, height: 15),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.28),
      );
      // The shaft, seen from above and slightly in front: a body plus a DRUM
      // TOP. Without the ellipse on top these were pale capsules standing on
      // the floor and read as bottles, not stone.
      canvas.drawRect(
        Rect.fromLTRB(c.dx - 13, c.dy - h, c.dx + 13, c.dy),
        Paint()..color = _kCryptStone.withValues(alpha: 0.50),
      );
      canvas.drawRect(
        Rect.fromLTRB(c.dx + 4, c.dy - h, c.dx + 13, c.dy),
        Paint()..color = _kCryptSeam.withValues(alpha: 0.22),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy - h), width: 26, height: 13),
        Paint()..color = _kCryptStoneCold.withValues(alpha: 0.85),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx, c.dy - h), width: 26, height: 13),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _kCryptBone.withValues(alpha: 0.22),
      );
      // Fluting, two strokes. Any more and the stumps went stripy.
      for (var k = -1; k <= 1; k += 2) {
        canvas.drawLine(
          Offset(c.dx + k * 6, c.dy - h + 8),
          Offset(c.dx + k * 6, c.dy - 3),
          Paint()
            ..strokeWidth = 1.2
            ..color = _kCryptSeam.withValues(alpha: 0.30),
        );
      }
    }
    // Fern clumps standing against the wall — the room's name, in the room.
    for (var i = 0; i < g.ferns.length; i++) {
      _drawFernClump(
        canvas,
        g.ferns[i],
        g.fernH[i] * (tiny ? 2.6 : 1.0),
        i * 1.31,
        t,
      );
    }
  }

  /// A fern: five fronds off one crown, leaning apart, swaying on one phase.
  void _drawFernClump(
    Canvas canvas,
    Offset at,
    double h,
    double phase,
    double t,
  ) {
    final sway = sin(t * 0.6 + phase) * (h * 0.05);
    for (var k = -2; k <= 2; k++) {
      final lean = k * 0.40;
      final hh = h * (1 - 0.13 * k.abs());
      final tip = Offset(at.dx + sin(lean) * hh * 0.62 + sway, at.dy - hh);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy)
          ..quadraticBezierTo(
            at.dx + sin(lean) * hh * 0.16,
            at.dy - hh * 0.6,
            tip.dx,
            tip.dy,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = max(1.4, h * 0.045)
          ..color = _kCryptGreen.withValues(alpha: h > 52 ? 0.40 : 0.52),
      );
      if (h > 52) {
        // Pinnae, but only when the frond is big enough for them to read.
        for (var p = 1; p <= 3; p++) {
          final u = p / 4;
          final on = Offset.lerp(at, tip, u)!;
          canvas.drawLine(
            on,
            on + Offset(-8.0 - u * 6, -5),
            Paint()
              ..strokeWidth = 1.6
              ..color = _kCryptGreen.withValues(alpha: 0.36),
          );
          canvas.drawLine(
            on,
            on + Offset(8.0 + u * 6, -5),
            Paint()
              ..strokeWidth = 1.6
              ..color = _kCryptGreen.withValues(alpha: 0.36),
          );
        }
      }
    }
  }

  /// What makes each room ITSELF rather than another lot of paving: the stair
  /// that gives the pollen stair its name, the reeds round the islet, the
  /// nave's chancel step, the arena's ring of root.
  void _renderCryptFixtures(
    Canvas canvas,
    DungeonRoom room,
    _CryptGround g,
    bool tiny,
    double t,
  ) {
    final b = room.bounds.deflate(10);

    // THE BROKEN TREAD. A flight of steps really crossing the floor, one of
    // them gone — which is the span the layout calls 'one step down, or a
    // cliff', so it had better be a step you can see.
    for (var i = 0; i < g.treads.length; i++) {
      final r = g.treads[i];
      if (g.treadBroken[i]) {
        // Rubble where the tread was: the riser behind it, and the pieces.
        canvas.drawRect(
          r,
          Paint()..color = _kCryptSeam.withValues(alpha: 0.62),
        );
        for (var k = 0; k < 4; k++) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(r.left + r.width * (0.2 + k * 0.22), r.center.dy),
              width: 16.0 + k * 5,
              height: 11.0 + (k % 2) * 5,
            ),
            Paint()..color = _kCryptStone.withValues(alpha: 0.45),
          );
        }
        continue;
      }
      canvas.drawRect(
        r.translate(0, 6),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.34),
      );
      canvas.drawRect(
        r,
        Paint()
          ..color = Color.lerp(
            _kCryptStoneCold,
            _kCryptStone,
            0.30,
          )!.withValues(alpha: 0.80),
      );
      // RISER then NOSING. A flight seen from above is a stack of identical
      // bars and nothing else — the descent only appears when each tread has
      // a dark vertical face at its back and a lit lip at its front. Pale and
      // half-transparent (the first attempt) the whole flight read as fog
      // lying on the floor, so the stone here is nearly opaque.
      canvas.drawRect(
        Rect.fromLTRB(r.left, r.top, r.right, r.top + 11),
        Paint()..color = _kCryptSeam.withValues(alpha: 0.72),
      );
      canvas.drawRect(
        Rect.fromLTRB(r.left, r.bottom - 4, r.right, r.bottom),
        Paint()..color = _kCryptBone.withValues(alpha: 0.22),
      );
    }

    // REEDS round the islet's shore, leaning off the water.
    for (var i = 0; i < g.reeds.length; i++) {
      final c = g.reeds[i];
      final sway = sin(t * 0.9 + i * 1.6) * 4;
      final h = (tiny ? 46.0 : 22.0) + (i % 3) * 7;
      canvas.drawLine(
        c,
        c + Offset(sway, -h),
        Paint()
          ..strokeWidth = tiny ? 3 : 1.6
          ..strokeCap = StrokeCap.round
          ..color = _kCryptGreen.withValues(alpha: 0.48),
      );
      canvas.drawCircle(
        c + Offset(sway, -h - 2),
        tiny ? 3.4 : 2.0,
        Paint()..color = const Color(0xFF8A7A42).withValues(alpha: 0.55),
      );
    }

    // THE CHANCEL STEP, in the bloom hall: a raised sanctuary platform across
    // the far end, with the rood line where the screen stands.
    if (_cryptHas(room.id, 'chancel')) {
      final step = Rect.fromLTRB(b.left, b.bottom - 118, b.right, b.bottom);
      canvas.drawRect(
        step,
        Paint()..color = _kCryptStone.withValues(alpha: 0.30),
      );
      canvas.drawRect(
        Rect.fromLTRB(step.left, step.top, step.right, step.top + 6),
        Paint()..color = _kCryptBone.withValues(alpha: 0.13),
      );
      canvas.drawRect(
        Rect.fromLTRB(step.left, step.top + 7, step.right, step.top + 13),
        Paint()..color = _kCryptSeam.withValues(alpha: 0.40),
      );
    }

    // Fallen petals, only in the arena. They lie where the flower dropped
    // them — banked at the edges, thinning inward, never scattered evenly.
    // The buttress roots that bank the arena are ordinary crypt roots at
    // eight times the scale and are drawn with the rest of them.
    for (var i = 0; i < g.petals.length; i++) {
      final c = g.petals[i];
      final a = i * 0.7;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 42, height: 17),
        Paint()..color = const Color(0xFFB9738F).withValues(alpha: 0.26),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -2), width: 30, height: 8),
        Paint()..color = const Color(0xFFE8A8BE).withValues(alpha: 0.14),
      );
      canvas.restore();
    }

    // The crypt's three obstacles, each drawn as itself.
    for (final w in room.walls) {
      switch (room.id) {
        case 'fern_gallery':
          _drawRootButtress(canvas, w, tiny);
        case 'lantern_court':
          _drawFallenCatafalque(canvas, w, tiny);
        default:
          _drawToppledLintel(canvas, w, tiny);
      }
    }
  }

  // ── THE THREE OBSTACLES ──────────────────────────────────
  //
  // The engine used to lay a generic blue-grey bar over every `room.walls`
  // rect, so a toppled lintel, a buttress of giant root and a fallen
  // catafalque all arrived on screen as the same object; this render drew a
  // mass UNDER the bar to give it a body. Now that the shared renderer skips
  // a planet's claimed rects, nothing is drawn over these at all — and
  // nothing was carrying their DEPTH either. The bar was generic but it was
  // doing real work: a cast shadow, a lit upper face and a dark foot. Without
  // those, a claimed rect reads as a flat panel lying on the carpet, which is
  // exactly what the lintel became.
  //
  // So each object now carries its own solidity, by the same three cues, in
  // the crypt's own palette — and since they are finally allowed to be three
  // objects, they are three different objects. All of it is world-size
  // geometry, so it reads at both scales without a branch: at tiny these are
  // cliffs, and the shadow and the lit face only get more emphatic.

  /// What puts a thing ON the floor rather than IN it, drawn before its body.
  ///
  /// A single cast shadow was not enough. The crypt's floor is already dark,
  /// so black at half alpha over it is barely a change of tone and the object
  /// went on reading as a differently-coloured slab. Two things fix it, and
  /// both are here: a TWO-STAGE contact shadow (a wide faint pool and a tight
  /// dark one — no blur filter anywhere, two alphas do the same work), and a
  /// NEAR FACE, a band of the object's own thickness that projects below the
  /// collision rect. The near face is the cue that actually lands: a block
  /// with no visible side has no height, whatever its shading says.
  ///
  /// The light is up and behind the camera, which is where the ledger stones,
  /// the wall course and the column stumps already put it. Nothing in a room
  /// may disagree about that; one object lit from elsewhere flattens the lot.
  void _cryptFooting(
    Canvas canvas,
    Rect w,
    bool tiny, {
    required double radius,
    required Color nearFace,
  }) {
    final lift = tiny ? 11.0 : 7.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        w.translate(lift * 0.5, lift * 1.4).inflate(7),
        Radius.circular(radius + 6),
      ),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.24),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        w.translate(lift * 0.35, lift).inflate(1.5),
        Radius.circular(radius),
      ),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.60),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          w.left,
          w.bottom - w.height * 0.30,
          w.right,
          w.bottom + lift * 0.85,
        ),
        Radius.circular(radius),
      ),
      Paint()..color = nearFace,
    );
  }

  /// A block's body: lit across its SHORT axis, because that is the axis a
  /// solid turns through. A long beam is lit top to bottom; a standing column
  /// is lit side to side. Getting this backwards is what makes a 3D object
  /// look like a printed rectangle.
  Paint _cryptSolid(Rect w, List<Color> ramp) {
    final horizontal = w.width >= w.height;
    return Paint()
      ..shader = ui.Gradient.linear(
        horizontal ? w.topCenter : w.centerLeft,
        horizontal ? w.bottomCenter : w.centerRight,
        ramp,
        const [0.0, 0.52, 1.0],
      );
  }

  /// THE TOPPLED LINTEL, over the root porch's gate. A carved beam that came
  /// off the arch: squared, moulded down its length, and broken at both ends
  /// — it did not arrive here cut, it arrived here falling.
  void _drawToppledLintel(Canvas canvas, Rect w, bool tiny) {
    // THE SILHOUETTE IS BROKEN, not the surface. Painting fracture wedges on
    // a clean rounded rectangle did nothing at all — the outline is what the
    // eye reads first, so the beam's own outline steps in at both ends. The
    // bite is ≤12px on a 170px beam, inside the slack the engine's rounded
    // corners already had, so it never asks you to collide with air.
    const bite = 17.0;
    final body = Path()
      ..moveTo(w.left + bite, w.top)
      ..lineTo(w.right - bite, w.top)
      ..lineTo(w.right - bite * 0.45, w.top + w.height * 0.34)
      ..lineTo(w.right, w.top + w.height * 0.52)
      ..lineTo(w.right - bite * 0.8, w.bottom)
      ..lineTo(w.left + bite * 0.55, w.bottom)
      ..lineTo(w.left, w.top + w.height * 0.58)
      ..lineTo(w.left + bite * 0.5, w.top + w.height * 0.28)
      ..close();
    _cryptFooting(
      canvas,
      w.deflate(2),
      tiny,
      radius: 3,
      nearFace: const Color(0xFF262A1C),
    );
    // The ramp tops out at the wall course's own lightest block. Pale stone
    // on a dark floor popped out of the room like a UI element — an obstacle
    // has to be solid, not luminous.
    canvas.drawPath(
      body,
      _cryptSolid(w, const [
        Color(0xFF6F6A54),
        Color(0xFF43452F),
        Color(0xFF171B11),
      ]),
    );
    canvas.save();
    canvas.clipPath(body);
    // The top face. A WIDE bright band turned the beam into a chrome pipe —
    // a weathered lintel catches the light along a narrow crown and nowhere
    // else, and everything below it is in its own shade.
    canvas.drawRect(
      Rect.fromLTRB(w.left, w.top + 1.5, w.right, w.top + w.height * 0.18),
      Paint()..color = _kCryptBone.withValues(alpha: 0.11),
    );
    // Tooling and weathering: chisel marks across the crown and a few pits.
    // A perfectly smooth body is the other half of why it read as a pipe.
    for (var i = 0; i < 11; i++) {
      final x = w.left + w.width * ((i * 0.091) + 0.05);
      canvas.drawLine(
        Offset(x, w.top + 3),
        Offset(x + 2, w.top + w.height * (0.22 + (i % 3) * 0.06)),
        Paint()
          ..strokeWidth = 1.1
          ..color = _kCryptSeam.withValues(alpha: 0.22),
      );
    }
    // Lichen on the crown — the garden is eating this too, and it is what
    // stops the beam looking like a machined part dropped into a crypt.
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            w.left + w.width * (0.24 + i * 0.27),
            w.top + w.height * (0.26 + (i % 2) * 0.18),
          ),
          width: 26.0 + i * 9,
          height: w.height * 0.34,
        ),
        Paint()..color = _kCryptMoss.withValues(alpha: 0.26),
      );
    }
    canvas.restore();
    // The foot: the dark band where the beam meets the floor, and the single
    // strongest cue that it is standing ON something.
    canvas.drawRect(
      Rect.fromLTRB(w.left, w.bottom - w.height * 0.20, w.right, w.bottom),
      Paint()..color = _kCryptSeam.withValues(alpha: 0.55),
    );
    // The moulding — two fillets running the length. A lintel without them is
    // a kerbstone.
    for (final u in [0.40, 0.56]) {
      canvas.drawRect(
        Rect.fromLTRB(
          w.left + 7,
          w.top + w.height * u,
          w.right - 7,
          w.top + w.height * u + 2,
        ),
        Paint()..color = _kCryptSeam.withValues(alpha: 0.38),
      );
    }
    // The fracture faces. Raw stone is LIGHTER than the lichened outside, not
    // darker — painted near-black (the first attempt) the breaks disappeared
    // into the room behind them and both ends read as a clean bevel.
    for (final left in [true, false]) {
      final x = left ? w.left + bite * 0.5 : w.right - bite * 0.45;
      final s = left ? 1.0 : -1.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, w.top + w.height * 0.28)
          ..lineTo(x + s * 10, w.top + 1)
          ..lineTo(x + s * 10, w.bottom - 1)
          ..lineTo(x - s * 2, w.bottom - w.height * 0.2)
          ..close(),
        Paint()..color = const Color(0xFF8E8871).withValues(alpha: 0.45),
      );
      canvas.drawLine(
        Offset(x, w.top + w.height * 0.28),
        Offset(x - s * 2, w.bottom - w.height * 0.2),
        Paint()
          ..strokeWidth = 1.4
          ..color = _kCryptSeam.withValues(alpha: 0.6),
      );
    }
    // And a split across it, a third of the way along — it is broken, not old.
    final sx = w.left + w.width * 0.36;
    canvas.drawPath(
      Path()
        ..moveTo(sx, w.top)
        ..lineTo(sx + 5, w.center.dy)
        ..lineTo(sx - 3, w.bottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tiny ? 4 : 2
        ..color = _kCryptSeam.withValues(alpha: 0.7),
    );
  }

  /// THE BUTTRESS OF GIANT ROOT, in the fern gallery. Not masonry at all: a
  /// living wall, round in section, with bark grain down its length and
  /// rootlets splaying where it meets the floor. Its silhouette is allowed to
  /// be softer than its hitbox — it is the one obstacle here that grew.
  void _drawRootButtress(Canvas canvas, Rect w, bool tiny) {
    final body = RRect.fromRectAndRadius(
      w,
      Radius.circular(w.shortestSide * 0.48),
    );
    _cryptFooting(
      canvas,
      w,
      tiny,
      radius: w.shortestSide * 0.48,
      nearFace: const Color(0xFF261B0E),
    );
    // Rootlets first, so they read as going UNDER the buttress rather than
    // being stuck on its face.
    for (var k = 0; k < 6; k++) {
      final u = 0.12 + k * 0.15;
      final at = Offset(
        w.center.dx + (k.isEven ? -1 : 1) * w.width * 0.4,
        w.top + w.height * u,
      );
      canvas.drawLine(
        at,
        at + Offset((k.isEven ? -1 : 1) * (16.0 + k * 5), 9.0 - k * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = tiny ? 5 : 3
          ..color = const Color(0xFF2A1D10).withValues(alpha: 0.85),
      );
    }
    canvas.drawRRect(
      body,
      // Kept in the same family as the roots running over the floor, so the
      // buttress reads as one of them stood on end rather than as timber.
      _cryptSolid(w, const [
        Color(0xFF6E5233),
        Color(0xFF3C2B1B),
        Color(0xFF150D06),
      ]),
    );
    // The lit cap at the top end: light comes from above in these rooms, and
    // a column lit only across its width has no top.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w.left, w.top, w.width, w.height * 0.13),
        Radius.circular(w.shortestSide * 0.45),
      ),
      Paint()..color = const Color(0xFF9A7846).withValues(alpha: 0.34),
    );
    // Bark grain, none of it straight and none of it evenly spaced — four
    // lines on an even pitch is corduroy, which is what this first was.
    const pitch = [0.17, 0.33, 0.41, 0.62, 0.79];
    for (var k = 0; k < pitch.length; k++) {
      final x = w.left + w.width * pitch[k];
      canvas.drawPath(
        Path()
          ..moveTo(x, w.top + 6)
          ..quadraticBezierTo(
            x + (k.isEven ? 5 : -6),
            w.center.dy,
            x + (k.isEven ? -2 : 3),
            w.bottom - 6,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = tiny ? 3 : 1.6
          ..color = const Color(0xFF17100A).withValues(alpha: 0.55),
      );
    }
    // Two knots, at different heights and sizes. A dark ring round a LIGHTER
    // middle drew two doughnuts — a knot is a raised boss, so it is a filled
    // swelling with the shadow only under its lower edge.
    for (final k in [0.31, 0.68]) {
      final c = Offset(w.center.dx + (k < 0.5 ? -5 : 6), w.top + w.height * k);
      final r = w.width * (k < 0.5 ? 0.20 : 0.15);
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(1, 2),
          width: r * 2.1,
          height: r * 2.7,
        ),
        Paint()..color = const Color(0xFF150D06).withValues(alpha: 0.8),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2, height: r * 2.6),
        Paint()..color = const Color(0xFF6B4F30).withValues(alpha: 0.95),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, -r * 0.3),
          width: r * 0.8,
          height: r * 0.9,
        ),
        Paint()..color = const Color(0xFF33220F).withValues(alpha: 0.75),
      );
    }
    // The foot, where it goes into the floor.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w.left, w.bottom - w.height * 0.08, w.right, w.bottom),
        Radius.circular(w.shortestSide * 0.4),
      ),
      Paint()..color = _kCryptSeam.withValues(alpha: 0.45),
    );
  }

  /// THE FALLEN CATAFALQUE, in the lantern court. The bier the crypt's dead
  /// were laid on: an arcaded stone chest with a lid — and the lid has SLID,
  /// which is the whole word "fallen". Drawn slipped off its plinth rather
  /// than tilted, so the silhouette still owns the rect the party walks round.
  void _drawFallenCatafalque(Canvas canvas, Rect w, bool tiny) {
    final chest = RRect.fromRectAndRadius(w, const Radius.circular(3));
    _cryptFooting(
      canvas,
      w,
      tiny,
      radius: 3,
      nearFace: const Color(0xFF262A1C),
    );
    canvas.drawRRect(
      chest,
      _cryptSolid(w, const [
        Color(0xFF6E6A54),
        Color(0xFF464837),
        Color(0xFF191D14),
      ]),
    );
    // THE ARCADED FACE, in the LOWER half of the chest. Put across the whole
    // height it vanished under the lid and the catafalque read as a second
    // toppled lintel; the plinth showing below the lid is what says "chest".
    final face = Rect.fromLTRB(
      w.left + 4,
      w.top + w.height * 0.52,
      w.right - 4,
      w.bottom - w.height * 0.12,
    );
    canvas.drawRect(
      face,
      Paint()..color = const Color(0xFF2E3226).withValues(alpha: 0.55),
    );
    final bays = (w.width / 30).clamp(3, 9).toInt();
    for (var i = 0; i < bays; i++) {
      final cx = face.left + face.width * (i + 0.5) / bays;
      final bw = face.width / bays * (0.56 + (i % 3) * 0.08);
      final arch = Rect.fromCenter(
        center: Offset(cx, face.bottom - face.height * 0.16),
        width: bw,
        height: face.height * 1.5,
      );
      final ink = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _kCryptBone.withValues(alpha: 0.14);
      canvas.save();
      canvas.clipRect(face);
      canvas.drawArc(arch, pi, pi, false, ink);
      canvas.drawLine(
        Offset(arch.left, arch.center.dy),
        Offset(arch.left, face.bottom),
        ink,
      );
      canvas.drawLine(
        Offset(arch.right, arch.center.dy),
        Offset(arch.right, face.bottom),
        ink,
      );
      canvas.restore();
    }
    // The foot.
    canvas.drawRect(
      Rect.fromLTRB(w.left, w.bottom - w.height * 0.12, w.right, w.bottom),
      Paint()..color = _kCryptSeam.withValues(alpha: 0.60),
    );
    // THE LID, slid off its plinth and turned a couple of degrees, sitting
    // high on the chest so the arcade below it stays visible. A chest with
    // its lid square on it is furniture; this is a grave that was opened.
    canvas.save();
    canvas.translate(w.center.dx, w.top + w.height * 0.26);
    canvas.rotate(0.045);
    final lid = Rect.fromCenter(
      center: const Offset(19, 0),
      width: w.width * 0.86,
      height: w.height * 0.50,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lid.translate(3, 7), const Radius.circular(3)),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.46),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lid, const Radius.circular(3)),
      Paint()
        ..shader = ui.Gradient.linear(
          lid.topCenter,
          lid.bottomCenter,
          const [Color(0xFF7E7961), Color(0xFF4E5040), Color(0xFF20241A)],
          const [0.0, 0.5, 1.0],
        ),
    );
    // The chamfer round the lid's top face.
    canvas.drawRect(
      Rect.fromLTRB(lid.left + 4, lid.top + 2, lid.right - 4, lid.top + 5),
      Paint()..color = _kCryptBone.withValues(alpha: 0.13),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lid.deflate(5), const Radius.circular(2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _kCryptSeam.withValues(alpha: 0.45),
    );
    // A corner broken off the lid, where it struck the floor — the raw stone
    // inside, lighter than the lichened face, as at the lintel's ends.
    canvas.drawPath(
      Path()
        ..moveTo(lid.right, lid.top)
        ..lineTo(lid.right - 24, lid.top)
        ..lineTo(lid.right - 9, lid.center.dy)
        ..lineTo(lid.right, lid.center.dy + 2)
        ..close(),
      Paint()..color = const Color(0xFF8E8871).withValues(alpha: 0.38),
    );
    // Lichen creeping over the slab, as on the lintel.
    for (var i = 0; i < 2; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            lid.left + lid.width * (0.28 + i * 0.34),
            lid.top + lid.height * (0.42 + i * 0.20),
          ),
          width: 30.0 + i * 12,
          height: lid.height * 0.40,
        ),
        Paint()..color = _kCryptMoss.withValues(alpha: 0.24),
      );
    }
    canvas.restore();
  }

  /// INSIDE THE SEED. The gourd hollow is the vault — the pocket behind the
  /// little door in the altar's rim — and it is not masonry at all: it is the
  /// inside of a dried seed-case, which is why a body has to be small to be
  /// in here.
  void _renderGourdShell(
    Canvas canvas,
    DungeonRoom room,
    _CryptGround g,
    bool tiny,
    double t,
  ) {
    final b = room.bounds.deflate(12);
    final shell = Rect.fromCenter(
      center: b.center,
      width: b.width,
      height: b.height,
    );
    // The corners of the room are inside the husk too — without this the
    // gourd floated on a square of the generic stage tint.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        room.bounds.deflate(8),
        const Radius.circular(30),
      ),
      Paint()..color = const Color(0xFF1B1408).withValues(alpha: 0.60),
    );
    // The case has THICKNESS: an outer husk, a shadowed inner face, and the
    // pith floor. Drawn as two flat ovals it was a barrel lid.
    canvas.drawOval(
      shell,
      Paint()..color = const Color(0xFF3A2C14).withValues(alpha: 0.62),
    );
    canvas.drawOval(
      shell.deflate(10),
      Paint()..color = const Color(0xFF8A7038).withValues(alpha: 0.50),
    );
    canvas.drawOval(
      shell.deflate(26),
      Paint()..color = const Color(0xFF241A0B).withValues(alpha: 0.40),
    );
    canvas.drawOval(
      shell.deflate(34),
      Paint()..color = const Color(0xFF6E5A2E).withValues(alpha: 0.45),
    );
    // Ribs of the case, bellying out toward the middle as a seed-case does.
    for (var i = 0; i < g.ribs.length; i++) {
      canvas.drawPath(
        g.ribs[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFF2E2210).withValues(alpha: 0.42),
      );
    }
    // The pith: dry fibre lying in the bottom of the case. Each patch runs
    // ONE way, in parallel strands — radiating them from a centre (the first
    // attempt) drew a row of asterisks, which is the last thing a heap of dry
    // fibre looks like.
    for (var i = 0; i < g.moss.length; i++) {
      final c = g.mossCentre[i];
      final a = (i * 1.7) % pi;
      final dir = Offset(cos(a), sin(a));
      final nrm = Offset(-dir.dy, dir.dx);
      for (var k = -2; k <= 2; k++) {
        final len = 26.0 - (k.abs() * 5) + (i % 3) * 5;
        final at = c + nrm * (k * 5.0);
        canvas.drawLine(
          at - dir * len,
          at + dir * len,
          Paint()
            ..strokeWidth = 1.5
            ..color = const Color(0xFFC8B87E).withValues(alpha: 0.14),
        );
      }
    }
    // THE WAY IN. The only light in here comes through the little door cut in
    // the altar's rim — the door a body has to be small to use — so it falls
    // in a wedge off that wall and says, without a word, how you got here.
    for (final d in room.doors) {
      final from = d.rect.center;
      final into = Offset.lerp(from, b.center, 0.62)!;
      final perp = Offset(-(into.dy - from.dy), into.dx - from.dx);
      final pl = perp.distance == 0 ? 1.0 : perp.distance;
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(into.dx + perp.dx / pl * 54, into.dy + perp.dy / pl * 54)
          ..lineTo(into.dx - perp.dx / pl * 54, into.dy - perp.dy / pl * 54)
          ..close(),
        Paint()..color = const Color(0xFFF2E3A8).withValues(alpha: 0.07),
      );
    }
    // Husk flakes off the shell, banked where they fell.
    for (var i = 0; i < g.ferns.length && i < 9; i++) {
      final c = g.ferns[i];
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * 0.9);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 7),
        Paint()..color = const Color(0xFF4A3A1A).withValues(alpha: 0.45),
      );
      canvas.restore();
    }
    // Loose seeds, each with its own shine. They breathe very slightly —
    // this room is the only place in the crypt with nothing else moving.
    for (var i = 0; i < g.seeds.length; i++) {
      final c = g.seeds[i];
      final r = 7.0 + (i % 4) * 2.5 + sin(t * 0.8 + i) * 0.6;
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(1, 3),
          width: r * 2,
          height: r * 1.5,
        ),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.25),
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2, height: r * 1.5),
        Paint()..color = const Color(0xFFD8C384).withValues(alpha: 0.60),
      );
      canvas.drawCircle(
        c.translate(-r * 0.3, -r * 0.3),
        r * 0.25,
        Paint()..color = _kCryptBone.withValues(alpha: 0.40),
      );
    }
  }

  /// The room's ground, built once. Keyed by room id — every room in the
  /// crypt has its own bounds, and the shapes are derived from those bounds,
  /// so a room looks the same every time you walk into it and no two rooms
  /// look alike.
  _CryptGround _cryptGround(DungeonRoom room) =>
      _cryptGroundCache.putIfAbsent(room.id, () => _buildCryptGround(room));

  /// A size glyph at every passage the room can see: a low flat bar for a way
  /// only a small body takes, a tall arch for one only a big body takes. The
  /// bar is drawn in the party's own colour when it fits and in bone when it
  /// does not, so "wrong size" is legible before you walk into it.
  void _renderCryptSpans(Canvas canvas, DungeonRoom room) {
    for (final d in room.doors) {
      if (isDoorHidden(room, d)) continue;
      final span = cryptSpanBetween(room.id, d.targetRoomId);
      if (span == null || span.size == SpanSize.both) continue;
      final fits = crypt.spanFits(span, crypt.scale);
      final c = fits ? _kCryptGreen : _kCryptBone.withValues(alpha: 0.5);
      final at = d.rect.center;
      final paint = Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = fits ? 3.5 : 2;
      if (span.size == SpanSize.tinyOnly) {
        canvas.drawLine(
          at + const Offset(-16, 8),
          at + const Offset(16, 8),
          paint,
        );
        canvas.drawLine(
          at + const Offset(-10, 2),
          at + const Offset(10, 2),
          paint,
        );
      } else {
        final r = Rect.fromCenter(center: at, width: 30, height: 40);
        canvas.drawArc(r, pi, pi, false, paint);
        canvas.drawLine(
          Offset(r.left, r.center.dy),
          Offset(r.left, r.bottom),
          paint,
        );
        canvas.drawLine(
          Offset(r.right, r.center.dy),
          Offset(r.right, r.bottom),
          paint,
        );
      }
    }
  }

  void _renderCryptBeds(Canvas canvas, DungeonRoom room) {
    for (final b in cryptBedsIn(room.id)) {
      final at = b.crown;
      switch (crypt.stateOf(b.id)) {
        case VineState.bare:
          // A dark split with loose soil banked either side.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: at, width: 96, height: 26),
              const Radius.circular(10),
            ),
            Paint()..color = _kCryptDeep.withValues(alpha: 0.6),
          );
          canvas.drawRect(
            Rect.fromCenter(center: at, width: 12, height: 40),
            Paint()..color = const Color(0xFF120E09),
          );
        case VineState.creeper:
          // ONE hairline filament with leaf nodes — nothing at your own size.
          final line = Paint()
            ..color = _kCryptGreen
            ..style = PaintingStyle.stroke
            ..strokeWidth = crypt.isTiny ? 5 : 1.6;
          final path = Path()..moveTo(at.dx - 60, at.dy + 10);
          for (var i = 1; i <= 4; i++) {
            path.quadraticBezierTo(
              at.dx - 60 + 30 * i - 15,
              at.dy + (i.isEven ? -14 : 20),
              at.dx - 60 + 30 * i,
              at.dy + 10,
            );
          }
          canvas.drawPath(path, line);
          for (var i = 0; i <= 4; i++) {
            canvas.drawCircle(
              Offset(at.dx - 60 + 30 * i, at.dy + 10),
              crypt.isTiny ? 6 : 2.6,
              Paint()..color = _kCryptGreen,
            );
          }
        case VineState.trunk:
          // A broad barked column, with a crown of leaf where it goes up.
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: at, width: 56, height: 120),
              const Radius.circular(12),
            ),
            Paint()..color = _kCryptBark,
          );
          final grain = Paint()
            ..color = const Color(0xFF3F2C1B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          for (var i = -1; i <= 1; i++) {
            canvas.drawLine(
              Offset(at.dx + i * 16, at.dy - 54),
              Offset(at.dx + i * 16, at.dy + 54),
              grain,
            );
          }
          canvas.drawCircle(
            at - const Offset(0, 74),
            34,
            Paint()..color = _kCryptGreen.withValues(alpha: 0.75),
          );
      }
    }
  }

  void _renderCryptObjects(Canvas canvas, DungeonRoom room) {
    final g = room.grove;
    if (g == null) return;

    // The briar over the lich-gate, while it still holds.
    final briar = g.briarGate;
    if (briar != null && !entryDoorRevealed) {
      final p = Paint()
        ..color = const Color(0xFF6E5A3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(
          briar + Offset(-40.0 + i * 20, -46),
          briar + Offset(40.0 - i * 20, 46),
          p,
        );
      }
    }

    // A seed-gall: a hollow swelling on the root, breathing.
    final gall = g.bole ?? g.rootBole;
    if (gall != null) {
      canvas.drawCircle(gall, 30, Paint()..color = _kCryptBark);
      canvas.drawCircle(
        gall,
        18,
        Paint()..color = _kCryptGreen.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        gall,
        crypt.isTiny ? 7 : 11,
        Paint()..color = _kCryptDeep,
      );
    }

    // The mulch pit: a low heap of leaf-litter, warmer when it is armed.
    final pit = g.mulchPit;
    if (pit != null) {
      final armed = crypt.armedPitRoom == room.id && crypt.armedPitTimer > 0;
      canvas.drawOval(
        Rect.fromCenter(center: pit, width: 74, height: 34),
        Paint()
          ..color = (armed ? const Color(0xFF9A6A2E) : const Color(0xFF4A3A22)),
      );
      final leaf = Paint()
        ..color = const Color(0xFF7C6A3E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (var i = -1; i <= 1; i++) {
        canvas.drawLine(
          pit + Offset(i * 20.0, -8),
          pit + Offset(i * 20.0 + 10, 8),
          leaf,
        );
      }
    }

    // The grave-lamp.
    final lamp = _lampIn(room);
    if (lamp != null) {
      final lit = crypt.lampsLit.contains(lamp.id);
      final tall = lamp.reach == PlantScale.huge;
      final body = Rect.fromCenter(
        center: lamp.position,
        width: tall ? 34 : 16,
        height: tall ? 52 : 22,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(6)),
        Paint()..color = _kCryptBone.withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        lamp.position - Offset(0, tall ? 16 : 6),
        tall ? 10 : 5,
        Paint()..color = lit ? _kCryptLamp : _kCryptDeep.withValues(alpha: 0.8),
      );
      if (lit) {
        canvas.drawCircle(
          lamp.position - Offset(0, tall ? 16 : 6),
          tall ? 22 : 12,
          Paint()..color = _kCryptLamp.withValues(alpha: 0.2),
        );
      }
    }

    // The growth altar, and the little door cut in its rim (§5.5's vault
    // trick: plain to see from up here, and a hand high).
    final altar = g.growthAltar;
    if (altar != null) {
      final bowl = Rect.fromCenter(
        center: altar,
        width: crypt.isTiny ? 320 : 130,
        height: crypt.isTiny ? 190 : 78,
      );
      canvas.drawOval(
        bowl,
        Paint()..color = _kCryptBone.withValues(alpha: 0.5),
      );
      canvas.drawOval(
        bowl.deflate(crypt.isTiny ? 26 : 12),
        Paint()
          ..color = crypt.bloomStep >= 1
              ? const Color(0xFF4A3A22)
              : _kCryptDeep.withValues(alpha: 0.6),
      );
      if (crypt.bloomStep >= 2) {
        canvas.drawCircle(
          altar,
          crypt.bloomWoken ? 26 : 9,
          Paint()..color = crypt.bloomWoken ? _kCryptLamp : _kCryptGreen,
        );
      }
      // The rim door.
      canvas.drawRect(
        Rect.fromLTWH(bowl.right - 14, bowl.center.dy - 9, 14, 18),
        Paint()..color = _kCryptDeep,
      );
    }

    // The sepulchre's baked clay.
    final tomb = g.sepulchre;
    if (tomb != null) {
      final sealed = (conduitEnergy['B'] ?? 0) <= 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: tomb, width: 130, height: 62),
          const Radius.circular(8),
        ),
        Paint()
          ..color = sealed
              ? const Color(0xFF8C7A5C)
              : _kCryptDeep.withValues(alpha: 0.85),
      );
      if (sealed) {
        final crack = Paint()
          ..color = const Color(0xFF5B4A32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawLine(
          tomb + const Offset(-40, -10),
          tomb + const Offset(10, 14),
          crack,
        );
      }
    }

    // The seed nobody planted — only a body small enough to be under the root
    // ever sees it (the Lost Maxim), and what it became is only visible from
    // your own size.
    final shade = g.shadeSeed;
    if (shade != null) {
      if (crypt.shadeRisen && !crypt.isTiny) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: shade + const Offset(0, -40),
              width: 40,
              height: 180,
            ),
            const Radius.circular(10),
          ),
          Paint()..color = _kCryptBark,
        );
        canvas.drawCircle(
          shade - const Offset(0, 150),
          72,
          Paint()..color = _kCryptGreen.withValues(alpha: 0.7),
        );
      } else if (crypt.isTiny && !crypt.shadeRisen) {
        canvas.drawCircle(shade, 10, Paint()..color = const Color(0xFF9CB47A));
        canvas.drawCircle(
          shade,
          10 + 4.0 * crypt.tendedBy.length,
          Paint()
            ..color = _kCryptGreen.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────
// THE GROUND, BUILT ONCE
// ─────────────────────────────────────────────────────────

/// One room's crypt floor and architecture, in world coordinates.
///
/// EVERYTHING IRREGULAR IN THE CRYPT LIVES HERE, and it is laid out exactly
/// once per room rather than re-derived sixty times a second. What the render
/// does per frame is fills and strokes over these lists plus three phases (a
/// fern sway, a sheen on water, a drift of spores) — no allocation that grows
/// with the party, the enemies or the puzzle state.
class _CryptGround {
  /// Grave slabs. Never a grid: they come out of a recursive split of the
  /// room with random fractions and a random stopping size, then every corner
  /// is jittered, so no two are the same shape and none of them line up.
  final List<Path> slabs = [];
  final List<double> slabTone = [];

  /// The joints between them — the crypt's SMALL graph. A hairline at your
  /// own size and a ravine at the other; one set of lines, two readings.
  final List<Path> seams = [];
  final List<double> seamWidth = [];

  /// Worn epitaphs: a few strokes of a name, on a few slabs.
  final List<Offset> carvings = [];
  final List<double> carvingAngle = [];
  final List<double> carvingLen = [];

  /// Dew in the low spots — beads up here, standing water down there.
  final List<Offset> seeps = [];
  final List<double> seepR = [];

  /// Moss blotches: a stain, or a canopy.
  final List<Path> moss = [];
  final List<Offset> mossCentre = [];
  final List<double> mossR = [];

  /// The roots taking the building apart: a filled, TAPERED body (a root is
  /// not a beam), its lit crest, and its feeders.
  final List<Path> roots = [];
  final List<Path> rootCrests = [];
  final List<List<(Offset, Offset)>> rootlets = [];

  /// The wall course, its burial niches, its broken colonnade.
  final List<Rect> masonry = [];
  final List<double> masonryTone = [];
  final List<Rect> loculi = [];
  final List<bool> loculiSlab = [];
  final List<Offset> columns = [];
  final List<double> columnH = [];

  /// Fern clumps against the wall.
  final List<Offset> ferns = [];
  final List<double> fernH = [];

  /// The pollen stair's flight, and which tread is the broken one.
  final List<Rect> treads = [];
  final List<bool> treadBroken = [];

  /// The islet: the shore it stands on, and the reeds round it.
  Path shore = Path();
  final List<Offset> reeds = [];

  /// Botanica's arena: what the flower has dropped.
  final List<Offset> petals = [];

  /// The gourd hollow: the seed-case's ribs and what is loose inside it.
  final List<Path> ribs = [];
  final List<Offset> seeds = [];
}

/// Built grounds, by room id. Top-level and never cleared: the geometry is a
/// pure function of the room's own bounds, so it is correct for the life of
/// the process and a re-entry costs nothing.
final Map<String, _CryptGround> _cryptGroundCache = {};

/// What each room of the crypt IS, beyond its paving. Read by both the
/// builder and the render, so a room cannot grow reeds in one and not the
/// other.
const Map<String, Set<String>> _kCryptRoomTraits = {
  'root_porch': {'ferny'},
  'mosswalk': {'loculi', 'ferny'},
  'fern_gallery': {'giantroot', 'ferny'},
  'pollen_stair': {'stair'},
  'crypt_niche': {'loculi', 'tight'},
  'lantern_court': {'colonnade'},
  'islet': {'water'},
  'gourd_hollow': {'shell'},
  'bloom_hall': {'colonnade', 'chancel'},
  'botanica_heart': {'arena'},
};

bool _cryptHas(String roomId, String trait) =>
    _kCryptRoomTraits[roomId]?.contains(trait) ?? false;

/// A closed, ragged blob. Eight points round an ellipse, each pushed in or
/// out and joined with quadratics — nothing a garden makes has a clean edge.
Path _cryptBlob(
  Offset c,
  double rx,
  double ry,
  double Function() rnd, {
  double wobble = 0.3,
}) {
  const n = 8;
  final pts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final a = i / n * pi * 2;
    final k = 1 + (rnd() - 0.5) * 2 * wobble;
    pts.add(Offset(c.dx + cos(a) * rx * k, c.dy + sin(a) * ry * k));
  }
  final path = Path();
  final mid0 = Offset.lerp(pts[n - 1], pts[0], 0.5)!;
  path.moveTo(mid0.dx, mid0.dy);
  for (var i = 0; i < n; i++) {
    final cur = pts[i];
    final mid = Offset.lerp(cur, pts[(i + 1) % n], 0.5)!;
    path.quadraticBezierTo(cur.dx, cur.dy, mid.dx, mid.dy);
  }
  path.close();
  return path;
}

/// Lay out one room. Deterministic from the room's own bounds.
_CryptGround _buildCryptGround(DungeonRoom room) {
  final g = _CryptGround();
  final b = room.bounds.deflate(10);
  var seed = (room.bounds.width * 31 + room.bounds.height * 17).toInt() | 1;
  double rnd() {
    seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
    return (seed >> 8) / 0x3FFFFF;
  }

  final shell = _cryptHas(room.id, 'shell');
  final arena = _cryptHas(room.id, 'arena');
  final water = _cryptHas(room.id, 'water');

  // THE OPEN CENTRE. A guardian arena and a star room have to be walked and
  // fought in, so every standing thing this builder makes is rejected out of
  // the middle of the room and the detail is banked at the edges. Paving,
  // joints, moss and seeps are floor and go everywhere — they are what you
  // walk ON, not what you walk round.
  final open = Rect.fromCenter(
    center: b.center,
    width: b.width * (arena ? 0.58 : 0.44),
    height: b.height * (arena ? 0.56 : 0.42),
  );

  // Doors are holes in the wall course; a block laid across one reads as a
  // bricked-up doorway with a door drawn on top of it.
  final blocked = [for (final d in room.doors) d.rect.inflate(10)];
  bool clearOfDoors(Rect r) {
    for (final d in blocked) {
      if (r.overlaps(d)) return false;
    }
    return true;
  }

  // ── the seed-case: no paving, no masonry, nothing built ──
  if (shell) {
    final o = Rect.fromCenter(
      center: b.center,
      width: b.width - 32,
      height: b.height - 32,
    );
    for (var i = 0; i < 6; i++) {
      final u = 0.13 + 0.15 * i + (rnd() - 0.5) * 0.05;
      final x = o.left + o.width * u;
      // How far down the case this rib runs depends on how far it is from
      // the middle, so the ribs follow the belly instead of standing as a
      // set of parallel vertical lines (which read as barrel staves).
      final edge = (u - 0.5).abs() * 2;
      final dy = o.height * 0.5 * sqrt(max(0.0, 1 - edge * edge)) * 0.92;
      g.ribs.add(
        Path()
          ..moveTo(x, o.center.dy - dy)
          ..quadraticBezierTo(
            x + (x - o.center.dx) * 0.62,
            o.center.dy,
            x,
            o.center.dy + dy,
          ),
      );
    }
    for (var i = 0; i < 6; i++) {
      final c = Offset(
        o.left + 40 + rnd() * (o.width - 80),
        o.top + 34 + rnd() * (o.height - 68),
      );
      g.moss.add(_cryptBlob(c, 30 + rnd() * 44, 20 + rnd() * 26, rnd));
      g.mossCentre.add(c);
      g.mossR.add(16);
    }
    for (var i = 0; i < 11; i++) {
      final p = Offset(
        o.left + 34 + rnd() * (o.width - 68),
        o.top + 30 + rnd() * (o.height - 60),
      );
      // Leave a standing spot in the middle: this pocket is small and the
      // party arrives in it.
      if (i > 2 && (p - b.center).distance < 46) continue;
      g.seeds.add(p);
    }
    // Husk flakes, banked round the wall of the case (the shell branch of
    // the render borrows the fern list for them — there is no fern in here).
    for (var i = 0; i < 9; i++) {
      final a = rnd() * pi * 2;
      g.ferns.add(
        b.center +
            Offset(
              cos(a) * o.width * 0.5 * (0.62 + rnd() * 0.30),
              sin(a) * o.height * 0.5 * (0.62 + rnd() * 0.30),
            ),
      );
      g.fernH.add(0);
    }
    return g;
  }

  // ── the paving ───────────────────────────────────────────
  // A recursive split with random fractions and a random stopping size. This
  // is the anti-grid: a lattice of identical stones is the one thing a
  // funerary floor never is, and a regular lattice is this project's most
  // common render failure.
  // The paving stops well short of the wall, leaving a verge of grave soil
  // the course sits in. Run to the wall (as the first attempt did) and the
  // room has no edge at all: paving and masonry fuse into one quilt of stone
  // and the picture reads as a WALL seen face-on rather than a floor.
  final pave = water ? b.deflate(90) : b.deflate(46);
  final minArea = (pave.width * pave.height / 52).clamp(3400.0, 9000.0);

  // ROT PATCHES. A crypt eaten by a garden does not lose its paving evenly —
  // it loses it where the water sits and the roots came through. Slabs whose
  // centre falls in one of these go, so the floor is a run of stone with bare
  // earth opening through it rather than a continuous carpet.
  final rot = <(Offset, double)>[];
  for (var i = 0; i < 3 + (rnd() * 3).floor(); i++) {
    rot.add((
      Offset(pave.left + rnd() * pave.width, pave.top + rnd() * pave.height),
      50 + rnd() * 95,
    ));
  }
  bool rotten(Offset c) {
    for (final r in rot) {
      if ((c - r.$1).distance < r.$2) return rnd() < 0.72;
    }
    return false;
  }

  late void Function(Rect, int) split;
  split = (r, depth) {
    if (depth >= 6 || r.width * r.height < minArea * (0.55 + rnd())) {
      // A missing stone now and then: bare grave soil, and the reason the
      // floor never reads as a continuous surface.
      if (rnd() < 0.10 || rotten(r.center)) return;
      final inset = 2.5 + rnd() * 3.5;
      final q = r.deflate(inset);
      if (q.width < 8 || q.height < 8) return;
      double j() => (rnd() - 0.5) * 11;
      // A SETTLED stone. The split gives four neighbours a shared straight
      // edge, and a run of those is what made the paving read as brickwork —
      // so every slab is turned a degree or two on its own centre, which
      // breaks every long collinear line in the room.
      final a = (rnd() - 0.5) * 0.13;
      final ca = cos(a), sa = sin(a);
      Offset turn(double x, double y) {
        final dx = x - q.center.dx, dy = y - q.center.dy;
        return Offset(
          q.center.dx + dx * ca - dy * sa,
          q.center.dy + dx * sa + dy * ca,
        );
      }

      final p0 = turn(q.left + j(), q.top + j());
      final p1 = turn(q.right + j(), q.top + j());
      final p2 = turn(q.right + j(), q.bottom + j());
      final p3 = turn(q.left + j(), q.bottom + j());
      g.slabs.add(
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..close(),
      );
      g.slabTone.add(rnd());
      // A worn name, on one slab in five.
      if (rnd() < 0.2 && q.shortestSide > 44) {
        g.carvings.add(q.center);
        g.carvingAngle.add(q.width >= q.height ? 0.0 : pi / 2);
        g.carvingLen.add(q.longestSide * 0.45);
      }
      return;
    }
    // Split the longer side most of the time — but not always, or the stones
    // march. The fraction is never a half.
    final long = r.width >= r.height;
    final vertical = rnd() < 0.78 ? long : !long;
    final f = 0.32 + rnd() * 0.36;
    // The cut IS a joint: a jittered polyline, not a ruled line. Its width is
    // its depth in the tree, so a room gets a few major fissures and many
    // hairlines rather than one size of crack everywhere.
    final w = switch (depth) {
      0 => 28.0,
      1 => 21.0,
      2 => 14.0,
      3 => 10.0,
      _ => 7.0,
    };
    Offset a, z;
    if (vertical) {
      final x = r.left + r.width * f;
      a = Offset(x, r.top);
      z = Offset(x, r.bottom);
    } else {
      final y = r.top + r.height * f;
      a = Offset(r.left, y);
      z = Offset(r.right, y);
    }
    // OVERSHOOT. A cut only spans its own sub-rectangle, so at tiny — where
    // these are ravines a body walks down — every crack ended in a blunt
    // round cap in the middle of the floor and the network read as a heap of
    // loose worms. Six pixels past each end and the cracks meet.
    final dir = z - a;
    final dirLen = dir.distance == 0 ? 1.0 : dir.distance;
    final over = Offset(dir.dx / dirLen, dir.dy / dirLen) * 7;
    a -= over;
    z += over;
    final n = Offset(-(z.dy - a.dy), z.dx - a.dx);
    final nl = n.distance == 0 ? 1.0 : n.distance;
    final seam = Path()..moveTo(a.dx, a.dy);
    for (var k = 1; k <= 3; k++) {
      final u = k / 3;
      final off = k == 3 ? 0.0 : (rnd() - 0.5) * (vertical ? 22 : 18);
      final p =
          Offset.lerp(a, z, u)! + Offset(n.dx / nl * off, n.dy / nl * off);
      seam.lineTo(p.dx, p.dy);
    }
    g.seams.add(seam);
    g.seamWidth.add(w);
    if (vertical) {
      final x = r.left + r.width * f;
      split(Rect.fromLTRB(r.left, r.top, x, r.bottom), depth + 1);
      split(Rect.fromLTRB(x, r.top, r.right, r.bottom), depth + 1);
    } else {
      final y = r.top + r.height * f;
      split(Rect.fromLTRB(r.left, r.top, r.right, y), depth + 1);
      split(Rect.fromLTRB(r.left, y, r.right, r.bottom), depth + 1);
    }
  };
  split(pave, 0);

  // ── moss and seeps ───────────────────────────────────────
  // Clustered, not sprinkled: moss grows where the water runs, so the
  // blotches come in runs of two or three off one damp spot.
  final clumps = (pave.width * pave.height / 52000).clamp(3, 8).toInt();
  for (var i = 0; i < clumps; i++) {
    final at = Offset(
      pave.left + rnd() * pave.width,
      pave.top + rnd() * pave.height,
    );
    final n = 2 + (rnd() * 3).floor();
    for (var k = 0; k < n; k++) {
      final c = at + Offset((rnd() - 0.5) * 90, (rnd() - 0.5) * 70);
      final r = 15.0 + rnd() * 26;
      g.moss.add(_cryptBlob(c, r, r * (0.5 + rnd() * 0.3), rnd, wobble: 0.34));
      g.mossCentre.add(c);
      g.mossR.add(r);
    }
    if (rnd() < 0.7) {
      g.seeps.add(at + Offset((rnd() - 0.5) * 40, (rnd() - 0.5) * 30));
      g.seepR.add(10.0 + rnd() * 13);
    }
  }

  // ── the roots ────────────────────────────────────────────
  // Each one comes in UNDER the wall course, curls, and tapers out before it
  // reaches the middle of the room — so it never crosses the ground the
  // party has to fight on, and it never reads as a beam laid over the floor.
  //
  // The guardian's arena gets the same thing at buttress scale and eight
  // times over, banked round the edge. It got a RING first — nine points on
  // an ellipse joined end to end — and that is exactly what it looked like:
  // a brown hoop drawn on the floor. Separate roots that happen to crowd the
  // same wall read as the root-bowl of something enormous; a closed curve
  // never will.
  final n = arena ? 8 : 2 + (rnd() * 2.4).floor();
  for (var i = 0; i < n; i++) {
    final side = (rnd() * 4).floor();
    final a = arena
        ? b.center +
              Offset(
                cos(i / n * pi * 2 + rnd() * 0.4) * b.width * 0.56,
                sin(i / n * pi * 2 + rnd() * 0.4) * b.height * 0.56,
              )
        : switch (side) {
            0 => Offset(b.left + 40 + rnd() * (b.width - 80), b.top - 14),
            1 => Offset(b.right + 14, b.top + 40 + rnd() * (b.height - 80)),
            2 => Offset(b.left + 40 + rnd() * (b.width - 80), b.bottom + 14),
            _ => Offset(b.left - 14, b.top + 40 + rnd() * (b.height - 80)),
          };
    // A tip in the outer band: past the wall, short of the open centre.
    final ang = arena
        ? atan2(a.dy - b.center.dy, a.dx - b.center.dx) + (rnd() - 0.5) * 1.1
        : rnd() * pi * 2;
    final reach = arena ? 0.46 + rnd() * 0.18 : 0.52 + rnd() * 0.30;
    final z =
        b.center +
        Offset(
          cos(ang) * b.width * 0.5 * reach,
          sin(ang) * b.height * 0.5 * reach,
        );
    final mid = Offset.lerp(a, z, 0.5)!;
    // A hard control offset, perpendicular-ish: a root that grew round
    // something, not one that was surveyed.
    final d = z - a;
    final dl = d.distance == 0 ? 1.0 : d.distance;
    final swing = (rnd() < 0.5 ? -1 : 1) * (0.34 + rnd() * 0.38) * dl;
    final ctrl = mid + Offset(-d.dy / dl * swing, d.dx / dl * swing);
    final base = arena ? 30.0 + rnd() * 26 : 13.0 + rnd() * 13;
    Offset at(double u) =>
        Offset.lerp(Offset.lerp(a, ctrl, u)!, Offset.lerp(ctrl, z, u)!, u)!;
    // Taper: sample the curve, walk out along one side and back along the
    // other, with the half-width falling to nothing at the tip.
    const steps = 12;
    final left = <Offset>[], right = <Offset>[];
    for (var k = 0; k <= steps; k++) {
      final u = k / steps;
      final p = at(u);
      final q = at(min(1.0, u + 0.03));
      final t = q - p;
      final tl = t.distance == 0 ? 1.0 : t.distance;
      final hw = base * 0.5 * (1 - u * u) + 0.8;
      final nn = Offset(-t.dy / tl, t.dx / tl) * hw;
      left.add(p + nn);
      right.add(p - nn);
    }
    final body = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      body.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      body.lineTo(p.dx, p.dy);
    }
    body.close();
    g.roots.add(body);
    // The crest is the same run at a third the width, shifted up the screen.
    final crest = Path();
    for (var k = 0; k <= steps; k++) {
      final p = Offset.lerp(left[k], right[k], 0.32)! - const Offset(0, 2);
      k == 0 ? crest.moveTo(p.dx, p.dy) : crest.lineTo(p.dx, p.dy);
    }
    for (var k = steps; k >= 0; k--) {
      final p = Offset.lerp(left[k], right[k], 0.58)! - const Offset(0, 2);
      crest.lineTo(p.dx, p.dy);
    }
    crest.close();
    g.rootCrests.add(crest);
    final feeders = <(Offset, Offset)>[];
    for (var k = 1; k <= 3; k++) {
      final u = (k / 4 + (rnd() - 0.5) * 0.12).clamp(0.05, 0.95);
      final on = at(u);
      final fa = rnd() * pi * 2;
      feeders.add((on, on + Offset(cos(fa), sin(fa)) * (20 + rnd() * 28)));
    }
    g.rootlets.add(feeders);
  }

  // ── the wall course ──────────────────────────────────────
  // Ashlar of uneven length, with gaps where a block has fallen out. The
  // depth of the course varies too, so the room's edge is a built thing and
  // not a border.
  void course(bool horizontal, bool nearSide) {
    var p = horizontal ? b.left : b.top;
    final end = horizontal ? b.right : b.bottom;
    while (p < end - 12) {
      final len = 26.0 + rnd() * 54;
      final depth = 18.0 + rnd() * 14;
      final r = horizontal
          ? Rect.fromLTWH(
              p,
              nearSide ? b.top : b.bottom - depth,
              min(len, end - p),
              depth,
            )
          : Rect.fromLTWH(
              nearSide ? b.left : b.right - depth,
              p,
              depth,
              min(len, end - p),
            );
      // One block in seven is missing — a course with no gaps in it is a
      // frame, and a frame is what the plain floor already drew.
      if (rnd() > 0.15 && clearOfDoors(r)) {
        g.masonry.add(r);
        g.masonryTone.add(rnd());
      }
      p += len + 2 + rnd() * 5;
    }
  }

  if (water) {
    // The islet's rim is its SHORE, not a wall — and it has to be well
    // inside the room or the water it stands in is only visible in the four
    // corners, which is how the first attempt drew it.
    g.shore = _cryptBlob(
      b.center,
      b.width / 2 - 44,
      b.height / 2 - 44,
      rnd,
      wobble: 0.11,
    );
    // Reeds stand on the shore ring, between the last stone and the water.
    for (var i = 0; i < 20; i++) {
      final a = i / 20 * pi * 2 + rnd() * 0.22;
      final rx = b.width / 2 - 46 - rnd() * 22;
      final ry = b.height / 2 - 46 - rnd() * 22;
      g.reeds.add(b.center + Offset(cos(a) * rx, sin(a) * ry));
    }
  } else {
    // The arena gets its course too: Botanica grew INSIDE a crypt chamber,
    // and an arena with no built edge is a field.
    course(true, true);
    course(true, false);
    course(false, true);
    course(false, false);
  }

  // ── burial niches ────────────────────────────────────────
  if (_cryptHas(room.id, 'loculi')) {
    for (final top in [true, false]) {
      var x = b.left + 30 + rnd() * 40;
      while (x < b.right - 44) {
        final w = 20.0 + rnd() * 16;
        final h = 22.0 + rnd() * 14;
        final r = Rect.fromLTWH(x, top ? b.top + 4 : b.bottom - 4 - h, w, h);
        if (clearOfDoors(r) && rnd() > 0.22) {
          g.loculi.add(r);
          g.loculiSlab.add(rnd() < 0.35);
        }
        // Uneven spacing: these were cut as they were needed, over centuries.
        x += w + 8 + rnd() * 46;
      }
    }
  }

  // ── colonnade ────────────────────────────────────────────
  if (_cryptHas(room.id, 'colonnade')) {
    for (final left in [true, false]) {
      var y = b.top + 50 + rnd() * 60;
      while (y < b.bottom - 50) {
        final c = Offset(
          left ? b.left + 44 + rnd() * 14 : b.right - 44 - rnd() * 14,
          y,
        );
        final r = Rect.fromCenter(center: c, width: 30, height: 70);
        if (clearOfDoors(r) && !open.contains(c)) {
          g.columns.add(c);
          g.columnH.add(28.0 + rnd() * 46);
        }
        y += 74 + rnd() * 78;
      }
    }
  }

  // ── ferns ────────────────────────────────────────────────
  // Ferns grow where the damp and the broken ground are, which in this crypt
  // means the VERGE between the last course of paving and the wall, and the
  // rot patches. Scattered over the open floor (the first attempt) they read
  // as weeds someone planted in rows of one.
  {
    final count = _cryptHas(room.id, 'ferny') ? 18 : 11;
    for (var i = 0; i < count; i++) {
      final onVerge = rnd() < 0.66 || rot.isEmpty;
      Offset c;
      if (onVerge) {
        final a = rnd() * pi * 2;
        c =
            b.center +
            Offset(
              cos(a) * (b.width / 2 - 22 - rnd() * 26),
              sin(a) * (b.height / 2 - 22 - rnd() * 26),
            );
      } else {
        final r = rot[(rnd() * rot.length).floor().clamp(0, rot.length - 1)];
        final a = rnd() * pi * 2;
        c = r.$1 + Offset(cos(a), sin(a)) * (r.$2 * (0.3 + rnd() * 0.7));
      }
      if (!b.contains(c) || open.contains(c)) continue;
      g.ferns.add(c);
      g.fernH.add(15.0 + rnd() * 18);
    }
  }

  // ── the broken tread ─────────────────────────────────────
  if (_cryptHas(room.id, 'stair')) {
    // A real flight, descending down-left across the room, and the sixth
    // step gone — which is exactly where the layout puts the repair bed
    // ('the sifted soil under the broken tread', at 380,280). The two have
    // to agree or the bed is sitting on nothing.
    const a = Offset(560, 40), z = Offset(330, 340);
    for (var i = 0; i < 8; i++) {
      final c = Offset.lerp(a, z, i / 7)!;
      // The treads OVERLAP. Spaced apart they were a ladder of bars with
      // floor showing between them; a flight of stairs is a continuous mass.
      g.treads.add(
        Rect.fromCenter(center: c, width: 152 - i * 3.0, height: 48),
      );
      g.treadBroken.add(i == 6);
    }
  }

  // ── what the flower has dropped ──────────────────────────
  if (arena) {
    for (var i = 0; i < 26; i++) {
      final c = Offset(
        b.left + 20 + rnd() * (b.width - 40),
        b.top + 20 + rnd() * (b.height - 40),
      );
      if (open.contains(c)) continue;
      g.petals.add(c);
    }
  }

  return g;
}
