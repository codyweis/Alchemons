// lib/games/planet_dungeon/planet_dungeon_game_plant.dart
//
// VERDANTHOS — THE CONSERVATORY. Plant's puzzle logic, as a `part of
// planet_dungeon_game.dart`. The layout, the recipes, the tendril's rule and
// the rite's root lattice are pure and live in planet_dungeon_layout_plant.dart; the
// pictures live in planet_dungeon_game_plant_art.dart. Design: §9.20.
//
// World rule: *every plant here thrives in a different climate, and yours is
// the hand that makes it.* One verb — the TENDING CIRCLE.
//
//  • Star 1 (Bloom) — THE THREE CLIMATES. The Dry Bed wants Water, the
//    Hothouse Ice (Water + Spirit), the Shadehouse Light (Spirit + Crystal).
//    When the third plant blooms the camera cuts to the hub: three motes fly
//    in, bind in the central planter, and one great plant rises and prises
//    the north door open. The star banks on the bind.
//  • Star 2 (Bud) — THE TRELLIS GARDEN. Wet the soil, freeze the crossing,
//    choose the lamp, then GROW at the root: the ghost shows exactly where
//    the tendril will go. PULL takes it back for free.
//  • Rite — THE ROOTBOUND DOOR. Seven buds on hanging roots, four rings at
//    the tips. Water rises up its root and stops at ice; frost crawls through
//    wet buds everywhere; light climbs dry bark and thaws the first frost it
//    meets. Make the roots match the great plant's crown — which flowered in
//    the hub on the Bud Star — and they let go. Light at the door is the
//    planet's Crystal MASK gate; the stump prunes the roots bare, free.
//  • Star 3 (Heart) — BOTANICA. Each strike wrecks the arena's climate; the
//    lull opens only once it is fixed, at either of two circles.
//  • Vault — the west bed's dead end is a lid: a tendril grown all the way
//    there prises it up, and there are steps under it.
//  • Lost Maxim — THE SEED THAT WANTED THE OPPOSITE: draw moisture, light
//    and frost back from the grey seed in the hub's fourth planter.

part of 'planet_dungeon_game.dart';

// ── Device-tunable knobs ───────────────────────────────────
// Plant has never been on a device; every number the feel depends on is named
// here so a tuning pass is edit-one-block.

/// How close a creature must stand to the trellis root or the grey seed to
/// act on it.
const double _kGreenReach = 72.0;

/// The cutscene, in seconds after the third bloom. The bloom plays in its own
/// wing first; then the camera cuts to the hub.
const double _kCutDelay = 1.9;
const double _kCutMotes = 1.7; // the motes fly in through the wing doors
const double _kCutBind = 2.5; // they meet over the planter: the star banks
const double _kCutRise = 4.3; // the great plant is up
const double _kCutPry = 5.3; // its roots have the north door open
const double _kCutEnd = 7.2; // and the shot has followed them in

/// THE BUD STAR, in seconds after the tendril's tip reaches the island: it
/// coils round the bud, the bud swells with light breaking through its seams,
/// it bursts (the star banks), a star rises out of it, and a stream of pollen
/// flows north and opens the way on.
const double kBudCoil = 0.7;
const double kBudBurst = 1.35;
const double kBudDoor = 3.4;
const double kBudEnd = 4.4;

/// How long the cut to the great plant's flowering crown holds.
const double kCrownCut = 3.2;

/// Seconds per tile the tendril unrolls, growing and pulling.
const double _kTendrilTileSeconds = 0.26;

/// Botanica: how long a strike takes to land, the restoration after a fix,
/// and the lull that follows it.
const double _kBotanicaStrike = 1.3;
const double _kBotanicaRestore = 1.0;
const double _kBotanicaLull = 6.0;

extension ConservatoryDungeon on PlanetDungeonGame {
  // ── Run state ─────────────────────────────────────────────

  void _resetConservatoryState() {
    if (!_isConservatory) return;
    final g = greenhouse..reset();
    _green.reset();
    // §5.7: what a banked star made is standing on every later descent.
    if (hasStar(0)) {
      g.healed.addAll(Climate.values);
      _green.settleWings();
    }
    if (hasStar(1)) {
      g.trellis
        ..watered = true
        ..frozen = true
        ..lit = TrellisLamp.east;
      g.grown = true;
      _green.settleTrellis(g.trellis, growTendril(g.trellis).path.length);
    }
    if (hasStar(2)) {
      g.roots.setAll(kRootTarget);
      g.rootsOpen = true;
      _green.settleRoots();
    }
    if (discoveredClouds.contains(kPlantOppositeSeedEggId)) {
      g.drawn.addAll(SeedChannel.values);
      _green.settleSeed();
    }
  }

  // ── Doors ─────────────────────────────────────────────────

  bool _conservatoryDoorHidden(DungeonRoom room, DungeonDoor door) {
    if (!_isConservatory) return false;
    // The north door exists once the great plant's roots have it open — not
    // on the frame the star banks, which is mid-cutscene.
    if (room.id == 'conservatory' &&
        door.targetRoomId == 'trellis_garden' &&
        _green.cutT >= 0 &&
        _green.cutT < _kCutPry) {
      return true;
    }
    // The way north appears when the bud's pollen reaches it, not on the
    // frame the star banks.
    if (room.id == 'trellis_garden' &&
        door.targetRoomId == 'rootbound_door' &&
        _green.budBurstT >= 0 &&
        _green.budBurstT < kBudDoor) {
      return true;
    }
    if (room.id == 'trellis_garden' && door.targetRoomId == 'root_cellar') {
      return !greenhouse.hatchOpen;
    }
    return false;
  }

  /// Nothing in the Conservatory is locked by its own rules; the engine's
  /// finale and guardian seals are the only shut doors.
  bool _conservatoryDoorBlocked(DungeonRoom room, DungeonDoor door) => false;

  String _conservatoryDoorHint(DungeonRoom room, DungeonDoor door) =>
      'The way is shut';

  // ── The verb ──────────────────────────────────────────────

  bool _tryConservatoryVerb(DungeonCreature a) {
    if (!_isConservatory) return false;
    final g = currentRoom.grove;
    if (g == null) return false;
    return _tryArenaRing(a, g) ||
        _tryGreySeed(a, g) ||
        _tryWingRing(a, g) ||
        _tryTrellis(a, g) ||
        _tryRite(a, g);
  }

  /// The bodies standing in the ring at [at] (alive, in this room).
  List<DungeonCreature> _inRing(Offset at) => [
    for (final c in creatures)
      if (c.alive && (c.position - at).distance <= kTendRingReach) c,
  ];

  List<String> _ringElements(Offset at) => [
    for (final c in _inRing(at)) c.member.element,
  ];

  bool _standingIn(DungeonCreature a, Offset at) =>
      (a.position - at).distance <= kTendRingReach;

  /// A ring asked for [product] and short of bodies: say which, spend nothing.
  void _refuseRing(Offset at, String product, List<String> missing) {
    _setBlockedHint(tendMissingLine(product, missing));
    _spawnAlchemyBurst(
      at,
      producedElement: product,
      reagentElements: _ringElements(at),
      unstable: true,
      particleCount: 10,
      intensity: 0.6,
    );
    _green.ringRefused(at);
  }

  /// The climate [product] made at the ring at [at]: the burst and the cue.
  void _ringMade(Offset at, String product) {
    _cue(switch (product) {
      'Water' => SoundCue.elementWater,
      'Ice' => SoundCue.elementIce,
      _ => SoundCue.elementLight,
    });
    _spawnAlchemyBurst(
      at,
      producedElement: product,
      reagentElements: kTendRecipes[product] ?? const [],
      particleCount: 22,
      intensity: 1.0,
    );
    _green.ringFired(at, product);
  }

  // ── STAR 1 — THE THREE CLIMATES ───────────────────────────

  bool _tryWingRing(DungeonCreature a, ConservatoryPlot g) {
    final wing = g.wing;
    if (wing == null || !_standingIn(a, wing.ring)) return false;
    final product = climateFix(wing.climate);
    if (greenhouse.healed.contains(wing.climate)) {
      _setHint('It is thriving. This room needs nothing more');
      return true;
    }
    final missing = tendMissing(product, _ringElements(wing.ring));
    if (missing.isNotEmpty) {
      _refuseRing(wing.ring, product, missing);
      return true;
    }
    greenhouse.healed.add(wing.climate);
    _ringMade(wing.ring, product);
    _green.healWing(wing.climate);
    if (greenhouse.wingsHealed && !hasStar(0)) {
      _green.cutPending = _kCutDelay;
    }
    return true;
  }

  /// The cutscene's clock, and the star on the bind.
  void _updateBloomCut(double dt) {
    final s = _green;
    if (s.cutPending > 0) {
      s.cutPending -= dt;
      if (s.cutPending <= 0) {
        s.cutPending = 0;
        s.cutT = 0;
        final hub = layout.rooms['conservatory']!;
        cutTo('conservatory', hub.grove!.greatPlanter!, hold: _kCutPry + 0.2);
      }
      return;
    }
    // A run that healed all three and never saw the cut (a restored state, a
    // test) still gets its star.
    if (s.cutT < 0) {
      if (greenhouse.wingsHealed && !hasStar(0)) s.cutPending = 0.01;
      return;
    }
    final was = s.cutT;
    s.cutT += dt;
    if (was < _kCutBind && s.cutT >= _kCutBind) {
      _cue(SoundCue.dungeonPuzzleSolved);
      final at = layout.rooms['conservatory']!.grove!.greatPlanter!;
      _spawnAlchemyBurst(
        at,
        producedElement: 'Plant',
        reagentElements: const ['Water', 'Ice', 'Light'],
        particleCount: 32,
        intensity: 1.3,
      );
      earnStar(0);
    }
    if (was < _kCutRise - 1.2 && s.cutT >= _kCutRise - 1.2) {
      _cue(SoundCue.elementPlant);
      _shake = max(_shake, 4.0);
    }
    if (was < _kCutPry - 0.4 && s.cutT >= _kCutPry - 0.4) {
      _cue(SoundCue.dungeonGateOpen);
      _shake = max(_shake, 5.0);
    }
    if (was < _kCutPry && s.cutT >= _kCutPry) {
      // Follow the roots through: the tendril's first shoot, in the garden.
      cutTo('trellis_garden', kTrellisRootKnuckle, hold: _kCutEnd - _kCutPry);
    }
    if (s.cutT >= _kCutEnd) s.cutT = -1;
  }

  // ── STAR 2 — THE TRELLIS GARDEN ───────────────────────────

  bool _tryTrellis(DungeonCreature a, ConservatoryPlot g) {
    if (!g.trellis) return false;
    if ((a.position - kTrellisRootKnuckle).distance <= _kGreenReach) {
      return _tryTrellisRoot(a);
    }
    for (final ring in kTrellisRings) {
      if (!_standingIn(a, ring.at)) continue;
      _tryTrellisRing(ring);
      return true;
    }
    return false;
  }

  void _tryTrellisRing(TendRing ring) {
    final t = greenhouse.trellis;
    final product = ring.product!;
    final lamp = ring.id == kTrellisWestLightRing.id
        ? TrellisLamp.west
        : ring.id == kTrellisEastLightRing.id
        ? TrellisLamp.east
        : null;
    final done = switch (product) {
      'Water' => t.watered,
      'Ice' => t.frozen,
      _ => t.lit == lamp,
    };
    if (done) {
      _setHint(switch (product) {
        'Water' => 'The soil is already wet, and it stays wet',
        'Ice' => 'The crossing is already frozen, and it stays frozen',
        _ => 'This lamp is already the lit one',
      });
      return;
    }
    final missing = tendMissing(product, _ringElements(ring.at));
    if (missing.isNotEmpty) {
      _refuseRing(ring.at, product, missing);
      return;
    }
    _ringMade(ring.at, product);
    switch (product) {
      case 'Water':
        t.watered = true;
        _green.waterT = 0;
        speakConsequence(
          'Water runs down both beds and the root approach. The soil darkens',
          3.4,
        );
      case 'Ice':
        t.frozen = true;
        _green.freezeT = 0;
        speakConsequence('The pond freezes across the east bed\'s crossing');
      default:
        t.lit = lamp;
        speakConsequence(
          greenhouse.grown
              ? 'The ${lamp == TrellisLamp.west ? 'west' : 'east'} lamp '
                    'draws the glow out of the other. A grown tendril '
                    'doesn\'t move for it'
              : 'The ${lamp == TrellisLamp.west ? 'west' : 'east'} lamp '
                    'lights and draws the glow out of the other',
          3.6,
        );
    }
  }

  bool _tryTrellisRoot(DungeonCreature a) {
    final g = greenhouse;
    if (_green.tendrilMoving) return true; // let it finish
    // Nor is the bud's opening something to pull out of.
    if (_green.budBurstT >= 0 && _green.budBurstT < kBudEnd) return true;
    if (g.grown) {
      g.grown = false;
      _green.tendrilTarget = 0;
      _cue(SoundCue.dungeonSwitch);
      speakConsequence(
        'The tendril draws back to the root. Water, ice and lamp stay as '
        'they are',
        3.2,
      );
      return true;
    }
    final grow = growTendril(g.trellis);
    if (grow.path.isEmpty) {
      _setBlockedHint('The earth is dry');
      _green.ringRefused(kTrellisRootKnuckle);
      return true;
    }
    g.grown = true;
    _green
      ..tendrilPath = grow.path
      ..tendrilStop = grow.stop
      ..tendrilTarget = grow.path.length.toDouble()
      ..tendrilLanded = false;
    _cue(SoundCue.elementPlant);
    return true;
  }

  /// The Bud Star's beats: the burst banks the star, and the pollen reaching
  /// the north door opens it.
  void _updateBudStar(double dt) {
    final s = _green;
    if (s.budBurstT < 0 || s.budBurstT >= 50) return;
    final was = s.budBurstT;
    s.budBurstT += dt;
    final t = s.budBurstT;
    if (was < kBudBurst && t >= kBudBurst) {
      _cue(SoundCue.dungeonGateOpen);
      _shake = max(_shake, 6.0);
      _spawnAlchemyBurst(
        trellisCellCentre(kTrellisIsland),
        producedElement: 'Plant',
        reagentElements: const ['Water', 'Ice', 'Light'],
        particleCount: 34,
        intensity: 1.3,
      );
      earnStar(1);
      // The great plant drops one grey seed into the hub's fourth planter.
      s.seedDropT = 0;
    }
    if (was < kBudDoor && t >= kBudDoor) {
      // The reveal flare plays where the pollen lands, now the door is real.
      _queueDoorReveal('trellis_garden', 'rootbound_door');
      _cue(SoundCue.dungeonSecretReveal);
      _shake = max(_shake, 2.5);
    }
    if (t >= kBudEnd) {
      s.budBurstT = 99;
      // THE CLUE: cut to the hub, where the great plant's crown flowers in
      // the shape of the door's roots — the colours the door will want.
      final hub = layout.rooms['conservatory']!.grove!.greatPlanter!;
      s.crownBloomT = 0;
      cutTo('conservatory', hub - const Offset(0, 150), hold: kCrownCut);
    }
  }

  /// The tendril's unroll, and what happens when its tip arrives.
  void _updateTendril(double dt) {
    final s = _green;
    final target = s.tendrilTarget;
    if ((s.tendrilShown - target).abs() < 1e-6) return;
    final step = dt / _kTendrilTileSeconds;
    if (s.tendrilShown < target) {
      s.tendrilShown = min(target, s.tendrilShown + step);
      if (s.tendrilShown >= target && !s.tendrilLanded) {
        s.tendrilLanded = true;
        _tendrilArrived(s.tendrilStop);
      }
    } else {
      // Pulling back is quicker than growing: it is an undo, not a show.
      s.tendrilShown = max(target, s.tendrilShown - step * 1.8);
    }
  }

  void _tendrilArrived(TendrilStop stop) {
    switch (stop) {
      case TendrilStop.bud:
        if (hasStar(1)) {
          speakConsequence('The tendril winds round the open bud again');
          return;
        }
        // The show runs from `_updateBudStar`; the star banks on the burst.
        _green.budBurstT = 0;
        _cue(SoundCue.elementPlant);
        // Hold the shot on the island for the whole of it.
        cutTo(
          'trellis_garden',
          Offset.lerp(
            trellisCellCentre(kTrellisIsland),
            const Offset(435, 60),
            0.3,
          )!,
          hold: kBudEnd,
        );
      case TendrilStop.bedEnd:
        if (!greenhouse.hatchOpen) {
          greenhouse.hatchOpen = true;
          _green.hatchT = 0;
          _cue(SoundCue.dungeonSecretReveal);
          _shake = max(_shake, 2.5);
          speakConsequence(
            'The tip finds the end of the bed and prises its stone up. There '
            'are steps under it',
            4.2,
          );
        } else {
          speakConsequence('The tendril stops at the stone, prised open');
        }
      case TendrilStop.water:
        speakConsequence('The tendril stops at the edge of open water');
      case TendrilStop.dry:
        speakConsequence('The tendril stops where the earth is dry');
      case TendrilStop.noLight:
        speakConsequence('The tendril waits at the fork. No lamp is lit');
    }
  }

  /// Test seam: play the crown's flowering from its first frame.
  @visibleForTesting
  void debugStartCrownBloom() => _green.crownBloomT = 0;

  // ── THE RITE — THE ROOTBOUND DOOR ─────────────────────────

  bool _tryRite(DungeonCreature a, ConservatoryPlot g) {
    if (!g.rite) return false;
    if ((a.position - kRootStump).distance <= _kGreenReach) {
      return _tryRootStump();
    }
    String? tip;
    for (final e in kRootRings.entries) {
      if (_standingIn(a, e.value.at)) tip = e.key;
    }
    if (tip == null) return false;
    final ring = kRootRings[tip]!.at;
    final g2 = greenhouse;
    if (g2.rootsOpen || hasStar(2)) {
      _setHint('The roots have let go');
      return true;
    }
    if (!guardianRiteUnlocked) {
      _setBlockedHint(
        'The roots won\'t answer until you have the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    final made = ringProduct(_ringElements(ring));
    if (made.both) {
      _setBlockedHint('Not like this');
      _green.ringRefused(ring);
      return true;
    }
    final product = made.product;
    if (product == null) {
      _setBlockedHint('Not yet');
      _green.ringRefused(ring);
      return true;
    }
    if (product == 'Light') {
      // THE GATE: the Crystal in the pair must be a Mask to focus it.
      final masked = _inRing(ring).any(
        (c) =>
            c.member.element == 'Crystal' &&
            abilityForFamily(c.member.family) == DungeonAbility.insight,
      );
      if (!masked) {
        final gate = layout.familyGateFor('root_light');
        if (gate != null) {
          _stampFamilyGate(gate);
        } else {
          _setBlockedHint('Only a Crystal Mask can focus the light');
        }
        _green.ringRefused(ring);
        return true;
      }
    }
    final changed = g2.roots.apply(tip, product);
    if (changed.isEmpty) {
      _setBlockedHint('Nothing takes');
      _green.ringRefused(ring);
      return true;
    }
    _ringMade(ring, product);
    _green.rootsChanged(tip, product, changed);
    if (g2.roots.matches) {
      g2.rootsOpen = true;
      _green.unwindT = -0.9; // let the last climate land first
      _energizeConduit('A');
      _energizeConduit('B');
      _cue(SoundCue.dungeonGateOpen);
      _shake = max(_shake, 5.0);
    }
    onChanged();
    return true;
  }

  /// PRUNE: the roots shed every climate. Free, and as often as you like —
  /// most of the lattice's states can no longer reach the crown.
  bool _tryRootStump() {
    final g = greenhouse;
    if (g.rootsOpen || hasStar(2)) {
      _setHint('The roots have let go');
      return true;
    }
    if (g.roots.bare) {
      _setHint('The roots are bare');
      return true;
    }
    final was = Map.of(g.roots.state);
    g.roots.reset();
    _green.rootsPruned(was);
    _cue(SoundCue.dungeonWallBreak);
    _shake = max(_shake, 2.0);
    onChanged();
    return true;
  }

  // ── STAR 3 — BOTANICA FIGHTS WITH THE CLIMATE ─────────────

  /// §7 — the guardian fights WITH the planet's rule. Each strike turns the
  /// arena too dry, too warm or too dark and holds it there; the lull opens
  /// only after the climate is fixed, and runs in full from that moment.
  /// Runs after the shared cycle in `_updateAltar`, so it owns the window.
  void _updateBotanica(DungeonRoom room, double dt) {
    if (room.guardian == null || room.grove == null) return;
    if (!guardianAwake || guardianArriving || hasStar(2)) return;
    final g = greenhouse;
    final s = _green;
    if (s.lull > 0) {
      s.lull = max(0.0, s.lull - dt);
      guardianVulnerable = s.lull > 0;
      if (s.lull <= 0) _botanicaStrike();
      return;
    }
    guardianVulnerable = false;
    if (s.strikeT >= 0) {
      s.strikeT += dt;
      if (s.strikeT >= _kBotanicaStrike) {
        s.strikeT = -1;
        g.arena = s.strikeClimate;
        g.lastArena = s.strikeClimate;
        _cue(SoundCue.dungeonHazardTrigger);
        _shake = max(_shake, 6.0);
        // A consequence the player must hear (§5.7), from update.
        speakConsequence(
          'The arena is ${climateWord(g.arena!).toLowerCase()}',
          4.0,
        );
      }
      return;
    }
    if (s.restoreT >= 0) {
      s.restoreT += dt;
      if (s.restoreT >= _kBotanicaRestore) {
        s.restoreT = -1;
        s.lull = _kBotanicaLull;
        guardianVulnerable = true;
      }
      return;
    }
    if (g.arena == null) _botanicaStrike();
  }

  void _botanicaStrike() {
    final g = greenhouse;
    final choices = [
      for (final c in Climate.values)
        if (c != g.lastArena) c,
    ];
    _green
      ..strikeClimate = choices[_combatRng.nextInt(choices.length)]
      ..strikeT = 0;
  }

  bool _tryArenaRing(DungeonCreature a, ConservatoryPlot g) {
    if (g.arenaRings.isEmpty) return false;
    Offset? ring;
    for (final r in g.arenaRings) {
      if (_standingIn(a, r)) ring = r;
    }
    if (ring == null) return false;
    final climate = greenhouse.arena;
    if (climate == null) {
      _setHint(
        _green.lull > 0
            ? 'The climate is right. Strike Botanica now'
            : 'Nothing is wrong with the arena yet',
      );
      return true;
    }
    final product = climateFix(climate);
    final missing = tendMissing(product, _ringElements(ring));
    if (missing.isNotEmpty) {
      _refuseRing(ring, product, missing);
      return true;
    }
    _ringMade(ring, product);
    _green
      ..restoreT = 0
      ..restoredClimate = climate;
    greenhouse.arena = null;
    speakConsequence('The arena is right again. Botanica is open to you', 3.4);
    return true;
  }

  /// Botanica's own window is open (its arena put right). It runs on its
  /// own clock, after the shared one `_updateAltar` reads, so the rage aura
  /// asks this the way it asks Wraithord's chime.
  bool get _botanicaLullOpen => _isConservatory && _green.lull > 0;

  /// Is a body at [pos] standing in one of the arena's circles? Idle
  /// companions there hold their ground instead of joining the fight
  /// (`_updateIdleCompanionMovement`).
  bool _conservatoryHoldsBody(Offset pos, DungeonRoom room) {
    for (final r in room.grove?.arenaRings ?? const <Offset>[]) {
      if ((pos - r).distance <= kTendRingReach) return true;
    }
    return false;
  }

  // ── THE LOST MAXIM — THE SEED THAT WANTED THE OPPOSITE ────

  bool get _greySeedPlanted => hasStar(1);

  bool _tryGreySeed(DungeonCreature a, ConservatoryPlot g) {
    final at = g.seedPlanter;
    if (at == null || !_greySeedPlanted) return false;
    if ((a.position - at).distance > _kGreenReach) return false;
    if (discoveredClouds.contains(kPlantOppositeSeedEggId) ||
        _ritePendingEgg == kPlantOppositeSeedEggId) {
      _setHint('It is in bloom, in the shade, the warm and the dry');
      return true;
    }
    final channel = seedChannelFor(a.member.element);
    if (channel == null) {
      _setBlockedHint('Nothing this creature carries runs to the seed');
      return true;
    }
    if (greenhouse.drawn.contains(channel)) {
      _setBlockedHint('That channel is drawn back already');
      return true;
    }
    greenhouse.drawn.add(channel);
    _green.drawChannel(channel);
    _cue(switch (channel) {
      SeedChannel.moisture => SoundCue.elementWater,
      SeedChannel.light => SoundCue.elementCrystal,
      SeedChannel.frost => SoundCue.elementSpirit,
    });
    _spawnAlchemyBurst(
      at,
      producedElement: a.member.element,
      particleCount: 14,
      intensity: 0.8,
    );
    // The plants tell it themselves (the user, 2026-09-27): a leaf
    // uncurls with every channel, and nothing is said.
    if (greenhouse.drawn.length < SeedChannel.values.length) return true;
    _cue(SoundCue.dungeonGateOpen);
    beginMaximRite(kPlantOppositeSeedEggId, at);
    return true;
  }

  /// The one nudge, given once ever, the first time the seed is seen.
  void _greySeedNudge(DungeonCreature a, DungeonRoom room) {
    final at = room.grove?.seedPlanter;
    if (at == null || !_greySeedPlanted) return;
    if (discoveredClouds.contains(kPlantOppositeSeedEggId)) return;
    const id = 'teach:plant_grey_seed';
    if (discoveredClouds.contains(id)) return;
    if ((a.position - at).distance > 150) return;
    _discoverCloud(id);
    speakConsequence('A grey seed. It hated the rooms you healed', 4.2);
  }

  // ── Frame ─────────────────────────────────────────────────

  void _updateConservatory(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isConservatory) return;
    _updateBloomCut(dt);
    _updateTendril(dt);
    _updateBudStar(dt);
    _updateBotanica(room, dt);
    _greySeedNudge(a, room);
  }

  // ── Readouts, hints, insight (§5.6) ──────────────────────

  DungeonProgressReadout? _conservatoryProgressReadout() {
    final room = layout.rooms[currentRoomId];
    final g = room?.grove;
    if (g == null) return null;
    if (g.arenaRings.isNotEmpty && guardianAwake && !hasStar(2)) {
      final c = greenhouse.arena ?? _green.strikeClimateIfLanding;
      return DungeonProgressReadout(
        label: 'ARENA',
        value: c == null
            ? (_green.lull > 0 ? 'OPEN' : 'RIGHT')
            : '${climateWord(c)} · ${climateFix(c).toUpperCase()}',
      );
    }
    if (g.seedPlanter != null &&
        _greySeedPlanted &&
        !discoveredClouds.contains(kPlantOppositeSeedEggId) &&
        greenhouse.drawn.isNotEmpty) {
      final n = greenhouse.drawn.length;
      return DungeonProgressReadout(
        label: 'SEED',
        value: '$n/3',
        fraction: n / 3,
      );
    }
    if (!hasStar(0)) {
      final n = greenhouse.healed.length;
      return DungeonProgressReadout(
        label: 'CLIMATES',
        value: '$n/3',
        fraction: n / 3,
      );
    }
    return null;
  }

  /// WHAT, never HOW (§5.6): each wing says what is wrong with it.
  String? _conservatoryObjectiveHint(DungeonRoom room) {
    final g = room.grove;
    if (g == null) return null;
    if (room.guardian != null) {
      return 'Botanica\'s Heart. The last star is here';
    }
    final wing = g.wing;
    if (wing != null) {
      return greenhouse.healed.contains(wing.climate)
          ? null
          : climateComplaint(wing.climate);
    }
    if (g.trellis) {
      return hasStar(1)
          ? null
          : 'The Trellis Garden. The bud across the pond is sealed';
    }
    if (g.rite) {
      return hasStar(2) ? null : 'The Rootbound Door. The roots are knotted';
    }
    if (room.vaultCache != null) {
      return 'Under the trellis. Something is stored here';
    }
    if (g.greatPlanter != null && !hasStar(0)) {
      return 'The Conservatory. Three wings, and nothing growing';
    }
    return null;
  }

  /// AMBIENT is flavour only (§5.6): no mechanics, no elements, no families.
  void _conservatoryAmbientHint(DungeonCreature a, DungeonRoom room) {
    final g = room.grove;
    final wing = g?.wing;
    if (wing != null &&
        !greenhouse.healed.contains(wing.climate) &&
        (a.position - wing.plant).distance < 120) {
      _setAmbientHint(switch (wing.climate) {
        Climate.dry => 'The leaves crackle when you breathe near them',
        Climate.warm => 'The air shimmers over the vents',
        Climate.dark => 'It has grown toward a light that isn\'t there',
      });
      return;
    }
    final seed = g?.seedPlanter;
    if (seed != null &&
        _greySeedPlanted &&
        (a.position - seed).distance < 120 &&
        !discoveredClouds.contains(kPlantOppositeSeedEggId)) {
      _setAmbientHint('It leans away from the great plant');
    }
  }

  /// INSIGHT is the only channel allowed to teach method (§5.6), tiered by
  /// Intelligence; tiers get shorter, not vaguer.
  void _conservatoryReveal(DungeonCreature a, DungeonRoom room) {
    // BARE, by the user's ruling (2026-09-27): a hint says what is WRONG and
    // nothing about how to fix it — no recipes, no "stand in the ring", no
    // steps. "This room is too dry" is the whole of it. Intelligence buys
    // nothing extra here, so there are no tiers.
    final g = room.grove;
    if (g == null) return;
    if (g.arenaRings.isNotEmpty) {
      final c = greenhouse.arena;
      _setInsightHint(
        c == null
            ? 'Botanica can only be hurt while the arena is right'
            : 'The arena is ${climateWord(c).toLowerCase()}',
      );
      return;
    }
    final wing = g.wing;
    if (wing != null) {
      _setInsightHint(
        greenhouse.healed.contains(wing.climate)
            ? 'It is thriving'
            : climateComplaint(wing.climate),
      );
      return;
    }
    if (g.trellis) {
      _setInsightHint(
        hasStar(1) ? 'The bud is open' : 'The bud across the pond is sealed',
      );
      return;
    }
    if (g.rite) {
      _setInsightHint(
        greenhouse.rootsOpen
            ? 'The roots have let go'
            : 'The roots are knotted',
      );
      return;
    }
    if (room.vaultCache != null) {
      _setInsightHint('Something is stored down here');
      return;
    }
    if (g.greatPlanter != null) {
      _setInsightHint(
        hasStar(0)
            ? 'The great plant opened the way north'
            : 'Nothing is growing',
      );
    }
  }

  /// Per-room mood — the hub is grey daylight, the shadehouse dark until its
  /// light comes, the heart deep green.
  double get _conservatoryMoodTarget => switch (currentRoomId) {
    'conservatory' => hasStar(0) ? 0.74 : 0.6,
    'dry_bed' => 0.7,
    'hothouse' => 0.62,
    'shadehouse' => greenhouse.healed.contains(Climate.dark) ? 0.66 : 0.28,
    'trellis_garden' => 0.66,
    'root_cellar' => 0.24,
    'rootbound_door' => 0.42,
    _ => guardianAwake ? 0.38 : 0.46,
  };

  // ── Planning (planet_dungeon_game_planning.dart) ──────────

  /// A nearby control's consequences, before committing. Describes the rule
  /// — never the solution — and never mutates the live puzzle.
  String? _conservatoryPreview(DungeonCreature a) {
    final g = currentRoom.grove;
    if (g == null) return null;
    if (g.trellis &&
        (a.position - kTrellisRootKnuckle).distance <= _kGreenReach) {
      if (greenhouse.grown) {
        return 'PULL · take the tendril back\n'
            'Free. Water, ice and the lit lamp stay as they are.';
      }
      final grow = growTendril(greenhouse.trellis);
      return 'GROW · ${grow.path.length} tiles\n'
          '${switch (grow.stop) {
            TendrilStop.bud => 'It reaches the bud.',
            TendrilStop.dry => 'It stops at dry earth.',
            TendrilStop.water => 'It stops at open water.',
            TendrilStop.bedEnd => 'It stops at the end of the west bed.',
            TendrilStop.noLight => 'It waits at the fork.',
          }} The ghost shows the route.';
    }
    final seed = g.seedPlanter;
    if (seed != null &&
        _greySeedPlanted &&
        !discoveredClouds.contains(kPlantOppositeSeedEggId) &&
        (a.position - seed).distance <= _kGreenReach) {
      final ch = seedChannelFor(a.member.element);
      if (ch == null || greenhouse.drawn.contains(ch)) return null;
      return 'DRAW BACK · ${switch (ch) {
        SeedChannel.moisture => 'the moisture',
        SeedChannel.light => 'the light',
        SeedChannel.frost => 'the frost',
      }}\n${greenhouse.drawn.length}/3 drawn. The healed wings stay healed.';
    }
    return null;
  }
}
