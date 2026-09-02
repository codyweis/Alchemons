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
        return 'The leaflet is held shut — there is pressure on it';
      case PassageKind.collateral:
        return 'Grafted, but slack — ${lobeWord(p.lobe!)} is running';
      case PassageKind.mural:
        return 'The wall does not open here';
      case PassageKind.vein:
        final flow = veinFlow(p.lobe!, heart.phase);
        if (flow == 0) return 'Collapsed — no blood in it at all';
        return 'It runs the other way — nothing swims up a heart';
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
    _setHint('The pericardium comes away — and Hemavorn is keeping time');
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
          'Nothing in it to drink — it takes ${phaseWord(o.phase)}',
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
        _setHint('The mouth takes it — and something in the wall lets go');
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
        _setBlockedHint('Turned already — the vessel behind it is dead');
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
              : 'It is thrombosed to the wall — nothing gets to '
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
        _setHint('The cock turns on nothing — the vessel is packed solid');
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
        _setHint('It takes — and the eight has a road it did not have');
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
      _setHint('${p.look} is held open — it will not close on the turn');
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
        'The sconces will not level — they answer only a bearer of the '
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
    _setHint('The heart stops — and everything in Hemavorn stops with it');
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
      _setHint('Sanguorath throws the beat forward — the pause is gone');
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
      _setHint('Off the beat — the drum swallows it');
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
      return 'Sanguorath\'s Systole — the beat keeps the last star';
    }
    if (room.sanguine?.balance != null) {
      return 'The Myocardium — the rite waits on the sconces';
    }
    if (room.sanguine?.starIndex == 0) {
      return hasStar(0)
          ? null
          : 'The Vena Crossing — four mouths in this orrery, and none of them '
                'drinking';
    }
    if (room.sanguine?.starIndex == 1) {
      return hasStar(1)
          ? null
          : 'The Capillary Weave — the eight has vessels it is not using';
    }
    if (room.vaultCache != null) {
      return 'A pocket the pressure keeps shut — something is bottled against '
          'the wall';
    }
    if (room.sanguine?.heartDrum != null) {
      return 'The Atrial Gallery — something in here is keeping time';
    }
    if (room.id == layout.entranceRoomId) {
      return entryDoorRevealed
          ? 'The Pericard Gate — the way out is only sometimes a way out'
          : 'The Pericard Gate — the sac is stitched shut over it';
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
              'not answer all four mouths on one beat — they are in four '
              'chambers and no two take at the same moment. Stand here; it '
              'comes round',
      });
      return;
    }
    if (cocksIn(room.id).isNotEmpty) {
      _setInsightHint(switch (tier) {
        0 => 'The wall is full of vessels nobody is using',
        1 =>
          'A grafted vessel carries when the round beside it is at rest — '
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
        1 => 'A leaflet is held shut by pressure — from either side',
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
        1 => 'Press it and the heart stops — briefly',
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

  /// THE SWELL. Cheap by construction: a fixed handful of strokes derived from
  /// the room's own bounds, no allocation per frame beyond the paints, and
  /// nothing that scales with the party or the enemies. No blur filters (the
  /// game's known jank source) — the wetness is done with alpha and arcs.
  void _renderHeartGround(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // How full the chamber is, eased off the phase. Systole floods it, the
    // flatline leaves it flat and bone-still.
    final fill = switch (heart.phase) {
      PulsePhase.systole => 0.85,
      PulsePhase.dicrotic => 0.6,
      PulsePhase.diastole => 0.45,
      PulsePhase.flatline => 0.12,
    };
    canvas.drawRect(b, Paint()..color = _kHeartInk.withValues(alpha: 0.42));
    canvas.drawRect(
      b,
      Paint()..color = _kHeartRust.withValues(alpha: 0.10 + 0.16 * fill),
    );
    // Four slow crimson bands, the tide of the chamber. They rise on the
    // systole and lie flat on the pause — the body reading, never a tide line.
    final band = Paint()
      ..color = _kHeartCrimson.withValues(alpha: 0.10 + 0.14 * fill)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + 3 * fill;
    for (var i = 1; i < 5; i++) {
      final y = b.top + b.height * i / 5;
      final lift = (1 - fill) * 8.0;
      canvas.drawLine(
        Offset(b.left + 12, y + lift),
        Offset(b.right - 12, y + lift),
        band,
      );
    }
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
