// lib/games/planet_dungeon/planet_dungeon_game_earth_art.dart
//
// THE BURIED GIANT, IN GLASS (docs/dungeons.md §7.11) — Earth's stone and the
// glass it signals with, as a part of planet_dungeon_game.dart.
//
// The barrow is carved earth and dolmen stone over strata; its glass is
// CRYSTAL, because Earth + Lightning makes Crystal and that is what this
// planet grows. One crystal, drawn one way everywhere — leaded blades with a
// lit facet — so a lock in the crypt, the prism before the eye and the
// cluster in the Giant's Palm are recognisably the same substance:
//
//   · the crypt's socket mouths are glass; locks and seals are crystal blades;
//   · the giant's eye is a leaded rondel that wakes with the prism;
//   · the gaze prism is a crystal blade grown out of its core;
//   · the bone mural is a leaded window with its diagram in gold lead;
//   · the Palm — the maxim — grows its cluster blade by blade as the rite
//     binds, and keeps it, leaded and gleaming, on every later descent.
//
// COST. The strata and walls are baked once per room.

part of 'planet_dungeon_game.dart';

const GlassPalette _kBarrowGlass = kBarrowGlass;

final Map<String, ui.Picture> _barrowFabricCache = {};

extension BuriedGiantArt on PlanetDungeonGame {
  /// Ease the barrow's glass. A negative value snaps to the truth.
  void _updateBarrowGlass(double dt) {
    final target =
        discoveredClouds.contains(kEarthGiantsPalmEggId) ||
            _ritePendingEgg == kEarthGiantsPalmEggId
        ? 1.0
        : 0.0;
    if (_palmGrow < 0) {
      _palmGrow = target;
    } else if (_palmGrow < target) {
      _palmGrow = min(target, _palmGrow + dt / 2.8);
    } else if (_palmGrow > target) {
      _palmGrow = target;
    }
  }

  // ── The ground: strata, baked ───────────────────────────

  void _renderBarrowFabric(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final key = '${room.id}|${b.width.round()}x${b.height.round()}';
    canvas.drawPicture(
      _barrowFabricCache.putIfAbsent(key, () => _bakeBarrowFabric(room)),
    );
  }

  ui.Picture _bakeBarrowFabric(DungeonRoom room) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final b = room.bounds;
    // THE GROUND IS STRATA: the giant sank through ages, and the ages are
    // still lying on top of it in bands with wavering boundaries (§8
    // translucent, so the shader shows through the dirt).
    canvas.drawRect(
      b,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          _kBarrowGlass.floor.withValues(alpha: 0.5),
          const Color(0xFF120E08).withValues(alpha: 0.58),
        ]),
    );
    final seed = (b.width * 31 + b.height * 17).toInt();
    double wob(int i, double x) =>
        sin((x + seed + i * 137) * 0.0121 + i * 2.3) * (5 + (i % 3) * 3.5);
    const bands = 7;
    for (var i = 1; i < bands; i++) {
      final y = b.top + b.height * i / bands;
      final path = Path()..moveTo(b.left, y + wob(i, b.left));
      for (var x = b.left; x <= b.right; x += 26) {
        path.lineTo(x, y + wob(i, x));
      }
      final seam = Path.from(path);
      path
        ..lineTo(b.right, b.bottom)
        ..lineTo(b.left, b.bottom)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color =
              (i.isEven ? const Color(0xFF241B12) : const Color(0xFF1A140D))
                  .withValues(alpha: 0.34),
      );
      canvas.drawPath(
        seam,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF8A6E48).withValues(alpha: 0.10),
      );
    }
    // Bone fleck and root: what is actually in the dirt over a giant.
    final chip = Paint()
      ..color = const Color(0xFFB8A070).withValues(alpha: 0.13);
    final root = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF4A3A22).withValues(alpha: 0.4);
    for (var i = 0; i < 34; i++) {
      final u = ((i * 2654435761) % 1000) / 1000.0;
      final v = ((i * 40503 + seed) % 997) / 997.0;
      final at = Offset(
        b.left + 20 + u * (b.width - 40),
        b.top + 20 + v * (b.height - 40),
      );
      if (i % 4 == 0) {
        canvas.drawPath(
          Path()
            ..moveTo(at.dx, at.dy)
            ..quadraticBezierTo(
              at.dx + 7 * (i.isEven ? 1 : -1),
              at.dy + 13,
              at.dx + 2 * (i.isEven ? -1 : 1),
              at.dy + 27,
            ),
          root,
        );
      } else {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(u * pi);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: 5 + (i % 3) * 2.0,
              height: 2,
            ),
            const Radius.circular(1),
          ),
          chip,
        );
        canvas.restore();
      }
    }
    paintCarvedRoomShell(
      canvas,
      b,
      _kBarrowGlass,
      GlassRng(glassSeed(room.id, b)),
      doors: room.doors.map((d) => d.rect),
      arcade: false,
      flags: false,
    );
    return rec.endRecording();
  }

  // ── Crystal ─────────────────────────────────────────────

  /// ONE blade of the planet's crystal: a body pane and a lit facet down one
  /// side, held in lead — the same substance in a lock, a prism or the Palm.
  /// [heat] 0 is cold crystal, 1 is the crystal lit from within.
  void _drawCrystalBlade(
    Canvas canvas,
    Offset base,
    double w,
    double h, {
    double lean = 0,
    double heat = 0.4,
    double opacity = 1,
  }) {
    if (h <= 0.5) return;
    final tip = base + Offset(sin(lean) * h, -cos(lean) * h);
    final body = Path()
      ..moveTo(base.dx - w, base.dy)
      ..lineTo(tip.dx - w * 0.22, tip.dy)
      ..lineTo(tip.dx + w * 0.22, tip.dy)
      ..lineTo(base.dx + w, base.dy)
      ..close();
    final facet = Path()
      ..moveTo(base.dx - w, base.dy)
      ..lineTo(tip.dx - w * 0.22, tip.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(base.dx, base.dy)
      ..close();
    paintPaneFill(
      canvas,
      body,
      Color.lerp(_kBarrowGlass.liveDeep, _kBarrowGlass.live, heat * 0.6)!,
      opacity: 0.9 * opacity,
    );
    paintPaneFill(
      canvas,
      facet,
      Color.lerp(_kBarrowGlass.live, _kBarrowGlass.liveCore, heat)!,
      opacity: 0.75 * opacity,
    );
    paintLead(
      canvas,
      body,
      _kBarrowGlass,
      width: 1.6,
      opacity: opacity,
      light: _kBarrowGlass.liveCore,
    );
    paintLead(
      canvas,
      Path()
        ..moveTo(base.dx, base.dy)
        ..lineTo(tip.dx, tip.dy),
      _kBarrowGlass,
      width: 1.0,
      opacity: opacity,
    );
  }

  /// A socket's mouth, in glass: frosted over when buried, smoked when bared,
  /// crystal-lit once locked.
  void _drawGlassMouth(
    Canvas canvas,
    Offset at, {
    required bool locked,
    required bool bared,
  }) {
    paintRondel(
      canvas,
      at,
      9,
      _kBarrowGlass,
      fill: locked
          ? _kBarrowGlass.heat(0.6)
          : (bared ? _kBarrowGlass.smoke : _kBarrowGlass.frostAt(1)),
      rim: locked ? 1.0 : 0.6,
      lead: 2,
    );
  }

  /// The giant's eye: a leaded rondel of crystal — iris panes round a pupil
  /// that wanders while it is blind, and wakes as the prism stands.
  void _drawGlassEye(Canvas canvas, Offset c, Offset look, double wake) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 0.55);
    for (var i = 0; i < 10; i++) {
      final pane = sectorPath(
        Offset.zero,
        24,
        58,
        i * pi / 5,
        (i + 1) * pi / 5,
      );
      paintPane(
        canvas,
        pane,
        Color.lerp(
          _kBarrowGlass.frostAt(i),
          _kBarrowGlass.live,
          0.15 + 0.55 * wake,
        )!,
        _kBarrowGlass,
        lead: 2.4,
      );
    }
    canvas.restore();
    paintRondel(
      canvas,
      c + look,
      12,
      _kBarrowGlass,
      fill: _kBarrowGlass.heat(0.3 + 0.55 * wake + 0.05 * sin(_time * 2.6)),
    );
  }

  /// The bone mural as a window: smoked glass in a carved frame, its diagram
  /// — the eye, its gaze bent through a crystal lens, the scale it reads — in
  /// gold lead, the lens in crystal.
  void _drawGlassBoneMural(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final panel = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + 120),
      width: 470,
      height: 130,
    );
    paintCarvedBlock(canvas, panel.inflate(10), 10, _kBarrowGlass, radius: 6);
    canvas.drawRect(panel.inflate(2), Paint()..color = _kBarrowGlass.lead);
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
          Color.lerp(_kBarrowGlass.frostAt(i + k), _kBarrowGlass.smoke, 0.35)!,
          _kBarrowGlass,
          lead: 1.8,
        );
      }
    }
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _kBarrowGlass.gold.withValues(alpha: 0.75);
    final eyeP = Offset(panel.left + 90, panel.center.dy);
    canvas.drawOval(Rect.fromCenter(center: eyeP, width: 56, height: 30), ink);
    paintRondel(canvas, eyeP, 8, _kBarrowGlass, fill: _kBarrowGlass.heat(0.45));
    final pivot = Offset(panel.center.dx + 60, panel.center.dy - 14);
    canvas.drawLine(
      pivot + const Offset(-80, 8),
      pivot + const Offset(80, -8),
      ink,
    );
    canvas.drawLine(pivot, pivot + const Offset(0, 30), ink);
    for (final side in const [-1.0, 1.0]) {
      final panC = pivot + Offset(side * 80, side * -8 + 22);
      canvas.drawArc(
        Rect.fromCircle(center: panC, radius: 16),
        0,
        pi,
        false,
        ink,
      );
    }
    final lensP = Offset((eyeP.dx + pivot.dx) / 2 - 16, panel.center.dy + 12);
    final beam = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = _kBarrowGlass.live.withValues(
        alpha: 0.4 + 0.15 * sin(_time * 2.4),
      );
    canvas.drawLine(
      eyeP + const Offset(26, 2),
      lensP - const Offset(0, 10),
      beam,
    );
    canvas.drawLine(
      lensP - const Offset(0, 10),
      pivot + const Offset(0, 2),
      beam,
    );
    _drawCrystalBlade(
      canvas,
      lensP,
      8,
      26,
      heat: 0.55 + 0.15 * sin(_time * 3.0),
    );
    paintLead(canvas, Path()..addRect(panel), _kBarrowGlass, width: 3.4);
  }

  // ── The Palm: the maxim's cluster ───────────────────────

  static const List<(double, double, double)> _kPalmBlades = [
    (-34.0, 46.0, -0.22),
    (-16.0, 74.0, -0.08),
    (2.0, 104.0, 0.02),
    (20.0, 66.0, 0.14),
    (38.0, 38.0, 0.26),
  ];

  /// TAKEN ROOT. The crystal comes up through the Palm as the rite binds —
  /// veins running the creases out to the fingers first, then the blades, the
  /// tallest last — and after that it is simply there, leaded and gleaming.
  void _drawPalmCrystal(Canvas canvas, Offset c, Path palm) {
    final g = _palmGrow.clamp(0.0, 1.0);
    if (g <= 0) return;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c + const Offset(0, 6),
        86 * (0.5 + 0.5 * g),
        _kBarrowGlass.live.withValues(
          alpha: (0.14 + 0.05 * sin(_time * 1.3)) * g,
        ),
      );
    }
    canvas.drawPath(
      palm,
      Paint()..color = _kBarrowGlass.live.withValues(alpha: 0.08 * g),
    );
    // Veins first: the crystal finds the creases.
    final veins = (g / 0.35).clamp(0.0, 1.0);
    for (var i = 0; i < 4; i++) {
      final t = i / 3;
      final end = Offset(c.dx - 66 + t * 132, c.dy - 30);
      final ctrl = Offset(c.dx - 40 + t * 80, c.dy - 6);
      final start = Offset(c.dx, c.dy + 10);
      final path = Path()..moveTo(start.dx, start.dy);
      // Grow along the curve.
      const steps = 10;
      final n = (steps * veins).round();
      for (var k = 1; k <= n; k++) {
        final u = k / steps;
        final w = 1 - u;
        final p = start * (w * w) + ctrl * (2 * w * u) + end * (u * u);
        path.lineTo(p.dx, p.dy);
      }
      paintLead(
        canvas,
        path,
        _kBarrowGlass,
        width: 4.4,
        light: _kBarrowGlass.liveCore,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = _kBarrowGlass.liveCore.withValues(alpha: 0.7),
      );
    }
    // Then the blades, smallest first, each growing out of the hand.
    final order = [4, 0, 3, 1, 2];
    for (var j = 0; j < order.length; j++) {
      final (dx, h, lean) = _kPalmBlades[order[j]];
      final k = ((g - 0.3 - j * 0.1) / 0.3).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final eased = Curves.easeOutBack.transform(k);
      _drawCrystalBlade(
        canvas,
        c + Offset(dx, 18),
        7.0 + h * 0.075,
        h * eased,
        lean: lean,
        heat: 0.45 + 0.2 * sin(_time * 0.7 + dx * 0.05),
      );
      if (k < 1 && _fx.ready) {
        final tip =
            c +
            Offset(dx, 18) +
            Offset(sin(lean) * h * eased, -cos(lean) * h * eased);
        drawGlow(
          canvas,
          _fx.mote!,
          tip,
          8,
          _kBarrowGlass.liveCore.withValues(alpha: 0.8 * (1 - k)),
        );
      }
    }
  }
}
