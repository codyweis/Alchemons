// lib/games/planet_dungeon/planet_dungeon_game_steam.dart
//
// VAPORIS — the Molten Labyrinth. The Steam planet's puzzle logic + rendering,
// as a part of planet_dungeon_game.dart.
//
// World rule: *each star room is a tile grid flooded by creeping lava.*
//   • FIRE melts a rock wall → LAVA (the Earth+Fire→Lava braid: a Fire heart
//     breaks the earthen rock and its fire-blood runs free). It opens a route —
//     and unleashes the flood.
//   • STEAM cools LAVA → standing rock you can walk on, and HALTS its creep.
//   • EARTH raises a wall on open floor → DAMS the flood.
// The molten SLEEPS until Fire first breaks rock in a room — then every beat,
// each lava cell creeps into its open neighbours. Cooling runs on a small
// breath meter (one back per beat), so a wide flood can't be out-cooled, only
// dammed; lava underfoot SCALDS. Strategy is the ORDER: fortify before you
// melt, quench sources before they multiply.
//  • Entry — a Steam creature cracks the relief vent and the seal hisses open.
//  • Star 0 (Causeway) — CHOOSE YOUR BREACH: the wall is a dam; wet sections
//    glow with ember cracks (molten behind — breaching them floods your own
//    chamber), one is dry. Read the wall, breach the quiet stone, cool, cross.
//  • Star 1 (Cinder) — bunker the sanctuary gate BEFORE melting it; the break
//    wakes every cistern in the vault.
//  • Rite (Crucible) — bunker a band-gate, break through, quench the upper
//    cistern at its source, take the pedestal → Boilrog.
//  • Egg — Hidden Harmony: finish the rite without one scald (Heraclitus).

part of 'planet_dungeon_game.dart';

/// Steam's lost maxim discovery id (screen pays 20 gold on first find).
const String kSteamHiddenHarmonyEggId = 'egg:steam_hidden_harmony';

/// Mutable cell codes for the molten grid.
const int _mOpen = 0; // walkable floor
const int _mWall = 1; // meltable rock wall ('#')
const int _mRock = 2; // bedrock — never melts ('X')
const int _mLava = 3; // molten — deadly, creeps ('L')

/// Seconds between lava-creep beats (generous; tune on device).
const double _kMoltenBeat = 2.2;

/// Steam's cooling-breath capacity. One breath per cooled cell, one back per
/// creep beat — you can quench a lane, never out-cool a whole flood.
const int kSteamBreathMax = 3;

/// HP torn away when the molten swallows a creature's footing (a scald).
const double _kScaldDamage = 14.0;

// ── Ring-main pressure economy ──
/// The boiler's head at the start of every run: enough for TWO junctions,
/// not four — choose your way around the ring.
const int kSteamStartPressure = 40;

/// The main never holds more than this.
const int kSteamPressureMax = 99;

/// Pressure returned per lava cell cooled — condensate back to the boiler.
/// The flood is also fuel.
const int kSteamCondensateGain = 4;

/// Pressure gained per Fire stoke of a firebox (the roar draws wisps).
const int kSteamStokeGain = 20;

/// Reach for throwing a junction release / stoking / venting the disc.
const double _kPressureReach = 78.0;

// ── Star 1 · geyser-field knobs (device-tunable) ──
const double _kGeyserPeriod = 6.0;
const double _kGeyserBlast = 2.4;
const double _kGeyserReach = 44.0;
const double _kBlastReach = 96.0;

/// A riser's throw: this far, plus this much again for every mouth shut.
const double _kThrowBase = 120.0;
const double _kThrowPerCap = 55.0;
const int _kBodyHoldLimit = 3;
const double _kRockRaiseSeconds = 0.55;
const double _kRockReach = 46.0;
const double _kRockPlaceAhead = 52.0;
const double _kRockRadius = 24.0;

extension MoltenLabyrinth on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetPressureState() {
    if (!_isVapor) return;
    moltenCells.clear();
    freshLava.clear();
    moltenBeat = _kMoltenBeat;
    moltenRiteDone = false;
    wokeRooms.clear();
    steamBreath = kSteamBreathMax;
    moltenScalds = 0;
    _moltenPulse = 0;
    boilerPressure = kSteamStartPressure;
    unclampedSeals.clear();
    burstDiscBlown = false;
    cappedGeysers.clear();
    geyserCycle = 0;
    earthRock = null;
    earthRockRaise = 0;
    burstCapstoneRooms.clear();
  }

  // ── STAR 1 · THE GEYSER FIELD ────────────────────────────
  //
  // Every mouth in the room breathes on ONE cycle: a long build, then a short
  // blast. Capping a mouth (a body on the stone, the rock, or authored
  // rubble) takes it out of the system and its head goes to whatever is still
  // open — so the field grows angrier the closer you get, and the last mouths
  // blow hard enough to throw a body clear. Only the rock can hold one then.

  /// Seconds of the shared geyser cycle: [_kGeyserBlast] of it is the blast.

  /// Standing this close to a mouth caps it (and is where a blast throws you
  /// from, if it is not capped).

  /// A blast at pressure p throws anything within this of the mouth.

  /// The pressure (capped count) at which a blast is strong enough to throw a
  /// BODY off the mouth it is holding. The rock never cares.

  bool get _geyserBlasting =>
      (geyserCycle % _kGeyserPeriod) >= (_kGeyserPeriod - _kGeyserBlast);

  /// 0..1 through the current cycle — the render's build-up, and the fair
  /// warning before every blast.
  double get geyserCharge =>
      ((geyserCycle % _kGeyserPeriod) / (_kGeyserPeriod - _kGeyserBlast)).clamp(
        0.0,
        1.0,
      );

  /// How many mouths are shut right now — the system's pressure.
  int get geyserPressure => cappedGeysers.length;

  /// Every mouth a body, the rock or the rubble is holding, recomputed from
  /// the world each frame (§ state is never an intention).
  void _recomputeCaps(DungeonRoom room) {
    cappedGeysers.clear();
    for (final gy in room.geysers) {
      if (gy.blockedAtStart) {
        cappedGeysers.add(gy.id);
        continue;
      }
      final rock = earthRock;
      if (rock != null &&
          earthRockRaise >= 1 &&
          (rock - gy.position).distance <= _kGeyserReach) {
        cappedGeysers.add(gy.id);
        continue;
      }
      // A RISER's throat is too wide for one body to smother: standing on it
      // does not shut it, it puts you in the plume. Only the stone caps one.
      if (gy.isRiser) continue;
      for (final cr in creatures) {
        if (!cr.alive) continue;
        if ((cr.position - gy.position).distance <= _kGeyserReach) {
          cappedGeysers.add(gy.id);
          break;
        }
      }
    }
  }

  void _updateGeyserField(DungeonCreature a, DungeonRoom room, double dt) {
    if (room.geysers.isEmpty) return;
    final star = room.capstone?.starIndex;
    if (star != null && hasStar(star)) return; // solved: the field sleeps

    if (earthRockRaise < 1 && earthRock != null) {
      earthRockRaise = min(1.0, earthRockRaise + dt / _kRockRaiseSeconds);
    }
    final wasBlasting = _geyserBlasting;
    geyserCycle += dt;
    _recomputeCaps(room);

    // THE BURST: every mouth shut, and the head has one place left to go.
    final cap = room.capstone;
    if (cap != null &&
        !capstoneBurst &&
        cappedGeysers.length >= room.geysers.length) {
      capstoneBurst = true;
      _setHint(
        'Every mouth is shut — the heart takes the whole head and the '
        'slab splits',
        4.0,
      );
      _spawnAlchemyBurst(
        cap.position,
        producedElement: 'Steam',
        reagentElements: const ['Earth'],
        unstable: true,
        particleCount: 34,
        intensity: 1.4,
      );
      if (!hasStar(cap.starIndex)) earnStar(cap.starIndex);
      onChanged();
      return;
    }

    // THE BLAST, on the edge where it opens: everything still open throws.
    if (!wasBlasting && _geyserBlasting) _eruptGeysers(room);

    // STAR 2 — THE LAUNCH: the room is won when the whole party stands on the
    // far shore. (Its capstone is the pedestal there, not a pressure lock.)
    if (cap != null && room.geysers.any((g) => g.isRiser) && !capstoneBurst) {
      final far = room.platforms.isEmpty ? null : room.platforms.last;
      if (far != null &&
          creatures.every(
            (c) => !c.alive || far.inflate(2).contains(c.position),
          ) &&
          creatures.any((c) => c.alive)) {
        capstoneBurst = true;
        _setHint(
          'The whole party stands on the far shore — the pedestal '
          'yields',
          4.0,
        );
        if (!hasStar(cap.starIndex)) earnStar(cap.starIndex);
        onChanged();
      }
    }
  }

  /// Seconds the raised rock takes to heave up out of the floor.

  void _eruptGeysers(DungeonRoom room) {
    final p = geyserPressure;
    var threw = false;
    for (final gy in room.geysers) {
      if (cappedGeysers.contains(gy.id)) continue;
      // A RISER throws whoever is riding it, as far as the shut field allows:
      // every body you send across is one fewer cap behind it, so the throws
      // get weaker the closer the room is to solved. That decay IS the puzzle.
      if (gy.isRiser) {
        for (final cr in creatures) {
          if (!cr.alive) continue;
          if ((cr.position - gy.position).distance > _kGeyserReach) continue;
          final reach = _kThrowBase + _kThrowPerCap * p;
          final aim = Offset(cos(cr.aimAngle), sin(cr.aimAngle));
          final to = _clampToBounds(cr.position + aim * reach, room);
          cr
            ..position = to
            ..lastSafe = _onSolidGround(to, room) ? to : cr.lastSafe;
          _spawnAlchemyBurst(
            gy.position,
            producedElement: 'Steam',
            particleCount: 18,
            intensity: 0.9,
          );
          _setHint(
            'The riser throws ${cr.member.displayName} across the dark',
            2.4,
          );
          threw = true;
        }
        continue;
      }
      for (final cr in creatures) {
        if (!cr.alive) continue;
        final d = (cr.position - gy.position).distance;
        if (d > _kBlastReach) continue;
        // A body ON the mouth is capping it, so it never erupts under anyone;
        // this is for everyone caught standing in the plume's skirt.
        final away = d < 1
            ? const Offset(0, -1)
            : (cr.position - gy.position) / d;
        final shove = 78.0 + 26.0 * p;
        final to = _clampToBounds(cr.position + away * shove, room);
        if (_canPlaceBody(to, cr.position, room)) {
          cr
            ..position = to
            ..lastSafe = to;
        }
        cr.hp = max(0, cr.hp - (6.0 + 3.0 * p) * progressDmgMul);
        threw = true;
      }
      // At full head a plume will even walk the rock off its stone — but only
      // a mouth that is ROARING, which a capped one never is.
      final rock = earthRock;
      if (rock != null && p >= _kBodyHoldLimit) {
        final d = (rock - gy.position).distance;
        if (d <= _kBlastReach && d > 1) {
          final away = (rock - gy.position) / d;
          earthRock = _clampToBounds(rock + away * 40, room);
        }
      }
    }
    if (threw) {
      _setHint('The field blows — it throws you off the stone', 2.4);
      onChanged();
    }
  }

  /// EARTH's verb in this labyrinth: heave one rock out of the floor, and
  /// heave it back down. Only ever ONE — pressing again on your own rock
  /// destroys it, which is what makes WHERE you spend it the question.
  /// Is this creature standing at something the ring-main answers for — a
  /// clamped junction, a stoke port, or the burst disc?
  bool _nearPressureFixture(DungeonCreature a, DungeonRoom room) {
    final port = room.stokePort;
    if (port != null && (a.position - port).distance <= _kPressureReach) {
      return true;
    }
    final disc = room.burstDisc;
    if (disc != null &&
        (a.position - disc.position).distance <= _kPressureReach) {
      return true;
    }
    for (final door in room.doors) {
      if (_sealFor(room, door) == null) continue;
      if (!_sealBlocked(room, door)) continue;
      if ((a.position - door.rect.center).distance <= _kPressureReach) {
        return true;
      }
    }
    return false;
  }

  bool _tryEarthRock(DungeonCreature a) {
    if (!_isVapor) return false;
    final room = currentRoom;
    if (room.geysers.isEmpty) return false;
    if (a.member.element != 'Earth') {
      // A REFUSAL MUST NEVER OUTRANK A THING THAT WOULD ACTUALLY WORK. Earth's
      // stone answers before the ring-main's fixtures on purpose, but this
      // branch claimed EVERY non-Earth press anywhere in a geyser room — and
      // both geyser rooms have pressure-sealed doors. So a Steam creature
      // standing on a clamped junction inside the Cinder Forge got "only Earth
      // raises stone from this floor" and the junction was never thrown: a
      // refusal that was both wrong and about something the player had not
      // asked for. Stand back and let the fixture answer.
      if (_nearPressureFixture(a, room)) return false;
      _setBlockedHint('Only Earth raises stone from this floor');
      return true;
    }
    final rock = earthRock;
    if (rock != null && (a.position - rock).distance <= _kRockReach) {
      earthRock = null;
      earthRockRaise = 0;
      _setHint('The stone sinks back into the floor');
      onChanged();
      return true;
    }
    if (rock != null) {
      _setBlockedHint('Your stone already stands — go and unmake it first');
      return true;
    }
    final at =
        a.position +
        Offset(cos(a.aimAngle), sin(a.aimAngle)) * _kRockPlaceAhead;
    final placed = _clampToBounds(at, room);
    if (!_canPlaceBody(placed, a.position, room)) {
      _setBlockedHint('The floor will not give up a stone there');
      return true;
    }
    earthRock = placed;
    earthRockRaise = 0;
    _setHint('Earth heaves a stone up out of the floor');
    _spawnAlchemyBurst(
      placed,
      producedElement: 'Earth',
      particleCount: 16,
      intensity: 0.8,
    );
    onChanged();
    return true;
  }

  /// Walking into the stone shoves it — the only way to move it, so the rock
  /// travels at a walking pace and every metre of it is a decision.
  void _pushEarthRock(DungeonCreature a, DungeonRoom room, Offset before) {
    final rock = earthRock;
    if (rock == null || earthRockRaise < 1) return;
    final d = (a.position - rock).distance;
    if (d >= _kRockRadius + PlanetDungeonGame._radius) return;
    final step = a.position - before;
    if (step.distanceSquared < 0.000001) {
      a.position = before; // standing against it: the stone does not budge
      return;
    }
    final dir = step / step.distance;
    final to = _clampToBounds(rock + dir * step.distance * 1.6, room);
    if (_canPlaceBody(to, rock, room)) {
      earthRock = to;
    } else {
      a.position = before; // the stone is against something solid
    }
  }

  // ── Ring-main junction seals ─────────────────────────────

  String _sealKey(String a, String b) =>
      (a.compareTo(b) < 0) ? '$a|$b' : '$b|$a';

  /// The authored seal on [room] guarding the door to [door.targetRoomId].
  PressureSeal? _sealFor(DungeonRoom room, DungeonDoor door) {
    for (final s in room.pressureSeals) {
      if (s.targetRoomId == door.targetRoomId) return s;
    }
    return null;
  }

  /// True while a junction door's clamp is still down (unpaid this run).
  bool _sealBlocked(DungeonRoom room, DungeonDoor door) {
    final seal = _sealFor(room, door);
    if (seal == null) return false;
    return !unclampedSeals.contains(_sealKey(room.id, seal.targetRoomId));
  }

  /// One BLOCKED clause naming what's missing (§5.6) — how to RAISE the
  /// main (condensate, the firebox) is the manifold's earned reading
  /// (_steamReveal), never a door refusal.
  String _sealDoorHint(DungeonRoom room, DungeonDoor door) {
    final seal = _sealFor(room, door)!;
    if (boilerPressure >= seal.cost) {
      return 'Clamped — the release beside it asks ${seal.cost} of the main';
    }
    return 'The clamp wants ${seal.cost} — the main holds only '
        '$boilerPressure';
  }

  /// Whether the current room is a molten puzzle that can be restarted.
  /// Dispatched from the core `canRestartRoom` (Fire's garth has one too).
  bool get _canRestartVaporRoom =>
      _isVapor &&
      ((layout.rooms[currentRoomId]?.molten) != null ||
          (layout.rooms[currentRoomId]?.geysers.isNotEmpty ?? false));

  /// Wipe the current molten room back to its authored state and return the
  /// party to the chamber entrance — the puzzle's clean-slate button. Earned
  /// stars are untouched (a cleared room has nothing to reset).
  void _restartVaporRoom() {
    if (!_canRestartVaporRoom) return;
    moltenCells.remove(currentRoomId);
    freshLava.remove(currentRoomId);
    wokeRooms.remove(currentRoomId); // the flood goes back to sleep
    // A geyser room resets the same way: the stone sinks, the field re-lays,
    // and the party comes back to the door — which is what keeps a party
    // stranded on the wrong shore from ever being a dead run.
    earthRock = null;
    earthRockRaise = 0;
    cappedGeysers.clear();
    geyserCycle = 0;
    steamBreath = kSteamBreathMax;
    moltenBeat = _kMoltenBeat;
    final spawn = _roomEntrySpawn(currentRoomId);
    for (final c in creatures) {
      c
        ..position = spawn
        ..lastSafe = spawn;
    }
    _fallRecovering = false;
    _moltenFor(
      currentRoom,
    ); // rebuild immediately so render/collision are fresh
    _setHint('The chamber resets — the molten recedes to its banks');
    onChanged();
  }

  /// The spawn a neighbour's door drops you onto when entering [roomId] (always
  /// an authored-open cell); the dungeon entrance as a last resort.
  Offset _roomEntrySpawn(String roomId) {
    for (final r in layout.rooms.values) {
      for (final d in r.doors) {
        if (d.targetRoomId == roomId) return d.targetSpawn;
      }
    }
    return layout.entranceSpawn;
  }

  /// THE SOURCE: the authored molten that sits OUTSIDE the pedestal's own
  /// chamber — the reservoir hanging above the band, not the cisterns you
  /// share the floor with. Found structurally, never by hand-counted rows:
  /// flood-fill the AUTHORED open ground from the pedestal, and any authored
  /// 'L' the fill cannot see is a source, because the band is what separates
  /// them. (So a re-authored crucible cannot silently drift from this rule.)
  List<(int, int)> _riteSourceCells(DungeonRoom room, MoltenGrid g) {
    final ped = _pedestalCell(g);
    if (ped == null) return const [];
    final seen = <int>{ped.$2 * g.cols + ped.$1};
    final queue = <(int, int)>[ped];
    while (queue.isNotEmpty) {
      final (c, r) = queue.removeLast();
      for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nc = c + dc, nr = r + dr;
        if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rowCount) continue;
        if (!seen.add(nr * g.cols + nc)) continue;
        final ch = g.rows[nr][nc];
        // The fill runs over authored floor only: rock and the band stop it,
        // and molten is a destination, not a corridor.
        if (ch == 'X' || ch == '#' || ch == 'L') continue;
        queue.add((nc, nr));
      }
    }
    final out = <(int, int)>[];
    for (var r = 0; r < g.rowCount; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (g.rows[r][c] != 'L') continue;
        if (seen.contains(r * g.cols + c)) continue; // shares your floor
        out.add((c, r));
      }
    }
    return out;
  }

  /// How many SOURCE veins still run. The crucible rite reads this: the
  /// pedestal will not sink while the thing overhead is still pouring.
  int _moltenLavaCount(DungeonRoom room, MoltenGrid g) {
    final grid = _moltenFor(room);
    var n = 0;
    for (final (c, r) in _riteSourceCells(room, g)) {
      if (grid[r][c] == _mLava) n++;
    }
    return n;
  }

  /// §5.6: the refusal names WHAT is owed, never the method — and it counts,
  /// so the readout is the progress bar for the quenching.
  String _riteRefusalHint(int live) => live == 1
      ? 'The crucible will not take you — one last vein still runs'
      : 'The crucible will not take you — $live veins still run';

  /// The mutable cell grid for [room], built lazily from its authored rows.
  List<List<int>> _moltenFor(DungeonRoom room) {
    final cached = moltenCells[room.id];
    if (cached != null) return cached;
    final g = room.molten;
    final grid = <List<int>>[];
    if (g != null) {
      for (final line in g.rows) {
        grid.add([for (final ch in line.split('')) _codeOf(ch)]);
      }
    }
    moltenCells[room.id] = grid;
    return grid;
  }

  int _codeOf(String ch) => switch (ch) {
    '#' => _mWall,
    'X' => _mRock,
    'L' => _mLava,
    _ => _mOpen, // '.', 'P', 'S'
  };

  (double, double) _cellSize(DungeonRoom room, MoltenGrid g) =>
      (room.bounds.width / g.cols, room.bounds.height / g.rowCount);

  /// The (col, row) of [p] in [room]'s grid, or (-1, -1) if outside.
  (int, int) _cellAt(Offset p, DungeonRoom room, MoltenGrid g) {
    final (cw, ch) = _cellSize(room, g);
    final c = ((p.dx - room.bounds.left) / cw).floor();
    final r = ((p.dy - room.bounds.top) / ch).floor();
    if (c < 0 || r < 0 || c >= g.cols || r >= g.rowCount) return (-1, -1);
    return (c, r);
  }

  Offset _cellCenter(DungeonRoom room, MoltenGrid g, int c, int r) {
    final (cw, ch) = _cellSize(room, g);
    return Offset(
      room.bounds.left + (c + 0.5) * cw,
      room.bounds.top + (r + 0.5) * ch,
    );
  }

  /// The pedestal cell ('P'), or null.
  (int, int)? _pedestalCell(MoltenGrid g) {
    for (var r = 0; r < g.rowCount; r++) {
      final i = g.rows[r].indexOf('P');
      if (i >= 0) return (i, r);
    }
    return null;
  }

  /// A molten room is "cleared" once its star banks (or, for the rite grid, once
  /// the rite is done). Cleared rooms freeze: the lava is cooled away for good.
  bool _moltenCleared(DungeonRoom room, MoltenGrid g) {
    if (g.starIndex != null) return hasStar(g.starIndex!);
    return moltenRiteDone;
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updatePressure(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isVapor) return;
    _moltenPulse = (_moltenPulse + dt) % 1000.0;
    // The guardian wakes once the rite is done, even from the (grid-less) heart.
    _maybeWakeBoilrog(room);
    final g = room.molten;
    if (g == null) return;
    final grid = _moltenFor(room);
    if (grid.isEmpty) return;

    // Cleared → cool every remaining lava cell once, then hold inert.
    if (_moltenCleared(room, g)) {
      for (final row in grid) {
        for (var c = 0; c < row.length; c++) {
          if (row[c] == _mLava) row[c] = _mOpen;
        }
      }
      return;
    }

    // The flood creeps on the beat — but only once WOKEN (the molten sleeps
    // until Fire first breaks rock in this room). Each beat also returns one
    // cooling breath, woken or not.
    moltenBeat -= dt;
    if (moltenBeat <= 0) {
      moltenBeat = _kMoltenBeat;
      steamBreath = min(kSteamBreathMax, steamBreath + 1);
      // A fresh breach spreads with everything else — that IS the creep.
      if (wokeRooms.contains(room.id)) _spreadLava(grid, g);
      // ...and having run for a beat, it has cooled enough to take the breath.
      freshLava.remove(room.id);
    }

    // Footing: lava under a creature throws it back to safe ground — and the
    // flood spares NO ONE: idle companions standing in its path scald too
    // (they were untouchable before — the flood walked straight through
    // them). If the whole chamber has flooded and there is no open ground,
    // the cell underfoot crusts to a foothold so no one is ever frozen (and
    // the restart button is the clean-slate option).
    for (final cr in creatures) {
      if (cr.hp <= 0) continue;
      final isActive = identical(cr, a);
      if (isActive && _fallRecovering) continue;
      final (col, r) = _cellAt(cr.position, room, g);
      if (col < 0) continue;
      if (grid[r][col] == _mLava) {
        // A scald: the molten bites (and spoils the Hidden Harmony this run).
        moltenScalds++;
        cr.hp = max(0, cr.hp - _kScaldDamage);
        final safe = _moltenSafe(cr, room, g, grid);
        final (sc, sr) = _cellAt(safe, room, g);
        if (sc < 0 || grid[sr][sc] != _mOpen) {
          grid[r][col] = _mOpen; // crust a foothold — never strand anyone
          cr.lastSafe = cr.position;
          if (isActive) {
            _setHint(
              'The molten scalds and closes in — your footing crusts '
              'to bare stone',
            );
          }
        } else if (isActive) {
          _beginFallRecovery(
            cr,
            safe,
            hint: 'The molten scalds — you scramble to cool ground',
          );
        } else {
          // Companions scramble instantly (no camera recovery beat) — and
          // only ever to ground they could actually REACH.
          cr
            ..position = safe
            ..lastSafe = safe;
          _setHint(
            '${cr.member.displayName} scrambles from the molten, '
            'scalded',
          );
        }
      } else if (grid[r][col] == _mOpen) {
        cr.lastSafe = cr.position;
      }
    }
    final (col, r) = _cellAt(a.position, room, g);
    final onGrid = col >= 0;

    // Pedestal reached → bank the star, or perform the rite.
    final ped = _pedestalCell(g);
    if (ped != null && onGrid && col == ped.$1 && r == ped.$2) {
      if (g.starIndex != null && !hasStar(g.starIndex!)) {
        _setHint('You stand on the cooled pedestal — the molten yields to you');
        earnStar(g.starIndex!);
      } else if (g.starIndex == null && !moltenRiteDone) {
        // THE RITE IS A QUENCHING (reworked 2026-08-14). The pedestal used to
        // sink for anyone who reached it, which made the crucible a 3.0s walk:
        // break a band, drop through, touch it — the reservoir overhead and
        // both cisterns never acted, because a flood that creeps one cell a
        // beat can never catch a walker who only has to walk once. So the
        // crucible now demands what this planet has been teaching all along:
        // the SOURCE, quenched. Every last drop of molten in the chamber must
        // be stilled — and since the cisterns lie beyond the band, you have to
        // break in to reach them, which wakes everything you have not yet
        // dealt with. Order is the whole rite: still the reservoir before you
        // break, dam what you cannot outpace, and quench the rest.
        final live = _moltenLavaCount(room, g);
        if (live > 0) {
          _setBlockedHint(_riteRefusalHint(live));
        } else {
          moltenRiteDone = true;
          _setHint(
            'The crucible pedestal sinks — Boilrog heaves up from the heart',
            4.0,
          );
          _maybeEarnHiddenHarmony(room);
        }
      }
    }
  }

  /// Every meltable gate in [roomId]'s band, and whether it is WET — asked
  /// through the REAL rule, so the layout test's proof cannot drift from the
  /// thing the renderer draws and the player reads.
  ///
  /// This exists because the crucible shipped with the cisterns one column
  /// off: diagonally beside the gates rather than orthogonally behind them.
  /// `_wallIsWet` looks at the four orthogonal neighbours only, so not one
  /// gate on the planet was ever wet, and choose-your-breach — the dungeon's
  /// first lesson, per the design doc — had no instance in the built game.
  @visibleForTesting
  Map<String, bool> gateWetness(String roomId) {
    final room = layout.rooms[roomId]!;
    final g = room.molten;
    if (g == null) return const {};
    final grid = _moltenFor(room);
    final out = <String, bool>{};
    for (var r = 0; r < g.rowCount; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (g.rows[r][c] != '#') continue;
        out['$c,$r'] = _wallIsWet(grid, g, c, r);
      }
    }
    return out;
  }

  /// A wall cell is WET when molten leans on it from any side — breaching it
  /// releases the reservoir. Rendered as ember cracks; hinted up close.
  bool _wallIsWet(List<List<int>> grid, MoltenGrid g, int c, int r) {
    for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nc = c + dc, nr = r + dr;
      if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rowCount) continue;
      if (grid[nr][nc] == _mLava) return true;
    }
    return false;
  }

  /// One creep step: each lava cell floods its open 4-neighbours (snapshot, so a
  /// single beat advances exactly one ring).
  void _spreadLava(List<List<int>> grid, MoltenGrid g) {
    final next = <(int, int)>[];
    for (var r = 0; r < g.rowCount; r++) {
      for (var c = 0; c < g.cols; c++) {
        if (grid[r][c] != _mLava) continue;
        for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final nc = c + dc, nr = r + dr;
          if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rowCount) continue;
          if (grid[nr][nc] == _mOpen) next.add((nc, nr));
        }
      }
    }
    for (final (c, r) in next) {
      grid[r][c] = _mLava;
    }
  }

  /// The nearest open ground the creature could actually SCRAMBLE to: a BFS
  /// from its cell through open/molten cells only. Walls and bedrock block
  /// the search — the old nearest-by-distance spiral would happily pick a
  /// cell on the far side of the dam and teleport the creature through it.
  Offset _moltenSafe(
    DungeonCreature a,
    DungeonRoom room,
    MoltenGrid g,
    List<List<int>> grid,
  ) {
    final (lc, lr) = _cellAt(a.lastSafe, room, g);
    if (lc >= 0 && grid[lr][lc] == _mOpen) return a.lastSafe;
    final (c0, r0) = _cellAt(a.position, room, g);
    if (c0 < 0) return a.lastSafe;
    final visited = <int>{r0 * g.cols + c0};
    final queue = <(int, int)>[(c0, r0)];
    var qi = 0;
    while (qi < queue.length) {
      final (c, r) = queue[qi++];
      if (grid[r][c] == _mOpen) return _cellCenter(room, g, c, r);
      for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nc = c + dc, nr = r + dr;
        if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rowCount) continue;
        if (!visited.add(nr * g.cols + nc)) continue;
        final code = grid[nr][nc];
        if (code == _mOpen || code == _mLava) queue.add((nc, nr));
      }
    }
    // No reachable open ground — the caller crusts a foothold underfoot.
    return a.position;
  }

  void _maybeWakeBoilrog(DungeonRoom room) {
    final guardian = room.guardian;
    if (guardian == null || guardianAwake || hasStar(guardian.starIndex)) {
      return;
    }
    if (!moltenRiteDone) return;
    guardianAwake = true;
    guardianHp = PlanetDungeonGame.maxGuardianHp;
    _setHint(
      'Boilrog heaves up from the furnace-heart, wreathed in steam',
      4.2,
    );
    spawnWispWave(
      element: 'Steam',
      center: guardian.position,
      count: 3,
      unstable: true,
      announce: false,
    );
  }

  /// The Hidden Harmony (Heraclitus): finish the whole labyrinth — all three
  /// molten chambers, the rite included — without the molten EVER swallowing a
  /// creature's footing. Zero scalds, one run. Checked as the rite completes.
  void _maybeEarnHiddenHarmony(DungeonRoom room) {
    if (discoveredClouds.contains(kSteamHiddenHarmonyEggId)) return;
    if (moltenScalds != 0) return;
    // THE RITE OF THREE pays this out (see `beginMaximRite`).
    _setHint('The molten never once touched you', 4.0);
    beginMaximRite(kSteamHiddenHarmonyEggId, room.bounds.center);
    _spawnAlchemyBurst(
      room.bounds.center,
      producedElement: 'Steam',
      unstable: true,
      particleCount: 36,
      intensity: 1.2,
    );
  }

  // ── Action button ────────────────────────────────────────

  bool _tryPressure(DungeonCreature a) {
    if (!_isVapor) return false;
    final room = currentRoom;

    // Entry rite: a Steam creature cracks the gate vent → the seal hisses open.
    final vent = room.steamVent;
    if (vent != null &&
        room.id == layout.entranceRoomId &&
        !entryDoorRevealed) {
      if ((a.position - vent).distance <= 64) {
        if (a.member.element != 'Steam') {
          _setHint('The clamped seal answers only to Steam');
          return true;
        }
        entryDoorRevealed = true;
        _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
        _setHint('Steam bleeds the clamp — the pressure door hisses open');
        _spawnAlchemyBurst(
          room.doors.isNotEmpty ? room.doors.first.rect.center : vent,
          producedElement: 'Steam',
          unstable: true,
          particleCount: 28,
          intensity: 1.1,
        );
        return true;
      }
    }

    // Junction release: any hands can throw it — the MAIN pays, not the
    // creature. Standing near a clamped junction door spends its cost.
    for (final door in room.doors) {
      final seal = _sealFor(room, door);
      if (seal == null || !_sealBlocked(room, door)) continue;
      if ((a.position - door.rect.center).distance > _kPressureReach) continue;
      if (boilerPressure < seal.cost) {
        _setHint(
          'The clamp wants ${seal.cost} pressure — the main holds '
          'only $boilerPressure',
        );
        return true;
      }
      boilerPressure -= seal.cost;
      unclampedSeals.add(_sealKey(room.id, seal.targetRoomId));
      // The gauge carries the number (§5.6 — state is not speech).
      _setHint('The main surges into the clamp — the junction hisses open');
      _spawnAlchemyBurst(
        door.rect.center,
        producedElement: 'Steam',
        particleCount: 20,
        intensity: 1.0,
      );
      return true;
    }

    // Stoke firebox: Fire feeds the main (+20) — and the roar draws wisps.
    final port = room.stokePort;
    if (port != null && (a.position - port).distance <= _kPressureReach) {
      if (a.member.element != 'Fire') {
        _setHint('Only Fire can stoke the firebox');
        return true;
      }
      if (boilerPressure >= kSteamPressureMax) {
        _setHint('The main already strains at its rivets');
        return true;
      }
      boilerPressure = min(kSteamPressureMax, boilerPressure + kSteamStokeGain);
      _setHint(
        'Fire roars in the box — the main surges, and something '
        'stirs at the noise',
      );
      spawnWispWave(
        element: 'Steam',
        center: port,
        count: 2,
        unstable: true,
        announce: false,
      );
      _spawnAlchemyBurst(
        port,
        producedElement: 'Fire',
        particleCount: 18,
        intensity: 1.0,
      );
      return true;
    }

    // Vent the main into the burst-disc: ALL pressure, one surge. At or
    // above the threshold the disc blows and the vault shaft stands open;
    // below it, the valve refuses — the sacrifice must be whole.
    final disc = room.burstDisc;
    if (disc != null &&
        !burstDiscBlown &&
        (a.position - disc.position).distance <= _kPressureReach) {
      if (boilerPressure < disc.threshold) {
        _setHint(
          'The burst-disc wants a surge of ${disc.threshold} at once — '
          'the main holds only $boilerPressure. The valve refuses',
        );
        return true;
      }
      boilerPressure = 0;
      burstDiscBlown = true;
      _setHint(
        'You vent the whole main in one surge — the burst-disc '
        'BLOWS, and the vault shaft stands open',
        4.5,
      );
      _spawnAlchemyBurst(
        disc.position,
        producedElement: 'Steam',
        unstable: true,
        particleCount: 40,
        intensity: 1.4,
      );
      return true;
    }

    final g = room.molten;
    if (g == null) return false;
    if (_moltenCleared(room, g)) return false;
    final grid = _moltenFor(room);
    if (grid.isEmpty) return false;

    final target = _targetCell(a, room, g);
    if (target == null) return false;
    final (c, r) = target;
    final code = grid[r][c];
    final el = a.member.element;
    final at = _cellCenter(room, g, c, r);

    switch (el) {
      case 'Fire':
        if (code == _mWall) {
          final wet = _wallIsWet(grid, g, c, r);
          grid[r][c] = _mLava;
          // The breach RUNS: too hot to quench until it has had its beat.
          // (The clock is deliberately NOT reset here either — resetting it
          // per melt let a player stall the whole flood by breaking rock on a
          // loop.)
          (freshLava[room.id] ??= <int>{}).add(r * g.cols + c);
          final woke = wokeRooms.add(room.id);
          _setHint(
            wet
                ? 'The dam gives way — the reservoir pours through your breach!'
                : woke
                ? 'Fire breaks the rock — and the sleeping cisterns WAKE'
                : 'Fire breaks the rock — the fire-blood runs free',
          );
          _spawnAlchemyBurst(
            at,
            producedElement: 'Lava',
            reagentElements: const ['Earth', 'Fire'],
            unstable: true,
            particleCount: 22,
            intensity: 1.1,
          );
        } else if (code == _mRock) {
          _setHint('This bedrock will not melt');
        } else {
          _setHint('Fire finds no rock wall to melt here');
        }
        return true;
      case 'Steam':
        if (code == _mLava) {
          if (freshLava[room.id]?.contains(r * g.cols + c) ?? false) {
            // §5.6 BLOCKED: names what is wrong, never the method.
            _setBlockedHint(
              'The fire-blood is still running — your breath '
              'flashes off it',
            );
            return true;
          }
          if (steamBreath <= 0) {
            _setHint('Your cooling breath is spent — it gathers with the beat');
            return true;
          }
          steamBreath--;
          grid[r][c] = _mOpen;
          // Condensate: cooled molten returns to the main as pressure.
          final gained = min(
            kSteamCondensateGain,
            kSteamPressureMax - boilerPressure,
          );
          boilerPressure += gained;
          _setHint(
            gained > 0
                ? 'Steam cools the molten to standing stone — condensate '
                      'returns to the main'
                : 'Steam cools the molten to standing stone',
          );
          _spawnAlchemyBurst(
            at,
            producedElement: 'Steam',
            particleCount: 16,
            intensity: 0.8,
          );
        } else {
          _setHint('Steam finds no molten to cool here');
        }
        return true;
      case 'Earth':
        final ped = _pedestalCell(g);
        final onPed = ped != null && ped.$1 == c && ped.$2 == r;
        // Never entomb a companion: a cell someone stands on stays open.
        final occupied = creatures.any((cr) {
          if (cr.hp <= 0) return false;
          final (cc, rr) = _cellAt(cr.position, room, g);
          return cc == c && rr == r;
        });
        if (occupied) {
          _setHint('A companion stands there — the wall will not rise');
          return true;
        }
        if (code == _mOpen && !onPed) {
          grid[r][c] = _mWall;
          // ELEMENT-ONLY: any Earth drives the wall home, clean and silent.
          _setHint('The wall drives home — the flood is dammed');
          _spawnAlchemyBurst(
            at,
            producedElement: 'Earth',
            particleCount: 14,
            intensity: 0.7,
          );
        } else {
          _setHint('Earth can only wall up open ground');
        }
        return true;
      default:
        _setHint('$el has no power over the molten here');
        return true;
    }
  }

  /// The cell the active creature is aiming at (the full joystick direction
  /// picks one of 4 dirs — [DungeonCreature.aimAngle], NOT the left/right
  /// sprite-flip angle, so cells above and below are targetable).
  (int, int)? _targetCell(DungeonCreature a, DungeonRoom room, MoltenGrid g) {
    final (col, r) = _cellAt(a.position, room, g);
    if (col < 0) return null;
    final dx = cos(a.aimAngle), dy = sin(a.aimAngle);
    var tc = col, tr = r;
    if (dx.abs() >= dy.abs()) {
      tc += dx >= 0 ? 1 : -1;
    } else {
      tr += dy >= 0 ? 1 : -1;
    }
    if (tc < 0 || tr < 0 || tc >= g.cols || tr >= g.rowCount) return null;
    return (tc, tr);
  }

  // ── Insight (Mask) ───────────────────────────────────────

  void _steamReveal(DungeonCreature a, DungeonRoom room) {
    final g = room.molten;
    if (g == null) {
      // The manifolds: insight reads the ring's ECONOMY, not a grid.
      if (room.pressureSeals.isNotEmpty || room.burstDisc != null) {
        _setHint(
          'The main starts with $kSteamStartPressure and each junction '
          'drinks 15 — the whole ring cannot be bought. Cooled molten '
          'condenses back (+$kSteamCondensateGain a cell), a stoked '
          'firebox feeds it more; the burst-disc yields only to a '
          'surge of 60',
          5.5,
        );
        return;
      }
      _setHint(_nothingHiddenLine());
      return;
    }
    _setHint(switch (g.starIndex) {
      0 =>
        'The wall is a dam — where the rock glows, molten leans on it; '
            'breach the dark, quiet stone and cool your doorway. Yet a bold '
            'founder might TAP a wet face on purpose: a dammed flood, cooled '
            'cell by cell, bleeds condensate for the main',
      1 =>
        'Every cistern wakes the moment you melt the gate — raise your '
            'walls around the gate mouth FIRST, then break through',
      _ =>
        'Bunker a gate, break it, and quench the far cistern at its source '
            'before it multiplies — then take the pedestal',
    });
  }

  // ── Collision ────────────────────────────────────────────

  /// Walls, bedrock, and lava block movement; cleared rooms are open footing.
  bool _steamBlocksAt(Offset center, DungeonRoom room) {
    final g = room.molten;
    if (g == null || flightActive) return false;
    final grid = _moltenFor(room);
    if (grid.isEmpty) return false;
    // Doors sit on the grid's bedrock border — carve a passage corridor
    // through the collision so every door stays walkable on foot.
    for (final d in room.doors) {
      final r = d.rect;
      final pass = r.width >= r.height
          ? Rect.fromLTRB(r.left, r.top - 90, r.right, r.bottom + 90)
          : Rect.fromLTRB(r.left - 90, r.top, r.right + 90, r.bottom);
      if (pass.contains(center)) return false;
    }
    if (_moltenCleared(room, g)) {
      // Frozen-solid rooms keep only their walls/bedrock; lava is cooled away.
      final (c, r) = _cellAt(center, room, g);
      if (c < 0) return true;
      return grid[r][c] == _mWall || grid[r][c] == _mRock;
    }
    final (c, r) = _cellAt(center, room, g);
    if (c < 0) return true;
    final code = grid[r][c];
    return code == _mWall || code == _mRock || code == _mLava;
  }

  // ── Hints ────────────────────────────────────────────────

  void _steamAmbientHint(DungeonCreature a, DungeonRoom room) {
    final vent = room.steamVent;
    if (vent != null &&
        !entryDoorRevealed &&
        (a.position - vent).distance < 70) {
      _setAmbientHint('A clamped relief vent hisses at its rivets');
      return;
    }
    for (final door in room.doors) {
      final seal = _sealFor(room, door);
      if (seal != null &&
          _sealBlocked(room, door) &&
          (a.position - door.rect.center).distance < _kPressureReach) {
        _setAmbientHint('A clamped ring junction, wound tight');
        return;
      }
    }
    final port = room.stokePort;
    if (port != null && (a.position - port).distance < _kPressureReach) {
      _setAmbientHint('A firebox — cold iron, breathing old soot');
      return;
    }
    final disc = room.burstDisc;
    if (disc != null &&
        !burstDiscBlown &&
        (a.position - disc.position).distance < _kPressureReach) {
      // The etching is diegetic — the yield condition is the manifold's
      // earned reading (_steamReveal), not proximity copy.
      _setAmbientHint('A riveted burst-disc, etched "${disc.threshold}"');
      return;
    }
    final g = room.molten;
    if (g == null || _moltenCleared(room, g)) return;
    final target = _targetCell(a, room, g);
    if (target == null) return;
    final grid = _moltenFor(room);
    switch (grid[target.$2][target.$1]) {
      case _mWall:
        // The glow/quiet reading IS the dam-wall's authored clue layer —
        // observation only; the breach method is Mask's (_steamReveal).
        _setAmbientHint(
          _wallIsWet(grid, g, target.$1, target.$2)
              ? 'The rock glows hot — something molten presses against its far side'
              : 'Cool, quiet rock — it sounds hollow beyond',
        );
      case _mLava:
        _setAmbientHint('The molten crawls, slow and bright');
    }
  }

  String? _steamObjectiveHint(DungeonRoom room) {
    final g = room.molten;
    if (g == null) {
      if (room.guardian != null) {
        return 'Furnace Heart — face Boilrog: calm it, or strike in its lulls';
      }
      if (room.id == 'manifold_south') {
        return 'South Manifold — the ring main runs through clamped '
            'junctions';
      }
      if (room.id == 'manifold_north') {
        return 'North Manifold — the crucible gate drops from this arc of '
            'the ring';
      }
      if (room.id == 'burst_vault') {
        return 'The Burst Vault — the foundry\'s bottled essence waits below';
      }
      return null;
    }
    // WHAT, never HOW (§5.6): where to breach, when to dam, and how to
    // thread the flood are the foundry's earned readings (_steamReveal).
    // These three lines described the TILE-LAVA CAUSEWAY, which was retired
    // on 2026-08-14 and replaced by the geyser field. The first promised the
    // player 'a dam of old stone' in a room that has not had one for weeks.
    return switch (g.starIndex) {
      0 => 'Ember Causeway — five mouths vent the field, and one is choked',
      1 => 'Cinder Forge — the far shore is across a chasm nothing can leap',
      _ => 'The Crucible — the pedestal stands past the sleeping flood',
    };
  }

  double get _steamMoodTarget {
    switch (currentRoomId) {
      case 'ember_causeway':
      case 'cinder_forge':
        return 0.30;
      case 'crucible':
        return 0.24;
      case 'boiler_heart':
        return guardianAwake ? 0.16 : 0.22;
      case 'boiler_gate':
        return 0.42;
      default:
        return 0.44;
    }
  }

  // ── Rendering ────────────────────────────────────────────

  /// STAR 1/2 — the geyser field. Every mouth shows three things at a glance:
  /// whether it is SHUT, how close the shared cycle is to blowing, and (for a
  /// riser) that its throat is too wide to smother. The capstone cracks wider
  /// the more of the field is held, so the goal reads from across the room.
  void _drawGeyserField(Canvas canvas, DungeonRoom room) {
    if (room.geysers.isEmpty) return;
    final solved = room.capstone != null && hasStar(room.capstone!.starIndex);
    final charge = geyserCharge;
    final blasting = _geyserBlasting;
    final p = geyserPressure;

    for (final gy in room.geysers) {
      final capped = cappedGeysers.contains(gy.id);
      final r = gy.isRiser ? 34.0 : 24.0;

      // THE MOUTH IS A RENT IN THE ROCK, not a hole punched in a floor.
      // Everything below is geology; the steam, glow and strain the FX layer
      // adds on top of it are untouched.
      //
      // Sinter: the mineral a hot spring lays down as it dries, in terraces
      // that build unevenly because one side always runs wetter. Three broken
      // rings, each nudged off-centre, so no two mouths read alike.
      for (var t = 3; t >= 1; t--) {
        final lean = Offset(
          cos(gy.position.dx * 0.11 + t) * 3.0,
          sin(gy.position.dy * 0.13 + t) * 3.0,
        );
        canvas.drawCircle(
          gy.position + lean,
          r + t * 5.0,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF6A5A48),
              const Color(0xFF3A322A),
              t / 3,
            )!.withValues(alpha: 0.55),
        );
      }
      // Wet stain around the lip — dark where it never dries out.
      canvas.drawCircle(
        gy.position,
        r + 7,
        Paint()..color = const Color(0x33100C08),
      );
      // The throat's own broken lip: an irregular ring of stone teeth.
      for (var i = 0; i < 9; i++) {
        final a0 = i * (pi * 2 / 9) + gy.position.dx * 0.01;
        final wob = 0.6 + 0.5 * _forgeNoise(i, gy.id.length + i);
        canvas.drawCircle(
          gy.position + Offset(cos(a0), sin(a0)) * (r + 1),
          2.6 + 3.2 * wob,
          Paint()..color = const Color(0xFF544A3E),
        );
      }
      // The throat itself, cut into it.
      canvas.drawCircle(
        gy.position,
        r,
        Paint()..color = const Color(0xFF17130F),
      );
      canvas.drawCircle(
        gy.position,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = gy.isRiser ? 3.4 : 2.2
          ..color = capped
              ? const Color(0xFF6E6257)
              : const Color(0xFF8FE0EC).withValues(alpha: 0.85),
      );
      // A riser wears a second ring: the throat one body cannot smother.
      if (gy.isRiser) {
        canvas.drawCircle(
          gy.position,
          r - 9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0x778FE0EC),
        );
      }

      if (capped) {
        // SHUT — but a shut mouth is not a dead one: the head it was venting
        // has gone into the rest of the field, and you can see it straining.
        canvas.drawCircle(
          gy.position,
          r - 7,
          Paint()..color = const Color(0xFF5A5048),
        );
        canvas.drawCircle(
          gy.position,
          r - 7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF8A7A68),
        );
        if (!solved && _fx.ready) {
          // Vapour hissing out from under the seal, hardest right before the
          // field blows — the room breathing even where it is held.
          final strain = (0.25 + 0.55 * charge) * (0.6 + 0.1 * p);
          for (var i = 0; i < 4; i++) {
            final a0 = i * pi / 2 + _moltenPulse * 0.6;
            final at =
                gy.position +
                Offset(cos(a0), sin(a0)) * (r - 2) -
                Offset(0, 4 + 7 * strain);
            drawPuff(
              canvas,
              _fx.puff!,
              at,
              r * (0.55 + 0.35 * strain),
              const Color(0xFFCFEAF2).withValues(alpha: 0.10 + 0.16 * strain),
            );
          }
        }
        continue;
      }
      if (solved) continue;

      // OPEN — the throat, then the column. Steam is drawn the way this
      // codebase draws soft things: baked puff sprites blitted cheaply and
      // additive glow, never per-frame blurs (see planet_dungeon_fx.dart).
      final heat = 0.25 + 0.55 * charge;
      // The throat: a hot well that brightens as the head builds under it,
      // with a low collar of steam always creeping over the lip — a live
      // mouth is never perfectly still.
      canvas.drawCircle(
        gy.position,
        r - 8,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF23343C),
            const Color(0xFFCFF4FF),
            heat,
          )!.withValues(alpha: 0.95),
      );
      if (_fx.ready) {
        drawPuff(
          canvas,
          _fx.puff!,
          gy.position + Offset(sin(_moltenPulse * 0.9) * 3, -3),
          r * 1.6,
          const Color(0xFFCFEAF2).withValues(alpha: 0.07 + 0.06 * charge),
        );
      }
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          gy.position,
          r * (0.9 + 0.5 * charge),
          const Color(0xFF8FE0EC).withValues(alpha: 0.10 + 0.30 * charge),
        );
      }

      // Pressure makes the column taller and fatter, so a field nearly shut
      // LOOKS like it is about to tear the lid off.
      // Every mouth you shut sends its head here, so an open mouth in a
      // nearly-shut field is not slightly bigger — it is a column.
      final force = 1.0 + 0.38 * p;

      // Seconds since this blast opened (negative while it is still building).
      // Steam is drawn as puffs BORN at the mouth that then rise, expand and
      // fade — never as one shape that scales, which is what made the old
      // version read as sucking inward instead of blowing out.
      final phase = geyserCycle % _kGeyserPeriod;
      final blastAge = phase - (_kGeyserPeriod - _kGeyserBlast);

      if (_fx.ready) {
        const puffs = 9;
        const puffLife = 1.5; // seconds a parcel of steam stays readable
        const stagger = 0.16; // seconds between parcels leaving the throat
        for (var i = 0; i < puffs; i++) {
          // While building, only a slow mutter of steam leaves the mouth; on
          // the blast the parcels come fast and hard.
          final age = blasting
              ? blastAge - i * stagger
              : (phase * 0.5) - i * (puffLife * 0.9);
          if (age <= 0) continue;
          final life = (age / puffLife).clamp(0.0, 1.0);
          if (life >= 1) continue;

          // Rise: fast off the mouth, slowing as it cools and spreads.
          final ease = 1 - pow(1 - life, 2.2).toDouble();
          final rise = (blasting ? 168.0 : 34.0) * force * ease;
          // Expand as it climbs — a plume mushrooms, it does not stay a rod.
          final w =
              r *
              (blasting ? 1.25 : 0.85) *
              (0.55 + 1.75 * life) *
              (1.0 + 0.16 * p); // the head widens the column too
          // Drift: each parcel keeps its own wander so the column churns.
          final sway =
              sin(_moltenPulse * 1.6 + i * 1.7 + gy.position.dx * 0.02) *
              (4 + 20 * life);
          // Fade: bright at the throat, gone by the top.
          final alpha =
              (blasting ? 0.42 : 0.16) *
              pow(1 - life, 1.35).toDouble() *
              (0.55 + 0.45 * (blasting ? 1.0 : charge));

          drawPuff(
            canvas,
            _fx.puff!,
            Offset(gy.position.dx + sway, gy.position.dy - rise),
            w,
            const Color(0xFFE6F7FF).withValues(alpha: alpha),
          );
        }

        if (blasting) {
          final bt = (blastAge / _kGeyserBlast).clamp(0.0, 1.0);
          // The jet at the throat: hardest as it opens, easing as it spends.
          final jet = pow(1 - bt, 1.6).toDouble();
          drawGlow(
            canvas,
            _fx.glow!,
            gy.position - Offset(0, 26 * force * (1 - jet)),
            r * (1.3 + 1.1 * jet),
            const Color(0xFFBFF2FF).withValues(alpha: 0.10 + 0.34 * jet),
          );
          // Condensate flung UP and out along the jet, falling back as it goes.
          for (var i = 0; i < 6; i++) {
            final k = ((i * 53) % 11) / 11.0;
            final spread = (i - 2.5) * 0.22;
            final travel = (0.35 + 0.65 * k) * bt;
            final d = 150 * force * travel;
            final at =
                gy.position +
                Offset(sin(spread) * d * 0.55, -cos(spread) * d) +
                Offset(0, d * d * 0.0016); // a little gravity on the arc
            drawGlow(
              canvas,
              _fx.mote!,
              at,
              4.5 + 3.0 * (1 - travel),
              const Color(
                0xFFF2FCFF,
              ).withValues(alpha: 0.42 * pow(1 - travel, 1.2).toDouble()),
            );
          }
          // The skirt: a ring rushing OUTWARD from the mouth as it opens —
          // the tell for the throw, travelling the way the force travels.
          canvas.drawCircle(
            gy.position,
            r + (_kBlastReach - r) * Curves.easeOutCubic.transform(bt),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0 * pow(1 - bt, 0.8).toDouble()
              ..color = const Color(
                0xFFBFF2FF,
              ).withValues(alpha: 0.50 * pow(1 - bt, 0.9).toDouble()),
          );
        }
      }
    }

    // THE HEART, ONCE IT IS OPEN: the whole field's head comes up through it
    // and never stops. Driven off _moltenPulse rather than the geyser cycle,
    // because a solved field stops turning — but this plume is the room's
    // standing trophy and has to keep breathing.
    final heart = room.capstone;
    if (heart != null &&
        !room.geysers.any((g) => g.isRiser) &&
        (capstoneBurst || solved) &&
        _fx.ready) {
      const puffs = 12;
      const life = 2.4;
      for (var i = 0; i < puffs; i++) {
        final age = (_moltenPulse * 1.15 + i * (life / puffs)) % life;
        final t = age / life;
        final ease = 1 - pow(1 - t, 2.0).toDouble();
        final rise = 300 * ease;
        final sway = sin(_moltenPulse * 1.1 + i * 1.6) * (6 + 34 * t);
        drawPuff(
          canvas,
          _fx.puff!,
          heart.position + Offset(sway, -rise),
          46 * (0.5 + 2.0 * t),
          const Color(
            0xFFE6F7FF,
          ).withValues(alpha: 0.34 * pow(1 - t, 1.3).toDouble()),
        );
      }
      drawGlow(
        canvas,
        _fx.glow!,
        heart.position - Offset(0, 20),
        70 + 10 * sin(_moltenPulse * 2.0),
        const Color(0xFFBFF2FF).withValues(alpha: 0.30),
      );
      // Condensate raining back down around the throat.
      for (var i = 0; i < 7; i++) {
        final k = ((i * 41) % 13) / 13.0;
        final f = (_moltenPulse * 0.8 + k) % 1.0;
        final a0 = k * pi * 2;
        drawGlow(
          canvas,
          _fx.mote!,
          heart.position +
              Offset(cos(a0) * (26 + 44 * f), -230 * (1 - f) + 60 * f * f),
          4.0,
          const Color(0xFFF2FCFF).withValues(alpha: 0.34 * (1 - f)),
        );
      }
    }

    // THE CAPSTONE at the heart: the slab, cracking wider with the head.
    final cap = room.capstone;
    if (cap != null && !room.geysers.any((g) => g.isRiser)) {
      final burst = capstoneBurst || hasStar(cap.starIndex);
      final frac = room.geysers.isEmpty
          ? 0.0
          : (p / room.geysers.length).clamp(0.0, 1.0);
      // Once it goes, the slab is not a lid any more — it is a throat.
      canvas.drawCircle(
        cap.position,
        30,
        Paint()
          ..color = burst ? const Color(0xFF10181C) : const Color(0xFF3A342C),
      );
      if (burst) {
        // The broken lip: shards left standing around the open mouth.
        final shard = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF8A7A68);
        for (var i = 0; i < 6; i++) {
          final a0 = i * pi / 3 + 0.3;
          canvas.drawLine(
            cap.position + Offset(cos(a0), sin(a0)) * 24,
            cap.position + Offset(cos(a0), sin(a0)) * 34,
            shard,
          );
        }
      }
      canvas.drawCircle(
        cap.position,
        30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = burst ? const Color(0xFFE4C16A) : const Color(0xFF8A7A68),
      );
      // Cracks: they widen and brighten as the field is shut.
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 + 2.4 * frac
        ..color = Color.lerp(
          const Color(0xFF6E6257),
          const Color(0xFFBFF2FF),
          burst ? 1.0 : frac,
        )!.withValues(alpha: 0.55 + 0.45 * frac);
      for (var i = 0; i < 5; i++) {
        final a0 = i * pi * 2 / 5 + 0.4;
        canvas.drawLine(
          cap.position + Offset(cos(a0), sin(a0)) * 8,
          cap.position + Offset(cos(a0), sin(a0)) * (30 * (0.5 + 0.5 * frac)),
          crack,
        );
      }
      if (_fx.ready) {
        // Light bleeding up through the seams, and a plume once it splits.
        if (frac > 0.25 || burst) {
          drawGlow(
            canvas,
            _fx.glow!,
            cap.position,
            40 + 26 * frac,
            const Color(
              0xFFBFF2FF,
            ).withValues(alpha: 0.08 + 0.34 * (burst ? 1.0 : frac)),
          );
        }
        if (burst) {
          for (var i = 0; i < 5; i++) {
            final f = (i + 1) / 5;
            drawPuff(
              canvas,
              _fx.puff!,
              cap.position -
                  Offset(sin(_moltenPulse * 1.4 + i) * 8, 30 + 150 * f),
              46 + 70 * f,
              const Color(0xFFE8FAFF).withValues(alpha: 0.30 - 0.22 * f),
            );
          }
        } else if (frac > 0.5) {
          // Before it goes: a warning wisp squeezing out of the seam.
          drawPuff(
            canvas,
            _fx.puff!,
            cap.position - Offset(0, 26 + 16 * frac),
            34 * frac,
            const Color(0xFFCFEAF2).withValues(alpha: 0.16 * frac),
          );
        }
      }
    }

    // THE STONE: Earth's one boulder, heaving up out of the floor.
    final rock = earthRock;
    if (rock != null) {
      final rise = earthRockRaise.clamp(0.0, 1.0);
      final rr = _kRockRadius * (0.45 + 0.55 * rise);
      canvas.drawOval(
        Rect.fromCenter(
          center: rock + const Offset(0, 8),
          width: rr * 2.1,
          height: rr * 0.8,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.35 * rise),
      );
      canvas.drawCircle(rock, rr, Paint()..color = const Color(0xFF6B5B49));
      canvas.drawCircle(
        rock,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFF9C8A66),
      );
      // A few facets so it reads as cut stone, not a ball.
      final facet = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x99483A2C);
      for (var i = 0; i < 3; i++) {
        final a0 = i * 2.1 + 0.6;
        canvas.drawLine(
          rock + Offset(cos(a0), sin(a0)) * rr * 0.25,
          rock + Offset(cos(a0 + 1.2), sin(a0 + 1.2)) * rr * 0.85,
          facet,
        );
      }
    }
  }

  void _renderSteamFloor(Canvas canvas, DungeonRoom room) {
    final g = room.molten;
    if (g == null) {
      _renderPlainFloor(canvas, room.bounds, room.id == layout.entranceRoomId);
      _drawFoundryFloor(canvas, room);
      _renderForgeAmbient(canvas, room);
      return;
    }
    // THE FLOOR IS CONTINUOUS, and only the MATERIAL sits on it. Drawing an
    // outlined tile for every open cell as well is what made the crucible read
    // as a board game rather than a room — the lattice was the loudest thing
    // in it. Same grid, same rules; the empty squares are simply floor now.
    _renderPlainFloor(canvas, room.bounds, false);
    _drawFoundryFloor(canvas, room);
    final grid = _moltenFor(room);
    final (cw, ch) = _cellSize(room, g);
    final cleared = _moltenCleared(room, g);
    for (var r = 0; r < g.rowCount; r++) {
      for (var c = 0; c < g.cols; c++) {
        final code = grid[r][c];
        if (code == _mOpen || (code == _mLava && cleared)) continue;
        final rect = Rect.fromLTWH(
          room.bounds.left + c * cw,
          room.bounds.top + r * ch,
          cw + 0.6,
          ch + 0.6,
        );
        _renderMoltenCell(canvas, rect, code, cleared);
      }
    }
  }

  /// A stable 0..1 value per grid cell — variation without allocating, and
  /// identical every frame so the floor never crawls.
  double _forgeNoise(int x, int y) {
    var h = x * 374761393 + y * 668265263;
    h = (h ^ (h >> 13)) * 1274126177;
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0;
  }

  /// THE FOUNDRY FLOOR. Vaporis was a 104px square lattice under every
  /// chamber — the same fault Lightning had, and for the same reason: a
  /// planet whose whole premise is a PRESSURE RING-MAIN was drawing itself as
  /// graph paper. It is firebrick laid in offset courses now, sooted and
  /// heat-bloomed, with the ring-main's own pipe runs sunk into it under
  /// bolted flanges and a condensate grate cut across the low side.
  void _drawFoundryFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    const bw = 78.0, bh = 34.0;
    final rows = (b.height / bh).ceil();
    final brick = Paint();
    final joint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x38120C08);

    // 1) Firebrick courses, every other one offset by half a brick.
    for (var r = 0; r < rows; r++) {
      final y = b.top + r * bh;
      final off = (r.isOdd ? bw * 0.5 : 0.0);
      for (var x = b.left - off; x < b.right; x += bw) {
        final c = ((x - b.left) / bw).floor();
        final n = _forgeNoise(c, r);
        final cell = Rect.fromLTWH(x, y, bw, bh).intersect(b);
        if (cell.isEmpty) continue;
        // Fired clay, kilned unevenly — some bricks darker, some scorched
        // ruddy where something hot has stood on them.
        brick.color = Color.lerp(
          const Color(0xFF2A2119),
          n > 0.93 ? const Color(0xFF3E2718) : const Color(0xFF322820),
          n,
        )!.withValues(alpha: 0.82);
        canvas.drawRect(cell, brick);
        canvas.drawRect(cell.deflate(0.5), joint);
      }
    }

    // 2) Heat blooms — the floor remembers what has been poured on it.
    for (var i = 0; i < 5; i++) {
      final n = _forgeNoise(i * 31, room.id.length * 17);
      final m = _forgeNoise(i * 57, room.id.length * 13);
      final c = Offset(b.left + b.width * n, b.top + b.height * m);
      canvas.drawCircle(
        c,
        26 + 40 * n,
        Paint()..color = const Color(0x14FF7A33),
      );
      canvas.drawCircle(
        c,
        14 + 22 * m,
        Paint()..color = const Color(0x12000000),
      );
    }

    // 3) THE RING-MAIN ITSELF, sunk into the floor: two heavy pipe runs with
    // bolted flanges. This planet's one big idea is that pressure travels
    // between the rooms — so the pipe that carries it is under your feet in
    // every one of them.
    for (final run in [
      Rect.fromLTWH(b.left, b.top + b.height * 0.13, b.width, 26),
      Rect.fromLTWH(b.left, b.top + b.height * 0.885, b.width, 22),
    ]) {
      // The trench it lies in.
      canvas.drawRect(run.inflate(5), Paint()..color = const Color(0x66120D09));
      canvas.drawRect(run, Paint()..color = const Color(0xFF3B3B40));
      // Barrel highlight along the top of the pipe.
      canvas.drawRect(
        Rect.fromLTWH(run.left, run.top + 3, run.width, 4),
        Paint()..color = const Color(0x3AD8E4EA),
      );
      canvas.drawRect(
        Rect.fromLTWH(run.left, run.bottom - 5, run.width, 4),
        Paint()..color = const Color(0x33000000),
      );
      // Flanged joints every 180px, each with its ring of bolts.
      for (var x = b.left + 90; x < b.right; x += 180) {
        final fl = Rect.fromLTWH(x - 7, run.top - 4, 14, run.height + 8);
        canvas.drawRect(fl, Paint()..color = const Color(0xFF4C4C52));
        canvas.drawRect(
          fl,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x55151013),
        );
        for (final by in [fl.top + 4.0, fl.bottom - 4.0]) {
          canvas.drawCircle(
            Offset(x, by),
            1.8,
            Paint()..color = const Color(0xFF8A8A90),
          );
        }
      }
    }

    // 4) A condensate grate down the low side — where the cooled breath goes.
    final grate = Rect.fromLTWH(b.left + 26, b.bottom - 40, b.width - 52, 12);
    canvas.drawRect(grate, Paint()..color = const Color(0xFF15100C));
    final bar = Paint()
      ..color = const Color(0xFF44464B)
      ..strokeWidth = 3;
    for (var x = grate.left + 5; x < grate.right; x += 13) {
      canvas.drawLine(
        Offset(x, grate.top + 1),
        Offset(x, grate.bottom - 1),
        bar,
      );
    }
  }

  /// Decorative foundry heat for the non-puzzle rooms (hub, gate, gallery,
  /// vault, heart): lava seeps in grated channels INSET from the walkable floor
  /// — clearly background, never on the path — plus a few rising steam wisps.
  /// Kept cheap: a handful of rects + baked-glow blits, no new render pass.
  void _renderForgeAmbient(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final t = _moltenPulse;
    const inset = 16.0;
    final channels = <Rect>[
      Rect.fromLTWH(b.left + inset, b.top + inset, b.width - 2 * inset, 6),
      Rect.fromLTWH(
        b.left + inset,
        b.bottom - inset - 6,
        b.width - 2 * inset,
        6,
      ),
      Rect.fromLTWH(b.left + inset, b.top + inset, 6, b.height - 2 * inset),
      Rect.fromLTWH(
        b.right - inset - 6,
        b.top + inset,
        6,
        b.height - 2 * inset,
      ),
    ];
    for (var i = 0; i < channels.length; i++) {
      final ch = channels[i];
      final horizontal = ch.width > ch.height;
      final pulse = 0.45 + 0.35 * sin(t * 1.6 + i * 1.3);
      // The molten seam itself.
      canvas.drawRRect(
        RRect.fromRectAndRadius(ch, const Radius.circular(3)),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF5A1E08),
            const Color(0xFFB5400F),
            pulse,
          )!.withValues(alpha: 0.55),
      );
      // Grate bars over it, so it reads as lava behind a floor grate.
      final n = ((horizontal ? ch.width : ch.height) / 26).floor().clamp(1, 60);
      final bars = Paint()
        ..color = const Color(0xCC141A20)
        ..strokeWidth = 3;
      for (var k = 1; k < n; k++) {
        if (horizontal) {
          final x = ch.left + k * 26.0;
          canvas.drawLine(
            Offset(x, ch.top - 1),
            Offset(x, ch.bottom + 1),
            bars,
          );
        } else {
          final y = ch.top + k * 26.0;
          canvas.drawLine(
            Offset(ch.left - 1, y),
            Offset(ch.right + 1, y),
            bars,
          );
        }
      }
      if (_fx.ready) {
        final steps = horizontal ? 3 : 2;
        for (var s = 0; s < steps; s++) {
          final p = horizontal
              ? Offset(ch.left + ch.width * ((s + 0.5) / steps), ch.center.dy)
              : Offset(ch.center.dx, ch.top + ch.height * ((s + 0.5) / steps));
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            26,
            const Color(0xFFFF7A33).withValues(alpha: 0.10 + 0.10 * pulse),
          );
        }
      }
    }
    // A few steam wisps rising through the room.
    if (_fx.ready) {
      for (var i = 0; i < 4; i++) {
        final wx = b.left + b.width * ((i + 0.5) / 4) + 18 * sin(t * 0.5 + i);
        final wy = b.bottom - 30 - ((t * 26 + i * 90) % (b.height - 60));
        drawGlow(
          canvas,
          _fx.glow!,
          Offset(wx, wy),
          20,
          const Color(0x2290A4AE),
        );
      }
    }
  }

  void _renderMoltenCell(Canvas canvas, Rect rect, int code, bool cleared) {
    // THE CRUCIBLE WAS A BOARD GAME. Flat orange squares for lava and flat
    // grey squares for rock, on a checkerboard — the most schematic room on
    // the planet, and the one the whole third star happens in. Same grid, same
    // rules, drawn as materials: basalt with mortar-dark joints, and lava as a
    // cooling crust with a bright core showing through its cracks.
    final n = _forgeNoise(rect.left.round(), rect.top.round());
    switch (code) {
      case _mOpen:
        // Translucent floor so the steam shader breathes through (FLOOR RULE),
        // with the foundry's own soot worked into it.
        canvas.drawRect(rect, Paint()..color = const Color(0x5520282E));
        canvas.drawRect(
          rect.deflate(2 + 3 * n),
          Paint()..color = Color(0x0EFF7A33),
        );
        canvas.drawRect(
          rect.deflate(0.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x118FA6B0),
        );
      case _mWall:
        // Dressed block — the built thing, squared off and mortared.
        final rr = RRect.fromRectAndRadius(
          rect.deflate(2),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF3A4149),
              const Color(0xFF4A525A),
              n,
            )!,
        );
        // Lit top face and a shadowed foot, so it stands rather than lies.
        canvas.drawRect(
          Rect.fromLTWH(rect.left + 4, rect.top + 3, rect.width - 8, 4),
          Paint()..color = const Color(0x55CFE0E6),
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left + 4, rect.bottom - 7, rect.width - 8, 4),
          Paint()..color = const Color(0x44000000),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = const Color(0xFF20262B),
        );
      case _mRock:
        // Raw basalt — irregular, dark, split. Never a rounded tile.
        canvas.drawRect(rect, Paint()..color = const Color(0xFF191F24));
        final slab = Rect.fromLTWH(
          rect.left + 1 + n,
          rect.top + 1 + (1 - n),
          rect.width - 2 - 2 * n,
          rect.height - 2,
        );
        canvas.drawRect(
          slab,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF23292F),
              const Color(0xFF2E353B),
              n,
            )!,
        );
        // A split across the face, angled by the cell's own noise.
        canvas.drawLine(
          Offset(slab.left + slab.width * (0.2 + 0.3 * n), slab.top),
          Offset(slab.left + slab.width * (0.5 + 0.4 * n), slab.bottom),
          Paint()
            ..color = const Color(0x55000000)
            ..strokeWidth = 1.4,
        );
      case _mLava:
        if (cleared) {
          canvas.drawRect(rect, Paint()..color = const Color(0x5520282E));
          return;
        }
        // A crust that has skinned over, with the bright body showing through
        // where it has cracked — not a solid orange square.
        final pulse = 0.55 + 0.45 * sin(_moltenPulse * 2.4 + rect.left * 0.03);
        canvas.drawRect(rect, Paint()..color = const Color(0xFF2A0C04));
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..color = Color.lerp(
              const Color(0xFF7A2A0E),
              const Color(0xFFB5400F),
              pulse * 0.5,
            )!,
        );
        // The cracks: a rough net of hot seams, fixed per cell so the crust
        // looks like crust rather than crawling.
        final hot = Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            const Color(0xFFFF6A2A),
            const Color(0xFFFFD98A),
            pulse,
          )!;
        // Short seams meeting at odd angles, each anchored to its own part
        // of the cell. Three lines drawn corner-to-corner through the middle
        // read as an asterisk stamped on a tile, which is the opposite of
        // crust.
        for (var k = 0; k < 4; k++) {
          final m = _forgeNoise(
            rect.left.round() + k * 7,
            rect.top.round() + k,
          );
          final m2 = _forgeNoise(rect.top.round() + k * 13, rect.left.round());
          final a0 = Offset(
            rect.left + rect.width * (0.12 + 0.76 * m),
            rect.top + rect.height * (0.12 + 0.76 * m2),
          );
          final ang = (m + m2) * pi;
          final len = rect.width * (0.18 + 0.22 * m2);
          // Clamped inside the cell: an unclamped seam runs out across the
          // floor and reads as a crack in the room rather than in the lava.
          final raw = a0 + Offset(cos(ang), sin(ang)) * len;
          final inner = rect.deflate(3);
          final a1 = Offset(
            raw.dx.clamp(inner.left, inner.right),
            raw.dy.clamp(inner.top, inner.bottom),
          );
          hot.strokeWidth = 1.6 + 1.2 * m;
          canvas.drawLine(a0, a1, hot);
        }
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            rect.center,
            rect.width * 0.7,
            const Color(0xFFFF7A33).withValues(alpha: 0.30 + 0.22 * pulse),
          );
        }
    }
  }

  /// Ring-main fixtures: clamped junction plates over sealed doors, the
  /// stoke firebox, and the riveted burst-disc. Drawn in every steam room.
  void _renderPressureFixtures(Canvas canvas, DungeonRoom room) {
    // Clamp plates on unpaid junction doors.
    for (final door in room.doors) {
      if (!_sealBlocked(room, door)) continue;
      final r = door.rect.inflate(6);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFF2B333B));
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF8FA6B0),
      );
      // Cross-bolted bars.
      final bars = Paint()
        ..color = const Color(0xFF5A6A74)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        r.topLeft + const Offset(6, 6),
        r.bottomRight - const Offset(6, 6),
        bars,
      );
      canvas.drawLine(
        r.topRight + const Offset(-6, 6),
        r.bottomLeft + const Offset(6, -6),
        bars,
      );
      // The release wheel beside the door, pulsing while affordable.
      final seal = _sealFor(room, door);
      final wheel =
          door.rect.center +
          (door.rect.width >= door.rect.height
              ? Offset(door.rect.width / 2 + 26, 0)
              : Offset(0, door.rect.height / 2 + 26));
      final afford = seal != null && boilerPressure >= seal.cost;
      final pulse = 0.6 + 0.4 * sin(_moltenPulse * 2.4);
      canvas.drawCircle(
        wheel,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = afford ? const Color(0xFF8FE0EC) : const Color(0xFF5A6A74),
      );
      for (var k = 0; k < 4; k++) {
        final ang = k * pi / 2 + _moltenPulse * 0.5;
        canvas.drawLine(
          wheel,
          wheel + Offset(cos(ang), sin(ang)) * 11,
          Paint()
            ..strokeWidth = 2
            ..color = afford
                ? const Color(0x998FE0EC)
                : const Color(0x775A6A74),
        );
      }
      if (_fx.ready && afford) {
        drawGlow(
          canvas,
          _fx.glow!,
          wheel,
          20,
          const Color(0xFF8FE0EC).withValues(alpha: 0.12 + 0.14 * pulse),
        );
      }
      // THE LINKAGE (2026-08-14, playtest: "it should be clear that turning
      // the wheel opens the door"). A wheel sitting NEXT to a clamp is just
      // scenery; a wheel visibly BOLTED TO one is a control. The rod runs
      // from the hub into the clamp plate, and it lights with the wheel.
      final linkPaint = Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = afford ? const Color(0xCC8FE0EC) : const Color(0x995A6A74);
      final toPlate = r.center - wheel;
      final len = toPlate.distance;
      if (len > 1) {
        final dir = toPlate / len;
        canvas.drawLine(
          wheel + dir * 11,
          wheel + dir * (len * 0.52),
          linkPaint,
        );
        // A collar where the rod enters the plate — the joint reads as driven.
        canvas.drawCircle(
          wheel + dir * (len * 0.52),
          4,
          Paint()..color = linkPaint.color,
        );
      }
      // THE PRICE, on the object (§5.6: state leaves the capsule). The door
      // refusal names the cost only once you lean on it; the wheel now says
      // it from across the room, so the junction can be PLANNED against the
      // gauge instead of discovered by walking into it.
      if (seal != null) {
        _drawTinyLabel(canvas, wheel + const Offset(0, 16), '${seal.cost}');
      }
    }

    // The stoke firebox: a grated hearth breathing ember light.
    final port = room.stokePort;
    if (port != null) {
      final box = Rect.fromCenter(center: port, width: 64, height: 46);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(6)),
        Paint()..color = const Color(0xFF2B2420),
      );
      final pulse = 0.5 + 0.5 * sin(_moltenPulse * 1.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.deflate(7), const Radius.circular(4)),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF5A1E08),
            const Color(0xFFB5400F),
            pulse,
          )!.withValues(alpha: 0.8),
      );
      final bars = Paint()
        ..color = const Color(0xCC141A20)
        ..strokeWidth = 3;
      for (var k = 1; k < 4; k++) {
        final x = box.left + box.width * k / 4;
        canvas.drawLine(
          Offset(x, box.top + 4),
          Offset(x, box.bottom - 4),
          bars,
        );
      }
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          port,
          30,
          const Color(0xFFFF7A33).withValues(alpha: 0.10 + 0.14 * pulse),
        );
      }
    }

    // The burst-disc: a riveted circular wall plate stamped with its
    // threshold; blown = torn petals around a dark opening.
    final disc = room.burstDisc;
    if (disc != null) {
      if (burstDiscBlown) {
        canvas.drawCircle(
          disc.position,
          26,
          Paint()..color = const Color(0xFF0A0D10),
        );
        final petals = Paint()
          ..color = const Color(0xFF5A6A74)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        for (var k = 0; k < 6; k++) {
          final ang = k * pi / 3 + 0.3;
          canvas.drawLine(
            disc.position + Offset(cos(ang), sin(ang)) * 14,
            disc.position + Offset(cos(ang + 0.5), sin(ang + 0.5)) * 30,
            petals,
          );
        }
      } else {
        canvas.drawCircle(
          disc.position,
          24,
          Paint()..color = const Color(0xFF39434B),
        );
        canvas.drawCircle(
          disc.position,
          24,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFF8FA6B0),
        );
        // Rivets.
        for (var k = 0; k < 8; k++) {
          final ang = k * pi / 4;
          canvas.drawCircle(
            disc.position + Offset(cos(ang), sin(ang)) * 18,
            2.2,
            Paint()..color = const Color(0xFF5A6A74),
          );
        }
        final tp = TextPainter(
          text: TextSpan(
            text: '${disc.threshold}',
            style: const TextStyle(
              color: Color(0xFFE4C16A),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, disc.position - Offset(tp.width / 2, tp.height / 2));
        if (_fx.ready && boilerPressure >= disc.threshold) {
          final pulse = 0.6 + 0.4 * sin(_moltenPulse * 3.0);
          drawGlow(
            canvas,
            _fx.glow!,
            disc.position,
            34,
            const Color(0xFFE4C16A).withValues(alpha: 0.10 + 0.16 * pulse),
          );
        }
      }
    }
  }

  void _renderSteam(Canvas canvas, DungeonRoom room) {
    _renderPressureFixtures(canvas, room);
    _drawGeyserField(canvas, room);
    final g = room.molten;
    if (g == null) {
      // The entry vent wheel.
      final vent = room.steamVent;
      if (vent != null) {
        final lit = entryDoorRevealed;
        canvas.drawCircle(
          vent,
          15,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = lit ? const Color(0xFF6FBE8F) : const Color(0xFF8FE0EC),
        );
        for (var k = 0; k < 4; k++) {
          final ang = k * pi / 2 + _moltenPulse * 0.6;
          canvas.drawLine(
            vent,
            vent + Offset(cos(ang), sin(ang)) * 15,
            Paint()
              ..color = const Color(0x998FE0EC)
              ..strokeWidth = 2,
          );
        }
        if (_fx.ready && !lit) {
          drawGlow(canvas, _fx.glow!, vent, 22, const Color(0x338FE0EC));
        }
      }
      return;
    }
    final grid = _moltenFor(room);
    if (grid.isEmpty) return;

    // WET walls — meltable rock with molten pressed against it glows with
    // pulsing ember cracks: the tell that breaching HERE releases the flood.
    if (!_moltenCleared(room, g)) {
      final (cw, ch) = _cellSize(room, g);
      for (var r = 0; r < g.rowCount; r++) {
        for (var c = 0; c < g.cols; c++) {
          if (grid[r][c] != _mWall || !_wallIsWet(grid, g, c, r)) continue;
          final rect = Rect.fromLTWH(
            room.bounds.left + c * cw,
            room.bounds.top + r * ch,
            cw,
            ch,
          );
          final pulse = 0.5 + 0.5 * sin(_moltenPulse * 2.2 + c * 1.7 + r);
          final crack = Paint()
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(
              const Color(0xFFB5400F),
              const Color(0xFFFFC14A),
              pulse * 0.7,
            )!.withValues(alpha: 0.55 + 0.35 * pulse);
          final cx = rect.center.dx, cy = rect.center.dy;
          canvas.drawLine(
            Offset(cx - cw * 0.22, rect.top + 8),
            Offset(cx + cw * 0.08, cy),
            crack,
          );
          canvas.drawLine(
            Offset(cx + cw * 0.08, cy),
            Offset(cx - cw * 0.12, rect.bottom - 8),
            crack,
          );
          canvas.drawLine(
            Offset(cx + cw * 0.20, cy - ch * 0.18),
            Offset(cx + cw * 0.26, cy + ch * 0.22),
            crack,
          );
          if (_fx.ready) {
            drawGlow(
              canvas,
              _fx.glow!,
              rect.center,
              cw * 0.55,
              const Color(0xFFFF7A33).withValues(alpha: 0.10 + 0.14 * pulse),
            );
          }
        }
      }
    }

    // The goal pedestal.
    final ped = _pedestalCell(g);
    if (ped != null) {
      final centre = _cellCenter(room, g, ped.$1, ped.$2);
      final won = _moltenCleared(room, g);
      canvas.drawCircle(
        centre,
        17,
        Paint()
          ..color = won ? const Color(0xFF3A4C44) : const Color(0xFF33414A),
      );
      canvas.drawCircle(
        centre,
        17,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE4C16A),
      );
      if (_fx.ready && !won) {
        final pulse = 0.7 + 0.3 * sin(_moltenPulse * 2.0);
        drawGlow(
          canvas,
          _fx.glow!,
          centre,
          30 * pulse,
          const Color(0xFFE4C16A),
        );
      }
    }

    // Mask insight: a creep FORECAST — with an insight creature active, the
    // cells the flood will take next beat glow warning-orange (Intelligence
    // tier 2 also ghosts the beat after). Reading the flood is the Mask's gift.
    final seer = active;
    if (seer != null &&
        seer.ability == DungeonAbility.insight &&
        wokeRooms.contains(room.id) &&
        !_moltenCleared(room, g)) {
      final tier = revealHintTier(seer.member.statIntelligence);
      final (cw, ch) = _cellSize(room, g);
      Rect cellRect(int c, int r) => Rect.fromLTWH(
        room.bounds.left + c * cw,
        room.bounds.top + r * ch,
        cw,
        ch,
      );
      final nextBeat = <(int, int)>{};
      for (var r = 0; r < g.rowCount; r++) {
        for (var c = 0; c < g.cols; c++) {
          if (grid[r][c] != _mLava) continue;
          for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final nc = c + dc, nr = r + dr;
            if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rowCount) continue;
            if (grid[nr][nc] == _mOpen) nextBeat.add((nc, nr));
          }
        }
      }
      final urgency = (1.0 - moltenBeat / _kMoltenBeat).clamp(0.0, 1.0);
      final warn = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color(0xFFFF7A33).withValues(alpha: 0.25 + 0.45 * urgency);
      for (final (c, r) in nextBeat) {
        canvas.drawRect(cellRect(c, r).deflate(4), warn);
      }
      if (tier >= 2) {
        final after = <(int, int)>{};
        for (final (c, r) in nextBeat) {
          for (final (dc, dr) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            final nc = c + dc, nr = r + dr;
            if (nc < 0 || nr < 0 || nc >= g.cols || nr >= g.rowCount) continue;
            if (grid[nr][nc] == _mOpen && !nextBeat.contains((nc, nr))) {
              after.add((nc, nr));
            }
          }
        }
        final ghost = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x33FF7A33);
        for (final (c, r) in after) {
          canvas.drawRect(cellRect(c, r).deflate(7), ghost);
        }
      }
    }

    // Highlight the cell the active creature is facing (where a verb would act).
    final act = active;
    if (act != null && !_moltenCleared(room, g)) {
      final t = _targetCell(act, room, g);
      if (t != null) {
        final (cw, ch) = _cellSize(room, g);
        final rect = Rect.fromLTWH(
          room.bounds.left + t.$1 * cw,
          room.bounds.top + t.$2 * ch,
          cw,
          ch,
        );
        final col = switch (act.member.element) {
          'Fire' => const Color(0xFFFF8A50),
          'Steam' => const Color(0xFF8FE0EC),
          'Earth' => const Color(0xFFD8B878),
          _ => const Color(0xFF8FA6B0),
        };
        canvas.drawRect(
          rect.deflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = col.withValues(alpha: 0.7),
        );
      }
    }
  }

  /// The boiler-pressure gauge (always on for Steam) plus, in live molten
  /// rooms, a compact legend of the three verbs + the creep-beat pulse.
  void _drawSteamPhaseHud(Canvas canvas, Size vp) {
    // ── The main's pressure gauge — the run's one budget, always visible ──
    final gx = vp.width - 116.0;
    final gy = vp.height * 0.5 - 64;
    final gaugeTp = TextPainter(
      text: TextSpan(
        text: 'MAIN $boilerPressure',
        style: const TextStyle(
          color: Color(0xFFE4C16A),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    gaugeTp.paint(canvas, Offset(gx, gy - 14));
    final gaugeBar = Rect.fromLTWH(gx - 2, gy + 2, 100, 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(gaugeBar, const Radius.circular(3)),
      Paint()..color = const Color(0x6606141C),
    );
    final frac0 = (boilerPressure / kSteamPressureMax)
        .clamp(0.0, 1.0)
        .toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          gaugeBar.left,
          gaugeBar.top,
          gaugeBar.width * frac0,
          gaugeBar.height,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFE4C16A).withValues(alpha: 0.85),
    );
    // A tick at the burst-disc threshold, so the goal is always legible.
    const burstTick = 60 / kSteamPressureMax;
    canvas.drawLine(
      Offset(gaugeBar.left + gaugeBar.width * burstTick, gaugeBar.top - 2),
      Offset(gaugeBar.left + gaugeBar.width * burstTick, gaugeBar.bottom + 2),
      Paint()
        ..color = const Color(0xFF8FE0EC)
        ..strokeWidth = 2,
    );

    final room = layout.rooms[currentRoomId];
    if (room?.molten == null || _moltenCleared(room!, room.molten!)) return;
    final entries = <(Color, String)>[
      (const Color(0xFFFF8A50), 'FIRE · melt'),
      (const Color(0xFF8FE0EC), 'STEAM · cool'),
      (const Color(0xFFD8B878), 'EARTH · dam'),
    ];
    final x = vp.width - 116.0;
    var y = vp.height * 0.5 - 30;
    for (final (col, label) in entries) {
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = col);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFFCFE0E6),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 12, y - 7));
      // Breath pips beside the STEAM row — the cooling charges left.
      if (label.startsWith('STEAM')) {
        for (var k = 0; k < kSteamBreathMax; k++) {
          canvas.drawCircle(
            Offset(x + 16 + tp.width + k * 9.0, y),
            3,
            Paint()
              ..color = k < steamBreath
                  ? const Color(0xFF8FE0EC)
                  : const Color(0x553A4750),
          );
        }
      }
      y += 20;
    }
    // Creep-beat bar — fills as the next flood approaches.
    final frac = (1.0 - (moltenBeat / _kMoltenBeat)).clamp(0.0, 1.0);
    final bar = Rect.fromLTWH(x - 2, y + 2, 100, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(3)),
      Paint()..color = const Color(0x6606141C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bar.left, bar.top, bar.width * frac, bar.height),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFFF7A33).withValues(alpha: 0.8),
    );
  }
}
