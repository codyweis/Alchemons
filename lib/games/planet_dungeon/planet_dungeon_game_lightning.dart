// lib/games/planet_dungeon/planet_dungeon_game_lightning.dart
//
// VOLTARA — the Storm Circuit. The Lightning planet's puzzle logic + rendering,
// as a part of planet_dungeon_game.dart (it shares the engine's private state
// the same way the Fire cathedral, Water temple and Earth barrow do).
//
// World rule: *the dungeon IS a living circuit.* Charge floods from energized
// SOURCE pylons across conductive links every tick; rotatable conductor MIRRORS
// route it (only the links of their current orientation conduct); SINKS light;
// powered doors open while unpowered ones close.
//  • Entry — the way in is a dead bus. A Lightning Horn charges the gate pylon
//    and, once power reaches the sink, the passage lights open (one-time, kept
//    across death like the other planets' entry rites).
//  • Star 1 (Circuit) — the pylon hall: a Lightning Horn charges the source
//    (a DECAYING window — perfect & silent for a Horn, short & loud for any
//    other Lightning), then two conductor mirrors must be turned so power
//    reaches all THREE terminals at once.
//  • Star 2 (Storm) — the cloud works: storm-cell echoes (bared by insight in
//    the mirror gallery) are herded onto sockets; the anvil socket ignites only
//    when a Fire creature heats its cell (Air+Fire→Lightning → a Thundercloud
//    source). Every energized socket feeds the grid; all three banks the star.
//  • Star 3 (Overload) — behind the breaker gate: a Lightning Horn charges the
//    maze pylon, a mirror routes the pulse so one corridor's doors open — cross
//    to the storm core before the charge dies → Raikuma (calm or defeat).
//  • Lost Maxim — the THUNDERBOLT: power EVERY maze door at once inside a single
//    charge window (far harder than the star) earns Heraclitus.

part of 'planet_dungeon_game.dart';

/// Lightning's lost maxim discovery id (screen pays 20 gold on first find).
const String kLightningThunderboltEggId = 'egg:lightning_thunderbolt';

/// Heraclitus, lit forever in the overloaded grid.
const String kLightningThunderboltMaxim =
    '"The thunderbolt steers all things."';

/// The three storm-cell echoes (authored in the mirror gallery) the cloud
/// works can herd. Their staging order maps to the staging slots.
const List<String> _kCircuitCellIds = ['cell_spark', 'cell_veil', 'cell_anvil'];

/// Charge windows: a Lightning HORN holds the pylon clean and long; any other
/// Lightning family can only scrape a brief, loud charge (FAMILY-QUALITY RULE).
const double _kChargePerfect = 8.0;
const double _kChargeValid = 4.0;

extension StormCircuit on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetCircuitState() {
    if (!_isCircuit) return;
    circuitCharge.clear();
    _circuitChargeMax.clear();
    mirrorOrient.clear();
    _poweredNodes.clear();
    energizedSockets.clear();
    _anvilCellWaiting.clear();
    _beamLatched = false;
    // The pylon beam stays on once its star is banked (knowledge persists).
    pylonBeamOn = hasStar(0);
    _circuitActDelay = 0;
    _circuitActPending = null;
    // The Thunderbolt's permanent glow survives death (it's a found secret).
    _thunderboltGlow = discoveredClouds.contains(kLightningThunderboltEggId)
        ? 1.0
        : 0.0;
  }

  // ── Beam-reflection maze (Star 3) ────────────────────────

  /// True while a creature of [element] is stationed on the pad at [pos]
  /// (active OR — the swap-control trick — held there while you control another).
  bool _creatureOn(String element, Offset pos, [double r = 42]) {
    for (final c in creatures) {
      if (!c.alive) continue;
      if (c.member.element == element && (c.position - pos).distance <= r) {
        return true;
      }
    }
    return false;
  }

  /// The index of the path segment on which the beam crosses the converter
  /// (within [r]) plus the projected crossing point; null = it never does.
  ({int seg, Offset at})? _beamConvertSplit(
    List<Offset> path,
    Offset converter, [
    double r = 22,
  ]) {
    for (var i = 0; i + 1 < path.length; i++) {
      final a = path[i], b = path[i + 1];
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (len2 < 1e-6) continue;
      var t = ((converter - a).dx * ab.dx + (converter - a).dy * ab.dy) / len2;
      t = t.clamp(0.0, 1.0);
      final proj = a + ab * t;
      if ((converter - proj).distance <= r) return (seg: i, at: proj);
    }
    return null;
  }

  /// The vent a creature of Air is stationed on (or null).
  BeamEmitter? _activeVent(DungeonRoom room) {
    for (final v in room.beamEmitters) {
      if (_creatureOn('Air', v.position)) return v;
    }
    return null;
  }

  /// The converter a creature of Fire is stationed on (or null).
  Offset? _activeConverter(DungeonRoom room) {
    for (final c in room.beamConverters) {
      if (_creatureOn('Fire', c)) return c;
    }
    return null;
  }

  // ── Star 1: thread one bolt-beam through all three terminals ──

  void _updatePylonBeam(DungeonRoom room, double dt) {
    if (_thunderboltGlow > 0 && _thunderboltGlow < 1.0) {
      _thunderboltGlow = (_thunderboltGlow + dt * 0.6).clamp(0.0, 1.0);
    }
    final idx = room.circuitStarIndex;
    if (idx == null || hasStar(idx)) return; // solved → frozen lit
    if (!pylonBeamOn) return; // the pylon isn't charged yet → no live beam
    final vent = room.beamEmitters.first;
    final path = _computeBeam(room, vent);
    // The star banks when the single beam lies on EVERY terminal at once.
    if (room.beamReceivers.isNotEmpty &&
        room.beamReceivers.every((t) => _beamHits(path, t))) {
      _setHint('One bolt strings every terminal — the circuit runs true');
      earnStar(idx);
    }
  }

  bool _tryPylonBeam(DungeonCreature a, DungeonRoom room) {
    final pylon = room.beamEmitters.first.position;
    // Charge the pylon (Lightning only) — it latches the beam ON for the run.
    if ((a.position - pylon).distance <= 52) {
      if (a.member.element != 'Lightning') {
        _setHint('Only a Lightning creature wakes the dead pylon');
        return true;
      }
      if (!pylonBeamOn) {
        pylonBeamOn = true;
        final perfect = a.ability == DungeonAbility.heavyForce;
        _spawnAlchemyBurst(
          pylon,
          producedElement: 'Lightning',
          unstable: true,
          particleCount: perfect ? 24 : 16,
          intensity: perfect ? 1.2 : 0.9,
        );
        _setHint(
          perfect
              ? 'The Horn wakes the pylon — a bolt leaps from it'
              : 'The pylon sputters alight — sparks scatter loose',
        );
        if (!perfect) {
          spawnWispWave(
            element: 'Lightning',
            center: pylon,
            count: 2,
            unstable: true,
            announce: false,
          );
        }
      } else {
        _setHint('The pylon already burns — turn the conductors');
      }
      return true;
    }
    // Turn a conductor mirror (Lightning only).
    for (final m in room.beamMirrors) {
      if ((a.position - m.position).distance <= 52) {
        if (a.member.element != 'Lightning') {
          _setHint('The conductor is dead iron — only Lightning can turn it');
          return true;
        }
        mirrorOrient[m.id] = ((mirrorOrient[m.id] ?? 0) + 1) % 2;
        _spawnAlchemyBurst(
          m.position,
          producedElement: 'Lightning',
          particleCount: 10,
          intensity: 0.5,
        );
        _setHint('The conductor turns — the bolt bends the other way');
        return true;
      }
    }
    return false;
  }

  void _renderPylonBeam(Canvas canvas, DungeonRoom room) {
    final pylon = room.beamEmitters.first;
    final on = pylonBeamOn || hasStar(room.circuitStarIndex ?? -1);
    final path = _computeBeam(room, pylon);

    // The bolt — a jagged lightning line when live, a faint preview when off.
    if (path.length >= 2) {
      if (on) {
        for (var i = 0; i + 1 < path.length; i++) {
          _drawJaggedBolt(canvas, path[i], path[i + 1]);
        }
        if (_fx.ready) {
          for (final v in path) {
            drawGlow(canvas, _fx.glow!, v, 12, const Color(0xFF6BA8FF));
          }
        }
      } else {
        final p = Path()..moveTo(path.first.dx, path.first.dy);
        for (var i = 1; i < path.length; i++) {
          p.lineTo(path[i].dx, path[i].dy);
        }
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..color = const Color(0x66BFE6FF)
            ..strokeWidth = 1.8,
        );
      }
    }

    // The pylon.
    canvas.drawCircle(
      pylon.position,
      14,
      Paint()..color = const Color(0xFF241B12),
    );
    canvas.drawCircle(
      pylon.position,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = on ? const Color(0xFFBFE6FF) : const Color(0xFFE9D27A),
    );
    if (_fx.ready && on) {
      drawGlow(canvas, _fx.glow!, pylon.position, 28, const Color(0xFF6BA8FF));
    }

    // Mirrors.
    for (final m in room.beamMirrors) {
      _drawBeamMirror(canvas, m, on);
    }

    // Terminals — lit when the live beam lies on them.
    for (final t in room.beamReceivers) {
      final lit = on && _beamHits(path, t);
      if (_fx.ready && lit) {
        drawGlow(canvas, _fx.glow!, t, 28, const Color(0xFF6BA8FF));
      }
      canvas.drawCircle(
        t,
        11,
        Paint()..color = lit ? const Color(0xFFEAF6FF) : const Color(0xFF2A3646),
      );
      canvas.drawCircle(
        t,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFF8FB8E0),
      );
    }
  }

  /// A 45° conductor plate (shared by both beam puzzles).
  void _drawBeamMirror(Canvas canvas, BeamMirror m, bool live) {
    final ang = (mirrorOrient[m.id] ?? 0) == 0 ? -pi / 4 : pi / 4;
    if (_fx.ready && live) {
      drawGlow(canvas, _fx.glow!, m.position, 24, const Color(0xFF6BA8FF));
    }
    canvas.save();
    canvas.translate(m.position.dx, m.position.dy);
    canvas.rotate(ang);
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 42, height: 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(plate, Paint()..color = const Color(0xFFEAF6FF));
    canvas.drawLine(
      const Offset(-19, -2),
      const Offset(19, -2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1.3,
    );
    canvas.drawLine(
      const Offset(-19, 3),
      const Offset(19, 3),
      Paint()
        ..color = const Color(0xFF26303C)
        ..strokeWidth = 2.4,
    );
    canvas.restore();
    canvas.drawCircle(
      m.position,
      3.4,
      Paint()..color = const Color(0xFFBFE6FF),
    );
  }

  void _updateBeamMaze(DungeonRoom room, double dt) {
    if (room.beamConverters.isEmpty) {
      _updatePylonBeam(room, dt);
      return;
    }
    final vent = _activeVent(room);
    final conv = _activeConverter(room);

    if (!_beamLatched && vent != null && conv != null) {
      final path = _computeBeam(room, vent);
      final split = _beamConvertSplit(path, conv);
      final recv = room.beamReceiver;
      // The beam must pass THROUGH the stationed converter, and the LIGHTNING
      // portion (after it) must strike the tower.
      if (split != null && recv != null) {
        // A real arc at the moment of conversion — air becomes lightning here.
        _beamSparkT += dt;
        if (_beamSparkT > 0.18) {
          _beamSparkT = 0;
          _spawnAlchemyBurst(
            split.at,
            producedElement: 'Lightning',
            reagentElements: const ['Air', 'Fire'],
            unstable: true,
            particleCount: 8,
            intensity: 0.7,
          );
        }
        final lightning = <Offset>[split.at, ...path.sublist(split.seg + 1)];
        if (_beamHits(lightning, recv)) {
          _beamLatched = true;
          _setHint(
            'The bolt crowns the Storm Spire — the gate to the core throws open',
            3.6,
          );
          _spawnAlchemyBurst(
            recv,
            producedElement: 'Lightning',
            reagentElements: const ['Air', 'Fire'],
            unstable: true,
            particleCount: 34,
            intensity: 1.3,
          );
          final horn = creatures.any(
            (c) =>
                c.alive &&
                c.member.element == 'Lightning' &&
                c.ability == DungeonAbility.heavyForce,
          );
          if (horn && !discoveredClouds.contains(kLightningThunderboltEggId)) {
            _discoverCloud(kLightningThunderboltEggId);
            _thunderboltGlow = 0.001;
            _setHint(
              '$kLightningThunderboltMaxim — the storm answered by its own.',
              7.5,
            );
          }
        }
      }
    }

    // The gate barrier reads its node from the live set (latched, or once the
    // star is banked it stays open for good — solved is solved).
    _poweredNodes.clear();
    if (_beamLatched || hasStar(2)) _poweredNodes.add('beam_core');

    if (_thunderboltGlow > 0 && _thunderboltGlow < 1.0) {
      _thunderboltGlow = (_thunderboltGlow + dt * 0.6).clamp(0.0, 1.0);
    }
    _maybeWakeRaikuma(room);
  }

  bool _tryBeamMaze(DungeonCreature a, DungeonRoom room) {
    if (room.beamConverters.isEmpty) return _tryPylonBeam(a, room);
    // Only a Lightning creature can turn the heavy iron conductors.
    for (final m in room.beamMirrors) {
      if ((a.position - m.position).distance <= 52) {
        if (a.member.element != 'Lightning') {
          _setHint('The conductor is dead iron — only Lightning can turn it');
          return true;
        }
        mirrorOrient[m.id] = ((mirrorOrient[m.id] ?? 0) + 1) % 2;
        _spawnAlchemyBurst(
          m.position,
          producedElement: 'Lightning',
          particleCount: 10,
          intensity: 0.5,
        );
        _setHint('The conductor turns — the beam will bounce the other way');
        return true;
      }
    }
    return false;
  }

  /// '/' (orient 0) swaps right↔up & left↔down; '\\' (orient 1) swaps
  /// right↔down & left↔up.
  Offset _reflectBeam(Offset dir, int orient) {
    if (orient == 0) {
      if (dir.dx > 0) return const Offset(0, -1);
      if (dir.dx < 0) return const Offset(0, 1);
      if (dir.dy < 0) return const Offset(1, 0);
      return const Offset(-1, 0);
    } else {
      if (dir.dx > 0) return const Offset(0, 1);
      if (dir.dx < 0) return const Offset(0, -1);
      if (dir.dy < 0) return const Offset(-1, 0);
      return const Offset(1, 0);
    }
  }

  /// The beam polyline from [vent], reflecting off mirrors until it leaves the
  /// room or is absorbed by a wall (or after a bounce cap).
  List<Offset> _computeBeam(DungeonRoom room, BeamEmitter vent) {
    final pts = <Offset>[vent.position];
    var pos = vent.position;
    var dir = vent.dir;
    for (var bounce = 0; bounce < 16; bounce++) {
      BeamMirror? hit;
      var best = double.infinity;
      for (final m in room.beamMirrors) {
        final rel = m.position - pos;
        final along = rel.dx * dir.dx + rel.dy * dir.dy;
        if (along <= 2) continue;
        final perp = (dir.dx != 0) ? rel.dy.abs() : rel.dx.abs();
        if (perp > 16) continue;
        if (along < best) {
          best = along;
          hit = m;
        }
      }
      // Candidate end: the mirror (if any) or the room bound.
      final end = hit?.position ?? _beamRayEnd(pos, dir, room.bounds);
      final endAlong = (end - pos).dx * dir.dx + (end - pos).dy * dir.dy;
      // A wall/pillar between here and the end ABSORBS the beam.
      final wall = _beamWallHit(pos, dir, endAlong, room.walls);
      if (wall != null && wall < endAlong - 0.5) {
        pos = pos + Offset(dir.dx * wall, dir.dy * wall);
        pts.add(pos);
        break;
      }
      pos = end;
      pts.add(pos);
      if (hit == null) break;
      dir = _reflectBeam(dir, mirrorOrient[hit.id] ?? 0);
    }
    return pts;
  }

  Offset _beamRayEnd(Offset pos, Offset dir, Rect b) {
    if (dir.dx > 0) return Offset(b.right, pos.dy);
    if (dir.dx < 0) return Offset(b.left, pos.dy);
    if (dir.dy < 0) return Offset(pos.dx, b.top);
    return Offset(pos.dx, b.bottom);
  }

  /// Distance along an axis-aligned ray to the nearest wall it enters (≤
  /// [maxAlong]), or null if it reaches the end unobstructed.
  double? _beamWallHit(
    Offset pos,
    Offset dir,
    double maxAlong,
    List<Rect> walls,
  ) {
    double? best;
    for (final w in walls) {
      double? t;
      if (dir.dx > 0) {
        if (pos.dy > w.top && pos.dy < w.bottom && w.left >= pos.dx) {
          t = w.left - pos.dx;
        }
      } else if (dir.dx < 0) {
        if (pos.dy > w.top && pos.dy < w.bottom && w.right <= pos.dx) {
          t = pos.dx - w.right;
        }
      } else if (dir.dy > 0) {
        if (pos.dx > w.left && pos.dx < w.right && w.top >= pos.dy) {
          t = w.top - pos.dy;
        }
      } else {
        if (pos.dx > w.left && pos.dx < w.right && w.bottom <= pos.dy) {
          t = pos.dy - w.bottom;
        }
      }
      if (t != null && t >= 0 && t <= maxAlong && (best == null || t < best)) {
        best = t;
      }
    }
    return best;
  }

  bool _beamHits(List<Offset> path, Offset point, [double r = 18]) {
    for (var i = 0; i + 1 < path.length; i++) {
      if (_pointNearSegment(point, path[i], path[i + 1]) <= r) return true;
    }
    return false;
  }

  double _pointNearSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-6) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updateCircuit(DungeonCreature a, DungeonRoom room, double dt) {
    if (!_isCircuit) return;

    // A pending off-family action lands after its groaning delay.
    if (_circuitActDelay > 0) {
      _circuitActDelay -= dt;
      if (_circuitActDelay <= 0) {
        final pending = _circuitActPending;
        _circuitActPending = null;
        pending?.call();
      }
    }

    // The overload maze is a beam-reflection puzzle — handled separately.
    if (room.beamEmitters.isNotEmpty) {
      _updateBeamMaze(room, dt);
      return;
    }

    // RULE (docs §7 — cleared stars + Air's altar pinned to infinity): once a
    // circuit puzzle's star is BANKED its grid freezes LIT — the charge timer
    // never runs out, the conductors stay live, the room reads solved forever.
    if (room.circuitStarIndex != null && _roomCleared(room)) {
      _poweredNodes
        ..clear()
        ..addAll(room.circuitNodes.map((n) => n.id));
      return;
    }

    // The entry-rite room: once the dead bus has been charged through (the door
    // revealed), the gate's power STAYS ON for good — it never bleeds back to
    // dark when the charge would have decayed.
    if (room.id == layout.entranceRoomId &&
        entryDoorRevealed &&
        room.circuitNodes.isNotEmpty) {
      _poweredNodes
        ..clear()
        ..addAll(room.circuitNodes.map((n) => n.id));
      return;
    }

    // Charge decays (latching sources — the storm-cell sockets — are re-asserted
    // below and never run down).
    final nodes = _circuitNodeMap(room);
    final cold = <String>[];
    circuitCharge.forEach((id, secs) {
      final node = nodes[id];
      if (node != null && node.latching) return;
      final left = secs - dt;
      if (left <= 0) {
        cold.add(id);
      } else {
        circuitCharge[id] = left;
      }
    });
    for (final id in cold) {
      circuitCharge.remove(id);
      _circuitChargeMax.remove(id);
    }

    // Re-assert latching sources whose socket is energized (so power survives a
    // room exit/return and never decays).
    for (final sock in room.cellSockets) {
      if (energizedSockets.contains(sock.id)) {
        circuitCharge[sock.energizesNodeId] = double.infinity;
      }
    }

    // Recompute the live power set for THIS room.
    _poweredNodes
      ..clear()
      ..addAll(_computePowered(room));

    if (_thunderboltGlow > 0 && _thunderboltGlow < 1.0) {
      _thunderboltGlow = (_thunderboltGlow + dt * 0.6).clamp(0.0, 1.0);
    }

    // Entry rite: the dead bus lights → the passage opens.
    if (room.id == layout.entranceRoomId &&
        !entryDoorRevealed &&
        room.circuitNodes.any(
          (n) => n.kind == CircuitNodeKind.sink && _poweredNodes.contains(n.id),
        )) {
      entryDoorRevealed = true;
      _discoverCloud(PlanetDungeonGame.entryDoorDiscoveryId);
      _setHint('Power crosses the dead bus — the passage lights open');
      final door = room.doors.isNotEmpty
          ? room.doors.first.rect.center
          : a.position;
      _spawnAlchemyBurst(
        door,
        producedElement: 'Lightning',
        unstable: true,
        particleCount: 30,
        intensity: 1.2,
      );
    }

    // Discover storm-cells by close approach (insight reveals them at range).
    for (final cell in room.stormCells) {
      if (discoveredClouds.contains(cell.id)) continue;
      if ((a.position - cell.position).distance < 40) {
        _discoverCloud(cell.id);
        _setHint('A storm-cell stirs — its echo wakes at the cloud works');
        _spawnAlchemyBurst(
          cell.position,
          producedElement: 'Lightning',
          reagentElements: const ['Air'],
          particleCount: 14,
          intensity: 0.7,
        );
      }
    }

    // If a barrier slams shut on a creature (charge died mid-corridor), drift it
    // to the nearest open footing instead of trapping it. Once the Overload Star
    // is banked the breakers stay open for good, so this never fires then.
    if (!_fallRecovering && !hasStar(2)) {
      for (final bar in room.poweredBarriers) {
        if (_poweredNodes.contains(bar.nodeId)) continue;
        if (bar.rect.inflate(PlanetDungeonGame._radius - 2).contains(a.position)) {
          final toLeft = (a.position.dx - bar.rect.left).abs();
          final toRight = (bar.rect.right - a.position.dx).abs();
          final safeX = toLeft < toRight
              ? bar.rect.left - PlanetDungeonGame._radius - 2
              : bar.rect.right + PlanetDungeonGame._radius + 2;
          _beginFallRecovery(
            a,
            Offset(safeX, a.position.dy),
            hint: 'The door slams shut — the surge throws you clear',
          );
          break;
        }
      }
    }

    if (_roomCleared(room)) {
      _maybeWakeRaikuma(room);
      return;
    }

    // Star 1 / Star 2: bank when this room's win condition is met.
    final starIdx = room.circuitStarIndex;
    if (starIdx != null && !hasStar(starIdx)) {
      if (room.cellSockets.isNotEmpty) {
        // Storm Star — every socket energized.
        if (room.cellSockets.every((s) => energizedSockets.contains(s.id))) {
          _setHint('Three storm-cells sing into the grid — the works light up');
          earnStar(starIdx);
        }
      } else {
        // Circuit Star — every sink powered together.
        final sinks = room.circuitNodes.where(
          (n) => n.kind == CircuitNodeKind.sink,
        );
        if (sinks.isNotEmpty && sinks.every((n) => _poweredNodes.contains(n.id))) {
          _setHint('Power runs true to every terminal at once');
          earnStar(starIdx);
        }
      }
    }

    // Star 3 / the Thunderbolt egg: the overload maze.
    if (room.poweredBarriers.isNotEmpty) {
      _maybeEarnThunderbolt(room);
    }

    // Reaching the storm core wakes Raikuma.
    _maybeWakeRaikuma(room);
  }

  void _maybeWakeRaikuma(DungeonRoom room) {
    final g = room.guardian;
    if (g == null || guardianAwake || hasStar(g.starIndex)) return;
    guardianAwake = true;
    guardianHp = PlanetDungeonGame.maxGuardianHp;
    _setHint('You reach the storm core — Raikuma uncoils from the grid', 4.2);
    spawnWispWave(
      element: 'Lightning',
      center: g.position,
      count: 3,
      unstable: true,
      announce: false,
    );
  }

  void _maybeEarnThunderbolt(DungeonRoom room) {
    if (discoveredClouds.contains(kLightningThunderboltEggId)) return;
    final allLit = room.poweredBarriers.every(
      (b) => _poweredNodes.contains(b.nodeId),
    );
    if (!allLit) return;
    _discoverCloud(kLightningThunderboltEggId);
    _thunderboltGlow = 0.001;
    _setHint(
      'Every door of the maze blazes at once. $kLightningThunderboltMaxim '
      '— the grid will never go dark here again.',
      7.5,
    );
    _spawnAlchemyBurst(
      room.bounds.center,
      producedElement: 'Lightning',
      unstable: true,
      particleCount: 40,
      intensity: 1.4,
    );
  }

  // ── Action button ────────────────────────────────────────

  bool _tryCircuit(DungeonCreature a) {
    if (!_isCircuit) return false;
    final room = currentRoom;
    if (room.beamEmitters.isNotEmpty) return _tryBeamMaze(a, room);
    if (_roomCleared(room)) return false;

    // 1) Charge / heat a source pylon you're standing at.
    for (final node in room.circuitNodes) {
      if (node.kind != CircuitNodeKind.source) continue;
      if (node.latching) continue; // sockets, not Horn-charged
      if ((a.position - node.position).distance > 52) continue;
      return _chargePylon(a, node);
    }

    // 2) Rotate a conductor mirror you're standing at.
    for (final node in room.circuitNodes) {
      if (node.kind != CircuitNodeKind.mirror) continue;
      if ((a.position - node.position).distance > 52) continue;
      return _rotateMirror(a, node);
    }

    // 3) Heat an anvil socket that already holds a cell (Fire only).
    for (final sock in room.cellSockets) {
      if (!sock.requiresHeat) continue;
      if (!_anvilCellWaiting.contains(sock.id)) continue;
      if ((a.position - sock.position).distance > 52) continue;
      if (a.member.element == 'Fire') {
        return _heatAnvil(a, sock);
      }
      _setHint('The anvil-cell is cold — it needs a Fire creature\'s heat');
      return true;
    }

    // 4) Deposit a carried storm-cell onto an empty socket.
    if (carriedCloudId != null) {
      for (final sock in room.cellSockets) {
        if (energizedSockets.contains(sock.id)) continue;
        if (_anvilCellWaiting.contains(sock.id)) continue;
        if ((a.position - sock.position).distance > 48) continue;
        return _depositCell(a, sock);
      }
    }

    // 5) Pick up a discovered storm-cell echo (cloud works staging).
    if (carriedCloudId == null && room.cellSockets.isNotEmpty) {
      final slots = _cellStagingSlots(room);
      for (var i = 0; i < _kCircuitCellIds.length; i++) {
        final id = _kCircuitCellIds[i];
        if (!discoveredClouds.contains(id)) continue;
        if (placedClouds.contains(id)) continue;
        if ((a.position - slots[i]).distance > 48) continue;
        carriedCloudId = id;
        carriedCloudType = _cellTypeFor(id);
        _setHint('You gather the $carriedCloudType echo — bear it to a socket');
        return true;
      }
    }

    return false;
  }

  bool _chargePylon(DungeonCreature a, CircuitNode node) {
    if (a.member.element != 'Lightning') {
      _setHint('Only a Lightning creature wakes the dead iron');
      return true;
    }
    final perfect = a.ability == DungeonAbility.heavyForce;
    final window = perfect ? _kChargePerfect : _kChargeValid;
    circuitCharge[node.id] = window;
    _circuitChargeMax[node.id] = window;
    _spawnAlchemyBurst(
      node.position,
      producedElement: 'Lightning',
      unstable: true,
      particleCount: perfect ? 26 : 18,
      intensity: perfect ? 1.2 : 0.9,
    );
    if (perfect) {
      _setHint('The Horn drives a full, clean charge into the pylon');
    } else {
      _setHint('The charge won\'t hold — only the strongest grip steadies it');
      // Off-family is slow AND loud — the spark wakes wisps.
      spawnWispWave(
        element: 'Lightning',
        center: node.position,
        count: 2,
        unstable: true,
        announce: false,
      );
    }
    return true;
  }

  bool _rotateMirror(DungeonCreature a, CircuitNode node) {
    final cur = mirrorOrient[node.id] ?? 0;
    mirrorOrient[node.id] = (cur + 1) % node.orientations;
    _spawnAlchemyBurst(
      node.position,
      producedElement: 'Lightning',
      particleCount: 12,
      intensity: 0.6,
    );
    _setHint('The conductor turns — power reroutes');
    return true;
  }

  bool _depositCell(DungeonCreature a, CellSocket sock) {
    final cellId = carriedCloudId!;
    final isWing = a.ability == DungeonAbility.aerialTraversal;
    placedClouds.add(cellId);
    carriedCloudId = null;
    carriedCloudType = null;
    _spawnAlchemyBurst(
      sock.position,
      producedElement: 'Lightning',
      reagentElements: const ['Air'],
      particleCount: 16,
      intensity: 0.8,
    );
    if (sock.requiresHeat) {
      _anvilCellWaiting.add(sock.id);
      _setHint('The cell rests on the anvil — heat it with Fire to charge it');
    } else {
      energizedSockets.add(sock.id);
      _setHint('The storm-cell socket latches live');
    }
    // Off-family herding is loud — the rough push wakes wisps.
    if (!isWing) {
      spawnWispWave(
        element: 'Lightning',
        center: sock.position,
        count: 2,
        unstable: true,
        announce: false,
      );
    }
    return true;
  }

  bool _heatAnvil(DungeonCreature a, CellSocket sock) {
    _anvilCellWaiting.remove(sock.id);
    energizedSockets.add(sock.id);
    _setHint('Air and Fire braid through the cell — a Thundercloud wakes');
    _spawnAlchemyBurst(
      sock.position,
      producedElement: 'Lightning',
      reagentElements: const ['Air', 'Fire'],
      unstable: true,
      particleCount: 28,
      intensity: 1.2,
    );
    return true;
  }

  // ── Insight (Mask) ───────────────────────────────────────

  void _circuitReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    // In the gallery, insight bares the hidden storm-cells from range.
    var found = 0;
    for (final cell in room.stormCells) {
      if (discoveredClouds.contains(cell.id)) continue;
      if ((a.position - cell.position).distance < 220) {
        _discoverCloud(cell.id);
        found++;
        _spawnAlchemyBurst(
          cell.position,
          producedElement: 'Lightning',
          reagentElements: const ['Air'],
          particleCount: 12,
          intensity: 0.6,
        );
      }
    }
    if (found > 0) {
      _setHint('Insight bares $found storm-cell echo${found == 1 ? '' : 'es'}');
      return;
    }
    // Star 1 pylon beam (no converters): thread all three terminals.
    if (room.beamEmitters.isNotEmpty && room.beamConverters.isEmpty) {
      _setHint(
        tier >= 2
            ? 'One bolt must lie across all three terminals at once — turn the '
                  'conductors so the beam snakes through each'
            : 'Charge the pylon, then bend the bolt through every terminal',
      );
      return;
    }
    // At the Storm Spire, a Mask reads the storm's recipe.
    if (room.beamEmitters.isNotEmpty) {
      _setHint(
        tier >= 2
            ? 'The tower wakes only to lightning — born where the Air beam '
                  'crosses a stationed Fire; bounce that bolt onto the spire'
            : 'Station Air on the vent, Fire on the converter, then aim the bolt',
      );
      return;
    }
    if (room.circuitNodes.any((n) => n.kind == CircuitNodeKind.sink)) {
      _setHint('Charge the pylon, then turn the mirrors until every light holds');
      return;
    }
    _setHint('${a.member.element} insight finds nothing hidden here');
  }

  // ── Collision: powered barriers ──────────────────────────

  bool _circuitBlocksAt(Offset center, DungeonRoom room) {
    if (room.poweredBarriers.isEmpty) return false;
    // Once the Overload Star is banked the maze stays crossable forever (the
    // breaker never re-locks behind you — solved is solved).
    if (_roomCleared(room) || hasStar(2)) return false;
    for (final bar in room.poweredBarriers) {
      if (_poweredNodes.contains(bar.nodeId)) continue; // open while powered
      final r = bar.rect;
      if (center.dx > r.left - PlanetDungeonGame._radius &&
          center.dx < r.right + PlanetDungeonGame._radius &&
          center.dy > r.top - PlanetDungeonGame._radius &&
          center.dy < r.bottom + PlanetDungeonGame._radius) {
        return true;
      }
    }
    return false;
  }

  // ── Hints ────────────────────────────────────────────────

  void _circuitAmbientHint(DungeonCreature a, DungeonRoom room) {
    // Star 1 pylon beam (a beam room with no Fire converters).
    if (room.beamEmitters.isNotEmpty && room.beamConverters.isEmpty) {
      if (hasStar(room.circuitStarIndex ?? -1)) return;
      final pylon = room.beamEmitters.first.position;
      if (!pylonBeamOn && (a.position - pylon).distance < 56) {
        _setAmbientHint('Charge this pylon — a single bolt will leap from it');
      }
      return;
    }
    if (room.beamEmitters.isNotEmpty) {
      if (_beamLatched || hasStar(2)) return;
      for (final v in room.beamEmitters) {
        if ((a.position - v.position).distance < 50 &&
            !_creatureOn('Air', v.position)) {
          _setAmbientHint('Station Air here — this vent will spit a beam');
          return;
        }
      }
      for (final c in room.beamConverters) {
        if ((a.position - c).distance < 50 && !_creatureOn('Fire', c)) {
          _setAmbientHint(
            'Station Fire here — a beam passing through becomes lightning',
          );
          return;
        }
      }
      return;
    }
    if (_roomCleared(room)) return;
    // Standing on an uncharged source pylon.
    for (final node in room.circuitNodes) {
      if (node.kind != CircuitNodeKind.source || node.latching) continue;
      if ((a.position - node.position).distance > 60) continue;
      if ((circuitCharge[node.id] ?? 0) > 0) return;
      _setAmbientHint(
        a.member.element == 'Lightning'
            ? 'This pylon is dead — charge it'
            : 'This pylon answers only to Lightning',
      );
      return;
    }
  }

  String? _circuitObjectiveHint(DungeonRoom room) {
    if (room.circuitStarIndex != null && room.cellSockets.isNotEmpty) {
      return 'Cloud Works — herd each storm-cell onto a socket; '
          'heat the anvil-cell with Fire';
    }
    if (room.circuitStarIndex != null) {
      return 'Pylon Hall — charge the pylon, then turn the mirrors so all '
          'three terminals light at once';
    }
    if (room.beamEmitters.isNotEmpty) {
      return 'Storm Spire — station Air on the vent + Fire on the converter, '
          'then turn the mirrors to bounce the bolt onto the tower';
    }
    if (room.guardian != null) {
      return 'Storm Core — face Raikuma: calm it, or strike in its lulls';
    }
    if (room.stormCells.isNotEmpty) {
      return 'Mirror Gallery — insight bares the hidden storm-cells';
    }
    return null;
  }

  double get _circuitMoodTarget {
    switch (currentRoomId) {
      case 'overload_maze':
        return 0.26;
      case 'storm_core':
        return guardianAwake ? 0.18 : 0.24;
      case 'cloud_works':
      case 'mirror_gallery':
        return 0.5;
      case 'arc_gate':
        return 0.4;
      default:
        return 0.46;
    }
  }

  // ── Circuit graph maths ──────────────────────────────────

  Map<String, CircuitNode> _circuitNodeMap(DungeonRoom room) => {
    for (final n in room.circuitNodes) n.id: n,
  };

  /// The neighbour ids a node currently conducts to (mirrors honour rotation).
  List<String> _conductingLinks(CircuitNode n) {
    if (n.kind == CircuitNodeKind.mirror && n.orientationLinks.isNotEmpty) {
      final o = (mirrorOrient[n.id] ?? 0) % n.orientationLinks.length;
      return n.orientationLinks[o];
    }
    return n.links;
  }

  bool _passesBack(CircuitNode n, String toId) =>
      _conductingLinks(n).contains(toId);

  /// Flood charge from energized sources across mutually-conducting edges.
  Set<String> _computePowered(DungeonRoom room) {
    final nodes = _circuitNodeMap(room);
    final powered = <String>{};
    final queue = <String>[];
    for (final n in room.circuitNodes) {
      if (n.kind == CircuitNodeKind.source && (circuitCharge[n.id] ?? 0) > 0) {
        if (powered.add(n.id)) queue.add(n.id);
      }
    }
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      final node = nodes[id]!;
      for (final nb in _conductingLinks(node)) {
        if (powered.contains(nb)) continue;
        final other = nodes[nb];
        if (other == null) continue;
        if (!_passesBack(other, id)) continue; // both ends must conduct
        powered.add(nb);
        queue.add(nb);
      }
    }
    return powered;
  }

  // ── Staging / lookup helpers ─────────────────────────────

  /// Where the discovered cell-echoes hover in the cloud works (a left-side
  /// staging column, by cell index). Only relevant in a room with sockets.
  List<Offset> _cellStagingSlots(DungeonRoom room) {
    final b = room.bounds;
    final x = b.left + 110;
    return [
      Offset(x, b.top + 180),
      Offset(x, b.top + 350),
      Offset(x, b.top + 520),
    ];
  }

  String _cellTypeFor(String id) {
    switch (id) {
      case 'cell_spark':
        return 'Spark';
      case 'cell_veil':
        return 'Veil';
      case 'cell_anvil':
        return 'Anvil';
      default:
        return 'Cell';
    }
  }

  // ── Rendering ────────────────────────────────────────────

  void _renderCircuitFloor(Canvas canvas, DungeonRoom room) {
    // Translucent plate so the storm shader shows through (FLOOR TRANSLUCENCY
    // RULE), with a faint conductor lattice etched into it.
    _renderPlainFloor(canvas, room.bounds, room.id == layout.entranceRoomId);
    final b = room.bounds;
    final grid = Paint()
      ..color = const Color(0x14BFE6FF)
      ..strokeWidth = 1.0;
    const step = 96.0;
    for (var x = b.left + step; x < b.right; x += step) {
      canvas.drawLine(Offset(x, b.top + 18), Offset(x, b.bottom - 18), grid);
    }
    for (var y = b.top + step; y < b.bottom; y += step) {
      canvas.drawLine(Offset(b.left + 18, y), Offset(b.right - 18, y), grid);
    }
  }

  void _renderCircuit(Canvas canvas, DungeonRoom room) {
    if (room.beamEmitters.isNotEmpty) {
      _renderBeamMaze(canvas, room);
      return;
    }

    final nodes = _circuitNodeMap(room);

    // 1) Wires first (under the nodes). A wire glows when BOTH ends are live.
    final drawn = <String>{};
    final wirePaint = Paint()..strokeCap = StrokeCap.round;
    for (final n in room.circuitNodes) {
      for (final nb in n.links) {
        final key = (n.id.compareTo(nb) < 0) ? '${n.id}|$nb' : '$nb|${n.id}';
        if (!drawn.add(key)) continue;
        final other = nodes[nb];
        if (other == null) continue;
        final conducting =
            _conductingLinks(n).contains(nb) && _passesBack(other, n.id);
        final live =
            conducting &&
            _poweredNodes.contains(n.id) &&
            _poweredNodes.contains(nb);
        wirePaint
          ..color = live
              ? const Color(0xFF9FD4FF)
              : const Color(0x3354708F)
          ..strokeWidth = live ? 3.2 : 1.6;
        canvas.drawLine(n.position, other.position, wirePaint);
        if (live && _fx.ready) {
          // a travelling spark bead
          final t = (_time * 1.6 + n.position.dx * 0.01) % 1.0;
          final bead = Offset.lerp(n.position, other.position, t)!;
          drawGlow(canvas, _fx.glow!, bead, 9, const Color(0xFFE9F6FF));
        }
      }
    }

    // 2) Nodes.
    for (final n in room.circuitNodes) {
      final live = _poweredNodes.contains(n.id);
      _drawCircuitNode(canvas, n, live, nodes);
    }

    // 3) Powered barriers (the overload maze doors) — open while powered, and
    // permanently once the Overload Star is banked (or the Thunderbolt won).
    final cleared = _roomCleared(room) || hasStar(2) || _thunderboltGlow >= 1.0;
    for (final bar in room.poweredBarriers) {
      final open = cleared || _poweredNodes.contains(bar.nodeId);
      _drawBarrier(canvas, bar.rect, open);
    }

    // 4) Cell sockets + the discovered echoes hovering in staging.
    for (final sock in room.cellSockets) {
      _drawSocket(canvas, sock);
    }
    if (room.cellSockets.isNotEmpty) {
      final slots = _cellStagingSlots(room);
      for (var i = 0; i < _kCircuitCellIds.length; i++) {
        final id = _kCircuitCellIds[i];
        if (!discoveredClouds.contains(id) || placedClouds.contains(id)) continue;
        if (carriedCloudId == id) continue;
        _drawStormCell(canvas, slots[i], _cellTypeFor(id));
      }
    }

    // 5) Carried echo bobs above the bearer.
    if (carriedCloudId != null && carriedCloudType != null) {
      final a = active;
      if (a != null && _kCircuitCellIds.contains(carriedCloudId)) {
        _drawStormCell(
          canvas,
          a.position + const Offset(0, -34),
          carriedCloudType!,
        );
      }
    }
  }

  void _renderBeamMaze(Canvas canvas, DungeonRoom room) {
    if (room.beamConverters.isEmpty) {
      _renderPylonBeam(canvas, room);
      return;
    }
    final vent = _activeVent(room);
    final conv = _activeConverter(room);

    // The beam only exists while Air is stationed on a vent.
    final path = vent != null ? _computeBeam(room, vent) : const <Offset>[];
    // Where (if at all) the beam converts to lightning.
    final split = (path.length >= 2 && conv != null)
        ? _beamConvertSplit(path, conv)
        : null;

    if (path.length >= 2) {
      void drawRun(List<Offset> run, Color color, double w) {
        if (run.length < 2) return;
        final p = Path()..moveTo(run.first.dx, run.first.dy);
        for (var i = 1; i < run.length; i++) {
          p.lineTo(run[i].dx, run[i].dy);
        }
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color
            ..strokeWidth = w,
        );
      }

      if (split != null) {
        // Air (pale cyan, straight) up to the converter…
        drawRun(
          [...path.sublist(0, split.seg + 1), split.at],
          const Color(0xCC8FE0EC),
          3.0,
        );
        // …then a JAGGED white-blue bolt onward (air → lightning here).
        final bolt = [split.at, ...path.sublist(split.seg + 1)];
        for (var i = 0; i + 1 < bolt.length; i++) {
          _drawJaggedBolt(canvas, bolt[i], bolt[i + 1]);
        }
        if (_fx.ready) {
          // The conversion arc itself — a bright crackle at the Fire spot.
          drawGlow(canvas, _fx.glow!, split.at, 30, const Color(0xFFBFE6FF));
          for (final v in bolt) {
            drawGlow(canvas, _fx.glow!, v, 12, const Color(0xFF6BA8FF));
          }
        }
      } else {
        // No conversion yet: a thin cyan air preview.
        drawRun(path, const Color(0x998FE0EC), 2.6);
      }
    }

    // All Wind Vents + Converter spots (lit when occupied).
    for (final v in room.beamEmitters) {
      _drawStationPad(canvas, v.position, 'Air', _creatureOn('Air', v.position));
    }
    for (final c in room.beamConverters) {
      _drawStationPad(canvas, c, 'Fire', _creatureOn('Fire', c));
    }

    // Mirrors as 45° plates ( / or \ ).
    final live = vent != null;
    for (final m in room.beamMirrors) {
      final ang = (mirrorOrient[m.id] ?? 0) == 0 ? -pi / 4 : pi / 4;
      if (_fx.ready && live) {
        drawGlow(canvas, _fx.glow!, m.position, 24, const Color(0xFF6BA8FF));
      }
      canvas.save();
      canvas.translate(m.position.dx, m.position.dy);
      canvas.rotate(ang);
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 42, height: 8),
        const Radius.circular(4),
      );
      canvas.drawRRect(plate, Paint()..color = const Color(0xFFEAF6FF));
      canvas.drawLine(
        const Offset(-19, -2),
        const Offset(19, -2),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..strokeWidth = 1.3,
      );
      canvas.drawLine(
        const Offset(-19, 3),
        const Offset(19, 3),
        Paint()
          ..color = const Color(0xFF26303C)
          ..strokeWidth = 2.4,
      );
      canvas.restore();
      canvas.drawCircle(
        m.position,
        3.4,
        Paint()..color = const Color(0xFFBFE6FF),
      );
    }

    // The Storm Tower (the beam's target).
    final recv = room.beamReceiver;
    if (recv != null) {
      final lit = _beamLatched || hasStar(2);
      // Spire body.
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(recv.dx - 16, recv.dy - 6, 32, 90),
        const Radius.circular(6),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xFF1C2733));
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = lit ? const Color(0xFFBFE6FF) : const Color(0xFF54708F),
      );
      // Beacon crown at the receive point.
      if (_fx.ready && lit) {
        drawGlow(canvas, _fx.glow!, recv, 40, const Color(0xFF6BA8FF));
      }
      canvas.drawCircle(
        recv,
        13,
        Paint()
          ..color = lit ? const Color(0xFFEAF6FF) : const Color(0xFF2A3646),
      );
      canvas.drawCircle(
        recv,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFF8FB8E0),
      );
    }

    // The gate to the storm core.
    final open = _beamLatched || hasStar(2) || _thunderboltGlow >= 1.0;
    for (final bar in room.poweredBarriers) {
      _drawBarrier(canvas, bar.rect, open);
    }
  }

  /// A crackling lightning segment between [a] and [b] (a jittering zigzag so
  /// the converted beam reads as a real bolt, not a straight line).
  void _drawJaggedBolt(Canvas canvas, Offset a, Offset b) {
    final len = (b - a).distance;
    if (len < 1) return;
    final dir = (b - a) / len;
    final nrm = Offset(-dir.dy, dir.dx);
    final steps = (len / 26).clamp(2, 18).floor();
    final p = Path()..moveTo(a.dx, a.dy);
    for (var i = 1; i < steps; i++) {
      final t = i / steps;
      final base = a + (b - a) * t;
      final j = sin(_time * 22 + i * 1.7 + a.dx * 0.05) * 6.0;
      final pt = base + nrm * j;
      p.lineTo(pt.dx, pt.dy);
    }
    p.lineTo(b.dx, b.dy);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFEAF6FF)
        ..strokeWidth = 3.4,
    );
  }

  /// A station pad keyed to [element]: a ring with a ghost mote of its element,
  /// brightly lit while a matching creature stands on it.
  void _drawStationPad(Canvas canvas, Offset pos, String element, bool on) {
    final col = elementColor(element);
    if (_fx.ready && on) {
      drawGlow(canvas, _fx.glow!, pos, 40, col);
    }
    canvas.drawCircle(
      pos,
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = on ? 4 : 2.5
        ..color = on ? col : col.withValues(alpha: 0.55),
    );
    // Inner element glyph (a mote), faint when empty (a "stand here" hint).
    canvas.drawCircle(
      pos,
      8,
      Paint()..color = col.withValues(alpha: on ? 0.95 : 0.4),
    );
    if (!on && _fx.ready) {
      drawGlow(canvas, _fx.glow!, pos, 18, col.withValues(alpha: 0.5));
    }
  }

  void _drawCircuitNode(
    Canvas canvas,
    CircuitNode n,
    bool live,
    Map<String, CircuitNode> nodes,
  ) {
    final base = switch (n.kind) {
      CircuitNodeKind.source => const Color(0xFFE9D27A), // brass pylon
      CircuitNodeKind.sink => const Color(0xFF8FB8E0),
      CircuitNodeKind.mirror => const Color(0xFFBFD2E6),
      CircuitNodeKind.bus => const Color(0xFF6E89A6),
    };
    final glowColor = live ? const Color(0xFFBFE6FF) : base;
    if (_fx.ready && live) {
      drawGlow(canvas, _fx.glow!, n.position, 30, const Color(0xFF6BA8FF));
    }

    switch (n.kind) {
      case CircuitNodeKind.source:
        // A pylon with a drain-timer arc.
        final r = 16.0;
        canvas.drawCircle(
          n.position,
          r,
          Paint()..color = const Color(0xFF241B12),
        );
        canvas.drawCircle(
          n.position,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = glowColor,
        );
        final maxC = _circuitChargeMax[n.id] ?? 0;
        final cur = circuitCharge[n.id] ?? 0;
        if (maxC > 0 && cur.isFinite && cur > 0) {
          final frac = (cur / maxC).clamp(0.0, 1.0);
          canvas.drawArc(
            Rect.fromCircle(center: n.position, radius: r + 5),
            -pi / 2,
            2 * pi * frac,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFFFFE9A8),
          );
        }
        break;
      case CircuitNodeKind.mirror:
        // A conductor mirror: a polished plate that REFLECTS the beam from its
        // incoming side toward whatever it's currently routing. The plate's
        // surface bisects the directions of its conducting neighbours, so it
        // visibly "faces" the route (rotating it re-aims the reflection).
        final conducting = _conductingLinks(n);
        var sum = Offset.zero;
        for (final id in conducting) {
          final o = nodes[id];
          if (o == null) continue;
          final d = o.position - n.position;
          final len = d.distance;
          if (len > 0) sum += d / len;
        }
        final barAng = sum.distance > 0.001
            ? atan2(sum.dy, sum.dx) + pi / 2
            : (mirrorOrient[n.id] ?? 0) * pi / 3;

        // Bright reflected beam-stubs toward each LIVE conducting neighbour.
        if (live) {
          final beam = Paint()
            ..color = const Color(0xFFEAF6FF)
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.round;
          for (final id in conducting) {
            final o = nodes[id];
            if (o == null || !_poweredNodes.contains(id)) continue;
            final d = o.position - n.position;
            final len = d.distance;
            if (len <= 0) continue;
            canvas.drawLine(n.position, n.position + d / len * 24, beam);
          }
        }

        canvas.save();
        canvas.translate(n.position.dx, n.position.dy);
        canvas.rotate(barAng);
        final plate = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 40, height: 7),
          const Radius.circular(3.5),
        );
        // The reflective FRONT face (lit when live) and a dark backing so the
        // plate reads as one-sided and angled, not a floating stick.
        canvas.drawRRect(
          plate,
          Paint()
            ..color = live ? const Color(0xFFEAF6FF) : const Color(0xFF7E93AB),
        );
        canvas.drawLine(
          const Offset(-18, -1.6),
          const Offset(18, -1.6),
          Paint()
            ..color = Colors.white.withValues(alpha: live ? 0.95 : 0.45)
            ..strokeWidth = 1.3,
        );
        canvas.drawLine(
          const Offset(-18, 2.6),
          const Offset(18, 2.6),
          Paint()
            ..color = const Color(0xFF26303C)
            ..strokeWidth = 2.2,
        );
        canvas.restore();
        // Pivot hub.
        canvas.drawCircle(
          n.position,
          3.2,
          Paint()
            ..color = live ? const Color(0xFFBFE6FF) : const Color(0xFF54708F),
        );
        break;
      case CircuitNodeKind.sink:
        canvas.drawCircle(
          n.position,
          10,
          Paint()
            ..color = live
                ? const Color(0xFFE9F6FF)
                : const Color(0xFF2A3646),
        );
        canvas.drawCircle(
          n.position,
          10,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = glowColor,
        );
        break;
      case CircuitNodeKind.bus:
        canvas.drawCircle(n.position, 6, Paint()..color = glowColor);
        break;
    }
  }

  void _drawBarrier(Canvas canvas, Rect rect, bool open) {
    if (open) {
      // A faint lit threshold — the door is up.
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0x224A7FB0),
      );
      if (_fx.ready) {
        drawGlow(canvas, _fx.glow!, rect.center, rect.height, const Color(0xFF6BA8FF));
      }
      return;
    }
    // A solid crackling shutter.
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF1B2530));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF6E89A6),
    );
    // arcing energy bars
    final spark = Paint()
      ..color = const Color(0x885FB8FF)
      ..strokeWidth = 1.4;
    final n = (rect.height / 18).floor();
    for (var i = 1; i < n; i++) {
      final y = rect.top + rect.height * i / n;
      final jitter = sin(_time * 8 + i) * 3;
      canvas.drawLine(
        Offset(rect.left + 3, y),
        Offset(rect.right - 3, y + jitter),
        spark,
      );
    }
  }

  void _drawSocket(Canvas canvas, CellSocket sock) {
    final energized = energizedSockets.contains(sock.id);
    final waiting = _anvilCellWaiting.contains(sock.id);
    final c = energized
        ? const Color(0xFFBFE6FF)
        : (sock.requiresHeat ? const Color(0xFFE9A86B) : const Color(0xFF8FB8E0));
    if (_fx.ready && energized) {
      drawGlow(canvas, _fx.glow!, sock.position, 34, const Color(0xFF6BA8FF));
    }
    canvas.drawCircle(
      sock.position,
      18,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = c,
    );
    canvas.drawCircle(
      sock.position,
      6,
      Paint()..color = energized || waiting ? c : const Color(0xFF2A3646),
    );
    if (sock.requiresHeat && !energized) {
      // anvil mark
      canvas.drawRect(
        Rect.fromCenter(center: sock.position + const Offset(0, 26), width: 26, height: 8),
        Paint()..color = const Color(0xFF6E5A48),
      );
    }
  }

  void _drawStormCell(Canvas canvas, Offset center, String type) {
    final c = switch (type) {
      'Anvil' => const Color(0xFFB6C2D0),
      'Veil' => const Color(0xFF9FB6CE),
      _ => const Color(0xFFBFE6FF),
    };
    final bob = sin(_time * 2 + center.dx * 0.02) * 3;
    final p = center + Offset(0, bob);
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, p, 26, c);
      drawPuff(canvas, _fx.puff!, p, 30, c.withValues(alpha: 0.7));
    } else {
      canvas.drawCircle(p, 12, Paint()..color = c.withValues(alpha: 0.8));
    }
    // a little fork of lightning inside
    final bolt = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p + const Offset(-4, -6), p + const Offset(1, 0), bolt);
    canvas.drawLine(p + const Offset(1, 0), p + const Offset(-2, 7), bolt);
  }
}
