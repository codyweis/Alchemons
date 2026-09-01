// lib/games/planet_dungeon/planet_dungeon_game_earth.dart
//
// THE BURIED GIANT — the Earth planet's puzzle logic + rendering, as a part
// of planet_dungeon_game.dart (shares the engine's private state the same
// way the Fire cathedral and Water temple do).
//
// World rule: *the dungeon IS a buried body* — rooms are anatomy and the
// bones are the machinery.
//  • Entry — the barrow's lintel has collapsed; an Earth creature raises the
//    fallen stones (one-time reveal, persisted like the other planets').
//  • Star 1 (Marrow) — the rib hall: three fossil ribs on carved tracks.
//    Shoves are TRACK-NOTCH slides (animated grinds, never snaps, never free
//    physics): a rib is a solid wall anywhere on its track EXCEPT settled in
//    the chasm groove (its last notch), where it drops in and becomes
//    walkway. Shoving is a HARD GATE — an Earth HORN and nothing else, one
//    clean grind per notch; the marrow chasm is impassable until bridged, and
//    the sternum plate beyond banks the star once all three ribs lie true.
//  • Star 2 (Crystal) — the pillar crypt: four buried sockets. Lightning
//    arcs them and the lock grows as crystal (Earth+Lightning→Crystal) —
//    ELEMENT-ONLY, so every Lightning family drives the same clean, fast
//    charge. PARITY: a Crystal creature sets the lock directly. Every lock
//    cracks loose bone wisps (the consequence layer, for everyone).
//  • Star 3 (Heart) — behind the rite-shut jaw: the giant's crystal eye
//    watches a stone scale. Each weight sits on a left or right pan; only
//    the giant's remembered arrangement balances it. The eye gives counting
//    feedback ("n of 4 sit true"); Crystal insight reads the answer
//    outright; fiddling shakes crystal wisps loose. Balanced → Terradon.
//  • Lost Maxim — the GIANT'S PALM: an open fossil hand, far off the puzzle
//    path; a Crystal creature laying a crystal in it earns Marcus Aurelius.

part of 'planet_dungeon_game.dart';

/// A live rib slide: from notch → to notch, eased over [dur] seconds.
class _RibSlide {
  _RibSlide({required this.from, required this.to, required this.dur});
  final int from;
  final int to;
  final double dur;
  double t = 0;
  double get progress => Curves.easeInOut.transform((t / dur).clamp(0.0, 1.0));
  bool get done => t >= dur;
}

/// Earth's lost maxim discovery id (screen pays 20 gold on first find).
const String kEarthGiantsPalmEggId = 'egg:earth_giants_palm';

/// The collapsed lintel in the barrow gate (entry rite).
const Offset kBarrowLintel = Offset(330, 265);

/// The giant's open hand in the palm hollow.
const Offset kGiantsPalm = Offset(320, 310);


/// Where each scale-stone's truth is RECORDED in the giant's body. The
/// per-run answer isn't noise to binary-search — it is physically written
/// into four subtle marks across the anatomy, each leaning toward its
/// stone's true pan: the mural-eye's pupil (skull), the roots creeping from
/// the wrist (root), the geode's shard-spray (geode), and the fossil
/// seed-pod's tilt (seed). The prism count remains as verification.
const Map<String, String> kScaleClueRooms = {
  'w_skull': 'skull_antechamber',
  'w_root': 'palm_hollow',
  'w_geode': 'marrow_vault',
  'w_seed': 'pillar_crypt',
};

// Shove tunable: the rib is a HARD Earth+Horn gate, so every shove is clean.
const double _kRibSlideClean = 0.9;

extension BuriedGiant on PlanetDungeonGame {
  // ── State helpers ───────────────────────────────────────

  void _resetBarrowState() {
    _entryReveal = entryDoorRevealed ? 1.0 : 0.0;
    _entryRevealPrev = _entryReveal;
    ribNotches.clear();
    _ribSlides.clear();
    lockedPillars.clear();
    _crystalGrow.clear();
    _pillarCharge.clear();
    _pillarChargeDur.clear();
    scalePanRight.clear();
    scaleToggles = 0;
    _scaleTruthFlash = 0;
    _scaleTiltShown = 0;
    _eyeLook = Offset.zero;
    prismStage = 0;
    _scaleJudged = null;
    _prismCoreRise = 0;
    _prismGrow = 0;
    // The solution itself persists for the run — death doesn't reroll it.
  }

  /// A rib's CURRENT rect: settled at its notch, or mid-grind between two.
  Rect _ribRect(FossilRib rib) {
    final slide = _ribSlides[rib.id];
    Offset center;
    if (slide != null) {
      center = Offset.lerp(
        rib.notches[slide.from],
        rib.notches[slide.to],
        slide.progress,
      )!;
    } else {
      center = rib
          .notches[(ribNotches[rib.id] ?? 0).clamp(0, rib.notches.length - 1)];
    }
    return Rect.fromCenter(
      center: center,
      width: rib.width,
      height: rib.height,
    );
  }

  /// Settled in the chasm groove (last notch, not mid-grind)?
  bool _ribBridging(FossilRib rib) =>
      !_ribSlides.containsKey(rib.id) &&
      (ribNotches[rib.id] ?? 0) == rib.notches.length - 1;

  bool _bridgeComplete(DungeonRoom room) =>
      room.fossilRibs.isNotEmpty && room.fossilRibs.every(_ribBridging);

  /// Rib + chasm collision: ribs are solid walls except settled in the
  /// groove; the chasm is impassable except across a bridging rib.
  bool _barrowBlocksAt(Offset center, DungeonRoom room) {
    for (final rib in room.fossilRibs) {
      if (_ribBridging(rib)) continue; // walkway now
      if (_ribRect(rib).inflate(14).contains(center)) return true;
    }
    final chasm = room.ribChasm;
    if (chasm != null && chasm.contains(center)) {
      for (final rib in room.fossilRibs) {
        if (_ribBridging(rib) && _ribRect(rib).inflate(4).contains(center)) {
          return false; // standing on the bone bridge
        }
      }
      return true;
    }
    return false;
  }

  // ── Update ──────────────────────────────────────────────

  void _updateBarrow(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isBarrow) return;
    if (_scaleTruthFlash > 0) _scaleTruthFlash -= dt;

    // Crystal locks grow out of their sockets (~0.6s each).
    if (_crystalGrow.isNotEmpty) {
      for (final id in _crystalGrow.keys.toList()) {
        final v = (_crystalGrow[id]! + dt / 0.6).clamp(0.0, 1.0);
        _crystalGrow[id] = v;
      }
    }

    // Gaze-prism build: the stone core heaves up, then the crystal grows.
    if (prismStage >= 1 && _prismCoreRise < 1.0) {
      _prismCoreRise = (_prismCoreRise + dt / 0.7).clamp(0.0, 1.0);
    }
    if (prismStage >= 2 && _prismGrow < 1.0) {
      _prismGrow = (_prismGrow + dt / 0.7).clamp(0.0, 1.0);
    }

    // The scale beam eases toward its loaded tilt (weight feels weighty), and
    // the giant's eye tracks you until its lens is built.
    final scale = room.stoneScale;
    if (scale != null) {
      final solved = guardianAwake || hasStar(2);
      final right = scale.weights
          .where((w) => scalePanRight[w.id] ?? false)
          .length;
      final left = scale.weights.length - right;
      final targetTilt = solved ? 0.0 : (right - left) * 0.055;
      _scaleTiltShown += (targetTilt - _scaleTiltShown) * (1 - exp(-dt * 7));

      // Eye gaze target: lock to the lens once seeing, else watch the active
      // creature (clamped so the pupil rides within the iris).
      final eyeC = Offset(room.bounds.center.dx, room.bounds.top + 170);
      final seeing = solved || prismStage >= 2;
      Offset targetLook;
      if (seeing) {
        targetLook = (scale.plinth - eyeC) * 0.06;
      } else {
        final watched = active;
        if (watched != null && watched.alive) {
          final d = watched.position - eyeC;
          final dist = d.distance;
          final dirn = dist > 1 ? d / dist : Offset.zero;
          targetLook = Offset(dirn.dx * 12, dirn.dy * 7);
        } else {
          targetLook = Offset(sin(_time * 0.7) * 7, cos(_time * 0.5) * 4);
        }
      }
      _eyeLook += (targetLook - _eyeLook) * (1 - exp(-dt * 6));
    }

    // The entry dolmen heaves itself upright (shared _entryReveal timer),
    // kicking dust as the stones grind home — discrete puffs as the reveal
    // value crosses each threshold, not a per-frame stream.
    if (_entryReveal < 1.0) {
      for (final mark in const [0.45, 0.82]) {
        if (_entryRevealPrev < mark && _entryReveal >= mark) {
          _spawnAlchemyBurst(
            kBarrowLintel + Offset(0, 34 - 70 * mark),
            producedElement: 'Earth',
            particleCount: 12,
            intensity: 0.7,
          );
        }
      }
    }

    // Charging sockets: the arc draws the storm over its window; when full,
    // the crystal lights. (The defend-the-charge enemy wave was already loosed
    // at charge START in _tryPillar.)
    if (_pillarCharge.isNotEmpty) {
      final done = <String>[];
      for (final id in _pillarCharge.keys.toList()) {
        final v = _pillarCharge[id]! + dt;
        _pillarCharge[id] = v;
        if (v >= (_pillarChargeDur[id] ?? 2.0)) done.add(id);
      }
      for (final id in done) {
        _pillarCharge.remove(id);
        _pillarChargeDur.remove(id);
        _lockPillar(room, id);
      }
    }

    // Animated rib grinds.
    if (_ribSlides.isNotEmpty) {
      final finished = <String>[];
      _ribSlides.forEach((id, slide) {
        slide.t += dt;
        if (slide.done) finished.add(id);
      });
      for (final id in finished) {
        final slide = _ribSlides.remove(id)!;
        ribNotches[id] = slide.to;
        final rib = room.fossilRibs.firstWhere(
          (r) => r.id == id,
          orElse: () => room.fossilRibs.isEmpty
              ? const FossilRib(id: '?', notches: [Offset.zero, Offset.zero])
              : room.fossilRibs.first,
        );
        if (rib.id == id && _ribBridging(rib)) {
          _spawnAlchemyBurst(
            rib.notches.last,
            producedElement: 'Earth',
            particleCount: 18,
            intensity: 0.9,
          );
          final laid = room.fossilRibs.where(_ribBridging).length;
          _setHint(
            laid >= room.fossilRibs.length
                ? 'The last rib drops home — the marrow is bridged'
                : 'The rib drops into the marrow groove — $laid of '
                      '${room.fossilRibs.length}',
            3.0,
          );
          onChanged();
        }
      }
    }

    // Star 1 banks on the sternum plate, once the bridge is whole.
    final ribStar = room.ribStarIndex;
    if (ribStar != null &&
        !hasStar(ribStar) &&
        room.sternumPlate != null &&
        room.sternumPlate!.contains(a.position) &&
        _bridgeComplete(room)) {
      earnStar(ribStar);
    }
  }

  void _lockPillar(DungeonRoom room, String pillarId) {
    if (!lockedPillars.add(pillarId)) return;
    _crystalGrow[pillarId] = 0.0001; // kick off the grow animation

    final pillar = room.fossilPillars.firstWhere(
      (p) => p.id == pillarId,
      orElse: () => room.fossilPillars.first,
    );
    // The charge completes in a bright crystal bloom (the defend-wave already
    // came at charge start, so no new enemies here — this is the payoff).
    _spawnAlchemyBurst(
      pillar.position,
      producedElement: 'Crystal',
      reagentElements: const ['Earth', 'Lightning'],
      particleCount: 26,
      intensity: 1.15,
    );
    final star = room.pillarStarIndex;
    if (star != null &&
        lockedPillars.length >= room.fossilPillars.length &&
        !hasStar(star)) {
      earnStar(star);
    } else {
      _setHint(
        'The socket takes the spark — crystal seals it '
        '(${lockedPillars.length} of ${room.fossilPillars.length})',
        3.0,
      );
    }
    onChanged();
  }

  // ── Utility interactions ────────────────────────────────

  bool _tryBarrow(DungeonCreature a) {
    if (!_isBarrow) return false;
    final room = currentRoom;
    if (_tryBarrowLintel(a, room)) return true;
    if (_tryRib(a, room)) return true;
    if (_tryPillar(a, room)) return true;
    if (_tryGazePrism(a, room)) return true;
    if (_tryScaleWeight(a, room)) return true;
    if (_tryGiantsPalm(a, room)) return true;
    if (_tryBarrowCommune(a, room)) return true;
    return false;
  }

  /// The gaze prism: build the eye its lens (Earth raises the core,
  /// Lightning crystallises it — the planet's own braid; Crystal sets it
  /// direct), then COMMUNE at the standing prism to hear the eye's count.
  /// This is the scale's ONLY reading: stones give no feedback themselves,
  /// so moves are batched and reasoned, Mastermind-style.
  bool _tryGazePrism(DungeonCreature a, DungeonRoom room) {
    final scale = room.stoneScale;
    if (scale == null || hasStar(2)) return false;
    if ((a.position - scale.plinth).distance > 46) return false;
    if (!guardianRiteUnlocked) {
      _setHint(
        'The plinth sleeps — it answers only a bearer of both the '
        '${layout.starName(0)} and ${layout.starName(1)}',
      );
      return true;
    }
    final element = a.member.element;
    switch (prismStage) {
      case 0:
        if (element == 'Earth') {
          prismStage = 1;
          _spawnAlchemyBurst(
            scale.plinth,
            producedElement: 'Earth',
            particleCount: 18,
            intensity: 0.9,
          );
          _setHint(
            'Stone rises on the plinth — now it wants the storm, or '
            'crystal outright',
            3.2,
          );
        } else {
          _setHint(
            'A bare plinth in the eye\'s sightline — stone must rise first',
          );
        }
        return true;
      case 1:
        if (element == 'Lightning' || element == 'Crystal') {
          prismStage = 2;
          _spawnAlchemyBurst(
            scale.plinth,
            producedElement: 'Crystal',
            reagentElements: element == 'Lightning'
                ? const ['Earth', 'Lightning']
                : const ['Crystal'],
            particleCount: 26,
            intensity: 1.15,
          );
          _setHint(
            element == 'Lightning'
                ? 'Earth and Lightning braid into crystal — the prism '
                      'stands, and the EYE TURNS TO LOOK'
                : 'Crystal takes the core whole — the prism stands, and '
                      'the EYE TURNS TO LOOK',
            4.2,
          );
        } else {
          _setHint('The stone core waits — for the storm, or for crystal');
        }
        return true;
      default:
        // The prism stands: communing here is the reading.
        final correct = scale.weights
            .where(
              (w) =>
                  (scalePanRight[w.id] ?? false) ==
                  (scaleSolution[w.id] ?? w.truePanRight),
            )
            .length;
        _spawnAlchemyBurst(
          scale.plinth,
          producedElement: 'Crystal',
          particleCount: 10,
          intensity: 0.6,
        );
        // The count is STATE, not speech — the eye's judgment snapshots
        // into the progress readout (§5.6); the capsule keeps only the
        // communing itself.
        _scaleJudged = correct;
        _setHint('The eye gazes through the prism, and judges', 4.0);
        onChanged();
        return true;
    }
  }

  /// The entry rite: Earth raises the fallen lintel.
  bool _tryBarrowLintel(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'barrow_gate') return false;
    if ((a.position - kBarrowLintel).distance > 46) return false;
    if (entryDoorRevealed) {
      _setHint('The lintel stands raised, the way within open');
      return true;
    }
    if (a.member.element != 'Earth') {
      _setHint('Fallen stone bars the way — it answers earthen strength');
      return true;
    }
    entryDoorRevealed = true;
    _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist
    final doorCenter = room.doors.isNotEmpty
        ? room.doors.first.rect.center
        : a.position;
    _setHint('The stones remember their place — the lintel rises');
    _spawnAlchemyBurst(
      kBarrowLintel,
      producedElement: 'Earth',
      particleCount: 30,
      intensity: 1.2,
    );
    _spawnAlchemyBurst(
      doorCenter,
      producedElement: 'Earth',
      particleCount: 22,
      intensity: 1.0,
    );
    return true;
  }

  /// Star 1: shove a rib one notch along its track. A HARD GATE — Earth+Horn
  /// and nothing else. Direction follows which side of the rib you stand on.
  bool _tryRib(DungeonCreature a, DungeonRoom room) {
    final star = room.ribStarIndex;
    if (room.fossilRibs.isEmpty || star == null || hasStar(star)) {
      return false;
    }
    for (final rib in room.fossilRibs) {
      if (!_ribRect(rib).inflate(38).contains(a.position)) continue;
      if (_ribSlides.containsKey(rib.id)) {
        _setHint('The bone is still grinding — let it settle');
        return true;
      }
      if (_ribBridging(rib)) {
        _setHint('This rib lies true in its groove');
        return true;
      }
      // HARD GATE: the giant's ribs are Earth + Horn. Nothing else shifts bone.
      final r = evaluateInteraction(
        a.member,
        const DungeonInteractionRequirement(
          element: 'Earth',
          requiredFamily: DungeonAbility.heavyForce,
        ),
      );
      if (r == InteractionResult.blockedFamily) {
        // The refusal stamps ⛰ HORN onto the descent panel — once, forever
        // ("the seal remembers", §4). One logical gate covers all three ribs.
        final gate = layout.familyGateFor('rib');
        if (gate != null) {
          _stampFamilyGate(gate);
        } else {
          _setBlockedHint('Only an Earth horn\'s force shifts this bone');
        }
        return true;
      }
      if (!interactionSucceeded(r)) {
        _setHint('The giant\'s bones move only for earthen strength');
        return true;
      }
      final cur = ribNotches[rib.id] ?? 0;
      // Which way? The shover stands on one side of the track axis.
      final axis = rib.notches.last - rib.notches.first;
      final axisLen = axis.distance;
      final dirn = axisLen > 0 ? axis / axisLen : const Offset(1, 0);
      final rel = a.position - _ribRect(rib).center;
      final along = rel.dx * dirn.dx + rel.dy * dirn.dy;
      final forward = along < 0; // standing behind → shove onward
      final target = forward ? cur + 1 : cur - 1;
      if (target < 0 || target >= rib.notches.length) {
        _setHint('The rib will not grind further that way');
        return true;
      }
      _ribSlides[rib.id] = _RibSlide(
        from: cur,
        to: target,
        dur: _kRibSlideClean,
      );
      _spawnAlchemyBurst(
        _ribRect(rib).center,
        producedElement: 'Earth',
        reagentElements: [a.member.element],
        particleCount: 14,
        intensity: 0.8,
      );
      _setHint('One clean shove — the rib grinds along its track');
      return true;
    }
    return false;
  }

  /// Star 2: arc a buried socket. The socket must CHARGE before the crystal
  /// lights — and the charge wakes the marrow AT ONCE, for EVERYONE, so the
  /// player defends the socket until it fills. ELEMENT-ONLY: any Lightning
  /// charges it; Crystal sets it direct (parity).
  bool _tryPillar(DungeonCreature a, DungeonRoom room) {
    final star = room.pillarStarIndex;
    if (room.fossilPillars.isEmpty || star == null || hasStar(star)) {
      return false;
    }
    for (final pillar in room.fossilPillars) {
      if ((a.position - pillar.position).distance > 50) continue;
      if (lockedPillars.contains(pillar.id)) {
        _setHint('This socket already burns with crystal');
        return true;
      }
      if (_pillarCharge.containsKey(pillar.id)) {
        _setHint(
          'The socket is charging — hold the marrow off until it lights',
        );
        return true;
      }
      final element = a.member.element;
      double dur;
      int waveCount;
      bool unstable;
      String hint;
      if (element == 'Crystal') {
        // PARITY: what the Earth+Lightning braid grows, Crystal sets direct.
        dur = 2.0;
        waveCount = 2;
        unstable = false;
        hint = 'Crystal floods the socket — guard it while it sets';
      } else if (element == 'Lightning') {
        // ELEMENT-ONLY: any Lightning drives the same clean, fast charge.
        dur = 2.0;
        waveCount = 2;
        unstable = false;
        hint = 'The spark slips clean into the socket — defend its charge';
      } else {
        _setHint(
          'A buried socket — storm-spark would wake it, or crystal '
          'seal it outright',
        );
        return true;
      }
      _pillarCharge[pillar.id] = 0.0;
      _pillarChargeDur[pillar.id] = dur;
      _spawnAlchemyBurst(
        pillar.position,
        producedElement: 'Crystal',
        reagentElements: element == 'Crystal'
            ? const ['Crystal']
            : const ['Earth', 'Lightning'],
        particleCount: 14,
        intensity: 0.8,
      );
      // The consequence is now an ACTIVE fight: the wave comes immediately.
      spawnWispWave(
        element: 'Earth',
        center: pillar.position,
        count: waveCount,
        unstable: unstable,
        announce: false,
      );
      _setHint(hint, 3.0);
      return true;
    }
    return false;
  }

  /// Star 3: toggle a scale weight between pans. The eye counts the truth.
  bool _tryScaleWeight(DungeonCreature a, DungeonRoom room) {
    final scale = room.stoneScale;
    if (scale == null || hasStar(2)) return false;
    for (final w in scale.weights) {
      if ((a.position - w.position).distance > 46) continue;
      if (!guardianRiteUnlocked) {
        _setHint(
          'The scale sleeps — it answers only a bearer of both the '
          '${layout.starName(0)} and ${layout.starName(1)}',
        );
        return true;
      }
      if (guardianAwake) {
        _setHint('The scale stands true — the heart already beats');
        return true;
      }
      scalePanRight[w.id] = !(scalePanRight[w.id] ?? false);
      scaleToggles++;
      _spawnAlchemyBurst(
        w.position,
        producedElement: 'Earth',
        reagentElements: const ['Crystal'],
        particleCount: 12,
        intensity: 0.7,
      );
      // The consequence layer: fiddling shakes the marrow loose.
      if (scaleToggles % 3 == 0) {
        spawnWispWave(
          element: 'Crystal',
          center: scale.position,
          count: 2,
          announce: false,
        );
      }
      final correct = scale.weights
          .where(
            (sw) =>
                (scalePanRight[sw.id] ?? false) ==
                (scaleSolution[sw.id] ?? sw.truePanRight),
          )
          .length;
      if (correct >= scale.weights.length) {
        guardianAwake = true;
        guardianHp = PlanetDungeonGame.maxGuardianHp;
        _setHint(
          'The scale stands true — beneath you, the heart begins to BEAT',
          4.2,
        );
        spawnWispWave(
          element: 'Earth',
          center: scale.position,
          count: 3,
          unstable: true,
          announce: false,
        );
      } else {
        // NO streaming feedback: the stones say nothing. The count lives at
        // the gaze prism — batch your moves, then go and ask the eye.
        final movedName = w.id.startsWith('w_') ? w.id.substring(2) : w.id;
        final nowRight = scalePanRight[w.id] ?? false;
        _setHint(
          'The $movedName-stone settles on the ${nowRight ? 'right' : 'left'} pan',
        );
      }
      onChanged();
      return true;
    }
    return false;
  }

  /// The Lost Maxim: lay a crystal in the giant's open palm. Wordless until
  /// won; the maxim is the fanfare.
  bool _tryGiantsPalm(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'palm_hollow') return false;
    if (discoveredClouds.contains(kEarthGiantsPalmEggId)) return false;
    if (a.member.element != 'Crystal') return false;
    if ((a.position - kGiantsPalm).distance > 34) return false;
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    beginMaximRite(kEarthGiantsPalmEggId, kGiantsPalm);
    _spawnAlchemyBurst(
      kGiantsPalm,
      producedElement: 'Crystal',
      reagentElements: const ['Earth'],
      particleCount: 26,
      intensity: 1.1,
    );
    _setHint('A crystal takes root in the open palm', 4.0);
    return true;
  }

  /// The 3-star secret: commune at the sternum court's heart.
  bool _tryBarrowCommune(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'sternum_court' || starsEarnedCount < 3) return false;
    if ((a.position - room.bounds.center).distance >= 34) return false;
    _setHint(
      'The dust settles utterly still. Before the burial, Terradon shaped '
      'these bones from the first mountain — the giant remembers, and now '
      'it rests.',
      7.5,
    );
    _spawnAlchemyBurst(
      room.bounds.center,
      producedElement: 'Light',
      reagentElements: const ['Earth'],
      particleCount: 20,
      intensity: 0.8,
    );
    return true;
  }

  // ── Mask insight ────────────────────────────────────────

  void _barrowReveal(DungeonCreature a, DungeonRoom room) {
    revealFlash = 0.6;
    revealTier = revealHintTier(a.member.statIntelligence);
    switch (room.id) {
      case 'rib_hall':
        _setHint(
          'The grooves remember three roads east — shove the bones home '
          'and the marrow is bridged',
          3.8,
        );
        return;
      case 'pillar_crypt':
        _setHint(
          revealTier >= 1
              ? 'Four sockets sleep beneath the pillars — storm-spark '
                    'wakes them as crystal'
              : 'Four sockets sleep beneath the pillars — more '
                    'Intelligence would read what wakes them',
          3.8,
        );
        return;
      case 'skull_antechamber':
        _setHint(
          'The bone-mural completes — the eye weighs four stones, and the '
          'giant\'s own body remembers each one\'s pan: read the leaning '
          'marks across its bones',
          5.0,
        );
        return;
      case 'eye_chamber':
        final scale = room.stoneScale;
        if (scale == null) break;
        if (prismStage < 2) {
          // The eye is BLIND until its lens stands.
          _setHint(
            'The eye stares at the bare plinth and sees nothing — raise '
            'it a lens of stone and storm',
            4.0,
          );
          return;
        }
        if (revealTier >= 2) {
          // The glow that used to fire here lit every stone's TRUE pan for six
          // seconds — the answer, handed over by a button press. A question
          // must not edit the world, and this was the largest thing any
          // reading did. Gone; the line describes the evidence instead, which
          // is what the rest of the tiers already do.
          _setHint(
            'The prism sharpens every grain — each stone wears which pan it '
            'was cut to ride',
            4.2,
          );
        } else {
          final correct = scale.weights
              .where(
                (sw) =>
                    (scalePanRight[sw.id] ?? false) ==
                    (scaleSolution[sw.id] ?? sw.truePanRight),
              )
              .length;
          _setHint(
            'Through the prism the eye flickers — $correct of '
            '${scale.weights.length} stones sit true; sharper insight '
            'would name them',
            3.8,
          );
        }
        return;
      case 'palm_hollow':
        // The egg's single oblique hint.
        _setHint(
          'The hand lies open. It has held nothing for an age — and '
          'misses it.',
          3.6,
        );
        return;
      case 'barrow_gate':
        _setHint(
          entryDoorRevealed
              ? 'The lintel stands; the barrow breathes'
              : 'The fallen stones ache to be stood back up',
        );
        return;
      case 'heart_chamber':
        _setHint(
          guardianAwake
              ? 'Terradon\'s fury ebbs in waves — strike in the lull'
              : 'The great heart hangs still — the scale will wake it',
          3.6,
        );
        return;
    }
    _setHint(_nothingHiddenLine());
  }

  // ── Ambient hints / objectives / mood ───────────────────

  /// The eye's last spoken judgment, glanceable beside the star tracker
  /// (§5.6). A snapshot of the LAST communion — never live, so the scale
  /// stays a batched Mastermind deduction, not a hot-cold meter.
  DungeonProgressReadout? get _barrowProgressReadout {
    final scale = currentRoom.stoneScale;
    if (scale == null || hasStar(2) || prismStage < 2) return null;
    final judged = _scaleJudged;
    if (judged == null) return null;
    return DungeonProgressReadout(
      label: 'STONES',
      value: '$judged of ${scale.weights.length} true',
      fraction: judged / scale.weights.length,
    );
  }

  void _barrowAmbientHint(DungeonCreature a, DungeonRoom room) {
    // A leaning bone-mark recording one scale-stone's true pan.
    if (!hasStar(2) && !guardianAwake) {
      final stoneId = kScaleClueRooms.entries
          .where((e) => e.value == room.id)
          .map((e) => e.key)
          .firstOrNull;
      if (stoneId != null && scaleSolution.containsKey(stoneId)) {
        final clueC = switch (room.id) {
          'skull_antechamber' => Offset(
            room.bounds.left + 90,
            room.bounds.top + 120,
          ),
          'palm_hollow' => kGiantsPalm + const Offset(0, 64),
          'marrow_vault' => room.bounds.center + const Offset(0, 70),
          'pillar_crypt' => room.bounds.center,
          _ => room.bounds.center,
        };
        if ((a.position - clueC).distance <= 64) {
          final right = scaleSolution[stoneId]!;
          final stoneName = stoneId.startsWith('w_')
              ? stoneId.substring(2)
              : stoneId;
          // The authored clue layer: the mark itself is the world's reading
          // — state the observation, let the player draw the conclusion.
          _setAmbientHint(
            'The $stoneName-mark leans ${right ? 'right' : 'left'} here',
          );
          return;
        }
      }
    }
    if (room.ribStarIndex != null && !hasStar(room.ribStarIndex!)) {
      for (final rib in room.fossilRibs) {
        if (_ribBridging(rib)) continue;
        if (!_ribRect(rib).inflate(52).contains(a.position)) continue;
        _setAmbientHint(
          a.member.element == 'Earth'
              ? 'The rib sits loose in its carved track'
              : 'A fossil rib, seated in a carved track',
        );
        return;
      }
    }
    if (room.pillarStarIndex != null && !hasStar(room.pillarStarIndex!)) {
      for (final pillar in room.fossilPillars) {
        if ((a.position - pillar.position).distance > 64) continue;
        if (lockedPillars.contains(pillar.id)) return;
        _setAmbientHint(
          a.member.element == 'Lightning'
              ? 'The buried socket hums against your charge'
              : 'A buried socket, dark beneath the pillar',
        );
        return;
      }
    }
    final scale = room.stoneScale;
    if (scale != null && !hasStar(2) && !guardianAwake) {
      if ((a.position - scale.plinth).distance <= 60 && prismStage < 2) {
        _setAmbientHint(
          prismStage == 0
              ? 'A bare plinth stands in the eye\'s sightline'
              : 'Raw stone rests on the plinth, unfinished',
        );
        return;
      }
      for (final w in scale.weights) {
        if ((a.position - w.position).distance > 60) continue;
        _setAmbientHint('A scale-stone, graven with an old sigil');
        return;
      }
    }
    if (room.id == 'barrow_gate' && !entryDoorRevealed) {
      if ((a.position - kBarrowLintel).distance <= 70) {
        _setAmbientHint('The fallen lintel lies broken across the way');
      }
    }
  }

  String? _barrowObjectiveHint(DungeonRoom room) {
    switch (room.id) {
      case 'barrow_gate':
        return entryDoorRevealed
            ? null
            : 'Barrow Gate — the lintel has fallen; earthen strength '
                  'raises it';
      case 'rib_hall':
        return 'Rib Hall — shove the three ribs home and bridge the marrow';
      case 'pillar_crypt':
        // WHAT, never HOW (§5.6): the storm-into-crystal method is the
        // bone-mural's earned reading (_barrowReveal).
        return 'Pillar Crypt — something sleeps beneath the four pillars';
      case 'palm_hollow':
        return null; // the egg keeps its silence
      case 'skull_antechamber':
        return hasStar(2)
            ? null
            : 'Skull Antechamber — the bone-mural diagrams the rite ahead';
      case 'eye_chamber':
        // Both were procedures — "build it a lens of stone and storm", then
        // "set the stones, THEN ask the eye". State only; the lens and the
        // order it wants are the bone-mural's to give.
        return prismStage < 2
            ? 'Eye Chamber — the eye is blind, and its prism is unmade'
            : 'Eye Chamber — the prism stands, and the eye has not spoken';
      case 'heart_chamber':
        return guardianAwake
            ? 'The Heart — Terradon rises'
            : 'The Heart — utterly still; the scale has not spoken';
    }
    return null;
  }

  double get _barrowMoodTarget => switch (currentRoomId) {
    'barrow_gate' => entryDoorRevealed ? 0.55 : 0.42,
    'sternum_court' => 0.52,
    'rib_hall' => 0.48,
    'marrow_vault' => 0.56,
    'pillar_crypt' => 0.45,
    'palm_hollow' => 0.58,
    'skull_antechamber' => 0.34,
    'eye_chamber' => 0.3,
    'heart_chamber' => guardianAwake ? 0.18 : 0.26,
    _ => 0.5,
  };

  // ── Render: screen-space atmosphere ─────────────────────

  void _drawBarrowFallbackSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [
            Color(0xFF0C0905), // packed dark earth
            Color(0xFF241A10), // strata mid
            Color(0xFF3E2E1A), // amber-lit depths
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  /// Ambient grave-dust: a handful of motes sifting slowly DOWN on
  /// staggered loops. 4 glow blits per frame.
  void _drawDustSift(Canvas canvas, Size vp) {
    if (!_fx.ready) return;
    for (var i = 0; i < 4; i++) {
      final speed = 16.0 + i * 6;
      final span = vp.height + 90;
      final travel = (_time * speed + i * 233) % span;
      final y = travel - 40;
      final x =
          vp.width * (0.18 + 0.21 * i) +
          sin(_time * (0.5 + i * 0.19) + i * 2.4) * 26;
      final fade = (travel / span).clamp(0.0, 1.0);
      drawGlow(
        canvas,
        _fx.mote!,
        Offset(x, y),
        3.0 + i * 0.7,
        Color.lerp(
          const Color(0xFFD8B878),
          const Color(0xFF8A6E48),
          fade,
        )!.withValues(alpha: (0.20 * (1 - fade) + 0.04).clamp(0.0, 0.24)),
      );
    }
  }

  // ── Render: world-space ─────────────────────────────────

  /// Barrow flooring: bone-ochre packed earth — TRANSLUCENT (alpha ≈
  /// 0.5–0.6) so the strata shader glows through.
  void _renderBarrowFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final rr = RRect.fromRectAndRadius(b.deflate(8), const Radius.circular(26));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          const Color(0xFF1E1812).withValues(alpha: 0.50),
          const Color(0xFF120E08).withValues(alpha: 0.58),
        ]),
    );
    // THE GROUND IS STRATA, NOT GRAPH PAPER.
    //
    // It used to be a 110px square grid of seams. Every room in the barrow
    // therefore sat on a sheet of graph paper, which is the single biggest
    // reason nine chambers of a BURIED BODY read as diagrams of their own
    // mechanics. Earth is the one planet whose ground is the story: the giant
    // sank through ages, and the ages are still lying on top of it in bands.
    //
    // Bands, then, with irregular boundaries — a straight line is a drawing
    // and a wavering one is a deposit. Deterministic per room (seeded off the
    // bounds), so the ground does not crawl between frames.
    final seed = (b.width * 31 + b.height * 17).toInt();
    double wob(int i, double x) =>
        sin((x + seed + i * 137) * 0.0121 + i * 2.3) * (5 + (i % 3) * 3.5);

    const bands = 7;
    for (var i = 1; i < bands; i++) {
      final y = b.top + b.height * i / bands;
      // The band's own body, laid under its boundary so the seam sits ON a
      // change of colour rather than floating over one flat tone.
      final path = Path()..moveTo(b.left, y + wob(i, b.left));
      for (var x = b.left; x <= b.right; x += 26) {
        path.lineTo(x, y + wob(i, x));
      }
      path.lineTo(b.right, b.bottom);
      path.lineTo(b.left, b.bottom);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = (i.isEven
                  ? const Color(0xFF241B12)
                  : const Color(0xFF1A140D))
              .withValues(alpha: 0.34),
      );
      // The seam itself: a pale line of older grit pressed between the ages.
      final seam = Path()..moveTo(b.left, y + wob(i, b.left));
      for (var x = b.left; x <= b.right; x += 26) {
        seam.lineTo(x, y + wob(i, x));
      }
      canvas.drawPath(
        seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF8A6E48).withValues(alpha: 0.10),
      );
    }

    // BONE FLECK AND ROOT. What is actually in the dirt over a giant: chips
    // of it, and the roots that came down looking for it. Sparse, small and
    // deterministic — this is texture, not a particle system.
    final chip = Paint()..color = const Color(0xFFB8A070).withValues(alpha: 0.13);
    final root = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4A3A22).withValues(alpha: 0.4);
    for (var i = 0; i < 34; i++) {
      final u = ((i * 2654435761) % 1000) / 1000.0;
      final v = ((i * 40503 + seed) % 997) / 997.0;
      final at = Offset(b.left + 20 + u * (b.width - 40),
          b.top + 20 + v * (b.height - 40));
      if (i % 4 == 0) {
        // A root thread, feeling downward.
        canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy)
            ..quadraticBezierTo(
              at.dx + 7 * (i.isEven ? 1 : -1),
              at.dy + 13,
              at.dx + 2 * (i.isEven ? -1 : 1),
              at.dy + 27,
            ),
          root,
        );
      } else {
        // A chip of the giant, edge-on.
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(u * pi);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 5 + (i % 3) * 2.0, height: 2),
            const Radius.circular(1),
          ),
          chip,
        );
        canvas.restore();
      }
    }
    if (_fx.ready) {
      final cols = (b.width / 130).clamp(3, 9).toInt();
      for (var i = 0; i < cols; i++) {
        final x = b.left + (i + 0.5) / cols * b.width;
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, b.top + 8),
          120,
          const Color(0xFF171208).withValues(alpha: 0.55),
        );
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, b.bottom - 8),
          120,
          const Color(0xFF120E08).withValues(alpha: 0.6),
        );
      }
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFD8B878).withValues(alpha: 0.12),
    );
  }

  void _renderBarrow(Canvas canvas, DungeonRoom room) {
    switch (room.id) {
      case 'barrow_gate':
        _drawBarrowLintel(canvas);
        break;
      case 'sternum_court':
        _drawSternumCourt(canvas, room);
        break;
      case 'rib_hall':
        _drawRibHall(canvas, room);
        break;
      case 'marrow_vault':
        _drawMarrowShrine(canvas, room.bounds.center);
        break;
      case 'pillar_crypt':
        _drawPillarCrypt(canvas, room);
        break;
      case 'palm_hollow':
        _drawGiantsPalm(canvas);
        break;
      case 'skull_antechamber':
        _drawBoneMural(canvas, room);
        break;
      case 'eye_chamber':
        _drawEyeAndScale(canvas, room);
        break;
      case 'heart_chamber':
        _drawHeartChamber(canvas, room);
        break;
    }
    _drawScaleClue(canvas, room);
  }

  /// A small carved sigil identifying which scale-stone a mark belongs to.
  /// The SAME glyph is engraved on the stone's scale-marker and beside its
  /// leaning clue-arrow, so a player matches mark→stone by symbol (skull /
  /// root / geode / seed) rather than guessing.
  void _drawStoneSigil(
    Canvas canvas,
    Offset c,
    String id,
    Color color,
    double r,
  ) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = color;
    switch (id) {
      case 'w_skull':
        // A little skull: domed cranium, square jaw, two hollow eyes.
        canvas.drawArc(
          Rect.fromCircle(center: c + Offset(0, r * 0.05), radius: r * 0.78),
          pi,
          pi,
          false,
          p,
        );
        canvas.drawLine(
          c + Offset(-r * 0.55, r * 0.05),
          c + Offset(-r * 0.38, r * 0.55),
          p,
        );
        canvas.drawLine(
          c + Offset(r * 0.55, r * 0.05),
          c + Offset(r * 0.38, r * 0.55),
          p,
        );
        canvas.drawLine(
          c + Offset(-r * 0.38, r * 0.55),
          c + Offset(r * 0.38, r * 0.55),
          p,
        );
        final eye = Paint()..color = color;
        canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.02), r * 0.15, eye);
        canvas.drawCircle(c + Offset(r * 0.3, -r * 0.02), r * 0.15, eye);
        break;
      case 'w_root':
        // A forking taproot.
        canvas.drawLine(c + Offset(0, -r * 0.85), c + Offset(0, r * 0.2), p);
        canvas.drawLine(
          c + Offset(0, r * 0.2),
          c + Offset(-r * 0.6, r * 0.85),
          p,
        );
        canvas.drawLine(
          c + Offset(0, r * 0.2),
          c + Offset(r * 0.55, r * 0.8),
          p,
        );
        canvas.drawLine(c + Offset(0, r * 0.2), c + Offset(0, r * 0.85), p);
        break;
      case 'w_geode':
        // A faceted gem.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r * 0.85)
            ..lineTo(c.dx + r * 0.7, c.dy - r * 0.05)
            ..lineTo(c.dx, c.dy + r * 0.85)
            ..lineTo(c.dx - r * 0.7, c.dy - r * 0.05)
            ..close(),
          p,
        );
        canvas.drawLine(
          c + Offset(-r * 0.7, -r * 0.05),
          c + Offset(r * 0.7, -r * 0.05),
          p,
        );
        canvas.drawLine(c + Offset(0, -r * 0.85), c + Offset(0, r * 0.85), p);
        break;
      case 'w_seed':
        // A pointed seed-pod with a central vein.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r * 0.9)
            ..quadraticBezierTo(
              c.dx + r * 0.7,
              c.dy - r * 0.05,
              c.dx,
              c.dy + r * 0.85,
            )
            ..quadraticBezierTo(
              c.dx - r * 0.7,
              c.dy - r * 0.05,
              c.dx,
              c.dy - r * 0.9,
            )
            ..close(),
          p,
        );
        canvas.drawLine(c + Offset(0, -r * 0.5), c + Offset(0, r * 0.55), p);
        break;
    }
  }

  /// The giant's body REMEMBERS the scale's answer: in each clue room, the
  /// recorded stone's mark leans toward its true pan (left/right). The answer
  /// is rolled per run but it is NEVER noise — it is written into the
  /// anatomy, and the prism count merely verifies what the body already
  /// told. Faded out once the scale stands true (the memory has served).
  void _drawScaleClue(Canvas canvas, DungeonRoom room) {
    if (hasStar(2) || guardianAwake) return;
    final stoneId = kScaleClueRooms.entries
        .where((e) => e.value == room.id)
        .map((e) => e.key)
        .firstOrNull;
    if (stoneId == null || !scaleSolution.containsKey(stoneId)) return;
    final right = scaleSolution[stoneId]!;
    final dir = right ? 1.0 : -1.0;
    // Anchor the mark to each room's signature feature.
    final c = switch (room.id) {
      'skull_antechamber' => Offset(
        room.bounds.left + 90,
        room.bounds.top + 120,
      ),
      'palm_hollow' => kGiantsPalm + const Offset(0, 64),
      'marrow_vault' => room.bounds.center + const Offset(0, 70),
      'pillar_crypt' => room.bounds.center,
      _ => room.bounds.center,
    };
    // A carved bone-groove that curves the way the stone leans, with a
    // crystal glint at its leaning tip — subtle, but unmistakable once seen.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8A6E48).withValues(alpha: 0.55);
    final path = Path()
      ..moveTo(c.dx - dir * 26, c.dy + 8)
      ..quadraticBezierTo(c.dx, c.dy - 10, c.dx + dir * 26, c.dy - 4);
    canvas.drawPath(path, groove);
    // A short barb at the leaning tip, like an arrowhead etched in bone.
    final tip = Offset(c.dx + dir * 26, c.dy - 4);
    canvas.drawLine(tip, tip + Offset(-dir * 9, -7), groove);
    canvas.drawLine(tip, tip + Offset(-dir * 9, 7), groove);
    // The stone's sigil, carved above the mark — names WHICH stone leans.
    _drawStoneSigil(
      canvas,
      c + const Offset(0, -26),
      stoneId,
      const Color(0xFFD8B878).withValues(alpha: 0.7),
      9,
    );
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.mote!,
        tip,
        5,
        const Color(
          0xFFB8E0D8,
        ).withValues(alpha: 0.28 + 0.16 * sin(_time * 2.4 + c.dx)),
      );
    }
  }

  /// One carved dolmen stone, as actual masonry (a beveled, outlined slab)
  /// rather than a line — drawn rotated about its own centre so it can heave
  /// up from a tumbled angle into place.
  void _drawDolmenStone(
    Canvas canvas,
    Offset center,
    double w,
    double h,
    double angle, {
    double alpha = 1.0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    // Grounded shadow under the slab.
    canvas.drawRRect(
      rr.shift(const Offset(2.5, 3.5)),
      Paint()..color = const Color(0xFF120C06).withValues(alpha: 0.45 * alpha),
    );
    // Stone body.
    canvas.drawRRect(
      rr,
      Paint()..color = const Color(0xFF6B5436).withValues(alpha: 0.95 * alpha),
    );
    // Lit top bevel (the giant's stone catches the barrow light).
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 2, rect.top + 2, w - 4, h * 0.34),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF8F7349).withValues(alpha: 0.85 * alpha),
    );
    // Carved outline.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF3A2C1A).withValues(alpha: 0.85 * alpha),
    );
    canvas.restore();
  }

  /// A scatter of small fallen rubble — the debris a collapsed barrow leaves
  /// strewn at its feet. Tiny filled pebbles with a grounded shadow; static
  /// (fixed offsets) so they don't shimmer frame to frame.
  void _drawRubble(Canvas canvas, Offset base) {
    const chunks = [
      (-60.0, 40.0, 6.5),
      (-38.0, 47.0, 4.0),
      (-12.0, 44.0, 5.5),
      (8.0, 49.0, 3.5),
      (28.0, 45.0, 5.0),
      (52.0, 42.0, 6.5),
      (44.0, 50.0, 3.5),
      (-26.0, 51.0, 3.0),
    ];
    for (final (dx, dy, s) in chunks) {
      final p = base + Offset(dx, dy);
      canvas.drawCircle(
        p + const Offset(1.5, 2),
        s,
        Paint()..color = const Color(0xFF120C06).withValues(alpha: 0.4),
      );
      canvas.drawCircle(
        p,
        s,
        Paint()..color = const Color(0xFF5C4830).withValues(alpha: 0.92),
      );
      // A small lit cap so each pebble catches the barrow light.
      canvas.drawCircle(
        p - Offset(s * 0.3, s * 0.35),
        s * 0.5,
        Paint()..color = const Color(0xFF856A44).withValues(alpha: 0.7),
      );
    }
  }

  void _drawBarrowLintel(Canvas canvas) {
    const c = kBarrowLintel;
    final r = _entryReveal.clamp(0.0, 1.0);

    // Loose rubble strewn at the dolmen's feet (drawn first so the standing
    // stones overlap it).
    _drawRubble(canvas, c);

    // The uprights heave up first; the capstone only settles once they stand.
    final postT = Curves.easeOutCubic.transform(r);
    final capT = Curves.easeOutBack.transform(
      ((r - 0.4) / 0.6).clamp(0.0, 1.0),
    );

    // Left upright: from tumbled-aslant on the ground → vertical post.
    final leftCenter = Offset.lerp(
      c + const Offset(-40, 30),
      c + const Offset(-44, 4),
      postT,
    )!;
    _drawDolmenStone(canvas, leftCenter, 20, 70, -0.62 * (1 - postT));

    // Right upright: tumbled the other way → vertical post.
    final rightCenter = Offset.lerp(
      c + const Offset(38, 33),
      c + const Offset(44, 4),
      postT,
    )!;
    _drawDolmenStone(canvas, rightCenter, 20, 70, 0.5 * (1 - postT));

    // Capstone: fallen aslant across the rubble → settles level on the posts.
    final capCenter = Offset.lerp(
      c + const Offset(-2, 24),
      c + const Offset(0, -42),
      capT,
    )!;
    _drawDolmenStone(canvas, capCenter, 124, 22, 0.4 * (1 - capT));

    // Warm light breathes through the standing arch once it's home.
    if (_fx.ready && r > 0.85) {
      drawGlow(
        canvas,
        _fx.glow!,
        c + const Offset(0, -6),
        38,
        const Color(0xFFD8B878).withValues(
          alpha:
              ((r - 0.85) / 0.15).clamp(0.0, 1.0) *
              (0.14 + 0.05 * sin(_time * 1.8)),
        ),
      );
    }

    // Flanking columns by the inner doors.
    final col = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF4A3A28).withValues(alpha: 0.7);
    canvas.drawLine(const Offset(640, 180), const Offset(640, 360), col);
    canvas.drawLine(const Offset(672, 190), const Offset(672, 350), col);
  }

  void _drawSternumCourt(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final spineX = b.center.dx;
    final top = b.top + 56;
    final bottom = b.bottom - 56;

    // The giant's BACKBONE runs the length of the court; the ribcage vaults
    // out from it on both sides — you stand inside the chest at the sternum.
    final spineGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6E5A3A).withValues(alpha: 0.18);
    canvas.drawLine(Offset(spineX, top), Offset(spineX, bottom), spineGlow);

    const ribCount = 7;
    final ribPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB8A070).withValues(alpha: 0.20);
    final reachMax = b.width * 0.44;
    for (var i = 0; i < ribCount; i++) {
      final t = i / (ribCount - 1);
      final y = top + t * (bottom - top);
      final reach = reachMax * (0.5 + 0.5 * sin(t * pi)); // widest mid-chest
      final drop = 60.0 + 30 * sin(t * pi);
      for (final s in const [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(spineX + s * 6, y)
            ..quadraticBezierTo(
              spineX + s * reach * 0.7,
              y + drop * 0.25,
              spineX + s * reach,
              y + drop,
            ),
          ribPaint,
        );
      }
      // Vertebra knot on the spine.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(spineX, y), width: 17, height: 11),
        Paint()..color = const Color(0xFF6E5A3A).withValues(alpha: 0.5),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(spineX, y), width: 17, height: 11),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFB8A070).withValues(alpha: 0.35),
      );
    }

    // Slow marrow motes drifting up the nave.
    if (_fx.ready) {
      for (var i = 0; i < 6; i++) {
        final ph = _time * 0.35 + i * 1.37;
        final mx = spineX + sin(ph * 1.1 + i * 2) * (b.width * 0.3);
        final my = bottom - ((ph * 26) % (bottom - top));
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(mx, my),
          3.0 + (i % 2),
          const Color(0xFFD8B878).withValues(alpha: 0.10),
        );
      }
    }

    // (No free-standing star vigil here — the two keys that open the jaw are
    // shown ON the locked finale door itself, in _renderDoors.)
  }

  /// A length of the giant, drawn as BONE rather than as a stroke.
  ///
  /// A rib is not a line: it is thick at the spine, tapers to nothing at the
  /// tip, and catches light along its upper edge. Every arch in this barrow
  /// goes through here, so the anatomy is one material instead of nine
  /// different curves that happen to be beige.
  void _drawBuriedBone(
    Canvas canvas,
    Offset from,
    Offset ctrl,
    Offset to, {
    double thick = 16,
    double alpha = 1.0,
  }) {
    const steps = 18;
    Offset at(double t) {
      final u = 1 - t;
      return Offset(
        u * u * from.dx + 2 * u * t * ctrl.dx + t * t * to.dx,
        u * u * from.dy + 2 * u * t * ctrl.dy + t * t * to.dy,
      );
    }

    // Two offset edges around the spine of the curve, tapering to the tip.
    final upper = <Offset>[];
    final lower = <Offset>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final p0 = at(max(0.0, t - 0.02));
      final p1 = at(min(1.0, t + 0.02));
      final d = p1 - p0;
      final len = d.distance;
      final n = len < 1e-4
          ? const Offset(0, -1)
          : Offset(-d.dy / len, d.dx / len);
      final w = thick * 0.5 * (1 - t * t * 0.86);
      upper.add(at(t) + n * w);
      lower.add(at(t) - n * w);
    }
    final body = Path()..moveTo(upper.first.dx, upper.first.dy);
    for (final p in upper.skip(1)) {
      body.lineTo(p.dx, p.dy);
    }
    for (final p in lower.reversed) {
      body.lineTo(p.dx, p.dy);
    }
    body.close();
    canvas.drawPath(
      body,
      Paint()..color = const Color(0xFF6B5636).withValues(alpha: 0.55 * alpha),
    );
    // The lit edge, which is what makes it read as round.
    final lit = Path()..moveTo(upper.first.dx, upper.first.dy);
    for (final p in upper.skip(1)) {
      lit.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      lit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFC6AC78).withValues(alpha: 0.42 * alpha),
    );
    // …and the shadow it sits in.
    final dark = Path()..moveTo(lower.first.dx, lower.first.dy);
    for (final p in lower.skip(1)) {
      dark.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      dark,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF120C06).withValues(alpha: 0.5 * alpha),
    );
  }

  /// THE HALL IS INSIDE THE RIBCAGE. Great ribs come down from the vault and
  /// up from the floor and stop short of the marrow channel that runs between
  /// them — so the room the player walks is the gap between two ribs of a
  /// body, which is what this planet has claimed to be all along and what
  /// only the hub was actually drawing.
  void _drawRibcageWalls(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final chasm = room.ribChasm;
    // A RIB ARCS, and the control point is the whole difference. Sitting it
    // near the chord (0.35 out, 0.30 down) draws a straight bone, and the
    // hall came out full of diagonal spears. The hub's ribcage — the one room
    // that always looked right — puts it at 0.7 of the reach and 0.25 of the
    // drop, so the bone leaves the vault almost sideways and turns down late.
    // Same numbers here, so the cage is one cage.
    for (var i = 0; i < 6; i++) {
      final t = (i + 0.5) / 6;
      final x = b.left + t * b.width;
      // Ribs never cross the marrow channel — the split is where they END.
      if (chasm != null && x > chasm.left - 40 && x < chasm.right + 40) {
        continue;
      }
      // Ribs sweep AWAY from the marrow channel, the way they sweep away
      // from a spine — and only as far as there is wall to sweep into, or the
      // ones near the edge simply leave the room and are never seen.
      final away = x < (chasm?.center.dx ?? b.center.dx) ? -1.0 : 1.0;
      final room2wall = away < 0 ? x - b.left : b.right - x;
      final depth = 150 + 60 * sin(t * pi);
      final sweep = min(165 + 55 * sin(t * pi), room2wall * 0.92);
      _drawBuriedBone(
        canvas,
        Offset(x, b.top - 10),
        Offset(x + away * sweep * 0.70, b.top + depth * 0.25),
        Offset(x + away * sweep, b.top + depth),
        thick: 21,
        alpha: 0.85,
      );
      _drawBuriedBone(
        canvas,
        Offset(x + 26, b.bottom + 10),
        Offset(x + 26 + away * sweep * 0.70, b.bottom - depth * 0.25),
        Offset(x + 26 + away * sweep, b.bottom - depth),
        thick: 21,
        alpha: 0.66,
      );
    }
  }


  void _drawRibHall(Canvas canvas, DungeonRoom room) {
    // The marrow chasm: a dark pit with glowing marrow veins down its walls.
    _drawRibcageWalls(canvas, room);
    final chasm = room.ribChasm;
    if (chasm != null) {
      // THE MARROW CHANNEL — a split in the bone, not a rounded rectangle.
      // Its edges waver the way a break does, and the lips of it are the same
      // bone the ribs are made of.
      double lip(double y, double sign) =>
          sign * (7 * sin(y * 0.021) + 4 * sin(y * 0.047 + 1.9));
      final split = Path()..moveTo(chasm.left + lip(chasm.top, 1), chasm.top);
      for (var y = chasm.top; y <= chasm.bottom; y += 18) {
        split.lineTo(chasm.left + lip(y, 1), y);
      }
      for (var y = chasm.bottom; y >= chasm.top; y -= 18) {
        split.lineTo(chasm.right + lip(y, -1), y);
      }
      split.close();
      canvas.drawPath(
        split,
        Paint()..color = const Color(0xFF050301).withValues(alpha: 0.88),
      );
      canvas.drawPath(
        split,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFF8A6E48).withValues(alpha: 0.45),
      );
      final vein = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round
        ..color = const Color(
          0xFFE4A86A,
        ).withValues(alpha: 0.12 + 0.05 * sin(_time * 1.5));
      for (var i = 0; i < 3; i++) {
        final y = chasm.top + 90.0 + i * 180;
        canvas.drawPath(
          Path()
            ..moveTo(chasm.left + 16, y)
            ..quadraticBezierTo(
              chasm.center.dx,
              y + 26,
              chasm.right - 16,
              y + 8,
            ),
          vein,
        );
      }
    }
    // Tracks: carved grooves with notch ticks.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF4A3A28).withValues(alpha: 0.55);
    for (final rib in room.fossilRibs) {
      canvas.drawLine(rib.notches.first, rib.notches.last, groove);
      for (final n in rib.notches) {
        canvas.drawLine(
          n + const Offset(0, -8),
          n + const Offset(0, 8),
          groove,
        );
      }
    }
    // The ribs themselves: solid bone slabs with knobbed vertebra heads,
    // beveled to match the dolmen masonry.
    for (final rib in room.fossilRibs) {
      final rect = _ribRect(rib);
      final bridging = _ribBridging(rib);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      // Knobbed bone heads (solid), drawn behind the shaft.
      final knobR = rect.height * 0.62;
      for (final end in [rect.centerLeft, rect.centerRight]) {
        canvas.drawCircle(
          end + const Offset(1.5, 2.5),
          knobR,
          Paint()..color = const Color(0xFF160F08).withValues(alpha: 0.4),
        );
        canvas.drawCircle(
          end,
          knobR,
          Paint()
            ..color =
                (bridging ? const Color(0xFF8E7A50) : const Color(0xFFBCA478))
                    .withValues(alpha: bridging ? 0.8 : 0.95),
        );
        canvas.drawCircle(
          end,
          knobR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF6E5A3A).withValues(alpha: 0.85),
        );
      }
      // Grounded shadow + shaft body.
      canvas.drawRRect(
        rr.shift(const Offset(2, 3)),
        Paint()..color = const Color(0xFF160F08).withValues(alpha: 0.4),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..color =
              (bridging ? const Color(0xFF9A8458) : const Color(0xFFC8B488))
                  .withValues(alpha: bridging ? 0.78 : 0.92),
      );
      // A SHAFT, NOT A CAPSULE. A plain rounded rect between two knobs reads
      // as a pill; real bone is waisted at the middle and split with old
      // fissures along its length. Two dark wedges pull the silhouette in and
      // three hairlines give it grain — the collision rect is untouched.
      for (final side in const [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(rect.center.dx - rect.width * 0.26,
                rect.center.dy + side * rect.height * 0.5)
            ..quadraticBezierTo(
              rect.center.dx,
              rect.center.dy + side * rect.height * 0.28,
              rect.center.dx + rect.width * 0.26,
              rect.center.dy + side * rect.height * 0.5,
            )
            ..lineTo(rect.center.dx + rect.width * 0.26,
                rect.center.dy + side * rect.height * 0.52)
            ..lineTo(rect.center.dx - rect.width * 0.26,
                rect.center.dy + side * rect.height * 0.52)
            ..close(),
          Paint()..color = const Color(0xFF17100A).withValues(alpha: 0.55),
        );
      }
      final grain = Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6E5A3A).withValues(alpha: 0.35);
      for (var i = 0; i < 3; i++) {
        final y = rect.top + rect.height * (0.34 + i * 0.16);
        final x0 = rect.left + 12 + i * 9.0;
        canvas.drawLine(
          Offset(x0, y),
          Offset(x0 + rect.width * (0.32 + i * 0.14), y + (i - 1) * 0.8),
          grain,
        );
      }
      // Lit bevel along the top of the shaft.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left + 4,
            rect.top + 3,
            rect.width - 8,
            rect.height * 0.34,
          ),
          const Radius.circular(8),
        ),
        Paint()
          ..color = const Color(
            0xFFE0CC9A,
          ).withValues(alpha: bridging ? 0.4 : 0.6),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF6E5A3A).withValues(alpha: 0.85),
      );
      // Grinding dust kicked up along the bone's trailing edge as it grinds.
      final slide = _ribSlides[rib.id];
      if (slide != null && _fx.ready) {
        // Direction of travel, so dust spills behind the grind.
        final dir = (rib.notches[slide.to] - rib.notches[slide.from]);
        final back = dir.distance > 0
            ? -dir / dir.distance
            : const Offset(0, 1);
        final edge = back * (min(rect.width, rect.height) * 0.5 + 6);
        for (var k = 0; k < 4; k++) {
          final phase = _time * 3.0 + k * 1.7 + rect.center.dx;
          final perp = Offset(-back.dy, back.dx) * ((k - 1.5) * 9);
          drawGlow(
            canvas,
            _fx.mote!,
            rect.center + edge + perp,
            5 + 2.5 * (0.5 + 0.5 * sin(phase * 1.3)),
            const Color(
              0xFFD8B878,
            ).withValues(alpha: 0.18 + 0.16 * (0.5 + 0.5 * sin(phase))),
          );
        }
      }
    }
    // The sternum plate: dim until the bridge is whole.
    final plate = room.sternumPlate;
    if (plate != null &&
        room.ribStarIndex != null &&
        !hasStar(room.ribStarIndex!)) {
      final ready = _bridgeComplete(room);
      final col = ready ? const Color(0xFFD8B878) : const Color(0xFF4A3A28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(8)),
        Paint()..color = col.withValues(alpha: ready ? 0.16 : 0.08),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = col.withValues(alpha: ready ? 0.9 : 0.4),
      );
      if (ready) _drawStarGlyph(canvas, plate.center, 11, col);
    }
  }

  void _drawMarrowShrine(Canvas canvas, Offset c) {
    // A solid carved pedestal (matches the dolmen masonry).
    _drawDolmenStone(canvas, c + const Offset(0, 22), 76, 26, 0);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c - const Offset(0, 4),
        30,
        const Color(
          0xFFE4A86A,
        ).withValues(alpha: 0.2 + 0.08 * sin(_time * 1.8)),
      );
    }
    // A marrow geode cracked open on the pedestal.
    canvas.drawCircle(
      c - const Offset(0, 4),
      10,
      Paint()..color = const Color(0xFF3A2C1A).withValues(alpha: 0.9),
    );
    final shard = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFE4A86A).withValues(alpha: 0.8);
    for (var i = 0; i < 5; i++) {
      final a = i * 1.256 + 0.4;
      canvas.drawLine(
        c - const Offset(0, 4) + Offset(cos(a), sin(a)) * 3,
        c - const Offset(0, 4) + Offset(cos(a), sin(a)) * 9,
        shard,
      );
    }
    _drawRuneCircle(
      canvas,
      c,
      66,
      const Color(0xFFD8B878).withValues(alpha: 0.25),
    );
  }

  /// THE CRYPT IS THE SPINE. The four sockets used to be four stacks of discs
  /// standing in a void; they are vertebrae, so there is a column for them to
  /// be vertebrae OF — a great backbone running the length of the chamber
  /// with the buried sockets set into it, and the transverse processes
  /// reaching out to the walls.
  void _drawSpinalColumn(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final x = b.center.dx;
    // The column itself, sunk in the earth: a broad dark shaft with a lit
    // near edge, so it reads as a mass rather than a stripe.
    canvas.drawRect(
      Rect.fromLTRB(x - 34, b.top, x + 34, b.bottom),
      Paint()..color = const Color(0xFF17110A).withValues(alpha: 0.55),
    );
    canvas.drawLine(
      Offset(x - 34, b.top),
      Offset(x - 34, b.bottom),
      Paint()
        ..strokeWidth = 1.4
        ..color = const Color(0xFF8A6E48).withValues(alpha: 0.20),
    );
    canvas.drawLine(
      Offset(x + 34, b.top),
      Offset(x + 34, b.bottom),
      Paint()
        ..strokeWidth = 1.4
        ..color = const Color(0xFF0C0804).withValues(alpha: 0.6),
    );
    // Vertebrae down the shaft, each with its processes reaching outward.
    const n = 9;
    for (var i = 0; i < n; i++) {
      final y = b.top + (i + 0.5) / n * b.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 62, height: 30),
          const Radius.circular(11),
        ),
        Paint()..color = const Color(0xFF5C4A2E).withValues(alpha: 0.62),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y - 4), width: 62, height: 30),
          const Radius.circular(11),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFFC6AC78).withValues(alpha: 0.22),
      );
      // The processes — short bones out to either side, catching the light.
      for (final side in const [-1.0, 1.0]) {
        _drawBuriedBone(
          canvas,
          Offset(x + side * 30, y),
          Offset(x + side * 96, y - 8),
          Offset(x + side * 168, y - 4),
          thick: 13,
          alpha: 0.5,
        );
      }
    }
  }

  void _drawPillarCrypt(Canvas canvas, DungeonRoom room) {
    _drawSpinalColumn(canvas, room);
    final star = room.pillarStarIndex;
    final done = star != null && hasStar(star);
    for (final pillar in room.fossilPillars) {
      final locked = done || lockedPillars.contains(pillar.id);
      final p = pillar.position;
      // The fossil column: stacked vertebra discs — solid bone, bottom-up so
      // the upper discs overlap the lower ones into a real stack.
      final discOutline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF6E5A3A).withValues(alpha: 0.85);
      for (var i = 2; i >= 0; i--) {
        final r = Rect.fromCenter(
          center: p + Offset(0, -8.0 + i * 14),
          width: 52 - i * 6,
          height: 16,
        );
        canvas.drawOval(
          r.shift(const Offset(1.5, 2.5)),
          Paint()..color = const Color(0xFF160F08).withValues(alpha: 0.4),
        );
        canvas.drawOval(
          r,
          Paint()..color = const Color(0xFFA88E5E).withValues(alpha: 0.95),
        );
        // Lit upper rim.
        canvas.drawOval(
          Rect.fromCenter(
            center: r.center - const Offset(0, 3),
            width: r.width * 0.78,
            height: r.height * 0.5,
          ),
          Paint()..color = const Color(0xFFC8B488).withValues(alpha: 0.7),
        );
        canvas.drawOval(r, discOutline);
      }
      // The buried socket at its base.
      canvas.drawCircle(
        p + const Offset(0, 34),
        9,
        Paint()..color = const Color(0xFF0E0A06).withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        p + const Offset(0, 34),
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = (locked ? const Color(0xFFB8E0D8) : const Color(0xFF6E5A3A))
              .withValues(alpha: 0.85),
      );
      if (locked) {
        // The grown crystal lock: a shard cluster that GROWS from the socket.
        final grow = done ? 1.0 : (_crystalGrow[pillar.id] ?? 1.0);
        final eased = Curves.easeOutBack.transform(grow);
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p + const Offset(0, 28),
            26 * (0.4 + 0.6 * grow),
            const Color(
              0xFFB8E0D8,
            ).withValues(alpha: (0.2 + 0.06 * sin(_time * 2.2 + p.dx)) * grow),
          );
        }
        final shard = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFD8F0EA).withValues(alpha: 0.85);
        final fill = Paint()
          ..color = const Color(0xFFB8E0D8).withValues(alpha: 0.20 * grow);
        for (final (dx, h) in const [(-8.0, 14.0), (0.0, 20.0), (8.0, 12.0)]) {
          final base = p + Offset(dx, 36);
          final path = Path()
            ..moveTo(base.dx - 4, base.dy)
            ..lineTo(base.dx, base.dy - h * eased)
            ..lineTo(base.dx + 4, base.dy)
            ..close();
          canvas.drawPath(path, fill);
          canvas.drawPath(path, shard);
        }
        // A bright growth-spark at the tip while it's still crystallising.
        if (grow < 1.0 && _fx.ready) {
          drawGlow(
            canvas,
            _fx.mote!,
            p + Offset(0, 36 - 20 * eased),
            6,
            const Color(0xFFEFFFFB).withValues(alpha: 0.6 * (1 - grow)),
          );
        }
      } else if (_pillarCharge.containsKey(pillar.id)) {
        // CHARGING: the socket draws the storm — a ring fills, sparks gather,
        // and crackle intensifies until it lights. The player defends it.
        final prog =
            (_pillarCharge[pillar.id]! / (_pillarChargeDur[pillar.id] ?? 2.0))
                .clamp(0.0, 1.0);
        final socketC = p + const Offset(0, 34);
        const ringR = 16.0;
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            socketC,
            18 + 16 * prog,
            Color.lerp(
              const Color(0xFFFFE9A0),
              const Color(0xFFB8E0D8),
              prog,
            )!.withValues(alpha: 0.12 + 0.30 * prog),
          );
        }
        // Faint full track, then the filling charge arc over it.
        canvas.drawCircle(
          socketC,
          ringR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF6E5A3A).withValues(alpha: 0.4),
        );
        canvas.drawArc(
          Rect.fromCircle(center: socketC, radius: ringR),
          -pi / 2,
          prog * pi * 2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(
              const Color(0xFFFFE9A0),
              const Color(0xFFD8F0EA),
              prog,
            )!.withValues(alpha: 0.9),
        );
        // Crackling storm-sparks gathering inward, fiercer as it fills.
        final bolt = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFEFFFFB).withValues(alpha: 0.3 + 0.5 * prog);
        for (var k = 0; k < 3; k++) {
          final ang = _time * 4.0 + k * (pi * 2 / 3);
          final outer = socketC + Offset(cos(ang), sin(ang)) * (ringR + 14);
          final mid =
              socketC +
              Offset(cos(ang + 0.35), sin(ang + 0.35)) *
                  (ringR + 3 + 4 * sin(_time * 9 + k));
          final inner = socketC + Offset(cos(ang), sin(ang)) * (ringR * 0.4);
          canvas.drawLine(outer, mid, bolt);
          canvas.drawLine(mid, inner, bolt);
        }
        // A swelling flare as it nears full charge.
        if (prog > 0.8 && _fx.ready) {
          drawGlow(
            canvas,
            _fx.mote!,
            socketC,
            8,
            const Color(
              0xFFEFFFFB,
            ).withValues(alpha: ((prog - 0.8) / 0.2) * 0.7),
          );
        }
      } else if (_fx.ready) {
        // A dormant spark deep in the socket.
        drawGlow(
          canvas,
          _fx.mote!,
          p + const Offset(0, 34),
          4,
          const Color(0xFFFFE9A0).withValues(
            alpha: 0.16 + 0.12 * (0.5 + 0.5 * sin(_time * 2.0 + p.dy)),
          ),
        );
      }
    }
  }

  void _drawGiantsPalm(Canvas canvas) {
    const c = kGiantsPalm;
    final won = discoveredClouds.contains(kEarthGiantsPalmEggId);
    // The open fossil hand: a palm arc and five finger strokes.
    final bone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB8A070).withValues(alpha: 0.5);
    canvas.drawArc(
      Rect.fromCircle(center: c + const Offset(0, 26), radius: 52),
      pi * 1.05,
      pi * 0.9,
      false,
      bone,
    );
    for (var i = 0; i < 5; i++) {
      final a = pi * 1.12 + i * pi * 0.19;
      final base = c + const Offset(0, 26) + Offset(cos(a), sin(a)) * 52;
      final tip =
          c +
          const Offset(0, 26) +
          Offset(cos(a), sin(a)) * (86 + (i == 2 ? 12 : 0));
      canvas.drawLine(base, tip, bone);
    }
    if (won) {
      // The crystal taken root, forever.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          44,
          const Color(
            0xFFB8E0D8,
          ).withValues(alpha: 0.22 + 0.07 * sin(_time * 1.7)),
        );
      }
      final shard = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFD8F0EA).withValues(alpha: 0.9);
      for (final (dx, h) in const [(-10.0, 18.0), (0.0, 28.0), (10.0, 16.0)]) {
        final base = c + Offset(dx, 10);
        canvas.drawPath(
          Path()
            ..moveTo(base.dx - 5, base.dy)
            ..lineTo(base.dx, base.dy - h)
            ..lineTo(base.dx + 5, base.dy)
            ..close(),
          shard,
        );
      }
    }
  }

  void _drawBoneMural(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final panel = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + 120),
      width: 470,
      height: 130,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()..color = const Color(0xFF120D07).withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF8A6E48).withValues(alpha: 0.7),
    );
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFD8B878).withValues(alpha: 0.55);
    // The eye glyph…
    final eyeP = Offset(panel.left + 90, panel.center.dy);
    canvas.drawOval(Rect.fromCenter(center: eyeP, width: 56, height: 30), ink);
    canvas.drawCircle(eyeP, 8, ink);
    // …watching a scale: beam, pivot, two pans with stones.
    final pivot = Offset(panel.center.dx + 60, panel.center.dy - 14);
    canvas.drawLine(
      pivot + const Offset(-80, 8),
      pivot + const Offset(80, -8),
      ink,
    );
    canvas.drawLine(pivot, pivot + const Offset(0, 30), ink);
    for (final side in const [-1.0, 1.0]) {
      final panC = pivot + Offset(side * 80, side * -8 + 22);
      canvas.drawArc(
        Rect.fromCircle(center: panC, radius: 16),
        0,
        pi,
        false,
        ink,
      );
      canvas.drawCircle(panC + const Offset(-5, -4), 3.4, ink);
      canvas.drawCircle(panC + const Offset(5, -4), 3.4, ink);
    }

    // …its gaze BENT through the crystal lens that stands between them. This
    // is the diagram's teaching: the eye reads the scale only via the prism.
    final lensP = Offset((eyeP.dx + pivot.dx) / 2 - 16, panel.center.dy + 6);
    final beam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(
        0xFFB8E0D8,
      ).withValues(alpha: 0.30 + 0.12 * sin(_time * 2.4));
    canvas.drawLine(
      eyeP + const Offset(26, 2),
      lensP - const Offset(0, 4),
      beam,
    );
    canvas.drawLine(
      lensP - const Offset(0, 4),
      pivot + const Offset(0, 2),
      beam,
    );
    // A little plinth under the lens.
    canvas.drawLine(
      lensP + const Offset(-12, 12),
      lensP + const Offset(12, 12),
      ink,
    );
    // The crystal lens itself: a faceted gem.
    final gem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFD8F0EA).withValues(alpha: 0.8);
    final gemPath = Path()
      ..moveTo(lensP.dx, lensP.dy - 16)
      ..lineTo(lensP.dx + 9, lensP.dy + 2)
      ..lineTo(lensP.dx, lensP.dy + 11)
      ..lineTo(lensP.dx - 9, lensP.dy + 2)
      ..close();
    canvas.drawPath(
      gemPath,
      Paint()..color = const Color(0xFFB8E0D8).withValues(alpha: 0.16),
    );
    canvas.drawPath(gemPath, gem);
    canvas.drawLine(
      lensP + const Offset(-9, 2),
      lensP + const Offset(9, 2),
      gem,
    );
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.mote!,
        lensP - const Offset(0, 2),
        6,
        const Color(
          0xFFD8F0EA,
        ).withValues(alpha: 0.30 + 0.12 * sin(_time * 3.0)),
      );
    }
  }

  void _drawEyeAndScale(Canvas canvas, DungeonRoom room) {
    final scale = room.stoneScale;
    if (scale == null) return;
    final solved = guardianAwake || hasStar(2);
    final seeing = solved || prismStage >= 2;

    // The giant's crystal eye, high on the north wall. BLIND (dim, wandering)
    // until its prism stands; awake and fixed on the lens after. Its glow
    // never leaks the count — readings happen at the prism.
    final eyeC = Offset(room.bounds.center.dx, room.bounds.top + 170);
    final eyeGlow = solved ? 1.0 : (seeing ? 0.62 : 0.14);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        eyeC,
        70,
        const Color(0xFFB8E0D8).withValues(alpha: 0.10 + 0.18 * eyeGlow),
      );
    }
    final iris = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFB8E0D8).withValues(alpha: 0.4 + 0.4 * eyeGlow);
    canvas.drawOval(
      Rect.fromCenter(center: eyeC, width: 120, height: 64),
      iris,
    );
    canvas.drawCircle(eyeC, 22, iris);
    // The pupil: while blind it TRACKS the active creature (the giant watches
    // you, eased in _updateBarrow); once the lens stands it locks on the prism.
    final pupil = eyeC + _eyeLook;
    canvas.drawCircle(
      pupil,
      9,
      Paint()
        ..color = const Color(
          0xFFD8F0EA,
        ).withValues(alpha: 0.25 + 0.5 * eyeGlow + 0.08 * sin(_time * 2.6)),
    );

    // The gaze prism on its plinth (and the beam, once it stands).
    _drawGazePrism(canvas, scale, eyeC, seeing);

    // The stone scale: a pivoting beam. The tilt follows PAN LOADING only
    // (how many stones sit each side) — it never betrays the answer — and it
    // EASES toward its load (driven in _updateBarrow) so the beam swings with
    // weight instead of snapping.
    final pivot = scale.position;
    final tilt = _scaleTiltShown;
    final beam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8A6E48).withValues(alpha: 0.85);
    final beamHalf = Offset(cos(tilt), sin(tilt)) * 130;
    canvas.drawLine(pivot - beamHalf, pivot + beamHalf, beam);
    canvas.drawLine(pivot, pivot + const Offset(0, 42), beam);
    // The pans, hanging level from the tilted beam.
    for (final side in const [-1.0, 1.0]) {
      final panC = pivot + beamHalf * side + const Offset(0, 34);
      final hang = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF8A6E48).withValues(alpha: 0.6);
      canvas.drawLine(
        pivot + beamHalf * side,
        panC + const Offset(-14, -8),
        hang,
      );
      canvas.drawLine(
        pivot + beamHalf * side,
        panC + const Offset(14, -8),
        hang,
      );
      canvas.drawArc(
        Rect.fromCircle(center: panC, radius: 20),
        0,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = const Color(0xFFB8A070).withValues(alpha: 0.8),
      );
      // Stones currently on this pan.
      var k = 0;
      for (final w in scale.weights) {
        final onRight = scalePanRight[w.id] ?? false;
        if ((side > 0) != onRight) continue;
        canvas.drawCircle(
          panC + Offset(-9.0 + k * 9, -6),
          4,
          Paint()..color = const Color(0xFFC8B488).withValues(alpha: 0.9),
        );
        k++;
      }
    }
    // The weights on the floor: each carries its SIGIL (so the clue marks
    // can be matched to it) and a chevron showing which pan it rides;
    // insight's truth-flash glows the TRUE side.
    for (final w in scale.weights) {
      final onRight = scalePanRight[w.id] ?? false;
      final p = w.position;
      canvas.drawCircle(
        p,
        15,
        Paint()..color = const Color(0xFF2A2014).withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        p,
        15,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFB8A070).withValues(alpha: 0.8),
      );
      // The stone's identity sigil, engraved on its marker.
      _drawStoneSigil(
        canvas,
        p,
        w.id,
        const Color(0xFFE0C68C).withValues(alpha: 0.95),
        8,
      );
      // Pan chevron: a triangle just outside the marker, pointing to the pan
      // this stone currently rides.
      final dir = onRight ? 1.0 : -1.0;
      final base = p + Offset(dir * 19, 0);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx + dir * 6, base.dy)
          ..lineTo(base.dx, base.dy - 5)
          ..lineTo(base.dx, base.dy + 5)
          ..close(),
        Paint()..color = const Color(0xFFC8B488).withValues(alpha: 0.95),
      );
      if (_scaleTruthFlash > 0 && !solved && _fx.ready) {
        final trueRight = scaleSolution[w.id] ?? w.truePanRight;
        drawGlow(
          canvas,
          _fx.mote!,
          p + Offset(trueRight ? 19 : -19, 0),
          8,
          const Color(
            0xFFB8E0D8,
          ).withValues(alpha: (0.5 * (_scaleTruthFlash / 6)).clamp(0.0, 0.5)),
        );
      }
    }
  }

  /// The gaze prism: bare plinth → raised stone core → standing crystal
  /// prism with the eye's beam refracting through it toward the scale.
  void _drawGazePrism(
    Canvas canvas,
    StoneScale scale,
    Offset eyeC,
    bool seeing,
  ) {
    final p = scale.plinth;
    // The plinth itself — a solid carved block.
    _drawDolmenStone(canvas, p + const Offset(0, 18), 54, 16, 0);

    final crystalUp = prismStage >= 2 || hasStar(2);
    final grow = hasStar(2) ? 1.0 : _prismGrow;

    // The raised stone core: heaves up in stage 1, then fades as the crystal
    // overtakes it in stage 2.
    if (prismStage >= 1) {
      final rise = Curves.easeOutBack.transform(_prismCoreRise);
      final coreAlpha =
          (crystalUp ? (1 - grow) : 1.0) * _prismCoreRise.clamp(0.0, 1.0);
      final coreY = p.dy + 14 - 12 * rise; // from plinth-top up to its perch
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(p.dx, coreY), width: 26, height: 26),
          const Radius.circular(6),
        ),
        Paint()
          ..color = const Color(0xFF6E5A3A).withValues(alpha: 0.85 * coreAlpha),
      );
    }

    if (crystalUp) {
      // The crystal prism, growing out of the core.
      final eased = Curves.easeOutBack.transform(grow);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p - const Offset(0, 4),
          36 * (0.4 + 0.6 * grow),
          const Color(
            0xFFB8E0D8,
          ).withValues(alpha: (0.20 + 0.07 * sin(_time * 2.0)) * grow),
        );
      }
      final shard = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFD8F0EA).withValues(alpha: 0.9);
      final shardFill = Paint()
        ..color = const Color(0xFFB8E0D8).withValues(alpha: 0.18 * grow);
      final apexY = p.dy + 10 - 36 * eased; // grows up from the core
      final prismPath = Path()
        ..moveTo(p.dx - 9, p.dy + 10)
        ..lineTo(p.dx, apexY)
        ..lineTo(p.dx + 9, p.dy + 10)
        ..close();
      canvas.drawPath(prismPath, shardFill);
      canvas.drawPath(prismPath, shard);
      canvas.drawLine(
        p + const Offset(-4, -4),
        Offset(p.dx + 4, apexY + 16),
        shard,
      );
      // A growth-spark riding the apex while it crystallises.
      if (grow < 1.0 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(p.dx, apexY),
          6,
          const Color(0xFFEFFFFB).withValues(alpha: 0.6 * (1 - grow)),
        );
      }
      // The eye's gaze: a beam into the prism, fanning on toward the scale.
      if (seeing) {
        final beam = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(
            0xFFB8E0D8,
          ).withValues(alpha: 0.18 + 0.07 * sin(_time * 3.1));
        canvas.drawLine(
          eyeC + const Offset(0, 26),
          p - const Offset(0, 22),
          beam,
        );
        for (var i = 0; i < 3; i++) {
          final t2 = (i - 1) * 0.35;
          canvas.drawLine(
            p + const Offset(0, 8),
            Offset.lerp(
              scale.position + Offset(t2 * 220, 6),
              scale.position,
              0.12,
            )!,
            beam..color = const Color(0xFFB8E0D8).withValues(alpha: 0.10),
          );
        }
        if (_fx.ready) {
          // A reading-mote pulsing at the prism's heart.
          drawGlow(
            canvas,
            _fx.mote!,
            p - const Offset(0, 6),
            5,
            const Color(
              0xFFD8F0EA,
            ).withValues(alpha: 0.4 + 0.2 * sin(_time * 4.2)),
          );
        }
      }
    }
  }

  /// One branch of the heart's vascular tree: a gently meandering vessel that
  /// forks into two thinner children, tapering with depth (recursive). Drawn
  /// inside a heart-clip by the caller so the veining stays within the muscle.
  void _drawHeartVein(
    Canvas canvas,
    Offset from,
    double angle,
    double len,
    double width,
    int depth,
    Paint Function(double) mk,
  ) {
    final dir = Offset(cos(angle), sin(angle));
    final to = from + dir * len;
    final ctrl =
        from + Offset(cos(angle - 0.32), sin(angle - 0.32)) * (len * 0.55);
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy),
      mk(width),
    );
    if (depth <= 0) return;
    _drawHeartVein(
      canvas,
      to,
      angle - 0.55,
      len * 0.66,
      width * 0.6,
      depth - 1,
      mk,
    );
    _drawHeartVein(
      canvas,
      to,
      angle + 0.45,
      len * 0.70,
      width * 0.6,
      depth - 1,
      mk,
    );
  }

  /// A symmetric anatomical-heart silhouette centred on [c], [w]×[h].
  Path _heartPath(Offset c, double w, double h) {
    return Path()
      ..moveTo(c.dx, c.dy + 0.42 * h)
      ..cubicTo(
        c.dx - 0.62 * w,
        c.dy - 0.02 * h,
        c.dx - 0.48 * w,
        c.dy - 0.52 * h,
        c.dx - 0.16 * w,
        c.dy - 0.34 * h,
      )
      ..cubicTo(
        c.dx - 0.05 * w,
        c.dy - 0.46 * h,
        c.dx + 0.05 * w,
        c.dy - 0.46 * h,
        c.dx + 0.16 * w,
        c.dy - 0.34 * h,
      )
      ..cubicTo(
        c.dx + 0.48 * w,
        c.dy - 0.52 * h,
        c.dx + 0.62 * w,
        c.dy - 0.02 * h,
        c.dx,
        c.dy + 0.42 * h,
      )
      ..close();
  }

  void _drawHeartChamber(Canvas canvas, DungeonRoom room) {
    final g = room.guardian;
    final c = g?.position ?? room.bounds.center;

    // A double-thump "lub-dub" envelope (0..1), only while the heart lives.
    final cyclePos = (_time * 0.85) % 1.0;
    double thump(double centre, double width) {
      final x = (cyclePos - centre) / width;
      return exp(-x * x);
    }

    final beat = guardianAwake
        ? (thump(0.10, 0.045) + 0.55 * thump(0.27, 0.055)).clamp(0.0, 1.0)
        : 0.0;

    // Ribcage caging the arena — breathes faintly with the beat, with a
    // sternum seam down the front.
    final ribArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB8A070).withValues(alpha: 0.22 + 0.10 * beat);
    for (var i = 0; i < 7; i++) {
      final a = pi * 0.5 + i * pi * (1.0 / 6);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 168 + (i % 2) * 20 + 4 * beat),
        a - 0.20,
        0.40,
        false,
        ribArc,
      );
    }
    canvas.drawLine(
      Offset(c.dx, c.dy - 188),
      Offset(c.dx, c.dy - 60),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6E5A3A).withValues(alpha: 0.2),
    );

    // The great heart, behind the roost.
    final heartC = c - const Offset(0, 110);
    final s = 1.0 + 0.09 * beat;
    final w = 124.0 * s;
    final h = 110.0 * s;

    // Surge glow behind the heart on every beat.
    if (guardianAwake && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        heartC,
        72 + 34 * beat,
        const Color(0xFFE4A86A).withValues(alpha: 0.10 + 0.22 * beat),
      );
    }

    // The dark heart-stone.
    final path = _heartPath(heartC, w, h);
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF2A1712).withValues(alpha: 0.9),
    );

    // Crystal veins: an organic vascular tree rooted at the heart's base and
    // branching up into both lobes, CLIPPED inside the silhouette so it reads
    // as veining within the muscle — not lines drawn over it. Brightens softly
    // on each thump (a muted cyan, never a hard white).
    final veinCol = Color.lerp(
      const Color(0xFF5E837C),
      const Color(0xFFB8E6DC),
      beat,
    )!;
    final veinAlpha = guardianAwake ? 0.18 + 0.34 * beat : 0.08;
    Paint veinPaint(double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = max(0.7, width)
      ..color = veinCol.withValues(alpha: veinAlpha);
    final base = heartC + Offset(0, 0.20 * h);
    canvas.save();
    canvas.clipPath(path);
    _drawHeartVein(canvas, base, -pi / 2 - 0.42, 0.34 * h, 2.4, 2, veinPaint);
    _drawHeartVein(canvas, base, -pi / 2 + 0.42, 0.34 * h, 2.4, 2, veinPaint);
    _drawHeartVein(canvas, base, -pi / 2, 0.30 * h, 1.8, 2, veinPaint);
    canvas.restore();

    // A soft warm pulse at the aortic root — a deep glow, not a sparkle.
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        base,
        14 + 10 * beat,
        const Color(
          0xFFE8B074,
        ).withValues(alpha: guardianAwake ? 0.12 + 0.22 * beat : 0.04),
      );
    }

    // Outline.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF6E3A2A).withValues(alpha: 0.6),
    );

    // A ring that flares out of the heart on each thump.
    if (guardianAwake && beat > 0.08) {
      canvas.drawCircle(
        heartC,
        w * 0.5 + 22 * beat,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFFE4A86A).withValues(alpha: 0.26 * beat),
      );
    }
  }
}
