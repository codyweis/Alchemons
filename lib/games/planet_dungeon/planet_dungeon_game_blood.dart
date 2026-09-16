// lib/games/planet_dungeon/planet_dungeon_game_blood.dart
//
// HEMAVORN — the Sanguine Orrery. Blood's puzzle logic + rendering, as a
// `part of planet_dungeon_game.dart` (the treatment every planet after the Air
// pilot gets). The layout, the passage graph, the pulse algebra, the ostia and
// the collaterals all live in planet_dungeon_layout_blood.dart; this file is
// the rules that drive them.
//
// World rule: *the dungeon is alive, and it beats on a rhythm.* See the layout
// header for the full statement of the pulse, the figure-eight, the vault
// trick, and why this planet needs no reset valve.
//
//  • Entry — the pericardium is stitched over the gate. BLOOD unpicks its own
//    sac and the orrery opens (§5.5, the eased entry reveal).
//  • Star 0 (Priming) — THE FOUR OSTIA. Each mouth drinks on one phase of the
//    beat and nowhere else, and the four sit in four different chambers — so
//    the priming cannot be finished on one beat. ELEMENT-ONLY, all three
//    entry elements used: this is the star §4 guarantees to any trio of the
//    right elements on a first descent.
//  • Star 1 (Graft) — THE COLLATERALS (§6's S2, "route life-flow through
//    correct veins"). A Dark MASK grafts a dead vessel (the planet's one
//    star-level family gate); a LIGHT hand flags which vessels are
//    thrombosed, element-only and purely informational; and a graft is the
//    only world-edit on the planet — always additive, never a subtraction.
//    Three of the five collaterals are sound, rolled per descent.
//  • Rite (the Myocardium) — conduit A is the Blood+KIN cannula (§6 put this
//    gate on Star 1; §4's first-descent guarantee wins, so it moved here);
//    the BALANCE is §6's "balance dark/light beams around the heart",
//    element-only Blood with **Dark+Light→Blood** as the braid.
//  • Star 2 (Systole) — MYS17 SANGUORATH. §7: the guardian fights WITH the
//    planet's rule. Its lull exists only on the FLATLINE, and every strike
//    beat it throws the heart forward a whole phase. The arena's VAGAL NODE
//    is the party's own hand on the clock.
//  • Lost Maxim — THE HEART-DRUM (§6 #17): strike it in sync with the pulse
//    for twelve straight beats. This is the ONE reaction-timed thing on
//    Hemavorn, it is optional, and no star touches it.
//
// NON-STRANDABILITY (see `solveSanguineOrrery`): Hemavorn is the first planet
// whose state advances WITHOUT the player, which is a stranding hazard no
// earlier proof had to answer — a window can close while you are somewhere
// only that window could have let you leave, and waiting is not obviously a
// remedy. Here it is, and provably: the beat is an unbranching period-4 cycle
// nothing can stop, every chamber is safe to stand in for ever, both lobes of
// the eight are CLOSED cycles, the heart's wall is phase-free, the vault's
// leaflet is two-way and the arena's arrest is bounded. The measured result
// agrees: **0 strandable across all ten rolls of the corruption, with no
// reset valve** — against a large number if either lobe is opened, if the
// leaflet is cut one-way, or if the arrest is allowed to hold for ever.

part of 'planet_dungeon_game.dart';

/// Blood's lost maxim discovery id (the screen pays 20 gold on first find).
const String kBloodDrumEggId = 'egg:blood_drum';

// ── Device-tunable knobs ───────────────────────────────────
// Blood has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block. The phase LENGTHS live in the
// layout (`kPulsePhaseSeconds`), because the proof reads them too.

/// How close a creature must stand to a mouth, a cock, the pericardium, the
/// balance, the drum or the vagal node to act on it.
const double _kHeartReach = 70.0;

/// How close the second body of a Dark+Light braid must stand (§6's recipe —
/// it substitutes the ELEMENT, never a family).
const double _kHeartBraidReach = 150.0;

/// How close a Blood KIN must stand to a doorway to steady the vein behind it.
const double _kSteadyReach = 96.0;

/// Seconds a steadied vein stays open past the turn. §6's "Bloodkin
/// stabilizes heartbeat doors (time movement)", honoured as what §4 calls a
/// family-exclusive BONUS — no puzzle requires it, and it is purely additive.
const double _kSteadySeconds = 4.5;

/// Seconds the arena's vagal node holds the heart still. BOUNDED on purpose:
/// see the layout header, reason 7.
const double _kAsystoleSeconds = 4.0;

/// Seconds before the vagal node answers again.
const double _kVagalCooldown = 7.0;

/// Seconds the pulse ring takes to cross a chamber at a phase turn. Purely
/// visual.
const double _kPulseTurnSeconds = 0.5;

/// Consecutive systole onsets the heart-drum wants (§6 #17: twelve).
const int _kDrumBeats = 12;

/// How far either side of a systole onset a drum strike still counts. The one
/// reaction window on the planet, and it belongs to an optional secret.
const double _kDrumWindow = 0.85;

/// Clots a primed mouth wakes (Star 0's one consequence). Waking a dead organ
/// wakes what has been living in it.
const int _kOstiumClots = 2;

/// Clots a THROMBOSED cock wakes (Star 1's one consequence). The price of
/// opening a vessel blind is a fight, never a road.
const int _kThrombusClots = 3;

// ── The orrery's palette (§5.5 VISUAL GRAMMAR) ─────────────
// A body, not a machine: wet crimson, old rust, wet bone. Nothing here is
// drawn like Dark's pewter/void inversion or Water's tide line.
const Color _kHeartCrimson = Color(0xFFB4213A);
const Color _kHeartRust = Color(0xFF7A2A24);
const Color _kHeartBone = Color(0xFFE6D9C8);
const Color _kHeartInk = Color(0xFF14080B);

extension SanguineOrreryDungeon on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetHeartState() {
    if (!_isHeart) return;
    // A death re-stitches no pericardium and un-grafts nothing by itself —
    // the orrery is puzzle state like every other planet's, so it resets with
    // the run. The CORRUPTION is the one exception (see below): re-rolling it
    // mid-run would make the Light flagging a lie.
    heart.reset();
    if (heart.soundCollaterals.isEmpty) {
      heart.rollCorruption(_combatRng.nextInt);
    }
  }

  // ── The map, at the moment it is ─────────────────────────

  /// The passage a door IS. One chamber pair, one passage (pinned by the
  /// tests), so the door the player walks and the edge the proof walks are the
  /// same object and can never drift apart.
  HeartPassage? _heartPassageFor(DungeonRoom room, DungeonDoor door) =>
      heartPassageBetween(room.id, door.targetRoomId);

  /// An UNGRAFTED collateral is not a door you have not opened — the vessel is
  /// dead and the wall it is behind is blank. Same for every way out of the
  /// gate while the pericardium is still stitched over it.
  bool _heartDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isHeart) return false;
    if (room.id == layout.entranceRoomId && !entryDoorRevealed) return true;
    final p = _heartPassageFor(room, door);
    if (p == null) return false;
    return p.kind == PassageKind.collateral && !heart.grafted.contains(p.id);
  }

  /// A collapsed vein is the opposite: you can see the mouth of it perfectly
  /// well and there is nothing coming through. Visible and refused, because
  /// being told what the beat has taken is the whole teaching layer of this
  /// planet (§5.6 BLOCKED).
  bool _heartDoorBlocked(DungeonRoom room, DungeonDoor door) {
    if (!_isHeart) return false;
    final p = _heartPassageFor(room, door);
    if (p == null) return false;
    return !heart.carriesFrom(p, room.id);
  }

  /// One short clause naming exactly what is missing (§5.6 BLOCKED) — never a
  /// method. When the beat opens a road is Mask's earned reading.
  String _heartDoorHint(DungeonRoom room, DungeonDoor door) {
    final p = _heartPassageFor(room, door)!;
    switch (p.kind) {
      case PassageKind.valve:
        return 'The leaflet is held shut, there is pressure on it';
      case PassageKind.collateral:
        return 'Grafted, but slack, ${lobeWord(p.lobe!)} is running';
      case PassageKind.mural:
        return 'The wall does not open here';
      case PassageKind.vein:
        final flow = veinFlow(p.lobe!, heart.phase);
        if (flow == 0) return 'Collapsed, no blood in it at all';
        return 'It runs the other way, nothing swims up a heart';
    }
  }

  // ── Verbs ────────────────────────────────────────────────

  /// Every Blood verb, in priority order. Returns true when one was consumed.
  /// The arena's vagal node outranks the guardian's own catch (Ice's pillar,
  /// Lightning's spike, Plant's root-gall and Dark's shadow-vane set that
  /// precedent) — the fight's errand must never be eaten by a strike.
  bool _tryHeartVerb(DungeonCreature a) {
    if (!_isHeart) return false;
    return _tryPericardium(a) ||
        _tryVagalNode(a) ||
        _tryOstium(a) ||
        _tryCollateralCock(a) ||
        _tryHeartBalance(a) ||
        _tryHeartDrum(a) ||
        // LAST, and deliberately: the steadying is a bonus, so it must never
        // swallow a press meant for anything else in the chamber.
        _trySteadyVein(a);
  }

  /// Blood is the planet's own element, and **Dark+Light→Blood** (§6) stands
  /// in as a BRAID — two bodies at the same spot — for a party whose Blood
  /// hand is down. A recipe substitutes the ELEMENT, never a family, so it is
  /// never accepted at the cannula or at a collateral cock.
  bool _heartHasBloodHand(DungeonCreature a) {
    final el = a.member.element;
    if (el == 'Blood') return true;
    if (el != 'Dark' && el != 'Light') return false;
    final want = el == 'Dark' ? 'Light' : 'Dark';
    return creatures.any(
      (c) =>
          !identical(c, a) &&
          c.alive &&
          c.member.element == want &&
          (c.position - a.position).distance < _kHeartBraidReach,
    );
  }

  /// The entry rite: Blood unpicks its own sac.
  bool _tryPericardium(DungeonCreature a) {
    final pos = currentRoom.sanguine?.pericardium;
    if (pos == null || entryDoorRevealed) return false;
    if ((a.position - pos).distance > _kHeartReach) return false;
    if (a.member.element != 'Blood') {
      _setBlockedHint('Only Blood unpicks its own sac');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist it
    _setHint('The pericardium comes away, and Hemavorn is keeping time');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Blood',
      reagentElements: const ['Dark', 'Light'],
      particleCount: 30,
      intensity: 1.25,
    );
    return true;
  }

  // ── Star 0 · THE PRIMING ─────────────────────────────────

  /// The chamber the Priming Star banks in, wherever it is (the tally reads it
  /// without walking there).
  DungeonRoom? get _primingStarRoom {
    for (final r in layout.rooms.values) {
      if (r.sanguine?.starIndex == 0) return r;
    }
    return null;
  }

  /// An ostium. Element-only (§4), and the mouth drinks on ONE phase — which
  /// is the whole star: four primings, and the beat can never offer more than
  /// one of them at a time.
  ///
  /// This is a WHERE, not a WHEN. Walk in, stand still, and the phase arrives
  /// within one beat; every chamber on this planet is safe to wait in for
  /// ever, so a mistimed arrival costs a wait and nothing else.
  bool _tryOstium(DungeonCreature a) {
    for (final o in ostiaIn(currentRoomId)) {
      if ((a.position - o.position).distance > _kHeartReach) continue;
      if (heart.ostiaPrimed.contains(o.id)) {
        _setAmbientHint('It is drinking, and it is warm');
        return true;
      }
      if (a.member.element != o.element) {
        _setBlockedHint('This mouth answers ${o.element}');
        return true;
      }
      if (heart.phase != o.phase) {
        _setBlockedHint(
          'Nothing in it to drink, it takes ${phaseWord(o.phase)}',
        );
        return true;
      }
      heart.ostiaPrimed.add(o.id);
      _spawnAlchemyBurst(
        o.position,
        producedElement: 'Blood',
        reagentElements: [o.element],
        particleCount: 26,
        intensity: 1.15,
      );
      // THE CONSEQUENCE (§7, one per star): waking a dead organ wakes what has
      // been living in it.
      spawnWispWave(
        element: 'Blood',
        center: o.position,
        count: _kOstiumClots,
        unstable: true,
        announce: false,
      );
      if (!heart.everyOstiumPrimed) {
        _setHint('The mouth takes it, and something in the wall lets go');
        return true;
      }
      final idx = _primingStarRoom?.sanguine?.starIndex;
      if (idx != null && !hasStar(idx)) {
        _setHint('Four mouths drinking, and never two of them on one beat');
        earnStar(idx);
      }
      return true;
    }
    return false;
  }

  // ── Star 1 · THE GRAFTS ──────────────────────────────────

  DungeonRoom? get _graftStarRoom {
    for (final r in layout.rooms.values) {
      if (r.sanguine?.starIndex == 1) return r;
    }
    return null;
  }

  /// A collateral cock. Three things happen here, in this order: a LIGHT hand
  /// flags whether the vessel behind it is sound (element-only, purely
  /// informational — you may always open blind); a DARK MASK grafts it (the
  /// star's ONE hard family gate, §4); and a thrombosed vessel does not take,
  /// which wakes clots and changes nothing else at all.
  bool _tryCollateralCock(DungeonCreature a) {
    for (final c in cocksIn(currentRoomId)) {
      if ((a.position - c.position).distance > _kHeartReach) continue;
      final p = heartPassageById(c.passageId)!;
      if (heart.grafted.contains(p.id)) {
        _setAmbientHint('It is carrying, and it was not built to');
        return true;
      }
      if (heart.cocksTurned.contains(p.id)) {
        _setBlockedHint('Turned already, the vessel behind it is dead');
        return true;
      }

      // The flagging. Element-only Light (§4), and it never consumes the cock
      // — §6 hands this to a Lightmask, but a family-exclusive PENALTY is
      // never legal in v2 and this one gates nothing.
      if (a.member.element == 'Light' && !heart.flagged.contains(p.id)) {
        heart.flagged.add(p.id);
        final far = p.from == currentRoomId ? p.to : p.from;
        _setInsightHint(
          heart.isSound(p.id)
              ? 'It runs clean, the whole way to ${_heartRoomWord(far)}'
              : 'It is thrombosed to the wall, nothing gets to '
                    '${_heartRoomWord(far)} through this',
          4.0,
        );
        return true;
      }

      // ELEMENT-ONLY. This was a Dark MASK gate; grafting a collateral is an
      // act on the vessel, and Dark is what the vessel answers to — the
      // family was a second lock on a planet that already asks for a Mane.
      const req = DungeonInteractionRequirement(element: 'Dark');
      switch (evaluateInteraction(a.member, req)) {
        case InteractionResult.passed:
        case InteractionResult.passedViaRecipe:
          break;
        case InteractionResult.blockedFamily:
          // "The seal remembers" (§4): the chip stamps on first refusal.
          final gate = layout.familyGateFor('collateral_cock');
          if (gate != null) {
            _stampFamilyGate(gate);
          } else {
            _setBlockedHint(
              'Only a Dark that sees inside an unlit vessel can graft this '
              'cock',
            );
          }
          return true;
        case InteractionResult.blockedElement:
        case InteractionResult.blockedStat:
          _setBlockedHint('An unlit lumen answers Dark');
          return true;
      }

      heart.cocksTurned.add(p.id);
      if (!heart.isSound(p.id)) {
        // THE CONSEQUENCE (§7): a thrombosed vessel does not take. Nothing is
        // closed and nothing is lost — the price of guessing is a fight.
        _setHint('The cock turns on nothing, the vessel is packed solid');
        spawnWispWave(
          element: 'Blood',
          center: c.position,
          count: _kThrombusClots,
          unstable: true,
          announce: false,
        );
        return true;
      }

      heart.grafted.add(p.id);
      _spawnAlchemyBurst(
        c.position,
        producedElement: 'Blood',
        reagentElements: const ['Dark'],
        particleCount: 28,
        intensity: 1.2,
      );
      // The graft is a road the beat never gave the eight, so it deserves the
      // engine's reveal flourish at both ends.
      _queueDoorReveal(p.from, p.to);
      _queueDoorReveal(p.to, p.from);
      if (!heart.everyGraftTaken) {
        _setHint('It takes, and the eight has a road it did not have');
        return true;
      }
      final idx = _graftStarRoom?.sanguine?.starIndex;
      if (idx != null && !hasStar(idx)) {
        _setHint(
          'Three dead vessels carrying, and the heart is not the only '
          'thing moving blood',
        );
        earnStar(idx);
      }
      return true;
    }
    return false;
  }

  // ── Steadying a vein (element-only) ──────────────────────

  /// §6's S1 line, "Bloodkin stabilizes heartbeat doors (time movement)",
  /// now ELEMENT-ONLY: any Blood hand standing in a doorway holds that vein
  /// open past the turn.
  ///
  /// It was a Kin exclusive, which §4 permits as a BONUS — but a
  /// family-exclusive behaviour nobody announces is the same trap as an
  /// undeclared gate, only quieter: a player who happens to own a Blood Kin
  /// gets a mechanic that nothing told them about, and everyone else never
  /// learns it exists. Blood is what the vein answers to.
  ///
  /// Still purely ADDITIVE — it can only ever leave a road open longer — so
  /// the no-strand proof continues to ignore it and stays conservative.
  bool _trySteadyVein(DungeonCreature a) {
    if (a.member.element != 'Blood') return false;
    for (final d in currentRoom.doors) {
      if ((a.position - d.rect.center).distance > _kSteadyReach) continue;
      final p = _heartPassageFor(currentRoom, d);
      if (p == null || p.kind != PassageKind.vein) continue;
      if (!heart.carriesFrom(p, currentRoom.id)) continue;
      if (heart.steadied.containsKey(p.id)) continue;
      heart.steadied[p.id] = _kSteadySeconds;
      heart.steadyDir[p.id] = currentRoom.id == p.from ? 1 : -1;
      _setHint('${p.look} is held open, it will not close on the turn');
      _spawnAlchemyBurst(
        d.rect.center,
        producedElement: 'Blood',
        particleCount: 16,
        intensity: 0.9,
      );
      return true;
    }
    return false;
  }

  // ── The rite · THE MYOCARDIUM ────────────────────────────

  /// The rite's second half — §6's "balance dark/light beams around the
  /// heart". Element-only Blood with the Dark+Light braid, so a party missing
  /// the Kin meets exactly ONE refusal in this chamber rather than two.
  bool _tryHeartBalance(DungeonCreature a) {
    final pos = currentRoom.sanguine?.balance;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kHeartReach) return false;
    if ((conduitEnergy['B'] ?? 0) > 0) return false;
    if (!_heartHasBloodHand(a)) {
      _setBlockedHint('Only Blood levels a heart against itself');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The sconces will not level, they answer only a bearer of the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    conduitEnergy['B'] = double.infinity;
    _setHint('The dark sconce and the light one come level, and stay level');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Blood',
      reagentElements: const ['Dark', 'Light'],
      particleCount: 30,
      intensity: 1.2,
    );
    return true;
  }

  // ── Star 2 · SANGUORATH ──────────────────────────────────

  /// The arena's vagal node: stop the heart. The party's only hand on the
  /// clock anywhere on Hemavorn, and it is BOUNDED — an unbounded arrest
  /// would kill the periodicity the whole no-strand proof rests on (the
  /// layout header, reason 7; the counterfactual measures it).
  bool _tryVagalNode(DungeonCreature a) {
    final pos = currentRoom.sanguine?.vagalNode;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kHeartReach) return false;
    if (heart.vagalCooldown > 0) {
      _setBlockedHint('The node will not answer yet');
      return true;
    }
    if (!_heartHasBloodHand(a)) {
      _setBlockedHint('Only Blood lays a hand on a heart');
      return true;
    }
    heart.arrestFor(_kAsystoleSeconds);
    heart.vagalCooldown = _kVagalCooldown;
    heart.turn = _kPulseTurnSeconds;
    _setHint('The heart stops, and everything in Hemavorn stops with it');
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Blood',
      reagentElements: const ['Dark'],
      particleCount: 32,
      intensity: 1.3,
    );
    return true;
  }

  /// §7 — the guardian fights WITH the planet's rule. Sanguorath IS the
  /// arrhythmia: its lull exists only on the FLATLINE, and the moment the
  /// window shuts it throws the beat forward a whole phase, so the rhythm the
  /// party learned outside will not hold in here. The vagal node is their
  /// answer, and the chordae gate is phase-free, so nothing in this fight can
  /// shut them in.
  void _updateSanguorath(DungeonRoom room, double dt) {
    if (room.guardian == null || !guardianAwake) return;
    if (heart.phase != PulsePhase.flatline) {
      guardianVulnerable = false;
      _sanguorathBitLastFrame = false;
      return;
    }
    if (guardianVulnerable && !_sanguorathBitLastFrame) {
      // The window opened: the heart is still, and so is the thing in it.
      _sanguorathBitLastFrame = true;
      return;
    }
    if (!guardianVulnerable && _sanguorathBitLastFrame) {
      _sanguorathBitLastFrame = false;
      heart.arrest = 0;
      heart.skipPhase();
      heart.turn = _kPulseTurnSeconds;
      _setHint('Sanguorath throws the beat forward, the pause is gone');
    }
  }

  // ── The Lost Maxim · THE HEART-DRUM ──────────────────────

  /// §6 #17: strike the heart-drum in sync with the dungeon's pulse for twelve
  /// straight beats. Deliberately beyond what the stars demand (§ "Easter
  /// eggs"), and deliberately the ONLY reaction-timed thing on Hemavorn — a
  /// planet built out of windows you plan for is allowed exactly one window
  /// you have to hit, as long as no star is behind it.
  bool _tryHeartDrum(DungeonCreature a) {
    final pos = currentRoom.sanguine?.heartDrum;
    if (pos == null) return false;
    if ((a.position - pos).distance > _kHeartReach) return false;
    if (heart.drumHeard || discoveredClouds.contains(kBloodDrumEggId)) {
      _setAmbientHint('The skin of it is still humming');
      return true;
    }
    if (a.member.element != 'Blood') {
      _setBlockedHint('Only Blood gets an answer out of this skin');
      return true;
    }
    final beat = _drumWindowBeat();
    if (beat == null) {
      heart.drumStreak = 0;
      heart.drumBeatStruck = -1;
      _setHint('Off the beat, the drum swallows it');
      return true;
    }
    if (beat == heart.drumBeatStruck) {
      _setAmbientHint('Once a beat, and no oftener');
      return true;
    }
    // Consecutive or not, decided by the beat NUMBER rather than by anything
    // the frame loop happened to see.
    heart.drumStreak = beat == heart.drumBeatStruck + 1
        ? heart.drumStreak + 1
        : 1;
    heart.drumBeatStruck = beat;
    if (heart.drumStreak < _kDrumBeats) {
      _setHint('${heart.drumStreak} of $_kDrumBeats', 1.2);
      return true;
    }
    heart.drumHeard = true;
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    beginMaximRite(kBloodDrumEggId, pos);
    _spawnAlchemyBurst(
      pos,
      producedElement: 'Blood',
      reagentElements: const ['Dark', 'Light'],
      particleCount: 44,
      intensity: 1.5,
    );
    return true;
  }

  /// Which BEAT the drum's window is currently open for, or null when it is
  /// shut. The window straddles the top of the cycle — a systole onset is the
  /// wrap — so the tail of one beat belongs to the NEXT one's onset.
  int? _drumWindowBeat() {
    if (heart.arrest > 0) return null;
    final t = heart.clock;
    if (t <= _kDrumWindow) return heart.beats;
    if (t >= kPulseCycleSeconds - _kDrumWindow) return heart.beats + 1;
    return null;
  }

  /// True while the drum's window is open — the render reads it, and so does
  /// nothing else: the streak itself is decided by beat NUMBER.
  bool _drumInWindow() => _drumWindowBeat() != null;

  /// A beat that comes round unanswered breaks the streak, and leaving the
  /// gallery breaks it too. Frame-rate independent: it fires as soon as the
  /// window belongs to a beat more than one past the last one answered, so no
  /// edge can be missed by a slow frame.
  void _updateDrum(DungeonRoom room, double dt) {
    if (room.sanguine?.heartDrum == null || heart.drumHeard) {
      heart.drumStreak = 0;
      heart.drumBeatStruck = -1;
      return;
    }
    final beat = _drumWindowBeat();
    if (beat != null &&
        heart.drumStreak > 0 &&
        beat > heart.drumBeatStruck + 1) {
      heart.drumStreak = 0;
      heart.drumBeatStruck = -1;
    }
  }

  // ── Per-frame ────────────────────────────────────────────

  void _updateHeart(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isHeart) return;
    // THE BEAT. The world's move, and the only mover on the planet the player
    // has no verb for. It runs whether or not anybody acts, which is exactly
    // what makes the reachability question a question about TIME.
    if (heart.advance(dt)) {
      heart.turn = _kPulseTurnSeconds;
      // A vein that has just come into being deserves the engine's flourish;
      // the ones that have just collapsed announce themselves by the lumen
      // closing in the render.
      for (final d in room.doors) {
        final p = _heartPassageFor(room, d);
        if (p == null || !heart.carriesFrom(p, room.id)) continue;
        if (p.kind == PassageKind.collateral && !heart.grafted.contains(p.id)) {
          continue;
        }
        _queueDoorReveal(room.id, d.targetRoomId);
      }
    }
    _updateDrum(room, dt);
    _updateSanguorath(room, dt);
  }

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  /// STATE LEAVES THE CAPSULE (§5.6): the counters live beside the star
  /// tracker, per chamber, never as prose that fades. THE PULSE is the
  /// default, because on this planet it is the one thing every decision turns
  /// on — and it is drawn as four marks in phase order with the live one
  /// filled, so a player can read where the beat is and what is coming at a
  /// glance. That readability is what makes the windows plannable.
  DungeonProgressReadout? _heartProgressReadout() {
    final ch = layout.rooms[currentRoomId]?.sanguine;
    if (ch?.starIndex == 0 && !hasStar(0)) {
      final n = heart.ostiaPrimed.length;
      return DungeonProgressReadout(
        label: 'MOUTHS',
        value: '$n/${kHeartOstia.length}',
        fraction: n / kHeartOstia.length,
      );
    }
    if (ch?.starIndex == 1 && !hasStar(1)) {
      final n = heart.grafted.length;
      return DungeonProgressReadout(
        label: 'GRAFTS',
        value: '$n/$kSoundCollateralCount',
        fraction: n / kSoundCollateralCount,
      );
    }
    if (ch?.heartDrum != null && heart.drumStreak > 0) {
      return DungeonProgressReadout(
        label: 'IN SYNC',
        value: '${heart.drumStreak}/$_kDrumBeats',
        fraction: heart.drumStreak / _kDrumBeats,
      );
    }
    final marks = [
      for (final p in PulsePhase.values) p == heart.phase ? '■' : '□',
    ].join();
    return DungeonProgressReadout(
      label: phaseTag(heart.phase),
      value: marks,
      fraction: (heart.clock / kPulseCycleSeconds).clamp(0.0, 1.0),
    );
  }

  String _heartRoomWord(String roomId) => switch (roomId) {
    'pericard_gate' => 'the Pericard Gate',
    'arterial_run' => 'the Arterial Run',
    'aortic_arch' => 'the Aortic Arch',
    'vena_crossing' => 'the Vena Crossing',
    'pulmonic_stair' => 'the Pulmonic Stair',
    'capillary_weave' => 'the Capillary Weave',
    'atrial_gallery' => 'the Atrial Gallery',
    'myocardium' => 'the Myocardium',
    'auricle_reliquary' => 'a pocket the beat keeps shut',
    _ => 'somewhere past the chordae',
  };

  /// WHAT, never HOW (§5.6). Every method here is Mask's to give.
  String? _heartObjectiveHint(DungeonRoom room) {
    if (room.guardian != null) {
      return 'Sanguorath\'s Systole, the beat keeps the last star';
    }
    if (room.sanguine?.balance != null) {
      return 'The Myocardium, the rite waits on the sconces';
    }
    if (room.sanguine?.starIndex == 0) {
      return hasStar(0)
          ? null
          : 'The Vena Crossing, four mouths in this orrery, and none of them '
                'drinking';
    }
    if (room.sanguine?.starIndex == 1) {
      return hasStar(1)
          ? null
          : 'The Capillary Weave, the eight has vessels it is not using';
    }
    if (room.vaultCache != null) {
      return 'A pocket the pressure keeps shut, something is bottled against '
          'the wall';
    }
    if (room.sanguine?.heartDrum != null) {
      return 'The Atrial Gallery, something in here is keeping time';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Pericard Gate, the way out is only sometimes a way out'
          : 'The Pericard Gate, the sac is stitched shut over it';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _heartAmbientHint(DungeonCreature a, DungeonRoom room) {
    for (final o in ostiaIn(room.id)) {
      if ((a.position - o.position).distance > 110) continue;
      _setAmbientHint('It opens and shuts, and it is not breathing');
      return;
    }
    for (final c in cocksIn(room.id)) {
      if ((a.position - c.position).distance > 110) continue;
      _setAmbientHint(
        heart.grafted.contains(c.passageId)
            ? 'Something is going through it that has not gone anywhere in an '
                  'age'
            : 'Cold brass, and the wall behind it is quiet',
      );
      return;
    }
    _setAmbientHint(switch (heart.phase) {
      PulsePhase.systole => 'The floor comes up under you, once, and settles',
      PulsePhase.dicrotic => 'Something sloshes back the way it came',
      PulsePhase.diastole => 'Far off, a long slow filling sound',
      PulsePhase.flatline => 'Nothing. Nothing at all, for a moment',
    });
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), and it is
  /// tiered by Intelligence.
  void _heartReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    if (ostiaIn(room.id).isNotEmpty) {
      final o = ostiaIn(room.id).first;
      _setInsightHint(switch (tier) {
        0 => 'The mouth is cut to take one thing, and only when it comes',
        1 => 'It drinks on ${phaseWord(o.phase)}, and on nothing else',
        _ =>
          'It drinks on ${phaseWord(o.phase)} and wants ${o.element}. You will '
              'not answer all four mouths on one beat, they are in four '
              'chambers and no two take at the same moment. Stand here; it '
              'comes round',
      });
      return;
    }
    if (cocksIn(room.id).isNotEmpty) {
      _setInsightHint(switch (tier) {
        0 => 'The wall is full of vessels nobody is using',
        1 =>
          'A grafted vessel carries when the round beside it is at rest'
              'it is a road on the phases the beat will not give you',
        _ =>
          'Five cocks, and only three of the vessels behind them are sound. '
              'A light shows you which before you open it; nothing else will, '
              'and a dead one costs you a fight and no ground',
      });
      return;
    }
    if (room.vaultCache != null ||
        heartPassageBetween(room.id, 'auricle_reliquary') != null) {
      _setInsightHint(switch (tier) {
        0 => 'That leaflet has never been open while you were looking',
        1 => 'A leaflet is held shut by pressure, from either side',
        _ =>
          'It hangs open only when there is no pressure at all, which is '
              'the pause between beats. Stand at it and wait; it is the same '
              'leaflet coming back out, so you are not shut in',
      });
      return;
    }
    if (room.sanguine?.vagalNode != null) {
      _setInsightHint(switch (tier) {
        0 => 'There is a knot in the floor that the beat runs through',
        1 => 'Press it and the heart stops. Briefly',
        _ =>
          'It only stops moving while the heart does, and the heart only '
              'stops when you stop it. Take the pause; do not wait for one',
      });
      return;
    }
    // Anywhere in the orrery, insight reads the PULSE — which is the planet.
    _setInsightHint(switch (tier) {
      0 => 'Nothing here is a road for very long',
      1 =>
        'A vein carries only while blood is being pushed through it, and '
            'only downstream. The greater round turns back on the backwash; '
            'the lesser round never does',
      _ =>
        'Four phases, in one order, for ever, and you cannot touch them. '
            'The greater round runs out on the squeeze and back on the '
            'backwash; the lesser round runs one way on the fill and closes on '
            'itself; on the pause nothing runs and every leaflet hangs open. '
            'Work out where to stand, not how fast to move',
    });
  }

  /// Per-chamber mood — the gate is grey daylight through a torn sac and the
  /// arena is the inside of a closed fist, but the real driver is the beat: a
  /// chamber goes darker as the blood leaves it.
  double get _heartMoodTarget {
    final base = switch (currentRoomId) {
      'pericard_gate' => 0.68,
      'arterial_run' => 0.56,
      'aortic_arch' => 0.48,
      'vena_crossing' => 0.42,
      'pulmonic_stair' => 0.38,
      'capillary_weave' => 0.30,
      'atrial_gallery' => 0.34,
      'myocardium' => 0.26,
      'auricle_reliquary' => 0.22,
      _ => guardianAwake ? 0.12 : 0.24,
    };
    return switch (heart.phase) {
      PulsePhase.systole => base * 1.18,
      PulsePhase.dicrotic => base,
      PulsePhase.diastole => base * 0.9,
      PulsePhase.flatline => base * 0.7,
    };
  }

  // ── Render (§5.5 VISUAL GRAMMAR) ─────────────────────────

  void _renderHeart(Canvas canvas, DungeonRoom room) {
    _renderHeartGround(canvas, room);
    _renderHeartLumens(canvas, room);
    _renderHeartObjects(canvas, room);
    _renderHeartTurn(canvas, room);
  }

  /// THE ONE MOVING NUMBER ON THE PLANET. A decaying thump at each of the two
  /// onsets a real beat has: the squeeze, and the rebound off the closing
  /// valve — which this layout already calls the backwash, so the lub-dub is
  /// not invented, it is the phase table read out loud.
  ///
  /// The pulse is Hemavorn's whole identity, which makes it the one planet
  /// where the temptation is to animate everything; heavy per-frame work is
  /// this repo's known jank source, so instead EVERY shape on the floor is
  /// cached and static and reads this single scalar. A wall that swells two
  /// pixels on the beat is worth more than a hundred moving particles and
  /// costs one multiply.
  double _heartSwell() {
    // The vagal node stops the heart, so it stops the room with it. The
    // arrest is the only hand anybody has on this clock and it should be
    // FELT, not just read in the capsule.
    if (heart.arrest > 0) return 0;
    double thump(double since, double len) {
      if (since < 0 || since > len) return 0.0;
      final t = 1 - since / len;
      return t * t;
    }

    return (thump(heart.clock, 1.4) +
            0.5 * thump(heart.clock - kPulsePhaseSeconds[0], 1.0))
        .clamp(0.0, 1.0);
  }

  /// THE CHAMBER ITSELF — wet tissue, valve leaves and vessel wall, built
  /// once per room and cached (see `_buildHeartGround`). What varies per frame
  /// is three numbers: the phase's [fill], the beat's swell, and one sine on
  /// the standing blood.
  void _renderHeartGround(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final g = _heartGround(room);
    // How full the chamber is, eased off the phase. Systole floods it, the
    // flatline leaves it flat and bone-still.
    final fill = switch (heart.phase) {
      PulsePhase.systole => 0.85,
      PulsePhase.dicrotic => 0.6,
      PulsePhase.diastole => 0.45,
      PulsePhase.flatline => 0.12,
    };
    final swell = _heartSwell();

    // The floor. Ink first, so the tissue drawn over it has something to be
    // wet against; then a rust wash that thickens as the chamber fills. Both
    // sit inside the FLOOR TRANSLUCENCY RULE — the sky shader is the room's
    // mood and has to keep showing through the meat.
    final rr = RRect.fromRectAndRadius(b.deflate(8), const Radius.circular(30));
    canvas.drawRRect(rr, Paint()..color = _kHeartInk.withValues(alpha: 0.46));
    canvas.drawRRect(
      rr,
      Paint()..color = _kHeartRust.withValues(alpha: 0.12 + 0.18 * fill),
    );

    // THE BREATH, in one matrix. The tissue grows a little over half a
    // percent on the thump and the floor under it does not, so the chamber
    // reads as a wall pressing in rather than as the camera lurching.
    //
    // CLIPPED TO THE FLOOR. The first cut of this let seams, spindles and
    // vessel throats run off the edge of the chamber and hang in the sky,
    // which turned a body into a diagram drawn on a card. Tissue stops at the
    // wall; one clip does it for everything, including the swell.
    canvas.save();
    canvas.clipRRect(rr);
    canvas.translate(b.center.dx, b.center.dy);
    canvas.scale(1 + 0.006 * swell);
    canvas.translate(-b.center.dx, -b.center.dy);

    // Standing blood, lying in the low places. Dark, because pooled blood is
    // nearly black and the crimson belongs to what is moving.
    for (var i = 0; i < g.pools.length; i++) {
      canvas.drawPath(
        g.pools[i],
        Paint()..color = _kHeartWet.withValues(alpha: 0.50),
      );
      final c = g.poolCentres[i];
      final y = sin(heart.clock * 0.7 + i * 1.7) * 5;
      canvas.drawLine(
        Offset(c.dx - 26, c.dy + y),
        Offset(c.dx + 24, c.dy + y - 2),
        Paint()
          ..strokeWidth = 1.6
          ..color = _kHeartCrimson.withValues(alpha: 0.16 + 0.16 * fill),
      );
    }

    for (final p in g.pieces) {
      final k = p.swell * swell;
      final paint = Paint()
        ..color = p.color.withValues(
          alpha: (p.alpha * (1 + 0.35 * k)).clamp(0.0, 1.0),
        );
      if (p.stroke > 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.stroke * (1 + 0.22 * k)
          ..strokeCap = StrokeCap.round;
      }
      canvas.drawPath(p.path, paint);
    }
    canvas.restore();

    if (heart.phase == PulsePhase.flatline) {
      // The pause is drawn by ABSENCE: one hard bone hairline across the
      // chamber, the flat trace on a stopped heart.
      canvas.drawLine(
        Offset(b.left + 12, b.center.dy),
        Offset(b.right - 12, b.center.dy),
        Paint()
          ..color = _kHeartBone.withValues(alpha: 0.55)
          ..strokeWidth = 2,
      );
    }
  }

  /// A glyph at every passage the chamber can see, so what the beat is doing
  /// is legible before you walk into it: an open vein is a filled TUBE with an
  /// arrowhead pointing the way it runs, a collapsed one is the same tube
  /// pinched to a hairline, a leaflet is two facing curves, and an ungrafted
  /// collateral is not drawn at all — it is not there (see `_heartDoorHidden`).
  void _renderHeartLumens(Canvas canvas, DungeonRoom room) {
    for (final d in room.doors) {
      if (isDoorHidden(room, d)) continue;
      final p = _heartPassageFor(room, d);
      if (p == null || p.kind == PassageKind.mural) continue;
      final at = d.rect.center;
      final live = heart.carriesFrom(p, room.id);
      if (p.kind == PassageKind.valve) {
        final paint = Paint()
          ..color = _kHeartBone.withValues(alpha: live ? 0.85 : 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = live ? 3.5 : 2;
        final gap = live ? 9.0 : 1.5;
        canvas.drawArc(
          Rect.fromCenter(center: at.translate(-gap, 0), width: 26, height: 30),
          -1.2,
          2.4,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: at.translate(gap, 0), width: 26, height: 30),
          1.94,
          2.4,
          false,
          paint,
        );
        continue;
      }
      // The lumen: a tube whose bore is the flow.
      final bore = live ? 13.0 : 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 40, height: bore),
          Radius.circular(bore / 2),
        ),
        Paint()
          ..color = live
              ? _kHeartCrimson.withValues(alpha: 0.8)
              : _kHeartRust.withValues(alpha: 0.55),
      );
      if (!live) continue;
      // Which way it runs. A collateral carries both ways, so it gets two.
      final forward = room.id == p.from;
      final both = p.kind == PassageKind.collateral;
      for (final dir in both ? const [1, -1] : [forward ? 1 : -1]) {
        final tip = at.translate(dir * 20.0, 0);
        final head = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - dir * 11, tip.dy - 8)
          ..lineTo(tip.dx - dir * 11, tip.dy + 8)
          ..close();
        canvas.drawPath(
          head,
          Paint()..color = _kHeartBone.withValues(alpha: 0.8),
        );
      }
    }
  }

  void _renderHeartObjects(Canvas canvas, DungeonRoom room) {
    final ch = room.sanguine;
    // The mouths.
    for (final o in ostiaIn(room.id)) {
      final primed = heart.ostiaPrimed.contains(o.id);
      final ready = heart.canPrime(o);
      canvas.drawCircle(
        o.position,
        18,
        Paint()
          ..color = (primed ? _kHeartCrimson : _kHeartRust).withValues(
            alpha: primed ? 0.75 : 0.5,
          ),
      );
      canvas.drawCircle(
        o.position,
        ready ? 26 : 22,
        Paint()
          ..color = _kHeartBone.withValues(alpha: ready ? 0.85 : 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ready ? 3 : 1.5,
      );
      if (!primed) {
        // A stub of the element the mouth answers, drawn as a chord of its
        // colour — never a letter, never a label.
        canvas.drawArc(
          Rect.fromCircle(center: o.position, radius: 30),
          -0.6,
          1.2,
          false,
          Paint()
            ..color = elementColor(o.element).withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
    // The cocks.
    for (final c in cocksIn(room.id)) {
      final grafted = heart.grafted.contains(c.passageId);
      final turned = heart.cocksTurned.contains(c.passageId);
      final flagged = heart.flagged.contains(c.passageId);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c.position, width: 26, height: 26),
          const Radius.circular(5),
        ),
        Paint()
          ..color = (grafted ? _kHeartCrimson : _kHeartRust).withValues(
            alpha: turned ? 0.8 : 0.55,
          ),
      );
      canvas.drawLine(
        c.position.translate(-16, 0),
        c.position.translate(16, 0),
        Paint()
          ..color = _kHeartBone.withValues(alpha: grafted ? 0.9 : 0.5)
          ..strokeWidth = 3,
      );
      if (flagged && !turned) {
        // The Light hand's flag: a clean ring for a sound vessel, a broken one
        // for a thrombus. Earned information, drawn on the object.
        final sound = heart.isSound(c.passageId);
        final paint = Paint()
          ..color = elementColor('Light').withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        final r = Rect.fromCircle(center: c.position, radius: 22);
        if (sound) {
          canvas.drawCircle(c.position, 22, paint);
        } else {
          canvas.drawArc(r, -2.6, 2.0, false, paint);
          canvas.drawArc(r, 0.5, 2.0, false, paint);
        }
      }
    }
    if (ch == null) return;
    // The pericardium: stitching across the way out.
    final sac = ch.pericardium;
    if (sac != null && !entryDoorRevealed) {
      final paint = Paint()
        ..color = _kHeartBone.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      for (var i = -3; i <= 3; i++) {
        canvas.drawLine(
          sac.translate(-14, i * 11.0),
          sac.translate(14, i * 11.0 + 6),
          paint,
        );
      }
    }
    // The balance: two sconces on one beam.
    final bal = ch.balance;
    if (bal != null) {
      final lit = (conduitEnergy['B'] ?? 0) > 0;
      canvas.drawLine(
        bal.translate(-34, 0),
        bal.translate(34, 0),
        Paint()
          ..color = _kHeartBone.withValues(alpha: lit ? 0.9 : 0.45)
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        bal.translate(-34, lit ? 0 : -8),
        9,
        Paint()..color = elementColor('Dark').withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        bal.translate(34, lit ? 0 : 8),
        9,
        Paint()..color = elementColor('Light').withValues(alpha: 0.85),
      );
    }
    // The drum.
    final drum = ch.heartDrum;
    if (drum != null) {
      final hit = _drumInWindow() && !heart.drumHeard;
      canvas.drawCircle(
        drum,
        26,
        Paint()..color = _kHeartRust.withValues(alpha: 0.7),
      );
      canvas.drawCircle(
        drum,
        hit ? 32 : 26,
        Paint()
          ..color = _kHeartBone.withValues(alpha: hit ? 0.9 : 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = hit ? 3.5 : 2,
      );
    }
    // The vagal node.
    final node = ch.vagalNode;
    if (node != null) {
      final ready = heart.vagalCooldown <= 0;
      canvas.drawCircle(
        node,
        16,
        Paint()..color = _kHeartCrimson.withValues(alpha: ready ? 0.85 : 0.35),
      );
      canvas.drawCircle(
        node,
        24,
        Paint()
          ..color = _kHeartBone.withValues(alpha: ready ? 0.8 : 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// The phase turn: ONE wet pulse ring thrown out from the chamber's centre.
  /// Never a wipe (Dark's grammar) and never a fade — the player has to read
  /// it as the body doing something, not as a lamp changing.
  void _renderHeartTurn(Canvas canvas, DungeonRoom room) {
    if (heart.turn <= 0) return;
    final t = 1 - (heart.turn / _kPulseTurnSeconds).clamp(0.0, 1.0);
    final b = room.bounds;
    canvas.drawCircle(
      b.center,
      t * b.longestSide * 0.62,
      Paint()
        ..color = _kHeartCrimson.withValues(alpha: 0.42 * (1 - t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 * (1 - t) + 2,
    );
  }

  // ── THE NO-STRAND PROOF ──────────────────────────────────

  /// Exhaustive reachability over the orrery's whole state graph, **in TIME**.
  ///
  /// A state is (which chamber you stand in) × (**which phase the beat is
  /// in**) × (which collaterals are grafted), enumerated separately for every
  /// one of the ten rolls the corruption can come up as. Every legal move is
  /// expanded: walking any passage that carries out of the chamber you are in
  /// at that phase, grafting a sound collateral whose cock is in the chamber
  /// you stand in, pulling the arena's vagal node — and **the beat**, which is
  /// not a move the player chooses at all and which is available from every
  /// single state, because a heart does not wait for anybody.
  ///
  /// That last point is the whole difference from the sixteen planets before
  /// this one. Their state only moved when the player moved it, so "wait" was
  /// a no-op and the search could ignore it. Here the world advances on its
  /// own, so the beat is modelled as an always-available edge in BOTH the
  /// forward enumeration and the escape audit: the enumerated set is therefore
  /// everything the world can put the party in, and the audit asks the honest
  /// question — from anywhere the CLOCK can leave you, can you still get out.
  ///
  /// The Blood KIN's steadying is deliberately NOT modelled. It only ever
  /// leaves a vein open longer, so including it could only add edges; leaving
  /// it out makes every number below a conservative bound.
  ///
  /// Seven answers, all by construction rather than by argument:
  ///
  ///  1. `strandable` — states from which some chamber is no longer
  ///     reachable. **It must be zero, and it is zero WITHOUT a reset valve.**
  ///     "Reachable" is checked for EVERY chamber in the layout, which is
  ///     stronger than the brief asks: not just the exit and the unearned
  ///     stars, but the vault and the arena as well.
  ///  2. `strandableWithOpenLesserRound` — the counterfactual for the closed
  ///     cycle: delete the sinus mouth, so the lesser lobe is a one-way chain
  ///     instead of a one-way ring. It must be catastrophic, because the lung
  ///     never reverses and a party that walks in could never walk out. This
  ///     is the single most load-bearing line of the layout.
  ///  3. `strandableWithOneWayLeaflet` — the counterfactual for the vault
  ///     trick: cut the leaflet as a one-way vein INTO the reliquary instead
  ///     of a two-way valve. It must be non-zero, because a pocket with a
  ///     one-way door is a trap however periodic the world outside is.
  ///  4. `strandableWithUnboundedArrest` — the counterfactual for
  ///     periodicity itself: let the vagal node hold the heart still for ever.
  ///     It must be non-zero, and it is the number that says premise one of
  ///     the whole proof — the beat cannot be stopped — is load-bearing
  ///     rather than decorative.
  ///  5. `worstWaitPhases` — the longest any state has to wait, in phases,
  ///     before SOME road opens. This is the "planned, not reacted to" claim
  ///     as a number: the beat has four phases, so anything at or under three
  ///     means no state is ever stuck waiting more than one turn of the
  ///     clock.
  ///  6. `ostiaPrimable` — how many of the four mouths have their own chamber
  ///     reachable ON their own phase with nothing grafted. It must be four,
  ///     or Star 0 is not earnable by a party without the Dark Mask, and §4's
  ///     first-descent guarantee fails.
  ///  7. `vaultReachableUngrafted` — whether the reliquary is reachable on a
  ///     flatline with nothing grafted, i.e. whether the vault sits behind the
  ///     planet's family gate. It must be true: one gate per star, and the
  ///     cache is not a star.
  ({
    int rolls,
    int states,
    int strandable,
    int strandableWithOpenLesserRound,
    int strandableWithOneWayLeaflet,
    int strandableWithUnboundedArrest,
    int worstWaitPhases,
    int ostiaPrimable,
    bool vaultReachableUngrafted,
  })
  solveSanguineOrrery() {
    final rooms = layout.rooms.keys.toList()..sort();
    final arena = layout.rooms.values.firstWhere((r) => r.guardian != null).id;
    final rolls = heartCollateralRolls();

    /// One state, encoded. `a` is the arrested flag, which only the
    /// unbounded-arrest counterfactual ever sets.
    String enc(String room, PulsePhase ph, int mask, bool a) =>
        '$room|${ph.index}|$mask|${a ? 1 : 0}';

    var total = 0;
    var strandable = 0;
    var openRound = 0;
    var oneWay = 0;
    var unbounded = 0;
    var worstWait = 0;
    var ostiaOk = 0;
    var vaultOk = false;

    /// Everything the world and the player can do from one state, under the
    /// three counterfactual switches.
    List<(String, PulsePhase, int, bool)> moves(
      String room,
      PulsePhase ph,
      int mask,
      bool arrested,
      List<String> sound, {
      required bool closedLesserRound,
      required bool twoWayLeaflet,
      required bool boundedArrest,
    }) {
      final out = <(String, PulsePhase, int, bool)>[];
      // THE BEAT. Always available, never chosen, and — unless the
      // counterfactual has stopped the heart — never absent. Premise one.
      if (!arrested) out.add((room, nextPulsePhase(ph), mask, false));
      // Walking. Derived from the SAME rule the engine gates real doors with,
      // via the chamber's own door list, so the proof can never drift from the
      // doors the player actually meets.
      for (final d in layout.rooms[room]!.doors) {
        final p = heartPassageBetween(room, d.targetRoomId);
        if (p == null) {
          out.add((d.targetRoomId, ph, mask, arrested));
          continue;
        }
        if (!closedLesserRound && p.id == 'vn_sinus') continue;
        if (!twoWayLeaflet && p.id == 'vv_leaflet') {
          // Cut as a one-way vein into the pocket.
          if (room == p.from && ph == PulsePhase.flatline) {
            out.add((p.to, ph, mask, arrested));
          }
          continue;
        }
        var grafted = false;
        if (p.kind == PassageKind.collateral) {
          final i = sound.indexOf(p.id);
          if (i < 0) continue; // thrombosed this roll: never a road
          grafted = mask & (1 << i) != 0;
        }
        if (!p.carriesFrom(room, ph, grafted: grafted)) continue;
        out.add((d.targetRoomId, ph, mask, arrested));
      }
      // Grafting. Irreversible, but purely ADDITIVE — it only ever grows the
      // edge set, so it cannot shrink reachability.
      for (var i = 0; i < sound.length; i++) {
        if (mask & (1 << i) != 0) continue;
        final cock = cockFor(sound[i]);
        if (cock == null || cock.roomId != room) continue;
        out.add((room, ph, mask | (1 << i), arrested));
      }
      // The vagal node. Bounded: it only ever puts the beat at the top of a
      // flatline and lets go. Unbounded (the counterfactual): it stops the
      // heart and never gives it back.
      if (room == arena && !arrested) {
        out.add((
          arena,
          PulsePhase.flatline,
          mask,
          boundedArrest ? false : true,
        ));
      }
      return out;
    }

    int audit(
      List<String> sound, {
      required bool closedLesserRound,
      required bool twoWayLeaflet,
      required bool boundedArrest,
      void Function(Map<String, (String, PulsePhase, int, bool)> live)? report,
    }) {
      final first = (layout.entranceRoomId, PulsePhase.systole, 0, false);
      final live = <String, (String, PulsePhase, int, bool)>{};
      live[enc(first.$1, first.$2, first.$3, first.$4)] = first;
      final queue = [first];
      while (queue.isNotEmpty) {
        final (rm, ph, mk, ar) = queue.removeLast();
        for (final m in moves(
          rm,
          ph,
          mk,
          ar,
          sound,
          closedLesserRound: closedLesserRound,
          twoWayLeaflet: twoWayLeaflet,
          boundedArrest: boundedArrest,
        )) {
          final k = enc(m.$1, m.$2, m.$3, m.$4);
          if (live.containsKey(k)) continue;
          live[k] = m;
          queue.add(m);
        }
      }
      var bad = 0;
      for (final st in live.values) {
        final seen = <String>{enc(st.$1, st.$2, st.$3, st.$4)};
        final hit = <String>{st.$1};
        final q = [st];
        while (q.isNotEmpty) {
          final (rm, ph, mk, ar) = q.removeLast();
          for (final m in moves(
            rm,
            ph,
            mk,
            ar,
            sound,
            closedLesserRound: closedLesserRound,
            twoWayLeaflet: twoWayLeaflet,
            boundedArrest: boundedArrest,
          )) {
            final k = enc(m.$1, m.$2, m.$3, m.$4);
            if (!seen.add(k)) continue;
            hit.add(m.$1);
            q.add(m);
          }
        }
        if (hit.length < rooms.length) bad++;
      }
      if (report != null) report(live);
      return bad;
    }

    for (final sound in rolls) {
      strandable += audit(
        sound,
        closedLesserRound: true,
        twoWayLeaflet: true,
        boundedArrest: true,
        report: (live) {
          total += live.length;
          for (final st in live.values) {
            // How many beats this state must sit through before ANY road
            // opens. The "planned, not reacted to" claim, measured.
            var wait = 0;
            var ph = st.$2;
            while (wait < PulsePhase.values.length) {
              final walks = moves(
                st.$1,
                ph,
                st.$3,
                false,
                sound,
                closedLesserRound: true,
                twoWayLeaflet: true,
                boundedArrest: true,
              ).where((m) => m.$1 != st.$1);
              if (walks.isNotEmpty) break;
              wait++;
              ph = nextPulsePhase(ph);
            }
            if (wait > worstWait) worstWait = wait;
          }
        },
      );
      openRound += audit(
        sound,
        closedLesserRound: false,
        twoWayLeaflet: true,
        boundedArrest: true,
      );
      oneWay += audit(
        sound,
        closedLesserRound: true,
        twoWayLeaflet: false,
        boundedArrest: true,
      );
      unbounded += audit(
        sound,
        closedLesserRound: true,
        twoWayLeaflet: true,
        boundedArrest: false,
      );
    }

    // Star 0 and the vault, with NOTHING grafted — i.e. what a party with no
    // Dark Mask can still reach. §4's first-descent guarantee lives here.
    {
      final live = <String>{};
      final first = (layout.entranceRoomId, PulsePhase.systole, 0, false);
      final q = [first];
      live.add(enc(first.$1, first.$2, 0, false));
      while (q.isNotEmpty) {
        final (rm, ph, mk, ar) = q.removeLast();
        for (final m in moves(
          rm,
          ph,
          mk,
          ar,
          const [], // no collateral is ever a road: nothing can be grafted
          closedLesserRound: true,
          twoWayLeaflet: true,
          boundedArrest: true,
        )) {
          final k = enc(m.$1, m.$2, m.$3, m.$4);
          if (!live.add(k)) continue;
          q.add(m);
        }
      }
      for (final o in kHeartOstia) {
        if (live.contains(enc(o.roomId, o.phase, 0, false))) ostiaOk++;
      }
      vaultOk = live.contains(
        enc('auricle_reliquary', PulsePhase.flatline, 0, false),
      );
    }

    return (
      rolls: rolls.length,
      states: total,
      strandable: strandable,
      strandableWithOpenLesserRound: openRound,
      strandableWithOneWayLeaflet: oneWay,
      strandableWithUnboundedArrest: unbounded,
      worstWaitPhases: worstWait,
      ostiaPrimable: ostiaOk,
      vaultReachableUngrafted: vaultOk,
    );
  }
}

// ═════════════════════════════════════════════════════════
// THE GROUND — what Hemavorn actually IS
// ═════════════════════════════════════════════════════════
//
// Every chamber of the terminal planet stood on the generic tinted slab with
// four evenly spaced hairlines ruled across it. Four equal lines is not a
// heart; it is a page of graph paper, and it was the same page in all ten
// rooms. What follows draws the inside of something ALIVE instead: an
// endocardial lining with muscle cords webbing its walls, standing blood in
// the low places, a vessel tracery in the wall itself — and then, per
// chamber, the one piece of anatomy that chamber is NAMED for. A run down
// the orrery should be legible as a tour of a body: sac, artery, arch,
// sinus, stair, lung, comb, muscle, ear, valve.
//
// Three rules this file keeps, all of them learned the hard way:
//
//  • **NOTHING ON A GRID.** Anatomy is never regular. Every spacing here is
//    jittered, every run skips, every length and angle varies, and the two
//    places that wanted to be a lattice (the myocardium's fibres, the
//    auricle's ridges) are built out of tapered bundles and bowed ribs
//    precisely so they cannot tile.
//  • **BUILT ONCE.** All of it is a pure function of the room's own bounds
//    through a small LCG, cached in `_heartGroundCache`, so a chamber looks
//    the same every time you walk into it and costs nothing to walk into
//    twice. Strokes are merged into compound paths wherever one paint can
//    serve many shapes, which keeps a room to roughly fifty draw calls.
//  • **NO `MaskFilter.blur`, ANYWHERE.** The wetness is alpha, dark pools and
//    a pale meniscus. Blur in a per-frame paint is this repo's main jank
//    source and there is none of it on this planet.
//
// The centre of a chamber is left to walk and fight in — the arena and the
// crossing take an explicit open radius — and every big fill stays inside the
// FLOOR TRANSLUCENCY RULE so the sky shader still reads through the meat.

/// Deep muscle in section — what the wall of a heart looks like cut.
const Color _kHeartMeat = Color(0xFF5A1420);

/// Tendon, cartilage and valve leaf: the pale, dry things inside a wet one.
const Color _kHeartSinew = Color(0xFFD9BFA2);

/// Standing blood. Nearly black, because pooled blood is — the crimson in
/// this planet belongs to what is still moving.
const Color _kHeartWet = Color(0xFF2A0A11);

/// One drawn piece of a chamber: a compound path plus the paint it wants.
///
/// [swell] is how much of the beat this piece takes — 0 for dead tissue that
/// should sit still, 1 for a wall that should visibly push. It is the only
/// per-frame input any of this has.
class _HeartPiece {
  const _HeartPiece(
    this.path,
    this.color, {
    this.stroke = 0,
    this.alpha = 0.4,
    this.swell = 0,
  });

  final Path path;
  final Color color;

  /// Stroke width, or 0 to fill.
  final double stroke;
  final double alpha;
  final double swell;
}

/// One chamber's static geometry.
class _HeartGround {
  final List<_HeartPiece> pieces = [];

  /// Standing blood is kept apart from [pieces] because it is the one thing
  /// with a moving highlight on it.
  final List<Path> pools = [];
  final List<Offset> poolCentres = [];
}

/// Built once per chamber, keyed by room id, and never rebuilt.
final Map<String, _HeartGround> _heartGroundCache = {};

_HeartGround _heartGround(DungeonRoom room) =>
    _heartGroundCache.putIfAbsent(room.id, () => _buildHeartGround(room));

// ── Small geometry helpers ────────────────────────────────

/// The control point that bows a straight run between [a] and [b] out to one
/// side by [bow]. Nothing in a body runs straight, so almost every line in
/// this file goes through here.
Offset _heartBow(Offset a, Offset b, double bow) {
  final m = Offset.lerp(a, b, 0.5)!;
  final d = b - a;
  final len = d.distance;
  if (len < 0.001) return m;
  return m + Offset(-d.dy / len, d.dx / len) * bow;
}

/// A bowed run from [a] to [b], appended to [into] (or a fresh path).
Path _heartArcTo(Offset a, Offset b, double bow, [Path? into]) {
  final c = _heartBow(a, b, bow);
  final p = into ?? Path();
  p.moveTo(a.dx, a.dy);
  p.quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
  return p;
}

/// A point on that same bowed run, so things can be hung along it (stitches
/// on a seam, voussoirs on an arch) without re-deriving the curve.
Offset _heartArcAt(Offset a, Offset b, double bow, double t) {
  final c = _heartBow(a, b, bow);
  final u = 1 - t;
  return Offset(
    u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
    u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy,
  );
}

/// A closed, ragged-lipped blob: eight points round an ellipse, each pushed
/// in or out and joined with quadratics, so no pool of blood in this dungeon
/// has a clean edge.
Path _heartBlob(
  Offset c,
  double rx,
  double ry,
  double Function() rnd, {
  double wobble = 0.30,
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

/// A closed contour round [r] with every point nudged off true, smoothed
/// through its own midpoints. Anywhere a chamber wants an outline, it gets
/// one of these rather than a rectangle — a body has no straight edges and a
/// ruled border is the single loudest way to make a room look like a diagram.
Path _heartLoop(Rect r, double Function() rnd, double jitter) {
  final pts = <Offset>[];
  void side(Offset a, Offset z, int n) {
    final d = z - a;
    final l = d.distance;
    final nrm = Offset(-d.dy / l, d.dx / l);
    for (var i = 0; i < n; i++) {
      pts.add(Offset.lerp(a, z, i / n)! + nrm * ((rnd() - 0.5) * 2 * jitter));
    }
  }

  side(r.topLeft, r.topRight, 7);
  side(r.topRight, r.bottomRight, 5);
  side(r.bottomRight, r.bottomLeft, 7);
  side(r.bottomLeft, r.topLeft, 5);
  final path = Path();
  final n = pts.length;
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

/// A branching vessel, recursively. A TREE is the one thing that can never
/// come out looking like a lattice however many of them you draw, which is
/// why the wall tracery and the lung's weave are both built out of it.
void _heartBranch(
  Path p,
  Offset at,
  double ang,
  double len,
  int depth,
  double Function() rnd,
) {
  if (depth <= 0 || len < 7) return;
  final end = at + Offset(cos(ang) * len, sin(ang) * len);
  _heartArcTo(at, end, (rnd() - 0.5) * len * 0.35, p);
  final forks = rnd() < 0.30 ? 3 : 2;
  for (var i = 0; i < forks; i++) {
    _heartBranch(
      p,
      end,
      ang + (rnd() - 0.5) * 1.6,
      len * (0.48 + rnd() * 0.30),
      depth - 1,
      rnd,
    );
  }
}

// ── The lining every chamber has ──────────────────────────

/// THE WALL. A heart chamber is not a floor with a border; it is a muscular
/// tube seen from inside, so the rim gets a thick band of meat, a wet inner
/// line, and endocardial fibres combed inward off it.
///
/// The fibres are where the "nothing on a grid" rule earns its keep: the
/// first cut of them was evenly spaced and read as the teeth of a zip round
/// every room. They now skip about a fifth of their steps, lean by a random
/// amount and vary from a stub to a finger.
void _heartLining(_HeartGround g, Rect b, double Function() rnd) {
  final rim = RRect.fromRectAndRadius(b, const Radius.circular(28));
  g.pieces.add(
    _HeartPiece(
      Path()..addRRect(rim.deflate(14)),
      _kHeartMeat,
      stroke: 28,
      alpha: 0.36,
      swell: 0.6,
    ),
  );
  // THE WET LINE where the lining meets the floor. It was a perfect rounded
  // rectangle, which in every single room read as a HUD frame ruled round the
  // outside of the picture — the exact fault this pass exists to remove. It
  // is a wobbling closed contour now: the same line, but grown.
  g.pieces.add(
    _HeartPiece(
      _heartLoop(b.deflate(24), rnd, 9),
      _kHeartCrimson,
      stroke: 2.6,
      alpha: 0.34,
      swell: 1,
    ),
  );

  // THE GRAIN OF THE FLOOR. Long, faint, bowed strokes right across the
  // chamber. Muscle has a direction, and without this the open middle of a
  // room — which the arena and the crossing are REQUIRED to keep clear —
  // came out as a flat wash with furniture round the edge of it. It is
  // texture, never an obstacle: nothing here is above a tenth of an alpha.
  final grain = Path();
  for (var i = 0; i < 8; i++) {
    final t0 = rnd();
    _heartArcTo(
      _heartPerimeter(b, t0),
      _heartPerimeter(b, t0 + 0.32 + rnd() * 0.28),
      (rnd() - 0.5) * 320,
      grain,
    );
  }
  g.pieces.add(
    _HeartPiece(grain, _kHeartCrimson, stroke: 2.2, alpha: 0.09, swell: 0.8),
  );

  final fib = Path();
  void comb(
    double along0,
    double along1,
    Offset Function(double) at,
    Offset dir,
  ) {
    var t = along0 + rnd() * 40;
    while (t < along1) {
      if (rnd() > 0.20) {
        final len = 9 + rnd() * 28;
        final lean = (rnd() - 0.5) * 0.7;
        final a = at(t);
        final d = Offset(
          dir.dx * cos(lean) - dir.dy * sin(lean),
          dir.dx * sin(lean) + dir.dy * cos(lean),
        );
        _heartArcTo(a, a + d * len, (rnd() - 0.5) * 9, fib);
      }
      t += 9 + rnd() * 26;
    }
  }

  comb(
    b.left + 26,
    b.right - 26,
    (t) => Offset(t, b.top + 26),
    const Offset(0, 1),
  );
  comb(
    b.left + 26,
    b.right - 26,
    (t) => Offset(t, b.bottom - 26),
    const Offset(0, -1),
  );
  comb(
    b.top + 40,
    b.bottom - 40,
    (t) => Offset(b.left + 26, t),
    const Offset(1, 0),
  );
  comb(
    b.top + 40,
    b.bottom - 40,
    (t) => Offset(b.right - 26, t),
    const Offset(-1, 0),
  );
  g.pieces.add(
    _HeartPiece(fib, _kHeartCrimson, stroke: 2.0, alpha: 0.34, swell: 1),
  );
}

/// A point [t] of the way round the perimeter of [b], t in [0,1).
Offset _heartPerimeter(Rect b, double t) {
  final per = 2 * (b.width + b.height);
  var d = (t % 1.0) * per;
  if (d < 0) d += per;
  if (d < b.width) return Offset(b.left + d, b.top);
  d -= b.width;
  if (d < b.height) return Offset(b.right, b.top + d);
  d -= b.height;
  if (d < b.width) return Offset(b.right - d, b.bottom);
  d -= b.width;
  return Offset(b.left, b.bottom - d);
}

/// TRABECULAE CARNEAE — the fleshy cords that web the inside of a chamber and
/// are the reason a heart's interior looks knotted rather than smooth.
///
/// ANCHORED AT BOTH ENDS. The first cut of these grew out of one wall and
/// stopped in mid-air, and a room full of them read as a floor strewn with
/// fallen branches. A trabecula is a BRIDGE: it leaves the wall, arches into
/// the chamber and comes back to the wall, which is both what the tissue
/// actually does and what makes the room read as webbed rather than littered.
/// [openRadius] keeps the arches shallow in a room that has to be fought in.
///
/// Bucketed into three thicknesses so all of them cost six draw calls rather
/// than two per cord.
void _heartTrabeculae(
  _HeartGround g,
  Rect b,
  double Function() rnd, {
  int count = 13,
  double openRadius = 0,
}) {
  final under = [Path(), Path(), Path()];
  final over = [Path(), Path(), Path()];
  const widths = [3.0, 5.0, 7.5];
  final per = 2 * (b.width + b.height);
  for (var i = 0; i < count; i++) {
    final t0 = rnd();
    final a = _heartPerimeter(b, t0);
    final z = _heartPerimeter(b, t0 + (70 + rnd() * 300) / per);
    final d = z - a;
    final l = d.distance;
    if (l < 40) continue;
    // Bow whichever way is into the room.
    final nrm = Offset(-d.dy / l, d.dx / l);
    final toward = b.center - Offset.lerp(a, z, 0.5)!;
    final sign = (nrm.dx * toward.dx + nrm.dy * toward.dy) >= 0 ? 1.0 : -1.0;
    final bow = sign * (26 + rnd() * 120);
    if (openRadius > 0 &&
        (_heartArcAt(a, z, bow, 0.5) - b.center).distance < openRadius) {
      continue;
    }
    final bucket = (rnd() * 3).floor();
    _heartArcTo(a, z, bow, under[bucket]);
    _heartArcTo(a, z, bow, over[bucket]);
  }
  for (var i = 0; i < 3; i++) {
    g.pieces.add(
      _HeartPiece(under[i], _kHeartInk, stroke: widths[i] + 3, alpha: 0.46),
    );
    g.pieces.add(
      _HeartPiece(
        over[i],
        _kHeartCrimson,
        stroke: widths[i],
        alpha: 0.32,
        swell: 1,
      ),
    );
  }
}

/// Standing blood, in the low places. Never round, never centred: a chamber
/// that has been beating for an age has puddles where the floor sags.
void _heartPools(
  _HeartGround g,
  Rect b,
  double Function() rnd, {
  int count = 5,
  double openRadius = 0,
}) {
  for (var i = 0; i < count; i++) {
    final c = Offset(
      b.left + 60 + rnd() * (b.width - 120),
      b.top + 50 + rnd() * (b.height - 100),
    );
    if (openRadius > 0 && (c - b.center).distance < openRadius) continue;
    final rx = 32 + rnd() * 60;
    g.pools.add(_heartBlob(c, rx, rx * (0.34 + rnd() * 0.28), rnd));
    g.poolCentres.add(c);
  }
}

/// VASA VASORUM — the vessels that feed the vessel. A fine tracery growing
/// out of the wall itself, which is what stops the rim reading as a painted
/// border: the wall has a supply, so it is tissue.
void _heartVasa(
  _HeartGround g,
  Rect b,
  double Function() rnd, {
  int trees = 5,
}) {
  final p = Path();
  for (var i = 0; i < trees; i++) {
    final side = (rnd() * 4).floor();
    final u = rnd();
    final (at, ang) = switch (side) {
      0 => (Offset(b.left + 40 + u * (b.width - 80), b.top + 16), pi / 2),
      1 => (Offset(b.left + 40 + u * (b.width - 80), b.bottom - 16), -pi / 2),
      2 => (Offset(b.left + 16, b.top + 50 + u * (b.height - 100)), 0.0),
      _ => (Offset(b.right - 16, b.top + 50 + u * (b.height - 100)), pi),
    };
    _heartBranch(p, at, ang + (rnd() - 0.5) * 0.9, 46 + rnd() * 36, 4, rnd);
  }
  g.pieces.add(
    _HeartPiece(p, _kHeartCrimson, stroke: 1.3, alpha: 0.26, swell: 0.5),
  );
}

// ── What each chamber is ──────────────────────────────────

/// THE PERICARD GATE — the sac. Leathery seams sweeping the whole width of
/// the room with sutures crossing them at irregular intervals, because the
/// thing the party's own BLOOD unpicks to open this planet ought to be
/// visibly SEWN. A fifth of the stitches are already gone.
void _buildSac(_HeartGround g, Rect b, double Function() rnd) {
  final dark = Path();
  final pale = Path();
  final stitch = Path();
  for (var i = 0; i < 4; i++) {
    final y = b.top + b.height * (0.13 + 0.25 * i) + (rnd() - 0.5) * 56;
    // TWO SEAMS ACROSS AND TWO DOWN. Four near-horizontal bands, however much
    // they sag and tilt, still read as a ruled page — and a sac is not sewn
    // in one direction anyway. The down-seams cross the across-seams, which
    // is what makes the room read as something CLOSED UP rather than lined.
    final across = i.isEven;
    final x = b.left + b.width * (0.24 + 0.46 * i) + (rnd() - 0.5) * 70;
    final a = across
        ? Offset(b.left - 14, y + (rnd() - 0.5) * 110)
        : Offset(x + (rnd() - 0.5) * 90, b.top - 14);
    final c = across
        ? Offset(b.right + 14, y + (rnd() - 0.5) * 110)
        : Offset(x + (rnd() - 0.5) * 90, b.bottom + 14);
    // A seam that barely bends is a clothesline. These sag and rise by up to
    // a fifth of the room.
    final bow = (rnd() - 0.5) * 210;
    // Two lips of membrane drawn TOGETHER — a seam is where two edges have
    // been pulled up against each other, which is why the stitches read as
    // holding something shut rather than as ticks on a wire.
    for (final lip in const [-5.0, 5.0]) {
      final off = across ? Offset(0, lip) : Offset(lip, 0);
      _heartArcTo(a + off, c + off, bow, dark);
    }
    _heartArcTo(a, c, bow, pale);
    // Sutures. Spacing is jittered and a fifth of them are missing, so the
    // seam reads as hand-sewn and half-unpicked rather than machined.
    // A WHIP STITCH, which leans the same way all along one seam. Ticks at
    // random angles read as tally marks; a consistent slant reads as
    // somebody's hand going round and round the same edge.
    final slant = (i.isEven ? 0.72 : -0.72) + (rnd() - 0.5) * 0.3;
    var t = 0.04 + rnd() * 0.08;
    while (t < 0.96) {
      if (rnd() > 0.22) {
        final at = _heartArcAt(a, c, bow, t);
        final lean = slant + (rnd() - 0.5) * 0.22 + (across ? 0 : pi / 2);
        final h = 8 + rnd() * 9;
        stitch.moveTo(at.dx - sin(lean) * h, at.dy - cos(lean) * h);
        stitch.lineTo(at.dx + sin(lean) * h, at.dy + cos(lean) * h);
      }
      t += 0.035 + rnd() * 0.055;
    }
  }
  g.pieces.add(_HeartPiece(dark, _kHeartInk, stroke: 11, alpha: 0.44));
  g.pieces.add(
    _HeartPiece(pale, _kHeartSinew, stroke: 3.2, alpha: 0.26, swell: 0.4),
  );
  g.pieces.add(
    _HeartPiece(stitch, _kHeartBone, stroke: 1.8, alpha: 0.34, swell: 0.3),
  );
}

/// THE ARTERIAL RUN — a length of great artery, seen from inside. Bands of
/// circular muscle cross the corridor at irregular intervals and every one of
/// them is BROKEN in the middle, which does two jobs at once: it leaves a
/// clear lane to run down, and a band you can see through reads as wrapped
/// around a tube rather than painted on a floor.
void _buildRun(_HeartGround g, Rect b, double Function() rnd) {
  // BANDS, NOT BARS. The first cut bowed these by a few pixels over two
  // hundred and the run came out looking like a row of railings; a hoop
  // wrapped round a tube has a real belly to it, and no two of them here have
  // the same belly, the same gap or the same thickness.
  final dark = [Path(), Path(), Path()];
  final lit = [Path(), Path(), Path()];
  const widths = [6.0, 9.5, 14.0];
  const lane = 78.0;
  var x = b.left + 40 + rnd() * 30;
  while (x < b.right - 30) {
    final bow = (rnd() < 0.5 ? -1 : 1) * (44 + rnd() * 62);
    final k = (rnd() * 3).floor();
    final drift = (rnd() - 0.5) * 44;
    final gapTop = b.center.dy - lane - rnd() * 34;
    final gapBottom = b.center.dy + lane + rnd() * 34;
    final foot = x + (rnd() - 0.5) * 24;
    for (final into in [dark[k], lit[k]]) {
      _heartArcTo(Offset(x, b.top + 14), Offset(x + drift, gapTop), bow, into);
      _heartArcTo(
        Offset(x + drift, gapBottom),
        Offset(foot, b.bottom - 14),
        bow,
        into,
      );
    }
    x += 40 + rnd() * 86;
  }
  for (var i = 0; i < 3; i++) {
    g.pieces.add(
      _HeartPiece(dark[i], _kHeartInk, stroke: widths[i] + 7, alpha: 0.40),
    );
    g.pieces.add(
      _HeartPiece(
        lit[i],
        _kHeartMeat,
        stroke: widths[i],
        alpha: 0.50,
        swell: 1,
      ),
    );
  }
  // Elastic laminae: a few long ridges running the LENGTH of the run, which
  // is the direction the party travels and the direction blood does.
  final lam = Path();
  for (var i = 0; i < 6; i++) {
    final y = b.top + 40 + rnd() * (b.height - 80);
    final x0 = b.left + rnd() * b.width * 0.4;
    final x1 = x0 + 160 + rnd() * 320;
    _heartArcTo(
      Offset(x0, y),
      Offset(min(x1, b.right - 20), y + (rnd() - 0.5) * 40),
      (rnd() - 0.5) * 40,
      lam,
    );
  }
  g.pieces.add(
    _HeartPiece(lam, _kHeartCrimson, stroke: 2.6, alpha: 0.40, swell: 0.7),
  );
}

/// THE AORTIC ARCH — an arch, and the only piece of this dungeon that is
/// genuinely ARCHITECTURE. Three nested muscular bands spring from both
/// haunches and cross the chamber overhead, with voussoir divisions cut
/// across the outer one at uneven intervals (an evenly divided arch reads as
/// masonry, and this one is grown, not laid).
void _buildArch(_HeartGround g, Rect b, double Function() rnd) {
  final dark = Path();
  final band = Path();
  final tick = Path();
  for (var i = 0; i < 3; i++) {
    final inset = 60.0 + i * 52;
    final a = Offset(b.left + inset * 0.5, b.bottom - 26);
    final c = Offset(b.right - inset * 0.5, b.bottom - 26);
    // A quadratic's crown rises only half its control offset, so the first
    // cut of this — one room-height of bow — put the springing of the arch
    // where its crown should be and left the top third of the chamber empty.
    final bow = -(b.height - inset) * 1.62;
    _heartArcTo(a, c, bow, dark);
    _heartArcTo(a, c, bow, band);
    if (i != 0) continue;
    var t = 0.06 + rnd() * 0.06;
    while (t < 0.94) {
      if (rnd() > 0.18) {
        final p0 = _heartArcAt(a, c, bow, t);
        final p1 = _heartArcAt(a, c, bow + 46, t);
        tick.moveTo(p0.dx, p0.dy);
        tick.lineTo(p1.dx, p1.dy);
      }
      t += 0.04 + rnd() * 0.06;
    }
  }
  g.pieces.add(_HeartPiece(dark, _kHeartInk, stroke: 22, alpha: 0.42));
  g.pieces.add(
    _HeartPiece(band, _kHeartMeat, stroke: 13, alpha: 0.48, swell: 1),
  );
  g.pieces.add(
    _HeartPiece(tick, _kHeartSinew, stroke: 2.0, alpha: 0.24, swell: 0.4),
  );
}

/// THE VENA CROSSING — the sinus, where the figure of eight crosses itself.
/// Two great throats come in from opposite corners and EMPTY into a common
/// pool in the middle: their walls are drawn only at the ends of each run and
/// stop before they reach the centre, so the hub keeps an open floor and
/// still reads as the one place two vessels meet.
void _buildSinus(_HeartGround g, Rect b, double Function() rnd) {
  final dark = Path();
  final wall = Path();
  final axes = [
    (Offset(b.left - 40, b.top - 30), Offset(b.right + 40, b.bottom + 30)),
    (Offset(b.left - 40, b.bottom + 30), Offset(b.right + 40, b.top - 30)),
  ];
  // A THROAT IS A HOLLOW, not a stick. The first cut drew each vessel as two
  // long thin strokes and the crossing came out looking like scaffolding
  // poles laid over the floor; each mouth is a tapered opening now, with a
  // dark hollow inside it and a wall of meat on either lip.
  final bore = Path();
  for (final (a, c) in axes) {
    final d = c - a;
    final len = d.distance;
    final n = Offset(-d.dy / len, d.dx / len);
    for (final seg in const [(0.0, 0.36), (1.0, 0.64)]) {
      final mouth = Offset.lerp(a, c, seg.$1)!;
      final inner = Offset.lerp(a, c, seg.$2)!;
      final wide = 116.0 + rnd() * 30;
      final narrow = 70.0 + rnd() * 20;
      final m0 = mouth + n * wide;
      final m1 = mouth - n * wide;
      final i0 = inner + n * narrow;
      final i1 = inner - n * narrow;
      final c0 = _heartBow(m0, i0, 30);
      final c1 = _heartBow(i1, m1, 30);
      bore.addPath(
        Path()
          ..moveTo(m0.dx, m0.dy)
          ..quadraticBezierTo(c0.dx, c0.dy, i0.dx, i0.dy)
          ..lineTo(i1.dx, i1.dy)
          ..quadraticBezierTo(c1.dx, c1.dy, m1.dx, m1.dy)
          ..close(),
        Offset.zero,
      );
      for (final into in [dark, wall]) {
        _heartArcTo(m0, i0, 30, into);
        _heartArcTo(i1, m1, 30, into);
      }
    }
  }
  // The lumen has to be DARKER than the chamber or the throat reads as two
  // lines rather than a hole: blood standing in a vessel is nearly black.
  g.pieces.add(_HeartPiece(bore, _kHeartWet, alpha: 0.58));
  g.pieces.add(_HeartPiece(dark, _kHeartInk, stroke: 20, alpha: 0.46));
  g.pieces.add(
    _HeartPiece(wall, _kHeartMeat, stroke: 11, alpha: 0.52, swell: 1),
  );
  // The sinus itself: one broad shallow pool of standing blood under the
  // crossing. Scenery to stand in, never an obstacle.
  g.pools.add(_heartBlob(b.center, 150, 96, rnd, wobble: 0.22));
  g.poolCentres.add(b.center);
}

/// THE PULMONIC STAIR — terraces of tissue climbing out of the crossing into
/// the lung. Each shelf has a pale cartilage lip on its tread and a fringe of
/// roots hanging under its nose; the rise and the run of every step differ,
/// because a stair grown by a body is not a stair anybody cut.
void _buildStair(_HeartGround g, Rect b, double Function() rnd) {
  final tread = Path();
  final shadow = Path();
  final lip = Path();
  final fringe = Path();
  var x = b.left + 34;
  var y = b.bottom - 70;
  for (var i = 0; i < 6 && x < b.right - 70; i++) {
    final w = 130 + rnd() * 110;
    final h = 30 + rnd() * 22;
    final a = Offset(x, y);
    final c = Offset(min(x + w, b.right - 24), y + (rnd() - 0.5) * 16);
    final slab = RRect.fromRectAndRadius(
      Rect.fromLTRB(a.dx, a.dy, c.dx, a.dy + h),
      Radius.circular(h * 0.45),
    );
    // THE SHADOW IS THE STEP. Seen from above, a shelf is only a shelf
    // because of what it casts; the first cut had treads at the same value as
    // the floor and the whole stair was invisible in the picture.
    shadow.addRRect(slab.shift(const Offset(5, 11)));
    tread.addRRect(slab);
    _heartArcTo(a, c, -6 - rnd() * 8, lip);
    // The roots under the nose. Jittered, and a quarter of them missing.
    var t = 0.05 + rnd() * 0.1;
    while (t < 0.95) {
      if (rnd() > 0.25) {
        final at = Offset.lerp(a, c, t)!.translate(0, h);
        fringe.moveTo(at.dx, at.dy);
        fringe.lineTo(at.dx + (rnd() - 0.5) * 12, at.dy + 8 + rnd() * 20);
      }
      t += 0.05 + rnd() * 0.08;
    }
    x += w * (0.62 + rnd() * 0.3);
    y -= 48 + rnd() * 34;
  }
  g.pieces.add(_HeartPiece(shadow, _kHeartInk, alpha: 0.55));
  g.pieces.add(_HeartPiece(tread, _kHeartMeat, alpha: 0.60, swell: 0.5));
  g.pieces.add(
    _HeartPiece(lip, _kHeartSinew, stroke: 4.0, alpha: 0.46, swell: 0.6),
  );
  g.pieces.add(_HeartPiece(fringe, _kHeartInk, stroke: 2.0, alpha: 0.5));
}

/// THE CAPILLARY WEAVE — the deepest chamber of the lung, and the busiest
/// room on the planet. A dense branching mesh grown off every wall, cross-
/// linked by anastomoses, with bunches of alveoli crowded where the weave is
/// thickest.
void _buildWeave(_HeartGround g, Rect b, double Function() rnd) {
  final fine = Path();
  for (var i = 0; i < 11; i++) {
    final side = (rnd() * 4).floor();
    final u = rnd();
    final (at, ang) = switch (side) {
      0 => (Offset(b.left + 30 + u * (b.width - 60), b.top + 14), pi / 2),
      1 => (Offset(b.left + 30 + u * (b.width - 60), b.bottom - 14), -pi / 2),
      2 => (Offset(b.left + 14, b.top + 40 + u * (b.height - 80)), 0.0),
      _ => (Offset(b.right - 14, b.top + 40 + u * (b.height - 80)), pi),
    };
    _heartBranch(fine, at, ang + (rnd() - 0.5) * 1.1, 50 + rnd() * 40, 5, rnd);
  }
  // ANASTOMOSES — short cross-links between neighbouring twigs. A capillary
  // bed is a network, not a set of separate trees, and the links are what
  // make it read as woven.
  for (var i = 0; i < 14; i++) {
    final a = Offset(
      b.left + 24 + rnd() * (b.width - 48),
      b.top + 24 + rnd() * (b.height - 48),
    );
    _heartArcTo(
      a,
      a + Offset((rnd() - 0.5) * 120, (rnd() - 0.5) * 90),
      (rnd() - 0.5) * 34,
      fine,
    );
  }
  g.pieces.add(
    _HeartPiece(fine, _kHeartCrimson, stroke: 1.7, alpha: 0.34, swell: 0.8),
  );

  // ALVEOLI. Bunches, never a scatter and never a grid: a cluster centre with
  // five to nine sacs crowded round it at varying radii.
  final sacs = Path();
  final rims = Path();
  for (var i = 0; i < 5; i++) {
    final c = Offset(
      b.left + 60 + rnd() * (b.width - 120),
      b.top + 50 + rnd() * (b.height - 100),
    );
    final n = 5 + (rnd() * 5).floor();
    for (var k = 0; k < n; k++) {
      final a = rnd() * pi * 2;
      final d = 6 + rnd() * 34;
      final at = c + Offset(cos(a) * d, sin(a) * d * 0.8);
      final r = 7 + rnd() * 10;
      sacs.addOval(Rect.fromCircle(center: at, radius: r));
      rims.addOval(Rect.fromCircle(center: at, radius: r));
    }
  }
  g.pieces.add(_HeartPiece(sacs, _kHeartWet, alpha: 0.44));
  g.pieces.add(
    _HeartPiece(rims, _kHeartCrimson, stroke: 1.4, alpha: 0.36, swell: 1),
  );
}

/// THE ATRIAL GALLERY — pectinate muscle, the comb an atrium actually has
/// inside it. A thick crista runs the length of the chamber and the teeth
/// spring off it in a FAN, with varied lengths, a fifth of them missing and
/// some of them forked. Parallel teeth of one length would be a garden rake;
/// this is a gallery of ribs.
void _buildGallery(_HeartGround g, Rect b, double Function() rnd) {
  final crista = Path();
  final teeth = Path();
  final dark = Path();
  for (final run in const [0.26, 0.78]) {
    final down = run < 0.5 ? 1.0 : -1.0;
    final y = b.top + b.height * run;
    final a = Offset(b.left + 20, y + (rnd() - 0.5) * 30);
    final c = Offset(b.right - 20, y + (rnd() - 0.5) * 30);
    final bow = (rnd() - 0.5) * 130;
    _heartArcTo(a, c, bow, crista);
    var t = 0.03 + rnd() * 0.06;
    while (t < 0.97) {
      if (rnd() > 0.20) {
        final at = _heartArcAt(a, c, bow, t);
        // Fanned: the lean runs from one end of the crista to the other, so
        // no two teeth are parallel.
        final lean = (t - 0.5) * 1.1 + (rnd() - 0.5) * 0.35;
        // Lengths are deliberately bimodal — mostly stubs with the occasional
        // long rib. Teeth of one length is a garden rake, and the first cut
        // of this was one.
        final len = rnd() < 0.40 ? 78 + rnd() * 105 : 22 + rnd() * 52;
        final end = at + Offset(sin(lean) * len, down * cos(lean) * len);
        _heartArcTo(at, end, (rnd() - 0.5) * 22, teeth);
        _heartArcTo(at, end, (rnd() - 0.5) * 22, dark);
        if (rnd() < 0.25) {
          // A forked tooth. Real pectinate muscle branches.
          final mid = Offset.lerp(at, end, 0.6)!;
          _heartArcTo(
            mid,
            mid +
                Offset(
                  sin(lean + 0.7) * len * 0.5,
                  down * cos(lean + 0.7) * len * 0.5,
                ),
            8,
            teeth,
          );
        }
      }
      t += 0.022 + rnd() * 0.045;
    }
  }
  g.pieces.add(_HeartPiece(dark, _kHeartInk, stroke: 7, alpha: 0.46));
  g.pieces.add(
    _HeartPiece(teeth, _kHeartMeat, stroke: 4.6, alpha: 0.62, swell: 1),
  );
  // A hairline of light down each rib. Without it the comb read as dark
  // stubble on the floor rather than as tissue standing up off it.
  g.pieces.add(
    _HeartPiece(teeth, _kHeartSinew, stroke: 1.1, alpha: 0.20, swell: 0.6),
  );
  g.pieces.add(_HeartPiece(crista, _kHeartInk, stroke: 20, alpha: 0.46));
  g.pieces.add(
    _HeartPiece(crista, _kHeartMeat, stroke: 9, alpha: 0.44, swell: 0.8),
  );
}

/// THE MYOCARDIUM — standing INSIDE the heart's wall, which is the one place
/// on the planet where you see the muscle rather than the cavity. Helical
/// fibre bundles, drawn as long tapered spindles at two interleaved angles.
///
/// Two families of lines at two angles is a LATTICE, which is what the first
/// cut of this looked like; what stops it here is that no bundle shares a
/// length, a width or an exact angle with any other, and they overlap.
void _buildMyocardium(_HeartGround g, Rect b, double Function() rnd) {
  final body = Path();
  final edge = Path();
  final striae = Path();
  for (var i = 0; i < 14; i++) {
    // Two helical families, badly behaved on purpose.
    final mean = i.isEven ? -0.44 : 0.36;
    final ang = mean + (rnd() - 0.5) * 0.34;
    final len = 170 + rnd() * 250;
    final half = 9 + rnd() * 17;
    // Spread right out to the walls: the first cut kept every centre well
    // inside the room and left the muscle as one diagonal raft with bare
    // corners round it. The floor clip takes care of the overhang.
    final c = Offset(
      b.left + 30 + rnd() * (b.width - 60),
      b.top + 40 + rnd() * (b.height - 80),
    );
    final d = Offset(cos(ang), sin(ang));
    final n = Offset(-d.dy, d.dx);
    final a = c - d * (len / 2);
    final z = c + d * (len / 2);
    // A spindle: two opposed bows meeting at tapered ends.
    final p = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(
        c.dx + n.dx * half * 2,
        c.dy + n.dy * half * 2,
        z.dx,
        z.dy,
      )
      ..quadraticBezierTo(
        c.dx - n.dx * half * 2,
        c.dy - n.dy * half * 2,
        a.dx,
        a.dy,
      )
      ..close();
    body.addPath(p, Offset.zero);
    edge.addPath(p, Offset.zero);
    for (var k = 0; k < 2; k++) {
      final off = n * ((rnd() - 0.5) * half);
      _heartArcTo(
        a + d * (len * 0.12) + off,
        z - d * (len * 0.12) + off,
        half * 0.8,
        striae,
      );
    }
  }
  g.pieces.add(_HeartPiece(body, _kHeartMeat, alpha: 0.40, swell: 0.8));
  g.pieces.add(_HeartPiece(edge, _kHeartInk, stroke: 2.4, alpha: 0.46));
  g.pieces.add(
    _HeartPiece(striae, _kHeartCrimson, stroke: 1.6, alpha: 0.42, swell: 1),
  );
}

/// THE AURICLE RELIQUARY — the little ear off the atrium, and the pocket the
/// vault trick hides in. An auricle is lined all round with ridges running
/// down into it, so the whole pouch is texture converging on the cache; the
/// ribs stop well short of the middle, bow in alternating directions and vary
/// wildly in length, which is what keeps a radial fan from reading as a
/// sunburst.
void _buildAuricle(_HeartGround g, Rect b, double Function() rnd) {
  final ribs = Path();
  final dark = Path();
  final c = b.center;
  var a = rnd() * pi * 2;
  for (var i = 0; i < 26; i++) {
    a += 0.14 + rnd() * 0.30;
    if (rnd() < 0.15) continue;
    final outer = Offset(
      c.dx + cos(a) * (b.width * 0.5 - 18),
      c.dy + sin(a) * (b.height * 0.5 - 18),
    );
    final inner = Offset.lerp(outer, c, 0.30 + rnd() * 0.42)!;
    final bow = (i.isEven ? 1 : -1) * (8 + rnd() * 22);
    _heartArcTo(outer, inner, bow, ribs);
    _heartArcTo(outer, inner, bow, dark);
  }
  g.pieces.add(_HeartPiece(dark, _kHeartInk, stroke: 8, alpha: 0.44));
  g.pieces.add(
    _HeartPiece(ribs, _kHeartMeat, stroke: 4.4, alpha: 0.52, swell: 1),
  );
  // Two muscle bands round the pouch. Wobbled, not oval: two true ellipses
  // round a small room read as a target reticle drawn on the floor.
  final bands = Path();
  for (final r in const [0.62, 0.86]) {
    bands.addPath(
      _heartLoop(
        Rect.fromCenter(
          center: c,
          width: b.width * r,
          height: b.height * r * 0.92,
        ),
        rnd,
        11,
      ),
      Offset.zero,
    );
  }
  g.pieces.add(
    _HeartPiece(bands, _kHeartCrimson, stroke: 2.2, alpha: 0.28, swell: 0.7),
  );
}

/// SANGUORATH'S SYSTOLE — the last arena in the campaign, and the inside of
/// the valve itself. Papillary muscles stand off the four corners, chordae
/// tendineae fan off their apexes to the rim, and three great cusps hang from
/// the upper wall.
///
/// EVERYTHING IS AT THE EDGE. The middle of this floor is where the final
/// fight of the game happens and where the vagal node sits, so nothing is
/// drawn within [open] of the guardian's stand — the cords all run OUTWARD
/// from their mounds, which is both what real chordae do and what keeps the
/// arena clear.
void _buildArena(_HeartGround g, Rect b, double Function() rnd) {
  const open = 205.0;
  final heartCentre = Offset(b.center.dx, b.top + b.height * 0.47);
  final mound = Path();
  final moundEdge = Path();
  final cord = Path();
  // THE ANNULUS — the fibrous ring the cusps actually hang from, round the
  // edge of the open floor, and the thing that frames the last fight in the
  // campaign with a piece of the body instead of a painted circle.
  //
  // IN FOUR PIECES, WITH GAPS. A closed ring came out as a rounded rectangle
  // inside a rounded rectangle — a box drawn inside a box, which is the exact
  // fault this whole pass exists to remove. A real annulus is four arcs
  // meeting at commissures, and broken arcs cannot read as a frame.
  final annulus = Path();
  var a0 = 0.4 + rnd();
  for (var i = 0; i < 4; i++) {
    final span = 0.85 + rnd() * 0.55;
    for (var k = 0; k <= 8; k++) {
      final t = a0 + span * k / 8;
      final at =
          heartCentre +
          Offset(
            cos(t) * (288 + (rnd() - 0.5) * 30),
            sin(t) * (212 + (rnd() - 0.5) * 30),
          );
      k == 0 ? annulus.moveTo(at.dx, at.dy) : annulus.lineTo(at.dx, at.dy);
    }
    a0 += span + 0.34 + rnd() * 0.5;
  }
  g.pieces.add(_HeartPiece(annulus, _kHeartInk, stroke: 28, alpha: 0.34));
  g.pieces.add(
    _HeartPiece(annulus, _kHeartMeat, stroke: 14, alpha: 0.44, swell: 1),
  );
  final mounts = [
    Offset(b.left + 120, b.bottom - 90),
    Offset(b.right - 120, b.bottom - 96),
    Offset(b.left + 150, b.top + 190),
    Offset(b.right - 150, b.top + 178),
  ];
  for (final base in mounts) {
    final w = 52 + rnd() * 30;
    final h = 62 + rnd() * 44;
    final apex = base.translate((rnd() - 0.5) * 26, -h);
    // A DOME, not a cone. Control points pushed out past the base make the
    // sides bulge; the first cut pulled them in and put four grey pyramids in
    // the corners of the last arena in the game.
    final p = Path()
      ..moveTo(base.dx - w, base.dy)
      ..quadraticBezierTo(
        base.dx - w * 1.05,
        base.dy - h * 0.92,
        apex.dx,
        apex.dy,
      )
      ..quadraticBezierTo(
        base.dx + w * 1.05,
        base.dy - h * 0.92,
        base.dx + w,
        base.dy,
      )
      ..close();
    mound.addPath(p, Offset.zero);
    moundEdge.addPath(p, Offset.zero);
    // The chordae. A fan per mound, every cord a different length, all of
    // them bowed (a straight fan of rays is a starburst, which is what the
    // first cut of this drew), and none reaching past the open floor.
    final n = 4 + (rnd() * 4).floor();
    final away = base - heartCentre;
    final base0 = atan2(away.dy, away.dx);
    for (var k = 0; k < n; k++) {
      final ang = base0 + (rnd() - 0.5) * 2.1;
      final len = 58 + rnd() * 96;
      final end = apex + Offset(cos(ang) * len, sin(ang) * len);
      if ((end - heartCentre).distance < open) continue;
      _heartArcTo(apex, end, (rnd() < 0.5 ? -1 : 1) * (14 + rnd() * 34), cord);
    }
  }
  g.pieces.add(_HeartPiece(mound, _kHeartMeat, alpha: 0.50, swell: 0.9));
  g.pieces.add(_HeartPiece(moundEdge, _kHeartInk, stroke: 3, alpha: 0.5));
  // Tendon is the one DRY thing in this dungeon, so it is the one pale thing
  // — and it goes taut on the beat, which is the swell doing real work.
  g.pieces.add(
    _HeartPiece(cord, _kHeartSinew, stroke: 1.8, alpha: 0.40, swell: 1),
  );

  // THE CUSPS. Three leaves hanging off the upper wall, uneven, overlapping.
  final leaf = Path();
  final leafEdge = Path();
  final cusps = [
    (b.left + 180.0, 270.0, 158.0),
    (b.center.dx, 205.0, 96.0),
    (b.right - 175.0, 255.0, 172.0),
  ];
  final leafRib = Path();
  for (final (cx, w, drop) in cusps) {
    final top = b.top + 14;
    final p = Path()
      ..moveTo(cx - w / 2, top)
      ..quadraticBezierTo(cx - w * 0.42, top + drop * 1.15, cx, top + drop)
      ..quadraticBezierTo(cx + w * 0.42, top + drop * 1.15, cx + w / 2, top)
      ..close();
    leaf.addPath(p, Offset.zero);
    leafEdge.addPath(p, Offset.zero);
    // Ribs down the leaf, unevenly spaced and none of them reaching the free
    // edge. A cusp with no grain in it read as a lampshade.
    for (var k = 0; k < 6; k++) {
      final u = -0.4 + k * 0.16 + (rnd() - 0.5) * 0.08;
      _heartArcTo(
        Offset(cx + w * u * 0.5, top),
        Offset(cx + w * u * 0.22, top + drop * (0.55 + rnd() * 0.3)),
        (rnd() - 0.5) * 16,
        leafRib,
      );
    }
  }
  g.pieces.add(_HeartPiece(leaf, _kHeartMeat, alpha: 0.54, swell: 0.7));
  g.pieces.add(
    _HeartPiece(leafRib, _kHeartRust, stroke: 2.0, alpha: 0.42, swell: 0.5),
  );
  g.pieces.add(_HeartPiece(leafEdge, _kHeartInk, stroke: 4.5, alpha: 0.45));
  g.pieces.add(
    _HeartPiece(leafEdge, _kHeartSinew, stroke: 1.8, alpha: 0.34, swell: 1),
  );

  // PURKINJE FIBRES — the conduction net, a pale tracery creeping along the
  // floor at the rim. The thing that actually carries the beat, in the one
  // room where the beat is the enemy.
  final purkinje = Path();
  for (var i = 0; i < 4; i++) {
    final at = Offset(
      i.isEven ? b.left + 30 : b.right - 30,
      b.top + 120 + rnd() * (b.height - 200),
    );
    _heartBranch(purkinje, at, i.isEven ? 0.4 : pi - 0.4, 54, 4, rnd);
  }
  g.pieces.add(
    _HeartPiece(purkinje, _kHeartBone, stroke: 1.1, alpha: 0.14, swell: 0.6),
  );
}

/// Which architecture each chamber gets. A room that is not in here still
/// gets the lining, the cords and the pools — nothing can come out empty.
final Map<String, void Function(_HeartGround, Rect, double Function())>
_heartArchitects = {
  'pericard_gate': _buildSac,
  'arterial_run': _buildRun,
  'aortic_arch': _buildArch,
  'vena_crossing': _buildSinus,
  'pulmonic_stair': _buildStair,
  'capillary_weave': _buildWeave,
  'atrial_gallery': _buildGallery,
  'myocardium': _buildMyocardium,
  'auricle_reliquary': _buildAuricle,
  'sanguorath_systole': _buildArena,
};

/// One chamber, built once. Deterministic from the room's own bounds through
/// a plain LCG, so a chamber looks the same every descent and no two of the
/// ten look alike (every room on this planet has its own size).
_HeartGround _buildHeartGround(DungeonRoom room) {
  final b = room.bounds.deflate(10);
  final g = _HeartGround();
  var seed = (b.width * 31 + b.height * 17).toInt() | 1;
  double rnd() {
    seed = (seed * 1103515245 + 12345) & 0x3FFFFFFF;
    return (seed >> 8) / 0x3FFFFF;
  }

  // The two rooms that have to be fought and gathered in keep their middles
  // clear: the guardian arena, and the hub where both rounds cross.
  final open = switch (room.id) {
    'sanguorath_systole' => 210.0,
    'vena_crossing' => 185.0,
    _ => 0.0,
  };

  _heartLining(g, b, rnd);
  _heartVasa(g, b, rnd, trees: room.id == 'auricle_reliquary' ? 3 : 5);
  _heartPools(
    g,
    b,
    rnd,
    count: (b.width * b.height / 86000).clamp(3, 7).toInt(),
    openRadius: open,
  );
  _heartArchitects[room.id]?.call(g, b, rnd);
  // The arena asks for more of them than anywhere else: its middle is out of
  // bounds by design, so the only way to keep the biggest room in the dungeon
  // from reading as bare is to web its edges properly.
  _heartTrabeculae(
    g,
    b,
    rnd,
    count: switch (room.id) {
      'auricle_reliquary' => 6,
      'sanguorath_systole' => 24,
      _ => 13,
    },
    openRadius: open,
  );
  return g;
}
