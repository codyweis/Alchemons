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
      return 'Grown shut — a trunk stands where the crack was';
    }
    return span.size == SpanSize.tinyOnly
        ? 'Too big by far — ${span.look} takes a smaller body'
        : 'Too small by far — ${span.look} wants a longer leg';
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
    _setHint('The briar lets go of the gate — Verdanthos opens both its ways');
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
          ? 'The gall takes you in — and the moss stands up into a forest'
          : 'The gall lets you go — and the forest lies back down as moss',
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
      _setBlockedHint('Nothing to turn — the crypt already lies fallow');
      return true;
    }
    if (crypt.armedPitRoom != currentRoomId) {
      crypt.armedPitRoom = currentRoomId;
      crypt.armedPitTimer = _kMulchArmSeconds;
      // Attempt-edged and explicit: the most expensive verb on the planet
      // never fires on one careless press.
      _setHint(
        'The litter steams — turn it again and the season takes back every '
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
      'The whole crypt goes brown at once — every vine down to mould, and the '
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
      _setHint('The wick catches — and something comes off the ceiling');
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
          'The bowl is a walled field — no body this big gets '
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
            _setBlockedHint('The seed wants a sun — it answers Light');
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
      _setHint('The heart-seed opens — and the whole crypt smells of spring');
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
        'The clay will not slake — it answers only a bearer of the '
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
      return 'A green thread runs out of ${bed.look} — hardly anything at all, '
          'at this size';
    }
    return 'It comes up wood, and it comes up fast — and ${bed.look} is not '
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
            : 'Spores burst — you come up at your own size, and somewhere out '
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
            : 'The seed has everything it wants — and nothing here can see it '
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
      return 'Botanica\'s Heart — the flower keeps the last star';
    }
    if (room.grove?.sepulchre != null) {
      return 'The Bloom Hall — the rite waits on the sepulchre';
    }
    if (room.grove?.growthAltar != null) {
      return hasStar(room.grove!.starIndex!)
          ? null
          : 'The Islet — the heart-seed has slept a long age';
    }
    if (room.vaultCache != null) {
      return 'Inside the altar\'s own rim — something is bottled here';
    }
    if (room.grove?.lampId != null && !hasStar(0)) {
      return crypt.lampsLit.contains(room.grove!.lampId)
          ? null
          : 'A grave-lamp stands dead here';
    }
    if (room.id == 'crypt_niche') {
      return 'The Crypt Niche — nothing this deep was built for you';
    }
    if (room.id == 'pollen_stair') {
      return 'The Pollen Stair — a gall hangs at the turn of it';
    }
    if (room.id == 'fern_gallery') {
      return 'The Fern Gallery — one root has swallowed half the wall';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Root Porch — the crypt runs west, and under itself'
          : 'The Root Porch — the lich-gate is knotted shut';
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
              'and this crypt has none — someone must show it one',
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
              'gets wood — and the wood fills the crack it came out of',
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
            'you plant anything — and the litter is the only take-back, and it '
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

  /// The change of reference. Cheap by construction: a fixed handful of
  /// strokes derived from the room's own bounds, no allocation per frame
  /// beyond the paints, and nothing that scales with the party or the enemies.
  void _renderCryptGround(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    if (crypt.isTiny) {
      // A canopy of fronds, and the paving joints as ravines.
      final frond = Paint()
        ..color = _kCryptGreen.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (var i = 0; i < 9; i++) {
        final x = b.left + b.width * (i + 0.5) / 9;
        final h = 70.0 + 26.0 * ((i % 3) - 1);
        final path = Path()
          ..moveTo(x, b.bottom)
          ..quadraticBezierTo(x + 22, b.bottom - h * 0.6, x + 6, b.bottom - h);
        canvas.drawPath(path, frond);
      }
      final ravine = Paint()..color = _kCryptDeep.withValues(alpha: 0.42);
      for (var i = 1; i < 4; i++) {
        final y = b.top + b.height * i / 4;
        canvas.drawRect(Rect.fromLTWH(b.left, y - 5, b.width, 10), ravine);
      }
    } else {
      // Trim: a moss verge along the wall and a hairline of paving joints.
      final verge = Paint()..color = _kCryptGreen.withValues(alpha: 0.2);
      canvas.drawRect(Rect.fromLTWH(b.left, b.bottom - 18, b.width, 18), verge);
      final joint = Paint()
        ..color = _kCryptDeep.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (var i = 1; i < 4; i++) {
        final y = b.top + b.height * i / 4;
        canvas.drawLine(Offset(b.left, y), Offset(b.right, y), joint);
      }
    }
  }

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
