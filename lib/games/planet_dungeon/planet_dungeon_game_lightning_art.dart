// lib/games/planet_dungeon/planet_dungeon_game_lightning_art.dart
//
// THE STORM CIRCUIT, IN GLASS (docs/dungeons.md §7.11) — Lightning's stone and
// the glass it signals with, as a part of planet_dungeon_game.dart.
//
// A storm-works: bolted iron plate in courses with the building's own cable
// runs sunk in it, walls of the same grey iron-stone, and glass exactly where
// high-tension equipment really carries it —
//
//   · every post's insulator stack is three discs of glass, lit when the line
//     through it is live;
//   · pylons and sinks wear a glass head, mirrors a silvered-glass vane;
//   · a closed barrier is a smoked leaded shutter with the charge in it;
//   · a socket's seat and a station pad are glass in a brass rim;
//   · the dynamo's rotor is a rose of glass that turns with the works;
//   · and the THUNDERBOLT — the maxim — leaves FULGURITE: the glass lightning
//     makes when it strikes sand, branching out of the rotor across the court
//     as you watch, and lying there for good.
//
// COST. The floor and walls are baked once per room.

part of 'planet_dungeon_game.dart';

const GlassPalette _kVoltGlass = kVoltGlass;

final Map<String, ui.Picture> _circuitFabricCache = {};

extension StormCircuitArt on PlanetDungeonGame {
  // ── The floor: bolted plate, baked ──────────────────────

  void _renderCircuitFabric(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final key = '${room.id}|${b.width.round()}x${b.height.round()}';
    canvas.drawPicture(
      _circuitFabricCache.putIfAbsent(key, () => _bakeCircuitFabric(room)),
    );
  }

  ui.Picture _bakeCircuitFabric(DungeonRoom room) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final b = room.bounds;
    final seed = (b.width * 13 + b.height * 7).toInt();
    final rng = GlassRng(glassSeed(room.id, b));

    // PLATE COURSES, offset like brickwork so the joins never make a grid —
    // translucent (§8), so the storm shader shows through the iron.
    const plateH = 118.0;
    var row = 0;
    for (var y = b.top; y < b.bottom; y += plateH) {
      final off = row.isEven ? 0.0 : 150.0;
      final h = min(plateH, b.bottom - y);
      canvas.drawRect(
        Rect.fromLTWH(b.left, y, b.width, h),
        Paint()
          ..color = (row.isEven ? _kVoltGlass.floor : _kVoltGlass.floorAlt)
              .withValues(alpha: 0.55),
      );
      canvas.drawLine(
        Offset(b.left, y),
        Offset(b.right, y),
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFF8FB6D8).withValues(alpha: 0.07),
      );
      for (var x = b.left + off + 300; x < b.right; x += 300) {
        canvas.drawLine(
          Offset(x, y + 2),
          Offset(x, y + h - 2),
          Paint()
            ..strokeWidth = 1.0
            ..color = _kVoltGlass.joint.withValues(alpha: 0.55),
        );
      }
      for (var x = b.left + 40 + off * 0.2; x < b.right - 20; x += 74) {
        canvas.drawCircle(
          Offset(x, y + 7),
          2.0,
          Paint()..color = const Color(0xFF6E8CA8).withValues(alpha: 0.16),
        );
      }
      row++;
    }
    // The building's own cable runs, sunk in the plate, with clamps.
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
          ..color = const Color(0xFF0A0F16).withValues(alpha: 0.6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFF3E5A72).withValues(alpha: 0.26),
      );
    }
    // Old scorch, where arcs have crossed this room for a long time.
    for (var i = 0; i < 5; i++) {
      final at = Offset(
        b.left + 60 + rng.next() * (b.width - 120),
        b.top + 60 + rng.next() * (b.height - 120),
      );
      canvas.drawCircle(
        at,
        20.0 + (i % 3) * 9,
        Paint()..color = const Color(0xFF05080D).withValues(alpha: 0.4),
      );
    }
    paintCarvedRoomShell(
      canvas,
      b,
      _kVoltGlass,
      rng,
      doors: room.doors.map((d) => d.rect),
      arcade: false,
      flags: false,
    );
    return rec.endRecording();
  }

  // ── The equipment's glass ───────────────────────────────

  /// The insulator stack under a post's head: three discs of glass, widest
  /// at the foot — real high-tension glass, dark until the line is live.
  void _drawGlassInsulators(Canvas canvas, Offset at, Color tone, bool live) {
    for (var i = 0; i < 3; i++) {
      final y = at.dy + 9 - i * 6.0;
      final w = 30.0 - i * 5;
      final disc = Path()
        ..addOval(
          Rect.fromCenter(center: Offset(at.dx, y), width: w, height: 7),
        );
      paintPane(
        canvas,
        disc,
        live
            ? Color.lerp(
                tone,
                _kVoltGlass.liveCore,
                0.25 + 0.15 * sin(_time * 6 + i),
              )!
            : Color.lerp(_kVoltGlass.frostAt(i), tone, 0.18)!,
        _kVoltGlass,
        lead: 1.3,
      );
    }
  }

  /// A glass head for a pylon or a sink, in a brass rim.
  void _drawGlassHead(
    Canvas canvas,
    Offset p,
    double r, {
    required bool live,
    Color? cold,
  }) {
    paintRondel(
      canvas,
      p,
      r,
      _kVoltGlass,
      fill: live
          ? _kVoltGlass.heat(0.78 + 0.12 * sin(_time * 7 + p.dx))
          : (cold ?? _kVoltGlass.frostAt(1)),
      rim: live ? 1.0 : 0.6,
    );
    if (live) paintStreak(canvas, Rect.fromCircle(center: p, radius: r * 0.7));
  }

  /// A conductor's vane, in silvered glass — drawn in the vane's own rotated
  /// frame, [len] long.
  void _drawSilverVane(Canvas canvas, double len, {required bool live}) {
    final plate = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: len, height: 8),
          const Radius.circular(3),
        ),
      );
    paintPane(
      canvas,
      plate,
      live ? _kVoltGlass.liveCore : _kVoltGlass.silver.withValues(alpha: 0.75),
      _kVoltGlass,
      lead: 1.6,
    );
    canvas.drawLine(
      Offset(-len / 2 + 3, -1.8),
      Offset(len / 2 - 3, -1.8),
      Paint()
        ..color = Colors.white.withValues(alpha: live ? 0.95 : 0.55)
        ..strokeWidth = 1.2,
    );
  }

  /// A closed barrier: a shutter of smoked leaded glass, the charge crackling
  /// in it — not a solid slab of UI.
  void _drawGlassShutter(Canvas canvas, Rect rect) {
    final vertical = rect.height > rect.width;
    final n = max(2, ((vertical ? rect.height : rect.width) / 22).floor());
    for (var i = 0; i < n; i++) {
      final pane = vertical
          ? Rect.fromLTWH(
              rect.left,
              rect.top + rect.height * i / n,
              rect.width,
              rect.height / n,
            )
          : Rect.fromLTWH(
              rect.left + rect.width * i / n,
              rect.top,
              rect.width / n,
              rect.height,
            );
      paintPane(
        canvas,
        Path()..addRect(pane),
        Color.lerp(
          _kVoltGlass.smoke,
          _kVoltGlass.liveDeep,
          0.12 + 0.1 * sin(_time * 5 + i),
        )!,
        _kVoltGlass,
        lead: 2.2,
      );
    }
    paintLead(
      canvas,
      Path()..addRect(rect),
      _kVoltGlass,
      width: 3.2,
      light: _kVoltGlass.gold,
    );
  }

  /// A socket's seat: a glass oval in a brass rim, lit once a cell sings in it.
  void _drawGlassSeat(
    Canvas canvas,
    Offset p,
    Color c, {
    required bool energized,
  }) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(1, 0.42);
    paintRondel(
      canvas,
      Offset.zero,
      22,
      _kVoltGlass,
      fill: energized
          ? _kVoltGlass.heat(0.8)
          : Color.lerp(_kVoltGlass.frostAt(2), c, 0.2)!,
      rim: energized ? 1.0 : 0.7,
    );
    canvas.restore();
  }

  /// A station pad: a brass-rimmed disc of glass the colour of the element it
  /// is keyed to — faint and waiting until that element stands on it.
  void _drawGlassPad(Canvas canvas, Offset pos, Color col, bool on) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(1, 0.5);
    paintRondel(
      canvas,
      Offset.zero,
      26,
      _kVoltGlass,
      fill: Color.lerp(_kVoltGlass.frostAt(0), col, on ? 0.85 : 0.3)!,
      rim: on ? 1.0 : 0.65,
    );
    canvas.restore();
  }

  // ── The dynamo and the Thunderbolt ──────────────────────

  List<RosePane> _rotorRose(Offset c) => _cathedralRoseCache.putIfAbsent(
    'rotor@${c.dx},${c.dy}',
    () => buildRose(c, [(10.0, 30.0, 6, 0.0), (30.0, 54.0, 12, 0.0)]),
  );

  /// The rotor, as a rose of glass that turns with the works: smoked while it
  /// idles, arc-lit while it feeds a wing, and running hot past its limit.
  void _drawGlassRotor(
    Canvas canvas,
    Offset c,
    double spin, {
    required bool live,
    required double over,
    required bool won,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    canvas.translate(-c.dx, -c.dy);
    for (final p in _rotorRose(c)) {
      final base = _kVoltGlass.frostAt(p.index + p.ring);
      final fill = won
          ? Color.lerp(
              _kVoltGlass.live,
              _kVoltGlass.liveCore,
              0.3 + 0.2 * sin(_time * 2 + p.index),
            )!
          : live
          ? Color.lerp(
              base,
              _kVoltGlass.live,
              0.55 + 0.25 * (p.index.isEven ? 1 : 0),
            )!
          : base;
      paintPane(
        canvas,
        p.path,
        over > 0.01
            ? Color.lerp(fill, const Color(0xFFFF9A5A), over * 0.6)!
            : fill,
        _kVoltGlass,
        lead: 2.4,
      );
    }
    canvas.restore();
    paintLead(
      canvas,
      Path()..addOval(Rect.fromCircle(center: c, radius: 54)),
      _kVoltGlass,
      width: 3.6,
      light: _kVoltGlass.gold,
    );
    paintRondel(
      canvas,
      c,
      10,
      _kVoltGlass,
      fill: live || won ? _kVoltGlass.liveCore : _kVoltGlass.smoke,
    );
  }

  /// FULGURITE — the Thunderbolt's mark. When the works let go, every trunk
  /// took at once and the bolt went down into the court: it left glass in the
  /// floor, the way lightning leaves glass in sand. Six veins branch out of
  /// the rotor's bed, growing out as [grow] runs 0 → 1, and then lie there
  /// for good with a slow cold light in them.
  void _drawFulgurite(Canvas canvas, Offset c, double grow) {
    if (grow <= 0) return;
    final rng = GlassRng(97);
    for (var i = 0; i < 6; i++) {
      final a0 = i * pi / 3 + 0.4;
      var at = c + Offset(cos(a0), sin(a0)) * 60;
      var a = a0;
      final pts = <Offset>[at];
      for (var k = 0; k < 7; k++) {
        a += (rng.next() - 0.5) * 0.9;
        at = at + Offset(cos(a), sin(a)) * 18;
        pts.add(at);
      }
      final reach = (grow * 1.3 - i * 0.05).clamp(0.0, 1.0);
      final count = (pts.length * reach).floor();
      if (count < 2) continue;
      final vein = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var k = 1; k < count; k++) {
        vein.lineTo(pts[k].dx, pts[k].dy);
      }
      canvas.drawPath(
        vein,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _kVoltGlass.lead,
      );
      final glow = grow < 1 ? 1.0 : 0.8 + 0.2 * sin(_time * 1.1 + i);
      canvas.drawPath(
        vein,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(
            _kVoltGlass.live,
            _kVoltGlass.liveCore,
            0.4,
          )!.withValues(alpha: 0.95 * glow),
      );
      // The glass's bright heart, and the cold light it holds.
      canvas.drawPath(
        vein,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.8 * glow),
      );
      if (_fx.ready) {
        for (var k = 1; k < count; k += 2) {
          drawGlow(
            canvas,
            _fx.glow!,
            pts[k],
            16,
            _kVoltGlass.live.withValues(alpha: 0.16 * glow),
          );
        }
      }
      // A branch off the middle — lightning forks, and so does its glass.
      if (count > 4) {
        final fork = pts[3];
        final fa = a0 + (i.isEven ? 0.9 : -0.9);
        final tip = fork + Offset(cos(fa), sin(fa)) * 30 * reach;
        canvas.drawLine(
          fork,
          tip,
          Paint()
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = _kVoltGlass.lead,
        );
        canvas.drawLine(
          fork,
          tip,
          Paint()
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..color = _kVoltGlass.live.withValues(alpha: 0.75 * glow),
        );
      }
      if (grow < 1 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          pts[count - 1],
          18,
          _kVoltGlass.liveCore.withValues(alpha: 0.7),
        );
      }
    }
  }

  // ── THE STORM, LIT (2026-09-24) ─────────────────────────
  // The works read as near-black navy with small props: the power that IS
  // the puzzle barely showed. Everything here is cheap — glow sprites, a
  // handful of short polylines and one overlay rect — and none of it blurs.

  /// Fresh jitter for an arc, changing ~12 times a second: a crackle, not a
  /// wobble. Deterministic per [seed] so every arc flickers on its own beat.
  double _crackle(int seed, int k) {
    final frame = (_time * 12).floor();
    final h =
        ((frame * 73856093) ^ (seed * 19349663) ^ (k * 83492791)) & 0x7fffffff;
    return (h % 1000) / 1000.0 - 0.5;
  }

  Path _jag(Offset a, Offset b, int seed, double amp, int segs) {
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / max(1.0, d.distance);
    final p = Path()..moveTo(a.dx, a.dy);
    for (var i = 1; i < segs; i++) {
      final q = Offset.lerp(a, b, i / segs)! + n * (_crackle(seed, i) * amp);
      p.lineTo(q.dx, q.dy);
    }
    return p..lineTo(b.dx, b.dy);
  }

  void _strokeArc(Canvas canvas, Path p, double alpha) {
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF6BA8FF).withValues(alpha: 0.35 * alpha),
    );
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFF2FAFF).withValues(alpha: alpha),
    );
  }

  /// A live line spits: now and then a short arc jumps off it.
  void _drawWireCrackle(Canvas canvas, Offset a, Offset b) {
    final seed = (a.dx * 7 + b.dy * 13).toInt();
    // On for roughly one frame in three, somewhere along the line.
    if (_crackle(seed, 99) < 0.2) return;
    final u = 0.2 + (_crackle(seed, 7) + 0.5) * 0.6;
    final at = Offset.lerp(a, b, u)!;
    final d = b - a;
    final n = Offset(-d.dy, d.dx) / max(1.0, d.distance);
    final tip = at + n * (14 + 10 * _crackle(seed, 8)) + d / d.distance * 10;
    _strokeArc(canvas, _jag(at, tip, seed, 7, 4), 0.85);
  }

  /// A live post: a pool of light on the floor round its foot, and arcs
  /// crawling round its head.
  void _drawPostCrackle(Canvas canvas, Offset at) {
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        at + const Offset(0, 22),
        72,
        const Color(0xFF4A86D8).withValues(alpha: 0.28),
      );
    }
    final seed = (at.dx * 31 + at.dy).toInt();
    for (var k = 0; k < 2; k++) {
      if (_crackle(seed, k + 40) < -0.1) continue;
      final a0 = (_crackle(seed, k + 50) + 0.5) * 2 * pi;
      final from = at + Offset(cos(a0), sin(a0)) * 10;
      final to = at + Offset(cos(a0 + 1.2), sin(a0 + 1.2)) * 24;
      _strokeArc(canvas, _jag(from, to, seed + k, 6, 3), 0.75);
    }
  }

  /// The cables sunk in every floor carry current while this wing is fed:
  /// pulses of light running the length of each run.
  void _renderCableCurrent(Canvas canvas, DungeonRoom room) {
    final dark = _trunkDark[room.id] ?? 0;
    if (dark > 0.6 || !_fx.ready) return;
    final b = room.bounds;
    final seed = (b.width * 13 + b.height * 7).toInt();
    final on = 1 - dark / 0.6;
    for (var i = 0; i < 3; i++) {
      final y0 = b.top + b.height * (0.24 + i * 0.26) + (seed % 17) - 8;
      // The run itself, faintly charged (the same curve the bake sank).
      final run = Path()..moveTo(b.left, y0);
      for (var x = b.left; x <= b.right; x += 60) {
        run.lineTo(x, y0 + sin((x + seed) * 0.006 + i) * 7);
      }
      canvas.drawPath(
        run,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF6BA8FF).withValues(alpha: 0.22 * on),
      );
      for (var k = 0; k < 2; k++) {
        final u = ((_time * (0.22 + i * 0.05)) + k * 0.5 + i * 0.3) % 1.0;
        final x = b.left + u * b.width;
        final y = y0 + sin((x + seed) * 0.006 + i) * 7;
        drawGlow(
          canvas,
          _fx.glow!,
          Offset(x, y),
          26,
          const Color(0xFF6BA8FF).withValues(alpha: 0.5 * on),
        );
        drawGlow(
          canvas,
          _fx.glow!,
          Offset(x, y),
          9,
          const Color(0xFFE9F6FF).withValues(alpha: 0.8 * on),
        );
      }
    }
  }

  /// THE STORM OUTSIDE. Every several seconds the works go white-blue for a
  /// double blink — lightning — with light raking in off the north wall.
  /// One rect and a few shafts, only while it is flashing.
  void _renderStormFlash(Canvas canvas, DungeonRoom room) {
    const period = 7.0;
    final cycle = (_time / period).floor();
    final h = ((cycle * 2654435761) & 0xffff) / 0xffff;
    final t = _time - cycle * period - h * 4.5;
    double pulse(double x) => x < 0 ? 0 : exp(-x * 16);
    final i = max(pulse(t), 0.6 * pulse(t - 0.16));
    if (i < 0.02) return;
    final b = room.bounds;
    canvas.drawRect(
      b.inflate(60),
      Paint()..color = const Color(0xFFCFE6FF).withValues(alpha: 0.2 * i),
    );
    // Light raking in from high windows in the north wall.
    for (var k = 0; k < 3; k++) {
      final x = b.left + b.width * (0.2 + k * 0.3 + (h - 0.5) * 0.1);
      canvas.drawPath(
        Path()
          ..moveTo(x - 18, b.top + 40)
          ..lineTo(x + 18, b.top + 40)
          ..lineTo(x + 90, b.bottom)
          ..lineTo(x + 20, b.bottom)
          ..close(),
        Paint()..color = const Color(0xFFE9F4FF).withValues(alpha: 0.1 * i),
      );
    }
  }
}
