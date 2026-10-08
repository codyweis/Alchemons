// lib/games/planet_dungeon/planet_dungeon_game_ice_art.dart
//
// GLACIUS, IN GLASS (docs/dungeons.md §7.11) — Ice's walls and the glass it
// signals with, as a part of planet_dungeon_game.dart.
//
// The observatory's ground was already built (the 2026-09-15 pass: strata,
// crazes, brass arcs, all baked) and it stays. What it gains:
//
//   · walls — the observatory's blue stone, round every room;
//   · the ROOF OF THE HOLLOW is a leaded window: every pane over the wyrm is
//     held in came, so snow, bared glass and open water read as one window
//     you are opening pane by pane;
//   · every mirror in the gallery is a lancet with tracery in its glass;
//   · and the STAR-WALKER — the maxim — no longer takes the telescope away.
//     The instrument stays where you left it, locked on its bearing, and the
//     stranger it found is caught in its lens as an eight-pointed star of
//     leaded glass that assembles as the rite binds.

part of 'planet_dungeon_game.dart';

const GlassPalette _kFrostGlass = kFrostGlass;

final Map<String, ui.Picture> _iceShellCache = {};

extension FrozenObservatoryArt on PlanetDungeonGame {
  void _updateIceGlass(double dt) {
    final target =
        discoveredClouds.contains(kIceStarWalkerEggId) ||
            _ritePendingEgg == kIceStarWalkerEggId
        ? 1.0
        : 0.0;
    if (_starCaught < 0) {
      _starCaught = target;
    } else if (_starCaught < target) {
      _starCaught = min(target, _starCaught + dt / 2.4);
    } else if (_starCaught > target) {
      _starCaught = target;
    }
  }

  /// The observatory's walls, baked once per room, over its own ground.
  void _renderIceShell(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _iceShellCache.putIfAbsent(
        '${room.id}|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          paintCarvedRoomShell(
            Canvas(rec),
            b,
            _kFrostGlass,
            GlassRng(glassSeed(room.id, b)),
            doors: room.doors.map((d) => d.rect),
            arcade: false,
            flags: false,
          );
          return rec.endRecording();
        },
      ),
    );
  }

  /// The roof's lead: every pane held in came, so the whole floor over the
  /// wyrm reads as one window.
  void _drawRoofLead(Canvas canvas, List<Rect> panes) {
    final lead = Path();
    for (final r in panes) {
      lead.addRect(r);
    }
    paintLead(canvas, lead, _kFrostGlass, width: 3.2);
  }

  /// A mirror's tracery: a mullion and two transoms in lead, and a lancet
  /// head — so a frame reads as a window of the gallery, not a panel.
  void _drawMirrorTracery(Canvas canvas, Rect glass) {
    final t = Path()
      ..moveTo(glass.center.dx, glass.top + glass.height * 0.28)
      ..lineTo(glass.center.dx, glass.bottom)
      ..moveTo(glass.left, glass.top + glass.height * 0.55)
      ..lineTo(glass.right, glass.top + glass.height * 0.55)
      ..moveTo(glass.left, glass.top + glass.height * 0.8)
      ..lineTo(glass.right, glass.top + glass.height * 0.8);
    final head = Rect.fromLTWH(
      glass.left,
      glass.top,
      glass.width,
      glass.height * 0.34,
    );
    t.addPath(lancetPath(head, AxisDirection.up), Offset.zero);
    paintLead(canvas, t, _kFrostGlass, width: 1.8);
  }

  /// THE STRANGER, CAUGHT. An eight-pointed star of leaded glass in the
  /// telescope's objective — its points filling in turn as the rite binds,
  /// then glinting there for good.
  void _drawCaughtStar(Canvas canvas, Offset eye) {
    final s = _starCaught.clamp(0.0, 1.0);
    if (s <= 0) return;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        eye,
        30 + 20 * s,
        _kFrostGlass.live.withValues(
          alpha: s < 1 ? 0.5 * s : 0.26 + 0.08 * sin(_time * 1.2),
        ),
      );
    }
    paintRondel(canvas, eye, 13, _kFrostGlass, fill: _kFrostGlass.smoke);
    for (var i = 0; i < 8; i++) {
      final k = ((s * 1.4 - i * 0.05) / 0.5).clamp(0.0, 1.0);
      if (k <= 0) continue;
      final a = -pi / 2 + i * pi / 4;
      final long = i.isEven ? 12.0 : 7.0;
      final tip = eye + Offset(cos(a), sin(a)) * long * k;
      final l = eye + Offset(cos(a - 0.35), sin(a - 0.35)) * 3.4;
      final r = eye + Offset(cos(a + 0.35), sin(a + 0.35)) * 3.4;
      paintPane(
        canvas,
        Path()
          ..moveTo(l.dx, l.dy)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(r.dx, r.dy)
          ..close(),
        i.isEven ? _kFrostGlass.liveCore : _kFrostGlass.live,
        _kFrostGlass,
        lead: 1.2,
      );
    }
    canvas.drawCircle(eye, 2.4, Paint()..color = Colors.white);
    if (s >= 1) {
      final glint = pow(0.5 + 0.5 * sin(_time * 0.8), 8).toDouble();
      final arm = 4 + 10 * glint;
      final p = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.3 + 0.6 * glint);
      canvas.drawLine(eye - Offset(arm, 0), eye + Offset(arm, 0), p);
      canvas.drawLine(eye - Offset(0, arm), eye + Offset(0, arm), p);
    }
  }
}

// ═══════════════════════════════════════════════════════════
// THE PROPS, IN THE GAME'S OWN LANGUAGE (2026-10-08)
// ═══════════════════════════════════════════════════════════
//
// The observatory's stone and glass stay as they were; what changed is the
// things standing in it. Three rules, one per kind of thing:
//
//   · COLD ITSELF IS GRAINS. The snow over the shaft (it was puff-sprite
//     clouds and wind streaks), the rime coming down every room (it was
//     sixteen white dashes), the icicle fringe (flat triangles with a stroked
//     highlight, now rime beards: dense at the lip, thinning to the tip), and
//     the hoarfrost pillar in the hollow — "feathered rime", so it is built
//     from grain plumes, and a shattered one is a stump with its grains
//     strewn round it and the ghost of the plumes over it.
//   · ICE THAT IS A PUZZLE PIECE IS ITS ORB. The orrery's star-blocks were
//     white faceted stickers; each is now the Codex's Ice orb carrying its
//     figure in leaded lines, and a seated one sits in a brass ring.
//   · SOLID THINGS ARE DARK CARVED SILHOUETTES. The telescope is iron, rim
//     lit, its objective a rondel of glass; the crates and instrument cases
//     are fewer blocks of the observatory's own stone; the ice rubble is
//     near-black glacier with only its top edges catching the light; the
//     orrery's crank is a carved pedestal with a glass knob.
//
// COST. Shapes and pictures are built once and cached. Live grains per room:
// ~190–580 rime falling, ~700–1,350 in the beards, ~850 snow over the sky
// (screen space, by viewport); the hollow's pillar ~1,500 standing and
// ~1,900 broken (ghost, stumps, shards), the sump's running fall ~570, each
// star-block orb 420. No blur; the haze is one baked picture of gradients.

/// Ice's grains: deep glacier, ice, frost, white.
const List<Color> _kRimeRamp = [
  Color(0xFF2E5A72),
  Color(0xFF9FC8DC),
  Color(0xFFDCEEF7),
  Color(0xFFFFFFFF),
];

/// The sky's snow (far, near) and the haze under it, by viewport size.
final Map<String, (GrainShape, GrainShape, ui.Picture)> _iceSkyCache = {};

/// Each room's rime fall (fine, coarse), by room id.
final Map<String, (GrainShape, GrainShape)> _iceRimeFallCache = {};

/// Each room's rime beards (the icicle fringe), by room id.
final Map<String, GrainShape?> _iceBeardCache = {};

/// Each room's carved furniture, baked.
final Map<String, ui.Picture?> _iceFurnitureCache = {};

/// Plumes, stumps and strewn shards, built once.
final Map<String, GrainShape> _iceShapes = {};

/// The orrery's star-blocks as Ice orbs, one per block (own clock each).
final Map<int, ElementOrb> _iceStarOrbs = {};

/// The running rimefall's wet sheen behind its grains.
const Color _kIcePaleSheen = Color(0x249FC8DC);

/// Grains laid by [density] (0..1, a chance to keep) through [box], each with
/// a random shade biased to the dim end — snow is mostly far away.
GrainShape _iceVeilGrains(
  Rect box,
  int count,
  int seed,
  double Function(Offset p) density,
) {
  final rng = Random(seed);
  final pts = <Offset>[];
  final shade = <double>[];
  var tries = 0;
  while (pts.length < count && tries < count * 40) {
    tries++;
    final p = Offset(
      box.left + rng.nextDouble() * box.width,
      box.top + rng.nextDouble() * box.height,
    );
    if (rng.nextDouble() > density(p)) continue;
    pts.add(p);
    shade.add(pow(rng.nextDouble(), 1.4).toDouble());
  }
  return GrainShape.points(pts, shade, seed: seed);
}

/// Curtains of thicker fall across [x], so snow has a grain to it rather
/// than being an even stipple.
double _iceCurtain(double x, double seed) {
  final v =
      0.5 + 0.32 * sin(x * 0.0123 + seed) + 0.18 * sin(x * 0.0391 + seed * 2.7);
  return (0.3 + 0.7 * v * v).clamp(0.0, 1.0);
}

extension FrozenObservatoryProps on PlanetDungeonGame {
  // ── The sky: snow and a cold haze, not puff clouds ──────────

  /// Screen-space weather over Glacius. It was the generic sky clouds (puff
  /// sprites) and wind streaks: summer weather, over a glacier.
  void _renderShaftSky(Canvas canvas, Size vp) {
    final key = '${vp.width.round()}x${vp.height.round()}';
    final (far, near, haze) = _iceSkyCache.putIfAbsent(
      key,
      () => _buildIceSky(vp),
    );
    canvas.save();
    canvas.translate(sin(_time * 0.031) * 26, cos(_time * 0.023) * 10);
    canvas.drawPicture(haze);
    canvas.restore();
    final c = Offset(vp.width / 2, vp.height / 2);
    final band = vp.height + 40;
    paintGrainShape(
      canvas,
      far,
      _time,
      origin: c,
      fall: band,
      fallSpeed: 12,
      drift: 7,
      alpha: 0.55,
      ramp: _kRimeRamp,
      glint: 0.006,
      width: 1.3,
      trail: 0.035,
    );
    paintGrainShape(
      canvas,
      near,
      _time,
      origin: c,
      fall: band,
      fallSpeed: 23,
      drift: 11,
      alpha: 0.75,
      ramp: _kRimeRamp,
      glint: 0.012,
      width: 1.8,
      trail: 0.035,
    );
  }

  (GrainShape, GrainShape, ui.Picture) _buildIceSky(Size vp) {
    final band = vp.height + 40;
    final box = Rect.fromLTWH(
      -vp.width / 2 - 20,
      -band / 2,
      vp.width + 40,
      band,
    );
    final area = vp.width * vp.height;
    final far = _iceVeilGrains(
      box,
      (area / 760).round().clamp(300, 1100),
      52,
      (p) => _iceCurtain(p.dx, 1.3),
    );
    final near = _iceVeilGrains(
      box,
      (area / 4200).round().clamp(60, 220),
      53,
      (p) => _iceCurtain(p.dx, 4.1),
    );
    // The haze: a few broad, faint gradients — cold light caught in the air
    // over the shaft, thickest toward the top.
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rng = Random(52);
    for (var i = 0; i < 11; i++) {
      final o = Offset(
        rng.nextDouble() * vp.width,
        vp.height * pow(rng.nextDouble(), 1.6).toDouble(),
      );
      final r = 140 + rng.nextDouble() * 180;
      c.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFCFE6F2).withValues(alpha: 0.05 + 0.015 * (i % 3)),
              const Color(0x00CFE6F2),
            ],
          ).createShader(Rect.fromCircle(center: o, radius: r)),
      );
    }
    return (far, near, rec.endRecording());
  }

  // ── The rime coming down every room ─────────────────────────

  /// A thin fall of rime through the room: a fine slow layer and a few
  /// nearer, faster grains. It was sixteen white dashes, which read as rain.
  void _paintRimeFall(Canvas canvas, DungeonRoom room) {
    final b = room.bounds.deflate(8);
    final (fine, coarse) = _iceRimeFallCache.putIfAbsent(room.id, () {
      final box = Rect.fromCenter(
        center: Offset.zero,
        width: b.width,
        height: b.height,
      );
      final area = b.width * b.height;
      final seed = room.id.length * 31 + b.width.round();
      return (
        _iceVeilGrains(
          box,
          (area / 1500).round().clamp(150, 480),
          seed,
          (p) => _iceCurtain(p.dx, seed * 0.1),
        ),
        _iceVeilGrains(
          box,
          (area / 6000).round().clamp(40, 130),
          seed + 1,
          (p) => _iceCurtain(p.dx, seed * 0.37),
        ),
      );
    });
    // Never over the gallery's pool: its stars are the thing that room is
    // read by, and falling grains in it would be stars that are not there.
    final ring = room.rime?.mirrors;
    if (ring != null) {
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(b.inflate(4))
          ..addOval(
            Rect.fromCircle(center: ring.center, radius: ring.radius - 26),
          ),
      );
    }
    paintGrainShape(
      canvas,
      fine,
      _time,
      origin: b.center,
      fall: b.height,
      fallSpeed: 15,
      drift: 5,
      alpha: 0.5,
      ramp: _kRimeRamp,
      glint: 0.006,
      width: 1.4,
      trail: 0.035,
    );
    paintGrainShape(
      canvas,
      coarse,
      _time,
      origin: b.center,
      fall: b.height,
      fallSpeed: 27,
      drift: 7,
      alpha: 0.66,
      ramp: _kRimeRamp,
      glint: 0.012,
      width: 1.8,
      trail: 0.035,
    );
    if (ring != null) canvas.restore();
  }

  // ── The icicle fringe, as rime beards ───────────────────────

  void _paintRimeBeards(Canvas canvas, DungeonRoom room, _ShaftGround g) {
    final shape = _iceBeardCache.putIfAbsent(
      room.id,
      () => g.icicles.isEmpty ? null : _buildRimeBeards(g, room.id.length),
    );
    if (shape == null) return;
    paintGrainShape(
      canvas,
      shape,
      _time,
      drift: 0.35,
      alpha: 0.95,
      ramp: _kRimeRamp,
      glint: 0.018,
      width: 1.5,
      trail: 0.035,
    );
  }

  /// Each icicle as a beard of rime: packed and bright at the lip it grows
  /// from, thinning and dimming to its tip — the taper is density, not an
  /// outline.
  GrainShape _buildRimeBeards(_ShaftGround g, int seed) {
    final rng = Random(seed * 97 + g.icicles.length);
    final pts = <Offset>[];
    final shade = <double>[];
    for (var k = 0; k < g.icicles.length; k++) {
      final r = g.icicles[k];
      final mid = r.left + r.width * 0.5;
      final tipX = mid + g.icicleTip[k];
      final n = (r.width * r.height / 3.4).round().clamp(24, 240);
      for (var i = 0; i < n; i++) {
        final t = pow(rng.nextDouble(), 1.5).toDouble();
        final half = r.width * 0.55 * pow(1 - t, 0.8) + 0.5;
        final cx = mid + (tipX - mid) * t;
        final u = rng.nextDouble() * 2 - 1;
        pts.add(Offset(cx + u * half, r.top + t * r.height));
        // Lit down its near side, dimmer at the back and toward the tip.
        shade.add((1 - 0.65 * t) * (0.62 + 0.38 * (0.5 - 0.5 * u)));
      }
      // A bead at the very tip, about to go.
      pts.add(Offset(tipX, r.top + r.height + 1.5));
      shade.add(0.9);
      // The lip it hangs from, packed.
      for (var x = r.left - 5; x <= r.right + 5; x += 1.6) {
        pts.add(Offset(x, r.top + rng.nextDouble() * 3.5));
        shade.add(0.55 + 0.35 * rng.nextDouble());
      }
    }
    return GrainShape.points(pts, shade, seed: seed);
  }

  // ── Carved furniture: fewer, darker ─────────────────────────

  /// The shelves' crates and instrument cases, as blocks of the
  /// observatory's own stone — near-black, lit only along the arris. Baked.
  void _renderIceFurniture(Canvas canvas, DungeonRoom room) {
    final pic = _iceFurnitureCache.putIfAbsent(room.id, () {
      final b = room.bounds;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      const p = _kFrostGlass;
      const top = Color(0xFF1E2A34);
      switch (room.id) {
        case 'shelf_glass':
          // Two blocks the ice has taken, one each side of the niche (there
          // were three crates).
          final n = Offset(b.left + 210, b.top + 232);
          for (final (dx, dy, w, h) in const [
            (-146.0, 30.0, 52.0, 24.0),
            (148.0, 30.0, 58.0, 28.0),
          ]) {
            final r = Rect.fromCenter(
              center: n + Offset(dx, dy - h * 0.5),
              width: w,
              height: 16,
            );
            paintContactShadow(
              c,
              r.bottomCenter + Offset(0, h + 2),
              w * 1.2,
              12,
              opacity: 0.4,
            );
            paintCarvedBlock(c, r, h, p, radius: 2, topColor: top);
            // Rime along the top's back edge.
            c.drawLine(
              r.topLeft + const Offset(3, 1),
              r.topRight + const Offset(-3, 1),
              Paint()
                ..strokeWidth = 1.2
                ..color = const Color(0xFFBFE6FA).withValues(alpha: 0.22),
            );
          }
        case 'shelf_lens':
          // The bracket shelf, and two stowed cases on it (there were three).
          final sy = b.top + 128.0;
          paintCarvedBlock(
            c,
            Rect.fromLTRB(b.left + 18, sy - 5, b.left + 128, sy + 2),
            8,
            p,
            radius: 1.5,
            topColor: top,
          );
          for (final (x, w, h) in const [
            (26.0, 30.0, 26.0),
            (66.0, 24.0, 20.0),
          ]) {
            paintCarvedBlock(
              c,
              Rect.fromLTWH(b.left + x, sy - 5 - h - 7, w, 7),
              h,
              p,
              radius: 1.5,
              topColor: top,
            );
          }
        default:
          return null;
      }
      return rec.endRecording();
    });
    if (pic != null) canvas.drawPicture(pic);
  }

  // ── The hoarfrost pillar, as feathered rime ─────────────────

  static const List<double> _kPlumeLen = [96, 70, 118, 58, 84];
  static const List<double> _kPlumeAt = [-26, -8, 6, 22, 34];
  static const List<double> _kPlumeLean = [-0.16, -0.05, 0.02, 0.09, 0.17];

  GrainShape _plume(double len) => _iceShapes.putIfAbsent(
    'plume|${len.round()}',
    () => GrainShape.feather(len, seed: len.round()),
  );

  /// "Feathered rime, grown taller than a man": five upright plumes of grain
  /// off a rimed foot. Shattered: "a broken stump, and its shards all round
  /// it" — short plumes, the shards' grains lying on the floor, and the
  /// ghost of the pillar that belongs here so the room says what it lacks.
  void _paintHoarfrost(Canvas canvas, Offset p, bool whole) {
    final foot = p + const Offset(0, 48);
    final pool = Rect.fromCenter(center: foot, width: 150, height: 54);
    // Its cold on the floor round it: a faint gradient, never a ring.
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFCFE6F2).withValues(alpha: whole ? 0.16 : 0.11),
            const Color(0x00CFE6F2),
          ],
        ).createShader(pool),
    );
    // The socket it grows from: carved, its bed lit.
    paintCarvedDisc(
      canvas,
      foot - const Offset(0, 4),
      36,
      10,
      5,
      _kFrostGlass,
      topColor: const Color(0xFF16242F),
    );
    canvas.drawOval(
      Rect.fromCenter(center: foot - const Offset(0, 4), width: 56, height: 14),
      Paint()
        ..color = _kFrostGlass.liveDeep.withValues(alpha: whole ? 0.5 : 0.8),
    );
    for (var i = 0; i < 5; i++) {
      final len = _kPlumeLen[i];
      final lean = _kPlumeLean[i] + sin(_time * 0.5 + i * 1.9) * 0.012;
      final root = foot + Offset(_kPlumeAt[i], -6);
      Offset centreOf(double l) =>
          root + Offset(sin(lean), -cos(lean)) * (l * 0.5);
      if (whole) {
        paintGrainShape(
          canvas,
          _plume(len),
          _time,
          origin: centreOf(len),
          rotation: -pi / 2 + lean,
          drift: 0.5,
          ramp: _kRimeRamp,
          glint: 0.02,
          width: 1.6,
          trail: 0.035,
        );
        continue;
      }
      // The ghost of the pillar that stood here, faint and loose: the three
      // tallest plumes are enough to say what is missing.
      if (len < 80) continue;
      paintGrainShape(
        canvas,
        _plume(len),
        _time,
        origin: centreOf(len),
        rotation: -pi / 2 + lean,
        drift: 1.4,
        alpha: 0.11,
        ramp: _kRimeRamp,
        width: 1.3,
        trail: 0.035,
      );
    }
    if (!whole) {
      // The stumps: packed rime broken off ragged, the fracture the brightest
      // thing on them.
      paintGrainShape(
        canvas,
        _iceShapes.putIfAbsent('stumps', _buildHoarStumps),
        _time,
        origin: foot,
        drift: 0.3,
        ramp: _kRimeRamp,
        glint: 0.04,
        width: 1.7,
        trail: 0.035,
      );
      // The shards, where it went: little drifts of its grains on the floor.
      final shards = _iceShapes.putIfAbsent('shards', () {
        final rng = Random(7);
        final pts = <Offset>[];
        final shade = <double>[];
        for (var i = 0; i < 7; i++) {
          final a = i * 0.9;
          final q = Offset(cos(a) * (40 + i * 9), 48 + sin(a) * 16);
          for (var k = 0; k < 22; k++) {
            final u = rng.nextDouble() + rng.nextDouble() - 1;
            final v = rng.nextDouble() + rng.nextDouble() - 1;
            pts.add(q + Offset(u * 9, v * 3.5));
            shade.add(0.35 + 0.65 * rng.nextDouble());
          }
        }
        return GrainShape.points(pts, shade, seed: 7);
      });
      paintGrainShape(
        canvas,
        shards,
        _time,
        origin: p,
        drift: 0.4,
        alpha: 0.85,
        ramp: _kRimeRamp,
        glint: 0.03,
        width: 1.5,
        trail: 0.035,
      );
    }
  }

  /// Five broken stumps where the plumes stood, relative to the foot: a
  /// column of packed rime each, narrowing a little, its top torn ragged
  /// and lit, and a stub or two of barb still standing off it.
  GrainShape _buildHoarStumps() {
    final rng = Random(11);
    final pts = <Offset>[];
    final shade = <double>[];
    for (var i = 0; i < 5; i++) {
      final x0 = _kPlumeAt[i];
      final h = 26.0 + (i % 3) * 9;
      final w = 4.5 + (i % 2) * 1.5;
      // A ragged top: three heights across the break.
      final tops = [
        for (var k = 0; k < 3; k++) h * (0.72 + 0.28 * rng.nextDouble()),
      ];
      double topAt(double u) {
        final f = (u + 1) * 1.0;
        final k = f.floor().clamp(0, 1);
        return tops[k] + (tops[k + 1] - tops[k]) * (f - k);
      }

      final n = (h * w * 0.8).round();
      for (var k = 0; k < n; k++) {
        final u = rng.nextDouble() * 2 - 1;
        final top = topAt(u);
        final y = rng.nextDouble() * top;
        final narrow = 1 - 0.25 * y / h;
        pts.add(Offset(x0 + u * w * narrow, -6 - y));
        shade.add(0.4 + 0.6 * (y / top) * (0.75 + 0.25 * (0.5 - 0.5 * u)));
      }
      // The fracture face, packed bright along the break.
      for (var u = -1.0; u <= 1.0; u += 0.12) {
        pts.add(Offset(x0 + u * w, -6 - topAt(u) + rng.nextDouble()));
        shade.add(1);
      }
      // A stub of barb or two, still swept up off the column.
      for (final side in const [-1.0, 1.0]) {
        if (rng.nextDouble() < 0.35) continue;
        final y = h * (0.3 + 0.35 * rng.nextDouble());
        for (var j = 1; j <= 5; j++) {
          pts.add(Offset(x0 + side * (w + j * 1.6), -6 - y - j * 1.1));
          shade.add(0.8 - j * 0.08);
        }
      }
    }
    return GrainShape.points(pts, shade, seed: 11);
  }

  // ── The rimefall ────────────────────────────────────────────

  /// Running: water coming down the chute in grains, fast, through a faint
  /// wet sheen, and spray churning where it lands. [r] is the fall's box.
  void _paintRimefallWater(Canvas canvas, Rect r) {
    final top = r.top - 24;
    final band = r.bottom - top;
    final o = Offset(r.center.dx, top + band / 2);
    canvas.drawPath(
      Path()
        ..moveTo(r.left + 22, top)
        ..lineTo(r.right - 22, top)
        ..lineTo(r.right - 6, r.bottom)
        ..lineTo(r.left + 6, r.bottom)
        ..close(),
      Paint()..color = _kIcePaleSheen,
    );
    final water = _iceShapes.putIfAbsent('fall|${band.round()}', () {
      final wTop = r.width / 2 - 24, wBot = r.width / 2 - 10;
      return GrainShape.region(
        Rect.fromLTWH(-wBot, -band / 2, wBot * 2, band),
        (p) => p.dx.abs() < wTop + (p.dy / band + 0.5) * (wBot - wTop),
        420,
        seed: 21,
      );
    });
    paintGrainShape(
      canvas,
      water,
      _time,
      origin: o,
      fall: band,
      fallSpeed: 150,
      drift: 1.2,
      alpha: 0.85,
      ramp: _kRimeRamp,
      glint: 0.02,
      width: 1.6,
      trail: 0.035,
    );
    final spray = _iceShapes.putIfAbsent('spray', () {
      final rng = Random(22);
      final pts = <Offset>[];
      final shade = <double>[];
      for (var k = 0; k < 150; k++) {
        final u = rng.nextDouble() + rng.nextDouble() - 1;
        final v = rng.nextDouble() + rng.nextDouble() - 1;
        pts.add(Offset(u * 62, v * 11 - 2));
        shade.add(0.3 + 0.7 * (1 - u.abs()) * rng.nextDouble());
      }
      return GrainShape.points(pts, shade, seed: 22);
    });
    paintGrainShape(
      canvas,
      spray,
      _time,
      origin: Offset(r.center.dx, r.bottom + 4),
      drift: 5,
      alpha: 0.8,
      ramp: _kRimeRamp,
      glint: 0.03,
      width: 1.5,
      trail: 0.035,
    );
  }

  /// The throat's water going down its wet black pipe, seen from above:
  /// grains falling fast across the mouth [r] (the caller clips to it).
  void _paintThroatWater(Canvas canvas, Rect r) {
    final shape = _iceShapes.putIfAbsent(
      'throat|${r.width.round()}x${r.height.round()}',
      () => GrainShape.region(
        Rect.fromCenter(
          center: Offset.zero,
          width: r.width - 16,
          height: r.height,
        ),
        (_) => true,
        130,
        seed: 23,
      ),
    );
    paintGrainShape(
      canvas,
      shape,
      _time,
      origin: r.center,
      fall: r.height,
      fallSpeed: 140,
      drift: 1,
      alpha: 0.65,
      ramp: _kRimeRamp,
      glint: 0.015,
      width: 1.7,
      trail: 0.035,
    );
  }

  /// Frozen: five fluted columns of leaded glass fused together, and the fan
  /// it froze into at the foot.
  void _paintRimefallIce(Canvas canvas, Rect r) {
    for (var i = 0; i < 5; i++) {
      final w = 14.0 + (i % 3) * 7;
      final x = r.left + 10 + i * 21.0;
      final foot = r.bottom - (i % 2) * 12;
      final flute = Path()
        ..moveTo(x, r.top - 24)
        ..lineTo(x + w, r.top - 24)
        ..lineTo(x + w * 0.72, foot)
        ..lineTo(x + w * 0.18, foot)
        ..close();
      paintPane(
        canvas,
        flute,
        Color.lerp(
          _kFrostGlass.liveDeep,
          _kFrostGlass.live,
          0.45 + 0.25 * (i % 3),
        )!.withValues(alpha: 0.9),
        _kFrostGlass,
        lead: 1.8,
      );
      paintStreak(
        canvas,
        Rect.fromLTRB(x + 1, r.top - 20, x + w * 0.6, foot - 6),
        opacity: 0.55,
      );
    }
    paintPane(
      canvas,
      Path()
        ..moveTo(r.left - 24, r.bottom + 26)
        ..lineTo(r.left + 14, r.bottom - 10)
        ..lineTo(r.right - 14, r.bottom - 10)
        ..lineTo(r.right + 26, r.bottom + 26)
        ..close(),
      Color.lerp(
        _kFrostGlass.frostAt(1),
        _kFrostGlass.live,
        0.45,
      )!.withValues(alpha: 0.85),
      _kFrostGlass,
      lead: 2.2,
    );
  }

  // ── The orrery's star-blocks, as Ice orbs ───────────────────

  /// A star-block is a lump of frozen sky the floor asks you to place: the
  /// Ice orb, carrying its own figure in lead so the block and the kerb cut
  /// for it are still recognisably the same one. Seated, it sits in a ring
  /// of the sockets' brass and its figure takes the gold.
  void _paintStarOrb(Canvas canvas, Offset p, int id, bool seated) {
    const r = 24.0;
    const core = 16.5;
    paintContactShadow(canvas, p + const Offset(0, r * 0.8), r * 2.2, r * 0.6);
    if (seated) {
      canvas.drawCircle(
        p,
        r + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _kFrostGlass.gold.withValues(alpha: 0.9),
      );
    }
    final orb = _iceStarOrbs.putIfAbsent(
      id,
      () => ElementOrb(EssenceElement.of('Ice'), radius: r, grains: 420),
    );
    orb.paint(canvas, p, _time * 0.8 + id * 1.7);
    // THE FIGURE IS THE READOUT, so it is not drawn over the grains: a disc
    // of dark glass is set into the orb's face, leaded round, and the figure
    // sits on that — the ice turns in the band round it. (Drawn straight on
    // the grains it was lost in them.)
    canvas.drawCircle(p, core + 1.6, Paint()..color = _kFrostGlass.lead);
    canvas.drawCircle(p, core, Paint()..color = const Color(0xFF06121B));
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: core - 1.4),
      pi * 1.1,
      pi * 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = _kFrostGlass.leadLight.withValues(alpha: 0.35),
    );
    final box = Rect.fromCenter(center: p, width: 24, height: 24);
    // Its figure, leaded and bold: the came first, then the line it catches,
    // and its stars bright.
    _drawStarFigure(canvas, box, id, _kFrostGlass.lead, 3.6);
    _drawStarFigure(
      canvas,
      box,
      id,
      seated ? _kFrostGlass.gold : _kFrostGlass.silver,
      1.9,
    );
  }
}
