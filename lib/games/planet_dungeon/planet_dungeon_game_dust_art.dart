// lib/games/planet_dungeon/planet_dungeon_game_dust_art.dart
//
// SABLIS, IN GLASS (docs/dungeons.md §7.11) — Dust's stone and the glass it
// signals with, as a part of planet_dungeon_game.dart.
//
// The city is a dig, so its carved edge is SANDSTONE worn soft by the wind;
// below the streets the cut face is the north wall and the shell keeps low.
// The deck and the standing fabric (flags, banks, ripples, stubs, drums,
// shoring, spoil) never change, so they are baked with the shell into one
// picture per room — they used to be redrawn every frame. The glass is lamp
// amber through a dusty pane, and it sits only where Sablis asks something:
//
//   · a survey tag is a leaded pane carrying its mound's mark, and the pane
//     says the square's state — frosted while buried, lit amber while bared,
//     sanded over while drifted;
//   · a seal cleared of its last load shows a lit glass boss;
//   · the great glass in the court is an hourglass of real leaded glass;
//   · a vane's blade is a pane, lit while it is wound;
//   · a granary pit's plate is glass, lit when its count agrees;
//   · and NOTHING PERISHES — the maxim — sets a rosette of five panes round
//     the cist, one per mound with its mark, lighting in turn as the rite
//     binds and lit on every later descent.

part of 'planet_dungeon_game.dart';

const GlassPalette _kSandGlass = kSandGlass;

final Map<String, ui.Picture> _ruinsStoneCache = {};

extension RuinsOfTimeArt on PlanetDungeonGame {
  void _updateDustGlass(double dt) {
    final target =
        discoveredClouds.contains(kDustNothingPerishesEggId) ||
            _ritePendingEgg == kDustNothingPerishesEggId
        ? 1.0
        : 0.0;
    if (_tallyShown < 0) {
      _tallyShown = target;
    } else if (_tallyShown < target) {
      _tallyShown = min(target, _tallyShown + dt / 2.4);
    } else if (_tallyShown > target) {
      _tallyShown = target;
    }
    // The observatory's star forms once both sights are open.
    final obsIdx = layout.rooms['observatory']?.ruins?.starIndex;
    final starTarget = armillarySeesSky && !(obsIdx != null && hasStar(obsIdx))
        ? 1.0
        : 0.0;
    if (_obsStar < 0) {
      _obsStar = starTarget;
    } else if (_obsStar < starTarget) {
      _obsStar = min(starTarget, _obsStar + dt / 1.8);
    } else if (_obsStar > starTarget) {
      _obsStar = max(starTarget, _obsStar - dt / 0.6);
    }
    final th = _sandThrow;
    if (th != null) {
      th.t += dt;
      // Next door: once the stream has left by the doorway, the camera goes
      // after it and watches it arrive.
      if (th.to == null && !th.cut && th.t >= _kFlightSeconds) {
        th.cut = true;
        cutTo(
          dustMoundById(th.toId)!.roomId,
          dustMoundById(th.toId)!.streetPos,
          hold: _kArriveSeconds - 0.1,
        );
      }
      // …and once the heap is up, slides across to the doorway it chokes.
      if (th.cut && followRoomId != null) {
        final to = dustMoundById(th.toId)!;
        final doors = ruins.stateOf(to.id) == MoundState.drifted
            ? _crossDoorsOf(layout.rooms[to.roomId]!, to.id)
            : const <DungeonDoor>[];
        if (doors.isNotEmpty) {
          final k = Curves.easeInOut.transform(_throwPan(th));
          followAt = Offset.lerp(to.streetPos, doors.first.rect.center, k);
        }
      }
      final end = th.to == null
          ? _kFlightSeconds + _kArriveSeconds
          : _kSandThrowSeconds;
      if (th.t > end) _sandThrow = null;
    }
  }

  // ── THE NIGHT DIG (2026-09-24) ──────────────────────────
  // Sablis read as one tan band: floor, drifts, rubble and the things you
  // act on all at the same brightness. Now the ground is dark umber by lamp
  // and moon, the rubble is cut back to the edges, and the MOUNDS are the
  // heroes — three silhouettes you can tell apart across the room — and a
  // dig throws its sand visibly to where it lands.

  /// A spadeful onto a square in the same room: flight, heap, choke.
  static const double _kSandThrowSeconds = 2.7;
  static const double _kSameFlight = 1.25;

  /// A spadeful for next door: the stream to the doorway, then the camera
  /// in the next room while it arrives, heaps, pans to the doorway it
  /// chokes, and holds on the blocked street.
  static const double _kFlightSeconds = 0.95;
  static const double _kArriveSeconds = 3.9;

  /// Seconds since the sand arrived next door, as a fraction of the stay.
  double _arrive(_DustThrow th) =>
      ((th.t - _kFlightSeconds) / _kArriveSeconds).clamp(0.0, 1.0);

  /// How far the landing square's heap has risen, 0..1.
  double _throwRise(_DustThrow th) => th.to != null
      ? ((th.t - 0.95) / 0.45).clamp(0.0, 1.0)
      : ((_arrive(th) - 0.18) / 0.2).clamp(0.0, 1.0);

  /// How far the landing square's streets have filled with sand, 0..1.
  double _throwChoke(_DustThrow th) => th.to != null
      ? ((th.t - 1.15) / 0.95).clamp(0.0, 1.0)
      : ((_arrive(th) - 0.36) / 0.34).clamp(0.0, 1.0);

  /// The camera's slide from the heap to the doorway it chokes, 0..1.
  double _throwPan(_DustThrow th) =>
      ((_arrive(th) - 0.3) / 0.16).clamp(0.0, 1.0);

  /// How a dug square's own street caves in, 0..1.
  double _throwCaveIn(_DustThrow th) => (th.t / 0.9).clamp(0.0, 1.0);

  /// The street doorways of [moundId]'s square in [room].
  List<DungeonDoor> _crossDoorsOf(DungeonRoom room, String moundId) => [
    for (final d in room.doors)
      if (_moundLeg(room, d) case (final m, 'cross') when m.id == moundId) d,
  ];

  /// Called straight after the dig lands in the ledger: the animation plays
  /// the trade back — the pit opening, the sand in the air, the heap rising
  /// where it falls — while the squares show their OLD states until it gets
  /// there.
  void _startSandThrow(DustMound from, DustMound to) {
    _sandThrow = _DustThrow(
      fromId: from.id,
      toId: to.id,
      toWas: moundStateFor(max(0, ruins.loadsOn(to.id) - 1)),
      from: from.streetPos,
      to: to.roomId == currentRoomId ? to.streetPos : null,
      door: _dustDoorToward(from, to),
    );
  }

  /// Where the sand leaves this room for a square next door: the doorway
  /// into that room, or the wall in that square's direction.
  Offset _dustDoorToward(DustMound from, DustMound to) {
    final room = layout.rooms[from.roomId]!;
    for (final d in room.doors) {
      if (d.targetRoomId == to.roomId) return d.rect.center;
    }
    final u = _moundBearing(from, to);
    final dir = u / u.distance;
    final b = room.bounds.deflate(40);
    var p = from.streetPos;
    while (b.contains(p + dir * 10)) {
      p += dir * 10;
    }
    return p;
  }

  static const Map<String, String> _kMoundNames = {
    'm_gate': 'GATE SQUARE',
    'm_agora': 'AGORA',
    'm_roof': 'ROOF SQUARE',
    'm_bump': 'THE BUMP',
    'm_kiln': 'KILN SQUARE',
  };

  /// A mound in the state it is IN, or — while a spadeful is in flight — in
  /// the state the animation has reached.
  void _drawMoundLive(Canvas canvas, DustMound m, Rect r, _MoundGeometry geo) {
    final th = _sandThrow;
    final now = ruins.stateOf(m.id);
    if (th != null && th.fromId == m.id) {
      // The dig: the paving lifts away and the pit opens under it.
      final k = Curves.easeOut.transform((th.t / 0.5).clamp(0.0, 1.0));
      if (k < 1) {
        canvas.saveLayer(
          r.inflate(20),
          Paint()..color = Colors.white.withValues(alpha: 1 - k),
        );
        _drawBuriedSquare(canvas, r, geo);
        canvas.restore();
      }
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.scale(0.4 + 0.6 * k);
      canvas.translate(-r.center.dx, -r.center.dy);
      _drawMoundState(canvas, m, now, r, geo);
      canvas.restore();
      return;
    }
    if (th != null && th.toId == m.id) {
      final land = _throwRise(th);
      if (land <= 0) {
        _drawMoundState(canvas, m, th.toWas, r, geo);
        return;
      }
      // The heap rises from the ground where the sand falls.
      final k = Curves.easeOutBack.transform(land);
      if (land < 1) _drawMoundState(canvas, m, th.toWas, r, geo);
      canvas.save();
      canvas.translate(r.center.dx, r.bottom);
      canvas.scale(1, k);
      canvas.translate(-r.center.dx, -r.bottom);
      _drawMoundState(canvas, m, now, r, geo);
      canvas.restore();
      return;
    }
    _drawMoundState(canvas, m, now, r, geo);
  }

  void _drawMoundState(
    Canvas canvas,
    DustMound m,
    MoundState state,
    Rect r,
    _MoundGeometry geo,
  ) {
    switch (state) {
      case MoundState.buried:
        _drawBuriedSquare(canvas, r, geo);
        if (_sandThrow == null) _drawMoundChoices(canvas, m);
      case MoundState.bared:
        _drawBaredPit(canvas, r, geo);
      case MoundState.drifted:
        _drawDriftedDune(canvas, r, geo);
    }
  }

  /// BURIED: a square of intact paving, pegged out and strung on all four
  /// sides in chalk — measured, solid, walkable.
  void _drawBuriedSquare(Canvas canvas, Rect r, _MoundGeometry geo) {
    // One laid slab of street. Destination tiles carry the choices around
    // its edge; internal quartering would look like four more choices.
    final slab = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(
      slab.shift(const Offset(0, 6)),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawRRect(slab, Paint()..color = const Color(0xFF6A5A42));
    canvas.drawLine(
      r.bottomLeft + const Offset(4, -1),
      r.bottomRight + const Offset(-4, -1),
      Paint()
        ..strokeWidth = 1.6
        ..color = RuinsOfTimeDungeon._kDustMoon.withValues(alpha: 0.4),
    );
    for (final c in [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft]) {
      canvas.drawCircle(c, 4, Paint()..color = const Color(0xFF2A2014));
      canvas.drawCircle(
        c,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = RuinsOfTimeDungeon._kDustMoon.withValues(alpha: 0.7),
      );
    }
  }

  /// BARED: a black pit with its strata glowing in the lamplight — a way
  /// down, and the brightest warm thing in the room.
  void _drawBaredPit(Canvas canvas, Rect r, _MoundGeometry geo) {
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        r.center,
        r.width * 0.7,
        _kSandGlass.live.withValues(alpha: 0.22 + 0.04 * sin(_time * 2.1)),
      );
    }
    canvas.drawPath(
      geo.lip,
      Paint()..color = RuinsOfTimeDungeon._kDustMoon.withValues(alpha: 0.5),
    );
    canvas.drawPath(geo.pit, Paint()..color = const Color(0xFF050302));
    canvas.save();
    canvas.clipPath(geo.pit);
    const strata = [Color(0xFFE8B048), Color(0xFFB0702A), Color(0xFF7A4A12)];
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top + 4.0 + i * 8, r.width, 6),
        Paint()..color = strata[i].withValues(alpha: 0.75 - i * 0.18),
      );
    }
    canvas.restore();
    canvas.drawPath(
      geo.pit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kSandGlass.live.withValues(alpha: 0.6),
    );
  }

  /// DRIFTED: a tall moonlit dune, casting a long shadow — packed hard, and
  /// the one thing here the spade will not bite.
  void _drawDriftedDune(Canvas canvas, Rect r, _MoundGeometry geo) {
    canvas.save();
    canvas.translate(22, 14);
    canvas.drawPath(
      geo.dune,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.restore();
    canvas.drawPath(geo.dune, Paint()..color = RuinsOfTimeDungeon._kDustMoon);
    canvas.drawPath(
      geo.duneLee,
      Paint()..color = const Color(0xFF8A7650).withValues(alpha: 0.85),
    );
    for (final w in geo.duneRipples) {
      canvas.drawPath(
        w,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF6A5A3A).withValues(alpha: 0.5),
      );
    }
    canvas.drawPath(
      geo.crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  /// THE SPADEFUL, WATCHED. Here: spoil kicked up off the dig and a stream
  /// of sand arcing over — onto a square in this room, or out through the
  /// doorway. Next door (the camera follows it): the stream pouring in by
  /// the doorway and running across the floor to the square it heaps on.
  void _drawSandThrow(Canvas canvas, DungeonRoom room) {
    final th = _sandThrow;
    if (th == null) return;
    final to = dustMoundById(th.toId)!;
    final fromRoom = dustMoundById(th.fromId)!.roomId;
    if (room.id == fromRoom) _drawSandFlight(canvas, th);
    if (th.to == null && room.id == to.roomId) {
      _drawSandArrival(canvas, room, th, to);
    }
  }

  void _drawSandFlight(Canvas canvas, _DustThrow th) {
    final dur = th.to == null ? _kFlightSeconds : _kSameFlight;
    final t = th.t / dur;
    if (t > 1.25) return;
    final from = th.from;
    final to = th.to ?? th.door;
    final peak =
        Offset.lerp(from, to, 0.5)! -
        Offset(0, 80 + (to - from).distance * 0.22);
    Offset along(double u) {
      final a = Offset.lerp(from, peak, u)!;
      final b = Offset.lerp(peak, to, u)!;
      return Offset.lerp(a, b, u)!;
    }

    final sand = RuinsOfTimeDungeon._kDustMoon;
    // Spoil kicked up off the dig.
    final kick = (t / 0.35).clamp(0.0, 1.0);
    if (kick < 1) {
      for (var i = 0; i < 10; i++) {
        final a = -pi / 2 + (i - 4.5) * 0.28;
        final p = from + Offset(cos(a), sin(a)) * (20 + 50 * kick);
        canvas.drawCircle(
          p,
          3 * (1 - kick) + 1,
          Paint()..color = sand.withValues(alpha: 0.8 * (1 - kick)),
        );
      }
    }
    // The stream: thirty grains, each leaving a beat after the last.
    final grain = Paint()..color = sand;
    for (var i = 0; i < 30; i++) {
      final u = ((t - 0.1 - i * 0.012) / 0.62).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      final jitter = Offset(sin(i * 2.3) * 6, cos(i * 1.7) * 5) * (1 - u);
      canvas.drawCircle(along(u) + jitter, 1.4 + (i % 3) * 0.6, grain);
    }
    // …and it keeps coming, thinner, until the doorway it chokes is full —
    // the whole trade is one motion, never a pause and then a door.
    if (th.to != null && t > 0.55) {
      final taper = 1 - _throwChoke(th);
      final fadeIn = ((t - 0.55) / 0.2).clamp(0.0, 1.0);
      for (var i = 0; i < 14; i++) {
        final u = ((th.t * 0.85 + i / 14) % 1.0);
        canvas.drawCircle(
          along(u),
          1.3 + (i % 2) * 0.5,
          Paint()..color = sand.withValues(alpha: 0.8 * fadeIn * taper),
        );
      }
    }
    // Landing in this room: a burst round the rising heap.
    if (th.to != null) {
      final land = _throwRise(th);
      if (land > 0 && land < 1) {
        canvas.drawOval(
          Rect.fromCenter(
            center: to,
            width: 60 + 110 * land,
            height: 24 + 44 * land,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - land)
            ..color = sand.withValues(alpha: 0.75 * (1 - land)),
        );
      }
    }
  }

  /// Next door: sand pours in through the doorway, runs across the floor in
  /// a ribbon of grains and heaps where the square is.
  void _drawSandArrival(
    Canvas canvas,
    DungeonRoom room,
    _DustThrow th,
    DustMound to,
  ) {
    final a = _arrive(th);
    if (th.t <= _kFlightSeconds || a >= 1) return;
    final fromRoom = dustMoundById(th.fromId)!.roomId;
    var entry = room.bounds.center;
    for (final d in room.doors) {
      if (d.targetRoomId == fromRoom) entry = d.rect.center;
    }
    final target = to.streetPos;
    final sand = RuinsOfTimeDungeon._kDustMoon;
    // The spill at the doorway: a fan of sand sliding in.
    final spill =
        (a / 0.12).clamp(0.0, 1.0) * (1 - ((a - 0.35) / 0.15).clamp(0.0, 1.0));
    if (spill > 0) {
      final inward = (target - entry) / (target - entry).distance;
      canvas.drawPath(
        Path()
          ..moveTo(entry.dx - inward.dy * 30, entry.dy + inward.dx * 30)
          ..quadraticBezierTo(
            (entry + inward * 50 * spill).dx,
            (entry + inward * 50 * spill).dy,
            entry.dx + inward.dy * 30,
            entry.dy - inward.dx * 30,
          )
          ..close(),
        Paint()..color = sand.withValues(alpha: 0.8 * spill),
      );
    }
    // The stream across the floor to the square: grains skittering along a
    // shallow wave, many at once, thinning as the heap takes them.
    // ONE CONTINUOUS FLOW: the leading edge runs in, then the stream keeps
    // coming — thinning, never stopping dead — until the doorway is full.
    final lead = (a / 0.3).clamp(0.0, 1.0);
    final taper = 1 - _throwChoke(th);
    final grain = Paint()..color = sand;
    final dir = target - entry;
    final side = Offset(-dir.dy, dir.dx) / dir.distance;
    for (var i = 0; i < 40; i++) {
      final u = ((th.t * 0.9 + i / 40) % 1.0);
      if (u > lead) continue;
      final alpha = (0.35 + 0.65 * taper) * (i.isEven || taper > 0.5 ? 1 : 0);
      if (alpha <= 0.02) continue;
      final p =
          Offset.lerp(entry, target, u)! + side * (sin(u * 9 + i * 1.3) * 10);
      canvas.drawCircle(
        p,
        1.3 + (i % 3) * 0.6,
        grain..color = sand.withValues(alpha: alpha),
      );
    }
  }

  /// The deck, the standing fabric and the sandstone shell, baked once.
  void _renderRuinsStone(Canvas canvas, DungeonRoom room, _RuinsGround g) {
    final b = room.bounds;
    canvas.drawPicture(
      _ruinsStoneCache.putIfAbsent(
        '${room.id}|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          // A ground under the deck, square to the shell — inside the floor
          // translucency budget (§8).
          c.drawRect(
            b,
            Paint()..color = _kSandGlass.floor.withValues(alpha: 0.55),
          );
          _renderRuinsDeck(c, room, g);
          _renderRuinsFabric(c, room, g);
          paintCarvedRoomShell(
            c,
            b,
            _kSandGlass,
            GlassRng(glassSeed(room.id, b)),
            doors: [
              for (final d in room.doors)
                if (_doorOnWall(room, d)) d.rect,
            ],
            // Below the streets the cut face IS the north wall.
            faceDepth: g.under ? 14 : 40,
            // A dig has no arcade: blind arches filled the low face as a row
            // of black humps.
            arcade: false,
            flags: false,
          );
          return rec.endRecording();
        },
      ),
    );
  }

  /// A survey tag's pane: the mound's mark in glass that says its state.
  void _drawTagGlass(Canvas canvas, Rect tag, int glyph, MoundState state) {
    final pane = Path()..addRect(tag);
    final fill = switch (state) {
      MoundState.buried => _kSandGlass.frostAt(glyph),
      MoundState.bared => _kSandGlass.live,
      MoundState.drifted => const Color(0xFF9A8762),
    };
    paintPane(canvas, pane, fill, _kSandGlass, lead: 2.0);
    if (state == MoundState.bared) {
      paintStreak(canvas, tag.deflate(2), opacity: 0.45);
    }
    _drawSurveyGlyph(
      canvas,
      tag.center,
      5.5,
      glyph,
      state == MoundState.buried
          ? RuinsOfTimeDungeon._kDustPale
          : RuinsOfTimeDungeon._kDustDeep,
    );
  }

  /// A seal's boss: dull glass under the spoil, lit amber once it is bare.
  void _drawDustSealBoss(Canvas canvas, Offset at, bool bare) {
    paintRondel(
      canvas,
      at,
      12,
      _kSandGlass,
      fill: bare ? _kSandGlass.live : _kSandGlass.smoke.withValues(alpha: 0.5),
      rim: bare ? 1 : 0.3,
      lead: 2,
    );
    if (bare) {
      paintStreak(canvas, Rect.fromCircle(center: at, radius: 9), opacity: 0.4);
      _drawStarGlyph(canvas, at, 8, RuinsOfTimeDungeon._kDustDeep);
    }
  }

  /// The great glass's two bulbs, as panes. [sand] paints what is inside
  /// them, between the glass and its lead.
  void _drawGreatGlass(
    Canvas canvas,
    Offset glass,
    bool turned,
    void Function() sand,
  ) {
    final upper = Path()
      ..moveTo(glass.dx - 26, glass.dy - 34)
      ..lineTo(glass.dx + 26, glass.dy - 34)
      ..lineTo(glass.dx, glass.dy)
      ..close();
    final lower = Path()
      ..moveTo(glass.dx, glass.dy)
      ..lineTo(glass.dx + 26, glass.dy + 34)
      ..lineTo(glass.dx - 26, glass.dy + 34)
      ..close();
    if (turned && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        glass,
        60,
        _kSandGlass.live.withValues(alpha: 0.28 + 0.06 * sin(_time * 2)),
      );
    }
    for (final bulb in [upper, lower]) {
      paintPaneFill(canvas, bulb, const Color(0xFF8E9A96), opacity: 0.32);
    }
    sand();
    for (final bulb in [upper, lower]) {
      paintLead(canvas, bulb, _kSandGlass, width: 2.6);
    }
    paintStreak(
      canvas,
      Rect.fromLTWH(glass.dx - 18, glass.dy - 32, 20, 26),
      opacity: turned ? 0.7 : 0.4,
    );
  }

  /// A vane's blade as a leaded pane — lit while it is wound.
  void _drawVaneBlade(Canvas canvas, Path blade, bool armed) {
    paintPane(
      canvas,
      blade,
      armed ? _kSandGlass.live : _kSandGlass.frostAt(2),
      _kSandGlass,
      lead: 1.8,
    );
  }

  /// A granary plate: the pit's mark in glass, lit amber when it agrees.
  void _drawPlateGlass(Canvas canvas, Rect plate, int glyph, bool lit) {
    final pane = Path()
      ..addRRect(RRect.fromRectAndRadius(plate, const Radius.circular(3)));
    paintPane(
      canvas,
      pane,
      lit ? _kSandGlass.live : _kSandGlass.frostAt(glyph),
      _kSandGlass,
      lead: 2.2,
    );
    if (lit) paintStreak(canvas, plate.deflate(3), opacity: 0.4);
    _drawSurveyGlyph(
      canvas,
      plate.center,
      7,
      glyph,
      lit ? const Color(0xFF2A1E0C) : RuinsOfTimeDungeon._kDustPale,
    );
  }

  /// NOTHING PERISHES. A rosette of five panes round the cist, one per mound
  /// with its mark cut in the lead, lighting in turn as the rite binds — the
  /// dead's count of the city, kept in glass for good.
  void _drawTallyRose(Canvas canvas, Offset c) {
    final o = _tallyShown.clamp(0.0, 1.0);
    if (o <= 0) return;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        70 + 20 * o,
        _kSandGlass.live.withValues(
          alpha: o < 1 ? 0.3 * o : 0.18 + 0.04 * sin(_time * 1.3),
        ),
      );
    }
    const n = 5;
    const r0 = 20.0, r1 = 46.0;
    for (var i = 0; i < n && i < kDustMounds.length; i++) {
      final k = ((o - i * 0.14) / 0.3).clamp(0.0, 1.0);
      final a0 = -pi / 2 + (i - 0.5) * 2 * pi / n + 0.04;
      final a1 = a0 + 2 * pi / n - 0.08;
      final pane = ellipseSectorPath(c, r0, r0 * 0.72, r1, r1 * 0.72, a0, a1);
      paintPane(
        canvas,
        pane,
        Color.lerp(_kSandGlass.frostAt(i), _kSandGlass.live, k)!,
        _kSandGlass,
        lead: 2.2,
      );
      final mid = (a0 + a1) / 2;
      final at = c + Offset(cos(mid) * 33, sin(mid) * 33 * 0.72);
      _drawSurveyGlyph(
        canvas,
        at,
        6,
        kDustMounds[i].glyph,
        Color.lerp(
          RuinsOfTimeDungeon._kDustPale,
          RuinsOfTimeDungeon._kDustDeep,
          k,
        )!,
      );
    }
    // The rim that holds them: a gold band, once all five agree.
    final rim = ((o - 0.7) / 0.3).clamp(0.0, 1.0);
    if (rim > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r1 * 2 + 6, height: r1 * 1.44 + 6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = _kSandGlass.gold.withValues(alpha: 0.85 * rim),
      );
    }
  }

  // ── DESTINATION STONES (2026-09-25) ─────────────────────
  // Where a spadeful goes is chosen by standing on a stone beside the mound.
  // They were outlined rounded squares with a thin line to each — UI laid
  // over the world, and on top of the slab and its tag. Now each is a
  // carved stepping-stone set just clear of the slab, the destination's mark
  // in a glass boss: frosted while that mound can take sand, smoked and
  // cracked while it is full, lit amber under your feet. A carved arrow on
  // the stone says which way the sand will go, and standing on it shows the
  // arc the spadeful will fly.

  void _drawMoundChoices(Canvas canvas, DustMound mound) {
    final player = active;
    final selected = player != null && player.alive
        ? _moundTileTarget(player.position, mound)
        : null;
    for (final id in mound.neighbours) {
      final to = dustMoundById(id)!;
      final tile = _moundChoiceTile(mound, to);
      final open = ruins.canDig(mound.id, id);
      final lit = selected?.id == id;
      final out = tile.center - mound.streetPos;
      final u = out / out.distance;
      if (lit && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          tile.center,
          46,
          (open ? _kSandGlass.live : const Color(0xFFB0705A)).withValues(
            alpha: 0.35,
          ),
        );
      }
      // The stone.
      paintCarvedBlock(
        canvas,
        tile.deflate(2),
        6,
        _kSandGlass,
        radius: 8,
        topColor: lit ? const Color(0xFF7A6446) : const Color(0xFF4E4130),
      );
      // A carved arrow at its outer edge: the way the sand will go.
      final tip = tile.center + u * (kMoundChoiceTile / 2 - 3);
      final side = Offset(-u.dy, u.dx);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((tip - u * 7 + side * 5).dx, (tip - u * 7 + side * 5).dy)
          ..lineTo((tip - u * 7 - side * 5).dx, (tip - u * 7 - side * 5).dy)
          ..close(),
        Paint()..color = const Color(0xFF1A120A).withValues(alpha: 0.85),
      );
      // The destination's mark, in a glass boss.
      final c = tile.center - u * 2;
      paintRondel(
        canvas,
        c,
        12,
        _kSandGlass,
        fill: lit && open
            ? _kSandGlass.live
            : open
            ? _kSandGlass.frostAt(to.glyph)
            : _kSandGlass.smoke,
        rim: open ? 1 : 0.35,
        lead: 2,
      );
      _drawSurveyGlyph(
        canvas,
        c,
        6.5,
        to.glyph,
        lit && open
            ? RuinsOfTimeDungeon._kDustDeep
            : open
            ? RuinsOfTimeDungeon._kDustPale
            : RuinsOfTimeDungeon._kDustPale.withValues(alpha: 0.35),
      );
      if (!open) {
        // Full: the glass is cracked across.
        canvas.drawLine(
          c + const Offset(-9, -6),
          c + const Offset(8, 7),
          Paint()
            ..strokeWidth = 1.4
            ..color = _kSandGlass.leadLight.withValues(alpha: 0.6),
        );
      } else if (lit) {
        paintStreak(
          canvas,
          Rect.fromCircle(center: c, radius: 9),
          opacity: 0.5,
        );
      }
    }
  }

  /// The preview and the plate go on top of EVERY mound in the room (drawn
  /// inside one mound, the next mound's slab covered the ghost heap).
  void _drawMoundChoiceOverlay(Canvas canvas, DungeonRoom room) {
    final player = active;
    if (player == null || !player.alive || _sandThrow != null) return;
    for (final m in _liveMoundsIn(room)) {
      if (ruins.stateOf(m.id) != MoundState.buried) continue;
      if ((player.position - m.streetPos).distance > 145) continue;
      final selected = _moundTileTarget(player.position, m);
      // No plate until you are on a stone: where to stand is obvious.
      if (selected == null) continue;
      _drawChoicePlate(canvas, m, selected);
    }
  }

  /// What a press here will do, in words, on a small dark plate above the
  /// mound: where the sand goes, and what that square becomes.
  void _drawChoicePlate(Canvas canvas, DustMound mound, DustMound? selected) {
    final open = selected != null && ruins.canDig(mound.id, selected.id);
    final line1 = selected == null
        ? 'STAND ON A STONE'
        : 'SAND \u2192 ${_kMoundNames[selected.id] ?? ''}';
    final line2 = selected == null
        ? 'to choose where the sand goes'
        : !open
        ? 'is full and can take no more'
        : ruins.loadsOn(selected.id) + 1 >= 2
        ? 'becomes a dune, too packed to dig'
        : 'fills back in';
    final ink = selected == null
        ? RuinsOfTimeDungeon._kDustPale
        : open
        ? _kSandGlass.live
        : const Color(0xFFD08A70);
    TextPainter paint(String s, double size, Color c, FontWeight w) =>
        TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              color: c,
              fontFamily: 'monospace',
              fontSize: size,
              fontWeight: w,
              letterSpacing: 1.2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final a = paint(line1, 11, ink, FontWeight.w800);
    final b = paint(
      line2,
      9.5,
      RuinsOfTimeDungeon._kDustPale.withValues(alpha: 0.85),
      FontWeight.w600,
    );
    final glyphW = selected == null ? 0.0 : 22.0;
    final w = max(a.width + glyphW, b.width) + 20;
    final h = a.height + b.height + 12;
    final plate = Rect.fromCenter(
      center: mound.streetPos - const Offset(0, 90),
      width: w,
      height: h,
    );
    final rr = RRect.fromRectAndRadius(plate, const Radius.circular(6));
    canvas.drawRRect(
      rr.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawRRect(rr, Paint()..color = const Color(0xF0120D07));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ink.withValues(alpha: 0.5),
    );
    a.paint(canvas, Offset(plate.left + 10, plate.top + 5));
    b.paint(canvas, Offset(plate.left + 10, plate.top + 7 + a.height));
    if (selected != null) {
      final c = Offset(
        plate.left + 10 + a.width + 12,
        plate.top + 5 + a.height / 2,
      );
      paintRondel(
        canvas,
        c,
        7,
        _kSandGlass,
        fill: open ? _kSandGlass.live : _kSandGlass.smoke,
        lead: 1.4,
      );
      _drawSurveyGlyph(
        canvas,
        c,
        4,
        selected.glyph,
        open ? RuinsOfTimeDungeon._kDustDeep : RuinsOfTimeDungeon._kDustPale,
      );
    }
  }

  // ── WHAT A DIG DOES TO THE STREETS (2026-09-25) ─────────
  // A crossing is walkable only while its square is flat paving. So a dig
  // cuts a TRENCH across this square's streets, and a dune heaped on the
  // landing square CHOKES its streets with sand. Both are shown — ghosted
  // before the press, happening during the throw, and the choked doorway
  // keeps its drift afterwards.

  /// Straight into the room from the wall a doorway at [at] is cut in.
  Offset _doorInward(DungeonRoom room, Offset at) {
    final b = room.bounds;
    final dl = at.dx - b.left, dr = b.right - at.dx;
    final dt = at.dy - b.top, db = b.bottom - at.dy;
    final m = [dl, dr, dt, db].reduce(min);
    if (m == dl) return const Offset(1, 0);
    if (m == dr) return const Offset(-1, 0);
    if (m == dt) return const Offset(0, 1);
    return const Offset(0, -1);
  }

  /// A DOORWAY WALLED WITH SAND TILES (2026-09-25). The sand that chokes a
  /// street sets into a wall of sandstone tiles laid in brick bond across
  /// the doorway, three courses deep. They drop into place one by one, each
  /// landing with a bump; the middle tile carries the blocked square's
  /// survey mark; and when the last one lands the joints flare amber as the
  /// wall locks. [k] 0..1 is how far it has come.
  void _drawDoorTiles(
    Canvas canvas,
    DungeonRoom room,
    Rect door,
    double k,
    int glyph,
  ) {
    if (k <= 0) return;
    final c = door.center;
    final u = _doorInward(room, c);
    final side = Offset(-u.dy, u.dx);
    final along = (u.dx != 0 ? door.height : door.width) + 28;
    const tile = 20.0, gap = 2.0, rows = 3;
    final cols = (along / (tile + gap)).floor();
    final n = rows * cols;
    final sand = RuinsOfTimeDungeon._kDustMoon;
    // The door behind goes dark as the wall closes over it.
    canvas.drawRect(
      door.inflate(3),
      Paint()..color = const Color(0xFF1A140C).withValues(alpha: 0.9 * k),
    );
    final mid = (cols - 1) ~/ 2;
    for (var r = 0; r < rows; r++) {
      final off = r.isOdd ? (tile + gap) / 2 : 0.0;
      for (var col = 0; col < cols; col++) {
        final i = r * cols + (r.isOdd ? cols - 1 - col : col);
        final start = i / n * 0.82;
        final t = ((k - start) / 0.18).clamp(0.0, 1.0);
        if (t <= 0) continue;
        final x = (col - (cols - 1) / 2) * (tile + gap) + off;
        if (x.abs() > along / 2) continue;
        final home = c + u * (tile / 2 + r * (tile + gap) - 2) + side * x;
        // Drops in from inside the room and settles with a small bump.
        final drop = 1 - Curves.easeOutBack.transform(t);
        final at = home + u * (26 * drop);
        final scale = 1 + 0.25 * drop;
        final shade = ((col * 7 + r * 3) % 5) / 5;
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(scale);
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: tile,
          height: tile,
        );
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
        canvas.drawRRect(
          rr.shift(const Offset(0, 3)),
          Paint()..color = Colors.black.withValues(alpha: 0.45 * t),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF9A8458),
              const Color(0xFFC2AC7C),
              shade,
            )!.withValues(alpha: t),
        );
        // A bevel: lit top-left edge, shaded bottom-right.
        canvas.drawLine(
          rect.topLeft + const Offset(2, 1),
          rect.topRight + const Offset(-2, 1),
          Paint()
            ..strokeWidth = 1.4
            ..color = Colors.white.withValues(alpha: 0.4 * t),
        );
        canvas.drawLine(
          rect.bottomLeft + const Offset(2, -1),
          rect.bottomRight + const Offset(-2, -1),
          Paint()
            ..strokeWidth = 1.4
            ..color = const Color(0xFF3A2C18).withValues(alpha: 0.6 * t),
        );
        if (r == 1 && col == mid) {
          _drawSurveyGlyph(
            canvas,
            Offset.zero,
            5,
            glyph,
            RuinsOfTimeDungeon._kDustDeep.withValues(alpha: t),
          );
        }
        canvas.restore();
        // A puff of sand where it lands.
        if (t > 0.6 && t < 1) {
          final f = (t - 0.6) / 0.4;
          canvas.drawCircle(
            home,
            tile * 0.5 + 10 * f,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2 * (1 - f)
              ..color = sand.withValues(alpha: 0.6 * (1 - f)),
          );
        }
      }
    }
    // The wall locks: the joints flare amber once the last tile is in.
    final lock = ((k - 0.95) / 0.05).clamp(0.0, 1.0);
    if (lock > 0 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c + u * (rows * (tile + gap) / 2),
        along * 0.7,
        _kSandGlass.live.withValues(alpha: 0.18 + 0.1 * sin(_time * 3)),
      );
    }
    if (lock > 0) {
      for (var r = 1; r < rows; r++) {
        final y = c + u * (r * (tile + gap) - 2 - gap / 2);
        canvas.drawLine(
          y - side * along / 2,
          y + side * along / 2,
          Paint()
            ..strokeWidth = 1.2
            ..color = _kSandGlass.live.withValues(alpha: 0.45 * lock),
        );
      }
    }
  }

  /// THE HEAP SHEDS INTO THE STREET: sand sliding off the new dune and
  /// running to the doorway, feeding the drift as it builds — so the heap and
  /// the blocked door are one flow, not two animations taking turns.
  void _drawDriftFeed(
    Canvas canvas,
    DungeonRoom room,
    Offset heap,
    Rect door,
    double rise,
    double k,
  ) {
    final start = ((rise - 0.4) / 0.4).clamp(0.0, 1.0);
    if (start <= 0) return;
    final end = door.center + _doorInward(room, door.center) * 40;
    final dir = end - heap;
    final side = Offset(-dir.dy, dir.dx) / dir.distance;
    final alpha = start * (1 - ((k - 0.75) / 0.25).clamp(0.0, 1.0));
    for (var i = 0; i < 30; i++) {
      final u = ((_time * 0.75 + i / 30) % 1.0);
      final p =
          Offset.lerp(heap, end, u)! +
          side * (sin(u * 7 + i * 2.1) * 9 + (i % 3 - 1) * 5);
      canvas.drawCircle(
        p,
        1.3 + (i % 3) * 0.5,
        Paint()
          ..color = RuinsOfTimeDungeon._kDustMoon.withValues(
            alpha: 0.85 * alpha,
          ),
      );
    }
  }

  /// The consequence, said at the doorway: a small plate once it is shut.
  void _drawBlockedPlate(Canvas canvas, DungeonRoom room, Rect door, double k) {
    if (k <= 0) return;
    final u = _doorInward(room, door.center);
    final at = door.center + u * 120;
    final tp = TextPainter(
      text: TextSpan(
        text: 'STREET BLOCKED',
        style: TextStyle(
          color: const Color(0xFFE8A070).withValues(alpha: k),
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final plate = Rect.fromCenter(
      center: at - Offset(0, 8 * (1 - k)),
      width: tp.width + 20,
      height: tp.height + 10,
    );
    final rr = RRect.fromRectAndRadius(plate, const Radius.circular(6));
    canvas.drawRRect(
      rr,
      Paint()..color = const Color(0xF0120D07).withValues(alpha: 0.94 * k),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFE8A070).withValues(alpha: 0.6 * k),
    );
    tp.paint(canvas, Offset(plate.left + 10, plate.top + 5));
  }

  /// Over the doors, in every room: a street whose square is a dune has its
  /// doorway filled with sand; one whose square is dug out has caved into a
  /// trench. Both happen on screen while the spadeful makes them, and stay.
  void _renderRuinsOverDoors(Canvas canvas, DungeonRoom room) {
    final th = _sandThrow;
    for (final d in room.doors) {
      if (isDoorHidden(room, d)) continue;
      final leg = _moundLeg(room, d);
      if (leg == null || leg.$2 != 'cross') continue;
      final m = leg.$1;
      final state = ruins.stateOf(m.id);
      if (state == MoundState.drifted) {
        final k = th != null && th.toId == m.id ? _throwChoke(th) : 1.0;
        if (th != null && th.toId == m.id && k < 1 && m.roomId == room.id) {
          _drawDriftFeed(canvas, room, m.streetPos, d.rect, _throwRise(th), k);
        }
        _drawDoorTiles(canvas, room, d.rect, k, m.glyph);
        if (th != null && th.toId == m.id) {
          _drawBlockedPlate(
            canvas,
            room,
            d.rect,
            ((k - 0.6) / 0.4).clamp(0.0, 1.0),
          );
        }
      } else if (state == MoundState.bared) {
        final k = th != null && th.fromId == m.id ? _throwCaveIn(th) : 1.0;
        // One look for every blocked street on the planet (the author,
        // 2026-09-25): the tile wall, laid as the dig cuts the street.
        _drawDoorTiles(canvas, room, d.rect, k, m.glyph);
        if (th != null && th.fromId == m.id && th.to != null) {
          _drawBlockedPlate(
            canvas,
            room,
            d.rect,
            ((th.t - 0.7) / 0.4).clamp(0.0, 1.0),
          );
        }
      }
    }
  }

  // ── THE OBSERVATORY (2026-09-25) ────────────────────────
  // The pit round the instrument read as a flat black square and the
  // armillary as three faint ovals. Now: a deep excavation with strata down
  // every wall and dust drifting in it; a carved round plinth with a ring of
  // zodiac glass that lights when the sky is open; brass rings that turn;
  // light pouring down through the dug roof; and — the moment both sights
  // are open — a star forming over the instrument for a Wing to fly into.

  void _drawObservatoryShaft(
    Canvas canvas,
    DungeonRoom room,
    Rect isle,
    bool roofOpen,
  ) {
    var outer = room.gaps.first.rect;
    for (final gap in room.gaps) {
      outer = outer.expandToInclude(gap.rect);
    }
    final inner = isle.inflate(4);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outer)
      ..addRRect(RRect.fromRectAndRadius(inner, const Radius.circular(40)));
    // Depth: darkest at the bottom of the far wall, a gradient toward us.
    canvas.drawPath(
      ring,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF020101), Color(0xFF0E0A06)],
        ).createShader(outer),
    );
    // Strata down every wall of the cut: bands inset from the rim.
    canvas.save();
    canvas.clipPath(ring);
    const bands = [
      Color(0xFF6A5031),
      Color(0xFF3E2F1E),
      Color(0xFF7B5C39),
      Color(0xFF2D2214),
    ];
    for (var i = 0; i < bands.length; i++) {
      final r = outer.deflate(4.0 + i * 7);
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = bands[i].withValues(alpha: 0.55 - i * 0.1),
      );
    }
    // The plinth's own foundation going down into the dark.
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          inner.inflate(6.0 + i * 7),
          Radius.circular(46.0 + i * 7),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = bands[(i + 1) % bands.length].withValues(
            alpha: 0.4 - i * 0.1,
          ),
      );
    }
    // Dust drifting in the shaft.
    for (var i = 0; i < 14; i++) {
      final f = (_time * 0.05 + i * 0.071) % 1.0;
      final p = Offset(
        outer.left + outer.width * ((i * 37 % 100) / 100),
        outer.bottom - outer.height * f,
      );
      canvas.drawCircle(
        p,
        1.4,
        Paint()
          ..color = RuinsOfTimeDungeon._kDustPale.withValues(
            alpha: 0.25 * sin(f * pi),
          ),
      );
    }
    canvas.restore();
    // The rim: a lit lip of cut stone all round.
    canvas.drawRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = RuinsOfTimeDungeon._kDustStone.withValues(alpha: 0.5),
    );
    // THE PLINTH: carved round stone, a ring of zodiac glass in its top.
    final c = isle.center;
    paintCarvedDisc(canvas, c, 72, 60, 14, _kSandGlass);
    paintCarvedDisc(
      canvas,
      c.translate(0, -4),
      56,
      46,
      6,
      _kSandGlass,
      topColor: const Color(0xFF6A5A42),
    );
    final lit = armillarySeesSky || roofOpen;
    for (var i = 0; i < 12; i++) {
      final a0 = i / 12 * 2 * pi;
      final pane = ellipseSectorPath(
        c.translate(0, -4),
        40,
        32,
        52,
        42,
        a0 + 0.03,
        a0 + 2 * pi / 12 - 0.03,
      );
      paintPane(
        canvas,
        pane,
        lit
            ? Color.lerp(
                _kSandGlass.frostAt(i),
                _kSandGlass.live,
                armillarySeesSky ? 0.8 : 0.35,
              )!
            : _kSandGlass.frostAt(i),
        _kSandGlass,
        lead: 1.4,
      );
    }
    // Light down through the dug roof onto the island.
    if (roofOpen) {
      final top = Offset(c.dx, room.bounds.top);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx - 60, top.dy)
          ..lineTo(top.dx + 60, top.dy)
          ..lineTo(c.dx + 90, c.dy + 30)
          ..lineTo(c.dx - 90, c.dy + 30)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFD8E8FF).withValues(alpha: 0.22),
              const Color(0xFFD8E8FF).withValues(alpha: 0.05),
            ],
          ).createShader(Rect.fromPoints(top, c.translate(0, 30))),
      );
    }
  }

  /// The armillary: a pillar, and three brass rings — meridian upright, the
  /// others hung in it and turning while it reads the sky — the ecliptic
  /// band in zodiac glass, and a gilt sun running round it.
  void _drawArmillary(
    Canvas canvas,
    Offset c, {
    required bool open,
    required bool won,
  }) {
    final live = open || won;
    const brass = Color(0xFFC89A48), dark = Color(0xFF5A4A34);
    final metal = live ? brass : dark;
    // The pillar and its foot.
    paintCarvedDisc(canvas, c.translate(0, 34), 22, 10, 6, _kSandGlass);
    canvas.drawRect(
      Rect.fromCenter(center: c.translate(0, 18), width: 10, height: 34),
      Paint()..color = live ? const Color(0xFF8A6A34) : const Color(0xFF4A3C28),
    );
    final spin = open ? _time * 0.6 : (won ? 0.9 : 0.0);
    void ringPath(double w, double h, double tilt, double stroke, Color col) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(tilt);
      final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + 2
          ..color = const Color(0xFF1A120A),
      );
      canvas.drawOval(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = col,
      );
      canvas.drawArc(
        r,
        pi * 1.1,
        pi * 0.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.4
          ..color = Colors.white.withValues(alpha: live ? 0.55 : 0.15),
      );
      canvas.restore();
    }

    // Meridian (upright), equator (turning), ecliptic (tilted, turning).
    ringPath(92, 92, 0, 3.4, metal);
    ringPath(92, 30 + 20 * cos(spin).abs(), 0, 2.6, metal);
    ringPath(92, 26 + 18 * sin(spin).abs(), 0.42, 4, metal);
    // The ecliptic's zodiac glass: small panes along the tilted band.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.42);
    final eh = 26 + 18 * sin(spin).abs();
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * 2 * pi;
      final p = Offset(cos(a) * 46, sin(a) * eh / 2);
      canvas.drawCircle(
        p,
        2.6,
        Paint()
          ..color = live
              ? _kSandGlass.live.withValues(alpha: 0.9)
              : _kSandGlass.frostAt(i),
      );
    }
    canvas.restore();
    // The polar axis and the gilt sun.
    canvas.drawLine(
      c + const Offset(-12, -52),
      c + const Offset(12, 52),
      Paint()
        ..strokeWidth = 2.4
        ..color = metal,
    );
    if (live) {
      final t = open ? _time * 0.8 : 0.9;
      final e = Offset(cos(t) * 46, sin(t) * 12);
      final sun =
          c +
          Offset(
            e.dx * cos(0.42) - e.dy * sin(0.42),
            e.dx * sin(0.42) + e.dy * cos(0.42),
          );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          sun,
          16,
          const Color(0xFFFFD27A).withValues(alpha: 0.6),
        );
      }
      canvas.drawCircle(sun, 4.5, Paint()..color = const Color(0xFFFFF0C0));
    }
  }

  /// THE STAR, FORMING. Motes gather in from the roof and the tube, spin in,
  /// and the star takes shape over the instrument; then it hangs there,
  /// turning, with a slow beacon ring — so the Wing knows to fly in.
  void _drawObservatoryStar(Canvas canvas, Offset rings, {required bool won}) {
    final o = _obsStar.clamp(0.0, 1.0);
    if (o <= 0 || won) return;
    final c = rings + kArmillaryStarLift + Offset(0, sin(_time * 1.6) * 4);
    const gold = Color(0xFFFFD27A);
    // Motes gathering in.
    if (o < 1) {
      for (var i = 0; i < 18; i++) {
        final a = i / 18 * 2 * pi + _time * 2;
        final r = 120 * (1 - o) + 8;
        canvas.drawCircle(
          c + Offset(cos(a), sin(a)) * r,
          2.2,
          Paint()..color = gold.withValues(alpha: 0.8 * o),
        );
      }
    }
    final form = Curves.easeOutBack.transform(
      ((o - 0.4) / 0.6).clamp(0.0, 1.0),
    );
    if (form <= 0) return;
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, c, 90 * form, gold.withValues(alpha: 0.55));
    }
    // The beacon: a ring swelling out and fading, over and over.
    final beat = (_time * 0.7) % 1.0;
    canvas.drawCircle(
      c,
      30 + 80 * beat,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - beat)
        ..color = gold.withValues(alpha: 0.6 * (1 - beat) * form),
    );
    // A thread of light down to the instrument, so the two read as one.
    canvas.drawLine(
      c,
      rings,
      Paint()
        ..strokeWidth = 1.4
        ..color = gold.withValues(alpha: 0.35 * form),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_time * 0.8);
    canvas.scale(form);
    _drawStarGlyph(canvas, Offset.zero, 28, gold);
    _drawStarGlyph(canvas, Offset.zero, 15, const Color(0xFFFFF6DC));
    canvas.restore();
  }
}

/// One spadeful in flight: which squares, what the landing square was
/// before, where it flies from and to (or the doorway it leaves by), and how
/// long it has been in the air.
class _DustThrow {
  _DustThrow({
    required this.fromId,
    required this.toId,
    required this.toWas,
    required this.from,
    required this.to,
    required this.door,
  });

  final String fromId;
  final String toId;
  final MoundState toWas;
  final Offset from;
  final Offset? to;
  final Offset door;
  double t = 0;
  bool cut = false;
}
