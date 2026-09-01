// lib/games/planet_dungeon/planet_dungeon_game_lightning.dart
//
// VOLTARA — the Storm Circuit, reworked to the ZERO-SUM DYNAMO (docs §6.3
// REWORK / §9.1 item 1). The Lightning planet's puzzle logic + rendering, as a
// part of planet_dungeon_game.dart (it shares the engine's private state the
// same way the Fire cathedral, Water temple and Earth barrow do).
//
// World rule: *the dungeon is a living circuit with ONE heart.* The hub dynamo
// feeds exactly one trunk at a time; charging a trunk breaker (any Lightning —
// element-only) routes the whole output down that wing and DARKENS every other
// wing. Dead segments stay walkable but unlit, spark wisps prowling. The
// run-long question: where does the power go, and what must I do in the dark?
//  • Entry — the way in is a dead bus. Any Lightning charges the gate pylon
//    and, once power reaches the sink, the passage lights open (one-time, kept
//    across death like the other planets' entry rites).
//  • Star 1 (Circuit) — the pylon hall: with its trunk fed, one bolt must
//    thread ALL THREE terminals via four conductor mirrors — and never cross a
//    fulminate vat (a cooked vat detonates and trips the dynamo dark). The
//    threading is PROVABLY UNIQUE (brute-forced in the layout test).
//  • Star 2 (Storm) — the cloud works: storm-cell echoes (bared in the mirror
//    gallery) are herded onto sockets; the anvil socket ignites only when a
//    Fire creature heats its cell (Air+Fire→Lightning → a Thundercloud). The
//    works only sing — and the star only banks — while their trunk burns.
//  • The vault — capacitor_vault only opens UNPOWERED: the bolt holds while
//    its trunk burns and falls open in the dark. Cut the very trunk you stand
//    in and walk the dead segment back to the fallen bolt.
//  • Star 3 (Overload) — behind the breaker gate: element stationing lights
//    the Storm Tower (one dead-aligned vent/converter pair is a geometric
//    lie). Beyond, Raikuma FEEDS on the powered core trunk — ground it at the
//    spike to force the lull; it seizes the trunk back when the window shuts.
//  • Lost Maxim — the THUNDERBOLT: light the Storm Tower with a Lightning
//    HORN standing among the conductors. Heraclitus, lit forever.

part of 'planet_dungeon_game.dart';

/// Lightning's lost maxim discovery id (screen pays 20 gold on first find).
const String kLightningThunderboltEggId = 'egg:lightning_thunderbolt';

/// Heraclitus, lit forever in the overloaded grid.
// The quotation this planet used to end on ("The thunderbolt steers all
// things.", Heraclitus) is retired: the payout is the Rite of Three now, and
// a borrowed line over the top of it was a label on a picture.

/// The three storm-cell echoes (authored in the mirror gallery) the cloud
/// works can herd. Their staging order maps to the staging slots.
const List<String> _kCircuitCellIds = ['cell_spark', 'cell_veil', 'cell_anvil'];

/// How long a charged (non-latching) pylon holds — the arc-gate entry rite.
const double _kChargeWindow = 8.0;

// ── Zero-sum feel knobs ────────────────────────────────────
/// Beam-to-vat contact radius (matches terminal tolerance; the solver uses
/// the same number, so game and proof can never drift apart).
const double _kVatRadius = 20.0;

/// Seconds a bolt may cook a fulminate vat before it detonates.
const double _kVatFuseSeconds = 1.6;

/// Seconds for a wing to fade dark / relight (eased, never snapped).
const double _kDarkFadeSeconds = 1.2;

/// Peak darkness-overlay alpha — capped ≈0.5 so the storm shader still
/// breathes through the floor (FLOOR TRANSLUCENCY rule).
const double _kDarkMaxAlpha = 0.52;

/// Seconds for the vault bolt to slide open / slam home (eased).
const double _kBoltEaseSeconds = 1.1;

/// Dark dead segments: prowl top-up interval and max concurrent spark wisps
/// (atmosphere-pressure, never a wall).
const double _kDarkWispIntervalSeconds = 7.0;
const int _kDarkWispMax = 2;

/// Raikuma's forced vulnerability window after the core trunk is grounded.
const double _kRaikumaLull = 3.4;
const double _kRaikumaLullEnraged = 2.4;

double _stepToward(double cur, double target, double delta) =>
    cur < target ? min(target, cur + delta) : max(target, cur - delta);

extension StormCircuit on PlanetDungeonGame {
  // ── Lifecycle ────────────────────────────────────────────

  void _resetCircuitState() {
    weldedBreakers.clear();
    rotorOverspeed = 0;
    if (!_isCircuit) return;
    circuitCharge.clear();
    _circuitChargeMax.clear();
    mirrorOrient.clear();
    _poweredNodes.clear();
    energizedSockets.clear();
    _anvilCellWaiting.clear();
    _vatFuse.clear();
    _beamLatched = false;
    _raikumaFed = false;
    _raikumaLullLeft = 0;
    _darkWispTimer = 0;
    _circuitPrevRoomId = null;
    _dynamoSwing = 1.0;
    // The dynamo idles into the vault trunk — the treasury hoards the storm.
    activeTrunk = layout.initialTrunkId;
    // Seed darkness/bolt state instantly (no fade-in on spawn or death).
    _trunkDark.clear();
    for (final t in layout.dynamoTrunks) {
      for (final rid in t.roomIds) {
        _trunkDark[rid] = circuitRoomLit(rid) ? 0.0 : 1.0;
      }
    }
    for (final r in layout.rooms.values) {
      if (r.vaultBolt != null) {
        _vaultBoltOpen = circuitRoomLit(r.id) ? 0.0 : 1.0;
      }
    }
    // The Thunderbolt's permanent glow survives death (it's a found secret).
    _thunderboltGlow = discoveredClouds.contains(kLightningThunderboltEggId)
        ? 1.0
        : 0.0;
  }

  // ── Zero-sum trunk state ─────────────────────────────────

  DynamoTrunk? _trunkForRoom(String roomId) {
    for (final t in layout.dynamoTrunks) {
      if (t.roomIds.contains(roomId)) return t;
    }
    return null;
  }

  /// Is [roomId] lit? Rooms off every trunk (gate, hub) are always lit; a
  /// trunk wing is lit while the dynamo feeds it — or forever once its star
  /// banks (solved is solved, the rule the circuit rooms already obey).
  bool circuitRoomLit(String roomId) {
    // THE THUNDERBOLT'S PERMANENT MARK. The dungeon's whole rule is that the
    // dynamo CHOOSES — one trunk fed, the rest dark, every wing you light
    // costing you the other three. The secret is breaking that, so what it
    // leaves behind is the rule broken for good: the welds hold, the works
    // never chooses again, and every wing stays lit for the rest of the run
    // and every run after it.
    //
    // It is also the only payoff the other four polished planets each have
    // and this one did not — Fire's burning epitaph, Air's turning compass,
    // Water's frozen moon, Earth's rooted crystal. Lightning left a boolean.
    if (thunderboltWon) return true;
    final t = _trunkForRoom(roomId);
    if (t == null) return true;
    final freeze = t.freezeLitStarIndex;
    if (freeze != null && hasStar(freeze)) return true;
    return activeTrunk == t.id;
  }

  /// Has the works been made to let go?
  bool get thunderboltWon =>
      discoveredClouds.contains(kLightningThunderboltEggId);

  /// Raikuma's feed state (read-only, for tests/diagnostics).
  bool get raikumaFed => _raikumaFed;

  /// The vault bolt's eased openness (read-only, for tests/diagnostics).
  double get vaultBoltOpenness => _vaultBoltOpen;

  // ── Beam stationing helpers (Star 3) ─────────────────────

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

  // ── The braid: wind, flame, iron (both beam halls) ──

  /// Cook every fulminate vat the CHARGED run lies on. Wind may cross a vat
  /// all day — it is the lightning half that lights the fuse, which is why
  /// the first hall hangs one in plain sight on the wind leg.
  ///
  /// Returns true when the frame must be abandoned: a fuse is burning, or one
  /// has just gone up and tripped the dynamo dark.
  bool _cookVats(DungeonRoom room, List<Offset> live, double dt) {
    var anyCrossed = false;
    for (final vat in room.fulminateVats) {
      if (_beamHits(live, vat.position, _kVatRadius)) {
        anyCrossed = true;
        final fuse = (_vatFuse[vat.id] ?? 0) + dt;
        _vatFuse[vat.id] = fuse;
        if (fuse >= _kVatFuseSeconds) {
          _vatFuse.clear();
          _spawnAlchemyBurst(
            vat.position,
            producedElement: 'Lightning',
            unstable: true,
            particleCount: 30,
            intensity: 1.3,
          );
          spawnWispWave(
            element: 'Lightning',
            center: vat.position,
            count: 2,
            unstable: true,
            announce: false,
          );
          activeTrunk = null;
          _dynamoSwing = 0;
          _setHint('The fulminate flashes — the dynamo trips dark', 3.4);
          return true;
        }
      } else {
        _coolVatFuse(vat.id, dt);
      }
    }
    return anyCrossed;
  }

  void _coolVatFuse(String vatId, double dt) {
    final fuse = _vatFuse[vatId];
    if (fuse == null) return;
    final cooled = fuse - dt * 0.8;
    if (cooled <= 0) {
      _vatFuse.remove(vatId);
    } else {
      _vatFuse[vatId] = cooled;
    }
  }

  void _coolVatFuses(double dt) {
    for (final id in _vatFuse.keys.toList()) {
      _coolVatFuse(id, dt);
    }
  }

  /// A 45° conductor plate (shared by both beam puzzles).
  void _drawBeamMirror(Canvas canvas, BeamMirror m, bool live) {
    final ang = (mirrorOrient[m.id] ?? 0) == 0 ? -pi / 4 : pi / 4;
    // A CONDUCTOR IS A HEAVY THING ON A PIVOT. It was a 42x8 white lozenge
    // lying on the floor — the single most schematic object on the planet,
    // and the one the player handles most. It stands on the same bolted post
    // every other piece of this circuit does, and the vane swings on a
    // yoke rather than floating.
    _drawCircuitPost(canvas, m.position, const Color(0xFFBFD2E6), live);
    if (_fx.ready && live) {
      drawGlow(canvas, _fx.glow!, m.position, 24, const Color(0xFF6BA8FF));
    }
    // The yoke the vane turns in.
    for (final dx in const [-23.0, 23.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: m.position + Offset(dx, -2),
            width: 7,
            height: 20,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF2A3644),
      );
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
    // The pivot bolt through the middle of the vane.
    canvas.drawCircle(
      m.position,
      4.6,
      Paint()..color = const Color(0xFF1A222C),
    );
    canvas.drawCircle(
      m.position,
      3.0,
      Paint()..color = const Color(0xFFBFE6FF),
    );
  }

  /// A fulminate vat: a squat cauldron of volatile charge-salts. Drawn as
  /// masonry (shadow + body + lit rim — §8), its amber pool whitening and
  /// flaring as a stray bolt cooks it toward detonation.
  void _drawFulminateVat(Canvas canvas, FulminateVat vat, double fuse) {
    final p = vat.position;
    final seethe = (fuse / _kVatFuseSeconds).clamp(0.0, 1.0);
    // A VAT IS A VESSEL. It was a flat 16px disc, which is why the one thing
    // in Star 1 that can kill a run read as a token on a board. Riveted iron
    // on three legs, with a lip you can see over.
    canvas.drawOval(
      Rect.fromCenter(center: p + const Offset(2, 22), width: 42, height: 12),
      Paint()..color = const Color(0xFF04070C).withValues(alpha: 0.6),
    );
    for (final dx in const [-11.0, 0.0, 11.0]) {
      canvas.drawRect(
        Rect.fromCenter(center: p + Offset(dx, 16), width: 4, height: 16),
        Paint()..color = const Color(0xFF241C14),
      );
    }
    // The belly, wider at the lip.
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - 15, p.dy - 8)
        ..quadraticBezierTo(p.dx - 19, p.dy + 14, p.dx, p.dy + 15)
        ..quadraticBezierTo(p.dx + 19, p.dy + 14, p.dx + 15, p.dy - 8)
        ..close(),
      Paint()..color = const Color(0xFF2A2118),
    );
    // Rivets round the belly.
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        p + Offset(-12 + i * 6.0, 6),
        1.3,
        Paint()..color = const Color(0xFF8A6E3F).withValues(alpha: 0.45),
      );
    }
    canvas.drawCircle(p, 16, Paint()..color = const Color(0xFF2A2118));
    canvas.drawCircle(
      p,
      16,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = Color.lerp(
          const Color(0xFF8A6E3F),
          const Color(0xFFFFB46B),
          seethe,
        )!,
    );
    // The salts: an amber pool that whitens as it cooks (jittering when hot).
    final jitter = seethe > 0 ? sin(_time * 26) * 1.6 * seethe : 0.0;
    canvas.drawCircle(
      p + Offset(jitter, 0),
      9,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFE9A86B),
          const Color(0xFFFFF3D0),
          seethe,
        )!.withValues(alpha: 0.55 + 0.45 * seethe),
    );
    if (_fx.ready && seethe > 0.02) {
      drawGlow(
        canvas,
        _fx.glow!,
        p,
        26 + 20 * seethe,
        const Color(0xFFFFB46B).withValues(alpha: 0.3 + 0.5 * seethe),
      );
    }
  }

  // ── Star 3: the Storm Spire stationing puzzle ────────────

  void _updateBeamMaze(DungeonRoom room, double dt) {
    final starIdx = room.circuitStarIndex;
    // The hall banks a star (Pylon Hall) or throws the core gate (the Spire).
    final solved = starIdx != null ? hasStar(starIdx) : _beamLatched;
    // A star hall stands on its own trunk: a dead wing can be staged in the
    // dark, but the wind never blows and nothing is ever crowned there.
    final fed = starIdx == null || circuitRoomLit(room.id);
    final vent = _activeVent(room);
    final conv = _activeConverter(room);

    if (!solved && fed && vent != null && conv != null) {
      final path = _computeBeam(room, vent);
      final split = _beamConvertSplit(path, conv);
      // The wind must pass THROUGH the stationed converter, and the LIGHTNING
      // half born there must lie on every terminal at once.
      if (split != null) {
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
        // Wind crosses fulminate freely; the charged half never may.
        if (_cookVats(room, lightning, dt)) return;
        final crowns = beamTerminalsOf(room);
        if (crowns.isNotEmpty && crowns.every((t) => _beamHits(lightning, t))) {
          for (final t in crowns) {
            _spawnAlchemyBurst(
              t,
              producedElement: 'Lightning',
              reagentElements: const ['Air', 'Fire'],
              unstable: true,
              particleCount: crowns.length > 1 ? 18 : 34,
              intensity: 1.3,
            );
          }
          if (starIdx != null) {
            _setHint('One braided bolt wakes the mast — the hall runs true');
            earnStar(starIdx);
          } else {
            _beamLatched = true;
            _setHint(
              'Every terminal crowned at once — the gate to the core throws '
              'open',
              3.6,
            );
          }

          // (The Thunderbolt used to fire HERE, off this very beam, if a
          // Lightning Horn happened to be standing in the room — a secret
          // that rode a star's coat-tails and asked nothing of its own. It is
          // its own chain at the dynamo now; see `_tryThunderbolt`.)
        }
      } else {
        _coolVatFuses(dt);
      }
    } else {
      _coolVatFuses(dt);
      if (!solved && !fed && vent != null) {
        _setBlockedHintOnce(
          'circuit:hall_dark',
          'The hall is dark — the vents wait on the dynamo',
        );
      }
    }

    // The gate barrier reads its node from the live set (latched, or once the
    // star is banked it stays open for good — solved is solved).
    if (room.poweredBarriers.isNotEmpty) {
      _poweredNodes.clear();
      if (_beamLatched || hasStar(2)) _poweredNodes.add('beam_core');
    }

    _maybeWakeRaikuma(room);
  }

  /// Every terminal the charged half of the braid has to lie on — the single
  /// mast of the first hall, or the Spire's three at once.
  List<Offset> beamTerminalsOf(DungeonRoom room) => <Offset>[
    if (room.beamReceiver != null) room.beamReceiver!,
    ...room.beamReceivers,
  ];

  bool _tryBeamMaze(DungeonCreature a, DungeonRoom room) {
    // Only a Lightning creature can turn the heavy iron conductors.
    for (final m in room.beamMirrors) {
      if ((a.position - m.position).distance <= 52) {
        if (a.member.element != 'Lightning') {
          _setBlockedHint('Only Lightning turns the conductor');
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

  // ── Brute-force solvers (public: the layout test's proof engine) ──

  /// Brute-force ONE hall's vent/converter pairing over every conductor
  /// orientation: in how many configurations does that pairing's CHARGED half
  /// crown every terminal at once without cooking a fulminate vat?
  ///
  /// The layout test sweeps every pairing of both halls with this and asserts
  /// exactly one pairing works, in exactly one configuration (§6.3 "provably
  /// unique") — and that the dead-aligned decoy returns ZERO, so eliminating
  /// it is mirror geometry rather than trial and error. It runs against the
  /// REAL beam engine, so the game and its proof cannot drift apart.
  ({int searched, int satisfying, Map<String, int>? solution}) solveBeamHall({
    required String roomId,
    required int ventIndex,
    required int converterIndex,
  }) {
    final room = layout.rooms[roomId]!;
    final vent = room.beamEmitters[ventIndex];
    final converter = room.beamConverters[converterIndex];
    final terminals = beamTerminalsOf(room);
    final mirrors = room.beamMirrors;
    final saved = Map<String, int>.from(mirrorOrient);
    var satisfying = 0;
    Map<String, int>? solution;
    final configs = 1 << mirrors.length;
    for (var mask = 0; mask < configs; mask++) {
      for (var i = 0; i < mirrors.length; i++) {
        mirrorOrient[mirrors[i].id] = (mask >> i) & 1;
      }
      final path = _computeBeam(room, vent);
      final split = _beamConvertSplit(path, converter);
      if (split == null) continue;
      final bolt = <Offset>[split.at, ...path.sublist(split.seg + 1)];
      if (!terminals.every((t) => _beamHits(bolt, t))) continue;
      // Wind may lie across fulminate; the charged half never may.
      if (room.fulminateVats.any(
        (v) => _beamHits(bolt, v.position, _kVatRadius),
      )) {
        continue;
      }
      satisfying++;
      solution = {for (final m in mirrors) m.id: mirrorOrient[m.id]!};
    }
    mirrorOrient
      ..clear()
      ..addAll(saved);
    return (searched: configs, satisfying: satisfying, solution: solution);
  }

  // ── Per-frame update ─────────────────────────────────────

  void _updateCircuit(DungeonCreature a, DungeonRoom room, double dt) {
    _updateThunderbolt(dt);
    if (!_isCircuit) return;

    // Zero-sum atmosphere first (darkness ease, bolt ease, wisp prowl) —
    // it applies to EVERY room, beam puzzles included.
    _updateTrunkAtmosphere(a, room, dt);

    // The beam rooms (pylon hall + storm spire) are handled separately.
    if (room.beamEmitters.isNotEmpty) {
      _updateBeamMaze(room, dt);
      return;
    }

    // RULE (docs §7 — cleared stars + Air's altar pinned to infinity): once a
    // circuit puzzle's star is BANKED its grid freezes LIT — the room reads
    // solved forever.
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

    // Re-assert latching sources whose socket is energized (so socket state
    // survives a room exit/return and never decays).
    for (final sock in room.cellSockets) {
      if (energizedSockets.contains(sock.id)) {
        circuitCharge[sock.energizesNodeId] = double.infinity;
      }
    }

    // Recompute the live power set for THIS room — ZERO-SUM: a wing whose
    // trunk the dynamo is not feeding computes DEAD, whatever its sources
    // hold. The socket state persists; the grid just has nothing to sing
    // through until the dynamo comes back.
    final lit = circuitRoomLit(room.id);
    _poweredNodes.clear();
    if (lit) _poweredNodes.addAll(_computePowered(room));

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

    // The vault bolt: refusal lean + never trapping a creature in its slot.
    if (room.vaultBolt != null) _updateVaultBolt(a, room);

    // If a barrier slams shut on a creature, drift it to the nearest open
    // footing instead of trapping it.
    if (!_fallRecovering && !hasStar(2)) {
      for (final bar in room.poweredBarriers) {
        if (_poweredNodes.contains(bar.nodeId)) continue;
        if (bar.rect
            .inflate(PlanetDungeonGame._radius - 2)
            .contains(a.position)) {
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

    // Star 1 / Star 2: bank when this room's win condition is met — and its
    // trunk is FED (a dark wing can be staged, but never sung).
    final starIdx = room.circuitStarIndex;
    if (starIdx != null && !hasStar(starIdx)) {
      if (room.cellSockets.isNotEmpty) {
        final staged = room.cellSockets.every(
          (s) => energizedSockets.contains(s.id),
        );
        if (staged && lit) {
          _setHint('Three storm-cells sing into the grid — the works light up');
          earnStar(starIdx);
        } else if (staged && !lit) {
          // Every cell seated in a dead wing: the refusal names what's
          // missing (§5.6 BLOCKED — attempt-edged by the state itself).
          _setBlockedHintOnce(
            'circuit:works_dark',
            'The works are dark — the sockets wait on the dynamo',
          );
        }
      } else {
        // Circuit Star fallback — every sink powered together.
        final sinks = room.circuitNodes.where(
          (n) => n.kind == CircuitNodeKind.sink,
        );
        if (lit &&
            sinks.isNotEmpty &&
            sinks.every((n) => _poweredNodes.contains(n.id))) {
          _setHint('Power runs true to every terminal at once');
          earnStar(starIdx);
        }
      }
    }

    // Reaching the storm core wakes Raikuma.
    _maybeWakeRaikuma(room);
  }

  /// Darkness/bolt easing, the dynamo swing, the thunderbolt glow, and the
  /// dark-segment spark-wisp prowl. Runs for every Lightning room each frame.
  void _updateTrunkAtmosphere(DungeonCreature a, DungeonRoom room, double dt) {
    for (final t in layout.dynamoTrunks) {
      for (final rid in t.roomIds) {
        final target = circuitRoomLit(rid) ? 0.0 : 1.0;
        _trunkDark[rid] = _stepToward(
          _trunkDark[rid] ?? target,
          target,
          dt / _kDarkFadeSeconds,
        );
      }
    }
    _dynamoSwing = min(1.0, _dynamoSwing + dt / 0.9);
    for (final r in layout.rooms.values) {
      if (r.vaultBolt == null) continue;
      final target = circuitRoomLit(r.id) ? 0.0 : 1.0;
      _vaultBoltOpen = _stepToward(
        _vaultBoltOpen,
        target,
        dt / _kBoltEaseSeconds,
      );
    }
    if (_thunderboltGlow > 0 && _thunderboltGlow < 1.0) {
      _thunderboltGlow = (_thunderboltGlow + dt * 0.6).clamp(0.0, 1.0);
    }

    // Spark wisps prowl the dead segment the party is walking — modest
    // numbers on a slow clock: atmosphere-pressure, never a wall. The
    // guardian's arena keeps its own consequence layer.
    if (_circuitPrevRoomId != room.id) {
      _circuitPrevRoomId = room.id;
      _darkWispTimer = 0.8; // a beat after stepping into the dark
    }
    final dark = (_trunkDark[room.id] ?? 0) > 0.6;
    if (!dark || room.guardian != null) return;
    _darkWispTimer -= dt;
    if (_darkWispTimer > 0) return;
    _darkWispTimer = _kDarkWispIntervalSeconds;
    final live = combatEnemies.where((e) => !e.isDead).length;
    if (live >= _kDarkWispMax) return;
    spawnWispWave(
      element: 'Lightning',
      center: a.position,
      count: _kDarkWispMax - live,
      announce: false,
    );
    _setAmbientHint('Spark wisps prowl the dead wires');
  }

  /// Is the vault bolt solid at this instant? Shut while the trunk burns, and
  /// still shut while the eased slide has not yet cleared the doorway.
  bool _vaultBoltBlocked(DungeonRoom room) =>
      circuitRoomLit(room.id) || _vaultBoltOpen < 0.55;

  void _updateVaultBolt(DungeonCreature a, DungeonRoom room) {
    final bolt = room.vaultBolt!;
    final shut = _vaultBoltBlocked(room);
    final keep = <String>{};
    if (shut && bolt.inflate(30).contains(a.position)) {
      keep.add('circuit:vault_bolt');
      _setBlockedHintOnce(
        'circuit:vault_bolt',
        'The vault bolt holds while this trunk burns',
      );
    }
    _releaseBlockedExcept('circuit:vault_bolt', keep);
    // The bolt slamming home must never trap a creature inside its slot.
    if (!_fallRecovering &&
        shut &&
        bolt.inflate(PlanetDungeonGame._radius - 2).contains(a.position)) {
      _beginFallRecovery(
        a,
        Offset(a.position.dx, bolt.bottom + PlanetDungeonGame._radius + 6),
        hint: 'The bolt slams home — the surge throws you clear',
      );
    }
  }

  // ── Raikuma feeds on the powered trunk (§7 retrofit) ─────

  /// Raikuma rouses at the LATCH, not at the door. The core hatch is sealed
  /// until its guardian is awake (§ the guardian seal), so waking it on
  /// arrival in the core would seal the room against itself: the beam that
  /// throws the gate open is the same act that uncoils the thing behind it.
  /// The player hears it from the maze — which is the better beat anyway.
  void _maybeWakeRaikuma(DungeonRoom room) {
    if (guardianAwake) return;
    // Standing in the core still counts (the powered barrier vouches for it):
    // belt and braces, so no route into that room can ever find it asleep.
    final atCore = room.guardian != null;
    if (!_beamLatched && !hasStar(2) && !atCore) return;
    DungeonRoom? core = atCore ? room : null;
    if (core == null) {
      for (final r in layout.rooms.values) {
        if (r.guardian != null) {
          core = r;
          break;
        }
      }
    }
    final g = core?.guardian;
    if (g == null || hasStar(g.starIndex)) return;
    guardianAwake = true;
    guardianHp = PlanetDungeonGame.maxGuardianHp;
    final inCore = identical(core, room);
    if (inCore && !isRaid) {
      // Already standing in the core when it woke: it seizes at once.
      _seizeCoreTrunk(core!);
    } else {
      _setHint('Behind the hatch, Raikuma uncoils from the grid', 4.2);
    }
    // The escort only gathers where the party can see it; woken from the maze
    // the core keeps its spawn for the arrival.
    if (inCore) {
      spawnWispWave(
        element: 'Lightning',
        center: g.position,
        count: 3,
        unstable: true,
        announce: false,
      );
    }
  }

  /// Raikuma SEIZES the dynamo — the core trunk surges live and it drinks, so
  /// there is no lull until the spike grounds it. Fired when the guardian
  /// LANDS in its core (or at the wake, if the party is already standing
  /// there): stealing the trunk from the maze the moment the beam latched
  /// would darken the room the player is still standing in.
  void _seizeCoreTrunk(DungeonRoom core) {
    if (!_isCircuit || isRaid) return;
    final g = core.guardian;
    if (g == null || hasStar(g.starIndex)) return;
    final trunk = _trunkForRoom(core.id);
    if (trunk == null) {
      _setHint('Raikuma uncoils from the grid', 4.2);
      return;
    }
    activeTrunk = trunk.id;
    _raikumaFed = true;
    _dynamoSwing = 0;
    _setHint(
      'Raikuma uncoils from the grid — and drinks the powered trunk',
      4.2,
    );
  }

  /// Called from the shared guardian loop (one `_isCircuit`-guarded line in
  /// `_updateAltar`): while Raikuma feeds on its powered trunk there is NO
  /// lull; grounding the trunk opens a timed vulnerability window, and when
  /// the window shuts Raikuma seizes the trunk back. Raids (no trunks, no
  /// spike in the generated arena) keep the shared rage/lull cycle.
  void _applyRaikumaFeed(DungeonRoom room, double dt) {
    final g = room.guardian;
    if (g == null || room.coreBreaker == null || isRaid) return;
    if (hasStar(g.starIndex)) return;
    final trunk = _trunkForRoom(room.id);
    if (trunk == null) return;
    if (activeTrunk == trunk.id) {
      // Feeding: whatever powered the trunk — the wake-seize, a re-seize, or
      // the player's own routing — the guardian drinks and never lulls.
      _raikumaFed = true;
      guardianVulnerable = false;
      return;
    }
    if (_raikumaFed) {
      // The trunk just died under it — the forced window opens.
      _raikumaFed = false;
      _raikumaLullLeft = _rocEnraged ? _kRaikumaLullEnraged : _kRaikumaLull;
    }
    _raikumaLullLeft -= dt;
    if (_raikumaLullLeft <= 0) {
      // The window closes: Raikuma seizes the trunk back and feeds again.
      _raikumaFed = true;
      activeTrunk = trunk.id;
      _dynamoSwing = 0;
      guardianVulnerable = false;
      _setHint('Raikuma drinks — the core trunk surges back to life', 2.8);
    } else {
      guardianVulnerable = true;
    }
  }

  /// The grounding spike: a Lightning creature cuts the core trunk mid-fight,
  /// forcing Raikuma's vulnerability window. Checked BEFORE the guardian's
  /// own interaction catch (the spike sits inside the guardian's radius).
  bool _tryCoreBreaker(DungeonCreature a) {
    final room = currentRoom;
    final spike = room.coreBreaker;
    if (spike == null || isRaid) return false;
    if ((a.position - spike).distance > 56) return false;
    if (a.member.element != 'Lightning') {
      _setBlockedHint('The grounding spike answers only Lightning');
      return true;
    }
    final g = room.guardian;
    if (g == null || !guardianAwake || hasStar(g.starIndex)) {
      _setHint('The spike is quiet — nothing drinks the trunk now');
      return true;
    }
    if (!_raikumaFed) {
      _setHint('The trunk is already dead — strike while Raikuma reels');
      return true;
    }
    activeTrunk = null;
    _dynamoSwing = 0;
    _spawnAlchemyBurst(
      spike,
      producedElement: 'Lightning',
      unstable: true,
      particleCount: 26,
      intensity: 1.2,
    );
    _setHint(
      'The spike bites — the trunk dies and Raikuma reels into the lull',
      3.2,
    );
    return true;
  }

  // ── Action button ────────────────────────────────────────

  /// Bare the gallery's hidden storm-cell echoes.
  ///
  /// Element-only (§4): any Lightning hand feels the air refusing to sit
  /// still. This was part of the Mask reading, which made a QUESTION into
  /// permanent progress — pressing HINT out of curiosity would discover the
  /// cells for you. Asking now only says how many are still hiding; finding
  /// them is something you do.
  bool _tryBareStormCells(DungeonCreature a, DungeonRoom room) {
    if (room.stormCells.isEmpty) return false;
    if (a.member.element != 'Lightning') return false;
    var found = 0;
    for (final cell in room.stormCells) {
      if (discoveredClouds.contains(cell.id)) continue;
      if ((a.position - cell.position).distance >= 220) continue;
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
    return found > 0;
  }

  bool _tryCircuit(DungeonCreature a) {
    if (!_isCircuit) return false;
    final room = currentRoom;

    if (_tryBareStormCells(a, room)) return true;

    // 0) The dynamo breakers — the zero-sum trunk selector.
    // The rotor's own verbs come first at the dynamo: Air winds it, and
    // Lightning throws a fused dynamo. Everything else falls through to the
    // breakers.
    if (_tryThunderbolt(a, room)) return true;
    if (room.id == layout.dynamoRoomId && _trySelectTrunk(a, room)) {
      return true;
    }

    if (room.beamEmitters.isNotEmpty) return _tryBeamMaze(a, room);
    if (_roomCleared(room)) return false;

    // 1) Charge a (non-latching) source pylon you're standing at — the entry
    // rite's dead bus.
    for (final node in room.circuitNodes) {
      if (node.kind != CircuitNodeKind.source) continue;
      if (node.latching) continue; // sockets, not charge-driven
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
      _setBlockedHint('The anvil-cell answers only Fire');
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

  // ── THE THUNDERBOLT · the lost maxim ─────────────────────
  //
  // WHAT THIS REPLACES: it fired off Star 3's beam, if a Lightning Horn
  // happened to be standing among the conductors when the tower lit. A secret
  // that rides a star's coat-tails and asks nothing of its own — the weakest
  // entry on the roster.
  //
  // THE CHAIN, and it is built out of the one thing this planet owns that no
  // other does: the dynamo is ZERO-SUM. It feeds one trunk and darkens the
  // rest, and every wing you have ever lit cost you the other three. The
  // secret is refusing that.
  //
  //   AIR winds the rotor past its limit. It bleeds back down on its own, so
  //   the over-speed is the clock the whole rite runs against.
  //   FIRE welds a breaker's blade shut — but only while the rotor is over,
  //   because the jaws must be carrying more than they were built for to
  //   fuse. Four breakers, four welds: the repeated beat.
  //   LIGHTNING throws the rotor with all four fused. The dynamo has nowhere
  //   left to choose, every trunk takes at once, and the works lets go.
  //
  // Nothing is consumed: Lightning on a welded breaker blows the fuse open
  // again, and a lapsed over-speed costs the walk back to the rotor and
  // nothing else.

  /// Seconds of over-speed one winding buys.
  static const double kRotorOverspeedSeconds = 22.0;

  /// How near the rotor a creature must stand to work it.
  static const double _kRotorReach = 70.0;

  bool get _atDynamo => _isCircuit && currentRoomId == layout.dynamoRoomId;

  /// Are all four breakers fused shut?
  bool get dynamoFused =>
      layout.dynamoTrunks.isNotEmpty &&
      layout.dynamoTrunks.every((t) => weldedBreakers.contains(t.id));

  void _updateThunderbolt(double dt) {
    if (!_atDynamo) return;
    if (rotorOverspeed > 0) rotorOverspeed = max(0, rotorOverspeed - dt);
  }

  /// AIR at the rotor, and LIGHTNING once it is fused.
  bool _tryThunderbolt(DungeonCreature a, DungeonRoom room) {
    if (!_atDynamo) return false;
    if (discoveredClouds.contains(kLightningThunderboltEggId)) return false;
    final c = room.bounds.center;
    if ((a.position - c).distance > _kRotorReach) return false;
    final element = a.member.element;

    if (element == 'Air') {
      rotorOverspeed = kRotorOverspeedSeconds;
      _dynamoSwing = 0;
      _spawnAlchemyBurst(
        c,
        producedElement: 'Air',
        reagentElements: const ['Lightning'],
        particleCount: 20,
        intensity: 0.9,
      );
      _setHint('The rotor takes the wind and runs past its limit', 3.0);
      return true;
    }

    if (element == 'Lightning' && dynamoFused) {
      _spawnAlchemyBurst(
        c,
        producedElement: 'Lightning',
        reagentElements: const ['Air', 'Fire'],
        unstable: true,
        particleCount: 40,
        intensity: 1.4,
      );
      _thunderboltGlow = 0.001;
      beginMaximRite(kLightningThunderboltEggId, c);
      _setHint(
        'Every trunk takes at once — the works has nowhere to put it',
        4.2,
      );
      return true;
    }
    return false;
  }

  /// Throw a trunk breaker at the dynamo. Any Lightning (element-only): the
  /// selected wing wakes, every other goes dark; throwing the live breaker
  /// again grounds the dynamo entirely.
  bool _trySelectTrunk(DungeonCreature a, DungeonRoom room) {
    for (final t in layout.dynamoTrunks) {
      if ((a.position - t.breakerPosition).distance > 56) continue;
      final el = a.member.element;

      // FIRE FUSES THE JAWS — but only on a rotor running past its limit,
      // because a breaker built to open will not weld on the current it was
      // designed for. This is the Thunderbolt's repeated beat.
      if (el == 'Fire' &&
          !discoveredClouds.contains(kLightningThunderboltEggId)) {
        if (weldedBreakers.contains(t.id)) {
          _setHint('This one is fused — it will not open again');
          return true;
        }
        if (rotorOverspeed <= 0) {
          _setBlockedHint(
            'The jaws are cold — nothing here is carrying enough to fuse',
          );
          return true;
        }
        weldedBreakers.add(t.id);
        _spawnAlchemyBurst(
          t.breakerPosition,
          producedElement: 'Lightning',
          reagentElements: const ['Air', 'Fire'],
          particleCount: 18,
          intensity: 0.95,
        );
        _setHint(
          dynamoFused
              ? 'The last blade fuses — the dynamo has nowhere left to choose'
              : 'The blade fuses across the jaws '
                    '(${weldedBreakers.length} of ${layout.dynamoTrunks.length})',
          3.2,
        );
        return true;
      }

      if (el != 'Lightning') {
        _setBlockedHint('The breaker answers only Lightning');
        return true;
      }

      // A FUSED BREAKER IS NOT STUCK. The storm blows the weld off it, which
      // is the undo the whole rite needs in order to be allowed a wrong turn.
      if (weldedBreakers.remove(t.id)) {
        _spawnAlchemyBurst(
          t.breakerPosition,
          producedElement: 'Lightning',
          unstable: true,
          particleCount: 16,
          intensity: 0.9,
        );
        _setHint('The storm blows the weld off — the blade is free', 2.8);
        return true;
      }
      _dynamoSwing = 0;
      _spawnAlchemyBurst(
        t.breakerPosition,
        producedElement: 'Lightning',
        unstable: true,
        particleCount: 20,
        intensity: 1.0,
      );
      if (activeTrunk == t.id) {
        activeTrunk = null;
        _setHint('The breaker opens — the dynamo idles, every trunk dark', 3.0);
      } else {
        activeTrunk = t.id;
        _setHint(
          'The dynamo swings — the ${t.name.toLowerCase()} wakes, '
          'the rest go dark',
          3.0,
        );
      }
      return true;
    }
    return false;
  }

  bool _chargePylon(DungeonCreature a, CircuitNode node) {
    if (a.member.element != 'Lightning') {
      _setBlockedHint('This dead iron answers only Lightning');
      return true;
    }
    // ELEMENT-ONLY: every Lightning drives the same full, clean charge.
    circuitCharge[node.id] = _kChargeWindow;
    _circuitChargeMax[node.id] = _kChargeWindow;
    _spawnAlchemyBurst(
      node.position,
      producedElement: 'Lightning',
      unstable: true,
      particleCount: 26,
      intensity: 1.2,
    );
    _setHint('A full, clean charge drives into the pylon');
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
      _setHint('The cell rests cold on the anvil');
    } else {
      energizedSockets.add(sock.id);
      _setHint('The storm-cell socket latches live');
    }
    // ELEMENT-ONLY: whoever herds the cell seats it just as quietly.
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

  // ── Insight (Mask) — the ONLY channel allowed to teach ──

  void _circuitReveal(DungeonCreature a, DungeonRoom room) {
    final tier = revealHintTier(a.member.statIntelligence);
    // The BARING used to happen here — a question that permanently discovered
    // hidden storm-cells, which is progress, not information. It is a verb now
    // (_tryBareStormCells). All this does is say whether anything is hiding.
    final hidden = room.stormCells
        .where((c) => !discoveredClouds.contains(c.id))
        .length;
    if (hidden > 0) {
      _setInsightHint(
        'The air will not sit still — $hidden echo${hidden == 1 ? '' : 'es'} '
        'somewhere in this gallery',
      );
      return;
    }
    // Star 1 — the Pylon Hall braid. t0 names the shape, t1 the method,
    // t2 the tempting lie the hall is built to teach.
    if (room.circuitStarIndex == 0 && room.beamEmitters.isNotEmpty) {
      if (!circuitRoomLit(room.id)) {
        _setHint('The hall is dead — the dynamo must feed the pylon trunk');
        return;
      }
      _setHint(
        tier >= 2
            ? 'The low vent and the flame in front of it make a real bolt — '
                  'and it dies in the east wall. Only the high vent ever '
                  'reaches iron'
            : tier >= 1
            ? 'Air opens a vent; Fire standing in that wind turns it to '
                  'lightning — and only lightning wakes the mast'
            : 'The mast drinks lightning alone; wind and flame must braid to '
                  'make it, and iron must carry it home',
      );
      return;
    }
    // Star 3 — the Spire. Three masts, one bolt, and fulminate that only the
    // charged half can set off.
    if (room.beamEmitters.isNotEmpty) {
      _setHint(
        tier >= 2
            ? 'Convert high on the long east fall — everything after it is '
                  'charged, and the charged run must thread all three masts '
                  'while missing every vat. The east aisle runs clear of all '
                  'iron: that pair is a lie'
            : tier >= 1
            ? 'One bolt must lie on all three masts at once, and the charged '
                  'half must never cross fulminate — the wind half may'
            : 'Three masts, one braid. Where the flame stands decides how '
                  'much of the run is lightning',
      );
      return;
    }
    // Star 2 — the works.
    if (room.cellSockets.isNotEmpty) {
      _setHint(
        tier >= 1
            ? 'Herd each echo to a socket — the anvil-cell answers only to '
                  'Fire\'s heat, and the works sing only while their trunk burns'
            : 'The sockets want their storm-cells, and the works want the '
                  'dynamo',
      );
      return;
    }
    // The dynamo court — the zero-sum rule, read; t2 whispers the vault.
    if (room.id == layout.dynamoRoomId) {
      _setHint(
        tier >= 2
            ? 'The dynamo owns one trunk at a time — and the vault bolt only '
                  'falls in a DEAD trunk'
            : 'The dynamo owns one trunk at a time — what it feeds wakes; '
                  'the rest go dark',
      );
      return;
    }
    // The vault — the re-hide, named.
    if (room.vaultBolt != null) {
      _setHint(
        'The bolt holds while this trunk burns — kill the power you '
        'stand in',
      );
      return;
    }
    // The storm core — the feed, named.
    if (room.guardian != null && guardianAwake) {
      _setHint(
        'Raikuma drinks the powered trunk — ground it at the spike to '
        'force the lull',
      );
      return;
    }
    _setHint(_nothingHiddenLine());
  }

  // ── Collision: powered barriers + the vault bolt ─────────

  bool _circuitBlocksAt(Offset center, DungeonRoom room) {
    // The vault bolt: solid while its trunk burns (or the slide hasn't
    // cleared the doorway yet).
    final bolt = room.vaultBolt;
    if (bolt != null && _vaultBoltBlocked(room)) {
      if (center.dx > bolt.left - PlanetDungeonGame._radius &&
          center.dx < bolt.right + PlanetDungeonGame._radius &&
          center.dy > bolt.top - PlanetDungeonGame._radius &&
          center.dy < bolt.bottom + PlanetDungeonGame._radius) {
        return true;
      }
    }
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

  // ── Hints (§5.6): ambient = flavor ONLY, objective = goal ONLY ──

  void _circuitAmbientHint(DungeonCreature a, DungeonRoom room) {
    // Rare atmosphere — no mechanics, no stats, no teaching.
    if ((_trunkDark[room.id] ?? 0) > 0.6) {
      _setAmbientHint('Dead wires tick as they cool');
      return;
    }
    if (room.id == layout.dynamoRoomId) {
      _setAmbientHint('The great rotor never slows');
      return;
    }
    if (room.circuitNodes.isNotEmpty || room.beamEmitters.isNotEmpty) {
      _setAmbientHint('Ozone hangs sharp over the conductors');
    }
  }

  String? _circuitObjectiveHint(DungeonRoom room) {
    // Room-entry goal lines — WHAT, never HOW (the method lives with Mask).
    if (room.id == layout.dynamoRoomId) {
      return 'Dynamo Court — one dynamo, four dark trunks';
    }
    if (room.cellSockets.isNotEmpty) {
      return 'Cloud Works — three sockets stand empty';
    }
    if (room.circuitStarIndex != null && room.beamEmitters.isNotEmpty) {
      return 'Pylon Hall — one dead mast, and no bolt in the hall to wake it';
    }
    if (room.beamConverters.isNotEmpty) {
      return 'Storm Spire — three dead masts, and only lightning wakes them';
    }
    if (room.guardian != null) {
      return 'Storm Core — face Raikuma: calm it, or strike in its lulls';
    }
    if (room.stormCells.isNotEmpty) {
      return 'Mirror Gallery — something stirs behind the glass';
    }
    if (room.vaultBolt != null && !discoveredClouds.contains(_vaultCacheId)) {
      return 'Capacitor Vault — the treasury hoards its charge';
    }
    return null;
  }

  /// The Lightning progress readout (§5.6 STATE LEAVES THE CAPSULE): live
  /// terminal/socket counters in the star wings, the dynamo's routing state
  /// everywhere else on the grid.
  DungeonProgressReadout? _circuitProgressReadout() {
    final room = currentRoom;
    // Either beam hall: masts the CHARGED half is lying on right now.
    if (room.beamEmitters.isNotEmpty &&
        !(room.circuitStarIndex == 0 ? hasStar(0) : _beamLatched)) {
      final terminals = beamTerminalsOf(room);
      var lit = 0;
      final vent = _activeVent(room);
      final conv = _activeConverter(room);
      if (vent != null &&
          conv != null &&
          (room.circuitStarIndex == null || circuitRoomLit(room.id))) {
        final path = _computeBeam(room, vent);
        final split = _beamConvertSplit(path, conv);
        if (split != null) {
          final bolt = <Offset>[split.at, ...path.sublist(split.seg + 1)];
          for (final t in terminals) {
            if (_beamHits(bolt, t)) lit++;
          }
        }
      }
      final total = terminals.length;
      return DungeonProgressReadout(
        label: total > 1 ? 'MASTS' : 'MAST',
        value: '$lit/$total',
        fraction: total == 0 ? null : lit / total,
      );
    }
    // S2: energized sockets.
    if (room.cellSockets.isNotEmpty && !hasStar(1)) {
      final total = room.cellSockets.length;
      final n = room.cellSockets
          .where((s) => energizedSockets.contains(s.id))
          .length;
      return DungeonProgressReadout(
        label: 'SOCKETS',
        value: '$n/$total',
        fraction: total == 0 ? null : n / total,
      );
    }
    // Anywhere on the grid: where the power is, glanceable.
    if (room.id == layout.dynamoRoomId || _trunkForRoom(room.id) != null) {
      DynamoTrunk? sel;
      for (final t in layout.dynamoTrunks) {
        if (t.id == activeTrunk) sel = t;
      }
      return DungeonProgressReadout(
        label: 'DYNAMO',
        value: sel?.name ?? 'GROUNDED',
      );
    }
    return null;
  }

  double get _circuitMoodTarget {
    final dark = _trunkDark[currentRoomId] ?? 0;
    final double base;
    switch (currentRoomId) {
      case 'overload_maze':
        base = 0.26;
        break;
      case 'storm_core':
        base = guardianAwake ? 0.18 : 0.24;
        break;
      case 'cloud_works':
      case 'mirror_gallery':
        base = 0.5;
        break;
      case 'arc_gate':
        base = 0.4;
        break;
      default:
        base = 0.46;
    }
    // A dead wing reads storm-dark even before the overlay finishes easing.
    return (base - 0.22 * dark).clamp(0.1, 1.0);
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
    // THE FLOOR OF A STORM-WORKS, NOT GRAPH PAPER.
    //
    // It was a 96px square lattice, which is what every chamber of this
    // planet was standing on — and it is the single reason a dungeon whose
    // premise is "the dungeon IS a living circuit" reads as a circuit
    // DIAGRAM. A circuit in a building is not a grid: it is iron plate
    // bolted down in courses, with cable runs buried in it and the burn
    // marks of everything that has ever arced across it.
    _renderPlainFloor(canvas, room.bounds, room.id == layout.entranceRoomId);
    final b = room.bounds;
    final seed = (b.width * 13 + b.height * 7).toInt();

    // PLATE COURSES. Long iron sheets laid across the room, offset row to
    // row like brickwork so the joins never line up into a grid.
    const plateH = 118.0;
    var row = 0;
    for (var y = b.top; y < b.bottom; y += plateH) {
      final off = (row.isEven ? 0.0 : 150.0);
      final h = min(plateH, b.bottom - y);
      canvas.drawRect(
        Rect.fromLTWH(b.left, y, b.width, h),
        Paint()
          ..color = (row.isEven
                  ? const Color(0xFF10161F)
                  : const Color(0xFF0C1219))
              .withValues(alpha: 0.5),
      );
      // The course join, and a lit top edge so the plate has thickness.
      canvas.drawLine(
        Offset(b.left, y),
        Offset(b.right, y),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFF8FB6D8).withValues(alpha: 0.06),
      );
      // Vertical joins between sheets in this course.
      for (var x = b.left + off + 300; x < b.right; x += 300) {
        canvas.drawLine(
          Offset(x, y + 2),
          Offset(x, y + h - 2),
          Paint()
            ..strokeWidth = 1.0
            ..color = const Color(0xFF04070C).withValues(alpha: 0.55),
        );
      }
      // RIVETS along the course, because bolted plate is what says iron.
      for (var x = b.left + 40 + off * 0.2; x < b.right - 20; x += 74) {
        canvas.drawCircle(
          Offset(x, y + 7),
          2.0,
          Paint()..color = const Color(0xFF6E8CA8).withValues(alpha: 0.16),
        );
        canvas.drawCircle(
          Offset(x, y + 6),
          1.1,
          Paint()..color = const Color(0xFFBFE6FF).withValues(alpha: 0.10),
        );
      }
      row++;
    }

    // CABLE RUNS sunk into the plate — three heavy conduits crossing the
    // room, sagging a little, with clamps holding them down. This is the
    // building's own wiring, and it is what the puzzles' bright wires are
    // laid on TOP of.
    for (var i = 0; i < 3; i++) {
      final y = b.top + b.height * (0.24 + i * 0.26) + (seed % 17) - 8;
      final path = Path()..moveTo(b.left, y);
      for (var x = b.left; x <= b.right; x += 60) {
        path.lineTo(x, y + sin((x + seed) * 0.006 + i) * 7);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = const Color(0xFF0A0F16).withValues(alpha: 0.65),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFF3E5A72).withValues(alpha: 0.30),
      );
      for (var x = b.left + 90; x < b.right - 40; x += 210) {
        final yy = y + sin((x + seed) * 0.006 + i) * 7;
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, yy), width: 14, height: 12),
          Paint()..color = const Color(0xFF1A2430).withValues(alpha: 0.8),
        );
      }
    }

    // SCORCH. Old arcs have been crossing this room for a long time; each
    // leaves a bloom and a few branching scars in the iron.
    for (var i = 0; i < 5; i++) {
      final u = ((i * 2654435761) % 1000) / 1000.0;
      final v = ((i * 40503 + seed) % 997) / 997.0;
      final at = Offset(
        b.left + 60 + u * (b.width - 120),
        b.top + 60 + v * (b.height - 120),
      );
      canvas.drawCircle(
        at,
        22.0 + (i % 3) * 9,
        Paint()..color = const Color(0xFF05080D).withValues(alpha: 0.45),
      );
      final scar = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF7FA8C8).withValues(alpha: 0.10);
      for (var k = 0; k < 4; k++) {
        final a = u * pi * 2 + k * 1.6;
        final mid = at + Offset(cos(a), sin(a)) * 16;
        canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy)
            ..lineTo(mid.dx, mid.dy)
            ..lineTo(
              mid.dx + cos(a + 0.7) * 13,
              mid.dy + sin(a + 0.7) * 13,
            ),
          scar,
        );
      }
    }
  }


  /// The zero-sum darkness overlay: one cheap eased tint over a dead wing's
  /// fabric (alpha-capped so the storm shader still glows through). Drawn
  /// UNDER creatures/enemies so the living stay readable in the dark.
  void _renderCircuitDarkness(Canvas canvas, DungeonRoom room) {
    final d = _trunkDark[room.id] ?? 0;
    if (d <= 0.01) return;
    canvas.drawRect(
      room.bounds.inflate(60),
      Paint()
        ..color = const Color(0xFF04060C).withValues(alpha: _kDarkMaxAlpha * d),
    );
  }

  void _renderCircuit(Canvas canvas, DungeonRoom room) {
    if (room.id == layout.dynamoRoomId) {
      _renderDynamoCourt(canvas, room);
      return;
    }
    if (room.beamEmitters.isNotEmpty) {
      _renderBeamMaze(canvas, room);
      return;
    }
    if (room.vaultBolt != null) {
      _renderVaultSanctum(canvas, room);
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
          ..color = live ? const Color(0xFF9FD4FF) : const Color(0x3354708F)
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

    // 3) Powered barriers — open while powered, and permanently once the
    // Overload Star is banked (or the Thunderbolt won).
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
        if (!discoveredClouds.contains(id) || placedClouds.contains(id)) {
          continue;
        }
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

  /// The hub: the great rotor, four trunk breakers, and the wing wires that
  /// carry the chosen trunk's light toward its doors. Everything eases — the
  /// swing brightens the new wire over ~0.9s, never a snap.
  void _renderDynamoCourt(Canvas canvas, DungeonRoom room) {
    final c = room.bounds.center;
    final live = activeTrunk != null;
    final swing = Curves.easeOutCubic.transform(_dynamoSwing);

    // Wing wires (under everything): breaker → each door its trunk feeds.
    for (final t in layout.dynamoTrunks) {
      final sel = activeTrunk == t.id;
      final alpha = sel ? 0.25 + 0.75 * swing : 1.0;
      final wire = Paint()
        ..strokeCap = StrokeCap.round
        ..color = sel
            ? const Color(0xFF9FD4FF).withValues(alpha: 0.85 * alpha)
            : const Color(0x3354708F)
        ..strokeWidth = sel ? 3.2 : 1.6;
      // Rotor → breaker feeder.
      canvas.drawLine(c, t.breakerPosition, wire);
      for (final d in room.doors) {
        if (!t.roomIds.contains(d.targetRoomId)) continue;
        canvas.drawLine(t.breakerPosition, d.rect.center, wire);
        if (sel && _fx.ready) {
          final u = (_time * 1.4 + d.rect.center.dx * 0.01) % 1.0;
          final bead = Offset.lerp(t.breakerPosition, d.rect.center, u)!;
          drawGlow(canvas, _fx.glow!, bead, 9, const Color(0xFFE9F6FF));
        }
      }
    }

    // THE ROTOR'S HOUSING. It was rings and spokes floating on the floor —
    // the biggest machine on the planet, mounted on nothing. A bolted bed
    // plate under it, and two field magnets flanking the drum.
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(4, 62), width: 190, height: 40),
      Paint()..color = const Color(0xFF04070C).withValues(alpha: 0.6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, 54), width: 176, height: 30),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF17202B),
    );
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
        c + Offset(-72 + i * 29.0, 54),
        2.2,
        Paint()..color = const Color(0xFF6E8CA8).withValues(alpha: 0.5),
      );
    }
    for (final side in const [-1.0, 1.0]) {
      // A field magnet: a squat coil block either side of the drum.
      final at = c + Offset(side * 78, 14);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 34, height: 62),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF1E2833),
      );
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(
          at + Offset(-14, -22 + i * 11.0),
          at + Offset(14, -22 + i * 11.0),
          Paint()
            ..strokeWidth = 2.4
            ..color = const Color(0xFFB98A44).withValues(alpha: 0.30),
        );
      }
    }

    // THE SCAR. Where the works let go, the iron did not recover: a burn
    // struck across the bed and out into the floor, with the welds still
    // standing cold in every breaker. This is what the secret leaves behind,
    // and it is visible from the doorway.
    if (thunderboltWon) {
      final burn = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF9FD4FF).withValues(alpha: 0.30);
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + 0.4;
        final u = Offset(cos(a), sin(a));
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + u.dx * 58, c.dy + u.dy * 58)
            ..lineTo(c.dx + u.dx * 104 + u.dy * 16, c.dy + u.dy * 104 - u.dx * 16)
            ..lineTo(c.dx + u.dx * 168, c.dy + u.dy * 168),
          burn,
        );
      }
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          120,
          const Color(0xFF6BA8FF).withValues(
            alpha: 0.10 + 0.04 * sin(_time * 1.1),
          ),
        );
      }
    }

    // The rotor: brass rings + spinning spokes (faster while feeding, and
    // running away with itself while Air has it over its limit).
    final over = (rotorOverspeed / kRotorOverspeedSeconds).clamp(0.0, 1.0);
    final spin = _time * (live ? 1.7 : 0.5) + _time * 5.5 * over;
    if (over > 0.01) {
      // A heat ring, tightening as the wind bleeds out of it: the clock the
      // whole rite runs against, drawn on the thing that is running.
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 62),
        -pi / 2,
        -pi * 2 * over,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            const Color(0xFFFF7A4A),
            const Color(0xFFBFE6FF),
            over,
          )!.withValues(alpha: 0.9),
      );
    }
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        70,
        (live ? const Color(0xFF6BA8FF) : const Color(0xFFE9D27A)).withValues(
          alpha: 0.32,
        ),
      );
    }
    canvas.drawCircle(c, 56, Paint()..color = const Color(0xFF1A222E));
    canvas.drawCircle(
      c,
      56,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFE9D27A),
    );
    canvas.drawCircle(
      c,
      40,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0x5954708F),
    );
    final spoke = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = live
          ? const Color(0xFF9FD4FF).withValues(alpha: 0.85)
          : const Color(0xFF6E89A6);
    for (var i = 0; i < 6; i++) {
      final ang = spin + i * pi / 3;
      final dir = Offset(cos(ang), sin(ang));
      canvas.drawLine(c + dir * 12, c + dir * 50, spoke);
    }
    canvas.drawCircle(
      c,
      9,
      Paint()..color = live ? const Color(0xFFBFE6FF) : const Color(0xFF54708F),
    );

    // The breakers: squat pylons, thrown-in when their trunk is fed.
    for (final t in layout.dynamoTrunks) {
      final sel = activeTrunk == t.id;
      final bp = t.breakerPosition;
      if (_fx.ready && sel) {
        drawGlow(
          canvas,
          _fx.glow!,
          bp,
          30,
          const Color(0xFF6BA8FF).withValues(alpha: 0.3 + 0.6 * swing),
        );
      }
      // A KNIFE SWITCH IN A HOUSING, not a circle with a stick in it. This is
      // the verb the player throws more than any other on this planet and it
      // was the smallest thing in the room. Backboard, two brass jaws, a
      // ceramic handle on a hinge, and a plate underneath saying which wing.
      _drawCircuitPost(canvas, bp, const Color(0xFFE9D27A), sel);
      final board = RRect.fromRectAndRadius(
        Rect.fromCenter(center: bp + const Offset(0, -6), width: 54, height: 40),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        board,
        Paint()..color = const Color(0xFF1B242F).withValues(alpha: 0.96),
      );
      canvas.drawRRect(
        board,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = (sel ? const Color(0xFFBFE6FF) : const Color(0xFF6E8CA8))
              .withValues(alpha: sel ? 0.95 : 0.5),
      );
      // The two jaws the blade closes across.
      for (final dx in const [-15.0, 15.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: bp + Offset(dx, -4),
              width: 9,
              height: 16,
            ),
            const Radius.circular(2),
          ),
          Paint()
            ..color = (sel ? const Color(0xFFE9D27A) : const Color(0xFF7A6A44)),
        );
      }
      // THE BLADE, hinged at the left jaw: open and up when the trunk is
      // dead, swung flat across both jaws when it is feeding — and FUSED flat
      // for good once Fire has welded it, whatever the dynamo wants.
      final welded = thunderboltWon || weldedBreakers.contains(t.id);
      final blade = welded ? 1.0 : (sel ? swing : 0.0);
      final ang = -1.05 * (1.0 - blade);
      final hinge = bp + const Offset(-15, -4);
      final tip = hinge + Offset(cos(ang), sin(ang)) * 30;
      canvas.drawLine(
        hinge,
        tip,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6
          ..color = sel ? const Color(0xFFEAF6FF) : const Color(0xFF8FB8E0),
      );
      // The ceramic grip at the end of it.
      canvas.drawCircle(
        tip,
        4.6,
        Paint()..color = const Color(0xFFD8B878),
      );
      canvas.drawCircle(hinge, 3.2, Paint()..color = const Color(0xFFBFE6FF));
      if (welded) {
        // The weld bead across the far jaw, still hot.
        final bead = bp + const Offset(15, -4);
        canvas.drawCircle(
          bead,
          5.0,
          Paint()..color = const Color(0xFFFFB46B).withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          bead,
          2.2,
          Paint()..color = const Color(0xFFFFF0D0),
        );
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            bead,
            16,
            const Color(0xFFFF9A4A).withValues(
              alpha: 0.20 + 0.10 * sin(_time * 2.2 + bp.dx),
            ),
          );
        }
      }
      if (sel) {
        // Contact arc across the closed jaws.
        canvas.drawLine(
          bp + const Offset(-15, -4),
          bp + const Offset(15, -4),
          Paint()
            ..strokeWidth = 1.4
            ..color = const Color(0xFFEAF6FF).withValues(alpha: 0.5 * swing),
        );
      }
    }
  }

  /// The capacitor vault: sanctum glow + the vault bolt sliding in its slot.
  /// The bolt SLIDES aside as its trunk dies (eased, never a snap) and slams
  /// back home when the power returns.
  void _renderVaultSanctum(Canvas canvas, DungeonRoom room) {
    final bolt = room.vaultBolt!;
    final open = Curves.easeOutCubic.transform(_vaultBoltOpen.clamp(0.0, 1.0));

    // The slot: a faint threshold under the bolt, lit when fallen open.
    canvas.drawRect(
      bolt,
      Paint()
        ..color = open > 0.55
            ? const Color(0x224A7FB0)
            : const Color(0x22101820),
    );
    if (open > 0.55 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        bolt.center,
        bolt.width * 0.4,
        const Color(0xFF6BA8FF).withValues(alpha: 0.35 * open),
      );
    }

    // The bolt itself, anchored at the west jamb, sliding aside as it opens.
    final w = bolt.width * (1.0 - open);
    if (w > 1.5) {
      final r = Rect.fromLTWH(bolt.left, bolt.top, w, bolt.height);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(4));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFF1B2530));
      // BANDED AND BOLTED, so a slab that holds a treasury looks like one.
      // Vertical straps down the bolt with rivets in them, and a bright top
      // edge — the same iron the rest of the works is made of.
      for (var x = r.left + 26; x < r.right - 10; x += 42) {
        canvas.drawRect(
          Rect.fromLTWH(x, r.top + 2, 9, r.height - 4),
          Paint()..color = const Color(0xFF283544),
        );
        for (final fy in const [0.25, 0.75]) {
          canvas.drawCircle(
            Offset(x + 4.5, r.top + r.height * fy),
            1.6,
            Paint()..color = const Color(0xFF8FB0CC).withValues(alpha: 0.5),
          );
        }
      }
      canvas.drawLine(
        Offset(r.left + 2, r.top + 1.5),
        Offset(r.right - 2, r.top + 1.5),
        Paint()
          ..strokeWidth = 1.4
          ..color = const Color(0xFF8FB0CC).withValues(alpha: 0.28),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF6E89A6),
      );
      // Arcing energy bars while the trunk burns.
      if (circuitRoomLit(room.id)) {
        final spark = Paint()
          ..color = const Color(0x885FB8FF)
          ..strokeWidth = 1.4;
        final n = (r.width / 18).floor();
        for (var i = 1; i < n; i++) {
          final x = r.left + r.width * i / n;
          final jitter = sin(_time * 8 + i) * 3;
          canvas.drawLine(
            Offset(x, r.top + 3),
            Offset(x + jitter, r.bottom - 3),
            spark,
          );
        }
      }
    }
  }

  void _renderBeamMaze(Canvas canvas, DungeonRoom room) {
    final terminals = beamTerminalsOf(room);
    final starIdx = room.circuitStarIndex;
    final solved = starIdx != null
        ? hasStar(starIdx)
        : (_beamLatched || hasStar(2));

    // Everything in here stands on the works' own bolted equipment.
    for (final e in room.beamEmitters) {
      _drawCircuitPost(canvas, e.position, const Color(0xFF8FE0EC), true);
    }
    for (final cv in room.beamConverters) {
      _drawCircuitPost(canvas, cv, const Color(0xFFE0A46A), false);
    }
    for (final t in terminals) {
      _drawCircuitPost(canvas, t, const Color(0xFF8FB8E0), false);
    }

    final vent = _activeVent(room);
    final conv = _activeConverter(room);

    // The beam only exists while Air is stationed on a vent.
    final path = vent != null ? _computeBeam(room, vent) : const <Offset>[];
    // Where (if at all) the beam converts to lightning.
    final split = (path.length >= 2 && conv != null)
        ? _beamConvertSplit(path, conv)
        : null;
    final bolt = split == null
        ? const <Offset>[]
        : <Offset>[split.at, ...path.sublist(split.seg + 1)];

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
      _drawStationPad(
        canvas,
        v.position,
        'Air',
        _creatureOn('Air', v.position),
      );
    }
    for (final c in room.beamConverters) {
      _drawStationPad(canvas, c, 'Fire', _creatureOn('Fire', c));
    }

    // Mirrors as 45° plates ( / or \ ).
    final live = vent != null;
    for (final m in room.beamMirrors) {
      _drawBeamMirror(canvas, m, live);
    }

    // Fulminate vats — the negative constraints, seething when cooked. Note
    // they read cold under a WIND run and only ever wake under the bolt.
    for (final vat in room.fulminateVats) {
      _drawFulminateVat(canvas, vat, _vatFuse[vat.id] ?? 0);
    }

    // The masts the bolt has to crown.
    for (final recv in terminals) {
      final lit = solved || (bolt.isNotEmpty && _beamHits(bolt, recv));
      // Mast body — the lone hall mast stands tall; the Spire's three are
      // shorter iron so the room does not read as three towers.
      final h = terminals.length > 1 ? 62.0 : 90.0;
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(recv.dx - 16, recv.dy - 6, 32, h),
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
    // The bolt itself now lives in the shared cosmic VFX layer
    // (`drawLightningBolt`) so survival, cosmic space and the dungeons all
    // draw the identical storm instead of each keeping its own zigzag.
    // Same numbers this room always used — 26px segments, 6px wobble, a
    // 3.4px #EAF6FF core — plus the layered halo the shared version adds.
    // No forks here on purpose: this bolt is a puzzle beam and the player
    // reads which terminals it lies on, so its silhouette stays exact.
    drawLightningBolt(canvas, a, b, time: _time);
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

  /// EVERY PIECE OF THIS CIRCUIT IS BOLTED TO SOMETHING.
  ///
  /// The nodes were bare circles floating on the floor, which is most of why
  /// a storm-works read as a wiring diagram. Each one now stands on a plinth:
  /// a bolted base plate, a short iron column, and a stack of porcelain
  /// insulator rings under the head — the three things that say "high tension
  /// equipment" at any size, and the rings are what carry the voltage.
  void _drawCircuitPost(Canvas canvas, Offset at, Color tone, bool live) {
    // The shadow it casts on the plate, so it is ON the floor.
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(2, 24), width: 54, height: 15),
      Paint()..color = const Color(0xFF04070C).withValues(alpha: 0.55),
    );
    // The bolted base plate.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at + const Offset(0, 21), width: 44, height: 13),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF1A222C),
    );
    for (final dx in const [-15.0, 15.0]) {
      canvas.drawCircle(
        at + Offset(dx, 21),
        2.0,
        Paint()..color = const Color(0xFF6E8CA8).withValues(alpha: 0.55),
      );
    }
    // The column.
    canvas.drawRect(
      Rect.fromCenter(center: at + const Offset(0, 12), width: 15, height: 22),
      Paint()..color = const Color(0xFF232E3A),
    );
    canvas.drawLine(
      at + const Offset(-7.5, 2),
      at + const Offset(-7.5, 22),
      Paint()
        ..strokeWidth = 1.4
        ..color = const Color(0xFF7FA8C8).withValues(alpha: 0.22),
    );
    // Insulator rings: three discs, widest at the bottom.
    for (var i = 0; i < 3; i++) {
      final y = at.dy + 9 - i * 6.0;
      final w = 30.0 - i * 5;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(at.dx, y), width: w, height: 7),
        Paint()
          ..color = (live ? tone : const Color(0xFF8A9AAA))
              .withValues(alpha: live ? 0.42 : 0.28),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(at.dx, y - 1.5), width: w, height: 7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFDCEAF6).withValues(alpha: live ? 0.30 : 0.14),
      );
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
    // The equipment it is mounted on, under the head.
    if (n.kind != CircuitNodeKind.bus) {
      _drawCircuitPost(canvas, n.position, base, live);
    }
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
            ..color = live ? const Color(0xFFE9F6FF) : const Color(0xFF2A3646),
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
      canvas.drawRect(rect, Paint()..color = const Color(0x224A7FB0));
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          rect.center,
          rect.height,
          const Color(0xFF6BA8FF),
        );
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
        : (sock.requiresHeat
              ? const Color(0xFFE9A86B)
              : const Color(0xFF8FB8E0));
    if (_fx.ready && energized) {
      drawGlow(canvas, _fx.glow!, sock.position, 34, const Color(0xFF6BA8FF));
    }
    // A CRADLE, not a ring. Something is meant to be SET into this, so it
    // has a mount, a seat and two contact horns waiting for the cell.
    _drawCircuitPost(canvas, sock.position, c, energized);
    canvas.drawOval(
      Rect.fromCenter(center: sock.position, width: 44, height: 18),
      Paint()..color = const Color(0xFF141C26),
    );
    canvas.drawOval(
      Rect.fromCenter(center: sock.position, width: 44, height: 18),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = c,
    );
    // Contact horns, curling up out of the seat to hold what is set in it.
    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(sock.position.dx + side * 20, sock.position.dy + 2)
          ..quadraticBezierTo(
            sock.position.dx + side * 24,
            sock.position.dy - 14,
            sock.position.dx + side * 13,
            sock.position.dy - 20,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = c.withValues(alpha: energized ? 1.0 : 0.7),
      );
    }
    canvas.drawCircle(
      sock.position,
      6,
      Paint()..color = energized || waiting ? c : const Color(0xFF2A3646),
    );
    if (sock.requiresHeat && !energized) {
      // anvil mark
      canvas.drawRect(
        Rect.fromCenter(
          center: sock.position + const Offset(0, 26),
          width: 26,
          height: 8,
        ),
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
