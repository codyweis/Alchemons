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

/// Heraclitus, in the stilled, cooled works.
const String kSteamHiddenHarmonyMaxim =
    '"The hidden harmony is better than the obvious."';

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

extension MoltenLabyrinth on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetPressureState() {
    if (!_isVapor) return;
    moltenCells.clear();
    moltenBeat = _kMoltenBeat;
    moltenRiteDone = false;
    wokeRooms.clear();
    steamBreath = kSteamBreathMax;
    moltenScalds = 0;
    _moltenPulse = 0;
    boilerPressure = kSteamStartPressure;
    unclampedSeals.clear();
    burstDiscBlown = false;
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

  String _sealDoorHint(DungeonRoom room, DungeonDoor door) {
    final seal = _sealFor(room, door)!;
    if (boilerPressure >= seal.cost) {
      return 'A clamped junction — throw the release beside it to spend '
          '${seal.cost} pressure and open the ring';
    }
    return 'The clamp wants ${seal.cost} pressure — the main holds only '
        '$boilerPressure. Cool molten for condensate, or stoke a firebox';
  }

  /// Whether the current room is a molten puzzle that can be restarted.
  bool get canRestartRoom =>
      _isVapor && (layout.rooms[currentRoomId]?.molten) != null;

  /// Wipe the current molten room back to its authored state and return the
  /// party to the chamber entrance — the puzzle's clean-slate button. Earned
  /// stars are untouched (a cleared room has nothing to reset).
  void restartRoom() {
    if (!canRestartRoom) return;
    moltenCells.remove(currentRoomId);
    wokeRooms.remove(currentRoomId); // the flood goes back to sleep
    steamBreath = kSteamBreathMax;
    moltenBeat = _kMoltenBeat;
    final spawn = _roomEntrySpawn(currentRoomId);
    for (final c in creatures) {
      c
        ..position = spawn
        ..lastSafe = spawn;
    }
    _fallRecovering = false;
    _moltenFor(currentRoom); // rebuild immediately so render/collision are fresh
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

  /// The mutable cell grid for [room], built lazily from its authored rows.
  List<List<int>> _moltenFor(DungeonRoom room) {
    final cached = moltenCells[room.id];
    if (cached != null) return cached;
    final g = room.molten;
    final grid = <List<int>>[];
    if (g != null) {
      for (final line in g.rows) {
        grid.add([
          for (final ch in line.split('')) _codeOf(ch),
        ]);
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
        room.bounds.left + (c + 0.5) * cw, room.bounds.top + (r + 0.5) * ch);
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
      if (wokeRooms.contains(room.id)) _spreadLava(grid, g);
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
            _setHint('The molten scalds and closes in — your footing crusts '
                'to bare stone');
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
          _setHint('${cr.member.displayName} scrambles from the molten, '
              'scalded');
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
        moltenRiteDone = true;
        _setHint(
            'The crucible pedestal sinks — Boilrog heaves up from the heart',
            4.0);
        _maybeEarnHiddenHarmony(room);
      }
    }
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
      DungeonCreature a, DungeonRoom room, MoltenGrid g, List<List<int>> grid) {
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
    if (guardian == null || guardianAwake || hasStar(guardian.starIndex)) return;
    if (!moltenRiteDone) return;
    guardianAwake = true;
    guardianHp = PlanetDungeonGame.maxGuardianHp;
    _setHint('Boilrog heaves up from the furnace-heart, wreathed in steam', 4.2);
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
    _discoverCloud(kSteamHiddenHarmonyEggId);
    _setHint('$kSteamHiddenHarmonyMaxim — the molten never once touched you.',
        7.5);
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
    if (vent != null && room.id == layout.entranceRoomId && !entryDoorRevealed) {
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
        _setHint('The clamp wants ${seal.cost} pressure — the main holds '
            'only $boilerPressure');
        return true;
      }
      boilerPressure -= seal.cost;
      unclampedSeals.add(_sealKey(room.id, seal.targetRoomId));
      _setHint('The main surges into the clamp — the junction hisses open '
          '(−${seal.cost} pressure)');
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
      _setHint('Fire roars in the box — the main surges '
          '(+$kSteamStokeGain pressure) — and something stirs at the noise');
      spawnWispWave(
        element: 'Steam',
        center: port,
        count: 2,
        unstable: true,
        announce: false,
      );
      _spawnAlchemyBurst(port,
          producedElement: 'Fire', particleCount: 18, intensity: 1.0);
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
        _setHint('The burst-disc wants a surge of ${disc.threshold} at once — '
            'the main holds only $boilerPressure. The valve refuses');
        return true;
      }
      final dumped = boilerPressure;
      boilerPressure = 0;
      burstDiscBlown = true;
      _setHint('You vent the whole main — $dumped pressure in one surge — '
          'and the burst-disc BLOWS. The vault shaft stands open', 4.5);
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
          final woke = wokeRooms.add(room.id);
          _setHint(wet
              ? 'The dam gives way — the reservoir pours through your breach!'
              : woke
                  ? 'Fire breaks the rock — and the sleeping cisterns WAKE'
                  : 'Fire breaks the rock — the fire-blood runs free');
          _spawnAlchemyBurst(at,
              producedElement: 'Lava',
              reagentElements: const ['Earth', 'Fire'],
              unstable: true,
              particleCount: 22,
              intensity: 1.1);
        } else if (code == _mRock) {
          _setHint('This bedrock will not melt');
        } else {
          _setHint('Fire finds no rock wall to melt here');
        }
        return true;
      case 'Steam':
        if (code == _mLava) {
          if (steamBreath <= 0) {
            _setHint('Your cooling breath is spent — it gathers with the beat');
            return true;
          }
          steamBreath--;
          grid[r][c] = _mOpen;
          // Condensate: cooled molten returns to the main as pressure.
          final gained = min(kSteamCondensateGain,
              kSteamPressureMax - boilerPressure);
          boilerPressure += gained;
          _setHint(gained > 0
              ? 'Steam cools the molten to standing stone — condensate '
                  'returns to the main (+$gained pressure)'
              : 'Steam cools the molten to standing stone');
          _spawnAlchemyBurst(at,
              producedElement: 'Steam', particleCount: 16, intensity: 0.8);
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
          // FAMILY-QUALITY: a Horn's heavy force sets the dam clean; any other
          // Earth raises it loud and rough — the noise draws consequence wisps.
          if (a.ability == DungeonAbility.heavyForce) {
            _setHint('The horn drives the wall home — the flood is dammed');
          } else {
            _setHint('Earth heaves a rough wall up — the racket draws wisps');
            spawnWispWave(
              element: 'Steam',
              center: at,
              count: 2,
              announce: false,
            );
          }
          _spawnAlchemyBurst(at,
              producedElement: 'Earth', particleCount: 14, intensity: 0.7);
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
            'condenses back (+$kSteamCondensateGain a cell); the burst-disc '
            'yields only to a surge of 60',
            5.5);
        return;
      }
      _setHint('${a.member.element} insight finds nothing hidden here');
      return;
    }
    _setHint(switch (g.starIndex) {
      0 => 'The wall is a dam — where the rock glows, molten leans on it; '
          'breach the dark, quiet stone and cool your doorway. Yet a bold '
          'founder might TAP a wet face on purpose: a dammed flood, cooled '
          'cell by cell, bleeds condensate for the main',
      1 => 'Every cistern wakes the moment you melt the gate — raise your '
          'walls around the gate mouth FIRST, then break through',
      _ => 'Bunker a gate, break it, and quench the far cistern at its source '
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
    if (vent != null && !entryDoorRevealed && (a.position - vent).distance < 70) {
      _setAmbientHint('A clamped relief vent — a Steam creature can crack it');
      return;
    }
    for (final door in room.doors) {
      final seal = _sealFor(room, door);
      if (seal != null &&
          _sealBlocked(room, door) &&
          (a.position - door.rect.center).distance < _kPressureReach) {
        _setAmbientHint(
            'A clamped ring junction — the release drinks ${seal.cost} '
            'of the main');
        return;
      }
    }
    final port = room.stokePort;
    if (port != null && (a.position - port).distance < _kPressureReach) {
      _setAmbientHint(
          'A firebox — Fire stokes the main (+$kSteamStokeGain), but the '
          'roar wakes what sleeps');
      return;
    }
    final disc = room.burstDisc;
    if (disc != null &&
        !burstDiscBlown &&
        (a.position - disc.position).distance < _kPressureReach) {
      _setAmbientHint(
          'A riveted burst-disc, etched "${disc.threshold}" — it yields only '
          'to the whole main vented at once');
      return;
    }
    final g = room.molten;
    if (g == null || _moltenCleared(room, g)) return;
    final target = _targetCell(a, room, g);
    if (target == null) return;
    final grid = _moltenFor(room);
    switch (grid[target.$2][target.$1]) {
      case _mWall:
        _setAmbientHint(_wallIsWet(grid, g, target.$1, target.$2)
            ? 'The rock glows hot — something molten presses against its far side'
            : 'Cool, quiet rock — it sounds hollow beyond; Fire can break it');
      case _mLava:
        _setAmbientHint('Molten — Steam cools it to standing stone');
      case _mOpen:
        _setAmbientHint('Open ground — Earth can raise a wall here to dam the flood');
    }
  }

  String? _steamObjectiveHint(DungeonRoom room) {
    final g = room.molten;
    if (g == null) {
      if (room.guardian != null) {
        return 'Furnace Heart — face Boilrog: calm it, or strike in its lulls';
      }
      if (room.id == 'manifold_south') {
        return 'South Manifold — the ring main: junctions west and east are '
            'clamped, and the main holds only so much. Spend it well';
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
    return switch (g.starIndex) {
      0 => 'Ember Causeway — the wall is a dam: some stone glows with what '
          'presses behind it; breach where it is dark and quiet',
      1 => 'Cinder Forge — the pedestal hides behind a meltable gate; dam the '
          'gate mouth before you break it, for melting wakes every cistern',
      _ => 'The Crucible — bunker a gate, break through, and thread the woken '
          'flood to the pedestal to wake the guardian',
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

  void _renderSteamFloor(Canvas canvas, DungeonRoom room) {
    final g = room.molten;
    if (g == null) {
      _renderPlainFloor(canvas, room.bounds, room.id == layout.entranceRoomId);
      final grid = Paint()
        ..color = const Color(0x12C99A6A) // faint ember-warm seams
        ..strokeWidth = 1.0;
      const step = 104.0;
      final b = room.bounds;
      for (var x = b.left + step; x < b.right; x += step) {
        canvas.drawLine(Offset(x, b.top + 18), Offset(x, b.bottom - 18), grid);
      }
      for (var y = b.top + step; y < b.bottom; y += step) {
        canvas.drawLine(Offset(b.left + 18, y), Offset(b.right - 18, y), grid);
      }
      _renderForgeAmbient(canvas, room);
      return;
    }
    final grid = _moltenFor(room);
    final (cw, ch) = _cellSize(room, g);
    final cleared = _moltenCleared(room, g);
    for (var r = 0; r < g.rowCount; r++) {
      for (var c = 0; c < g.cols; c++) {
        final rect = Rect.fromLTWH(
            room.bounds.left + c * cw, room.bounds.top + r * ch, cw + 0.6, ch + 0.6);
        _renderMoltenCell(canvas, rect, grid[r][c], cleared);
      }
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
      Rect.fromLTWH(b.left + inset, b.bottom - inset - 6, b.width - 2 * inset, 6),
      Rect.fromLTWH(b.left + inset, b.top + inset, 6, b.height - 2 * inset),
      Rect.fromLTWH(b.right - inset - 6, b.top + inset, 6, b.height - 2 * inset),
    ];
    for (var i = 0; i < channels.length; i++) {
      final ch = channels[i];
      final horizontal = ch.width > ch.height;
      final pulse = 0.45 + 0.35 * sin(t * 1.6 + i * 1.3);
      // The molten seam itself.
      canvas.drawRRect(
        RRect.fromRectAndRadius(ch, const Radius.circular(3)),
        Paint()
          ..color = Color.lerp(const Color(0xFF5A1E08),
                  const Color(0xFFB5400F), pulse)!
              .withValues(alpha: 0.55),
      );
      // Grate bars over it, so it reads as lava behind a floor grate.
      final n =
          ((horizontal ? ch.width : ch.height) / 26).floor().clamp(1, 60);
      final bars = Paint()
        ..color = const Color(0xCC141A20)
        ..strokeWidth = 3;
      for (var k = 1; k < n; k++) {
        if (horizontal) {
          final x = ch.left + k * 26.0;
          canvas.drawLine(Offset(x, ch.top - 1), Offset(x, ch.bottom + 1), bars);
        } else {
          final y = ch.top + k * 26.0;
          canvas.drawLine(Offset(ch.left - 1, y), Offset(ch.right + 1, y), bars);
        }
      }
      if (_fx.ready) {
        final steps = horizontal ? 3 : 2;
        for (var s = 0; s < steps; s++) {
          final p = horizontal
              ? Offset(ch.left + ch.width * ((s + 0.5) / steps), ch.center.dy)
              : Offset(ch.center.dx, ch.top + ch.height * ((s + 0.5) / steps));
          drawGlow(canvas, _fx.glow!, p, 26,
              const Color(0xFFFF7A33).withValues(alpha: 0.10 + 0.10 * pulse));
        }
      }
    }
    // A few steam wisps rising through the room.
    if (_fx.ready) {
      for (var i = 0; i < 4; i++) {
        final wx = b.left + b.width * ((i + 0.5) / 4) + 18 * sin(t * 0.5 + i);
        final wy = b.bottom - 30 - ((t * 26 + i * 90) % (b.height - 60));
        drawGlow(canvas, _fx.glow!, Offset(wx, wy), 20, const Color(0x2290A4AE));
      }
    }
  }

  void _renderMoltenCell(Canvas canvas, Rect rect, int code, bool cleared) {
    switch (code) {
      case _mOpen:
        // Translucent floor so the steam shader breathes through (FLOOR RULE).
        canvas.drawRect(rect, Paint()..color = const Color(0x5520282E));
        canvas.drawRect(
          rect.deflate(0.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x118FA6B0),
        );
      case _mWall:
        final rr = RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(5));
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF39434B));
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF8FA6B0),
        );
        canvas.drawLine(
          Offset(rect.left + 6, rect.top + 6),
          Offset(rect.right - 6, rect.top + 6),
          Paint()
            ..color = const Color(0x44CFE0E6)
            ..strokeWidth = 1.4,
        );
      case _mRock:
        final rr = RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(3));
        canvas.drawRRect(rr, Paint()..color = const Color(0xFF20272D));
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF3A444C),
        );
      case _mLava:
        if (cleared) {
          canvas.drawRect(rect, Paint()..color = const Color(0x5520282E));
          return;
        }
        canvas.drawRect(rect, Paint()..color = const Color(0xFF3A1206));
        // A breathing ember body.
        final pulse = 0.55 + 0.45 * sin(_moltenPulse * 2.4 + rect.left * 0.03);
        canvas.drawRect(
          rect.deflate(3),
          Paint()
            ..color = Color.lerp(const Color(0xFFFF6A2A),
                const Color(0xFFFFC14A), pulse * 0.6)!,
        );
        if (_fx.ready) {
          drawGlow(canvas, _fx.glow!, rect.center, rect.width * 0.6,
              Color(0x66FF7A33).withValues(alpha: 0.30 + 0.20 * pulse));
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
      canvas.drawLine(r.topLeft + const Offset(6, 6),
          r.bottomRight - const Offset(6, 6), bars);
      canvas.drawLine(r.topRight + const Offset(-6, 6),
          r.bottomLeft + const Offset(6, -6), bars);
      // The release wheel beside the door, pulsing while affordable.
      final seal = _sealFor(room, door);
      final wheel = door.rect.center +
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
          ..color = afford
              ? const Color(0xFF8FE0EC)
              : const Color(0xFF5A6A74),
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
                  : const Color(0x775A6A74));
      }
      if (_fx.ready && afford) {
        drawGlow(canvas, _fx.glow!, wheel, 20,
            const Color(0xFF8FE0EC).withValues(alpha: 0.12 + 0.14 * pulse));
      }
    }

    // The stoke firebox: a grated hearth breathing ember light.
    final port = room.stokePort;
    if (port != null) {
      final box = Rect.fromCenter(center: port, width: 64, height: 46);
      canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(6)),
          Paint()..color = const Color(0xFF2B2420));
      final pulse = 0.5 + 0.5 * sin(_moltenPulse * 1.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.deflate(7), const Radius.circular(4)),
        Paint()
          ..color = Color.lerp(const Color(0xFF5A1E08),
                  const Color(0xFFB5400F), pulse)!
              .withValues(alpha: 0.8),
      );
      final bars = Paint()
        ..color = const Color(0xCC141A20)
        ..strokeWidth = 3;
      for (var k = 1; k < 4; k++) {
        final x = box.left + box.width * k / 4;
        canvas.drawLine(
            Offset(x, box.top + 4), Offset(x, box.bottom - 4), bars);
      }
      if (_fx.ready) {
        drawGlow(canvas, _fx.glow!, port, 30,
            const Color(0xFFFF7A33).withValues(alpha: 0.10 + 0.14 * pulse));
      }
    }

    // The burst-disc: a riveted circular wall plate stamped with its
    // threshold; blown = torn petals around a dark opening.
    final disc = room.burstDisc;
    if (disc != null) {
      if (burstDiscBlown) {
        canvas.drawCircle(
            disc.position, 26, Paint()..color = const Color(0xFF0A0D10));
        final petals = Paint()
          ..color = const Color(0xFF5A6A74)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        for (var k = 0; k < 6; k++) {
          final ang = k * pi / 3 + 0.3;
          canvas.drawLine(
              disc.position + Offset(cos(ang), sin(ang)) * 14,
              disc.position + Offset(cos(ang + 0.5), sin(ang + 0.5)) * 30,
              petals);
        }
      } else {
        canvas.drawCircle(
            disc.position, 24, Paint()..color = const Color(0xFF39434B));
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
              Paint()..color = const Color(0xFF5A6A74));
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
        tp.paint(canvas,
            disc.position - Offset(tp.width / 2, tp.height / 2));
        if (_fx.ready && boilerPressure >= disc.threshold) {
          final pulse = 0.6 + 0.4 * sin(_moltenPulse * 3.0);
          drawGlow(canvas, _fx.glow!, disc.position, 34,
              const Color(0xFFE4C16A).withValues(alpha: 0.10 + 0.16 * pulse));
        }
      }
    }
  }

  void _renderSteam(Canvas canvas, DungeonRoom room) {
    _renderPressureFixtures(canvas, room);
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
          canvas.drawLine(vent, vent + Offset(cos(ang), sin(ang)) * 15,
              Paint()..color = const Color(0x998FE0EC)..strokeWidth = 2);
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
              room.bounds.left + c * cw, room.bounds.top + r * ch, cw, ch);
          final pulse = 0.5 + 0.5 * sin(_moltenPulse * 2.2 + c * 1.7 + r);
          final crack = Paint()
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(const Color(0xFFB5400F),
                    const Color(0xFFFFC14A), pulse * 0.7)!
                .withValues(alpha: 0.55 + 0.35 * pulse);
          final cx = rect.center.dx, cy = rect.center.dy;
          canvas.drawLine(Offset(cx - cw * 0.22, rect.top + 8),
              Offset(cx + cw * 0.08, cy), crack);
          canvas.drawLine(Offset(cx + cw * 0.08, cy),
              Offset(cx - cw * 0.12, rect.bottom - 8), crack);
          canvas.drawLine(Offset(cx + cw * 0.20, cy - ch * 0.18),
              Offset(cx + cw * 0.26, cy + ch * 0.22), crack);
          if (_fx.ready) {
            drawGlow(canvas, _fx.glow!, rect.center, cw * 0.55,
                const Color(0xFFFF7A33).withValues(alpha: 0.10 + 0.14 * pulse));
          }
        }
      }
    }

    // The goal pedestal.
    final ped = _pedestalCell(g);
    if (ped != null) {
      final centre = _cellCenter(room, g, ped.$1, ped.$2);
      final won = _moltenCleared(room, g);
      canvas.drawCircle(centre, 17,
          Paint()..color = won ? const Color(0xFF3A4C44) : const Color(0xFF33414A));
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
        drawGlow(canvas, _fx.glow!, centre, 30 * pulse, const Color(0xFFE4C16A));
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
          room.bounds.left + c * cw, room.bounds.top + r * ch, cw, ch);
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
        final rect = Rect.fromLTWH(room.bounds.left + t.$1 * cw,
            room.bounds.top + t.$2 * ch, cw, ch);
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
        Paint()..color = const Color(0x6606141C));
    final frac0 =
        (boilerPressure / kSteamPressureMax).clamp(0.0, 1.0).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(
              gaugeBar.left, gaugeBar.top, gaugeBar.width * frac0, gaugeBar.height),
          const Radius.circular(3)),
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
    canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(3)),
        Paint()..color = const Color(0x6606141C));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bar.left, bar.top, bar.width * frac, bar.height),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFFFF7A33).withValues(alpha: 0.8),
    );
  }
}
