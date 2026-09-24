// lib/games/planet_dungeon/planet_dungeon_game_fire_art.dart
//
// THE CINDER CATHEDRAL, IN GLASS — the Fire planet's world-space art, as a
// part of planet_dungeon_game.dart. The pilot of the glass-inlay direction
// (docs/dungeons.md §7.11): the cathedral is carved basalt, and leaded ember
// glass appears only where the player acts, reads or has changed something.
//
//   · Narthex — the hearth's fanlight catches from the middle out as it kindles.
//   · Nave — the rose before the chancel gate IS the star count: a third of it
//     ignites, sweeping round, for each star banked.
//   · Scriptorium — the soot mural is a smoked window. Each corner torch warms
//     its own quarter of the lead; the fourth sends a light front out from the
//     middle and the recorded stations bloom as it passes.
//   · Choir — the labyrinth is a rose laid in the floor with a petal aimed at
//     every brazier. Light one and fire runs up its spoke into the petal; get
//     the order wrong and the whole rose smokes over.
//   · Cloister — the garth is a leaded bed: soil, vine, ash and seep are panes.
//   · Bell gallery — every bell hangs before an oculus that floods when it rings.
//   · High altar — the dais carries one pane per bell; the black flame's vessel
//     wakes with the guardian.
//   · Sanctum — the Simurgh's roost is a shattered rose that burns violet.
//
// COST. Stone and dormant glass are baked once per room into a `ui.Picture`
// (keyed on id + bounds, generated from a seeded LCG — the Light archive's
// precedent). Per frame: the live panes, flames and baked glow sprites only.

part of 'planet_dungeon_game.dart';

const GlassPalette _kGlass = kCinderGlass;

/// The black flame's glass: violet in soot.
const Color _kVioletDeep = Color(0xFF3A1250);
const Color _kViolet = Color(0xFF8A3AB0);

/// Baked stone + dormant glass, per room (id + bounds).
final Map<String, ui.Picture> _cathedralFabricCache = {};

/// Rose windows and mural panes, built once and shared by the bake and the
/// live overlay (so the light always lands exactly on the lead it was baked in).
final Map<String, List<RosePane>> _cathedralRoseCache = {};

/// The glass collar in each choir brazier's plinth, by brazier position.
final Map<String, List<Path>> _collarCache = {};

extension CinderCathedralArt on PlanetDungeonGame {
  // ── Eased display state ─────────────────────────────────

  /// Ease every piece of glass toward the state it shows. Called once a frame
  /// from `_updateCathedral`, for the room the party is in.
  void _updateCathedralGlass(DungeonRoom room, double dt) {
    double toward(double v, double target, double upSecs, double downSecs) {
      if (v < 0) return target; // first sight: snap to the truth
      if (v < target) return min(target, v + dt / upSecs);
      if (v > target) return max(target, v - dt / downSecs);
      return v;
    }

    switch (room.id) {
      case 'scriptorium':
        for (var i = 0; i < room.muralTorches.length; i++) {
          if (litMuralTorches.contains(i)) {
            _torchCatch[i] = min(1.0, (_torchCatch[i] ?? 0) + dt / 1.1);
          } else {
            _torchCatch.remove(i);
          }
        }
        _muralGlow = muralLit(room) ? min(1.0, _muralGlow + dt / 2.6) : 0;
      case 'choir':
        final star = room.brazierStarIndex;
        final done = star != null && hasStar(star);
        if (ritualProgress < _ritePrevProgress) _riteSnuff = 1.0;
        _ritePrevProgress = ritualProgress;
        if (_riteSnuff > 0) _riteSnuff = max(0.0, _riteSnuff - dt / 1.6);
        for (var i = 0; i < room.braziers.length; i++) {
          final rank = star == null ? room.braziers[i].order : riteRankOf(i);
          final lit = done || rank < ritualProgress;
          final v = _petalHeat[i] ?? (done ? -1.0 : 0.0);
          _petalHeat[i] = toward(v, lit ? 1.0 : 0.0, 1.3, 0.45);
        }
        _riteBlaze = toward(_riteBlaze, done ? 1.0 : 0.0, 2.4, 0.6);
      case 'nave':
        for (var i = 0; i < 3; i++) {
          _roseStars[i] = toward(
            _roseStars[i],
            hasStar(i) ? 1.0 : 0.0,
            2.2,
            0.4,
          );
        }
      case 'bell_gallery':
        for (final chain in room.incenseChains) {
          final rung = bellsRung.contains(chain.id) || hasStar(2);
          _bellWindow[chain.id] = toward(
            _bellWindow[chain.id] ?? -1,
            rung ? 1.0 : 0.0,
            1.8,
            0.6,
          );
        }
      case 'high_altar':
        _altarWake = toward(
          _altarWake,
          (guardianAwake || hasStar(2)) ? 1.0 : 0.0,
          2.0,
          0.8,
        );
      case 'sanctum':
        _roostWake = toward(
          _roostWake,
          guardianAwake && !hasStar(2) ? 1.0 : 0.0,
          1.6,
          1.2,
        );
    }
  }

  // ── The floor: baked fabric ─────────────────────────────

  /// The whole room's stone and dormant glass, as one baked Picture.
  void _renderCathedralFloor(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final key = '${room.id}|${b.width.round()}x${b.height.round()}';
    canvas.drawPicture(
      _cathedralFabricCache.putIfAbsent(key, () => _bakeCathedral(room)),
    );
  }

  ui.Picture _bakeCathedral(DungeonRoom room) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final b = room.bounds;
    final rng = GlassRng(glassSeed(room.id, b));
    paintCarvedRoomShell(
      c,
      b,
      _kGlass,
      rng,
      doors: room.doors.map((d) => d.rect),
      arcade: room.id != 'scriptorium' && room.id != 'vestry',
    );
    switch (room.id) {
      case 'narthex':
        _bakeRunner(c, Rect.fromLTRB(b.left + 50, 240, b.right - 24, 300));
        _bakeHearth(c, const Offset(330, 265));
        _bakePier(c, const Offset(640, 176), 170);
        _bakePier(c, const Offset(672, 186), 150);
      case 'nave':
        _bakeRunner(
          c,
          Rect.fromLTRB(b.left + 24, b.top + 312, b.right - 24, b.top + 364),
        );
        for (var i = 0; i < 4; i++) {
          final x = b.left + 150 + i * 200.0;
          _bakePier(c, Offset(x, b.top + 112), 66);
          _bakePier(c, Offset(x, b.bottom - 190), 66);
        }
        _bakeRose(c, _naveRose(room), _naveRoseCentre(room), 54);
      case 'scriptorium':
        _bakeMural(c, room);
        for (final t in room.muralTorches) {
          paintCarvedDisc(c, t + const Offset(0, 20), 15, 6, 6, _kGlass);
        }
      case 'choir':
        _bakeChoirStalls(c, room);
        _bakeChoirRose(c, room);
        for (final brz in room.braziers) {
          _bakeBrazierPlinth(c, brz.position);
        }
      case 'cloister':
        final g = room.garth;
        if (g != null) _bakeGarthKerb(c, garthField(room, g));
        _bakeFountain(c, room.windVane ?? b.center);
      case 'reliquary':
        _bakeShrine(c, b.center);
      case 'vestry':
        _bakeFresco(c, room);
        for (var i = 0; i < 5; i++) {
          _bakeHook(c, Offset(b.left + 130 + i * 140.0, b.bottom - 150));
        }
      case 'bell_gallery':
        _bakeGalleryBeams(c, room);
        for (final chain in room.incenseChains) {
          paintPane(
            c,
            Path()..addOval(
              Rect.fromCircle(center: _bellOculus(chain), radius: 26),
            ),
            _kGlass.frostAt(1),
            _kGlass,
          );
        }
        for (final route in room.vesperRoutes) {
          paintCarvedDisc(
            c,
            route.standPosition + const Offset(0, 28),
            34,
            13,
            6,
            _kGlass,
          );
        }
      case 'high_altar':
        _bakeAltar(c, b.center);
      case 'sanctum':
        final g = room.guardian;
        _bakeRoost(c, room, g?.position ?? b.center);
    }
    return rec.endRecording();
  }

  /// A processional runner: porphyry laid in the flags, with a brass hem.
  void _bakeRunner(Canvas c, Rect r) {
    c.drawRect(
      r,
      Paint()..color = const Color(0xFF4A1510).withValues(alpha: 0.5),
    );
    final hem = Paint()
      ..strokeWidth = 1.6
      ..color = _kGlass.goldDeep.withValues(alpha: 0.5);
    c.drawLine(r.topLeft, r.topRight, hem);
    c.drawLine(r.bottomLeft, r.bottomRight, hem);
    final weave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _kGlass.goldDeep.withValues(alpha: 0.24);
    final cy = r.center.dy;
    final w = r.height * 0.32;
    for (var x = r.left + 26; x < r.right - 10; x += 52) {
      c.drawPath(
        Path()
          ..moveTo(x - w * 1.3, cy)
          ..lineTo(x, cy - w)
          ..lineTo(x + w * 1.3, cy)
          ..lineTo(x, cy + w)
          ..close(),
        weave,
      );
    }
  }

  /// A carved pier: capital, shaft, base, and the shadow at its foot.
  void _bakePier(Canvas c, Offset head, double height) {
    final foot = head + Offset(0, height);
    paintContactShadow(c, foot + const Offset(0, 6), 46, 14, opacity: 0.45);
    final shaft = Rect.fromLTRB(head.dx - 9, head.dy, head.dx + 9, foot.dy);
    c.drawRect(
      shaft,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _kGlass.stoneFoot,
            _kGlass.stoneFace,
            Color.lerp(_kGlass.stoneFace, _kGlass.stoneTop, 0.5)!,
            _kGlass.stoneFace,
          ],
          stops: const [0.0, 0.35, 0.62, 1.0],
        ).createShader(shaft),
    );
    paintCarvedBlock(
      c,
      Rect.fromCenter(center: foot + const Offset(0, -2), width: 32, height: 8),
      7,
      _kGlass,
    );
    paintCarvedBlock(
      c,
      Rect.fromCenter(center: head, width: 30, height: 9),
      6,
      _kGlass,
    );
  }

  // ── The live half, per room ─────────────────────────────

  void _renderCathedral(Canvas canvas, DungeonRoom room) {
    _renderGlassDoorPlugs(canvas, room);
    switch (room.id) {
      case 'narthex':
        _drawHearthLive(canvas, const Offset(330, 265));
      case 'nave':
        _drawNaveRoseLive(canvas, room);
        final stands = naveCandleStands(room);
        for (var i = 0; i < stands.length; i++) {
          _drawCandleStand(canvas, stands[i], naveCandles[i] ?? 0, i);
        }
      case 'scriptorium':
        _drawMuralLive(canvas, room);
        _drawMuralTorches(canvas, room);
        _drawEmberEpitaph(canvas);
      case 'choir':
        _drawChoirRoseLive(canvas, room);
        _drawRiteAshDrift(canvas, room); // the drift lies under everything
        _drawRitualBraziers(canvas, room);
      case 'cloister':
        if (room.garth != null) {
          final vane = room.windVane ?? room.bounds.center;
          _drawGlassGarth(canvas, room);
          final field = burnFieldFor(room);
          if (field != null) _drawBurnRing(canvas, vane, room.garth!, field);
          _drawWindVane(canvas, vane);
        } else {
          _drawCrosswind(canvas, room);
          _drawWindVane(canvas, room.windVane ?? room.bounds.center);
          _drawVineBeds(canvas, room);
        }
      case 'reliquary':
        _drawReliquaryLive(canvas, room.bounds.center);
      case 'vestry':
        _drawFrescoLive(canvas, room);
      case 'bell_gallery':
        _drawVesperStands(canvas, room);
        _drawBellWindows(canvas, room);
        _drawIncenseChains(canvas, room);
      case 'high_altar':
        _drawAltarLive(canvas, room.bounds.center);
      case 'sanctum':
        final g = room.guardian;
        _drawRoostLive(canvas, room, g?.position ?? room.bounds.center);
        _drawSimurghTelegraph(canvas, room);
    }
  }

  // ── Narthex: the hearth ─────────────────────────────────

  static const double _kFanR = 36.0;

  Offset _fanCentre(Offset hearth) => hearth + const Offset(0, -58);

  List<RosePane> _fanPanes(Offset hearth) => _cathedralRoseCache.putIfAbsent(
    'fan@${hearth.dx},${hearth.dy}',
    () => buildRose(_fanCentre(hearth), [
      (0.0, 13.0, 4, pi),
      (13.0, _kFanR, 10, pi),
    ]).where((p) => sin(p.angle) < 0).toList(),
  );

  void _bakeHearth(Canvas c, Offset h) {
    // The chimney breast: a tall carved face with a cap, the mouth cut in it.
    final face = Rect.fromLTRB(h.dx - 86, h.dy - 100, h.dx + 86, h.dy + 30);
    paintContactShadow(c, Offset(h.dx, h.dy + 44), 220, 30, opacity: 0.5);
    c.drawRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kGlass.stoneFace, _kGlass.stoneFoot],
        ).createShader(face),
    );
    final coursing = Paint()
      ..strokeWidth = 1.1
      ..color = _kGlass.joint.withValues(alpha: 0.5);
    for (var y = face.top + 16; y < face.bottom; y += 16) {
      c.drawLine(Offset(face.left, y), Offset(face.right, y), coursing);
    }
    paintCarvedBlock(
      c,
      Rect.fromLTRB(h.dx - 94, h.dy - 112, h.dx + 94, h.dy - 100),
      6,
      _kGlass,
    );
    final mouth = Path()
      ..moveTo(h.dx - 58, h.dy + 30)
      ..lineTo(h.dx - 58, h.dy - 22)
      ..quadraticBezierTo(h.dx - 56, h.dy - 54, h.dx, h.dy - 56)
      ..quadraticBezierTo(h.dx + 56, h.dy - 54, h.dx + 58, h.dy - 22)
      ..lineTo(h.dx + 58, h.dy + 30)
      ..close();
    c.drawPath(mouth, Paint()..color = const Color(0xFF070403));
    c.drawPath(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = _kGlass.stoneTop.withValues(alpha: 0.7),
    );
    // Andirons and logs, in the mouth.
    final log = Paint()
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A241A);
    c.drawLine(h + const Offset(-34, 20), h + const Offset(30, 12), log);
    c.drawLine(h + const Offset(-26, 10), h + const Offset(36, 22), log);
    // The hearthstone it all stands on.
    paintCarvedBlock(
      c,
      Rect.fromLTRB(h.dx - 96, h.dy + 30, h.dx + 96, h.dy + 50),
      9,
      _kGlass,
    );
    // The fanlight: dormant glass, the hearth's one pane of signal.
    for (final p in _fanPanes(h)) {
      paintPane(
        c,
        p.path,
        _kGlass.frostAt(p.index + p.ring),
        _kGlass,
        lead: 2.4,
      );
    }
    paintLead(
      c,
      Path()..addArc(
        Rect.fromCircle(center: _fanCentre(h), radius: _kFanR),
        pi,
        pi,
      ),
      _kGlass,
      width: 3.4,
    );
  }

  void _drawHearthLive(Canvas canvas, Offset c) {
    final k = _entryReveal.clamp(0.0, 1.0); // 0 cold ash → 1 roaring hearth
    // THE FANLIGHT CATCHES from the middle out: the inner wedges first, then
    // the outer panes, the centre ones before the ends.
    for (final p in _fanPanes(c)) {
      final spread = (p.angle - 1.5 * pi).abs() / (pi / 2); // 0 middle … 1 end
      final delay = p.ring * 0.28 + spread * 0.32;
      final heat = ((k - delay) / 0.4).clamp(0.0, 1.0);
      _heatPane(
        canvas,
        p.path,
        heat * (0.78 + 0.1 * sin(_time * 2.4 + p.index)),
      );
    }
    if (k > 0.05 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        _fanCentre(c),
        44 + 20 * k,
        _kGlass.live.withValues(alpha: 0.10 * k),
      );
    }
    if (k <= 0.0) {
      // Stone-cold: one stubborn ember waiting for a flame.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          c + const Offset(8, 16),
          5,
          const Color(
            0xFFFF8A50,
          ).withValues(alpha: 0.25 + 0.18 * (0.5 + 0.5 * sin(_time * 2.3))),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(center: c + const Offset(0, 22), width: 64, height: 16),
        Paint()..color = const Color(0xFF3A332C).withValues(alpha: 0.7),
      );
      return;
    }
    // KINDLE: the smaller tongues catch a beat behind the main one.
    final kindle = Curves.easeOutCubic.transform(k);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c + const Offset(0, 10),
        34 + 30 * kindle,
        const Color(0xFFFF9A50).withValues(alpha: 0.12 + 0.18 * kindle),
      );
      // The hearth throws its light onto the floor in front of it.
      drawGlow(
        canvas,
        _fx.glow!,
        c + const Offset(0, 70),
        90 * kindle,
        const Color(0xFFFF8A3C).withValues(alpha: 0.10 * kindle),
      );
    }
    _drawFlame(canvas, c + const Offset(0, 22), 52 * kindle, phase: 0.4);
    final k2 = ((k - 0.25) / 0.75).clamp(0.0, 1.0);
    final k3 = ((k - 0.5) / 0.5).clamp(0.0, 1.0);
    if (k2 > 0) {
      _drawFlame(canvas, c + const Offset(-20, 26), 30 * k2, phase: 2.1);
    }
    if (k3 > 0) {
      _drawFlame(canvas, c + const Offset(18, 26), 26 * k3, phase: 3.6);
    }
  }

  // ── Nave: the rose is the star count ────────────────────

  Offset _naveRoseCentre(DungeonRoom room) =>
      Offset(room.bounds.center.dx + 185, room.bounds.top + 106);

  List<RosePane> _naveRose(DungeonRoom room) {
    final c = _naveRoseCentre(room);
    return _cathedralRoseCache.putIfAbsent(
      'nave@${c.dx},${c.dy}',
      () => buildRose(c, [(12.0, 30.0, 6, -pi / 2), (30.0, 54.0, 12, -pi / 2)]),
    );
  }

  /// Which third of the nave rose a pane belongs to, and how far round it.
  (int, double) _roseThird(double angle) {
    var a = (angle + pi / 2) % (2 * pi);
    if (a < 0) a += 2 * pi;
    final third = (a / (2 * pi / 3)).floor().clamp(0, 2);
    return (third, (a - third * 2 * pi / 3) / (2 * pi / 3));
  }

  void _bakeRose(Canvas c, List<RosePane> panes, Offset centre, double r) {
    paintContactShadow(
      c,
      centre + const Offset(0, 4),
      r * 2.3,
      r * 1.2,
      opacity: 0.3,
    );
    for (final p in panes) {
      paintPane(
        c,
        p.path,
        _kGlass.frostAt(p.index * 2 + p.ring),
        _kGlass,
        lead: 2.6,
      );
    }
    // The three thirds are divided by heavier lead: three stars, three lights.
    final div = Path();
    for (var k = 0; k < 3; k++) {
      final a = -pi / 2 + k * 2 * pi / 3;
      div
        ..moveTo(centre.dx + 12 * cos(a), centre.dy + 12 * sin(a))
        ..lineTo(centre.dx + r * cos(a), centre.dy + r * sin(a));
    }
    div.addOval(Rect.fromCircle(center: centre, radius: r));
    paintLead(c, div, _kGlass, width: 4);
    paintRondel(c, centre, 11, _kGlass, fill: const Color(0xFF2A1A10));
  }

  void _drawNaveRoseLive(Canvas canvas, DungeonRoom room) {
    final panes = _naveRose(room);
    final c = _naveRoseCentre(room);
    var banked = 0.0;
    for (final p in panes) {
      final (third, along) = _roseThird(p.angle);
      final v = _roseStars[third].clamp(0.0, 1.0);
      if (v <= 0) continue;
      // The light SWEEPS round its third, inner ring a step ahead.
      final heat = ((v * 1.5 - along - (1 - p.ring) * 0.15) / 0.45).clamp(
        0.0,
        1.0,
      );
      _heatPane(
        canvas,
        p.path,
        heat * (0.72 + 0.08 * sin(_time * 1.3 + p.index)),
      );
    }
    for (var i = 0; i < 3; i++) {
      banked += _roseStars[i].clamp(0.0, 1.0);
    }
    if (banked > 0 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        64 + 12 * banked,
        _kGlass.live.withValues(alpha: 0.05 + 0.05 * banked),
      );
    }
    // The boss catches gold once all three are home.
    if (banked >= 2.99) {
      paintRondel(canvas, c, 11, _kGlass, fill: _kGlass.heat(0.95));
      _drawStarGlyph(canvas, c, 6, const Color(0xFF4A1A08));
    } else {
      _drawStarGlyph(
        canvas,
        c,
        6,
        _kGlass.goldDeep.withValues(alpha: 0.55 + 0.15 * banked),
      );
    }
  }

  /// A three-taper candle stand on a votive glass dish. [lit] is 0..1.
  void _drawCandleStand(Canvas canvas, Offset p, double lit, int seed) {
    final dish = Rect.fromCenter(
      center: p + const Offset(0, 5),
      width: 40,
      height: 13,
    );
    paintContactShadow(canvas, p + const Offset(0, 8), 46, 14, opacity: 0.35);
    paintPane(
      canvas,
      Path()..addOval(dish),
      _kGlass.frostAt(seed),
      _kGlass,
      lead: 2.2,
    );
    if (lit > 0.01) {
      _heatPane(canvas, Path()..addOval(dish.deflate(1.5)), 0.7 * lit);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p + const Offset(0, 4),
          30 + 8 * lit,
          const Color(0xFFFF9A3C).withValues(alpha: 0.16 * lit),
        );
      }
    }
    canvas.drawLine(
      p + const Offset(-16, 2),
      p + const Offset(16, 2),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3A2E24),
    );
    for (var k = -1; k <= 1; k++) {
      final h = k == 0 ? 18.0 : 13.0;
      final base = p + Offset(k * 10.0, 1);
      final tip = base + Offset(0, -h);
      canvas.drawLine(
        base,
        tip,
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            const Color(0xFF6B5C46),
            const Color(0xFFD8C7A2),
            lit,
          )!,
      );
      if (lit <= 0.01) {
        canvas.drawCircle(tip, 1.4, Paint()..color = const Color(0xFF2A2118));
        continue;
      }
      final ph = _time * 4.6 + k * 2.3 + seed * 0.9;
      final fh = (5.0 + 3.0 * sin(ph)) * lit;
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx - 2.2, tip.dy)
          ..quadraticBezierTo(
            tip.dx - 1.6,
            tip.dy - fh * 0.6,
            tip.dx,
            tip.dy - fh,
          )
          ..quadraticBezierTo(
            tip.dx + 1.6,
            tip.dy - fh * 0.6,
            tip.dx + 2.2,
            tip.dy,
          )
          ..close(),
        Paint()..color = const Color(0xFFFFC46A).withValues(alpha: 0.9 * lit),
      );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          tip + Offset(0, -fh * 0.5),
          9,
          const Color(0xFFFFB46B).withValues(alpha: 0.30 * lit),
        );
      }
    }
  }

  // ── Scriptorium: the soot mural is a window ─────────────

  Rect _muralPanel(DungeonRoom room) => Rect.fromCenter(
    center: Offset(room.bounds.center.dx, room.bounds.top + 130),
    width: 490,
    height: 170,
  );

  /// The mural's panes: an uneven lattice of smoked glass, generated once.
  List<RosePane> _muralPanes(DungeonRoom room) {
    final panel = _muralPanel(room);
    return _cathedralRoseCache.putIfAbsent('mural@${room.id}', () {
      final rng = GlassRng(glassSeed('mural', panel));
      const cols = 11, rows = 4;
      final pts = List.generate(
        cols + 1,
        (i) => List.generate(rows + 1, (k) {
          final edge = i == 0 || i == cols || k == 0 || k == rows;
          return Offset(
            panel.left + panel.width * i / cols + (edge ? 0 : rng.range(-9, 9)),
            panel.top + panel.height * k / rows + (edge ? 0 : rng.range(-7, 7)),
          );
        }),
      );
      final out = <RosePane>[];
      for (var i = 0; i < cols; i++) {
        for (var k = 0; k < rows; k++) {
          final q = [
            pts[i][k],
            pts[i + 1][k],
            pts[i + 1][k + 1],
            pts[i][k + 1],
          ];
          final path = Path()..addPolygon(q, true);
          final mid = (q[0] + q[1] + q[2] + q[3]) / 4;
          out.add(RosePane(k, i, 0, path, mid));
        }
      }
      return out;
    });
  }

  void _bakeMural(Canvas c, DungeonRoom room) {
    final panel = _muralPanel(room);
    // A carved frame the glass is set in.
    paintCarvedBlock(c, panel.inflate(12), 10, _kGlass, radius: 6);
    c.drawRect(panel.inflate(2), Paint()..color = _kGlass.lead);
    for (final p in _muralPanes(room)) {
      paintPane(
        c,
        p.path,
        Color.lerp(_kGlass.smoke, _kGlass.frostAt(p.index + p.ring), 0.25)!,
        _kGlass,
        lead: 2.4,
      );
    }
    paintLead(c, Path()..addRect(panel), _kGlass, width: 4);
  }

  Offset _stationAt(Rect panel, int rank) =>
      Offset(panel.left + 52 + rank * 77.0, panel.bottom - 36);

  void _drawMuralLive(Canvas canvas, DungeonRoom room) {
    final panel = _muralPanel(room);
    final panes = _muralPanes(room);
    final centre = panel.center;
    final maxR = panel.width * 0.56;
    final glow = Curves.easeInOut.transform(_muralGlow.clamp(0.0, 1.0));
    final front = glow * (maxR + 80);

    // EACH TORCH WARMS ITS OWN QUARTER: the glass nearest a lit corner takes
    // an ember back-light, and the lead there catches.
    for (final p in panes) {
      var warmth = 0.0;
      for (var i = 0; i < room.muralTorches.length; i++) {
        final k = _torchCatch[i] ?? 0;
        if (k <= 0) continue;
        final t = room.muralTorches[i];
        final d =
            (p.mid -
                    Offset(
                      t.dx.clamp(panel.left, panel.right),
                      t.dy.clamp(panel.top, panel.bottom),
                    ))
                .distance;
        warmth += k * (1 - (d / (panel.width * 0.55)).clamp(0.0, 1.0)) * 0.34;
      }
      // …and the fourth sends the light out from the middle. Settled, the
      // window is a DEEP amber — it is the largest pane of glass in the
      // cathedral, and the stations it holds have to be brighter than it.
      final dist = (p.mid - centre).distance;
      final lit = ((front - dist) / 70).clamp(0.0, 1.0);
      final edge = lit > 0 && lit < 1 ? (1 - (lit - 0.5).abs() * 2) : 0.0;
      final tint = 0.22 + 0.07 * ((p.index * 7 + p.ring * 3) % 5) / 4;
      final breathe = glow >= 1
          ? 0.025 * sin(_time * 1.1 + p.index * 0.9 + p.ring * 1.7)
          : 0.0;
      final heat = max(warmth, lit * (tint + breathe) + edge * 0.5);
      _heatPane(canvas, p.path, heat, opacity: 0.82);
    }
    // The lead catches as the light reaches it.
    if (glow > 0) {
      final lead = Path();
      for (final p in panes) {
        if ((p.mid - centre).distance < front) {
          lead.addPath(p.path, Offset.zero);
        }
      }
      canvas.drawPath(
        lead,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = _kGlass.gold.withValues(alpha: 0.30 * glow),
      );
    }
    // A catching torch sends an ember running along the lead to the middle.
    if (_fx.ready) {
      for (var i = 0; i < room.muralTorches.length; i++) {
        final k = _torchCatch[i] ?? 0;
        if (k <= 0 || k >= 1) continue;
        final t = room.muralTorches[i];
        final from = Offset(
          t.dx.clamp(panel.left, panel.right),
          t.dy.clamp(panel.top, panel.bottom),
        );
        final at = Offset.lerp(from, centre, Curves.easeIn.transform(k))!;
        drawGlow(
          canvas,
          _fx.mote!,
          at,
          7,
          _kGlass.liveCore.withValues(alpha: 0.8 * (1 - k * 0.5)),
        );
        drawGlow(
          canvas,
          _fx.glow!,
          at,
          22,
          _kGlass.live.withValues(alpha: 0.25 * (1 - k)),
        );
      }
      if (glow > 0 && glow < 1) {
        // The light front itself, running outward through the glass.
        drawGlow(
          canvas,
          _fx.glow!,
          centre,
          front * 0.9,
          _kGlass.live.withValues(alpha: 0.18 * (1 - glow)),
        );
      }
    }

    // THE STATIONS. The lower band is the mural's own testimony, and it is
    // CONFIRMATION, not a key (§6.1 REWORK): six numbered stations, of which
    // only TWO were ever recorded — and never two in a row. Each recorded
    // station names its brazier wordlessly, as the choir's six bowls with one
    // alight. KNOWLEDGE persists across a death; LIGHT does not: relight the
    // corners and everything already recovered comes back.
    if (glow <= 0) return;
    final tier = choirRevealTier;
    final shown = tier < 0
        ? const <int>{}
        : riteMuralRanks.take(tier >= 1 ? 2 : 1).toSet();
    final choir = _choirRoom;
    for (var rank = 0; rank < 6; rank++) {
      final p = _stationAt(panel, rank);
      // A station blooms as the light front passes it.
      final bloom = ((front - (p - centre).distance) / 60).clamp(0.0, 1.0);
      if (bloom <= 0) continue;
      final recorded = shown.contains(rank) && choir != null;
      paintRondel(
        canvas,
        p,
        17 * (0.7 + 0.3 * bloom),
        _kGlass,
        fill: recorded
            ? _kGlass.heat(0.45 + 0.25 * bloom)
            : const Color(0xFF16100C),
        rim: bloom * (recorded ? 1.0 : 0.45),
        lead: 2.4,
      );
      // The station's number, always legible once lit: rank+1 tally pips.
      for (var k = 0; k <= rank; k++) {
        canvas.drawCircle(
          p + Offset(-18 + k * 7.5, 26),
          2.0,
          Paint()..color = _kGlass.gold.withValues(alpha: 0.8 * bloom),
        );
      }
      if (!recorded) {
        // Unrecorded: the soot here has flaked away to a crack.
        canvas.drawLine(
          p + const Offset(-7, -6),
          p + const Offset(5, 7),
          Paint()
            ..strokeWidth = 1.2
            ..color = _kGlass.goldDeep.withValues(alpha: 0.5 * bloom),
        );
        continue;
      }
      final named = riteBrazierAt(rank);
      for (var i = 0; i < choir.braziers.length; i++) {
        final q = p + (choir.braziers[i].position - choir.bounds.center) * 0.05;
        final isNamed = i == named;
        canvas.drawCircle(
          q,
          isNamed ? 3.2 : 1.8,
          Paint()
            ..style = isNamed ? PaintingStyle.fill : PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = (isNamed ? _kGlass.liveCore : _kGlass.gold).withValues(
              alpha: (isNamed ? 0.95 : 0.45) * bloom,
            ),
        );
        if (isNamed && _fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            q,
            12,
            _kGlass.live.withValues(alpha: 0.5 * bloom),
          );
        }
      }
    }
  }

  /// The four corner torches: a lamp-glass on a carved stand, and a flame
  /// once lit. An unlit one still has to read as something a hand could
  /// light, so its glass is a gold-rimmed rondel — the mark of a thing to act on.
  void _drawMuralTorches(Canvas canvas, DungeonRoom room) {
    for (var i = 0; i < room.muralTorches.length; i++) {
      final p = room.muralTorches[i];
      final catchT = _torchCatch[i] ?? 0;
      final lit = litMuralTorches.contains(i);
      canvas.drawRect(
        Rect.fromCenter(center: p + const Offset(0, 10), width: 4, height: 18),
        Paint()..color = const Color(0xFF2A2019),
      );
      paintRondel(
        canvas,
        p,
        9,
        _kGlass,
        fill: lit ? _kGlass.heat(0.35 + 0.5 * catchT) : _kGlass.smoke,
        rim: lit ? 1.0 : 0.7,
        lead: 2.4,
      );
      if (!lit) {
        canvas.drawCircle(
          p,
          2.6,
          Paint()
            ..color = const Color(
              0xFFFF8A50,
            ).withValues(alpha: 0.18 + 0.1 * sin(_time * 2 + i)),
        );
        continue;
      }
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p + const Offset(0, -6),
          30 + 24 * catchT,
          const Color(0xFFFFB46B).withValues(alpha: 0.10 + 0.10 * catchT),
        );
      }
      // The flame climbs out of the glass as it catches.
      _drawFlame(
        canvas,
        p + const Offset(0, -4),
        8 + 10 * catchT,
        phase: i * 1.7,
      );
    }
  }

  // ── Choir: the labyrinth rose ───────────────────────────

  Offset _choirRoseCentre(DungeonRoom room) =>
      room.bounds.center + const Offset(0, 8);

  static const double _kChoirRoseR = 112.0;

  List<RosePane> _choirRose(DungeonRoom room) {
    final c = _choirRoseCentre(room);
    return _cathedralRoseCache.putIfAbsent(
      'choir@${c.dx},${c.dy}',
      () => buildRose(c, [
        (11.0, 30.0, 6, 0.2),
        (30.0, 52.0, 10, 0.05),
        (52.0, 70.0, 14, 0.3),
        (70.0, 94.0, 18, 0.1),
        (94.0, _kChoirRoseR, 30, 0.0),
      ]),
    );
  }

  /// The petal ring panes aimed at brazier [i]: the outer ring, within a
  /// narrow arc of its direction.
  bool _isPetalOf(RosePane p, DungeonRoom room, int i) {
    if (p.ring != 4) return false;
    final d = room.braziers[i].position - _choirRoseCentre(room);
    return angleGap(p.angle, atan2(d.dy, d.dx)) < 0.24;
  }

  void _bakeChoirRose(Canvas c, DungeonRoom room) {
    final centre = _choirRoseCentre(room);
    // Spokes out to each brazier: channels cut in the flags, identical for
    // every brazier — the composition must never hint at the order.
    for (final brz in room.braziers) {
      final d = brz.position - centre;
      final len = d.distance;
      if (len < 130) continue;
      final u = d / len;
      final a = centre + u * (_kChoirRoseR + 2);
      final z = brz.position - u * 36;
      c.drawLine(
        a,
        z,
        Paint()
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = _kGlass.stoneFoot.withValues(alpha: 0.85),
      );
      c.drawLine(
        a + const Offset(0, 1.5),
        z + const Offset(0, 1.5),
        Paint()
          ..strokeWidth = 1
          ..color = _kGlass.stoneTop.withValues(alpha: 0.35),
      );
    }
    paintContactShadow(
      c,
      centre + const Offset(0, 6),
      _kChoirRoseR * 2.2,
      _kChoirRoseR * 1.3,
      opacity: 0.28,
    );
    for (final p in _choirRose(room)) {
      paintPane(
        c,
        p.path,
        _kGlass.frostAt(p.index * 3 + p.ring),
        _kGlass,
        lead: p.ring == 4 ? 2.4 : 2.0,
        opacity: 0.85,
      );
    }
    // The labyrinth's walk, in gold lead laid over the glass: four broken
    // circuits joined at their gates. Devotional, not a diagram (§6.1).
    const radii = [30.0, 52.0, 70.0, 94.0];
    final walk = Path();
    for (var i = 0; i < radii.length; i++) {
      final from = i * 1.35 + 0.4;
      walk.addArc(
        Rect.fromCircle(center: centre, radius: radii[i]),
        from,
        pi * 1.72,
      );
      if (i + 1 < radii.length) {
        final u = Offset(cos(from), sin(from));
        walk
          ..moveTo(centre.dx + u.dx * radii[i], centre.dy + u.dy * radii[i])
          ..lineTo(
            centre.dx + u.dx * radii[i + 1],
            centre.dy + u.dy * radii[i + 1],
          );
      }
    }
    c.drawPath(
      walk,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = _kGlass.goldDeep.withValues(alpha: 0.9),
    );
    paintLead(
      c,
      Path()..addOval(Rect.fromCircle(center: centre, radius: _kChoirRoseR)),
      _kGlass,
      width: 4,
    );
    paintRondel(c, centre, 11, _kGlass, fill: const Color(0xFF2A1A10));
  }

  void _drawChoirRoseLive(Canvas canvas, DungeonRoom room) {
    final centre = _choirRoseCentre(room);
    final panes = _choirRose(room);
    final blaze = _riteBlaze.clamp(0.0, 1.0);

    // THE RITE WON: the whole rose catches, from the heart outward.
    if (blaze > 0) {
      for (final p in panes) {
        final r = (p.mid - centre).distance / _kChoirRoseR;
        final heat = ((blaze * 1.4 - r) / 0.4).clamp(0.0, 1.0);
        _heatPane(
          canvas,
          p.path,
          heat * (0.42 + 0.06 * sin(_time * 1.2 + p.index)),
        );
      }
    }

    // EACH LIT BRAZIER: fire runs up its spoke, then its petal takes.
    for (var i = 0; i < room.braziers.length; i++) {
      final h = (_petalHeat[i] ?? 0).clamp(0.0, 1.0);
      if (h <= 0) continue;
      final brz = room.braziers[i].position;
      final d = brz - centre;
      final len = d.distance;
      if (len > 1) {
        final u = d / len;
        final a = brz - u * 36;
        final z = centre + u * (_kChoirRoseR + 2);
        final run = (h / 0.55).clamp(0.0, 1.0);
        final head = Offset.lerp(a, z, run)!;
        canvas.drawLine(
          a,
          head,
          Paint()
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = _kGlass.live.withValues(alpha: 0.55 * h),
        );
        if (run < 1 && _riteSnuff <= 0 && _fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            head,
            16,
            _kGlass.liveCore.withValues(alpha: 0.7),
          );
        }
      }
      final petal = ((h - 0.45) / 0.55).clamp(0.0, 1.0);
      if (petal <= 0) continue;
      for (final p in panes) {
        if (!_isPetalOf(p, room, i)) continue;
        _heatPane(canvas, p.path, petal * (0.82 + 0.08 * sin(_time * 3 + i)));
      }
    }

    // A WRONG FLAME: the rose smokes over, and the smoke clears.
    if (_riteSnuff > 0) {
      final s = _riteSnuff;
      final path = Path()
        ..addOval(Rect.fromCircle(center: centre, radius: _kChoirRoseR));
      paintPaneFill(canvas, path, const Color(0xFF0E0B0A), opacity: 0.6 * s);
      if (_fx.ready) {
        // Smoke boils up off the glass and rolls outward as it clears.
        for (var k = 0; k < 8; k++) {
          final a = k * 0.785 + (1 - s) * 0.9;
          final rise = (1 - s) * 40;
          drawPuff(
            canvas,
            _fx.puff!,
            centre +
                Offset(cos(a), sin(a) * 0.7) * (40 + (1 - s) * 90) -
                Offset(0, rise),
            110 + (1 - s) * 60,
            const Color(0xFF7A6E66).withValues(alpha: 0.5 * s),
          );
        }
      }
    }
    if (blaze > 0 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        centre,
        _kChoirRoseR * (1.1 + 0.3 * blaze),
        _kGlass.live.withValues(alpha: 0.10 * blaze),
      );
    }
  }

  void _bakeChoirStalls(Canvas c, DungeonRoom room) {
    final b = room.bounds;
    for (final left in [true, false]) {
      // Two rows, between the braziers rather than under them.
      final x0 = left ? b.left + 84 : b.right - 232;
      final x1 = left ? b.left + 232 : b.right - 84;
      for (var i = 0; i < 2; i++) {
        final y = b.center.dy - 42 + i * 70.0;
        // The back rail stands behind the seat; both are carved.
        paintCarvedBlock(
          c,
          Rect.fromLTRB(x0, y - 8, x1, y - 2),
          10,
          _kGlass,
          radius: 2,
        );
        paintCarvedBlock(
          c,
          Rect.fromLTRB(x0, y + 8, x1, y + 16),
          6,
          _kGlass,
          radius: 2,
          topColor: const Color(0xFF4A3A2E),
        );
        final divide = Paint()
          ..strokeWidth = 1.4
          ..color = Colors.black.withValues(alpha: 0.5);
        for (var k = 1; k < 3; k++) {
          final x = x0 + (x1 - x0) * k / 3;
          c.drawLine(Offset(x, y + 8), Offset(x, y + 22), divide);
        }
      }
    }
  }

  /// The twelve panes of the glass collar in a brazier's plinth top, built
  /// once per brazier and shared by the bake, the soot and the fire.
  List<Path> _collarPanes(Offset brazier) => _collarCache.putIfAbsent(
    '${brazier.dx},${brazier.dy}',
    () => [
      for (var k = 0; k < 12; k++)
        ellipseSectorPath(
          brazier + const Offset(0, 24),
          18,
          7,
          28,
          10.8,
          k * pi / 6,
          (k + 1) * pi / 6,
          steps: 4,
        ),
    ],
  );

  /// A brazier's carved plinth, and the glass collar set in its top that
  /// takes the soot.
  void _bakeBrazierPlinth(Canvas c, Offset p) {
    final base = p + const Offset(0, 24);
    paintCarvedDisc(c, base, 31, 12, 7, _kGlass);
    for (var k = 0; k < 12; k++) {
      // Clean glass is PALE honey: the soot is the evidence, and black smoke
      // has to have something light to stain.
      paintPane(
        c,
        _collarPanes(p)[k],
        Color.lerp(
          const Color(0xFFB08A52),
          const Color(0xFF8A6A3C),
          (k % 3) / 2,
        )!,
        _kGlass,
        lead: 1.6,
        opacity: 0.92,
      );
    }
  }

  void _drawRitualBraziers(Canvas canvas, DungeonRoom room) {
    final star = room.brazierStarIndex;
    final done = star != null && hasStar(star);
    // The evidence lies under the iron, so a lit brazier's own light falls
    // over its own testimony.
    if (!done && star != null) {
      for (var i = 0; i < room.braziers.length; i++) {
        _drawBrazierTestimony(canvas, room, i);
      }
      _drawTestimonyLink(canvas, room);
    }
    for (var i = 0; i < room.braziers.length; i++) {
      final brz = room.braziers[i];
      final rank = star == null ? brz.order : riteRankOf(i);
      final lit = done || rank < ritualProgress;
      final wax = !done && star != null;
      final h = (_petalHeat[i] ?? (lit ? 1.0 : 0.0)).clamp(0.0, 1.0);
      if (h > 0) {
        // The collar catches the brazier's fire.
        for (var k = 0; k < 12; k++) {
          _heatPane(
            canvas,
            _collarPanes(brz.position)[k],
            h * (0.62 + 0.1 * sin(_time * 2.6 + k + i)),
          );
        }
      }
      // The tallow COLUMN goes behind the iron and the MELT LINE in front.
      if (wax) _drawBrazierWax(canvas, room, i, body: true);
      // Animation phase rides the brazier's PLACE, never its rank — a flicker
      // that beat in rite order would leak the answer through the idle loop.
      _drawBrazier(canvas, brz.position, lit: lit, phase: i * 1.3);
      if (wax) _drawBrazierWax(canvas, room, i, body: false);
    }
  }

  /// THE SOOT + THE ASH at one brazier's foot.
  ///
  ///  • SOOT — smoke has stained the glass collar on the side it leans, AWAY
  ///    from whichever neighbour was already burning, and fanned out across
  ///    the flags beyond. On the fire lit FIRST there was no such neighbour,
  ///    so the whole collar is smoked: an even ring, unmistakable at a glance
  ///    and the thread-end of the whole deduction.
  ///  • ASH — a small drift banked downwind, matching the floor streaks.
  ///
  /// Mask insight (t1) only brightens what is already drawn and adds a caret;
  /// it never adds information the iron does not carry.
  void _drawBrazierTestimony(Canvas canvas, DungeonRoom room, int i) {
    final alive = _testimonyAlive(i);
    if (alive <= 0.01) return;
    final t = testimonyFor(i);
    if (t == null) return;
    final base = room.braziers[i].position + const Offset(0, 24);
    final mark = _testimonyMark;
    final lean = t.sootLean;
    final smoke = const Color(0xFF0B0908);

    if (lean == null) {
      // THE EVEN COLLAR — nothing was alight, so the soot fell all round.
      for (var k = 0; k < 12; k++) {
        paintPaneFill(
          canvas,
          _collarPanes(room.braziers[i].position)[k],
          smoke,
          opacity: (0.78 + 0.14 * mark) * alive,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(center: base, width: 84, height: 34),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = smoke.withValues(alpha: (0.45 + 0.15 * mark) * alive),
      );
    } else {
      final a = atan2(lean.dy, lean.dx);
      // Smoke on the collar's panes on the leaning side.
      for (var k = 0; k < 12; k++) {
        final am = (k + 0.5) * pi / 6;
        final gap = angleGap(am, a);
        if (gap > 1.15) continue;
        paintPaneFill(
          canvas,
          _collarPanes(room.braziers[i].position)[k],
          smoke,
          opacity: (0.85 - gap * 0.45 + 0.1 * mark) * alive,
        );
      }
      // …and fanned out over the flags beyond it.
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.scale(1, 0.55);
      canvas.rotate(a);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(44, 0), width: 44, height: 26),
        Paint()..color = smoke.withValues(alpha: (0.55 + 0.15 * mark) * alive),
      );
      for (final fan in const [-0.32, 0.0, 0.32]) {
        final u = Offset(cos(fan), sin(fan));
        for (var seg = 0; seg < 3; seg++) {
          final t0 = 50.0 + seg * 11.0;
          canvas.drawLine(
            u * t0,
            u * (t0 + 11),
            Paint()
              ..strokeWidth = 4.2 - seg * 1.1
              ..strokeCap = StrokeCap.round
              ..color = smoke.withValues(
                alpha: (0.46 + 0.16 * mark) * alive * (1 - seg * 0.28),
              ),
          );
        }
      }
      canvas.restore();
    }

    // THE ASH, banked downwind on the same side as the floor streaks: a soft
    // drift and a few settled grains, never a shape — a wedge here read as a
    // play button.
    final d = riteAshDrift;
    if (d != Offset.zero) {
      final ab = base + Offset(d.dx * 40, d.dy * 17);
      final ash = const Color(0xFFBFAE96);
      if (_fx.ready) {
        drawPuff(
          canvas,
          _fx.puff!,
          ab,
          46,
          ash.withValues(alpha: (0.34 + 0.14 * mark) * alive),
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: ab, width: 30, height: 12),
          Paint()..color = ash.withValues(alpha: 0.25 * alive),
        );
      }
      final grain = Paint()
        ..color = ash.withValues(alpha: (0.5 + 0.2 * mark) * alive);
      final n = Offset(-d.dy, d.dx);
      for (var k = 0; k < 4; k++) {
        final q =
            ab + d * (8.0 + k * 5) + n * ((k.isEven ? 1 : -1) * (3.0 + k));
        canvas.drawCircle(
          Offset(q.dx, ab.dy + (q.dy - ab.dy) * 0.45),
          1.3,
          grain,
        );
      }
    }

    if (mark > 0.02) {
      final caret = room.braziers[i].position - const Offset(0, 50);
      final nib = Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = _kGlass.gold.withValues(alpha: 0.42 * mark * alive);
      canvas.drawLine(caret + const Offset(-5, 5), caret, nib);
      canvas.drawLine(caret, caret + const Offset(5, 5), nib);
    }
  }

  /// A standing ritual brazier: tripod and iron basin, fire when lit. It
  /// stands on the carved plinth baked under it.
  void _drawBrazier(
    Canvas canvas,
    Offset p, {
    required bool lit,
    double phase = 0,
  }) {
    if (lit && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        p,
        56,
        const Color(0xFFFF8A50).withValues(alpha: 0.2),
      );
    }
    final leg = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF221812);
    canvas.drawLine(p + const Offset(-8, 14), p + const Offset(-15, 25), leg);
    canvas.drawLine(p + const Offset(8, 14), p + const Offset(15, 25), leg);
    canvas.drawLine(p + const Offset(0, 14), p + const Offset(0, 26), leg);
    const rimY = -13.0;
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - 21, p.dy + rimY)
        ..lineTo(p.dx + 21, p.dy + rimY)
        ..lineTo(p.dx + 11, p.dy + 15)
        ..lineTo(p.dx - 11, p.dy + 15)
        ..close(),
      Paint()..color = const Color(0xFF221610),
    );
    canvas.drawLine(
      p + const Offset(-19, rimY + 3),
      p + const Offset(-10, 13),
      Paint()
        ..strokeWidth = 1.6
        ..color = const Color(0xFF5A4636).withValues(alpha: 0.7),
    );
    final rim = Rect.fromCenter(
      center: p + const Offset(0, rimY),
      width: 42,
      height: 13,
    );
    canvas.drawOval(
      rim,
      Paint()..color = lit ? const Color(0xFF3A1606) : const Color(0xFF160D08),
    );
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = (lit ? _kGlass.gold : const Color(0xFF6A5240)).withValues(
          alpha: 0.9,
        ),
    );
    if (lit) {
      for (final dx in const [-9.0, 0.0, 9.0]) {
        canvas.drawCircle(
          p + Offset(dx, rimY + 1),
          3.2,
          Paint()
            ..color = const Color(0xFFFF7A2A).withValues(
              alpha: 0.55 + 0.3 * (0.5 + 0.5 * sin(_time * 3.1 + dx + phase)),
            ),
        );
      }
      _drawFlame(canvas, p + const Offset(0, rimY - 2), 32, phase: phase);
    } else if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.mote!,
        p + const Offset(6, rimY),
        4,
        const Color(0xFFFF8A50).withValues(
          alpha: 0.16 + 0.12 * (0.5 + 0.5 * sin(_time * 2.0 + phase)),
        ),
      );
    }
  }

  // ── Cloister: the garth is a leaded bed ─────────────────

  void _bakeGarthKerb(Canvas c, Rect f) {
    final k = f.inflate(12);
    paintContactShadow(
      c,
      k.center + const Offset(0, 8),
      k.width * 1.05,
      k.height * 1.05,
      opacity: 0.25,
    );
    c.drawRect(k, Paint()..color = _kGlass.lead);
    for (final side in [
      Rect.fromLTRB(k.left, k.top, k.right, k.top + 10),
      Rect.fromLTRB(k.left, k.bottom - 10, k.right, k.bottom),
      Rect.fromLTRB(k.left, k.top + 10, k.left + 10, k.bottom - 10),
      Rect.fromLTRB(k.right - 10, k.top + 10, k.right, k.bottom - 10),
    ]) {
      paintCarvedBlock(
        c,
        side,
        side.top >= k.bottom - 11 ? 6 : 0,
        _kGlass,
        radius: 1,
      );
    }
  }

  void _bakeFountain(Canvas c, Offset v) {
    paintCarvedDisc(c, v, 50, 40, 9, _kGlass);
    c.drawOval(
      Rect.fromCenter(center: v, width: 76, height: 58),
      Paint()..color = const Color(0xFF1A110D),
    );
    c.drawOval(
      Rect.fromCenter(center: v + const Offset(0, 2), width: 22, height: 16),
      Paint()..color = const Color(0xFF070403),
    );
    final crack = Paint()
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF120B08).withValues(alpha: 0.8);
    const angles = [0.35, 1.62, 2.44, 3.9, 5.31];
    const lengths = [18.0, 26.0, 13.0, 21.0, 16.0];
    for (var i = 0; i < angles.length; i++) {
      final u = Offset(cos(angles[i]), sin(angles[i]) * 0.8);
      c.drawLine(v + u * 50, v + u * (50 + lengths[i]), crack);
    }
  }

  void _drawGlassGarth(Canvas canvas, DungeonRoom room) {
    final g = room.garth;
    final field = burnFieldFor(room);
    if (g == null || field == null) return;
    final f = garthField(room, g);
    final done = hasStar(g.starIndex);
    final cw = g.cell;

    for (var i = 0; i < g.cols * g.rows; i++) {
      final c = garthCentre(room, g, i);
      final cell = Rect.fromCenter(center: c, width: cw, height: cw);
      final pane = Path()..addRect(cell.deflate(1.5));
      switch (field.at(i)) {
        case BurnCell.stone:
          // A fallen column: carved stone standing proud of the glass.
          paintPane(canvas, pane, const Color(0xFF140C08), _kGlass, lead: 2.6);
          paintCarvedBlock(
            canvas,
            Rect.fromLTRB(
              cell.left + 6,
              cell.top + 4,
              cell.right - 6,
              cell.bottom - 14,
            ),
            8,
            _kGlass,
          );
        case BurnCell.wet:
        case BurnCell.wetVine:
          paintPane(
            canvas,
            pane,
            const Color(0xFF1C3A48),
            _kGlass,
            lead: 2.6,
            opacity: 0.92,
          );
          paintStreak(canvas, cell.deflate(8), opacity: 0.35);
          if (field.at(i) == BurnCell.wetVine) {
            _drawVineTuft(canvas, c, cw, const Color(0xFF4E7F5E));
          }
        case BurnCell.ash:
          // Spent, and NOTHING will take here again: smoked, cracked glass.
          paintPane(canvas, pane, const Color(0xFF3A3431), _kGlass, lead: 2.6);
          final crack = Paint()
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF0E0B0A).withValues(alpha: 0.85);
          canvas.drawLine(
            c + Offset(-cw * 0.3, -cw * 0.1),
            c + Offset(-cw * 0.02, cw * 0.06),
            crack,
          );
          canvas.drawLine(
            c + Offset(-cw * 0.02, cw * 0.06),
            c + Offset(cw * 0.26, -cw * 0.2),
            crack,
          );
          canvas.drawLine(
            c + Offset(-cw * 0.02, cw * 0.06),
            c + Offset(cw * 0.06, cw * 0.32),
            crack,
          );
          final flake = Paint()
            ..color = const Color(0xFFB0A89E).withValues(alpha: 0.4);
          for (var k = 0; k < 5; k++) {
            final a = (i * 7 + k * 11) % 17 / 17.0;
            final r2 = (i * 5 + k * 13) % 19 / 19.0;
            canvas.drawCircle(
              c + Offset((a - 0.5) * cw * 0.7, (r2 - 0.5) * cw * 0.7),
              1.4,
              flake,
            );
          }
        case BurnCell.vine:
          paintPane(
            canvas,
            pane,
            const Color(0xFF2E4A22),
            _kGlass,
            lead: 2.6,
            opacity: 0.95,
          );
          _drawVineTuft(canvas, c, cw, const Color(0xFF8FCF6A));
        case BurnCell.soil:
          paintPane(
            canvas,
            pane,
            _kGlass.frostAt(i),
            _kGlass,
            lead: 2.6,
            opacity: 0.8,
          );
          for (var k = -1; k <= 1; k++) {
            canvas.drawLine(
              c + Offset(-cw * 0.3, k * 10.0),
              c + Offset(cw * 0.3, k * 10.0),
              Paint()
                ..strokeWidth = 1.1
                ..color = const Color(0x33B08458),
            );
          }
      }
    }
    paintLead(canvas, Path()..addRect(f), _kGlass, width: 3.4);

    // THE WIND over the whole field: which way the fire will run next.
    final (dc, dr) = field.wind.delta;
    final dir = Offset(dc.toDouble(), dr.toDouble());
    final across = Offset(-dir.dy, dir.dx);
    if (_fx.ready) {
      for (var i = 0; i < 9; i++) {
        final t = ((_time * 0.28) + i / 9.0) % 1.0;
        final lane = (i - 4) * (f.shortestSide / 9);
        final span = f.longestSide * 0.6;
        final p = f.center + across * lane + dir * ((t - 0.5) * 2 * span);
        if (!f.inflate(20).contains(p)) continue;
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          3.2,
          _kGlass.gold.withValues(alpha: 0.4 * sin(t * pi)),
        );
        canvas.drawLine(
          p - dir * 14,
          p,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.4
            ..color = _kGlass.gold.withValues(alpha: 0.22 * sin(t * pi)),
        );
      }
    }

    // THE HEAD: the one pane alive on the field.
    final h = field.head;
    if (h != null && !done) {
      final at = garthCentre(room, g, h);
      final cell = Rect.fromCenter(center: at, width: cw, height: cw);
      final smouldering = field.smoulder > 0;
      final beat = 1 - (burnBeat / _kBurnBeat).clamp(0.0, 1.0);
      _heatPane(
        canvas,
        Path()..addRect(cell.deflate(1.5)),
        (smouldering ? 0.4 : 0.7) + 0.2 * beat + 0.08 * sin(_time * 7),
      );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          at,
          (smouldering ? 34.0 : 50.0) + 10 * burnFlash,
          (smouldering ? const Color(0xFFB4542A) : const Color(0xFFFF9A3C))
              .withValues(alpha: smouldering ? 0.26 : 0.4),
        );
      }
      for (var i = 0; i < 3; i++) {
        final ph = _time * 4.0 + i * 2.1;
        final hgt =
            (smouldering ? 10.0 : 20.0) * (0.7 + 0.5 * beat) + 5.0 * sin(ph);
        _drawFlame(
          canvas,
          Offset(at.dx + (i - 1) * 9.0 + sin(ph * 0.8) * 2.0, at.dy + 10),
          hgt,
          outer: smouldering
              ? const Color(0xFF8A4520)
              : const Color(0xFFE2701F),
          phase: ph,
        );
      }
      // Where it will go NEXT — the fair warning before every beat.
      final next = field.downwind(h);
      if (next != null) {
        final to = garthCentre(room, g, next);
        final takes = field.at(next) == BurnCell.vine;
        canvas.drawRect(
          Rect.fromCenter(center: to, width: cw - 12, height: cw - 12),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = (takes ? _kGlass.gold : const Color(0xFF7A6656))
                .withValues(alpha: 0.3 + 0.4 * beat),
        );
      }
    }
  }

  /// THE BURN RING: the progress display, wrapped around the vane — one pane
  /// per square the garden owes, each taking fire as a square burns.
  void _drawBurnRing(Canvas canvas, Offset c, BurnGarth g, BurnField field) {
    final goal = g.coverageGoal;
    if (goal <= 0 || goal > 64) return;
    final fill = poolShown.clamp(0.0, 1.0);
    final burnt = field.burntThisFire.clamp(0, goal);
    const r0 = 58.0, r1 = 70.0;
    for (var i = 0; i < goal; i++) {
      final a0 = -pi / 2 + i * 2 * pi / goal + 0.02;
      final a1 = -pi / 2 + (i + 1) * 2 * pi / goal - 0.02;
      final pane = ellipseSectorPath(
        c,
        r0,
        r0 * 0.8,
        r1,
        r1 * 0.8,
        a0,
        a1,
        steps: 3,
      );
      final on = i < burnt;
      paintPane(
        canvas,
        pane,
        on ? _kGlass.heat(0.82) : _kGlass.frostAt(i),
        _kGlass,
        lead: 2.0,
        opacity: on ? 1.0 : 0.85,
      );
    }
    if (_fx.ready && fill > 0.02) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        r1 * (1.1 + 0.25 * fill),
        const Color(0xFFFF9A3C).withValues(alpha: 0.08 + 0.2 * fill),
      );
    }
  }

  // ── Reliquary ───────────────────────────────────────────

  void _bakeShrine(Canvas c, Offset s) {
    // The rune ring, cut into the flags around the shrine.
    c.drawOval(
      Rect.fromCenter(center: s + const Offset(0, 16), width: 150, height: 96),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = _kGlass.stoneFoot.withValues(alpha: 0.8),
    );
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      final p = s + const Offset(0, 16) + Offset(cos(a) * 75, sin(a) * 48);
      c.drawCircle(
        p,
        2.2,
        Paint()..color = _kGlass.goldDeep.withValues(alpha: 0.7),
      );
    }
    paintCarvedBlock(
      c,
      Rect.fromCenter(center: s + const Offset(0, 22), width: 100, height: 26),
      12,
      _kGlass,
    );
    paintCarvedBlock(
      c,
      Rect.fromCenter(center: s + const Offset(0, 2), width: 62, height: 18),
      9,
      _kGlass,
    );
  }

  void _drawReliquaryLive(Canvas canvas, Offset s) {
    final p = s + const Offset(0, -12);
    final breathe = 0.5 + 0.5 * sin(_time * 1.4);
    paintRondel(
      canvas,
      p,
      15,
      _kGlass,
      fill: _kGlass.heat(0.5 + 0.12 * breathe),
    );
    paintStreak(canvas, Rect.fromCircle(center: p, radius: 11), opacity: 0.6);
    _drawFlame(canvas, p + const Offset(0, -6), 24, phase: 1.1);
  }

  // ── Vestry: the fresco is a story window ────────────────

  Rect _frescoPanel(DungeonRoom room) => Rect.fromCenter(
    center: Offset(room.bounds.center.dx, room.bounds.top + 120),
    width: 460,
    height: 130,
  );

  List<Offset> _frescoCensers(Rect panel) => [
    Offset(panel.left + 50, panel.center.dy - 6),
    Offset(panel.left + 190, panel.center.dy - 2),
    Offset(panel.left + 330, panel.center.dy - 6),
  ];

  Offset _frescoBell(Rect panel) =>
      Offset(panel.right - 60, panel.center.dy - 6);

  /// The chain the fresco's flame walks: censer to censer, then the bell.
  Offset _frescoChainPoint(Rect panel, double t) {
    final pts = [..._frescoCensers(panel), _frescoBell(panel)];
    final seg = (t * (pts.length - 1)).clamp(0.0, pts.length - 1.001);
    final i = seg.floor();
    final u = seg - i;
    final a = pts[i], b = pts[i + 1];
    final mid = Offset.lerp(a, b, 0.5)! + const Offset(0, 24);
    final w = 1 - u;
    return a * (w * w) + mid * (2 * w * u) + b * (u * u);
  }

  void _bakeFresco(Canvas c, DungeonRoom room) {
    final panel = _frescoPanel(room);
    paintCarvedBlock(c, panel.inflate(12), 10, _kGlass, radius: 6);
    c.drawRect(panel.inflate(2), Paint()..color = _kGlass.lead);
    final rng = GlassRng(glassSeed('fresco', panel));
    const cols = 9, rows = 3;
    for (var i = 0; i < cols; i++) {
      for (var k = 0; k < rows; k++) {
        final r = Rect.fromLTWH(
          panel.left + panel.width * i / cols,
          panel.top + panel.height * k / rows,
          panel.width / cols,
          panel.height / rows,
        );
        paintPane(
          c,
          Path()..addRect(r),
          Color.lerp(_kGlass.frostAt(rng.pick(5)), _kGlass.smoke, 0.35)!,
          _kGlass,
          lead: 2.0,
        );
      }
    }
    // The story, told in lead and coloured glass: the chain of censers, the
    // wind that carries the flame between them, the bell it rings.
    final chain = Path();
    final cs = _frescoCensers(panel);
    final pts = [...cs, _frescoBell(panel)];
    chain.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final mid = Offset.lerp(pts[i], pts[i + 1], 0.5)! + const Offset(0, 24);
      chain.quadraticBezierTo(mid.dx, mid.dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    c.drawPath(
      chain,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _kGlass.goldDeep,
    );
    for (final p in cs) {
      paintRondel(c, p, 9, _kGlass, fill: _kGlass.heat(0.3), lead: 2.2);
    }
    // The wind: a curl of pale glass.
    final sp = Offset(panel.left + 262, panel.center.dy - 34);
    final spiral = Path()..moveTo(sp.dx - 16, sp.dy + 2);
    spiral.quadraticBezierTo(sp.dx, sp.dy - 20, sp.dx + 14, sp.dy - 2);
    spiral.quadraticBezierTo(sp.dx + 2, sp.dy + 12, sp.dx - 5, sp.dy + 2);
    c.drawPath(
      spiral,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = _kGlass.lead,
    );
    c.drawPath(
      spiral,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFBFD4E0).withValues(alpha: 0.75),
    );
    final bell = _frescoBell(panel);
    final bellPath = _bellPath(bell, 16);
    paintPane(c, bellPath, _kGlass.heat(0.62), _kGlass, lead: 2.6);
    paintLead(c, Path()..addRect(panel), _kGlass, width: 4);
  }

  void _drawFrescoLive(Canvas canvas, DungeonRoom room) {
    final panel = _frescoPanel(room);
    // The story, re-told for ever: a flame walks the chain, rings the bell,
    // and the bell's glass flares.
    const loop = 6.5;
    final t = (_time % loop) / loop;
    if (t < 0.8) {
      final p = _frescoChainPoint(panel, t / 0.8);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p,
          16,
          _kGlass.live.withValues(alpha: 0.55),
        );
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          5,
          _kGlass.liveCore.withValues(alpha: 0.9),
        );
      }
    } else {
      final ring = (t - 0.8) / 0.2;
      final bell = _frescoBell(panel);
      _heatPane(canvas, _bellPath(bell, 16), 0.95 * (1 - ring * 0.6));
      canvas.drawCircle(
        bell,
        18 + ring * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _kGlass.liveCore.withValues(alpha: 0.5 * (1 - ring)),
      );
    }
  }

  void _bakeHook(Canvas c, Offset p) {
    final hook = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = const Color(0xFF4A3A2E);
    paintContactShadow(c, p + const Offset(0, 30), 16, 5, opacity: 0.35);
    c.drawLine(p, p + const Offset(0, 18), hook);
    c.drawCircle(p + const Offset(0, 22), 4, hook);
  }

  // ── Bell gallery ────────────────────────────────────────

  Offset _bellOculus(IncenseChain chain) =>
      chain.bellPosition + const Offset(0, -4);

  Path _bellPath(Offset c, double r) => Path()
    ..moveTo(c.dx - r * 0.9, c.dy + r * 0.7)
    ..quadraticBezierTo(c.dx - r * 0.85, c.dy - r * 0.7, c.dx, c.dy - r)
    ..quadraticBezierTo(
      c.dx + r * 0.85,
      c.dy - r * 0.7,
      c.dx + r * 0.9,
      c.dy + r * 0.7,
    )
    ..close();

  void _bakeGalleryBeams(Canvas c, DungeonRoom room) {
    for (final chain in room.incenseChains) {
      // Beams span the WHOLE of both runs, so neither route's censers hang
      // from nothing.
      final all = <Offset>[...chain.nodes, chain.bellPosition];
      for (final route in room.vesperRoutes) {
        all.addAll(route.chainNodes[chain.id] ?? const []);
      }
      var top = all.first.dy, lo = all.first.dx, hi = all.first.dx;
      for (final p in all) {
        top = min(top, p.dy);
        lo = min(lo, p.dx);
        hi = max(hi, p.dx);
      }
      final beamY = top - 58;
      paintCarvedBlock(
        c,
        Rect.fromLTRB(lo - 34, beamY - 7, hi + 34, beamY + 1),
        8,
        _kGlass,
        radius: 2,
        topColor: const Color(0xFF4A3A2C),
      );
      for (final x in [lo - 28, hi + 28]) {
        c.drawPath(
          Path()
            ..moveTo(x - 7, beamY + 9)
            ..lineTo(x + 7, beamY + 9)
            ..lineTo(x, beamY + 20)
            ..close(),
          Paint()..color = _kGlass.stoneFace,
        );
      }
    }
  }

  void _drawBellWindows(Canvas canvas, DungeonRoom room) {
    for (final chain in room.incenseChains) {
      final w = (_bellWindow[chain.id] ?? 0).clamp(0.0, 1.0);
      if (w <= 0) continue;
      final o = _bellOculus(chain);
      // The oculus floods from its heart outward as the bell rings.
      final r = 26 * Curves.easeOutCubic.transform(w);
      _heatPane(
        canvas,
        Path()..addOval(Rect.fromCircle(center: o, radius: r)),
        0.62 + 0.08 * sin(_time * 1.6 + o.dx),
      );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          o,
          34 + 20 * w,
          _kGlass.live.withValues(alpha: 0.16 * w),
        );
      }
    }
  }

  /// The two censer stands (Star 3's decision, §6.1 REWORK). Both stand cold
  /// and equal until one is lit; the declared one's glass takes fire, and the
  /// ghost of the run it would swing out to is sketched from the other — so
  /// the choice can be WEIGHED by looking, not by committing.
  void _drawVesperStands(Canvas canvas, DungeonRoom room) {
    if (room.vesperRoutes.isEmpty || hasStar(2)) return;
    final declared = vesperRouteId;
    for (final route in room.vesperRoutes) {
      final chosen = route.id == declared;
      final p = route.standPosition;
      if (!chosen) {
        // DOTTED, not drawn: a dotted line reads as a way you could go.
        final ghost = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = _kGlass.gold.withValues(alpha: 0.16);
        for (final chain in room.incenseChains) {
          final nodes = route.chainNodes[chain.id] ?? chain.nodes;
          final live = chainNodes(chain);
          if (nodes.length == live.length) {
            var same = true;
            for (var k = 0; k < nodes.length; k++) {
              if (nodes[k] != live[k]) {
                same = false;
                break;
              }
            }
            if (same) continue;
          }
          final pts = [...nodes, chain.bellPosition];
          for (var i = 0; i < pts.length - 1; i++) {
            final a = pts[i];
            final bp = pts[i + 1];
            final steps = ((bp - a).distance / 11).round().clamp(2, 40);
            for (var k = 0; k < steps; k++) {
              canvas.drawLine(
                Offset.lerp(a, bp, k / steps)!,
                Offset.lerp(a, bp, (k + 0.45) / steps)!,
                ghost,
              );
            }
          }
          for (final n in nodes) {
            canvas.drawCircle(
              n,
              5,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2
                ..color = ghost.color,
            );
          }
        }
      }
      // The spot you stand on to declare the run: a gold-rimmed glass rondel
      // set in the carved foot.
      final spot = p + const Offset(0, 28);
      final swing = chosen
          ? Curves.easeOutCubic.transform(_routeSwapT.clamp(0.0, 1.0))
          : 0.0;
      canvas.save();
      canvas.translate(spot.dx, spot.dy);
      canvas.scale(1, 0.4);
      paintRondel(
        canvas,
        Offset.zero,
        26,
        _kGlass,
        fill: chosen ? _kGlass.heat(0.35 + 0.4 * swing) : _kGlass.frostAt(2),
        rim: chosen ? 1.0 : 0.6,
      );
      canvas.restore();
      final iron = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = (chosen ? _kGlass.gold : const Color(0xFF5A4636)).withValues(
          alpha: 0.9,
        );
      canvas.drawLine(p + const Offset(0, 26), p + const Offset(0, -18), iron);
      canvas.drawLine(
        p + const Offset(-16, -14),
        p + const Offset(16, -14),
        iron,
      );
      for (final dx in const [-14.0, 0.0, 14.0]) {
        canvas.drawArc(
          Rect.fromCircle(center: p + Offset(dx, -2), radius: 7),
          0,
          pi,
          false,
          iron,
        );
      }
      if (chosen) {
        _drawFlame(canvas, p + const Offset(0, 4), 8 + 10 * swing, phase: 2.4);
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p,
            26 + 10 * swing,
            const Color(0xFFFF8A50).withValues(alpha: 0.18 * swing),
          );
        }
      } else if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.mote!,
          p + const Offset(6, -2),
          4,
          const Color(0xFFFF8A50).withValues(
            alpha: 0.14 + 0.10 * (0.5 + 0.5 * sin(_time * 2.0 + p.dy)),
          ),
        );
      }
    }
  }

  void _drawIncenseChains(Canvas canvas, DungeonRoom room) {
    for (final chain in room.incenseChains) {
      final rung = bellsRung.contains(chain.id) || hasStar(2);
      final checkpoint = _chainCheckpoints[chain.id] ?? 0;
      final flame = _vesperFlames[chain.id];
      final nodes = chainNodes(chain);
      final pts = [...nodes, chain.bellPosition];
      final beamY = () {
        final all = <Offset>[...chain.nodes, chain.bellPosition];
        for (final route in room.vesperRoutes) {
          all.addAll(route.chainNodes[chain.id] ?? const []);
        }
        return all.map((p) => p.dy).reduce(min) - 58;
      }();
      // Hangers from the beam to every censer and the bell.
      final hanger = Paint()
        ..strokeWidth = 1.3
        ..color = const Color(0xFF5A463A).withValues(alpha: 0.6);
      for (final p in pts) {
        canvas.drawLine(
          Offset(p.dx, beamY + 8),
          Offset(p.dx, p.dy - 8),
          hanger,
        );
      }
      final linkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = (rung ? _kGlass.gold : const Color(0xFF5A463A)).withValues(
          alpha: rung ? 0.55 : 0.5,
        );
      final link = Paint()
        ..strokeWidth = 1.2
        ..color = linkPaint.color.withValues(alpha: rung ? 0.4 : 0.3);
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
        const steps = 9;
        for (var k = 1; k < steps; k++) {
          final t = k / steps;
          final u = 1 - t;
          final pt = a * (u * u) + mid * (2 * u * t) + bp * (t * t);
          final tan = (mid - a) * (2 * u) + (bp - mid) * (2 * t);
          final len = tan.distance;
          if (len < 0.01) continue;
          final n = Offset(-tan.dy, tan.dx) / len;
          canvas.drawLine(pt - n * 2.6, pt + n * 2.6, link);
        }
      }
      // Censers: lidded iron cups, each with a bead of glass in its belly that
      // keeps a coal alive once the flame has reached it.
      for (var i = 0; i < nodes.length; i++) {
        final p = nodes[i];
        final reached = rung || i <= checkpoint;
        final iron = (reached ? _kGlass.gold : const Color(0xFF5A4636))
            .withValues(alpha: 0.9);
        canvas.drawLine(
          p + const Offset(0, -14),
          p + const Offset(0, -8),
          Paint()
            ..strokeWidth = 1.4
            ..color = iron.withValues(alpha: 0.7),
        );
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - 8, p.dy - 5)
            ..lineTo(p.dx, p.dy - 12)
            ..lineTo(p.dx + 8, p.dy - 5)
            ..close(),
          Paint()..color = const Color(0xFF2E2219),
        );
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 10),
          0,
          pi,
          false,
          Paint()..color = const Color(0xFF221610),
        );
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: 10),
          0,
          pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = iron,
        );
        paintRondel(
          canvas,
          p + const Offset(0, 4),
          3.6,
          _kGlass,
          fill: reached
              ? _kGlass.heat(0.7 + 0.15 * sin(_time * 2.6 + i * 1.4))
              : _kGlass.smoke,
          rim: reached ? 0.9 : 0.4,
          lead: 1.4,
        );
        if (reached && _fx.ready && !rung) {
          drawGlow(
            canvas,
            _fx.mote!,
            p + const Offset(0, 4),
            7,
            const Color(0xFFFF8A50).withValues(
              alpha: 0.26 + 0.14 * (0.5 + 0.5 * sin(_time * 2.6 + i * 1.4)),
            ),
          );
        }
      }
      // The ember bell: cast bronze, hung in its headstock before the oculus.
      final bp = chain.bellPosition;
      canvas.drawRect(
        Rect.fromCenter(
          center: bp + const Offset(0, -20),
          width: 30,
          height: 7,
        ),
        Paint()..color = const Color(0xFF31251B),
      );
      final bronze = rung ? const Color(0xFFB8893A) : const Color(0xFF5A4630);
      canvas.drawPath(
        _bellPath(bp, 16),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Color.lerp(bronze, Colors.black, 0.35)!,
              Color.lerp(bronze, Colors.white, rung ? 0.35 : 0.12)!,
              bronze,
              Color.lerp(bronze, Colors.black, 0.5)!,
            ],
            stops: const [0.0, 0.35, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: bp, radius: 16)),
      );
      canvas.drawCircle(
        bp + const Offset(0, 13.6),
        3.2,
        Paint()..color = Color.lerp(bronze, Colors.black, 0.3)!,
      );
      if (rung && _bellTollFx > 0) {
        final t = 1 - (_bellTollFx / 2.2);
        for (var k = 0; k < 2; k++) {
          canvas.drawCircle(
            bp,
            20 + t * 70 + k * 16,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8 - k * 0.6
              ..color = _kGlass.liveCore.withValues(
                alpha: (0.5 * (1 - t) - k * 0.15).clamp(0.0, 0.5),
              ),
          );
        }
      }
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

  // ── High altar ──────────────────────────────────────────

  List<Rect> _altarBellPanes(Offset c) => [
    for (var i = -1; i <= 1; i++)
      Rect.fromCenter(center: c + Offset(i * 42.0, 60), width: 16, height: 18),
  ];

  void _bakeAltar(Canvas c, Offset a) {
    // The dais: two broad steps and the altar block. Big tops stay DARK and
    // jointed — a wide pale slab reads as a panel, not as stone.
    final lower = Rect.fromLTRB(a.dx - 100, a.dy - 30, a.dx + 100, a.dy + 50);
    final upper = Rect.fromLTRB(a.dx - 66, a.dy - 22, a.dx + 66, a.dy + 26);
    paintCarvedBlock(c, lower, 16, _kGlass, topColor: const Color(0xFF3A2C24));
    paintCarvedBlock(c, upper, 10, _kGlass, topColor: const Color(0xFF45352B));
    final joint = Paint()
      ..strokeWidth = 1.2
      ..color = _kGlass.joint.withValues(alpha: 0.6);
    for (final x in [-66.0, -22.0, 22.0, 66.0]) {
      c.drawLine(
        Offset(a.dx + x, lower.top),
        Offset(a.dx + x, upper.top),
        joint,
      );
      c.drawLine(
        Offset(a.dx + x, upper.bottom + 10),
        Offset(a.dx + x, lower.bottom),
        joint,
      );
    }
    for (final x in [-33.0, 0.0, 33.0]) {
      c.drawLine(
        Offset(a.dx + x, upper.top),
        Offset(a.dx + x, upper.bottom),
        joint,
      );
    }
    paintCarvedBlock(
      c,
      Rect.fromLTRB(a.dx - 36, a.dy - 20, a.dx + 36, a.dy + 2),
      16,
      _kGlass,
      topColor: const Color(0xFF524036),
    );
    // One lancet in the dais face per bell: the altar keeps the tally.
    for (final r in _altarBellPanes(a)) {
      paintPane(
        c,
        lancetPath(r, AxisDirection.up),
        _kGlass.frostAt(1),
        _kGlass,
        lead: 2.2,
      );
    }
    // The black flame's vessel, set in the altar top.
    _bakeObsidianVessel(c, a + const Offset(0, -9));
    for (final side in const [-1.0, 1.0]) {
      final base = a + Offset(side * 132, 34);
      paintContactShadow(c, base + const Offset(0, 3), 30, 9, opacity: 0.4);
      final pole = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2E211A);
      c.drawLine(base, base + const Offset(0, -42), pole);
      c.drawLine(
        base + const Offset(-14, -30),
        base + const Offset(14, -30),
        pole,
      );
    }
  }

  void _bakeObsidianVessel(Canvas c, Offset p) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1, 0.5);
    paintRondel(c, Offset.zero, 24, _kGlass, fill: const Color(0xFF120A14));
    c.restore();
  }

  void _drawAltarLive(Canvas canvas, Offset a) {
    // The tally: a bell's lancet takes fire as each bell rings.
    final panes = _altarBellPanes(a);
    final chains = layout.rooms['bell_gallery']?.incenseChains ?? const [];
    for (var i = 0; i < panes.length && i < chains.length; i++) {
      final rung = bellsRung.contains(chains[i].id) || hasStar(2);
      if (!rung) continue;
      _heatPane(
        canvas,
        lancetPath(panes[i], AxisDirection.up),
        0.78 + 0.08 * sin(_time * 2 + i),
      );
    }
    for (final side in const [-1.0, 1.0]) {
      final base = a + Offset(side * 132, 34);
      _drawFlame(canvas, base + const Offset(0, -44), 13, phase: side * 2.0);
      _drawFlame(canvas, base + const Offset(-14, -32), 10, phase: side * 3.1);
      _drawFlame(canvas, base + const Offset(14, -32), 10, phase: side * 1.2);
    }
    final wake = _altarWake.clamp(0.0, 1.0);
    final vessel = a + const Offset(0, -9);
    if (wake > 0) {
      canvas.save();
      canvas.translate(vessel.dx, vessel.dy);
      canvas.scale(1, 0.5);
      canvas.drawCircle(
        Offset.zero,
        24 * wake,
        Paint()
          ..color = Color.lerp(
            _kVioletDeep,
            _kViolet,
            0.4 + 0.2 * sin(_time * 2),
          )!.withValues(alpha: 0.9),
      );
      canvas.restore();
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          vessel - const Offset(0, 18),
          66 * wake,
          _kViolet.withValues(alpha: 0.22 * wake),
        );
      }
      _drawFlame(
        canvas,
        vessel + const Offset(0, 4),
        56 * wake,
        core: const Color(0xFF35124A),
        outer: const Color(0xFF1A0A26),
        phase: 0.9,
      );
      _drawFlame(
        canvas,
        vessel + const Offset(0, 4),
        30 * wake,
        core: const Color(0xFFFF7A3C),
        outer: const Color(0xFF6E2A14),
        phase: 2.3,
      );
    }
    if (wake < 1) {
      // Dormant: one thin smoke thread rising from the cold vessel.
      final smoke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF6E5A4A).withValues(alpha: 0.30 * (1 - wake));
      final path = Path()..moveTo(vessel.dx, vessel.dy);
      for (var i = 1; i <= 4; i++) {
        path.quadraticBezierTo(
          vessel.dx + sin(_time * 1.1 + i * 1.7) * 10,
          vessel.dy - i * 18.0 + 9,
          vessel.dx + sin(_time * 1.1 + i * 1.7 + 0.8) * 6,
          vessel.dy - i * 18.0,
        );
      }
      canvas.drawPath(path, smoke);
    }
  }

  // ── Sanctum: the shattered rose ─────────────────────────

  List<RosePane> _roostRose(Offset c) =>
      _cathedralRoseCache.putIfAbsent('roost@${c.dx},${c.dy}', () {
        final rng = GlassRng(
          glassSeed('roost', Rect.fromCircle(center: c, radius: 130)),
        );
        return buildRose(c, [
          (0.0, 26.0, 6, 0.3),
          (26.0, 60.0, 11, 0.0),
          (60.0, 96.0, 16, 0.2),
          (96.0, 130.0, 22, 0.05),
        ]).where((p) => p.ring < 2 || rng.next() > 0.22).toList();
      });

  void _bakeRoost(Canvas c, DungeonRoom room, Offset g) {
    paintContactShadow(c, g + const Offset(0, 6), 290, 180, opacity: 0.3);
    for (final p in _roostRose(g)) {
      paintPane(
        c,
        p.path,
        Color.lerp(_kGlass.smoke, _kVioletDeep, 0.35)!,
        _kGlass,
        lead: 2.4,
      );
    }
    // Char where the missing panes burned out.
    final char = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF3A2A20).withValues(alpha: 0.7);
    for (var i = 0; i < 10; i++) {
      final a = i * 0.628 + 0.25;
      c.drawLine(
        g + Offset(cos(a), sin(a)) * 132,
        g + Offset(cos(a), sin(a)) * 150,
        char,
      );
    }
    // Broken arches behind the roost: carved stones along the fallen curve.
    for (final (centre, r, a0, sweep) in [
      (g + const Offset(-150, -110), 56.0, pi * 1.1, pi * 0.55),
      (g + const Offset(160, -96), 48.0, pi * 1.35, pi * 0.5),
    ]) {
      const n = 5;
      for (var k = 0; k < n; k++) {
        final a = a0 + sweep * (k + 0.5) / n;
        final p = centre + Offset(cos(a), sin(a)) * r;
        paintCarvedBlock(
          c,
          Rect.fromCenter(center: p, width: 16, height: 11),
          9,
          _kGlass,
          radius: 2,
        );
      }
    }
  }

  void _drawRoostLive(Canvas canvas, DungeonRoom room, Offset g) {
    final wake = _roostWake.clamp(0.0, 1.0);
    if (wake <= 0) return;
    // The roost's glass burns violet from its heart outward as the Simurgh
    // descends, and keeps a slow ember pulse while it fights.
    for (final p in _roostRose(g)) {
      final r = (p.mid - g).distance / 130;
      final k = ((wake * 1.5 - r) / 0.5).clamp(0.0, 1.0);
      if (k <= 0) continue;
      // Deep violet, with a pulse running out through it — it is a whole
      // floor of glass in a FIGHT, so it smoulders under the telegraph's
      // warnings rather than competing with them.
      final pulse = 0.5 + 0.5 * sin(_time * 2.2 - r * 5 + p.index);
      paintPaneFill(
        canvas,
        p.path,
        Color.lerp(_kVioletDeep, _kViolet, 0.12 + 0.38 * pulse)!,
        opacity: 0.36 * k,
      );
      paintLead(canvas, p.path, _kGlass, width: 2.4, opacity: k);
    }
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        g,
        150 * wake,
        _kViolet.withValues(alpha: 0.10 * wake),
      );
      for (var i = 0; i < 5; i++) {
        final a = i * 1.256 + _time * 0.5;
        final rr = 70 + 28 * sin(_time * 0.9 + i * 2.0);
        final p = g + Offset(cos(a) * rr, sin(a) * rr * 0.7);
        drawGlow(
          canvas,
          _fx.mote!,
          p,
          4.5,
          const Color(0xFFFFB46B).withValues(
            alpha: (0.18 + 0.12 * (0.5 + 0.5 * sin(_time * 3 + i))) * wake,
          ),
        );
      }
    }
  }

  /// SIMURGH'S TELEGRAPH (§7): phantom braziers ringing the roost in the
  /// choir's own arrangement, re-lit in this run's remembered order. Each
  /// takes its turn with a readable FLARE before the pillar of flame lands.
  void _drawSimurghTelegraph(Canvas canvas, DungeonRoom room) {
    if (isRaid || !guardianAwake) return;
    final g = room.guardian;
    if (g == null || hasStar(g.starIndex)) return;
    final spots = simurghTelegraphSpots(room);
    if (spots.isEmpty) return;
    // The phantom glass, always present once the Simurgh is up.
    for (final p in spots) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.scale(1, 0.45);
      paintRondel(
        canvas,
        Offset.zero,
        18,
        _kGlass,
        fill: const Color(0xFF1A0E1E),
        rim: 0.5,
        lead: 2.4,
      );
      canvas.restore();
    }
    _simurghPillars.forEach((rank, t) {
      final idx = riteBrazierAt(rank);
      if (idx < 0 || idx >= spots.length) return;
      final p = spots[idx];
      if (t < _kTelegraphWindup) {
        // THE FLARE — the fair warning.
        final u = (t / _kTelegraphWindup).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.scale(1, 0.45);
        canvas.drawCircle(
          Offset.zero,
          18,
          Paint()..color = _kViolet.withValues(alpha: 0.3 + 0.5 * u),
        );
        canvas.restore();
        canvas.drawOval(
          Rect.fromCenter(
            center: p,
            width: _kTelegraphRadius * 2 * (1.35 - 0.35 * u),
            height: _kTelegraphRadius * (1.35 - 0.35 * u),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 + 1.6 * u
            ..color = const Color(
              0xFFFF8A50,
            ).withValues(alpha: 0.18 + 0.32 * u),
        );
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.mote!,
            p,
            4 + 8 * u,
            const Color(0xFFFFD27A).withValues(alpha: 0.24 + 0.36 * u),
          );
        }
      } else {
        // THE PILLAR — black-flame fire standing where the warning stood.
        final u = ((t - _kTelegraphWindup) / (1 - _kTelegraphWindup)).clamp(
          0.0,
          1.0,
        );
        final fade = 1.0 - u * u;
        canvas.drawOval(
          Rect.fromCenter(
            center: p,
            width: _kTelegraphRadius * 2,
            height: _kTelegraphRadius,
          ),
          Paint()
            ..color = const Color(0xFF6E2A14).withValues(alpha: 0.22 * fade),
        );
        if (_fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            p - const Offset(0, 20),
            _kTelegraphRadius * 1.1,
            const Color(0xFF8A2AA0).withValues(alpha: 0.22 * fade),
          );
        }
        _drawFlame(
          canvas,
          p + const Offset(0, 6),
          88 * fade,
          core: const Color(0xFF35124A),
          outer: const Color(0xFF1A0A26),
          phase: rank * 1.7,
        );
        _drawFlame(
          canvas,
          p + const Offset(0, 6),
          46 * fade,
          core: const Color(0xFFFF7A3C),
          outer: const Color(0xFF6E2A14),
          phase: rank * 2.3,
        );
      }
    });
  }

  // ── Kept as they were: shapes, the epitaph, the evidence ─

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

  /// The Ember Epitaph: invisible at stage 0. Insight WRITES the maxim into
  /// the floor — an ember-quill draws each line in — then the garden planter
  /// settles in beside it. Plant, flame and gusts grow the blaze; when the
  /// third gust lands, a burn-front sweeps the script and the words stay lit
  /// in fire. Text painters are cached once; per-frame work is clip + paint.
  void _drawEmberEpitaph(Canvas canvas) {
    final won = discoveredClouds.contains(kFireEpitaphEggId);
    final stage = won ? 3 : epitaphStage;

    // The words are painted ON the mural's glass, the way a glazier paints
    // detail onto a pane: dark grisaille over the lit amber. An italic serif
    // ('serif' is Noto Serif on Android; elsewhere it falls back to the
    // system face, which is what this drew in before).
    List<TextPainter> painters(List<String> lines, TextStyle style) => [
      for (final line in lines)
        TextPainter(
          text: TextSpan(text: line, style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    const base = TextStyle(
      fontFamily: 'serif',
      fontSize: 14,
      fontStyle: FontStyle.italic,
      letterSpacing: 0.6,
    );
    // Ghost cipher: before insight finds it, the dead words sit in the
    // mural's upper half as near-invisible soot.
    _epitaphGhostLines ??= painters(
      kFireEpitaphScrambledLines,
      base.copyWith(color: const Color(0xFF0E0806).withValues(alpha: 0.16)),
    );
    // The quill's script stays SCRAMBLED — insight bares the writing, not
    // its meaning. Only the fire unscrambles it.
    _epitaphSootLines ??= painters(
      kFireEpitaphScrambledLines,
      base.copyWith(
        color: const Color(0xFF120A06).withValues(alpha: 0.82),
        fontWeight: FontWeight.w600,
      ),
    );
    // The fire turns the words themselves to glass: white-hot letters, each
    // held in its own lead. (A blurred shadow here was a per-frame blur.)
    _epitaphFireLead ??= painters(
      kFireEpitaphLines,
      base.copyWith(
        fontWeight: FontWeight.w600,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeJoin = StrokeJoin.round
          ..color = _kGlass.lead,
      ),
    );
    _epitaphFireLines ??= painters(
      kFireEpitaphLines,
      base.copyWith(color: _kGlass.liveCore, fontWeight: FontWeight.w600),
    );

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
          const Color(
            0xFFFFB46B,
          ).withValues(alpha: 0.55 + 0.25 * sin(_time * 9)),
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
        _epitaphFireLead![i].paint(canvas, pos);
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
            const Color(
              0xFFFF8A50,
            ).withValues(alpha: 0.10 + 0.05 * sin(_time * 2.4)),
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
    // A carved trough rising out of the flags as the last line is written.
    final rise = Curves.easeOutCubic.transform(planterIn);
    if (planterIn < 1) {
      canvas.saveLayer(
        Rect.fromCenter(center: p, width: 110, height: 70),
        Paint()..color = Colors.white.withValues(alpha: planterIn),
      );
    }
    final top = Rect.fromCenter(
      center: p + Offset(0, 4 - 6 * rise),
      width: 60,
      height: 18,
    );
    paintCarvedBlock(canvas, top, 4 + 8 * rise, _kGlass, radius: 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(top.deflate(4), const Radius.circular(3)),
      Paint()..color = const Color(0xFF1A0F09),
    );
    if (planterIn < 1) canvas.restore();
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
          const Color(
            0xFFFF8A50,
          ).withValues(alpha: 0.16 + 0.06 * sin(_time * 3.1)),
        );
      }
    }
  }

  /// THE ASH DRIFT (evidence channel 3): the whole sequence's downwind, laid
  /// in one direction across the choir floor. With the wax and the soot it
  /// says which way the rite ran — and it is genuinely load-bearing: without
  /// it, barely a tenth of orders are uniquely deducible; with it, two fifths.
  /// Twelve strokes on a fixed lattice; nothing per-frame but the draw.
  void _drawRiteAshDrift(Canvas canvas, DungeonRoom room) {
    final star = room.brazierStarIndex;
    if (star == null || hasStar(star)) return;
    final d = riteAshDrift;
    if (d == Offset.zero) return;
    final b = room.bounds;
    final n = Offset(-d.dy, d.dx); // across the drift
    final mark = _testimonyMark;
    final streak = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7A6249).withValues(alpha: 0.17 + 0.13 * mark);
    final tail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9A8168).withValues(alpha: 0.10 + 0.09 * mark);
    // A grain or two at the head of each streak, so the marks read as ash
    // that blew and settled rather than as scratches in the floor.
    final grain = Paint()
      ..color = const Color(0xFF9A8168).withValues(alpha: 0.13 + 0.10 * mark);
    for (var i = 0; i < 12; i++) {
      // Scattered, but a fixed lattice — never re-randomised per frame.
      final p = Offset(
        b.left + 90 + (((i * 7) % 11) / 11.0) * (b.width - 180),
        b.top + 80 + (((i * 5) % 7) / 7.0) * (b.height - 160),
      );
      final jog = n * (i.isEven ? 6.0 : -6.0);
      canvas.drawLine(p - d * 14 + jog, p + d * 14 + jog, streak);
      canvas.drawLine(p + d * 14 + jog, p + d * 28 + jog, tail);
      canvas.drawCircle(p + d * 30 + jog + n * 3, 1.3, grain);
      canvas.drawCircle(p + d * 22 + jog - n * 4, 1.0, grain);
    }
  }

  /// How much of brazier [i]'s testimony still survives: 1 until its own fire
  /// takes it, then eased away over [_kTestimonyFade].
  double _testimonyAlive(int i) => _testimonyFade[i] ?? 1.0;

  /// THE WAX (evidence channel 1): tallow run down the iron and set there.
  /// Lowest = lit first, burned longest. Three tiers, two braziers each, so
  /// the wax narrows the rite to eight candidates and never hands it over —
  /// and two braziers of one tier are drawn IDENTICALLY, or the tier would
  /// leak the rank.
  void _drawBrazierWax(
    Canvas canvas,
    DungeonRoom room,
    int i, {
    required bool body,
  }) {
    final alive = _testimonyAlive(i);
    if (alive <= 0.01) return;
    final t = testimonyFor(i);
    if (t == null) return;
    final p = room.braziers[i].position;
    final h = 6.0 + 26.0 * t.waxFill; // 10 · 20 · 32 px of set tallow
    final mark = _testimonyMark;

    if (body) {
      // The column of wax banked round the bowl's foot. Narrower than it was
      // (and tallow rather than bone-white), so the iron shows either side of
      // it — the HEIGHT is the evidence, not the bulk.
      final tallow = Paint()
        ..color = const Color(
          0xFFC6B189,
        ).withValues(alpha: (0.66 + 0.16 * mark) * alive);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx - 11, p.dy + 24)
          ..lineTo(p.dx - 8, p.dy + 22 - h)
          ..quadraticBezierTo(p.dx, p.dy + 17 - h, p.dx + 8, p.dy + 22 - h)
          ..lineTo(p.dx + 11, p.dy + 24)
          ..close(),
        tallow,
      );
      // The drips that got that far down before they set.
      final drip = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB8A37C).withValues(alpha: 0.5 * alive);
      for (final dx in const [-6.0, 0.0, 6.0]) {
        canvas.drawLine(
          Offset(p.dx + dx, p.dy + 21 - h * 0.72),
          Offset(p.dx + dx, p.dy + 22),
          drip,
        );
      }
      return;
    }

    // THE MELT LINE — the one edge the eye actually measures, so it is drawn
    // over the iron and left the brightest thing on the brazier.
    canvas.drawLine(
      Offset(p.dx - 9, p.dy + 21 - h),
      Offset(p.dx + 9, p.dy + 21 - h),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(
          0xFFF2E6C8,
        ).withValues(alpha: (0.62 + 0.25 * mark) * alive),
    );
  }

  /// Insight t2's ONE annotated link: a dotted arc drawn from the fire at the
  /// picked rank to the fire that followed it — one step of the deduction,
  /// worked out for you. Never more than one, and always the same one.
  void _drawTestimonyLink(Canvas canvas, DungeonRoom room) {
    final rank = _testimonyLinkRank;
    if (rank == null || _testimonyMark <= 0.02) return;
    if (rank + 1 >= riteOrder.length) return;
    final from = room.braziers[riteBrazierAt(rank)].position;
    final to = room.braziers[riteBrazierAt(rank + 1)].position;
    final a = 0.5 * _testimonyMark;
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE4C16A).withValues(alpha: a);
    // Dashed, so it reads as annotation over the world rather than a wire.
    for (final (f0, f1) in const [
      (0.10, 0.22),
      (0.32, 0.44),
      (0.54, 0.66),
      (0.76, 0.88),
    ]) {
      canvas.drawLine(
        Offset.lerp(from, to, f0)!,
        Offset.lerp(from, to, f1)!,
        ink,
      );
    }
    // An arrowhead at the later fire.
    final dir = to - from;
    final len = dir.distance;
    if (len < 1) return;
    final u = dir / len;
    final n = Offset(-u.dy, u.dx);
    final tip = to - u * 26;
    canvas.drawLine(tip, tip - u * 11 + n * 7, ink);
    canvas.drawLine(tip, tip - u * 11 - n * 7, ink);
  }

  // ── The garth: the wind, the grooves, the drift ─────────

  /// THE CROSSWIND, drawn first and under everything: soot streaking across
  /// the open garth on one scrolling phase. Eight short strokes — the wind has
  /// to be READABLE before a burn is committed, and it must cost nothing.
  void _drawCrosswind(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final dir = gardenWindVector;
    final across = Offset(-dir.dy, dir.dx);
    final c = b.center;
    final span = b.longestSide * 0.5;

    // The air itself: comets running downwind, bright head into a fading
    // tail so the DIRECTION is unmistakable. (These used to sit at alpha
    // 0.05 — present in the code and invisible on the screen.)
    for (var i = 0; i < 14; i++) {
      final lane = (i - 6.5) * (b.shortestSide / 14.5);
      final phase = (_time * 78 + i * 97) % (span * 2);
      final head = c + across * lane + dir * (phase - span);
      if (!b.inflate(60).contains(head)) continue;
      final len = 30.0 + (i.isEven ? 16.0 : 0.0);
      final breathe = 0.60 + 0.40 * sin(_time * 1.4 + i);
      // Tail: several segments, each fainter, so it reads as motion.
      for (var k = 0; k < 4; k++) {
        final t0 = head - dir * (len * k / 4);
        final t1 = head - dir * (len * (k + 1) / 4);
        canvas.drawLine(
          t1,
          t0,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.6 - k * 0.5
            ..color = const Color(
              0xFFBFAE97,
            ).withValues(alpha: (0.20 - k * 0.045) * breathe),
        );
      }
    }

    // THE LANES: the ash road. Every bed sits on a lane running downwind, and
    // a burn dusts everything behind it on that lane — so the lanes are drawn
    // through the bed centres as long arrows. This is the single thing that
    // makes the wind mean something instead of just moving.
    if (room.vineBeds.isNotEmpty) {
      final seen = <double>{};
      for (final bed in room.vineBeds) {
        // One arrow per lane: key by the across-axis coordinate.
        final key = (bed.position.dx * across.dx + bed.position.dy * across.dy)
            .roundToDouble();
        if (!seen.add(key)) continue;
        final from = bed.position - dir * 150;
        final to = bed.position + dir * 190;
        canvas.drawLine(
          from,
          to,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.4
            ..color = const Color(0xFFC4A35A).withValues(alpha: 0.16),
        );
        // Chevrons along the lane, marching downwind.
        for (var k = 0; k < 5; k++) {
          final march = ((_time * 0.35 + k * 0.2) % 1.0);
          final at = from + (to - from) * march;
          final wing = 7.0;
          canvas.drawPath(
            Path()
              ..moveTo(
                (at - dir * 7 + across * wing).dx,
                (at - dir * 7 + across * wing).dy,
              )
              ..lineTo(at.dx, at.dy)
              ..lineTo(
                (at - dir * 7 - across * wing).dx,
                (at - dir * 7 - across * wing).dy,
              ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..strokeCap = StrokeCap.round
              ..color = const Color(
                0xFFC4A35A,
              ).withValues(alpha: 0.30 * sin(march * pi).clamp(0.0, 1.0)),
          );
        }
      }
    }
  }

  /// The iron wind-cross on the dry fountain: the vane any Air creature swings
  /// a quarter. The pointer EASES round (never a snap) and the four cardinal
  /// pins stay put, so the turn reads as a mechanism and not a teleport.
  void _drawWindVane(Canvas canvas, Offset c) {
    final iron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF74613A).withValues(alpha: 0.8);
    // The cross's arms, joined at the hub with a tip on each end. These used
    // to float between r20 and r30 — four detached ticks at exactly N/E/S/W,
    // which reads as a reticle rather than ironwork.
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2 - pi / 2;
      final u = Offset(cos(a), sin(a));
      final across = Offset(-u.dy, u.dx);
      canvas.drawLine(c + u * 9, c + u * 27, iron);
      canvas.drawLine(c + u * 27 - across * 4, c + u * 27 + across * 4, iron);
    }
    // The vane itself, swung to the live quarter.
    final dir = gardenWindVector;
    final across = Offset(-dir.dy, dir.dx);
    final head = c + dir * 34;
    final arrow = Paint()
      ..color = const Color(0xFFC4A35A).withValues(alpha: 0.9);
    canvas.drawLine(
      c - dir * 26,
      head,
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFC4A35A).withValues(alpha: 0.85),
    );
    canvas.drawPath(
      Path()
        ..moveTo(head.dx, head.dy)
        ..lineTo(
          (head - dir * 14 + across * 8).dx,
          (head - dir * 14 + across * 8).dy,
        )
        ..lineTo(
          (head - dir * 14 - across * 8).dx,
          (head - dir * 14 - across * 8).dy,
        )
        ..close(),
      arrow,
    );
    // The tail feather, so the quarter reads at a glance.
    canvas.drawLine(c - dir * 26 + across * 9, c - dir * 26 - across * 9, iron);
    if (_fx.ready && gardenWindSwing < 1.0) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        46,
        const Color(0xFFBFD4E0).withValues(alpha: 0.16 * (1 - gardenWindSwing)),
      );
    }
  }

  /// THE FORECAST — where a burn's ash would land, shown BEFORE it is
  /// committed. Every grown bed shows a faint downwind streak (a plume waiting
  /// to happen); the bed the active creature is standing at shows a bright one
  /// with a ring on each groove it would dust.
  /// The votive flame of an ANSWERED groove: three small tongues standing in
  /// the carved cut, each on its own phase so a row of lit beds never
  /// flickers in lockstep. Deliberately small and low — this is a sigil
  /// alight in its channel, not a bed on fire.
  void _drawSigilFlame(Canvas canvas, Offset p, int seed) {
    for (var i = 0; i < 3; i++) {
      final ph = _time * 3.4 + i * 2.1 + seed * 0.7;
      final h = 13.0 + 5.0 * sin(ph);
      final x = p.dx + (i - 1) * 9.0 + sin(ph * 0.8) * 1.6;
      final base = Offset(x, p.dy + 9);
      Path tongue(double w, double hh) => Path()
        ..moveTo(base.dx - w, base.dy)
        ..quadraticBezierTo(
          base.dx - w * 0.7,
          base.dy - hh * 0.62,
          base.dx,
          base.dy - hh,
        )
        ..quadraticBezierTo(
          base.dx + w * 0.7,
          base.dy - hh * 0.62,
          base.dx + w,
          base.dy,
        )
        ..close();
      // Outer body, then a brighter heart inside it.
      canvas.drawPath(
        tongue(4.6, h),
        Paint()..color = const Color(0xFFE2701F).withValues(alpha: 0.70),
      );
      canvas.drawPath(
        tongue(2.4, h * 0.62),
        Paint()..color = const Color(0xFFFFDDA0).withValues(alpha: 0.85),
      );
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          base - Offset(0, h * 0.45),
          13,
          const Color(0xFFFFB25A).withValues(alpha: 0.26),
        );
      }
    }
  }

  void _drawPlumeForecast(Canvas canvas, DungeonRoom room) {
    final rules = ashGardenRules;
    if (rules == null) return;
    final active = creatures.isNotEmpty
        ? creatures[activeIndex].position
        : null;
    for (var i = 0; i < room.vineBeds.length; i++) {
      if (bedStateAt(i) != AshBedState.green) continue;
      final from = room.vineBeds[i].position;
      final near =
          active != null && (active - from).distance <= _kBedReach + 22;
      final ready = bedGrowthAt(i) >= 1.0;
      final targets = plumeTargetsAt(i);
      if (targets.isEmpty) continue;
      final alpha = near && ready ? 0.34 : 0.10;
      final streak = Paint()
        ..strokeWidth = near ? 3.0 : 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB9A891).withValues(alpha: alpha);
      var tail = from;
      for (final t in targets) {
        final to = room.vineBeds[t].position;
        canvas.drawLine(tail, to, streak);
        canvas.drawCircle(
          to,
          near ? 26 : 22,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = near ? 2.0 : 1.2
            ..color = const Color(0xFFB9A891).withValues(alpha: alpha * 0.9),
        );
        tail = to;
      }
    }
    // A tier-2 reading draws ONE source→groove link out of the plan.
    final link = _gardenLink;
    if (link != null &&
        link.source < room.vineBeds.length &&
        link.groove < room.vineBeds.length) {
      final a = room.vineBeds[link.source].position;
      final b = room.vineBeds[link.groove].position;
      final pulse = 0.4 + 0.25 * sin(_time * 2.4);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF7FC7E8).withValues(alpha: pulse * 0.7),
      );
      canvas.drawCircle(
        b,
        30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF7FC7E8).withValues(alpha: pulse * 0.6),
      );
    }
  }

  /// The groove cut into a bed's stone kerb. Three unmistakable shapes, always
  /// visible (no Mask required — the rite's own standard): a shallow BOWL of
  /// broken arcs wants the drift · a deep angular BRAND wants its own fire ·
  /// a smooth SWEPT ring, barred, wants nothing at all.
  /// What a groove is ASKING FOR, shown as a GHOST OF THE STATE IT WANTS —
  /// never an icon.
  ///
  /// PLAYTEST: "icons mean nothing to me or anyone playing the game; icons
  /// shouldn't be how we solve this puzzle... we should use logic physics and
  /// alchemy." Right on both counts, and it is the standard this planet
  /// already sets elsewhere: the rite's evidence is PHYSICAL (the wax melted
  /// lowest was lit first), never a symbol you have to be taught. So a bed
  /// now shows a faint preview of the material it is waiting for, and solving
  /// is comparing what lies in the bed with the ghost above it:
  ///   · wants the drift → pale ash banked, lying with the live wind
  ///   · wants the brand → the bed shown burnt, with cold char veins
  ///   · must stay swept → rake lines combed across bare soil
  void _drawGroove(
    Canvas canvas,
    Offset p,
    GrooveDemand demand,
    bool sitsTrue,
  ) {
    // An answered groove has stopped asking: the flame and the real material
    // in the bed say everything, and a ghost under them only muddies it.
    if (sitsTrue) return;
    final ghost = 0.30 + 0.06 * sin(_time * 1.5 + p.dx * 0.04);

    switch (demand) {
      case GrooveDemand.ash:
        final dir = gardenWindVector;
        if (_fx.ready) {
          for (var k = -1; k <= 1; k++) {
            final off = Offset(-dir.dy, dir.dx) * (k * 15.0);
            drawPuff(
              canvas,
              _fx.puff!,
              p + off,
              54 - k.abs() * 10,
              const Color(
                0xFFCFC3B0,
              ).withValues(alpha: (0.15 - k.abs() * 0.04) * ghost * 2.2),
            );
          }
        }
      case GrooveDemand.scorch:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 82, height: 58),
            const Radius.circular(9),
          ),
          Paint()..color = const Color(0xFF0C0806).withValues(alpha: ghost),
        );
        final vein = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF7A6656).withValues(alpha: ghost * 1.5);
        canvas.drawLine(
          p + const Offset(-26, 5),
          p + const Offset(-4, -10),
          vein,
        );
        canvas.drawLine(
          p + const Offset(-4, -10),
          p + const Offset(20, 7),
          vein,
        );
        canvas.drawLine(p + const Offset(2, -6), p + const Offset(6, 12), vein);
      case GrooveDemand.clean:
        final rake = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF8A7458).withValues(alpha: ghost * 1.6);
        for (var k = -2; k <= 2; k++) {
          final y = p.dy + k * 9.0;
          final path = Path()..moveTo(p.dx - 34, y);
          for (var x = -34.0; x <= 34.0; x += 8.5) {
            path.lineTo(p.dx + x, y + sin(x * 0.22 + k) * 1.4);
          }
          canvas.drawPath(path, rake);
        }
    }
  }

  void _drawVineTuft(Canvas canvas, Offset c, double cw, Color col) {
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = col.withValues(alpha: 0.85);
    for (var i = -1; i <= 1; i++) {
      final sway = sin(_time * 1.3 + c.dx * 0.02 + i) * 3.0;
      final base = c + Offset(i * cw * 0.16, 12);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            base.dx + sway,
            base.dy - 12,
            base.dx + sway * 1.6,
            base.dy - 22,
          ),
        stem,
      );
    }
  }

  void _drawVineBeds(Canvas canvas, DungeonRoom room) {
    final rules = ashGardenRules;
    if (rules == null) return;
    _drawPlumeForecast(canvas, room);
    for (var i = 0; i < room.vineBeds.length; i++) {
      final bed = room.vineBeds[i];
      final state = bedStateAt(i);
      final fx = _bedFx[i] ?? 0;
      final p = bed.position;
      // Does this groove have what it asked for, right now?
      final sitsTrue = grooveSitsTrue(i);
      // A groove that HAS what it asked for BURNS — the cathedral lights the
      // sigil that has been answered. It is a votive flame standing in the
      // carved channel, not a fire on the soil: small, contained and ritual,
      // so a swept groove satisfied by an empty bed reads as ANSWERED rather
      // than as the garth being ablaze.
      if (sitsTrue && _fx.ready) {
        final breathe = 0.74 + 0.26 * sin(_time * 2.2 + p.dx * 0.03);
        drawGlow(
          canvas,
          _fx.glow!,
          p,
          38 * breathe,
          const Color(0xFFFFA24C).withValues(alpha: 0.24 * breathe),
        );
      }

      // The bed itself: a soil plot with a scorched kerb.
      final plot = Rect.fromCenter(center: p, width: 112, height: 88);
      final rr = RRect.fromRectAndRadius(plot, const Radius.circular(12));
      canvas.drawRRect(
        rr,
        Paint()
          ..color = switch (state) {
            AshBedState.scorch => const Color(0xFF0C0806),
            AshBedState.ash => const Color(0xFF201C18),
            AshBedState.spoiled => const Color(0xFF17110D),
            _ => const Color(0xFF15100B),
          }.withValues(alpha: 0.88),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF4A382C).withValues(alpha: 0.7),
      );

      switch (state) {
        case AshBedState.barren:
          final scorch = Paint()
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF33261D).withValues(alpha: 0.8);
          canvas.drawLine(
            p + const Offset(-30, -22),
            p + const Offset(-12, -10),
            scorch,
          );
          canvas.drawLine(
            p + const Offset(10, -26),
            p + const Offset(26, -14),
            scorch,
          );
          canvas.drawLine(
            p + const Offset(-8, 26),
            p + const Offset(12, 30),
            scorch,
          );
        case AshBedState.green:
          // Vines TAKING: the shoots climb in over `_kGardenGrowSeconds`, and
          // will not answer flame until they have (the price of a redo).
          final grown = bedGrowthAt(i);
          final vine = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(
              const Color(0xFF4E7C42),
              const Color(0xFF6FAF5A),
              grown,
            )!.withValues(alpha: 0.55 + 0.35 * grown);
          final sway = sin(_time * 1.8) * 3;
          for (var v = 0; v < 3; v++) {
            final ox = -28.0 + v * 26;
            final h = (18.0 + v * 4) * (0.25 + 0.75 * grown);
            canvas.drawPath(
              Path()
                ..moveTo(p.dx + ox, p.dy + 28)
                ..quadraticBezierTo(
                  p.dx + ox - 12 + sway,
                  p.dy + 2,
                  p.dx + ox + 6 + sway,
                  p.dy + 28 - h - 28,
                ),
              vine,
            );
            canvas.drawCircle(
              Offset(p.dx + ox + 6 + sway, p.dy - h),
              3 * (0.4 + 0.6 * grown),
              Paint()
                ..color = const Color(
                  0xFF8FCF6A,
                ).withValues(alpha: 0.5 + 0.45 * grown),
            );
          }
        case AshBedState.ash:
          // The drift, banked in pale streaks lying WITH the wind that laid
          // it — and easing in as the plume arrives.
          final land = 1.0 - (_bedPlume[i] ?? 1.0);
          final dir = gardenWindVector;
          // A soft bank of ash lying WITH the wind that laid it — the puff
          // sprite rather than scratched parallel lines, which read as hatching
          // instead of dust.
          if (_fx.ready) {
            for (var s = -1; s <= 1; s++) {
              final off = Offset(-dir.dy, dir.dx) * (s * 16.0);
              drawPuff(
                canvas,
                _fx.puff!,
                p + off + dir * (s.abs() * 4.0),
                62 - s.abs() * 12,
                const Color(
                  0xFFCFC3B0,
                ).withValues(alpha: (0.26 - s.abs() * 0.06) * land),
              );
            }
          }
        case AshBedState.scorch:
          // A brand is SPENT — cold black char with grey veins, not a fire
          // still burning. (It is also why Plant can take it again: new growth
          // out of burnt ground is the whole idea of an ash garden. A bed that
          // looked alight made that read as planting into flame.)
          final crack = Paint()
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = const Color(
              0xFF6B5A4E,
            ).withValues(alpha: 0.42 + 0.08 * sin(_time * 0.7 + p.dx));
          canvas.drawLine(
            p + const Offset(-34, 6),
            p + const Offset(-6, -14),
            crack,
          );
          canvas.drawLine(
            p + const Offset(6, 16),
            p + const Offset(32, -6),
            crack,
          );
        case AshBedState.spoiled:
          // Ash muddled into char: neither one thing nor the other. Grow it
          // again and it is gone — that is the whole recovery.
          final land = 1.0 - (_bedPlume[i] ?? 1.0);
          final smear = Paint()
            ..strokeWidth = 4.0
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF6C6055).withValues(alpha: 0.32 * land);
          canvas.drawLine(
            p + const Offset(-32, -16),
            p + const Offset(30, 12),
            smear,
          );
          canvas.drawLine(
            p + const Offset(-28, 16),
            p + const Offset(26, -12),
            smear,
          );
      }

      _drawGroove(canvas, p, grooveDemandAt(i), sitsTrue);
      if (sitsTrue) _drawSigilFlame(canvas, p, i);

      if (fx > 0 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          p,
          52,
          (state == AshBedState.green
                  ? const Color(0xFF6FAF5A)
                  : const Color(0xFFFFD27A))
              .withValues(alpha: 0.20 * fx),
        );
      }
    }
  }
}
