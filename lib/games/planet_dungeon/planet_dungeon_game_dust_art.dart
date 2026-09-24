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
    final th = _sandThrow;
    if (th != null) {
      final t = th.$3 + dt;
      _sandThrow = t > _kSandThrowSeconds ? null : (th.$1, th.$2, t);
    }
  }

  // ── THE NIGHT DIG (2026-09-24) ──────────────────────────
  // Sablis read as one tan band: floor, drifts, rubble and the things you
  // act on all at the same brightness. Now the ground is dark umber by lamp
  // and moon, the rubble is cut back to the edges, and the MOUNDS are the
  // heroes — three silhouettes you can tell apart across the room — and a
  // dig throws its sand visibly to where it lands.

  static const double _kSandThrowSeconds = 1.1;

  void _startSandThrow(DustMound from, DustMound to) {
    _sandThrow = (
      from.streetPos,
      to.roomId == currentRoomId ? to.streetPos : null,
      0.0,
    );
  }

  /// BURIED: a square of intact paving, pegged out and strung on all four
  /// sides in chalk — measured, solid, walkable.
  void _drawBuriedSquare(Canvas canvas, Rect r, _MoundGeometry geo) {
    // One laid slab of street, proud of the dig: shadow, stone, a single
    // cross joint, the lit near edge, and a peg at each corner. Nothing
    // else — the jittered flags and chalk dashes read as mess.
    final slab = RRect.fromRectAndRadius(r, const Radius.circular(4));
    canvas.drawRRect(
      slab.shift(const Offset(0, 6)),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawRRect(slab, Paint()..color = const Color(0xFF6A5A42));
    final joint = Paint()
      ..strokeWidth = 1.4
      ..color = const Color(0xFF2A2014).withValues(alpha: 0.7);
    canvas.drawLine(r.topCenter, r.bottomCenter, joint);
    canvas.drawLine(r.centerLeft, r.centerRight, joint);
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

  /// The spadeful in the air: grains on an arc from the pit to where they
  /// land, and a puff where they do. Out of the room, over the wall.
  void _drawSandThrow(Canvas canvas, DungeonRoom room) {
    final th = _sandThrow;
    if (th == null) return;
    final (from, maybeTo, t0) = th;
    final t = t0 / _kSandThrowSeconds;
    final to = maybeTo ?? from + Offset(0, -room.bounds.height);
    final peak =
        Offset.lerp(from, to, 0.5)! -
        Offset(0, 90 + (to - from).distance * 0.2);
    Offset along(double u) {
      final a = Offset.lerp(from, peak, u)!;
      final b = Offset.lerp(peak, to, u)!;
      return Offset.lerp(a, b, u)!;
    }

    final grain = Paint()..color = RuinsOfTimeDungeon._kDustMoon;
    for (var i = 0; i < 16; i++) {
      final u = (t * 1.3 - i * 0.025).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      final p = along(u) + Offset(sin(i * 2.3) * 5, cos(i * 1.7) * 4);
      canvas.drawCircle(p, 2.4 - (i % 3) * 0.5, grain);
    }
    // The landing: a ring of sand thrown up where it falls.
    if (maybeTo != null) {
      final land = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
      if (land > 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: to,
            width: 40 + 90 * land,
            height: 16 + 36 * land,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * (1 - land)
            ..color = RuinsOfTimeDungeon._kDustMoon.withValues(
              alpha: 0.8 * (1 - land),
            ),
        );
      }
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
}
