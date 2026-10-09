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
  /// the one thing here the spade will not bite. Its sand is grains now
  /// (2026-10-08), over the same silhouette: it was a flat pale shape with a
  /// white stroke for a crest.
  void _drawDriftedDune(Canvas canvas, Rect r, _MoundGeometry geo) {
    canvas.save();
    canvas.translate(22, 14);
    canvas.drawPath(
      geo.dune,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.restore();
    canvas.drawPath(geo.dune, Paint()..color = const Color(0xFFB2A386));
    canvas.drawPath(
      geo.duneLee,
      Paint()..color = const Color(0xFF5E4E36).withValues(alpha: 0.9),
    );
    _drawDuneGrains(canvas, r, geo);
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

  /// THE SPADEFUL, in grains (2026-10-08 — it was a few dozen dots and an
  /// expanding ring where it landed). Spoil sprays up off the dig and falls
  /// back; the stream arcs over, each grain a short streak; and where it
  /// lands the sand slides out round the foot of the rising heap.
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
    // Spoil kicked up off the dig: thrown up, falling back, going out.
    for (var i = 0; i < 40; i++) {
      final r0 = _dustHash(i * 7 + 1), r1 = _dustHash(i * 13 + 2);
      final a = -pi / 2 + (r0 - 0.5) * 2.2;
      final v = 55 + r1 * 75;
      final s = th.t - r1 * 0.08;
      final life = 0.42 + r0 * 0.3;
      if (s <= 0 || s > life) continue;
      Offset at(double s) =>
          from + Offset(cos(a) * v * s, sin(a) * v * s + 210 * s * s);
      _dustInk.add(at(max(0.0, s - 0.035)), at(s), sand, 0.85 * (1 - s / life));
    }
    // The stream: seventy grains, each leaving a beat after the last, fanned
    // a little either side of the arc and tightening as they fly.
    final tp = (th.t - 0.012) / dur;
    for (var i = 0; i < 70; i++) {
      double uAt(double tt) => ((tt - 0.1 - i * 0.0055) / 0.62).clamp(0.0, 1.0);
      final u = uAt(t);
      if (u <= 0 || u >= 1) continue;
      final jitter = Offset(sin(i * 2.3) * 8, cos(i * 1.7) * 7);
      final q = along(u) + jitter * (1 - 0.5 * u);
      final up = uAt(tp);
      final q0 = along(up) + jitter * (1 - 0.5 * up);
      _dustInk.add(q0, q, sand, 0.9);
    }
    // …and it keeps coming, thinner, until the doorway it chokes is full —
    // the whole trade is one motion, never a pause and then a door.
    if (th.to != null && t > 0.55) {
      final taper = 1 - _throwChoke(th);
      final fadeIn = ((t - 0.55) / 0.2).clamp(0.0, 1.0);
      for (var i = 0; i < 30; i++) {
        final side = Offset(sin(i * 3.1) * 6, cos(i * 2.2) * 5);
        final u = (th.t * 0.85 + i / 30) % 1.0;
        final u0 = ((th.t - 0.012) * 0.85 + i / 30) % 1.0;
        if (u0 > u) continue;
        _dustInk.add(
          along(u0) + side,
          along(u) + side,
          sand,
          0.8 * fadeIn * taper,
        );
      }
    }
    // Landing in this room: the sand slides out round the foot of the heap
    // as it rises, and settles.
    if (th.to != null) {
      final land = _throwRise(th);
      if (land > 0 && land < 1) {
        final k = Curves.easeOut.transform(land);
        final k0 = Curves.easeOut.transform(max(0.0, land - 0.03));
        for (var i = 0; i < 34; i++) {
          final a = _dustHash(i * 5 + 3) * 2 * pi;
          final reach = 36 + 58 * _dustHash(i * 9 + 4);
          Offset at(double k) =>
              to + Offset(cos(a) * reach * k, sin(a) * reach * 0.42 * k + 12);
          _dustInk.add(at(k0), at(k), sand, 0.7 * (1 - land));
        }
      }
    }
    _dustInk.paint(canvas, width: 1.7);
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
    final inward = (target - entry) / (target - entry).distance;
    final across = Offset(-inward.dy, inward.dx);
    // The spill at the doorway: a fan of grains sliding in and settling.
    final spill =
        (a / 0.12).clamp(0.0, 1.0) * (1 - ((a - 0.35) / 0.15).clamp(0.0, 1.0));
    if (spill > 0) {
      for (var i = 0; i < 36; i++) {
        final r0 = _dustHash(i * 3 + 8), r1 = _dustHash(i * 17 + 6);
        final u = (th.t * (0.5 + r1 * 0.4) + r0) % 1.0;
        final u0 = ((th.t - 0.02) * (0.5 + r1 * 0.4) + r0) % 1.0;
        if (u0 > u) continue;
        Offset at(double u) =>
            entry + across * ((r0 - 0.5) * 60 * (0.4 + u)) + inward * (50 * u);
        _dustInk.add(at(u0), at(u), sand, 0.8 * spill * (1 - u));
      }
    }
    // The stream across the floor to the square: grains skittering along a
    // shallow wave, many at once, thinning as the heap takes them.
    // ONE CONTINUOUS FLOW: the leading edge runs in, then the stream keeps
    // coming — thinning, never stopping dead — until the doorway is full.
    final lead = (a / 0.3).clamp(0.0, 1.0);
    final taper = 1 - _throwChoke(th);
    final dir = target - entry;
    final side = Offset(-dir.dy, dir.dx) / dir.distance;
    for (var i = 0; i < 90; i++) {
      double uAt(double tt) => (tt * 0.9 + i / 90) % 1.0;
      final u = uAt(th.t), u0 = uAt(th.t - 0.015);
      if (u > lead || u0 > u) continue;
      final alpha = (0.35 + 0.65 * taper) * (i % 3 == 0 || taper > 0.5 ? 1 : 0);
      if (alpha <= 0.02) continue;
      Offset at(double u) =>
          Offset.lerp(entry, target, u)! + side * (sin(u * 9 + i * 1.3) * 10);
      _dustInk.add(at(u0), at(u), sand, alpha * 0.9);
    }
    _dustInk.paint(canvas, width: 1.7);
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
    // Set in a dark stone stele standing at the back of the pit — not a tile
    // floating over it (2026-10-08: the five plates read as a row of UI
    // buttons). The glass, its mark and its state are as they were.
    canvas.drawPicture(
      _dustStill('plateStele|${plate.left.round()}|${plate.top.round()}', (c) {
        final stele = Rect.fromLTRB(
          plate.left - 5,
          plate.top - 7,
          plate.right + 5,
          plate.bottom + 3,
        );
        _dustCarve(
          c,
          Path()..addRRect(
            RRect.fromRectAndCorners(
              stele,
              topLeft: const Radius.circular(9),
              topRight: const Radius.circular(9),
              bottomLeft: const Radius.circular(2),
              bottomRight: const Radius.circular(2),
            ),
          ),
          under: true,
          rim: 0.45,
        );
      }),
    );
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
      // The stone: a worn stepping-stone set in the street, dark, the moon
      // on its near arris — not a rounded tile (2026-10-08: the stones and
      // their gold rings read as a row of UI buttons). Lit underfoot.
      canvas.drawPicture(
        _dustStill(
          'stepStone|${tile.left.round()}|${tile.top.round()}|$lit',
          (c) => _drawStepStone(
            c,
            tile.deflate(2),
            lit,
            (tile.left * 7 + tile.top * 3).round(),
          ),
        ),
      );
      // The way the sand will go, as a sliver of glass at the stone's outer
      // edge: frosted while it can, lit underfoot, smoked when full.
      final tip = tile.center + u * (kMoundChoiceTile / 2 - 4);
      final side = Offset(-u.dy, u.dx);
      paintPane(
        canvas,
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((tip - u * 7 + side * 5).dx, (tip - u * 7 + side * 5).dy)
          ..lineTo((tip - u * 7 - side * 5).dx, (tip - u * 7 - side * 5).dy)
          ..close(),
        lit && open
            ? _kSandGlass.live
            : open
            ? const Color(0xFF8A7A5C)
            : _kSandGlass.smoke,
        _kSandGlass,
        lead: 1.4,
      );
      // The destination's mark, in a glass boss.
      final c = tile.center - u * 2;
      paintRondel(
        canvas,
        c,
        11,
        _kSandGlass,
        fill: lit && open
            ? _kSandGlass.live
            : open
            ? _kSandGlass.frostAt(to.glyph)
            : _kSandGlass.smoke,
        rim: lit ? 1 : (open ? 0.5 : 0.2),
        lead: 2.4,
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
        // A little sand sliding off it as it settles — grains, not a ring
        // (2026-10-08).
        if (t > 0.6 && t < 1) {
          final f = (t - 0.6) / 0.4;
          final f0 = max(0.0, f - 0.08);
          for (var g = 0; g < 5; g++) {
            final a = (g / 5 + _dustHash(i * 5 + g) * 0.2) * 2 * pi;
            Offset at(double f) =>
                home +
                Offset(cos(a), sin(a) * 0.6) * (tile * 0.45 + 9 * f) +
                Offset(0, 6 * f * f);
            _dustInk.add(at(f0), at(f), sand, 0.7 * (1 - f));
          }
        }
      }
    }
    _dustInk.paint(canvas, width: 1.6);
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
    // In grains, each a short streak running for the doorway (2026-10-08).
    for (var i = 0; i < 54; i++) {
      double uAt(double t) => (t * 0.75 + i / 54) % 1.0;
      final u = uAt(_time), u0 = uAt(_time - 0.015);
      if (u0 > u) continue;
      Offset at(double u) =>
          Offset.lerp(heap, end, u)! +
          side * (sin(u * 7 + i * 2.1) * 9 + (i % 3 - 1) * 5);
      _dustInk.add(at(u0), at(u), RuinsOfTimeDungeon._kDustMoon, 0.85 * alpha);
    }
    _dustInk.paint(canvas, width: 1.7);
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
    // Dust drifting up out of the shaft — grains, wandering as they rise
    // (2026-10-08: fourteen dots). The clip keeps them in the cut.
    final motes = _dustGrainCache.putIfAbsent(
      'shaftDust|${outer.width.round()}x${outer.height.round()}',
      () {
        final rng = Random(51);
        final pts = <Offset>[];
        final sh = <double>[];
        for (var i = 0; i < 300; i++) {
          pts.add(
            Offset(
              (rng.nextDouble() - 0.5) * outer.width,
              (rng.nextDouble() - 0.5) * outer.height,
            ),
          );
          sh.add(0.2 + rng.nextDouble() * 0.7);
        }
        return GrainShape.points(pts, sh, seed: 51);
      },
    );
    paintGrainShape(
      canvas,
      motes,
      _time,
      origin: outer.center,
      drift: 4,
      alpha: 0.45,
      fall: outer.height,
      fallSpeed: -6,
      ramp: _kDustGrainRamp,
      glint: 0.01,
      width: 1.4,
      trail: 0.06,
    );
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
    // Motes gathering in — grains spiralling in from the roof and the tube
    // on trails (2026-10-08: eighteen dots on a shrinking circle).
    if (o < 1) {
      for (var i = 0; i < 90; i++) {
        final r0 = _dustHash(i * 7 + 2), r1 = _dustHash(i * 3 + 9);
        Offset at(double t, double oo) {
          final a = r0 * 2 * pi + t * (1.6 + r1);
          final r = (130 + r1 * 50) * (1 - oo) + 8 + r1 * 10;
          return c + Offset(cos(a), sin(a) * 0.8) * r;
        }

        _dustInk.add(
          at(_time - 0.05, o),
          at(_time, o),
          r1 < 0.2 ? const Color(0xFFFFF6DC) : gold,
          0.75 * min(1.0, o * 3),
        );
      }
      _dustInk.paint(canvas, width: 1.6);
    }
    final form = Curves.easeOutBack.transform(
      ((o - 0.4) / 0.6).clamp(0.0, 1.0),
    );
    if (form <= 0) return;
    if (_fx.ready) {
      drawGlow(canvas, _fx.glow!, c, 90 * form, gold.withValues(alpha: 0.55));
    }
    // The beacon: a slow halo of gold grains turning round it and breathing
    // — so the Wing knows to fly in (it was a ring swelling out and fading,
    // over and over: a shock ring).
    final halo = _dustGrainCache.putIfAbsent('starHalo', () {
      final rng = Random(33);
      final pts = <Offset>[];
      final sh = <double>[];
      while (pts.length < 240) {
        final a = rng.nextDouble() * 2 * pi;
        if (rng.nextDouble() > 0.35 + 0.65 * (0.5 + 0.5 * cos(3 * a))) {
          continue;
        }
        final r = 36 + rng.nextDouble() * 16;
        pts.add(Offset(cos(a), sin(a)) * r);
        sh.add(0.4 + 0.6 * rng.nextDouble());
      }
      return GrainShape.points(pts, sh, seed: 33);
    });
    paintGrainShape(
      canvas,
      halo,
      _time,
      origin: c,
      scale: form * (1 + 0.07 * sin(_time * 1.4)),
      rotation: _time * 0.9,
      spin: 0.9,
      drift: 1.2,
      alpha: 0.85 * form.clamp(0.0, 1.0),
      ramp: grainRampFrom(gold),
      glint: 0.02,
      width: 1.6,
      trail: 0.05,
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

// ── Sablis's props, drawn (2026-10-08; the kit is at the end of the file) ──

/// Unlit granary grain: old, dry, pale — the grain the old drawing filled
/// its heaps with, a shade dimmer.
const List<Color> _kDustDullRamp = [
  Color(0xFF6A5634),
  Color(0xFFA88E5E),
  Color(0xFFD6C08E),
  Color(0xFFF0E4C4),
];

/// Ochre drift: the gate's silt and a single load's low mound.
const List<Color> _kDustOchreRamp = [
  Color(0xFF6A5028),
  Color(0xFFA8874E),
  Color(0xFFD9BC80),
  Color(0xFFF4E6C4),
];

extension SablisProps on PlanetDungeonGame {
  // ── Stones and marks ────────────────────────────────────

  /// A worn stepping-stone set into the street: an uneven slab, dark, the
  /// moon on its near arris; lighter while it is underfoot.
  void _drawStepStone(Canvas canvas, Rect r, bool lit, int seed) {
    double j(int k) => (_dustHash(seed * 7 + k) - 0.5) * 6;
    final pts = [
      r.topLeft + Offset(3 + j(0), 1 + j(1)),
      r.topRight + Offset(-2 + j(2), 3 + j(3)),
      r.bottomRight + Offset(-3 + j(4), j(5)),
      r.bottomLeft + Offset(2 + j(6), -2 + j(7)),
    ];
    // Corners rounded off by a thousand years of feet.
    final top = Path();
    for (var i = 0; i < 4; i++) {
      final a = pts[i], b = pts[(i + 1) % 4];
      final m0 = Offset.lerp(pts[(i + 3) % 4], a, 0.78)!;
      final m1 = Offset.lerp(a, b, 0.22)!;
      i == 0 ? top.moveTo(m0.dx, m0.dy) : top.lineTo(m0.dx, m0.dy);
      top.quadraticBezierTo(a.dx, a.dy, m1.dx, m1.dy);
    }
    top.close();
    paintContactShadow(
      canvas,
      r.center.translate(2, r.height * 0.5 + 5),
      r.width * 1.15,
      10,
      opacity: 0.45,
    );
    canvas.drawPath(
      top.shift(const Offset(0, 3)),
      Paint()..color = _kDustSilFoot,
    );
    _dustCarve(
      canvas,
      top,
      under: false,
      rim: lit ? 0.7 : 0.42,
      top: lit ? const Color(0xFF5E4C34) : const Color(0xFF30261A),
      foot: lit ? const Color(0xFF4A3B28) : const Color(0xFF221A12),
    );
    canvas.drawLine(
      Offset.lerp(pts[3], pts[2], 0.12)!,
      Offset.lerp(pts[3], pts[2], 0.88)!,
      Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = _kDustMoonRim.withValues(alpha: lit ? 0.55 : 0.28),
    );
  }

  /// A MARK CUT INTO STONE — for a mark that only names something and has
  /// no state of its own (the sighting tube's tag naming the kiln square):
  /// a small dark tablet with the mark incised, the light caught on the
  /// lip of the cut.
  void _drawCarvedMark(Canvas canvas, Offset at, int glyph) {
    final tab = Rect.fromCenter(center: at, width: 24, height: 20);
    paintContactShadow(canvas, tab.bottomCenter.translate(2, 3), 28, 7);
    paintCarvedBlock(
      canvas,
      tab,
      4,
      _kSandGlass,
      radius: 3,
      topColor: const Color(0xFF55452F),
    );
    _drawSurveyGlyph(canvas, at, 5.5, glyph, const Color(0xFF120C06));
    _drawSurveyGlyph(
      canvas,
      at.translate(0, 1.1),
      5.5,
      glyph,
      _kDustMoonRim.withValues(alpha: 0.32),
    );
    _drawSurveyGlyph(canvas, at, 5.5, glyph, const Color(0xFF1A120A));
  }

  // ── The survey yard's loads ─────────────────────────────

  /// A one-load mound and a two-load dune, on a cell centred at [o]: the
  /// same two silhouettes the yard has always used.
  ({Rect mound, Path dune, Path lee, Path crest}) _yardLoadPaths(
    Offset o,
    double cell,
  ) {
    final mound = Rect.fromCenter(
      center: o.translate(0, 4),
      width: cell * 0.66,
      height: cell * 0.40,
    );
    final foot = Rect.fromCenter(
      center: o.translate(0, 10),
      width: cell * 0.78,
      height: cell * 0.44,
    );
    final dune = Path()
      ..moveTo(foot.left, foot.center.dy)
      ..quadraticBezierTo(
        o.dx - 14,
        o.dy - cell * 0.46,
        o.dx + 6,
        o.dy - cell * 0.30,
      )
      ..quadraticBezierTo(foot.right - 6, o.dy - 4, foot.right, foot.center.dy)
      ..arcTo(foot, 0, pi, false)
      ..close();
    final lee = Path()
      ..moveTo(o.dx + 6, o.dy - cell * 0.30)
      ..quadraticBezierTo(foot.right - 6, o.dy - 4, foot.right, foot.center.dy)
      ..lineTo(o.dx + 10, foot.bottom - 4)
      ..close();
    final crest = Path()
      ..moveTo(foot.left + 6, foot.center.dy - 4)
      ..quadraticBezierTo(
        o.dx - 14,
        o.dy - cell * 0.46,
        o.dx + 6,
        o.dy - cell * 0.30,
      );
    return (mound: mound, dune: dune, lee: lee, crest: crest);
  }

  /// A cell's sand under its grains: its shadow and its body.
  void _drawYardLoadBody(Canvas canvas, Offset o, double cell, int loads) {
    if (loads <= 0) return;
    final p = _yardLoadPaths(o, cell);
    if (loads == 1) {
      canvas.drawOval(
        p.mound.shift(const Offset(0, 4)),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      canvas.drawOval(p.mound, Paint()..color = const Color(0xFF8A6E46));
      return;
    }
    canvas.drawPath(
      p.dune.shift(const Offset(12, 8)),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    canvas.drawPath(p.dune, Paint()..color = const Color(0xFFB2A386));
    canvas.drawPath(p.lee, Paint()..color = const Color(0xFF66563C));
  }

  /// The whole yard's sand as three shapes of grains — the low mounds, the
  /// dunes, and the dunes' crests in heavier grains — rebuilt only when a
  /// load moves: a low mound is a dull ochre spread, a dune is bright on its
  /// windward face, dim in its lee and hard along its crest. ≤ ~3,400
  /// grains, three draws.
  void _drawYardSand(Canvas canvas, DriftField f) {
    final loads = [for (var i = 0; i < f.cols * f.rows; i++) ruins.driftAt(i)];
    final key = loads.join();
    if (_dustYardShapes == null || _dustYardKey != key) {
      final low = <Offset>[], lowSh = <double>[];
      final high = <Offset>[], highSh = <double>[];
      final crest = <Offset>[], crestSh = <double>[];
      final rng = Random(17);
      for (var r = 0; r < f.rows; r++) {
        for (var c = 0; c < f.cols; c++) {
          final n = loads[r * f.cols + c];
          if (n <= 0 || f.isPillar(c, r)) continue;
          final p = _yardLoadPaths(f.rectAt(c, r).center, f.cell);
          if (n == 1) {
            final m = p.mound;
            var made = 0;
            while (made < 140) {
              final q = Offset(
                m.left + rng.nextDouble() * m.width,
                m.top + rng.nextDouble() * m.height,
              );
              final d = Offset(
                (q.dx - m.center.dx) / (m.width / 2),
                (q.dy - m.center.dy) / (m.height / 2),
              );
              if (d.dx * d.dx + d.dy * d.dy > 1) continue;
              low.add(q);
              lowSh.add(0.3 + 0.35 * (1 - (q.dy - m.top) / m.height));
              made++;
            }
            for (final (q, s) in _dustLineGrains(
              Path()..addArc(m.deflate(4), pi * 1.15, pi * 0.7),
              1.8,
              0.85,
              jitter: 0.5,
              seed: r * 9 + c,
            )) {
              low.add(q);
              lowSh.add(s);
            }
          } else {
            final box = p.dune.getBounds();
            var made = 0;
            while (made < 250) {
              final q = Offset(
                box.left + rng.nextDouble() * box.width,
                box.top + rng.nextDouble() * box.height,
              );
              if (!p.dune.contains(q)) continue;
              final up = 1 - (q.dy - box.top) / box.height;
              high.add(q);
              highSh.add(p.lee.contains(q) ? 0.2 + 0.1 * up : 0.5 + 0.36 * up);
              made++;
            }
            for (final (q, s) in _dustLineGrains(
              p.crest,
              1.4,
              1.0,
              jitter: 0.4,
              seed: r * 9 + c,
            )) {
              crest.add(q);
              crestSh.add(s);
            }
          }
        }
      }
      _dustYardShapes = (
        GrainShape.points(low, lowSh, seed: 19),
        GrainShape.points(high, highSh, seed: 23),
        GrainShape.points(crest, crestSh, seed: 29),
      );
      _dustYardKey = key;
    }
    final (low, high, crest) = _dustYardShapes!;
    paintGrainShape(
      canvas,
      low,
      _time,
      drift: 0.45,
      ramp: _kDustOchreRamp,
      glint: 0.004,
      width: 1.6,
      trail: 0.035,
    );
    paintGrainShape(
      canvas,
      high,
      _time,
      drift: 0.45,
      ramp: _kDustGrainRamp,
      glint: 0.006,
      width: 1.6,
      trail: 0.035,
    );
    paintGrainShape(
      canvas,
      crest,
      _time,
      drift: 0.3,
      ramp: _kDustGrainRamp,
      glint: 0.01,
      width: 2.2,
      trail: 0.035,
    );
  }

  // ── The mounds' dunes ───────────────────────────────────

  /// A drifted mound's dune in grains, over its own silhouette: bright and
  /// combed on the windward face, dim in the lee, the crest a hard line of
  /// lit grains. ~1,050 grains, built once per mound.
  void _drawDuneGrains(Canvas canvas, Rect r, _MoundGeometry geo) {
    final key = 'dune|${r.center.dx.round()}|${r.center.dy.round()}';
    final shape = _dustGrainCache.putIfAbsent(key, () {
      final ripples = Path();
      for (final w in geo.duneRipples) {
        ripples.addPath(w, Offset.zero);
      }
      final box = geo.dune.getBounds();
      return _dustRegionGrains(
        box,
        geo.dune.contains,
        (p) {
          final high = 1 - (p.dy - box.top) / box.height;
          return geo.duneLee.contains(p) ? 0.2 + 0.1 * high : 0.5 + 0.38 * high;
        },
        950,
        seed: (r.center.dx + r.center.dy).round(),
        extra: _dustLineGrains(ripples, 2.2, 0.3, jitter: 0.6, seed: 4),
      );
    });
    // The crest on its own, in heavier grains: a dune's hard edge is the
    // thing that says DUNE from across the room.
    final crest = _dustGrainCache.putIfAbsent('$key|crest', () {
      final pts = _dustLineGrains(geo.crest, 1.4, 1.0, jitter: 0.5, seed: 3);
      return GrainShape.points(
        [for (final (p, _) in pts) p],
        [for (final (_, s) in pts) s],
        seed: 5,
      );
    });
    paintGrainShape(
      canvas,
      shape,
      _time,
      drift: 0.5,
      ramp: _kDustGrainRamp,
      glint: 0.006,
      width: 1.6,
      trail: 0.035,
    );
    paintGrainShape(
      canvas,
      crest,
      _time,
      drift: 0.35,
      ramp: _kDustGrainRamp,
      glint: 0.01,
      width: 2.2,
      trail: 0.035,
    );
  }

  // ── The silt in the gate ────────────────────────────────

  /// THE SILT IN THE ARCH, as a drift of grains: deep against the gate,
  /// sloping back into the room, combed by the wind into crests. ~1,300
  /// grains, churning in place.
  void _drawGateSilt(Canvas canvas, Offset silt) {
    final body = Path()
      ..moveTo(48, -95)
      ..lineTo(48, 95)
      ..lineTo(-62, 105)
      ..quadraticBezierTo(-38, 0, -44, -101)
      ..close();
    final shape = _dustGrainCache.putIfAbsent('gateSilt', () {
      final crests = Path();
      for (var i = 0; i < 5; i++) {
        crests
          ..moveTo(-38 - i * 2.0, -81.0 + i * 34)
          ..quadraticBezierTo(0, -89.0 + i * 34, 44, -77.0 + i * 34);
      }
      return _dustRegionGrains(
        body.getBounds(),
        body.contains,
        // The slope facing the room is lit; the deep sand against the arch
        // is in the arch's shadow.
        (p) => 0.35 + 0.4 * ((48 - p.dx) / 110).clamp(0.0, 1.0),
        1150,
        seed: 71,
        extra: _dustLineGrains(crests, 1.5, 0.95, jitter: 0.7, seed: 72),
      );
    });
    canvas.save();
    canvas.translate(silt.dx, silt.dy);
    canvas.drawPath(
      body,
      Paint()..color = const Color(0xFF9C7E50).withValues(alpha: 0.85),
    );
    canvas.restore();
    paintGrainShape(
      canvas,
      shape,
      _time,
      origin: silt,
      drift: 0.6,
      ramp: _kDustOchreRamp,
      glint: 0.006,
      width: 1.6,
      trail: 0.035,
    );
  }

  // ── The wind vanes ──────────────────────────────────────

  /// A vane's mast: dark iron on a cut-stone footing, the deck's light down
  /// one side. Still, so it is baked; the blade is drawn live over it.
  void _drawVaneMast(Canvas c, Offset vane, {required bool under}) {
    paintCarvedDisc(
      c,
      vane + const Offset(0, 34),
      17,
      7,
      5,
      _kSandGlass,
      topColor: const Color(0xFF3A2E20),
    );
    _dustCarve(
      c,
      Path()..addPolygon([
        vane + const Offset(-2.8, 35),
        vane + const Offset(2.8, 35),
        vane + const Offset(1.6, -26),
        vane + const Offset(-1.6, -26),
      ], true),
      under: under,
      light: const Offset(1.3, 0),
      rim: 0.55,
    );
    _dustCarve(
      c,
      Path()
        ..addOval(Rect.fromCircle(center: vane.translate(0, -26), radius: 3.2)),
      under: under,
      light: const Offset(0.8, 1),
      rim: 0.6,
    );
  }

  /// A wound vane's wind: grains turning fast round the hub in a flattened
  /// ring, three thicker arcs so the turning shows. ~110 grains, live only
  /// while it is armed.
  void _drawVaneWind(Canvas canvas, Offset hub) {
    final breathe = 0.75 + 0.25 * sin(_time * 3);
    for (var j = 0; j < 110; j++) {
      final r0 = _dustHash(j * 11 + 1), r1 = _dustHash(j * 7 + 5);
      // Bunched into three arcs.
      final a0 = (j % 3) * 2 * pi / 3 + (r0 - 0.5) * 1.6;
      final rad = 24 + r1 * 13;
      final w = 4.2 + (1 - r1) * 1.6;
      Offset where(double t) {
        final a = a0 + t * w;
        return hub + Offset(cos(a) * rad, sin(a) * rad * 0.38 + (r0 - 0.5) * 4);
      }

      final q = where(_time), q0 = where(_time - 0.04);
      _dustInk.add(
        q0,
        q,
        r0 < 0.15 ? Colors.white : const Color(0xFFE6DFCB),
        (0.35 + 0.4 * (1 - (r0 - 0.5).abs() * 2)) * breathe,
      );
    }
    _dustInk.paint(canvas, width: 1.5);
  }

  // ── The great glass ─────────────────────────────────────

  /// The glass's frame: dark stone end-plates and iron posts, lit at the
  /// rim. Baked.
  void _drawGreatGlassFrame(Canvas c, Offset glass) {
    for (final x in [-33.0, 33.0]) {
      _dustCarve(
        c,
        Path()..addRect(
          Rect.fromCenter(center: glass.translate(x, 0), width: 7, height: 86),
        ),
        under: false,
        light: const Offset(1.4, 0),
        rim: 0.5,
      );
    }
    for (final y in [-42.0, 42.0]) {
      paintCarvedBlock(
        c,
        Rect.fromCenter(
          center: glass.translate(0, y - 2),
          width: 76,
          height: 7,
        ),
        5,
        _kSandGlass,
        radius: 2,
        topColor: const Color(0xFF3E3123),
      );
    }
  }

  /// The glass's sand, in grains: a heap in the bottom bulb, still; once it
  /// is turned, warm in the glass's light and RUNNING — a thread of grains
  /// falling through the neck onto the heap.
  void _drawGlassSand(Canvas canvas, Offset glass, bool turned) {
    final heapPath = Path()
      ..moveTo(-19, 34)
      ..lineTo(19, 34)
      ..lineTo(0, 8)
      ..close();
    final shape = _dustGrainCache.putIfAbsent(
      'glassSand',
      () => _dustRegionGrains(
        heapPath.getBounds(),
        heapPath.contains,
        (p) => 0.35 + 0.55 * (1 - (p.dy - 8) / 26),
        230,
        seed: 81,
        extra: _dustLineGrains(
          Path()
            ..moveTo(-17, 32)
            ..lineTo(0, 9)
            ..lineTo(17, 32),
          1.5,
          0.9,
          jitter: 0.4,
          seed: 82,
        ),
      ),
    );
    canvas.save();
    canvas.translate(glass.dx, glass.dy);
    canvas.drawPath(
      heapPath,
      Paint()
        ..color = (turned ? const Color(0xFF9A6A2A) : const Color(0xFF7A6240))
            .withValues(alpha: 0.75),
    );
    canvas.restore();
    paintGrainShape(
      canvas,
      shape,
      _time,
      origin: glass,
      drift: turned ? 0.5 : 0.3,
      ramp: turned ? _kDustWarmRamp : _kDustGrainRamp,
      glint: turned ? 0.015 : 0.004,
      width: 1.5,
      trail: 0.035,
    );
    if (!turned) return;
    for (var j = 0; j < 16; j++) {
      final r0 = _dustHash(j * 19 + 4), r1 = _dustHash(j * 3 + 1);
      Offset where(double t) {
        final u = (t * 1.6 + r0) % 1.0;
        return glass + Offset((r1 - 0.5) * 1.6, -4 + u * u * 14);
      }

      final u = (_time * 1.6 + r0) % 1.0;
      final q = where(_time), q0 = where(_time - 0.035);
      if ((q - q0).distance > 6) continue;
      _dustInk.add(q0, q, _kDustWarmRamp[2], 0.95 * min(1.0, (1 - u) * 4));
    }
    _dustInk.paint(canvas, width: 1.5);
  }

  // ── Ashdjinn's cut ──────────────────────────────────────

  /// One course of sand the storm has shovelled back into the cut: a band of
  /// grains with its top edge lit hard, so the courses count from across
  /// the arena.
  void _drawFillCourse(Canvas canvas, Rect course, int i) {
    final local = Rect.fromLTWH(0, 0, course.width, course.height);
    final shape = _dustGrainCache.putIfAbsent(
      'fillCourse|${course.width.round()}x${course.height.round()}',
      () => _dustRegionGrains(
        local,
        (_) => true,
        (p) => 0.3 + 0.45 * (1 - p.dy / local.height),
        300,
        seed: 91,
        extra: _dustLineGrains(
          Path()
            ..moveTo(1, 0.8)
            ..lineTo(local.width - 1, 0.8),
          1.4,
          1.0,
          jitter: 0.5,
          seed: 92,
        ),
      ),
    );
    canvas.drawRect(
      course,
      Paint()..color = const Color(0xFF7A6646).withValues(alpha: 0.8),
    );
    paintGrainShape(
      canvas,
      shape,
      _time + i * 2.3,
      origin: course.topLeft,
      drift: 0.45,
      ramp: _kDustGrainRamp,
      glint: 0.005,
      width: 1.6,
      trail: 0.035,
    );
  }

  // ── The granary's grain ─────────────────────────────────

  /// A pit's grain, to its count, as grains: a low level for one, a heap
  /// standing over the lip for two. Lit, it is warm and glinting with grains
  /// lifting off it into the dark; unlit it is dull and still.
  void _drawPitGrain(Canvas canvas, Offset at, int count, bool lit, int i) {
    const r = 30.0;
    // Lit, the pit is warm whatever its count — an empty one too.
    if (lit && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        at.translate(0, -6),
        r * 1.9,
        const Color(0xFFFFD27A).withValues(alpha: 0.30),
      );
    }
    if (count <= 0) {
      if (lit) _drawPitMotes(canvas, at, count, i);
      return;
    }
    final (shape, level, heap) = _pitGrain(count);
    // The body of the grain under its grains, so the count reads as a
    // level and a heap from across the room and not as a dusting.
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.drawPath(
      level,
      Paint()
        ..color = (lit ? const Color(0xFF8A5E26) : const Color(0xFF6E5A3A))
            .withValues(alpha: 0.9),
    );
    if (heap != null) {
      // The heap stands up off the level, lighter: its cone is the count.
      canvas.drawPath(
        heap,
        Paint()
          ..color = (lit ? const Color(0xFFC48C3C) : const Color(0xFFA8916A))
              .withValues(alpha: 0.92),
      );
    }
    canvas.restore();
    paintGrainShape(
      canvas,
      shape,
      _time + i * 3.1,
      origin: at,
      drift: 0.45,
      alpha: lit ? 1.0 : 0.8,
      ramp: lit ? _kDustWarmRamp : _kDustDullRamp,
      glint: lit ? 0.02 : 0.003,
      width: 1.6,
      trail: 0.035,
    );
    if (lit) _drawPitMotes(canvas, at, count, i);
  }

  /// Nothing perishes: grains lifting off a lit pit and going out.
  void _drawPitMotes(Canvas canvas, Offset at, int count, int i) {
    const r = 30.0;
    for (var j = 0; j < 12; j++) {
      final r0 = _dustHash(i * 97 + j * 13 + 1), r1 = _dustHash(i * 31 + j);
      Offset where(double t) {
        final u = (t * (0.28 + r1 * 0.12) + r0) % 1.0;
        return at +
            Offset(
              (r1 - 0.5) * 34 * (1 + u * 0.6) + sin(t * 1.2 + j) * 4 * u,
              -r * (count >= 2 ? 0.75 : 0.2) - u * 52,
            );
      }

      final u = (_time * (0.28 + r1 * 0.12) + r0) % 1.0;
      final q = where(_time), q0 = where(_time - 0.05);
      if ((q - q0).distance > 10) continue;
      _dustInk.add(q0, q, const Color(0xFFFFE9A8), 0.75 * sin(u * pi));
    }
    _dustInk.paint(canvas, width: 1.6);
  }

  (GrainShape, Path, Path?) _pitGrain(int count) {
    const r = 30.0;
    final key = 'pit|$count';
    final level = Rect.fromCenter(
      center: Offset(0, count >= 2 ? -2 : 6),
      width: r * (count >= 2 ? 1.9 : 1.45),
      height: r * (count >= 2 ? 1.5 : 0.9),
    );
    final heap = Path()
      ..moveTo(-r * 0.9, 0)
      ..quadraticBezierTo(-r * 0.3, -r * 1.1, r * 0.1, -r * 0.95)
      ..quadraticBezierTo(r * 0.7, -r * 0.7, r * 0.9, 0)
      ..close();
    final levelPath = Path()..addOval(level);
    final heapPath = count >= 2 ? heap : null;
    final cached = _dustGrainCache[key];
    if (cached != null) return (cached, levelPath, heapPath);
    bool inOval(Offset p) {
      final d = Offset(
        (p.dx - level.center.dx) / (level.width / 2),
        (p.dy - level.center.dy) / (level.height / 2),
      );
      return d.dx * d.dx + d.dy * d.dy < 1;
    }

    final GrainShape built;
    if (count < 2) {
      built = _dustRegionGrains(
        level,
        inOval,
        (p) => 0.35 + 0.4 * (1 - (p.dy - level.top) / level.height),
        260,
        seed: 41,
      );
    } else {
      final box = level.expandToInclude(heap.getBounds());
      built = _dustRegionGrains(
        box,
        (p) => inOval(p) || heap.contains(p),
        (p) {
          if (!heap.contains(p)) {
            return 0.22 + 0.16 * (1 - (p.dy - box.top) / box.height);
          }
          // Windward lit, lee in shadow.
          return p.dx < r * 0.1
              ? 0.6 + 0.32 * (-p.dy / r)
              : 0.36 + 0.1 * (-p.dy / r);
        },
        560,
        seed: 43,
        extra: _dustLineGrains(
          Path()
            ..moveTo(-r * 0.62, -r * 0.48)
            ..quadraticBezierTo(-r * 0.3, -r * 1.06, r * 0.1, -r * 0.93),
          1.6,
          1.0,
          jitter: 0.6,
        ),
      );
    }
    _dustGrainCache[key] = built;
    return (built, levelPath, heapPath);
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

// ─────────────────────────────────────────────────────────
// THE PROPS, AGAIN (2026-10-08)
// ─────────────────────────────────────────────────────────
// The rest of the game moved to lit grains on black, and Sablis's furniture
// was still clip-art: rows of round clay pots, a beehive kiln, columns that
// read as coin stacks, a fallen drum like a scroll, a cartoon hourglass
// frame, a brass telescope, sacks, a rake, lamp flames like teardrops. The
// stone, the floors and the light are untouched; the props follow three
// rules now:
//
//   · SAND IS GRAINS. Every heap, spill, throw and running glass is lit
//     grains in motion (grain_cloud.dart) — Dust's own essence form is a
//     heap of them.
//   · SOLID THINGS ARE DARK CARVED SILHOUETTES in the city's stone, fewer of
//     them, lit only at the rim by the deck's light: moon on the streets,
//     lamp below them. No glossy fills, no outlines.
//   · ANYTHING YOU READ OR ACT ON keeps its signal in leaded glass (§7.11);
//     a mark that only names something is cut into the stone.
//
// COST. Every still prop is baked once into a Picture per room; the grain
// shapes are built once and cached; the only per-frame grains are the ones
// that move (heaps churning in place, a throw, a flame, a running glass).

/// Moon sand: shadow, body, lit, glint (the Dust essence ramp, a little
/// warmer for Sablis's night).
const List<Color> _kDustGrainRamp = [
  Color(0xFF4E3F2C),
  Color(0xFF9C8A6C),
  Color(0xFFD8C8A6),
  Color(0xFFF6EEDC),
];

/// The same sand in lamplight — a lit granary pit, a running glass.
const List<Color> _kDustWarmRamp = [
  Color(0xFF6A4418),
  Color(0xFFC08A3A),
  Color(0xFFF0C878),
  Color(0xFFFFF4D8),
];

/// A dark carved silhouette's body: its lit top and its foot.
const Color _kDustSilTop = Color(0xFF2A2117);
const Color _kDustSilFoot = Color(0xFF0B0805);

/// The rim light a silhouette catches: moon on the streets, lamp below.
const Color _kDustMoonRim = Color(0xFFCFC3A4);
const Color _kDustLampRim = Color(0xFFD09A52);

Color _dustRim(bool under) => under ? _kDustLampRim : _kDustMoonRim;

final Map<String, ui.Picture> _dustStillCache = {};
final Map<String, GrainShape> _dustGrainCache = {};

/// The survey yard's sand — its low mounds and its dunes — kept for the
/// loads it was built for.
(GrainShape, GrainShape, GrainShape)? _dustYardShapes;
String? _dustYardKey;

/// A still prop, painted once and kept.
ui.Picture _dustStill(String key, void Function(Canvas c) paint) =>
    _dustStillCache.putIfAbsent(key, () {
      final rec = ui.PictureRecorder();
      paint(Canvas(rec));
      return rec.endRecording();
    });

/// A DARK CARVED SILHOUETTE. The body in the city's dark stone, and the
/// deck's light on it only where the shape faces that light: the crescent
/// the body leaves when it is nudged away from the light — a rim, no
/// outline, no blur.
void _dustCarve(
  Canvas c,
  Path body, {
  required bool under,
  Offset light = const Offset(1.8, 2.4),
  double rim = 0.55,
  Color top = _kDustSilTop,
  Color foot = _kDustSilFoot,
}) {
  final b = body.getBounds();
  c.drawPath(
    body,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, foot],
      ).createShader(b.inflate(1)),
  );
  c.drawPath(
    Path.combine(ui.PathOperation.difference, body, body.shift(light)),
    Paint()..color = _dustRim(under).withValues(alpha: rim),
  );
}

/// A groove cut into a dark surface: the cut, and the light on its lip.
void _dustGroove(Canvas c, Path p, {required bool under, double w = 1.6}) {
  c.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.6),
  );
  c.drawPath(
    p.shift(const Offset(0, 1.1)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..color = _dustRim(under).withValues(alpha: 0.14),
  );
}

/// A vessel seen from a little above — belly at [at], [r] its half-width —
/// as a dark silhouette with a black mouth and a lit far lip. [slump] skews
/// the shoulders (a waster that sagged in the firing).
void _dustVessel(
  Canvas c,
  Offset at,
  double r, {
  required bool under,
  double slump = 0,
  double rim = 0.5,
}) {
  paintContactShadow(c, at + Offset(r * 0.15, r * 0.9), r * 2.3, r * 0.7);
  final body = Path()
    ..moveTo(at.dx - r * 0.42, at.dy - r * 0.8)
    ..quadraticBezierTo(
      at.dx - r * 1.14,
      at.dy - r * 0.56 + slump * r,
      at.dx - r,
      at.dy + r * 0.12,
    )
    ..quadraticBezierTo(
      at.dx - r * 0.86,
      at.dy + r * 0.8,
      at.dx - r * 0.32,
      at.dy + r * 0.88,
    )
    ..lineTo(at.dx + r * 0.32, at.dy + r * 0.88)
    ..quadraticBezierTo(
      at.dx + r * 0.86,
      at.dy + r * 0.8,
      at.dx + r,
      at.dy + r * 0.12,
    )
    ..quadraticBezierTo(
      at.dx + r * 1.14,
      at.dy - r * 0.56 - slump * r,
      at.dx + r * 0.42,
      at.dy - r * 0.8,
    )
    ..close();
  _dustCarve(
    c,
    body,
    under: under,
    rim: rim,
    light: Offset(r * 0.12, r * 0.16),
  );
  final mouth = Rect.fromCenter(
    center: Offset(at.dx + slump * r * 0.3, at.dy - r * 0.8),
    width: r * 0.92,
    height: r * 0.34,
  );
  c.drawOval(mouth, Paint()..color = const Color(0xFF050302));
  c.drawArc(
    mouth,
    pi * 1.05,
    pi * 0.9,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _dustRim(under).withValues(alpha: rim * 0.7),
  );
}

/// Sand as grains through any region: [inside] decides where, [shade] how
/// lit each grain is (0 shadow .. 1 crest).
GrainShape _dustRegionGrains(
  Rect box,
  bool Function(Offset) inside,
  double Function(Offset) shade,
  int count, {
  int seed = 1,
  List<(Offset, double)> extra = const [],
}) {
  final rng = Random(seed);
  final pts = <Offset>[];
  final sh = <double>[];
  var tries = 0;
  while (pts.length < count && tries < count * 60) {
    tries++;
    final p = Offset(
      box.left + rng.nextDouble() * box.width,
      box.top + rng.nextDouble() * box.height,
    );
    if (!inside(p)) continue;
    pts.add(p);
    sh.add(shade(p).clamp(0.0, 1.0));
  }
  for (final (p, s) in extra) {
    pts.add(p);
    sh.add(s);
  }
  return GrainShape.points(pts, sh, seed: seed);
}

/// Grains strung along [path], [step] apart, jittered by [jitter] — a crest,
/// a wind-lip, the hard edge a heap of dry sand keeps.
List<(Offset, double)> _dustLineGrains(
  Path path,
  double step,
  double shade, {
  double jitter = 0.8,
  int seed = 7,
}) {
  final rng = Random(seed);
  final out = <(Offset, double)>[];
  for (final m in path.computeMetrics()) {
    for (var d = 0.0; d < m.length; d += step) {
      final p = m.getTangentForOffset(d)?.position;
      if (p == null) continue;
      out.add((
        p +
            Offset(
              (rng.nextDouble() - 0.5) * jitter * 2,
              (rng.nextDouble() - 0.5) * jitter * 2,
            ),
        shade,
      ));
    }
  }
  return out;
}

/// LOOSE GRAINS worked out from time alone — a throw, a trickle, a flame —
/// bucketed by color and drawn in a handful of calls, each one a short
/// streak from where it was a moment ago.
class _DustInk {
  final Map<int, List<Offset>> _runs = {};

  void add(Offset from, Offset to, Color c, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 10).round();
    if (a <= 0) return;
    final k = ((c.toARGB32() & 0x00FFFFFF) << 4) | a;
    // A streak too short to draw is nudged so the cap still makes a grain.
    final f = (to - from).distance < 0.3 ? from - const Offset(0.3, 0) : from;
    (_runs[k] ??= <Offset>[])
      ..add(f)
      ..add(to);
  }

  void paint(Canvas canvas, {double width = 1.7}) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    for (final e in _runs.entries) {
      if (e.value.isEmpty) continue;
      p.color = Color(
        0xFF000000 | (e.key >> 4),
      ).withValues(alpha: (e.key & 15) / 10);
      canvas.drawPoints(ui.PointMode.lines, e.value, p);
      e.value.clear();
    }
  }
}

final _DustInk _dustInk = _DustInk();

double _dustHash(int n) {
  final v = sin(n * 127.1 + 311.7) * 43758.5453;
  return v - v.floorToDouble();
}
