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
    // The diagram is LEADED INTO the window (2026-10-08): came with a gold
    // line in it, and the eye a lens-shaped pane of its own — it was gold
    // strokes drawn over the glass, which read as an icon on a panel.
    void leadIn(Path path) {
      paintLead(
        canvas,
        path,
        _kBarrowGlass,
        width: 3.8,
        light: _kBarrowGlass.gold,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = _kBarrowGlass.gold.withValues(alpha: 0.8),
      );
    }

    final eyeP = Offset(panel.left + 90, panel.center.dy);
    final lens = Path()
      ..moveTo(eyeP.dx - 28, eyeP.dy)
      ..quadraticBezierTo(eyeP.dx, eyeP.dy - 24, eyeP.dx + 28, eyeP.dy)
      ..quadraticBezierTo(eyeP.dx, eyeP.dy + 24, eyeP.dx - 28, eyeP.dy)
      ..close();
    paintPaneFill(
      canvas,
      lens,
      Color.lerp(_kBarrowGlass.frostAt(2), _kBarrowGlass.liveDeep, 0.6)!,
    );
    leadIn(lens);
    paintRondel(canvas, eyeP, 8, _kBarrowGlass, fill: _kBarrowGlass.heat(0.45));
    final pivot = Offset(panel.center.dx + 60, panel.center.dy - 14);
    final scale = Path()
      ..moveTo(pivot.dx - 80, pivot.dy + 8)
      ..lineTo(pivot.dx + 80, pivot.dy - 8)
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(pivot.dx, pivot.dy + 30);
    for (final side in const [-1.0, 1.0]) {
      final panC = pivot + Offset(side * 80, side * -8 + 22);
      scale.addArc(Rect.fromCircle(center: panC, radius: 16), 0, pi);
    }
    leadIn(scale);
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

// ═══════════════════════════════════════════════════════════
// THE PROPS, IN THE GAME'S OWN LANGUAGE (2026-10-08)
// ═══════════════════════════════════════════════════════════
//
// The barrow's strata, walls and crystal stay as they were. What changed is
// the giant and the things lying about in it:
//
//   · THE GIANT IS CARVED STONE, NOT BEIGE CARTOON BONE. Every length of it
//     — ribs, fingers, the palm, the processes of the spine, the rib levers —
//     is near-black stone lit only along its upper edge, so the hand, the
//     cage and the levers read as relief cut into the barrow. The heart is a
//     heart-stone of the same dark, anatomical rather than a valentine, its
//     crystal veins the only light in it; it no longer throws a ring.
//   · EARTH ITSELF IS GRAINS. The dust over the barrow (puff-sprite veils
//     and four glow motes) sifts down in grains over a faint haze, and the
//     rubble at the dolmen's feet is crumbled earth, not pebbles.
//   · WHAT YOU READ IS INLAY OR GLASS. The giant's tablets carry their scale
//     as gold inlaid in a cut groove (it was a stroked amber icon); the
//     weights on the scale and floor are carved stones with their sigils cut
//     in gold; the mural's diagram is leaded into its window.
//
// COST. The hand, the rib walls and the sternum's skeleton are baked once.
// Live grains: ~650–900 dust over the sky (screen space, by viewport) and
// ~410 in the gate's rubble. No blur; the haze is one baked picture.

/// Earth's dust: deep loam, ochre, bone, pale bone (never white).
const List<Color> _kBarrowDustRamp = [
  Color(0xFF3A2C1C),
  Color(0xFF8A6E48),
  Color(0xFFC8AC7A),
  Color(0xFFEAD9B0),
];

/// The carved giant's stone: its dark, its lit face, and the light it
/// catches at the rim.
const Color _kGiantDark = Color(0xFF130E09);
const Color _kGiantFace = Color(0xFF2E2318);
const Color _kGiantRim = Color(0xFFC8A872);

/// The lit top of a carved piece of it (a disc, a weight).
const Color _kGiantTop = Color(0xFF3A2C1D);

/// The sky's dust (fine, near) and the haze under it, by viewport size.
final Map<String, (GrainShape, GrainShape, ui.Picture)> _barrowDustCache = {};

/// The giant's static anatomy, baked: the hand, each rib hall's cage, the
/// sternum court's skeleton.
final Map<String, ui.Picture> _barrowBoneCache = {};

/// Small shapes built once (the gate's rubble).
final Map<String, GrainShape> _barrowShapes = {};

/// The heart-stone's outline at unit size, built once (a path union is not
/// something to do every frame).
final Map<String, Path> _barrowPaths = {};

/// Gradient paints in a prop's own (unit) space, built once.
final Map<String, Paint> _barrowPaints = {};

extension BuriedGiantProps on PlanetDungeonGame {
  // ── The dust over the barrow ────────────────────────────────

  /// Grave-dust sifting down through a faint warm haze, in grains: a fine
  /// slow layer and a few nearer grains. Denser in drifting curtains, so it
  /// reads as dust falling and not as a stipple.
  void _renderBarrowDust(Canvas canvas, Size vp) {
    final key = '${vp.width.round()}x${vp.height.round()}';
    final (fine, near, haze) = _barrowDustCache.putIfAbsent(key, () {
      final band = vp.height + 40;
      final box = Rect.fromLTWH(
        -vp.width / 2 - 20,
        -band / 2,
        vp.width + 40,
        band,
      );
      final area = vp.width * vp.height;
      GrainShape veil(int n, int seed, double phase) {
        final rng = Random(seed);
        final pts = <Offset>[];
        final shade = <double>[];
        var tries = 0;
        while (pts.length < n && tries < n * 40) {
          tries++;
          final p = Offset(
            box.left + rng.nextDouble() * box.width,
            box.top + rng.nextDouble() * box.height,
          );
          final v =
              0.5 +
              0.3 * sin(p.dx * 0.0097 + phase) +
              0.2 * sin(p.dx * 0.031 + phase * 3.1);
          if (rng.nextDouble() > 0.25 + 0.75 * v * v) continue;
          pts.add(p);
          shade.add(pow(rng.nextDouble(), 1.5).toDouble());
        }
        return GrainShape.points(pts, shade, seed: seed);
      }

      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final rng = Random(68);
      for (var i = 0; i < 10; i++) {
        final o = Offset(
          rng.nextDouble() * vp.width,
          vp.height * (0.2 + 0.8 * rng.nextDouble()),
        );
        final r = 150 + rng.nextDouble() * 170;
        c.drawCircle(
          o,
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(
                  0xFF8A6E48,
                ).withValues(alpha: 0.05 + 0.012 * (i % 3)),
                const Color(0x008A6E48),
              ],
            ).createShader(Rect.fromCircle(center: o, radius: r)),
        );
      }
      return (
        veil((area / 820).round().clamp(280, 1000), 67, 0.7),
        veil((area / 5200).round().clamp(50, 180), 68, 2.3),
        rec.endRecording(),
      );
    });
    canvas.save();
    canvas.translate(sin(_time * 0.027) * 22, 0);
    canvas.drawPicture(haze);
    canvas.restore();
    final c = Offset(vp.width / 2, vp.height / 2);
    final band = vp.height + 40;
    paintGrainShape(
      canvas,
      fine,
      _time,
      origin: c,
      fall: band,
      fallSpeed: 7,
      drift: 9,
      alpha: 0.5,
      ramp: _kBarrowDustRamp,
      glint: 0.004,
      width: 1.3,
      trail: 0.035,
    );
    paintGrainShape(
      canvas,
      near,
      _time,
      origin: c,
      fall: band,
      fallSpeed: 13,
      drift: 12,
      alpha: 0.62,
      ramp: _kBarrowDustRamp,
      glint: 0.008,
      width: 1.7,
      trail: 0.035,
    );
  }

  // ── The giant, carved ───────────────────────────────────────

  /// One length of the giant in carved stone between two edges: near-black,
  /// its upper half a lit face, the edge that faces up catching the light
  /// and the other sunk in its own shadow.
  void _paintCarvedBone(
    Canvas canvas,
    List<Offset> a,
    List<Offset> b,
    double alpha,
  ) {
    var ay = 0.0, by = 0.0;
    for (var i = 0; i < a.length; i++) {
      ay += a[i].dy;
      by += b[i].dy;
    }
    final top = ay <= by ? a : b;
    final low = ay <= by ? b : a;
    final body = Path()..moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      body.lineTo(p.dx, p.dy);
    }
    for (final p in low.reversed) {
      body.lineTo(p.dx, p.dy);
    }
    body.close();
    canvas.drawPath(
      body,
      Paint()..color = _kGiantDark.withValues(alpha: 0.92 * alpha),
    );
    // The lit face: from the upper edge to the bone's spine.
    final face = Path()..moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      face.lineTo(p.dx, p.dy);
    }
    for (var i = top.length - 1; i >= 0; i--) {
      final m = Offset.lerp(top[i], low[i], 0.5)!;
      face.lineTo(m.dx, m.dy);
    }
    face.close();
    canvas.drawPath(
      face,
      Paint()..color = _kGiantFace.withValues(alpha: 0.7 * alpha),
    );
    final rim = Path()..moveTo(top.first.dx, top.first.dy);
    for (final p in top.skip(1)) {
      rim.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _kGiantRim.withValues(alpha: 0.36 * alpha),
    );
    final under = Path()..moveTo(low.first.dx, low.first.dy);
    for (final p in low.skip(1)) {
      under.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      under,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.55 * alpha),
    );
  }

  /// A joint of the giant: a small dark boss with a lit upper rim.
  void _paintCarvedJoint(Canvas canvas, Offset c, double r, double alpha) {
    canvas.drawCircle(
      c,
      r,
      Paint()..color = _kGiantDark.withValues(alpha: 0.95 * alpha),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 0.6),
      pi * 1.08,
      pi * 0.84,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _kGiantRim.withValues(alpha: 0.4 * alpha),
    );
  }

  /// A groove cut into the floor or a slab: the dark of the cut and the lit
  /// lip on its far side.
  void _paintCarvedGroove(Canvas canvas, Path path, {double width = 2.4}) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawPath(
      path.shift(const Offset(0, 1.1)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..color = _kGiantRim.withValues(alpha: 0.22),
    );
  }

  /// Draws [key]'s picture, baking it with [paint] the first time.
  void _drawBakedBones(
    Canvas canvas,
    String key,
    void Function(Canvas c) paint,
  ) {
    canvas.drawPicture(
      _barrowBoneCache.putIfAbsent(key, () {
        final rec = ui.PictureRecorder();
        paint(Canvas(rec));
        return rec.endRecording();
      }),
    );
  }

  /// Gold inlaid in a cut: the groove, then the thread of gold in it.
  void _paintGoldInlay(Canvas canvas, Path path, {double width = 2.2}) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _kBarrowGlass.stoneFoot.withValues(alpha: 0.95),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _kBarrowGlass.goldDeep,
    );
    canvas.drawPath(
      path.shift(const Offset(0, -0.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.7, width * 0.4)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _kBarrowGlass.gold.withValues(alpha: 0.9),
    );
  }

  // ── The heart-stone ─────────────────────────────────────────

  /// The giant's heart as an organ, not a valentine: a heavy rounded cone
  /// leaning to its apex, with the great vessels cut off above it.
  Path _heartStonePath(Offset c, double w, double h) {
    final body = Path()
      ..moveTo(c.dx - 0.10 * w, c.dy + 0.46 * h) // apex, low and left
      ..cubicTo(
        c.dx - 0.46 * w,
        c.dy + 0.30 * h,
        c.dx - 0.56 * w,
        c.dy - 0.10 * h,
        c.dx - 0.38 * w,
        c.dy - 0.30 * h,
      )
      ..cubicTo(
        c.dx - 0.22 * w,
        c.dy - 0.46 * h,
        c.dx + 0.06 * w,
        c.dy - 0.40 * h,
        c.dx + 0.20 * w,
        c.dy - 0.34 * h,
      )
      ..cubicTo(
        c.dx + 0.48 * w,
        c.dy - 0.26 * h,
        c.dx + 0.52 * w,
        c.dy + 0.06 * h,
        c.dx + 0.30 * w,
        c.dy + 0.24 * h,
      )
      ..cubicTo(
        c.dx + 0.18 * w,
        c.dy + 0.36 * h,
        c.dx + 0.04 * w,
        c.dy + 0.44 * h,
        c.dx - 0.10 * w,
        c.dy + 0.46 * h,
      )
      ..close();
    // The aorta arching up and over to the left, and two cut vessels.
    final aorta = Path()
      ..moveTo(c.dx - 0.04 * w, c.dy - 0.36 * h)
      ..cubicTo(
        c.dx - 0.06 * w,
        c.dy - 0.66 * h,
        c.dx + 0.26 * w,
        c.dy - 0.70 * h,
        c.dx + 0.30 * w,
        c.dy - 0.50 * h,
      )
      ..lineTo(c.dx + 0.20 * w, c.dy - 0.46 * h)
      ..cubicTo(
        c.dx + 0.16 * w,
        c.dy - 0.58 * h,
        c.dx + 0.06 * w,
        c.dy - 0.56 * h,
        c.dx + 0.10 * w,
        c.dy - 0.34 * h,
      )
      ..close();
    final vena = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            c.dx - 0.30 * w,
            c.dy - 0.56 * h,
            c.dx - 0.18 * w,
            c.dy - 0.30 * h,
          ),
          Radius.circular(0.05 * w),
        ),
      );
    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, body, aorta),
      vena,
    );
  }
}
