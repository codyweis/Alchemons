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

/// Water's grains for the broken main's spray: deep, body, lit, glint.
const List<Color> _kSprayRamp = [
  Color(0xFF2A5C6E),
  Color(0xFF6FC4DC),
  Color(0xFFBFEAF4),
  Color(0xFFF2FCFF),
];

extension MirrorTideArt on PlanetDungeonGame {
  /// THE BROKEN MAIN'S SPRAY: ~130 grains of water thrown up out of the
  /// mouth on real arcs and falling back round it, worked out from time
  /// alone. [open] (1 running .. 0 plugged) takes the height and the count
  /// down together, so a choking main visibly runs out of breath.
  void _drawMainSpray(Canvas canvas, Offset mouth, double open) {
    const g = 300.0; // px/s², enough that it reads as water, not mist
    final n = (130 * open).round();
    final lines = List.generate(4, (_) => <Offset>[]);
    for (var i = 0; i < n; i++) {
      final h1 = (sin(i * 127.1 + 311.7) * 43758.5453) % 1.0;
      final h2 = (sin(i * 269.5 + 183.3) * 43758.5453) % 1.0;
      final h3 = (sin(i * 419.2 + 371.9) * 43758.5453) % 1.0;
      // Most of it goes nearly straight up; a little is flung wide.
      final a = -pi / 2 + (h2 + h3 - 1) * 0.34 + sin(_time * 1.9) * 0.05;
      final v = (150 + 45 * h3) * sqrt(open);
      final vx = cos(a) * v, vy = sin(a) * v;
      final life = -2 * vy / g + 0.12;
      Offset at(double tau) =>
          mouth + Offset(vx * tau, vy * tau + 0.5 * g * tau * tau);
      final tau = (_time + h1 * life) % life;
      final q = at(tau);
      final p = tau < 0.018 ? q + const Offset(0, 0.4) : at(tau - 0.018);
      // Bright going up, dimmer coming down, gone as it lands.
      final u = tau / life;
      final shade = h1 > 0.96
          ? 3
          : u < 0.45
          ? 2
          : h2 > 0.35
          ? 1
          : 0;
      if (u > 0.92) continue;
      lines[shade]
        ..add(p)
        ..add(q);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;
    for (var s = 0; s < 4; s++) {
      if (lines[s].isEmpty) continue;
      paint.color = _kSprayRamp[s].withValues(
        alpha: (0.26 + 0.12 * s) * (0.4 + 0.6 * open),
      );
      canvas.drawPoints(ui.PointMode.lines, lines[s], paint);
    }
  }

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

  /// Each hall of the temple is laid for what it is (2026-11-02): the
  /// galleries run long, the courts and the well are ashlar, the works and
  /// the vault are basketwork, and the gate and the depths keep the old
  /// courses.
  static const Map<String, FlagLaying> _kTempleLaying = {
    'moon_hall': FlagLaying.long,
    'ghost_gallery': FlagLaying.long,
    'drowned_court': FlagLaying.ashlar,
    'reflection_court': FlagLaying.ashlar,
    'moon_well': FlagLaying.ashlar,
    'tide_works': FlagLaying.basket,
    'pearl_vault': FlagLaying.basket,
  };

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
      laying: _kTempleLaying[room.id] ?? FlagLaying.courses,
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

  // ── POOLS AND RUNNELS, IN STONE (2026-11-03) ───────────────

  /// The kerbs' stone: darker than the marble's lit top, so a kerb frames a
  /// pool without reading as a pale UI panel round it.
  Color get _kerbStone =>
      Color.lerp(_kSeaGlass.stoneFace, _kSeaGlass.stoneTop, 0.35)!;

  /// A TEMPLE POOL. Every tide basin was a flat translucent rectangle — at
  /// play zoom a UI panel lying on the floor. It is a sunk basin now: a
  /// sea-marble kerb, the far inner wall catching what light there is, an
  /// old mosaic on its floor; and as the tide reaches it, water climbing the
  /// far wall, deep at the back, glinting where the surface moves.
  /// A [ledge] is a drowned wall, not a basin: a carved block the water
  /// climbs over. [wet] is 0 (dry) .. 1 (under).
  void _drawTemplePool(
    Canvas canvas,
    Rect r,
    double wet, {
    required bool ledge,
  }) {
    final key =
        'pool|${r.left.round()},${r.top.round()},${r.width.round()},'
        '${r.height.round()}|$ledge';
    canvas.drawPicture(
      _templeFabricCache.putIfAbsent(key, () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        if (ledge) {
          paintCarvedBlock(
            c,
            r.deflate(2),
            12,
            _kSeaGlass,
            radius: 8,
            topColor: _kerbStone,
          );
          return rec.endRecording();
        }
        final rng = GlassRng(glassSeed('pool', r));
        final kerb = RRect.fromRectAndRadius(
          r.inflate(10),
          const Radius.circular(16),
        );
        c.drawRRect(
          kerb.shift(const Offset(0, 4)),
          Paint()..color = const Color(0x66000000),
        );
        c.drawRRect(kerb, Paint()..color = _kerbStone);
        c.drawLine(
          Offset(r.left + 4, r.top - 9),
          Offset(r.right - 4, r.top - 9),
          Paint()
            ..strokeWidth = 1.4
            ..color = Colors.white.withValues(alpha: 0.16),
        );
        final basin = RRect.fromRectAndRadius(r, const Radius.circular(10));
        c.drawRRect(basin, Paint()..color = _kSeaGlass.stoneFoot);
        c.save();
        c.clipRRect(basin);
        // What is left of an old mosaic: patches of tesserae in the silt,
        // most of the floor long since taken by the sea. (Laid whole it read
        // as a game board.)
        for (var k = 0; k < (r.width * r.height / 9000).ceil(); k++) {
          final cx = rng.range(r.left + 20, r.right - 20);
          final cy = rng.range(r.top + 30, r.bottom - 14);
          final reach = rng.range(18, 40);
          for (var t = 0; t < 26; t++) {
            final a = rng.range(0, 2 * pi);
            final d = reach * sqrt(rng.next());
            final at = Offset(cx + cos(a) * d, cy + sin(a) * d * 0.8);
            c.drawRect(
              Rect.fromCenter(center: at, width: 7, height: 7),
              Paint()
                ..color = Color.lerp(
                  _kSeaGlass.frostAt(rng.pick(5)),
                  const Color(0xFF3E7C8C),
                  rng.next() * 0.35,
                )!.withValues(alpha: 0.35 + 0.3 * rng.next()),
            );
          }
        }
        // The far inner wall, which is what a basin seen from the south is.
        final wall = Rect.fromLTWH(r.left, r.top, r.width, 20);
        c.drawRect(
          wall,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kSeaGlass.stoneFace, _kSeaGlass.stoneFoot],
            ).createShader(wall),
        );
        c.restore();
        c.drawRRect(
          basin,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xAA05090C),
        );
        return rec.endRecording();
      }),
    );
    if (wet <= 0) return;
    // The water: it climbs the far wall as it rises.
    final surface = ledge
        ? r.inflate(6)
        : Rect.fromLTRB(r.left, r.top + 20 * (1 - wet), r.right, r.bottom);
    final body = RRect.fromRectAndRadius(surface, const Radius.circular(10));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3A90AC).withValues(alpha: 0.30 + 0.32 * wet),
            const Color(0xFF0C3446).withValues(alpha: 0.40 + 0.38 * wet),
          ],
        ).createShader(surface),
    );
    // The waterline against the far wall.
    canvas.drawLine(
      Offset(surface.left + 8, surface.top + 1),
      Offset(surface.right - 8, surface.top + 1),
      Paint()
        ..strokeWidth = 1.4
        ..color = const Color(0xFFBFEAF4).withValues(alpha: 0.30 * wet),
    );
    // Glints where the surface moves: short bright grains drifting with the
    // swell, twinkling in and out — never a drawn wavy line.
    final n = (surface.width * surface.height / 900 * wet).round().clamp(
      6,
      220,
    );
    final seed = glassSeed('glint', r);
    for (var i = 0; i < n; i++) {
      final h1 = _vaporHash(seed + i * 3);
      final h2 = _vaporHash(seed * 7 + i * 5 + 1);
      final h3 = _vaporHash(seed * 13 + i * 11 + 2);
      final x =
          surface.left +
          8 +
          ((h1 * (surface.width - 16) + _time * (6 + 6 * h3)) %
              (surface.width - 16));
      final y =
          surface.top +
          6 +
          h2 * (surface.height - 12) +
          sin(_time + h1 * 9) * 2;
      final tw = (0.5 + 0.5 * sin(_time * (1.5 + h3 * 2) + h2 * 20)).clamp(
        0.0,
        1.0,
      );
      final len = 2 + 5 * h3;
      _vaporBatch.add(
        Offset(x - len, y),
        Offset(x, y),
        h3 > 0.85 ? 3 : (h3 > 0.5 ? 2 : 1),
        0.55 * tw * wet,
      );
    }
    _vaporBatch.paint(canvas, _kSprayRamp, width: 1.4);
    if (_fx.ready) {
      for (var k = 0; k < 2; k++) {
        drawGlow(
          canvas,
          _fx.glow!,
          Offset(
            surface.left +
                surface.width * (0.3 + 0.4 * k) +
                surface.width * 0.15 * sin(_time * 0.21 + k * 2),
            surface.center.dy + surface.height * 0.2 * cos(_time * 0.17 + k),
          ),
          min(surface.width, surface.height) * 0.45,
          const Color(0xFF6FC4DC).withValues(alpha: 0.07 * wet),
        );
      }
    }
  }

  /// A RUNNEL of the canal gallery: a channel cut in the floor with stone
  /// kerbs either side, its bed dark — what the line on the floor was meant
  /// to be. A deep cut is cut wider and darker.
  void _drawCanalRunnel(
    Canvas canvas,
    Offset a,
    Offset b, {
    bool deep = false,
  }) {
    canvas.drawLine(
      a + const Offset(0, 3),
      b + const Offset(0, 3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = deep ? 30 : 24
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x55000000),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = deep ? 30 : 24
        ..strokeCap = StrokeCap.round
        ..color = _kerbStone,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = deep ? 20 : 15
        ..strokeCap = StrokeCap.round
        ..color = deep ? const Color(0xFF02070A) : const Color(0xFF071319),
    );
  }

  /// Live water running down a runnel: a ribbon of water and grains of light
  /// riding it downstream, so "this one runs, and THAT way" reads at a
  /// glance. A [torrent] churns: faster, broken, white.
  void _drawRunnelWater(
    Canvas canvas,
    Offset a,
    Offset unit,
    double length, {
    bool torrent = false,
  }) {
    final b = a + unit * length;
    canvas.drawLine(
      a,
      b,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = torrent ? 15 : 11
        ..strokeCap = StrokeCap.round
        ..color = (torrent ? const Color(0xFF4A9AB8) : const Color(0xFF2A88A8))
            .withValues(alpha: torrent ? 0.6 : 0.5),
    );
    final normal = Offset(-unit.dy, unit.dx);
    final n = (length / (torrent ? 3 : 6)).round().clamp(4, 260);
    final speed = torrent ? 120.0 : 46.0;
    final seed = (a.dx * 7 + a.dy * 13).round();
    for (var i = 0; i < n; i++) {
      final h1 = _vaporHash(seed + i * 3);
      final h2 = _vaporHash(seed * 5 + i * 7 + 1);
      final along = (h1 * length + _time * speed * (0.8 + 0.4 * h2)) % length;
      final across =
          (h2 - 0.5) * (torrent ? 11 : 7) +
          (torrent ? sin(_time * 9 + i) * 2.5 : 0);
      final q = a + unit * along + normal * across;
      final p = q - unit * (torrent ? 6 : 4);
      final fade = min(1.0, min(along, length - along) / 14);
      _vaporBatch.add(
        p,
        q,
        torrent ? (h2 > 0.4 ? 3 : 2) : (h2 > 0.75 ? 3 : (h2 > 0.35 ? 2 : 1)),
        (torrent ? 0.75 : 0.55) * fade,
      );
    }
    _vaporBatch.paint(canvas, _kSprayRamp, width: 1.5);
  }
}
