// lib/games/planet_dungeon/planet_dungeon_game_water_art.dart
//
// THE MIRROR-TIDE TEMPLE, IN GLASS (docs/dungeons.md §7.11) — Water's stone
// and the glass it signals with, as a part of planet_dungeon_game.dart.
//
// The temple already drew its water and its moon with great care — the tide
// that fills and drains, the reflections broken across sliding slices — and
// none of that is touched. What changes is the stone around it (sea-marble,
// baked, arcaded) and the working parts, which become sea glass:
//
//   · a sluice wheel carries a glass hub, lit on the stand it commands, and
//     its stand is counted in glass beads;
//   · a seal is a glass hatch — smoked shut, its wanted tide marked in gold,
//     running clear once it yields;
//   · a canal basin is a glass bowl, a dam is a pane of ice, a sill is counted
//     in beads;
//   · the offering bowl fills as a pane of live water;
//   · the mural is a leaded window;
//   · and the FROZEN MOON — the maxim — sets in the pool inside a rosette of
//     ice glass, frosting out from the moon as the rite binds, and holding
//     the moon's reflection for good.

part of 'planet_dungeon_game.dart';

const GlassPalette _kSeaGlass = kTempleGlass;

final Map<String, ui.Picture> _templeFabricCache = {};

extension MirrorTideArt on PlanetDungeonGame {
  void _updateTempleGlass(double dt) {
    final target =
        discoveredClouds.contains(kWaterFrozenMoonEggId) ||
            _ritePendingEgg == kWaterFrozenMoonEggId
        ? 1.0
        : 0.0;
    if (_frostMoon < 0) {
      _frostMoon = target;
    } else if (_frostMoon < target) {
      _frostMoon = min(target, _frostMoon + dt / 2.4);
    } else if (_frostMoon > target) {
      _frostMoon = target;
    }
  }

  // ── The stone ───────────────────────────────────────────

  void _renderTempleFabric(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final key = '${room.id}|${b.width.round()}x${b.height.round()}';
    canvas.drawPicture(
      _templeFabricCache.putIfAbsent(key, () => _bakeTempleFabric(room)),
    );
  }

  ui.Picture _bakeTempleFabric(DungeonRoom room) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final b = room.bounds;
    final rng = GlassRng(glassSeed(room.id, b));
    paintCarvedRoomShell(
      c,
      b,
      _kSeaGlass,
      rng,
      doors: room.doors.map((d) => d.rect),
      // Big flags, faint joints: a temple floor, not a grid (the trap Air's
      // first pass fell into).
      floorOpacity: 0.42,
      flagCourse: 88,
      jointOpacity: 0.26,
    );
    // Old salt lines where past tides stood — the temple remembers its water.
    final salt = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF8FA8B0).withValues(alpha: 0.1);
    c.drawLine(
      Offset(b.left + 26, b.top + 110),
      Offset(b.right - 26, b.top + 102),
      salt,
    );
    c.drawLine(
      Offset(b.left + 30, b.top + 180),
      Offset(b.right - 30, b.top + 174),
      salt,
    );
    if (room.id == 'tide_gate') {
      for (final (x, y0, y1) in const [
        (640.0, 180.0, 360.0),
        (672.0, 190.0, 350.0),
      ]) {
        paintContactShadow(c, Offset(x, y1 + 6), 40, 12, opacity: 0.45);
        final shaft = Rect.fromLTRB(x - 8, y0, x + 8, y1);
        c.drawRect(
          shaft,
          Paint()
            ..shader = LinearGradient(
              colors: [
                _kSeaGlass.stoneFoot,
                _kSeaGlass.stoneFace,
                _kSeaGlass.stoneTop,
                _kSeaGlass.stoneFace,
              ],
              stops: const [0.0, 0.4, 0.62, 1.0],
            ).createShader(shaft),
        );
        paintCarvedBlock(
          c,
          Rect.fromCenter(center: Offset(x, y0), width: 26, height: 8),
          5,
          _kSeaGlass,
        );
      }
    }
    return rec.endRecording();
  }

  // ── The working parts ───────────────────────────────────

  /// A bead of sea glass — a stand counted, a sill marked.
  void _drawSeaBead(
    Canvas canvas,
    Offset at, {
    required bool lit,
    double r = 3.4,
  }) {
    paintRondel(
      canvas,
      at,
      r,
      _kSeaGlass,
      fill: lit ? _kSeaGlass.heat(0.85) : _kSeaGlass.frostAt(1),
      rim: lit ? 0.9 : 0.45,
      lead: 1.4,
    );
  }

  /// A wheel's glass hub, lit while the tide stands at this wheel's stand.
  void _drawWheelHub(Canvas canvas, Offset p, {required bool current}) {
    paintRondel(
      canvas,
      p,
      6,
      _kSeaGlass,
      fill: current
          ? _kSeaGlass.heat(0.8 + 0.1 * sin(_time * 2))
          : _kSeaGlass.frostAt(2),
      lead: 1.8,
    );
  }

  /// A sluice seal: a glass hatch, smoked while shut, clear once it yields.
  void _drawSealGlass(Canvas canvas, Offset p, {required bool open}) {
    paintRondel(
      canvas,
      p,
      15,
      _kSeaGlass,
      fill: open ? _kSeaGlass.heat(0.62) : _kSeaGlass.smoke,
      rim: open ? 1.0 : 0.6,
    );
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2 + pi / 4;
      paintLead(
        canvas,
        Path()
          ..moveTo(p.dx + cos(a) * 5, p.dy + sin(a) * 5)
          ..lineTo(p.dx + cos(a) * 15, p.dy + sin(a) * 15),
        _kSeaGlass,
        width: 1.6,
      );
    }
    if (open) {
      paintStreak(canvas, Rect.fromCircle(center: p, radius: 10), opacity: 0.6);
    }
  }

  /// A canal basin: a bowl of sea glass under its own turning water.
  void _drawBasinGlass(Canvas canvas, Offset p, double r) {
    paintRondel(
      canvas,
      p,
      r,
      _kSeaGlass,
      fill: _kSeaGlass.frostAt(3),
      rim: 0.55,
    );
  }

  /// A dam: a pane of ice that grows in and thaws back out, cracked in lead.
  void _drawIceDam(Canvas canvas, Offset p, double r, double ice) {
    final grow = Curves.easeOutBack.transform(ice.clamp(0.0, 1.0));
    final rr = r * 0.92 * grow;
    if (rr <= 0.5) return;
    final pane = Path()..addOval(Rect.fromCircle(center: p, radius: rr));
    paintPane(
      canvas,
      pane,
      const Color(0xFFCFE4EE).withValues(alpha: 0.75 * ice),
      _kSeaGlass,
      lead: 2,
    );
    final crack = Path()
      ..moveTo(p.dx - rr * 0.8, p.dy - rr * 0.3)
      ..lineTo(p.dx, p.dy + rr * 0.1)
      ..lineTo(p.dx + rr * 0.7, p.dy - rr * 0.5)
      ..moveTo(p.dx, p.dy + rr * 0.1)
      ..lineTo(p.dx + rr * 0.2, p.dy + rr * 0.85);
    paintLead(
      canvas,
      crack,
      _kSeaGlass,
      width: 1.4,
      opacity: ice,
      light: Colors.white,
    );
    paintStreak(
      canvas,
      Rect.fromCircle(center: p, radius: rr * 0.7),
      opacity: ice * 0.8,
    );
  }

  /// The offering bowl: carved stone, and the water rising in it as a pane of
  /// live glass that brims when full.
  void _drawBowlGlass(Canvas canvas, Offset c, double fill) {
    paintCarvedDisc(canvas, c + const Offset(0, -2), 32, 30, 8, _kSeaGlass);
    paintRondel(canvas, c, 20, _kSeaGlass, fill: _kSeaGlass.smoke, rim: 0.6);
    if (fill <= 0) return;
    final rise = Curves.easeOutCubic.transform(fill.clamp(0.0, 1.0));
    final pane = Path()..addOval(Rect.fromCircle(center: c, radius: 18 * rise));
    paintPane(
      canvas,
      pane,
      _kSeaGlass.heat(0.5 + 0.1 * sin(_time * 2.2)),
      _kSeaGlass,
      lead: 1.8,
    );
    if (fill >= 1) {
      paintStreak(canvas, Rect.fromCircle(center: c, radius: 12), opacity: 0.5);
    }
  }

  /// A vigil light over the mirror gate: a star in a glass rondel.
  void _drawVigilGlass(Canvas canvas, Offset p, bool earned) {
    paintRondel(
      canvas,
      p,
      10,
      _kSeaGlass,
      fill: earned ? _kSeaGlass.heat(0.8) : _kSeaGlass.smoke,
      rim: earned ? 1 : 0.5,
      lead: 2,
    );
    _drawStarGlyph(
      canvas,
      p,
      6,
      (earned ? const Color(0xFF0E3440) : _kSeaGlass.goldDeep).withValues(
        alpha: 0.9,
      ),
    );
  }

  /// The tide mural as a leaded window: three tide-lines in lead, the moon
  /// riding the middle one in silver glass, ice diamonds either side.
  void _drawGlassTideMural(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final panel = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + 120),
      width: 470,
      height: 130,
    );
    paintCarvedBlock(canvas, panel.inflate(10), 10, _kSeaGlass, radius: 6);
    canvas.drawRect(panel.inflate(2), Paint()..color = _kSeaGlass.lead);
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
          canvas,
          Path()..addRect(r),
          Color.lerp(_kSeaGlass.frostAt(i + k), _kSeaGlass.liveDeep, 0.12 * k)!,
          _kSeaGlass,
          lead: 1.8,
        );
      }
    }
    for (var i = 0; i < 3; i++) {
      final y = panel.top + 36.0 + i * 28;
      final path = Path()..moveTo(panel.left + 36, y);
      var x = panel.left + 36.0;
      while (x < panel.right - 120) {
        path.quadraticBezierTo(x + 14, y - 7, x + 28, y);
        x += 28;
      }
      paintLead(canvas, path, _kSeaGlass, width: 3, light: _kSeaGlass.live);
    }
    final moonP = Offset(panel.right - 80, panel.top + 64);
    paintRondel(canvas, moonP, 12, _kSeaGlass, fill: _kSeaGlass.silver);
    for (final dx in const [-30.0, 30.0]) {
      final p = moonP + Offset(dx, 0);
      paintPane(
        canvas,
        Path()
          ..moveTo(p.dx, p.dy - 8)
          ..lineTo(p.dx + 6, p.dy)
          ..lineTo(p.dx, p.dy + 8)
          ..lineTo(p.dx - 6, p.dy)
          ..close(),
        const Color(0xFFCFE4EE),
        _kSeaGlass,
        lead: 1.6,
      );
    }
    paintLead(canvas, Path()..addRect(panel), _kSeaGlass, width: 3.4);
  }

  /// THE FROZEN MOON's setting: a rosette of ice glass round the caught
  /// reflection, frosting out from the moon as the rite binds and then holding
  /// it for good. Drawn OVER the pane the temple already drew, which keeps its
  /// sliding slices — the ice holds the moon, not the pool.
  void _drawFrostRosette(Canvas canvas, Offset c) {
    final f = _frostMoon.clamp(0.0, 1.0);
    if (f <= 0) return;
    for (var ring = 0; ring < 2; ring++) {
      final r0 = 30.0 + ring * 16, r1 = 46.0 + ring * 18;
      final n = 8 + ring * 6;
      for (var i = 0; i < n; i++) {
        final k = ((f * 1.6 - ring * 0.35 - (i / n) * 0.25) / 0.4).clamp(
          0.0,
          1.0,
        );
        if (k <= 0) continue;
        final a0 = i * 2 * pi / n + ring * 0.2,
            a1 = (i + 1) * 2 * pi / n + ring * 0.2;
        final pane = sectorPath(c, r0, r0 + (r1 - r0) * k, a0, a1);
        paintPane(
          canvas,
          pane,
          Color.lerp(
            const Color(0xFFBFE6F5),
            _kSeaGlass.liveDeep,
            0.12 + 0.18 * ring + 0.1 * (i % 2),
          )!.withValues(alpha: 0.72),
          _kSeaGlass,
          lead: 2,
        );
      }
    }
    paintLead(
      canvas,
      Path()..addOval(Rect.fromCircle(center: c, radius: 30)),
      _kSeaGlass,
      width: 2.6,
      light: _kSeaGlass.silver,
    );
    if (f < 1 && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        40 + 50 * f,
        Colors.white.withValues(alpha: 0.25 * (1 - f)),
      );
    }
  }
}
