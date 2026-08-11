// lib/games/planet_dungeon/planet_dungeon_game_fire.dart
//
// CINDER CATHEDRAL — the Fire planet's puzzle logic + rendering, as a part of
// planet_dungeon_game.dart (shares the engine's private state the same way
// the Air pilot's inline code does, without growing the main file).
//
// World rule: *fire remembers the order it was lit.*
//  • Entry — the narthex's great hearth is cold; a Fire creature rekindles it
//    and the inner doors part (one-time reveal, persisted like Air's rune).
//  • Star 1 (Ember) — the choir's SIX braziers must be lit in the order the
//    cathedral remembers. The order is NOT spatial. Two hint layers: a
//    cryptic soot mural on the choir floor (a faint ember slowly walks the
//    true order — decodable by patient watching; Mask insight brightens it)
//    and the scriptorium's mural, the explicit key (Mask reads it whole
//    there; choir reading caps at a partial tier). A wrong flame snuffs the
//    rite and the ash rises angry (consequence).
//  • Star 2 (Ash) — the cloister's scorched beds: Plant grows vines, Fire
//    burns them (Plant+Fire→Dust), the settling ash reveals the sigil cut in
//    the groove beneath; each burn breathes out cinder wisps, angrier as the
//    garden bares. PARITY RULE: anything the Plant+Fire braid renders to
//    ash, a Dust creature lays directly.
//  • Star 3 (Pyre) — flame is carried along hanging incense chains: Fire
//    lights a censer (the ash rises to smother it AT ONCE — the rite is
//    tended under attack), the flame crawls but starves between censers,
//    gusts of Air (ELEMENT-ONLY: any family, Speed-scaled) bear it on; a
//    starved flame spawns a fury wave. Each flame reaching its bell rings
//    it; three tolls
//    wake the black-flame Simurgh in the sanctum.

part of 'planet_dungeon_game.dart';

/// A live vesper flame crawling its incense chain (Star 3). Lives in
/// [PlanetDungeonGame._vesperFlames]; advanced by `_updateCathedral`.
class _VesperFlame {
  _VesperFlame({required this.segment, required this.t, required this.life});

  /// Index of the chain segment being crossed (nodes[i] → nodes[i+1]/bell).
  int segment;

  /// 0..1 progress along the current segment.
  double t;

  /// Seconds before the flame starves (censers and gusts refresh it).
  double life;
}

// Tunables for the vesper rite. Self-speed alone can't cross a censer gap
// before the flame starves — the wind has to matter.
const double _kFlameSelfSpeed = 24.0; // px/s unaided
const double _kFlameLife = 2.6; // seconds per feeding
const double _kGustRadius = 85.0;

// ── The Lost Maxims (easter eggs — one per dungeon, 20 gold once) ──
// Discovery ids ride the persisted cloud-discovery channel ('egg:' prefix);
// the screen pays out 20 gold the first time one is found.

/// Air's maxim: commune at the hub compass heart with all three stars.
const String kAirFirstWindEggId = 'egg:air_first_wind';

/// Fire's maxim — the EMBER EPITAPH. Mask insight in the scriptorium WRITES
/// the maxim into the floor (an ember-quill animates it stroke by stroke) and
/// bares a garden planter beside it; Plant fills the planter, Fire lights it,
/// and three gusts of Air swell the blaze until a burn-front sweeps the
/// script and the words stay lit in fire. Entirely wordless — no hint popups.
const String kFireEpitaphEggId = 'egg:fire_epitaph';

/// Where the epitaph garden sits beside the floor-script.
const Offset kEmberEpitaphPlanter = Offset(170, 390);

/// Epicurus, written in soot, then in fire.
const List<String> kFireEpitaphLines = [
  'Death is nothing to us.',
  'When we exist, death is not;',
  'and when death exists, we are not.',
];

/// The dead words as the quill writes them: an alchemist's mirror-cipher
/// (every word backwards) — scrambled enough to stay hidden, fair enough to
/// be decoded by a determined reader. The fire unscrambles them.
const List<String> kFireEpitaphScrambledLines = [
  'htaeD si gnihton ot su.',
  'nehW ew tsixe, htaed si ton;',
  'dna nehw htaed stsixe, ew era ton.',
];

// Mural-script geometry + animation pacing (the words live IN the soot
// mural panel, where the unread smudges used to be).
const Offset _kEpitaphTextAnchor = Offset(320, 86); // first line's centre
const double _kEpitaphLineHeight = 23.0;
const double _kEpitaphWritePerLine = 1.5; // seconds the quill spends per line
const double _kEpitaphWriteStagger = 1.3; // line i starts at i * stagger
const double _kEpitaphBurnPerLine = 1.6; // the fire takes its time
const double _kEpitaphBurnStagger = 1.2;

extension CinderCathedral on PlanetDungeonGame {
  // ── Update ──────────────────────────────────────────────

  void _resetCathedralState() {
    ritualProgress = 0;
    bedStates.clear();
    bellsRung.clear();
    _chainCheckpoints.clear();
    _vesperFlames.clear();
    _bedFx.clear();
    _bellTollFx = 0;
    // choirRevealTier survives: the mural, once read, stays read (knowledge
    // persists across death, like cloud discoveries). Same for the bared
    // epitaph planter — but its growth restarts.
    if (epitaphStage > 1) epitaphStage = 1;
    epitaphFans = 0;
  }

  void _updateCathedral(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isCathedral) return;
    if (_bellTollFx > 0) _bellTollFx -= dt;
    if (_bedFx.isNotEmpty) {
      _bedFx.updateAll((k, v) => v - dt);
      _bedFx.removeWhere((k, v) => v <= 0);
    }
    // Epitaph animation clocks (capped — a fresh session that already owns
    // the maxim skips straight to the settled, fully-lit script).
    final epitaphWon = discoveredClouds.contains(kFireEpitaphEggId);
    if ((epitaphStage >= 1 || epitaphWon) && epitaphWriteT < 30) {
      epitaphWriteT += dt;
    }
    if (epitaphWon && epitaphBlazeT < 30) epitaphBlazeT += dt;
    if (room.incenseChains.isEmpty || hasStar(2)) return;
    // Advance live flames only while their gallery is on screen — the rite
    // is tended, not left to run itself.
    for (final chain in room.incenseChains) {
      final flame = _vesperFlames[chain.id];
      if (flame == null) continue;
      _advanceFlame(room, chain, flame, _kFlameSelfSpeed * dt);
      if (!_vesperFlames.containsKey(chain.id)) continue; // rang the bell
      flame.life -= dt;
      if (flame.life <= 0) {
        _vesperFlames.remove(chain.id);
        final pos = _chainPoint(chain, flame.segment, flame.t);
        _spawnAlchemyBurst(
          pos,
          producedElement: 'Dust',
          reagentElements: const ['Fire'],
          particleCount: 14,
          intensity: 0.7,
        );
        // A starved flame angers the ash far worse than a tended one.
        spawnWispWave(
          element: 'Fire',
          center: pos,
          count: 3,
          unstable: true,
          announce: false,
        );
        _setHint('The vesper flame gutters out — its ash rises in fury', 3.0);
        onChanged();
      }
    }
  }

  /// World position along [chain]: nodes, then the bell as the final point.
  Offset _chainPoint(IncenseChain chain, int segment, double t) {
    final from = chain.nodes[segment];
    final to = segment + 1 < chain.nodes.length
        ? chain.nodes[segment + 1]
        : chain.bellPosition;
    return Offset.lerp(from, to, t.clamp(0.0, 1.0))!;
  }

  int _chainSegmentCount(IncenseChain chain) => chain.nodes.length;

  /// Move a flame [distance] px along its chain, refreshing it at censers and
  /// ringing the bell at the end.
  void _advanceFlame(
    DungeonRoom room,
    IncenseChain chain,
    _VesperFlame flame,
    double distance,
  ) {
    var remaining = distance;
    while (remaining > 0) {
      final from = chain.nodes[flame.segment];
      final to = flame.segment + 1 < chain.nodes.length
          ? chain.nodes[flame.segment + 1]
          : chain.bellPosition;
      final segLen = (to - from).distance;
      if (segLen <= 0.01) {
        flame.t = 1;
      } else {
        flame.t += remaining / segLen;
      }
      if (flame.t < 1) return;
      // Crossed to the next point.
      remaining = (flame.t - 1) * segLen;
      flame.t = 0;
      flame.segment++;
      if (flame.segment >= _chainSegmentCount(chain)) {
        _ringBell(room, chain);
        return;
      }
      // A censer feeds the flame and banks the re-ignite checkpoint.
      _chainCheckpoints[chain.id] = max(
        _chainCheckpoints[chain.id] ?? 0,
        flame.segment,
      );
      flame.life = max(flame.life, _kFlameLife * 0.7);
      _spawnAlchemyBurst(
        chain.nodes[flame.segment],
        producedElement: 'Fire',
        particleCount: 8,
        intensity: 0.5,
      );
    }
  }

  void _ringBell(DungeonRoom room, IncenseChain chain) {
    _vesperFlames.remove(chain.id);
    if (!bellsRung.add(chain.id)) return;
    _bellTollFx = 2.2;
    _spawnAlchemyBurst(
      chain.bellPosition,
      producedElement: 'Fire',
      reagentElements: const ['Air'],
      particleCount: 26,
      intensity: 1.2,
    );
    if (bellsRung.length >= room.incenseChains.length) {
      guardianAwake = true;
      guardianHp = PlanetDungeonGame.maxGuardianHp;
      _setHint(
        'The third bell tolls — black flame pours toward the sanctum',
        4.2,
      );
      spawnWispWave(
        element: 'Fire',
        center: room.bounds.center,
        count: 3,
        unstable: true,
        announce: false,
      );
    } else {
      _setHint(
        'An ember bell tolls — ${bellsRung.length} of '
        '${room.incenseChains.length}',
        3.2,
      );
    }
    onChanged();
  }

  /// Live flame position for [chainId] (null = no flame). Public for the
  /// minimap beacon and the headless full-run test.
  Offset? vesperFlamePosition(String chainId) {
    for (final room in layout.rooms.values) {
      for (final chain in room.incenseChains) {
        if (chain.id != chainId) continue;
        final flame = _vesperFlames[chainId];
        if (flame == null) return null;
        return _chainPoint(chain, flame.segment, flame.t);
      }
    }
    return null;
  }

  /// The censer where a chain's next ignition takes (its checkpoint).
  Offset chainIgnitionPoint(IncenseChain chain) =>
      chain.nodes[(_chainCheckpoints[chain.id] ?? 0).clamp(
        0,
        chain.nodes.length - 1,
      )];

  // ── Utility interactions ────────────────────────────────

  bool _tryCathedral(DungeonCreature a) {
    if (!_isCathedral) return false;
    final room = currentRoom;
    if (_tryHearthOrBrazier(a, room)) return true;
    if (_tryAshGarden(a, room)) return true;
    if (_tryVesper(a, room)) return true;
    if (_tryEmberEpitaph(a, room)) return true;
    if (_tryNaveCommune(a, room)) return true;
    return false;
  }

  /// The Ember Epitaph easter egg (scriptorium). Entirely WORDLESS: stage 0
  /// gives no response, and every step answers with the world (bursts, the
  /// growing flame, the burning script) — never a hint popup. Only an actual
  /// transition consumes the action; anything else falls through to the
  /// creature's normal ability.
  bool _tryEmberEpitaph(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'scriptorium') return false;
    if (discoveredClouds.contains(kFireEpitaphEggId)) return false;
    if ((a.position - kEmberEpitaphPlanter).distance > 52) return false;
    // The garden only exists once the writing has settled.
    if (epitaphStage >= 1 && epitaphWriteT < _epitaphWriteDuration) {
      return false;
    }
    final element = a.member.element;
    if (epitaphStage == 1 && element == 'Plant') {
      epitaphStage = 2;
      _spawnAlchemyBurst(
        kEmberEpitaphPlanter,
        producedElement: 'Plant',
        particleCount: 14,
        intensity: 0.7,
      );
      return true;
    }
    if (epitaphStage == 2 && element == 'Fire') {
      epitaphStage = 3;
      epitaphFans = 0;
      _spawnAlchemyBurst(
        kEmberEpitaphPlanter,
        producedElement: 'Fire',
        reagentElements: const ['Plant'],
        particleCount: 16,
        intensity: 0.8,
      );
      return true;
    }
    if (epitaphStage == 3 && element == 'Air') {
      epitaphFans++;
      _spawnAlchemyBurst(
        kEmberEpitaphPlanter,
        producedElement: 'Fire',
        reagentElements: const ['Air'],
        particleCount: 12 + epitaphFans * 8,
        intensity: 0.7 + epitaphFans * 0.25,
      );
      if (epitaphFans >= 3) {
        epitaphBlazeT = 0; // the burn-front starts its sweep
        _discoverCloud(kFireEpitaphEggId); // screen pays the 20 gold
      }
      return true;
    }
    return false;
  }

  /// Seconds until the quill finishes the last line.
  double get _epitaphWriteDuration =>
      (kFireEpitaphLines.length - 1) * _kEpitaphWriteStagger +
      _kEpitaphWritePerLine;

  /// The narthex hearth (entry rite) and the choir's ritual braziers.
  bool _tryHearthOrBrazier(DungeonCreature a, DungeonRoom room) {
    if (room.braziers.isEmpty) return false;
    RitualBrazier? nearest;
    var bestDist = 46.0;
    for (final b in room.braziers) {
      final d = (a.position - b.position).distance;
      if (d < bestDist) {
        bestDist = d;
        nearest = b;
      }
    }
    if (nearest == null) return false;

    // Standalone hearth (no star index) = the entry rite.
    if (room.brazierStarIndex == null) {
      if (entryDoorRevealed) {
        _setHint('The great hearth burns steady');
        return true;
      }
      if (a.member.element != 'Fire') {
        _setHint('The hearth is stone-cold — only flame wakes it');
        return true;
      }
      entryDoorRevealed = true;
      _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId); // persist
      final doorCenter = room.doors.isNotEmpty
          ? room.doors.first.rect.center
          : a.position;
      _setHint('Flame takes the great hearth — the inner doors grind apart');
      _spawnAlchemyBurst(
        nearest.position,
        producedElement: 'Fire',
        particleCount: 32,
        intensity: 1.3,
      );
      _spawnAlchemyBurst(
        doorCenter,
        producedElement: 'Fire',
        particleCount: 24,
        intensity: 1.1,
      );
      return true;
    }

    // The choir rite.
    final star = room.brazierStarIndex!;
    if (hasStar(star)) return false;
    if (nearest.order < ritualProgress) {
      _setHint('This brazier already burns its remembered turn');
      return true;
    }
    if (a.member.element != 'Fire') {
      _setHint('Cold ritual iron — the braziers answer Fire alone');
      return true;
    }
    if (nearest.order == ritualProgress) {
      ritualProgress++;
      _spawnAlchemyBurst(
        nearest.position,
        producedElement: 'Fire',
        reagentElements: [a.member.element],
        particleCount: 20,
        intensity: 1.0,
      );
      if (ritualProgress >= room.braziers.length) {
        earnStar(star); // the spec's announcement covers the copy
      } else {
        // The count is STATE — it lives in the progress readout (§5.6);
        // the capsule keeps only the rite's answer.
        _setHint('The flame takes its remembered turn');
      }
      onChanged();
    } else {
      ritualProgress = 0;
      _spawnAlchemyBurst(
        nearest.position,
        producedElement: 'Dust',
        reagentElements: const ['Fire'],
        unstable: true,
        particleCount: 22,
      );
      spawnWispWave(
        element: 'Fire',
        center: nearest.position,
        count: 2,
        announce: false,
      );
      _setHint(
        'The fire remembers another order — every brazier snuffs out',
        3.2,
      );
    }
    return true;
  }

  /// The cloister's ash garden (Star 2).
  bool _tryAshGarden(DungeonCreature a, DungeonRoom room) {
    final star = room.vineStarIndex;
    if (room.vineBeds.isEmpty || star == null || hasStar(star)) return false;
    VineBed? bed;
    var bestDist = 50.0;
    for (final b in room.vineBeds) {
      final d = (a.position - b.position).distance;
      if (d < bestDist) {
        bestDist = d;
        bed = b;
      }
    }
    if (bed == null) return false;
    final state = bedStates[bed.id] ?? 0;
    final element = a.member.element;

    if (state == 2) {
      _setHint('This sigil already burns in its groove');
      return true;
    }
    if (element == 'Plant' && state == 0) {
      bedStates[bed.id] = 1;
      _bedFx[bed.id] = 1.2;
      // ELEMENT-ONLY: any Plant lays the growth clean and silent.
      _setHint('Vines surge across the bed in one green breath');
      _spawnAlchemyBurst(
        bed.position,
        producedElement: 'Plant',
        reagentElements: [element],
        particleCount: 16,
        intensity: 0.8,
      );
      return true;
    }
    if (element == 'Fire' && state == 1) {
      bedStates[bed.id] = 2;
      _bedFx[bed.id] = 1.4;
      _spawnAlchemyBurst(
        bed.position,
        producedElement: 'Dust',
        reagentElements: const ['Plant', 'Fire'],
        particleCount: 24,
        intensity: 1.05,
      );
      final revealed = room.vineBeds
          .where((b) => (bedStates[b.id] ?? 0) == 2)
          .length;
      // The consequence layer: every burning bed breathes out cinders, and
      // the garden grows angrier with each sigil bared.
      spawnWispWave(
        element: 'Fire',
        center: bed.position,
        count: 3,
        unstable: revealed >= 3,
        announce: false,
      );
      if (revealed >= room.vineBeds.length) {
        earnStar(star);
      } else {
        _setHint(
          'The vines char to ash — a sigil glows in its groove '
          '($revealed of ${room.vineBeds.length})',
          3.2,
        );
      }
      return true;
    }
    // PARITY RULE: what the Plant+Fire braid renders to ash, Dust lays
    // directly — no growth, no burning.
    if (element == 'Dust') {
      bedStates[bed.id] = 2;
      _bedFx[bed.id] = 1.4;
      _spawnAlchemyBurst(
        bed.position,
        producedElement: 'Dust',
        particleCount: 20,
        intensity: 0.9,
      );
      final revealed = room.vineBeds
          .where((b) => (bedStates[b.id] ?? 0) == 2)
          .length;
      if (revealed >= room.vineBeds.length) {
        earnStar(star);
      } else {
        _setHint(
          'Ash needs no fire — it settles straight into the groove '
          '($revealed of ${room.vineBeds.length})',
          3.2,
        );
      }
      return true;
    }
    if (element == 'Fire' && state == 0) {
      _setHint('Bare scorched earth — flame needs something to take first');
      return true;
    }
    if (element == 'Plant' && state == 1) {
      _setHint('The vines wait for flame');
      return true;
    }
    _setHint('The garden answers Plant, then Fire — ash reveals the sigils');
    return true;
  }

  /// The bell gallery's vesper rite (Star 3): ignite + gust.
  bool _tryVesper(DungeonCreature a, DungeonRoom room) {
    if (room.incenseChains.isEmpty || hasStar(2)) return false;
    final element = a.member.element;

    // Fire: light (or re-light) a chain at its checkpoint censer.
    if (element == 'Fire') {
      for (final chain in room.incenseChains) {
        if (bellsRung.contains(chain.id)) continue;
        if (_vesperFlames.containsKey(chain.id)) continue;
        final ignition = chainIgnitionPoint(chain);
        if ((a.position - ignition).distance > 46) continue;
        if (!guardianRiteUnlocked) {
          _setHint(
            'The censer swallows the flame — the vesper waits on the '
            '${layout.starName(0)} and ${layout.starName(1)}',
          );
          return true;
        }
        final checkpoint = _chainCheckpoints[chain.id] ?? 0;
        _vesperFlames[chain.id] = _VesperFlame(
          segment: checkpoint.clamp(0, chain.nodes.length - 1),
          t: 0,
          life: _kFlameLife,
        );
        _spawnAlchemyBurst(
          ignition,
          producedElement: 'Fire',
          particleCount: 16,
          intensity: 0.9,
        );
        // The vesper flame draws the ash the moment it lights — the rite
        // is tended under attack.
        spawnWispWave(
          element: 'Fire',
          center: ignition,
          count: 2,
          announce: false,
        );
        _setHint(
          checkpoint > 0
              ? 'The flame rekindles — and the ash stirs with it'
              : 'The first censer takes the flame and the ash rises to '
                    'smother it — gust it down the chain',
          3.0,
        );
        return true;
      }
    }

    // Air: gust a live flame onward. ELEMENT-ONLY — every Air carries it the
    // same distance; Speed alone decides how far.
    if (element == 'Air') {
      for (final chain in room.incenseChains) {
        final flame = _vesperFlames[chain.id];
        if (flame == null) continue;
        final pos = _chainPoint(chain, flame.segment, flame.t);
        if ((a.position - pos).distance > _kGustRadius) continue;
        final speedT = normStat(a.member.statSpeed);
        final push = 120.0 + 70.0 * speedT;
        flame.life = max(flame.life, _kFlameLife);
        _spawnAlchemyBurst(
          pos,
          producedElement: 'Air',
          reagentElements: const ['Fire'],
          particleCount: 12,
          intensity: 0.7,
        );
        _setHint('The gust bears the flame down the chain');
        _advanceFlame(room, chain, flame, push);
        return true;
      }
    }

    // Near a chain but holding the wrong element: teach the rite.
    for (final chain in room.incenseChains) {
      if (bellsRung.contains(chain.id)) continue;
      final flame = _vesperFlames[chain.id];
      final anchor = flame != null
          ? _chainPoint(chain, flame.segment, flame.t)
          : chainIgnitionPoint(chain);
      if ((a.position - anchor).distance <= _kGustRadius) {
        _setHint('The censers answer Fire; the flame rides on Air');
        return true;
      }
    }
    return false;
  }

  /// The 3-star secret: commune beneath the rose window.
  bool _tryNaveCommune(DungeonCreature a, DungeonRoom room) {
    if (room.id != 'nave' || starsEarnedCount < 3) return false;
    if ((a.position - room.bounds.center).distance >= 34) return false;
    _setHint(
      'The rose window stills. Before the ash, the Simurgh sang the first '
      'dawn into these vaults — the cathedral remembers, and now it rests.',
      7.5,
    );
    _spawnAlchemyBurst(
      room.bounds.center,
      producedElement: 'Light',
      reagentElements: const ['Fire'],
      particleCount: 20,
      intensity: 0.8,
    );
    return true;
  }

  // ── Mask insight ────────────────────────────────────────

  void _cathedralReveal(DungeonCreature a, DungeonRoom room) {
    revealFlash = 0.6;
    revealTier = revealHintTier(a.member.statIntelligence);
    switch (room.id) {
      case 'scriptorium':
        // NO hint popups in this room — the mural answers visually: the
        // brazier glyphs draw themselves into the panel per insight tier,
        // and the epitaph cipher writes itself in (and bares the garden).
        choirRevealTier = max(choirRevealTier, revealTier);
        if (epitaphStage == 0 &&
            !discoveredClouds.contains(kFireEpitaphEggId)) {
          epitaphStage = 1;
          epitaphWriteT = 0;
        }
        return;
      case 'choir':
        if (hasStar(room.brazierStarIndex ?? 0)) {
          _setHint('The braziers keep their vigil — the rite is done');
          return;
        }
        if (choirRevealTier >= 0) {
          _setHint(_muralReading(choirRevealTier), 4.2);
          return;
        }
        // Reading the stalls cold caps out below the mural itself.
        choirRevealTier = min(revealTier, 1);
        _setHint(
          choirRevealTier >= 1
              ? 'Soot tallies ghost over two braziers — the scriptorium '
                    'holds the whole rite'
              : 'The braziers keep their secret — soot writing waits in '
                    'the scriptorium',
          3.8,
        );
        return;
      case 'cloister':
        final hidden = room.vineBeds
            .where((b) => (bedStates[b.id] ?? 0) != 2)
            .length;
        _setHint(
          hidden > 0
              ? (revealTier >= 1
                    ? 'Insight: $hidden bed${hidden == 1 ? '' : 's'} still '
                          'hide${hidden == 1 ? 's' : ''} a sigil — grow them '
                          'green, then give them to flame'
                    : 'The soot whispers of sigils beneath the beds — more '
                          'Intelligence would read how they bare themselves')
              : 'Every groove burns — the garden has told all it knows',
          3.8,
        );
        return;
      case 'vestry':
        _setHint(
          'The charred fresco completes — flame walks the hanging chains, '
          'and the wind bears it censer to censer',
          4.0,
        );
        return;
      case 'bell_gallery':
        final left = room.incenseChains.length - bellsRung.length;
        _setHint(
          left > 0
              ? 'Three chains, three bells — $left still '
                    'silent. Light the censer; gust the flame onward'
              : 'The bells have all spoken',
          3.8,
        );
        return;
      case 'narthex':
        _setHint(
          entryDoorRevealed
              ? 'The hearth-soot has burned clean'
              : 'The hearth\'s soot spells a single word: burn',
        );
        return;
      case 'nave':
        _setHint(
          'Three lights watch over the chancel gate — ember, ash, and pyre',
          3.6,
        );
        return;
      case 'high_altar':
        _setHint('The black flame defers to the bells', 3.2);
        return;
      case 'sanctum':
        _setHint(
          guardianAwake
              ? 'The Simurgh\'s rage thins in waves — strike in the lull'
              : 'An empty roost above the altar — the bells will fill it',
          3.6,
        );
        return;
    }
    _setHint('Nothing hidden stirs here');
  }

  String _muralReading(int tier) => switch (tier) {
    >= 2 =>
      'The mural completes — west floor, the high northeast lamp, the low '
          'seat, the high northwest lamp, the east floor, and last the '
          'high seat',
    1 =>
      'The mural half-steadies: the rite begins at the west floor, then '
          'the high northeast lamp — the rest still writhes',
    _ =>
      'Soot on soot — six fires and one remembered order; the choir floor '
          'replays it for patient eyes. More Intelligence would steady '
          'the strokes',
  };

  // ── Ambient hints / objectives / mood ───────────────────

  /// The choir rite's progress, glanceable beside the star tracker (§5.6):
  /// live only while the braziers are the room's business.
  DungeonProgressReadout? get _cathedralProgressReadout {
    final room = currentRoom;
    final star = room.brazierStarIndex;
    if (star == null || hasStar(star) || room.braziers.isEmpty) return null;
    return DungeonProgressReadout(
      label: 'BRAZIERS',
      value: '$ritualProgress/${room.braziers.length}',
      fraction: ritualProgress / room.braziers.length,
    );
  }

  void _cathedralAmbientHint(DungeonCreature a, DungeonRoom room) {
    // Braziers (hearth + choir).
    for (final b in room.braziers) {
      if ((a.position - b.position).distance > 64) continue;
      if (room.brazierStarIndex == null) {
        if (!entryDoorRevealed) {
          _setAmbientHint(
            a.member.element == 'Fire'
                ? 'The cold hearth leans toward your flame'
                : 'The great hearth lies cold under old ash',
          );
        }
        return;
      }
      if (hasStar(room.brazierStarIndex!)) return;
      _setAmbientHint(
        a.member.element == 'Fire'
            ? 'The brazier waits for its remembered turn'
            : 'Cold ritual iron, kept in its old order',
      );
      return;
    }
    // Garden beds.
    if (room.vineStarIndex != null && !hasStar(room.vineStarIndex!)) {
      for (final bed in room.vineBeds) {
        if ((a.position - bed.position).distance > 64) continue;
        final state = bedStates[bed.id] ?? 0;
        if (state == 0) {
          _setAmbientHint(
            a.member.element == 'Plant'
                ? 'The scorched bed tugs at your green'
                : 'A scorched bed, bare to the soot',
          );
        } else if (state == 1) {
          _setAmbientHint(
            a.member.element == 'Fire'
                ? 'The vines lean toward your flame'
                : 'The vines crowd thick over the bed',
          );
        }
        return;
      }
    }
    // Vesper chains.
    if (room.incenseChains.isNotEmpty && !hasStar(2)) {
      for (final chain in room.incenseChains) {
        final flame = _vesperFlames[chain.id];
        if (flame != null) {
          final pos = _chainPoint(chain, flame.segment, flame.t);
          if ((a.position - pos).distance <= 95) {
            _setAmbientHint('The flame gutters low between censers');
            return;
          }
          continue;
        }
        if (bellsRung.contains(chain.id)) continue;
        if ((a.position - chainIgnitionPoint(chain)).distance <= 60) {
          _setAmbientHint('A cold censer, dark with old incense');
          return;
        }
        if ((a.position - chain.bellPosition).distance <= 60) {
          _setAmbientHint('An ember bell hangs silent');
          return;
        }
      }
    }
  }

  String? _cathedralObjectiveHint(DungeonRoom room) {
    switch (room.id) {
      case 'narthex':
        return entryDoorRevealed
            ? null
            : 'Narthex — the great hearth is cold; flame wakes the way in';
      case 'scriptorium':
        return hasStar(0)
            ? null
            : 'Scriptorium — soot writing on the wall; insight steadies it';
      case 'choir':
        return 'Choir — the floor mural walks the order; light the six '
            'braziers as the fire remembers';
      case 'cloister':
        // WHAT, never HOW (§5.6): the grow-burn-read rite is Mask-insight
        // content (_cathedralReveal), not room-entry copy.
        return 'Cloister — the scorched beds keep their sigils';
      case 'vestry':
        return hasStar(2)
            ? null
            : 'Vestry — a charred fresco diagrams the vesper ahead';
      case 'bell_gallery':
        return 'Bell Gallery — carry flame down each chain; ring all '
            'three bells';
      case 'high_altar':
        return hasStar(2)
            ? null
            : 'High Altar — the black flame waits on the bells';
      case 'sanctum':
        return guardianAwake
            ? 'Sanctum — the Simurgh descends'
            : 'Sanctum — an empty roost; the bells have not rung';
    }
    return null;
  }

  double get _cathedralMoodTarget {
    return switch (currentRoomId) {
      'narthex' => entryDoorRevealed ? 0.55 : 0.40,
      'nave' => 0.52,
      'scriptorium' => 0.46,
      'choir' => 0.50 + ritualProgress * 0.05,
      'cloister' => 0.60,
      'reliquary' => 0.55,
      'vestry' => 0.34,
      'bell_gallery' => 0.30 + bellsRung.length * 0.05,
      'high_altar' => 0.26,
      'sanctum' => guardianAwake ? 0.18 : 0.24,
      _ => 0.5,
    };
  }

  // ── Render: screen-space atmosphere ─────────────────────

  /// Warm gradient fallback when the Fire shader is unavailable.
  void _drawCathedralFallbackSky(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [
            Color(0xFF120A07), // soot vault
            Color(0xFF2A130C), // ember dusk
            Color(0xFF4A2410), // hearth-light horizon
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  /// Ambient embers: a handful of slow sparks rising on staggered loops —
  /// the cathedral's air, visible in every chamber. 4 glow blits per frame.
  void _drawEmberDrift(Canvas canvas, Size vp) {
    if (!_fx.ready) return;
    for (var i = 0; i < 4; i++) {
      final speed = 26.0 + i * 9;
      final span = vp.height + 120;
      final travel = ((_time * speed + i * 311) % span);
      final y = vp.height + 40 - travel;
      final x =
          vp.width * (0.16 + 0.22 * i) +
          sin(_time * (0.8 + i * 0.23) + i * 2.1) * 30;
      final fade = (travel / span).clamp(0.0, 1.0);
      final alpha = (0.26 * (1 - fade) + 0.04).clamp(0.0, 0.3);
      drawGlow(
        canvas,
        _fx.mote!,
        Offset(x, y),
        3.4 + i * 0.8,
        Color.lerp(
          const Color(0xFFFFB46B),
          const Color(0xFF8A5A48),
          fade,
        )!.withValues(alpha: alpha),
      );
    }
  }

  // ── Render: world-space ─────────────────────────────────

  /// Cathedral stone flooring for plain rooms — replaces the Air island.
  void _renderCathedralFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final rr = RRect.fromRectAndRadius(b.deflate(8), const Radius.circular(26));
    // TRANSLUCENT like the Air islands (alpha ≈ 0.5–0.6): the elemental
    // shader atmosphere must glow through the stone, never be painted over.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          const Color(0xFF1B130E).withValues(alpha: 0.52),
          const Color(0xFF100B08).withValues(alpha: 0.60),
        ]),
    );
    // Flagstone seams — sparse grid, barely-there.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF4A382C).withValues(alpha: 0.10);
    for (var x = b.left + 90; x < b.right - 20; x += 110) {
      canvas.drawLine(Offset(x, b.top + 18), Offset(x, b.bottom - 18), seam);
    }
    for (var y = b.top + 90; y < b.bottom - 20; y += 110) {
      canvas.drawLine(Offset(b.left + 18, y), Offset(b.right - 18, y), seam);
    }
    // The processional runner: a dark crimson carpet down the long axis.
    final horizontal = b.width >= b.height;
    final runner = horizontal
        ? Rect.fromCenter(center: b.center, width: b.width - 90, height: 86)
        : Rect.fromCenter(center: b.center, width: 86, height: b.height - 90);
    final runnerRR = RRect.fromRectAndRadius(runner, const Radius.circular(8));
    canvas.drawRRect(
      runnerRR,
      Paint()..color = const Color(0xFF541A14).withValues(alpha: 0.30),
    );
    canvas.drawRRect(
      runnerRR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFC4A35A).withValues(alpha: 0.22),
    );
    // Ember veins smouldering in two corners.
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF8A50).withValues(
        alpha: 0.10 + 0.05 * sin(_time * 1.7),
      );
    final v1 = Path()
      ..moveTo(b.left + 30, b.bottom - 60)
      ..quadraticBezierTo(
        b.left + 110,
        b.bottom - 95,
        b.left + 150,
        b.bottom - 40,
      );
    final v2 = Path()
      ..moveTo(b.right - 36, b.top + 70)
      ..quadraticBezierTo(b.right - 130, b.top + 95, b.right - 170, b.top + 48);
    canvas.drawPath(v1, vein);
    canvas.drawPath(v2, vein);
    // Soot feathering dissolves the hard edges.
    if (_fx.ready) {
      final cols = (b.width / 130).clamp(3, 9).toInt();
      for (var i = 0; i < cols; i++) {
        final x = b.left + (i + 0.5) / cols * b.width;
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, b.top + 8),
          120,
          const Color(0xFF17100C).withValues(alpha: 0.55),
        );
        drawPuff(
          canvas,
          _fx.puff!,
          Offset(x, b.bottom - 8),
          120,
          const Color(0xFF120D0A).withValues(alpha: 0.6),
        );
      }
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFC4A35A).withValues(alpha: 0.14),
    );
  }

  /// Per-room landmarks + puzzle objects.
  void _renderCathedral(Canvas canvas, DungeonRoom room) {
    switch (room.id) {
      case 'narthex':
        _drawGreatHearth(canvas, room);
        break;
      case 'nave':
        _drawNave(canvas, room);
        break;
      case 'scriptorium':
        _drawSootMural(canvas, room);
        _drawEmberEpitaph(canvas);
        break;
      case 'choir':
        _drawChoirStalls(canvas, room);
        _drawChoirFloorMural(canvas, room);
        _drawRitualBraziers(canvas, room);
        break;
      case 'cloister':
        _drawDryFountain(canvas, room.bounds.center);
        _drawVineBeds(canvas, room);
        break;
      case 'reliquary':
        _drawCinderShrine(canvas, room.bounds.center);
        break;
      case 'vestry':
        _drawVesperFresco(canvas, room);
        break;
      case 'bell_gallery':
        _drawIncenseChains(canvas, room);
        break;
      case 'high_altar':
        _drawBlackFlameAltar(canvas, room);
        break;
      case 'sanctum':
        _drawSanctumRoost(canvas, room);
        break;
    }
  }

  /// A small layered flame: two teardrop lobes + a baked glow beneath.
  void _drawFlame(
    Canvas canvas,
    Offset base,
    double h, {
    Color core = const Color(0xFFFFD27A),
    Color outer = const Color(0xFFFF7A3C),
    double phase = 0,
  }) {
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        base - Offset(0, h * 0.35),
        h * 1.5,
        outer.withValues(alpha: 0.30 + 0.08 * sin(_time * 6 + phase)),
      );
    }
    final sway = sin(_time * 5.2 + phase) * h * 0.12;
    Path lobe(double w, double hh, double lean) => Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
        base.dx - w,
        base.dy - hh * 0.45,
        base.dx + lean,
        base.dy - hh,
      )
      ..quadraticBezierTo(base.dx + w, base.dy - hh * 0.45, base.dx, base.dy);
    canvas.drawPath(
      lobe(h * 0.42, h, sway),
      Paint()..color = outer.withValues(alpha: 0.75),
    );
    canvas.drawPath(
      lobe(h * 0.24, h * 0.62, sway * 0.7),
      Paint()..color = core.withValues(alpha: 0.9),
    );
  }

  void _drawGreatHearth(Canvas canvas, DungeonRoom room) {
    final c = Offset(330, 265);
    // Arched hearth mouth.
    final arch = Path()
      ..moveTo(c.dx - 70, c.dy + 46)
      ..lineTo(c.dx - 70, c.dy - 10)
      ..quadraticBezierTo(c.dx, c.dy - 86, c.dx + 70, c.dy - 10)
      ..lineTo(c.dx + 70, c.dy + 46)
      ..close();
    canvas.drawPath(
      arch,
      Paint()..color = const Color(0xFF0B0705).withValues(alpha: 0.85),
    );
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF74613A).withValues(alpha: 0.8),
    );
    // Andiron logs.
    final log = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A241A);
    canvas.drawLine(c + const Offset(-34, 36), c + const Offset(30, 28), log);
    canvas.drawLine(c + const Offset(-26, 26), c + const Offset(36, 38), log);
    final k = _entryReveal.clamp(0.0, 1.0); // 0 cold ash → 1 roaring hearth
    // The cold ash heap fades out as the fire catches.
    if (k < 1.0) {
      canvas.drawOval(
        Rect.fromCenter(center: c + const Offset(0, 34), width: 64, height: 18),
        Paint()..color = const Color(0xFF3A332C).withValues(alpha: 0.7 * (1 - k)),
      );
    }
    if (k <= 0.0) {
      // Stone-cold: one stubborn ember waiting for a flame.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          c + const Offset(8, 30),
          5,
          const Color(0xFFFF8A50).withValues(
            alpha: 0.25 + 0.18 * (0.5 + 0.5 * sin(_time * 2.3)),
          ),
        );
      }
    } else {
      // KINDLE: flames climb out of the embers, the smaller tongues catching a
      // beat behind the main one so it reads as the fire taking hold.
      final kindle = Curves.easeOutCubic.transform(k);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c + const Offset(0, 18),
          30 + 26 * kindle,
          const Color(0xFFFF9A50).withValues(alpha: 0.10 + 0.16 * kindle),
        );
      }
      _drawFlame(canvas, c + const Offset(0, 30), 52 * kindle, phase: 0.4);
      final k2 = ((k - 0.25) / 0.75).clamp(0.0, 1.0);
      final k3 = ((k - 0.5) / 0.5).clamp(0.0, 1.0);
      if (k2 > 0) _drawFlame(canvas, c + const Offset(-20, 34), 30 * k2, phase: 2.1);
      if (k3 > 0) _drawFlame(canvas, c + const Offset(18, 34), 26 * k3, phase: 3.6);
    }
    // Flanking columns by the inner doors.
    final col = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF4A382C).withValues(alpha: 0.7);
    canvas.drawLine(const Offset(640, 180), const Offset(640, 360), col);
    canvas.drawLine(const Offset(672, 190), const Offset(672, 350), col);
  }

  void _drawNave(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    // Column rows down both sides.
    final col = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF3E2E22).withValues(alpha: 0.62);
    for (var i = 0; i < 4; i++) {
      final x = b.left + 150 + i * 200.0;
      canvas.drawLine(Offset(x, b.top + 120), Offset(x, b.top + 175), col);
      canvas.drawLine(
        Offset(x, b.bottom - 175),
        Offset(x, b.bottom - 120),
        col,
      );
      canvas.drawCircle(
        Offset(x, b.top + 112),
        9,
        Paint()..color = const Color(0xFF4A382C).withValues(alpha: 0.6),
      );
      canvas.drawCircle(
        Offset(x, b.bottom - 112),
        9,
        Paint()..color = const Color(0xFF4A382C).withValues(alpha: 0.6),
      );
      // Candle clusters at the column feet.
      if (_fx.ready) {
        final flick = 0.5 + 0.5 * sin(_time * 5.5 + i * 1.9);
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(x, b.top + 184),
          7,
          const Color(0xFFE4C16A).withValues(alpha: 0.22 + 0.12 * flick),
        );
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(x, b.bottom - 184),
          7,
          const Color(0xFFE4C16A).withValues(alpha: 0.22 + 0.12 * flick),
        );
      }
    }
    // The rose window above the chancel gate.
    _drawRoseWindow(canvas, Offset(b.center.dx + 185, b.top + 88), 56);
    // Star vigil lights over the gate: ember, ash, pyre.
    for (var i = 0; i < 3; i++) {
      final p = Offset(b.center.dx + 120 + i * 50.0, b.top + 170);
      final earnedStar = hasStar(i);
      final col2 = earnedStar
          ? const Color(0xFFE4C16A)
          : const Color(0xFF4A382C);
      if (_fx.ready && earnedStar) {
        drawGlow(canvas, _fx.glow!, p, 16, col2.withValues(alpha: 0.35));
      }
      _drawStarGlyph(canvas, p, 7, col2.withValues(alpha: earnedStar ? 0.95 : 0.5));
    }
  }

  void _drawRoseWindow(Canvas canvas, Offset c, double r) {
    final lit = 0.35 + _skyMood * 0.5;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        r * 1.5,
        const Color(0xFFFF8A50).withValues(alpha: 0.16 * lit + 0.06),
      );
    }
    final glass = Paint()
      ..color = const Color(0xFF6E2A14).withValues(alpha: 0.5 * lit + 0.18);
    canvas.drawCircle(c, r, glass);
    final tracery = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.55);
    canvas.drawCircle(c, r, tracery);
    canvas.drawCircle(c, r * 0.62, tracery);
    canvas.drawCircle(c, r * 0.24, tracery);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + pi / 8;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * r * 0.24,
        c + Offset(cos(a), sin(a)) * r,
        tracery,
      );
      // Petal glow segments.
      if (_fx.ready) {
        final pp = c + Offset(cos(a), sin(a)) * r * 0.8;
        drawGlow(
          canvas,
          _fx.mote!,
          pp,
          5,
          const Color(0xFFFFB46B).withValues(
            alpha: 0.10 + 0.10 * lit * (0.5 + 0.5 * sin(_time * 1.3 + i)),
          ),
        );
      }
    }
  }

  void _drawSootMural(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final panel = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + 130),
      width: 490,
      height: 170,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()..color = const Color(0xFF0D0907).withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF74613A).withValues(alpha: 0.7),
    );
    // The panel's upper half belongs to the dead words (_drawEmberEpitaph).
    // The lower band carries the brazier glyphs in RITE order, left to
    // right — drawn ONLY once insight has steadied them (no placeholders).
    final tier = choirRevealTier;
    final visible = tier < 0 ? 0 : (tier >= 2 ? 6 : tier + 1);
    final glyphY = panel.bottom - 32;
    for (var i = 0; i < visible; i++) {
      final p = Offset(panel.left + 52 + i * 77.0, glyphY);
      // Steady glyph: bowl + flame + tally pips (order i = i+1 pips).
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: 13),
        0,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE4C16A).withValues(alpha: 0.8),
      );
      _drawFlame(canvas, p + const Offset(0, 2), 18, phase: i * 1.7);
      for (var k = 0; k <= i; k++) {
        canvas.drawCircle(
          p + Offset(-18 + k * 7.5, 22),
          2.0,
          Paint()..color = const Color(0xFFE4C16A).withValues(alpha: 0.85),
        );
      }
      if (i > 0) {
        // Order arrow from the previous glyph.
        final prev = Offset(panel.left + 52 + (i - 1) * 77.0, p.dy - 24);
        canvas.drawLine(
          prev + const Offset(14, 0),
          Offset(p.dx - 14, p.dy - 24),
          Paint()
            ..strokeWidth = 1.2
            ..color = const Color(0xFFC4A35A).withValues(alpha: 0.5),
        );
      }
    }
  }

  /// The Ember Epitaph: invisible at stage 0. Insight WRITES the maxim into
  /// the floor — an ember-quill draws each line in — then the garden planter
  /// settles in beside it. Plant, flame and gusts grow the blaze; when the
  /// third gust lands, a burn-front sweeps the script and the words stay lit
  /// in fire. Text painters are cached once; per-frame work is clip + paint.
  void _drawEmberEpitaph(Canvas canvas) {
    final won = discoveredClouds.contains(kFireEpitaphEggId);
    final stage = won ? 3 : epitaphStage;

    // Ghost cipher: before insight finds it, the dead words sit in the
    // mural's upper half as near-invisible scrambled soot.
    _epitaphGhostLines ??= [
      for (final line in kFireEpitaphScrambledLines)
        TextPainter(
          text: TextSpan(
            text: line,
            style: TextStyle(
              color: const Color(0xFF9A8A74).withValues(alpha: 0.07),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    // The quill's script stays SCRAMBLED — insight bares the writing, not
    // its meaning. Only the fire unscrambles it.
    _epitaphSootLines ??= [
      for (final line in kFireEpitaphScrambledLines)
        TextPainter(
          text: TextSpan(
            text: line,
            style: TextStyle(
              color: const Color(0xFF9A8A74).withValues(alpha: 0.38),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    _epitaphFireLines ??= [
      for (final line in kFireEpitaphLines)
        TextPainter(
          text: TextSpan(
            text: line,
            style: const TextStyle(
              color: Color(0xFFFFC07A),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.6,
              shadows: [Shadow(color: Color(0xFFFF7A3C), blurRadius: 7)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];

    Offset lineTopLeft(TextPainter tp, int i) => Offset(
      _kEpitaphTextAnchor.dx - tp.width / 2,
      _kEpitaphTextAnchor.dy + i * _kEpitaphLineHeight - tp.height / 2,
    );

    if (stage == 0) {
      // Unfound: just the ghost cipher, refusing to be read.
      for (var i = 0; i < _epitaphGhostLines!.length; i++) {
        final tp = _epitaphGhostLines![i];
        tp.paint(canvas, lineTopLeft(tp, i));
      }
      return;
    }

    // The scrambled script, written line by line behind an ember-quill.
    // Once the maxim ignites, each line's cipher survives only AHEAD of the
    // advancing burn-front — the fire consumes it as it unscrambles.
    for (var i = 0; i < _epitaphSootLines!.length; i++) {
      final tp = _epitaphSootLines![i];
      final reveal = won
          ? 1.0
          : ((epitaphWriteT - i * _kEpitaphWriteStagger) /
                    _kEpitaphWritePerLine)
                .clamp(0.0, 1.0);
      if (reveal <= 0) continue;
      final burn = won
          ? ((epitaphBlazeT - i * _kEpitaphBurnStagger) / _kEpitaphBurnPerLine)
                .clamp(0.0, 1.0)
          : 0.0;
      if (burn >= 1) continue; // fully consumed by the fire
      final pos = lineTopLeft(tp, i);
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(
          pos.dx - 3 + (tp.width + 6) * burn,
          pos.dy - 3,
          (tp.width + 6) * (reveal - burn).clamp(0.0, 1.0),
          tp.height + 6,
        ),
      );
      tp.paint(canvas, pos);
      canvas.restore();
      // The quill: a bright ember tracing the stroke being written.
      if (reveal < 1 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          Offset(pos.dx + tp.width * reveal, pos.dy + tp.height * 0.55),
          5,
          const Color(0xFFFFB46B).withValues(
            alpha: 0.55 + 0.25 * sin(_time * 9),
          ),
        );
      }
    }

    // The burn-front: fire-script sweeps over the soot, then stays lit.
    if (won) {
      for (var i = 0; i < kFireEpitaphLines.length; i++) {
        final tp = _epitaphFireLines![i];
        final burn =
            ((epitaphBlazeT - i * _kEpitaphBurnStagger) / _kEpitaphBurnPerLine)
                .clamp(0.0, 1.0);
        if (burn <= 0) continue;
        final pos = Offset(
          _kEpitaphTextAnchor.dx - tp.width / 2,
          _kEpitaphTextAnchor.dy + i * _kEpitaphLineHeight - tp.height / 2,
        );
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(
            pos.dx - 3,
            pos.dy - 3,
            (tp.width + 6) * burn,
            tp.height + 6,
          ),
        );
        tp.paint(canvas, pos);
        canvas.restore();
        if (burn < 1 && _fx.ready) {
          // Sparks at the advancing burn-front.
          drawGlow(
            canvas,
            _fx.glow!,
            Offset(pos.dx + tp.width * burn, pos.dy + tp.height * 0.5),
            14,
            const Color(0xFFFF8A50).withValues(alpha: 0.5),
          );
        }
      }
      // Settled: the script breathes with fire-light and keeps tiny flames.
      final settled =
          epitaphBlazeT >
          (kFireEpitaphLines.length - 1) * _kEpitaphBurnStagger +
              _kEpitaphBurnPerLine;
      if (settled) {
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            _kEpitaphTextAnchor + const Offset(0, _kEpitaphLineHeight),
            120,
            const Color(0xFFFF8A50).withValues(
              alpha: 0.10 + 0.05 * sin(_time * 2.4),
            ),
          );
        }
        _drawFlame(
          canvas,
          _kEpitaphTextAnchor + const Offset(-118, 6),
          12,
          phase: 1.7,
        );
        _drawFlame(
          canvas,
          _kEpitaphTextAnchor + const Offset(126, 60),
          12,
          phase: 3.9,
        );
      }
    }

    // The garden planter settles in once the writing finishes.
    final planterIn = won
        ? 1.0
        : ((epitaphWriteT - _epitaphWriteDuration) / 0.8).clamp(0.0, 1.0);
    if (planterIn <= 0) return;
    final p = kEmberEpitaphPlanter;
    final planter = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p, width: 56, height: 22),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      planter,
      Paint()
        ..color = const Color(0xFF15100B).withValues(alpha: 0.9 * planterIn),
    );
    canvas.drawRRect(
      planter,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF74613A).withValues(alpha: 0.65 * planterIn),
    );
    // Vines, once planted.
    if (stage >= 2 && !won) {
      final vine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF6FAF5A).withValues(alpha: 0.85);
      for (var i = 0; i < 3; i++) {
        final ox = -14.0 + i * 14;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx + ox, p.dy + 6)
            ..quadraticBezierTo(
              p.dx + ox - 5,
              p.dy - 6,
              p.dx + ox + 3,
              p.dy - 14 - i * 3.0,
            ),
          vine,
        );
      }
    }
    // The flame, swelling with each gust — and it KEEPS its full height
    // once the maxim is won (a fire that never dims again).
    if (stage >= 3) {
      final h = won ? 46.0 : 15.0 + epitaphFans * 9.0;
      _drawFlame(canvas, p + const Offset(0, 4), h, phase: 4.2);
      if (won && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p - const Offset(0, 18),
          52,
          const Color(0xFFFF8A50).withValues(
            alpha: 0.16 + 0.06 * sin(_time * 3.1),
          ),
        );
      }
    }
  }

  void _drawChoirStalls(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final stall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF3E2E22).withValues(alpha: 0.55);
    // Two facing banks of stalls flanking the processional line.
    for (var i = 0; i < 3; i++) {
      final y = b.center.dy - 90 + i * 90.0;
      canvas.drawLine(Offset(b.left + 90, y), Offset(b.left + 240, y), stall);
      canvas.drawLine(Offset(b.right - 240, y), Offset(b.right - 90, y), stall);
    }
  }

  /// The cryptic floor mural: a faded soot diagram of the six braziers at
  /// the choir's heart. The connecting path is broken and barely-there, but
  /// a faint ember endlessly WALKS the true order — patient eyes can decode
  /// the rite unaided; Mask insight (choirRevealTier) brightens everything.
  void _drawChoirFloorMural(Canvas canvas, DungeonRoom room) {
    final star = room.brazierStarIndex;
    if (star == null || room.braziers.length < 2) return;
    final done = hasStar(star);
    final c = room.bounds.center + const Offset(0, 8);
    final tier = choirRevealTier;
    // Visibility scales with insight; the solved rite settles into a calm,
    // legible memorial.
    final pathAlpha = done
        ? 0.20
        : tier >= 2
        ? 0.22
        : tier >= 1
        ? 0.14
        : 0.07;
    final ordered = [...room.braziers]..sort((a, b) => a.order - b.order);
    Offset mapPt(Offset p) => c + (p - room.bounds.center) * 0.26;

    // Worn ritual ring framing the diagram.
    canvas.drawCircle(
      c,
      104,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF4A382C).withValues(alpha: 0.35),
    );
    // Broken soot path through the braziers in rite order: each segment is
    // drawn as worn fragments, never a clean line.
    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFC4A35A).withValues(alpha: pathAlpha);
    for (var i = 0; i < ordered.length - 1; i++) {
      final a = mapPt(ordered[i].position);
      final b = mapPt(ordered[i + 1].position);
      for (final (f0, f1) in const [(0.06, 0.26), (0.42, 0.58), (0.76, 0.94)]) {
        canvas.drawLine(
          Offset.lerp(a, b, f0)!,
          Offset.lerp(a, b, f1)!,
          pathPaint,
        );
      }
    }
    // Brazier glyphs: a tick per brazier; the FIRST carries a tiny flame
    // mark (the rite's start), pips appear with insight.
    for (var i = 0; i < ordered.length; i++) {
      final p = mapPt(ordered[i].position);
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xFFC4A35A).withValues(
            alpha: (pathAlpha * 2.2).clamp(0.0, 0.6),
          ),
      );
      if (i == 0) {
        _drawFlame(
          canvas,
          p + const Offset(0, 3),
          10,
          outer: const Color(0xFF8A5A48),
          phase: 5.0,
        );
      }
      if (tier >= 2 && !done) {
        for (var k = 0; k <= i; k++) {
          canvas.drawCircle(
            p + Offset(-9 + k * 4.0, -10),
            1.4,
            Paint()..color = const Color(0xFFE8DFC8).withValues(alpha: 0.5),
          );
        }
      }
    }
    if (done) return;
    // The walking ember: one slow lap of the rite, pausing nowhere — the
    // mural remembering out loud. Brighter the more insight has steadied it.
    final emberAlpha = tier >= 2
        ? 0.5
        : tier >= 1
        ? 0.34
        : 0.20;
    final segs = ordered.length - 1;
    final u = (_time % 11.0) / 11.0 * segs;
    final si = u.floor().clamp(0, segs - 1);
    final p = Offset.lerp(
      mapPt(ordered[si].position),
      mapPt(ordered[si + 1].position),
      u - si,
    )!;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.mote!,
        p,
        6,
        const Color(0xFFFFB46B).withValues(alpha: emberAlpha),
      );
    }
  }

  void _drawRitualBraziers(Canvas canvas, DungeonRoom room) {
    final star = room.brazierStarIndex;
    final done = star != null && hasStar(star);
    for (final brz in room.braziers) {
      final lit = done || brz.order < ritualProgress;
      _drawBrazier(canvas, brz.position, lit: lit, phase: brz.order * 1.3);
      // Mural knowledge ghosts tally pips over the braziers.
      if (!done && choirRevealTier >= 1) {
        final show = choirRevealTier >= 2 || brz.order <= 1;
        if (show) {
          for (var k = 0; k <= brz.order; k++) {
            canvas.drawCircle(
              brz.position + Offset(-16 + k * 6.5, -42),
              2.0,
              Paint()
                ..color = const Color(0xFFE8DFC8).withValues(
                  alpha: 0.35 + 0.18 * sin(_time * 2.4 + k),
                ),
            );
          }
        }
      }
    }
  }

  void _drawBrazier(
    Canvas canvas,
    Offset p, {
    required bool lit,
    double phase = 0,
  }) {
    // Light pool under a lit basin.
    if (lit && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        p,
        46,
        const Color(0xFFFF8A50).withValues(alpha: 0.18),
      );
    }
    // Tripod legs.
    final leg = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2E211A);
    canvas.drawLine(p + const Offset(-10, 8), p + const Offset(-16, 22), leg);
    canvas.drawLine(p + const Offset(10, 8), p + const Offset(16, 22), leg);
    canvas.drawLine(p + const Offset(0, 10), p + const Offset(0, 24), leg);
    // Iron basin.
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: 16),
      0,
      pi,
      false,
      Paint()..color = const Color(0xFF241812),
    );
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: 16),
      0,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = (lit ? const Color(0xFFC4A35A) : const Color(0xFF4A382C))
            .withValues(alpha: 0.85),
    );
    if (lit) {
      _drawFlame(canvas, p + const Offset(0, 2), 30, phase: phase);
    } else if (_fx.ready) {
      // A dormant rim-ember so cold braziers still read as interactable.
      drawGlow(
        canvas,
        _fx.mote!,
        p + const Offset(5, -2),
        4,
        const Color(0xFFFF8A50).withValues(
          alpha: 0.16 + 0.12 * (0.5 + 0.5 * sin(_time * 2.0 + phase)),
        ),
      );
    }
  }

  void _drawDryFountain(Canvas canvas, Offset c) {
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF4A382C).withValues(alpha: 0.7);
    canvas.drawCircle(c, 52, stone);
    canvas.drawCircle(c, 30, stone);
    canvas.drawCircle(
      c,
      8,
      Paint()..color = const Color(0xFF241812).withValues(alpha: 0.9),
    );
    // Cracks radiating from the dry basin.
    final crack = Paint()
      ..strokeWidth = 1.3
      ..color = const Color(0xFF3A2A20).withValues(alpha: 0.7);
    for (var i = 0; i < 5; i++) {
      final a = i * 1.26 + 0.4;
      final p1 = c + Offset(cos(a), sin(a)) * 52;
      final p2 = c + Offset(cos(a + 0.18), sin(a + 0.18)) * 76;
      canvas.drawLine(p1, p2, crack);
    }
  }

  void _drawVineBeds(Canvas canvas, DungeonRoom room) {
    final star = room.vineStarIndex;
    final done = star != null && hasStar(star);
    for (final bed in room.vineBeds) {
      final state = done ? 2 : (bedStates[bed.id] ?? 0);
      final fx = _bedFx[bed.id] ?? 0;
      final p = bed.position;
      // The bed itself: a soil plot with a scorched border.
      final plot = Rect.fromCenter(center: p, width: 110, height: 84);
      canvas.drawRRect(
        RRect.fromRectAndRadius(plot, const Radius.circular(12)),
        Paint()..color = const Color(0xFF15100B).withValues(alpha: 0.85),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(plot, const Radius.circular(12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF4A382C).withValues(alpha: 0.7),
      );
      switch (state) {
        case 0:
          // Barren: scorch marks.
          final scorch = Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF33261D).withValues(alpha: 0.8);
          canvas.drawLine(p + const Offset(-26, -8), p + const Offset(-8, 6), scorch);
          canvas.drawLine(p + const Offset(6, -12), p + const Offset(22, 2), scorch);
          canvas.drawLine(p + const Offset(-4, 14), p + const Offset(14, 18), scorch);
          break;
        case 1:
          // Overgrown: vine curls.
          final vine = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF6FAF5A).withValues(alpha: 0.85);
          final sway = sin(_time * 1.8) * 3;
          for (var i = 0; i < 3; i++) {
            final ox = -28.0 + i * 26;
            final path = Path()
              ..moveTo(p.dx + ox, p.dy + 28)
              ..quadraticBezierTo(
                p.dx + ox - 12 + sway,
                p.dy + 2,
                p.dx + ox + 6 + sway,
                p.dy - 18 - i * 4,
              );
            canvas.drawPath(path, vine);
            canvas.drawCircle(
              Offset(p.dx + ox + 6 + sway, p.dy - 18 - i * 4),
              3,
              Paint()..color = const Color(0xFF8FCF6A).withValues(alpha: 0.9),
            );
          }
          if (fx > 0 && _fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              p,
              40,
              const Color(0xFF6FAF5A).withValues(alpha: 0.18 * fx),
            );
          }
          break;
        case 2:
          // Revealed: the ash-filled sigil glowing in its groove.
          final glowA = 0.5 + 0.22 * sin(_time * 2.2 + p.dx);
          if (_fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              p,
              44,
              const Color(0xFFFF8A50).withValues(alpha: 0.16 + 0.08 * glowA),
            );
          }
          final sig = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFFFB46B).withValues(alpha: 0.55 + 0.3 * glowA);
          canvas.drawCircle(p, 18, sig);
          final d = 18.0;
          canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy - d)
              ..lineTo(p.dx + d, p.dy)
              ..lineTo(p.dx, p.dy + d)
              ..lineTo(p.dx - d, p.dy)
              ..close(),
            sig,
          );
          if (fx > 0 && _fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              p,
              58,
              const Color(0xFFFFD27A).withValues(alpha: 0.22 * fx),
            );
          }
          break;
      }
    }
  }

  void _drawCinderShrine(Canvas canvas, Offset c) {
    // Pedestal + flame sigil: the cathedral's quiet treasury.
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF74613A).withValues(alpha: 0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 22), width: 76, height: 26),
        const Radius.circular(6),
      ),
      stone,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 2), width: 48, height: 16),
        const Radius.circular(5),
      ),
      stone,
    );
    _drawFlame(canvas, c + const Offset(0, -6), 26, phase: 1.1);
    _drawRuneCircle(
      canvas,
      c,
      66,
      const Color(0xFFC4A35A).withValues(alpha: 0.30),
    );
  }

  void _drawVesperFresco(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final panel = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + 120),
      width: 460,
      height: 130,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()..color = const Color(0xFF0D0907).withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF74613A).withValues(alpha: 0.7),
    );
    // Diagram: a sagging chain of censers, a wind spiral, a tolling bell.
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.6);
    final y = panel.center.dy;
    final chain = Path()..moveTo(panel.left + 40, y - 10);
    chain.quadraticBezierTo(panel.left + 110, y + 26, panel.left + 180, y - 6);
    chain.quadraticBezierTo(panel.left + 250, y + 26, panel.left + 320, y - 10);
    canvas.drawPath(chain, ink);
    for (final dx in const [40.0, 180.0, 320.0]) {
      canvas.drawCircle(Offset(panel.left + dx, y - 8), 6, ink);
    }
    // Wind spiral mid-chain.
    final sp = Offset(panel.left + 250, y - 30);
    final spiral = Path()..moveTo(sp.dx - 14, sp.dy);
    spiral.quadraticBezierTo(sp.dx, sp.dy - 18, sp.dx + 12, sp.dy - 2);
    spiral.quadraticBezierTo(sp.dx + 2, sp.dy + 10, sp.dx - 4, sp.dy + 2);
    canvas.drawPath(spiral, ink);
    // The bell, rung.
    _drawBellShape(
      canvas,
      Offset(panel.right - 60, y - 4),
      14,
      const Color(0xFFE4C16A).withValues(alpha: 0.8),
    );
    // Vestment hooks along the south wall.
    final hook = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF3E2E22).withValues(alpha: 0.6);
    for (var i = 0; i < 5; i++) {
      final p = Offset(b.left + 130 + i * 140.0, b.bottom - 150);
      canvas.drawLine(p, p + const Offset(0, 18), hook);
      canvas.drawCircle(p + const Offset(0, 22), 4, hook);
    }
  }

  void _drawBellShape(Canvas canvas, Offset c, double r, Color color) {
    final bell = Path()
      ..moveTo(c.dx - r * 0.9, c.dy + r * 0.7)
      ..quadraticBezierTo(c.dx - r * 0.85, c.dy - r * 0.7, c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.85, c.dy - r * 0.7, c.dx + r * 0.9, c.dy + r * 0.7)
      ..close();
    canvas.drawPath(
      bell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    canvas.drawCircle(c + Offset(0, r * 0.85), r * 0.2, Paint()..color = color);
  }

  void _drawIncenseChains(Canvas canvas, DungeonRoom room) {
    for (final chain in room.incenseChains) {
      final rung = bellsRung.contains(chain.id) || hasStar(2);
      final checkpoint = _chainCheckpoints[chain.id] ?? 0;
      final flame = _vesperFlames[chain.id];
      // Chain segments: sagging links between censers, ending at the bell.
      final pts = [...chain.nodes, chain.bellPosition];
      final linkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = (rung ? const Color(0xFFC4A35A) : const Color(0xFF5A463A))
            .withValues(alpha: rung ? 0.55 : 0.45);
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i];
        final bp = pts[i + 1];
        final mid = Offset.lerp(a, bp, 0.5)! + const Offset(0, 20);
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(mid.dx, mid.dy, bp.dx, bp.dy),
          linkPaint,
        );
      }
      // Censers: small swinging cups; reached ones keep a coal alive.
      for (var i = 0; i < chain.nodes.length; i++) {
        final p = chain.nodes[i];
        final reached = rung || i <= checkpoint;
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 9),
          0,
          pi,
          false,
          Paint()..color = const Color(0xFF241812),
        );
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 9),
          0,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color =
                (reached ? const Color(0xFFC4A35A) : const Color(0xFF4A382C))
                    .withValues(alpha: 0.85),
        );
        if (reached && _fx.ready && !rung) {
          drawGlow(
            canvas,
            _fx.mote!,
            p,
            5,
            const Color(0xFFFF8A50).withValues(
              alpha: 0.22 + 0.14 * (0.5 + 0.5 * sin(_time * 2.6 + i * 1.4)),
            ),
          );
        }
      }
      // The ember bell.
      final bellColor = rung
          ? const Color(0xFFE4C16A)
          : const Color(0xFF74613A).withValues(alpha: 0.8);
      if (rung && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          chain.bellPosition,
          30,
          const Color(0xFFFFB46B).withValues(alpha: 0.22),
        );
      }
      _drawBellShape(canvas, chain.bellPosition, 16, bellColor);
      // Toll ripples while the last ring still hums.
      if (rung && _bellTollFx > 0) {
        final t = 1 - (_bellTollFx / 2.2);
        canvas.drawCircle(
          chain.bellPosition,
          20 + t * 70,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFFFFD27A).withValues(
              alpha: (0.5 * (1 - t)).clamp(0.0, 0.5),
            ),
        );
      }
      // The live flame, crawling.
      if (flame != null) {
        final p = _chainPoint(chain, flame.segment, flame.t);
        final starving = flame.life < 1.0;
        _drawFlame(
          canvas,
          p + const Offset(0, 6),
          starving ? 16 : 24,
          outer: starving ? const Color(0xFFB05A2C) : const Color(0xFFFF7A3C),
          phase: chain.id.hashCode.toDouble(),
        );
      }
    }
  }

  void _drawBlackFlameAltar(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    // Stepped dais.
    final stone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF74613A).withValues(alpha: 0.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 16), width: 190, height: 96),
        const Radius.circular(14),
      ),
      stone,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 8), width: 130, height: 58),
        const Radius.circular(10),
      ),
      stone,
    );
    // Candelabra flanks.
    for (final side in const [-1.0, 1.0]) {
      final base = c + Offset(side * 130, 30);
      final pole = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2E211A);
      canvas.drawLine(base, base + const Offset(0, -42), pole);
      canvas.drawLine(
        base + const Offset(-14, -30),
        base + const Offset(14, -30),
        pole,
      );
      _drawFlame(canvas, base + const Offset(0, -44), 13, phase: side * 2.0);
      _drawFlame(canvas, base + const Offset(-14, -32), 10, phase: side * 3.1);
      _drawFlame(canvas, base + const Offset(14, -32), 10, phase: side * 1.2);
    }
    if (guardianAwake || hasStar(2)) {
      // The black flame: dark violet body, ember-rimmed.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c - const Offset(0, 16),
          64,
          const Color(0xFF6E2A8A).withValues(alpha: 0.20),
        );
      }
      _drawFlame(
        canvas,
        c + const Offset(0, 4),
        56,
        core: const Color(0xFF35124A),
        outer: const Color(0xFF1A0A26),
        phase: 0.9,
      );
      _drawFlame(
        canvas,
        c + const Offset(0, 4),
        30,
        core: const Color(0xFFFF7A3C),
        outer: const Color(0xFF6E2A14),
        phase: 2.3,
      );
    } else {
      // Dormant: one thin smoke thread rising from the cold altar stone.
      final smoke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF6E5A4A).withValues(alpha: 0.30);
      final path = Path()..moveTo(c.dx, c.dy);
      for (var i = 1; i <= 4; i++) {
        path.quadraticBezierTo(
          c.dx + sin(_time * 1.1 + i * 1.7) * 10,
          c.dy - i * 18.0 + 9,
          c.dx + sin(_time * 1.1 + i * 1.7 + 0.8) * 6,
          c.dy - i * 18.0,
        );
      }
      canvas.drawPath(path, smoke);
    }
  }

  void _drawSanctumRoost(Canvas canvas, DungeonRoom room) {
    final g = room.guardian;
    final c = g?.position ?? room.bounds.center;
    // Scorched ring where the Simurgh's flame has licked the stone for ages.
    canvas.drawCircle(
      c,
      120,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF33261D).withValues(alpha: 0.8),
    );
    final char = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A2A20).withValues(alpha: 0.7);
    for (var i = 0; i < 10; i++) {
      final a = i * 0.628 + 0.25;
      canvas.drawLine(
        c + Offset(cos(a), sin(a)) * 112,
        c + Offset(cos(a), sin(a)) * 132,
        char,
      );
    }
    // Broken arch ruins behind the roost.
    final ruin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF3E2E22).withValues(alpha: 0.6);
    canvas.drawArc(
      Rect.fromCircle(center: c + const Offset(-150, -110), radius: 56),
      pi * 1.1,
      pi * 0.55,
      false,
      ruin,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c + const Offset(160, -96), radius: 48),
      pi * 1.35,
      pi * 0.5,
      false,
      ruin,
    );
    // Ember updrafts around an awake guardian.
    if (guardianAwake && _fx.ready) {
      for (var i = 0; i < 5; i++) {
        final a = i * 1.256 + _time * 0.5;
        final rr = 70 + 28 * sin(_time * 0.9 + i * 2.0);
        final p = c + Offset(cos(a) * rr, sin(a) * rr * 0.7);
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          4.5,
          const Color(0xFFFFB46B).withValues(
            alpha: 0.18 + 0.12 * (0.5 + 0.5 * sin(_time * 3 + i)),
          ),
        );
      }
    }
  }
}
