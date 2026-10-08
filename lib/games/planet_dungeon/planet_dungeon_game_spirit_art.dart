// lib/games/planet_dungeon/planet_dungeon_game_spirit_art.dart
//
// REQUIA, IN GLASS (docs/dungeons.md §7.11) — the Unfinished Funeral's
// pictures, as a part of planet_dungeon_game.dart.
//
// ONE PLACE IN TWO TIMES. The same rooms and the same things in the same
// places: the present, moonlit and still, and the past, cold and luminous,
// with its people at work. Crossing over is a hard cross-fade — no dissolve,
// no blur (MaskFilter.blur is the game's known jank source; there is none
// here). Glass only on puzzle things: the memory crystals, the sockets, the
// flags' beams, the chime. Material, not lines: every shape is filled and lit.

part of 'planet_dungeon_game.dart';

const GlassPalette _kWraithGlass = kWraithGlass;

// MOONLIT, NOT MUDDY (2026-09-25, from the author: "spirit's colors don't
// look mystical"): blue-slate ground, silver stone, a luminous aqua for the
// past. Gold (the sockets' rims) and blood (a pulse) are the only warm things.
const Color _fSod = Color(0xFF131926);
const Color _fCold = Color(0xFF7FE0DA);
const Color _fVoid = Color(0xFF04050C);
const Color _fEmber = Color(0xFFD9A24C);
const Color _fAsh = Color(0xFF9C95A8);
const Color _fBlood = Color(0xFFB02A3A);
const Color _fTurf = Color(0xFF1D2A34);
const Color _fCut = Color(0xFF070910);
const Color _fCrystal = Color(0xFFB8E8FF);

// THE PROPS PASS (2026-10-08): the churchyard's solid things — headstones,
// the belfry and its bell, the urns, the tomb chests and the memorial slabs —
// are cut in near-black slate and bronze, lit only along the edge the moon
// catches (the past's along its cold edge). Their flames, ashes, dust and the
// offerings that pass between hands are grains.

/// The moon's light on a carved edge.
const Color _fMoonRim = Color(0xFFAFC0DC);

/// Near-black grave slate: the headstones, chests and memorial slabs.
const GlassPalette _kGraveStone = GlassPalette(
  lead: Color(0xFF07090C),
  leadLight: Color(0xFFC8DCE4),
  frost: [
    Color(0xFF2E383E),
    Color(0xFF344048),
    Color(0xFF2A3238),
    Color(0xFF3A464E),
    Color(0xFF303A42),
  ],
  liveDeep: Color(0xFF1C4A52),
  live: Color(0xFF86DCD6),
  liveCore: Color(0xFFEAFFFC),
  smoke: Color(0xFF101418),
  silver: Color(0xFFE2EAEE),
  gold: Color(0xFFD9A24C),
  goldDeep: Color(0xFF6E5228),
  stoneTop: Color(0xFF2B313D),
  stoneFace: Color(0xFF151820),
  stoneFoot: Color(0xFF040508),
  floor: Color(0xFF1B1F28),
  floorAlt: Color(0xFF171A22),
  joint: Color(0xFF08090A),
);

/// A candle's grains, low and warm in the present, tall and cold in the past.
const List<Color> _kWarmFlame = [
  Color(0xFFB0581E),
  Color(0xFFF2A048),
  Color(0xFFFFDC9A),
  Color(0xFFFFFBF0),
];
const List<Color> _kColdFlame = [
  Color(0xFF2E7C80),
  Color(0xFF7FE0DA),
  Color(0xFFC8F6F2),
  Color(0xFFFFFFFF),
];

/// Grave-ash and grave-dust, in grains.
/// Soft-stepped, so a heap reads as one drift and not as salt.
const List<Color> _kAshGrains = [
  Color(0xFF4A4656),
  Color(0xFF7E788C),
  Color(0xFFA29CB0),
  Color(0xFFC8C2D4),
];

/// THE PAST'S STONE: the same courses as the present, re-struck cold and
/// clean — joints faintly lit, the floor the colour of deep water.
const GlassPalette _kPastGlass = GlassPalette(
  lead: Color(0xFF07090C),
  leadLight: Color(0xFFC8F4F0),
  frost: [
    Color(0xFF1E3A3E),
    Color(0xFF24444A),
    Color(0xFF1A3438),
    Color(0xFF2A4C52),
    Color(0xFF203E44),
  ],
  liveDeep: Color(0xFF1C4A52),
  live: Color(0xFF86DCD6),
  liveCore: Color(0xFFEAFFFC),
  smoke: Color(0xFF0C1618),
  silver: Color(0xFFE2EAEE),
  gold: Color(0xFFD9A24C),
  goldDeep: Color(0xFF6E5228),
  stoneTop: Color(0xFF4F8288),
  stoneFace: Color(0xFF1B3438),
  stoneFoot: Color(0xFF040A0C),
  floor: Color(0xFF0F2428),
  floorAlt: Color(0xFF0C1D21),
  joint: Color(0xFF3E8A88),
);

/// The baked room — wall, floor and edge dressing — per room, per world.
final Map<String, ui.Picture> _funeralBakeCache = {};

/// The candle stands of each room: where their flames burn.
final Map<String, List<Offset>> _funeralCandleCache = {};

/// Grain shapes built once: the dust drifts, keyed by size and seed.
final Map<String, GrainShape> _funeralGrainShapes = {};

/// The faint body under each dust drift's grains.
final Map<String, Path> _funeralDriftHaze = {};

/// One frame's loose grains (flames, ashes, offerings), drawn together.
final _FuneralInk _funeralInk = _FuneralInk();

extension FuneralArt on PlanetDungeonGame {
  void _updateSpiritGlass(double dt) {
    final target =
        discoveredClouds.contains(kSpiritEmptyUrnEgg) ||
            _ritePendingEgg == kSpiritEmptyUrnEgg
        ? 1.0
        : 0.0;
    if (_dreamShown < 0) {
      _dreamShown = target;
    } else if (_dreamShown < target) {
      _dreamShown = min(target, _dreamShown + dt / 2.6);
    } else if (_dreamShown > target) {
      _dreamShown = target;
    }
  }

  double get _fClock => funeral.clock;

  // ── The room ─────────────────────────────────────────────

  void _renderFuneral(Canvas canvas, DungeonRoom room) {
    final ghost = _run.isGhost;
    canvas.drawRect(
      room.bounds,
      Paint()
        ..color = ghost
            ? _fVoid.withValues(alpha: 0.42)
            : _fSod.withValues(alpha: 0.58),
    );
    _renderFuneralBake(canvas, room, ghost);
    _renderGlassDoorPlugs(canvas, room);
    _renderFuneralCandles(canvas, room, ghost);
    final fr = room.funeral;
    if (fr == null) return;
    if (fr.drift != null && !entryDoorRevealed) {
      _drawDustDrift(
        canvas,
        Rect.fromCenter(center: fr.drift!, width: 150, height: 40),
        7,
      );
    }
    if (fr.niche != null) _drawNiche(canvas, fr.niche!, ghost);
    if (fr.flagOrigin != null) _renderBearersCourt(canvas, fr, ghost);
    if (fr.bell != null) _renderBellCourt(canvas, fr, ghost);
    if (fr.rite) _renderChapel(canvas, room, fr, ghost);
    if (fr.nameStone != null) {
      _renderAlcove(canvas, fr, ghost);
      _drawNameStone(canvas, fr, ghost);
    }
    if (fr.socket != null) _drawSocket(canvas, fr.socket!, ghost);
    if (fr.urn != null) _drawUrn(canvas, fr, ghost);
    if (ghost && fr.bell != null) _drawKeeperLesson(canvas, fr);
    if (fr.memorialStone != null) {
      _drawMemorialStone(canvas, fr.memorialStone!, ghost);
    }
    if (fr.chime != null) _renderVigil(canvas, room, fr);
  }

  // ── The baked room ───────────────────────────────────────

  /// Everywhere a fixture stands in [room]: the dressing keeps clear of
  /// these so nothing decorative reads as something to press.
  List<Offset> _funeralKeepClear(DungeonRoom room) {
    final fr = room.funeral;
    return [
      for (final d in room.doors) d.rect.center,
      ?fr?.memorialStone,
      ?fr?.drift,
      ?fr?.urn,
      ?fr?.socket?.at,
      ?fr?.bell,
      ?fr?.niche,
      ?fr?.bier,
      ?fr?.chime,
      ?fr?.nameStone,
      ...?fr?.stones,
      ?room.vaultCache,
      ?room.guardian?.position,
      if (fr?.flagOrigin != null)
        for (var i = 0; i < kBearerCols * kBearerCols; i++) fr!.flagCentre(i),
    ];
  }

  void _renderFuneralBake(Canvas canvas, DungeonRoom room, bool ghost) {
    final b = room.bounds;
    final key =
        '${room.id}|${ghost ? 'g' : 'l'}|${b.width.round()}x${b.height.round()}';
    canvas.drawPicture(
      _funeralBakeCache.putIfAbsent(key, () {
        final rec = ui.PictureRecorder();
        _bakeFuneralRoom(Canvas(rec), room, ghost);
        return rec.endRecording();
      }),
    );
  }

  void _bakeFuneralRoom(Canvas canvas, DungeonRoom room, bool ghost) {
    final b = room.bounds;
    final pal = ghost ? _kPastGlass : _kWraithGlass;
    final rng = GlassRng(glassSeed(room.id, b));
    paintCarvedRoomShell(
      canvas,
      b,
      pal,
      rng,
      doors: [
        for (final d in room.doors)
          if (_doorOnWall(room, d)) d.rect,
      ],
      faceDepth: 44,
      arcade: false,
      floorOpacity: ghost ? 0.66 : 0.62,
      flagCourse: 58,
      jointOpacity: ghost ? 0.35 : 0.6,
    );
    final floor = Rect.fromLTRB(
      b.left + 10,
      b.top + 44,
      b.right - 10,
      b.bottom - 10,
    );
    final clear = _funeralKeepClear(room);
    bool free(Offset p, double r) =>
        floor.deflate(4).contains(p) &&
        clear.every((c) => (c - p).distance > r + 60);

    // MOONLIGHT, a pool of it from the north-west; in the past, the cold
    // light the dead see by, pooled round the middle.
    final moon = ghost
        ? b.center
        : Offset(b.left + b.width * 0.35, b.top + b.height * 0.4);
    canvas.drawCircle(
      moon,
      b.shortestSide * 0.62,
      Paint()
        ..shader = ui.Gradient.radial(moon, b.shortestSide * 0.62, [
          (ghost ? _fCold : const Color(0xFFB8C8E8)).withValues(
            alpha: ghost ? 0.12 : 0.09,
          ),
          (ghost ? _fCold : const Color(0xFFB8C8E8)).withValues(alpha: 0.0),
        ]),
    );

    if (!ghost) {
      // MOSS creeping out of the joints along the walls, and CRACKS.
      for (var i = 0; i < 26; i++) {
        final onWall = rng.next();
        final p = onWall < 0.5
            ? Offset(
                rng.range(floor.left, floor.right),
                onWall < 0.25
                    ? floor.top + rng.range(0, 30)
                    : floor.bottom - rng.range(0, 30),
              )
            : Offset(
                onWall < 0.75
                    ? floor.left + rng.range(0, 30)
                    : floor.right - rng.range(0, 30),
                rng.range(floor.top, floor.bottom),
              );
        if (!free(p, 0)) continue;
        final w = rng.range(18, 46), h = rng.range(8, 18);
        canvas.drawOval(
          Rect.fromCenter(center: p, width: w, height: h),
          Paint()
            ..color = const Color(
              0xFF1F3A36,
            ).withValues(alpha: rng.range(0.35, 0.6)),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: p.translate(-w * 0.12, -h * 0.15),
            width: w * 0.55,
            height: h * 0.5,
          ),
          Paint()..color = const Color(0xFF2E5448).withValues(alpha: 0.35),
        );
      }
      for (var i = 0; i < 6; i++) {
        final p = Offset(
          rng.range(floor.left + 60, floor.right - 60),
          rng.range(floor.top + 60, floor.bottom - 60),
        );
        if (!free(p, 20)) continue;
        final a = rng.range(0, pi);
        final len = rng.range(30, 70);
        final dir = Offset(cos(a), sin(a));
        final n = Offset(-dir.dy, dir.dx);
        final mid = p + dir * (len * 0.5) + n * rng.range(-6, 6);
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy)
            ..lineTo(mid.dx + n.dx * 1.6, mid.dy + n.dy * 1.6)
            ..lineTo((p + dir * len).dx, (p + dir * len).dy)
            ..lineTo(mid.dx - n.dx * 1.6, mid.dy - n.dy * 1.6)
            ..close(),
          Paint()..color = Colors.black.withValues(alpha: 0.5),
        );
      }
      // Fallen leaves.
      for (var i = 0; i < 14; i++) {
        final p = Offset(
          rng.range(floor.left, floor.right),
          rng.range(floor.top, floor.bottom),
        );
        if (!free(p, 0)) continue;
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(rng.range(0, pi));
        canvas.drawOval(
          const Rect.fromLTWH(-5, -2.2, 10, 4.4),
          Paint()
            ..color = Color.lerp(
              const Color(0xFF5A3A26),
              const Color(0xFF6E5A30),
              rng.next(),
            )!.withValues(alpha: 0.55),
        );
        canvas.restore();
      }
      // IVY down the north wall's face.
      for (var x = b.left + 30; x < b.right - 30; x += rng.range(50, 130)) {
        final p = Offset(x, b.top + 6);
        if (room.doors.any((d) => (d.rect.center - p).distance < 90)) continue;
        final drop = rng.range(18, 40);
        for (var k = 0; k < 9; k++) {
          final q = p + Offset(rng.range(-12, 12), rng.range(0, drop));
          canvas.save();
          canvas.translate(q.dx, q.dy);
          canvas.rotate(rng.range(-1, 1));
          canvas.drawPath(
            Path()
              ..moveTo(0, -5)
              ..quadraticBezierTo(5, -2, 0, 5)
              ..quadraticBezierTo(-5, -2, 0, -5)
              ..close(),
            Paint()..color = const Color(0xFF26463C).withValues(alpha: 0.9),
          );
          canvas.restore();
        }
      }
    }

    // HEADSTONES along the north wall, clear of doors and fixtures: fallen,
    // leaning and cracked in the present; upright, clean, with a flame and
    // flowers at their feet in the past.
    var x = floor.left + 30;
    while (x < floor.right - 30) {
      final p = Offset(x, floor.top + 34);
      x += rng.range(64, 110);
      final kind = rng.pick(4);
      final lean = rng.range(-0.22, 0.22);
      final fallen = rng.next() < 0.28;
      if (!free(p, 20)) continue;
      // Fewer of them: where a cross stood there is now a gap in the row.
      // (The draws above still run, so the rest of the dressing lands where
      // it always did.)
      if (kind == 1) continue;
      _bakeHeadstone(
        canvas,
        p,
        kind,
        ghost ? 0 : lean,
        pal,
        ghost: ghost,
        fallen: !ghost && fallen,
      );
    }
    // THE VIGIL: a great funeral wreath laid into the floor round where
    // Wraithord stands, petals across the stone, and mourning drapes swagged
    // along the north wall.
    final vigil = room.guardian?.position;
    if (vigil != null) _bakeVigilFloor(canvas, room, vigil, ghost, rng);
    // TOMB CHESTS in the southern corners, where there is room for them.
    for (final corner in [
      Offset(floor.left + 70, floor.bottom - 40),
      Offset(floor.right - 70, floor.bottom - 40),
    ]) {
      if (!free(corner, 40)) continue;
      // Near-black slate in the present, the moon along its far lip.
      final chest = ghost ? pal : _kGraveStone;
      final top = Rect.fromCenter(center: corner, width: 96, height: 30);
      paintCarvedBlock(canvas, top, 18, chest, radius: 3);
      if (!ghost) {
        canvas.drawRect(
          Rect.fromLTWH(top.left + 3, top.top, top.width - 6, 1.6),
          Paint()..color = _fMoonRim.withValues(alpha: 0.45),
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(top.deflate(6), const Radius.circular(2)),
        Paint()..color = chest.stoneFace.withValues(alpha: 0.45),
      );
      final panel = Rect.fromLTWH(
        top.left + 8,
        top.bottom + 4,
        top.width - 16,
        10,
      );
      canvas.drawRect(
        panel,
        Paint()..color = chest.stoneFoot.withValues(alpha: 0.5),
      );
      if (!ghost) {
        canvas.drawOval(
          Rect.fromCenter(
            center: top.bottomLeft.translate(14, 14),
            width: 36,
            height: 12,
          ),
          Paint()..color = const Color(0xFF1F3A36).withValues(alpha: 0.6),
        );
      }
    }
    // CANDLE STANDS: beside every door, and at the bier's corners. The
    // stands bake; their flames burn per frame.
    final candles = <Offset>[];
    for (final d in room.doors) {
      final r = d.rect;
      final horizontal = r.width > r.height;
      for (final side in const [-1.0, 1.0]) {
        final c = horizontal
            ? Offset(
                r.center.dx + side * (r.width / 2 + 34),
                r.top <= b.top + 1 ? b.top + 64 : r.top - 20,
              )
            : Offset(
                r.left <= b.left + 1 ? b.left + 40 : r.right - 40,
                r.center.dy + side * (r.height / 2 + 30),
              );
        if (clear.any((q) => q != r.center && (q - c).distance < 50)) continue;
        candles.add(c);
      }
    }
    if (vigil != null) {
      // A ring of vigil candles outside the wreath.
      for (var k = 0; k < 8; k++) {
        final a = -pi / 2 + k * pi / 4 + pi / 8;
        candles.add(vigil + Offset(cos(a) * 250, sin(a) * 175));
      }
    }
    final bier = room.funeral?.bier;
    if (bier != null) {
      for (final o in const [
        Offset(-110, -40),
        Offset(110, -40),
        Offset(-110, 50),
        Offset(110, 50),
      ]) {
        candles.add(bier + o);
      }
    }
    candles.removeWhere((c) => !floor.deflate(18).contains(c));
    for (final c in candles) {
      _bakeCandleStand(canvas, c, pal);
    }
    _funeralCandleCache[room.id] = candles;
  }

  void _bakeVigilFloor(
    Canvas canvas,
    DungeonRoom room,
    Offset c,
    bool ghost,
    GlassRng rng,
  ) {
    final b = room.bounds;
    // The wreath's bed: a darker ring worn into the flags.
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 460, height: 320),
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          230,
          [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: ghost ? 0.10 : 0.22),
            Colors.black.withValues(alpha: 0.0),
          ],
          const [0.55, 0.82, 1.0],
        ),
    );
    // THE WREATH: laurel leaves laid round in two courses, lilies at the
    // four quarters. Filled, lit on one side — material, not a ring.
    final leafA = ghost
        ? _fCold.withValues(alpha: 0.40)
        : const Color(0xFF26443A).withValues(alpha: 0.92);
    final leafB = ghost
        ? _fCold.withValues(alpha: 0.22)
        : const Color(0xFF1A3029).withValues(alpha: 0.92);
    const rx = 200.0, ry = 140.0;
    for (var course = 0; course < 2; course++) {
      final n = 44;
      for (var k = 0; k < n; k++) {
        final t = (k + course * 0.5) / n * 2 * pi;
        final p =
            c +
            Offset(cos(t) * (rx + course * 14), sin(t) * (ry + course * 10));
        final along =
            atan2(cos(t) * ry, -sin(t) * rx) + (course == 0 ? 0.5 : -0.5);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(along + rng.range(-0.15, 0.15));
        final leaf = Path()
          ..moveTo(-13, 0)
          ..quadraticBezierTo(0, -7, 13, 0)
          ..quadraticBezierTo(0, 7, -13, 0)
          ..close();
        canvas.drawPath(
          leaf,
          Paint()
            ..shader = ui.Gradient.linear(
              const Offset(0, -6),
              const Offset(0, 6),
              [leafA, leafB],
            ),
        );
        canvas.restore();
      }
    }
    // (The four white five-petal lilies that sat on the quarters are gone:
    // laid flat and symmetrical they read as star stickers, not flowers. The
    // laurel and the petals strewn round it carry the wreath.)
    // Petals across the stone, thickest near the wreath.
    for (var k = 0; k < 60; k++) {
      final t = rng.range(0, 2 * pi);
      final d = rng.range(0.6, 1.35);
      final p = c + Offset(cos(t) * rx * d, sin(t) * ry * d);
      if (!b.deflate(40).contains(p)) continue;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(rng.range(0, pi));
      canvas.drawOval(
        const Rect.fromLTWH(-3.5, -1.8, 7, 3.6),
        Paint()
          ..color = (ghost ? _fCold : const Color(0xFFD8D2C4)).withValues(
            alpha: rng.range(0.3, 0.6),
          ),
      );
      canvas.restore();
    }
    // MOURNING DRAPES, swagged along the north wall's face between hooks.
    final cloth = ghost
        ? _fCold.withValues(alpha: 0.35)
        : const Color(0xFF14111A);
    final hem = ghost ? _fCold.withValues(alpha: 0.6) : const Color(0xFF3A2E48);
    for (var x = b.left + 40.0; x < b.right - 100; x += 120) {
      if (room.doors.any(
        (d) =>
            (d.rect.center.dx - (x + 60)).abs() < 110 &&
            d.rect.top <= b.top + 1,
      )) {
        continue;
      }
      final l = Offset(x, b.top + 6), r = Offset(x + 120, b.top + 6);
      final sag = Offset(x + 60, b.top + 36);
      canvas.drawPath(
        Path()
          ..moveTo(l.dx, l.dy)
          ..quadraticBezierTo(sag.dx, sag.dy + 10, r.dx, r.dy)
          ..lineTo(r.dx, r.dy - 4)
          ..quadraticBezierTo(sag.dx, sag.dy - 12, l.dx, l.dy - 4)
          ..close(),
        Paint()..color = cloth,
      );
      canvas.drawPath(
        Path()
          ..moveTo(l.dx + 6, l.dy + 3)
          ..quadraticBezierTo(sag.dx, sag.dy + 12, r.dx - 6, r.dy + 3)
          ..lineTo(r.dx - 6, r.dy + 1)
          ..quadraticBezierTo(sag.dx, sag.dy + 8, l.dx + 6, l.dy + 1)
          ..close(),
        Paint()..color = hem,
      );
      for (final hook in [l, r]) {
        canvas.drawCircle(
          hook,
          4,
          Paint()..color = _fEmber.withValues(alpha: 0.7),
        );
      }
    }
  }

  /// A HEADSTONE: a near-black slate silhouette lit only along the edge the
  /// moon catches (in the past, its cold edge) — no grey fill, no lettering
  /// drawn on it. Fallen ones lie as a dark carved slab, cracked.
  void _bakeHeadstone(
    Canvas canvas,
    Offset foot,
    int kind,
    double lean,
    GlassPalette pal, {
    required bool ghost,
    required bool fallen,
  }) {
    // Its shadow.
    paintContactShadow(canvas, foot.translate(4, 2), 40, 9, opacity: 0.5);
    if (fallen) {
      final slab = Rect.fromCenter(
        center: foot.translate(6, -2),
        width: 44,
        height: 14,
      );
      // Broken where it fell: the head end lies a little apart and askew.
      final head = Rect.fromLTWH(slab.left, slab.top + 1, 17, slab.height);
      final rest = Rect.fromLTWH(slab.left + 20, slab.top, 24, slab.height);
      paintCarvedBlock(canvas, rest, 5, _kGraveStone, radius: 3);
      canvas.save();
      canvas.translate(head.center.dx, head.center.dy);
      canvas.rotate(-0.16);
      canvas.translate(-head.center.dx, -head.center.dy);
      paintCarvedBlock(canvas, head, 4, _kGraveStone, radius: 3);
      canvas.restore();
      for (final r in [head, rest]) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + 2, r.top, r.width - 4, 1.3),
          Paint()..color = _fMoonRim.withValues(alpha: 0.36),
        );
      }
      return;
    }
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.rotate(lean);
    final Path shape;
    switch (kind) {
      case 0: // round-topped slab
        shape = Path()
          ..moveTo(-13, 0)
          ..lineTo(-13, -30)
          ..quadraticBezierTo(0, -44, 13, -30)
          ..lineTo(13, 0)
          ..close();
      case 2: // obelisk
        shape = Path()
          ..moveTo(-9, 0)
          ..lineTo(-6, -40)
          ..lineTo(0, -48)
          ..lineTo(6, -40)
          ..lineTo(9, 0)
          ..close();
      default: // shouldered tablet
        shape = Path()
          ..moveTo(-14, 0)
          ..lineTo(-14, -26)
          ..lineTo(-9, -32)
          ..lineTo(-5, -32)
          ..quadraticBezierTo(0, -40, 5, -32)
          ..lineTo(9, -32)
          ..lineTo(14, -26)
          ..lineTo(14, 0)
          ..close();
    }
    _funeralCarve(
      canvas,
      shape,
      body: ghost
          ? Color.lerp(pal.stoneFace, _fCold, 0.12)!
          : _kGraveStone.stoneTop,
      deep: ghost ? pal.stoneFoot : _kGraveStone.stoneFoot,
      rim: ghost
          ? _fCold.withValues(alpha: 0.8)
          : _fMoonRim.withValues(alpha: 0.5),
    );
    canvas.restore();
    // (The three flower dots at each stone's foot in the past are gone: a
    // row of them read as beads, not flowers.)
    if (!ghost) {
      canvas.drawOval(
        Rect.fromCenter(center: foot.translate(0, 1), width: 30, height: 8),
        Paint()..color = const Color(0xFF1F3A36).withValues(alpha: 0.7),
      );
    }
  }

  void _bakeCandleStand(Canvas canvas, Offset at, GlassPalette pal) {
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(0, 18), width: 22, height: 7),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );
    // An iron pricket: three feet, a stem, a drip pan, the candle.
    const iron = Color(0xFF1C1B22);
    canvas.drawRect(
      Rect.fromCenter(center: at.translate(0, 4), width: 3, height: 28),
      Paint()..color = iron,
    );
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 9, at.dy + 18)
        ..lineTo(at.dx, at.dy + 10)
        ..lineTo(at.dx + 9, at.dy + 18)
        ..lineTo(at.dx + 7, at.dy + 19)
        ..lineTo(at.dx, at.dy + 13)
        ..lineTo(at.dx - 7, at.dy + 19)
        ..close(),
      Paint()..color = iron,
    );
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(0, -10), width: 16, height: 5),
      Paint()..color = iron,
    );
    // The candle: a stub of old wax, lit at its lip by its own flame and
    // gone dark toward the pan — not a white stick.
    final wax = Rect.fromCenter(
      center: at.translate(0, -15.5),
      width: 5,
      height: 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(wax, const Radius.circular(1.6)),
      Paint()
        ..shader = ui.Gradient.linear(
          wax.topCenter,
          wax.bottomCenter,
          [
            const Color(0xFFCDB894),
            const Color(0xFF6E604C),
            const Color(0xFF2A2420),
          ],
          const [0.0, 0.35, 1.0],
        ),
    );
    // The wick.
    canvas.drawRect(
      Rect.fromLTWH(at.dx - 0.5, at.dy - 23, 1, 2.6),
      Paint()..color = const Color(0xFF14100C),
    );
  }

  /// The flames, in grains: each a few dozen grains rising off the wick,
  /// white at the root, narrowing and dimming as they climb — warm and low in
  /// the present, cold and tall in the past. ~38 grains a candle.
  void _renderFuneralCandles(Canvas canvas, DungeonRoom room, bool ghost) {
    final candles = _funeralCandleCache[room.id];
    if (candles == null) return;
    final ramp = ghost ? _kColdFlame : _kWarmFlame;
    final t = _fClock;
    for (var i = 0; i < candles.length; i++) {
      final at = candles[i].translate(0, -22);
      final f = 0.85 + 0.15 * sin(t * (7 + i) + i * 1.7);
      final col = ghost ? _fCold : const Color(0xFFFFC36A);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          at.translate(0, -5),
          34 * f,
          col.withValues(alpha: ghost ? 0.22 : 0.26),
        );
      }
      final h = (ghost ? 15.0 : 11.0) * f;
      final w = ghost ? 2.6 : 3.0;
      const n = 32;
      const back = 0.05;
      final sway = sin(t * 2.3 + i * 1.9);
      for (var j = 0; j < n; j++) {
        // Each grain's own lane across the flame, and its own pace up it.
        final side = sin(j * 2.39996 + i);
        final pace = 1.35 + 0.35 * ((j * 7 + i * 3) % 5) / 4;
        final u = (t * pace + j / n + i * 0.37) % 1.0;
        final u0 = u - pace * back;
        if (u0 < 0) continue; // just born: no trail yet
        Offset pos(double q) {
          final width = w * sin(pi * pow(q, 0.55)) * (1 - 0.45 * q);
          return at.translate(side * width + sway * q * q * 2.2, -q * h);
        }

        final c = u < 0.18
            ? ramp[3]
            : u < 0.42
            ? ramp[2]
            : u < 0.72
            ? ramp[1]
            : ramp[0];
        _funeralInk.add(
          pos(u0),
          pos(u),
          c,
          (1 - u) * min(1.0, u * 10) * (ghost ? 0.85 : 0.95),
        );
      }
      // The root of it: a few grains held bright at the wick.
      for (var j = 0; j < 6; j++) {
        final p = at.translate(
          sin(t * 9 + j * 2.1 + i) * 0.9,
          -1.5 - (j % 3) * 1.4,
        );
        _funeralInk.add(p.translate(0, 0.8), p, ramp[3], 0.9);
      }
    }
    _funeralInk.paint(canvas);
  }

  // ── Figures ──────────────────────────────────────────────

  /// A hooded ghost, drawn as MATERIAL: filled, brightest at the hood,
  /// thinning to a wisp where its feet would be. [kneel] lowers it.
  void _drawGhost(
    Canvas canvas,
    Offset foot, {
    double alpha = 0.75,
    double kneel = 0,
    double phase = 0,
    Color? tint,
  }) {
    if (alpha <= 0.01) return;
    final ink = tint ?? _fCold;
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.scale(1.3);
    canvas.translate(-foot.dx, -foot.dy);
    final sway = sin(_fClock * 1.1 + phase) * 3;
    final h = 50 * (1 - 0.35 * kneel);
    final at = foot.translate(0, -h / 2);
    final top = at.dy - h / 2;
    final body = Path()
      ..moveTo(at.dx, top)
      ..quadraticBezierTo(at.dx + 11, top + 1, at.dx + 12, top + h * 0.36)
      ..quadraticBezierTo(at.dx + 13, top + h * 0.68, at.dx + 5 + sway, foot.dy)
      ..quadraticBezierTo(
        at.dx + sway * 0.5,
        foot.dy - 6,
        at.dx - 5 + sway,
        foot.dy,
      )
      ..quadraticBezierTo(
        at.dx - 13,
        top + h * 0.68,
        at.dx - 12,
        top + h * 0.36,
      )
      ..quadraticBezierTo(at.dx - 11, top + 1, at.dx, top)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(Offset(at.dx, top), foot, [
          ink.withValues(alpha: alpha),
          ink.withValues(alpha: 0.0),
        ]),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(at.dx, top + 11), width: 10, height: 12),
      Paint()..color = _fVoid.withValues(alpha: 0.85 * alpha),
    );
    canvas.restore();
  }

  // ── The memorial stone ───────────────────────────────────

  /// THE MEMORIAL: a tomb slab of near-black slate with a coffin-shaped
  /// light of leaded glass let into its lid — dim in the present, lit cold in
  /// the past. (It was a pale block with a round head and a capsule body on
  /// it: a sign, not a grave.)
  void _drawMemorialStone(Canvas canvas, Offset at, bool ghost) {
    final top = Rect.fromCenter(center: at, width: 96, height: 30);
    paintCarvedBlock(canvas, top, 8, _kGraveStone, radius: 4);
    canvas.drawRect(
      Rect.fromLTWH(top.left + 4, top.top, top.width - 8, 1.6),
      Paint()..color = _fMoonRim.withValues(alpha: 0.45),
    );
    // The coffin's outline: narrow at the head, widest at the shoulder,
    // tapering to the foot. Three panes, leaded across.
    double half(double x) =>
        x < -20 ? 4.6 + (x + 38) / 18 * 3.6 : 8.2 - (x + 20) / 58 * 4.2;
    Path pane(double x0, double x1) => Path()
      ..moveTo(at.dx + x0, at.dy - half(x0))
      ..lineTo(
        at.dx + max(x0, min(x1, -20)),
        at.dy - half(max(x0, min(x1, -20))),
      )
      ..lineTo(at.dx + x1, at.dy - half(x1))
      ..lineTo(at.dx + x1, at.dy + half(x1))
      ..lineTo(
        at.dx + max(x0, min(x1, -20)),
        at.dy + half(max(x0, min(x1, -20))),
      )
      ..lineTo(at.dx + x0, at.dy + half(x0))
      ..close();
    final glow = ghost
        ? _kWraithGlass.live.withValues(alpha: 0.75 + 0.15 * sin(_fClock * 1.1))
        : Color.lerp(
            _kWraithGlass.frostAt(1),
            _kWraithGlass.live,
            0.18,
          )!.withValues(alpha: 0.7);
    // The slot it is set in, cut dark.
    canvas.drawPath(
      pane(-38, 38).shift(const Offset(0, 1)),
      Paint()..color = _fVoid.withValues(alpha: 0.9),
    );
    for (final (x0, x1) in const [
      (-38.0, -20.0),
      (-20.0, 10.0),
      (10.0, 38.0),
    ]) {
      paintPane(canvas, pane(x0, x1), glow, _kWraithGlass, lead: 1.6);
    }
    paintStreak(
      canvas,
      Rect.fromLTWH(at.dx - 14, at.dy - 7, 18, 13),
      opacity: ghost ? 0.5 : 0.22,
    );
    paintLead(canvas, pane(-38, 38), _kWraithGlass, width: 2.2);
  }

  // ── Dust ─────────────────────────────────────────────────

  /// Grave-dust, drifted: one low heap with three humps, in ash grains that
  /// shift where they lie, lit along the crest, on its own shadow. Never a
  /// terrain — Dust's mounds stay Dust's. ~0.12 grains per square unit.
  void _drawDustDrift(Canvas canvas, Rect area, int seed) {
    final base = area.bottom - area.height * 0.18;
    canvas.drawOval(
      Rect.fromLTRB(area.left, base - 6, area.right, base + 7),
      Paint()..color = const Color(0xFF020308).withValues(alpha: 0.45),
    );
    final key =
        'drift|${area.left.round()},${area.top.round()},'
        '${area.width.round()}x${area.height.round()}|$seed';
    final w = area.width;
    double hump(int k) =>
        area.top + area.height * (0.12 + 0.22 * (((seed * 7 + k * 5) % 9) / 9));
    // The crest: three humps eased into one another, down to the floor at
    // both ends.
    double crest(double x) {
      final u = ((x - area.left) / w).clamp(0.0, 1.0);
      final ends = sin(pi * u);
      final h0 = exp(-pow((u - 0.24) / 0.16, 2));
      final h1 = exp(-pow((u - 0.52) / 0.15, 2));
      final h2 = exp(-pow((u - 0.8) / 0.14, 2));
      final lift =
          (base - hump(0)) * h0 + (base - hump(1)) * h1 + (base - hump(2)) * h2;
      return base -
          min(base - area.top, lift * 0.9 + 4) * pow(ends, 0.6).toDouble();
    }

    // Under the grains, the heap's body as a faint ash haze, so it reads as
    // one drift rather than scattered dust.
    final haze = _funeralDriftHaze.putIfAbsent(key, () {
      final p = Path()..moveTo(area.left, base + 2);
      for (var x = area.left; x <= area.right; x += 3) {
        p.lineTo(x, crest(x) + 1.5);
      }
      return p
        ..lineTo(area.right, base + 2)
        ..close();
    });
    canvas.drawPath(
      haze,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, area.top),
          Offset(0, base),
          [
            _fAsh.withValues(alpha: 0.32),
            _fAsh.withValues(alpha: 0.16),
            _fAsh.withValues(alpha: 0.04),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    final shape = _funeralGrainShapes.putIfAbsent(
      key,
      () => GrainShape.region(
        Rect.fromLTRB(area.left, area.top, area.right, base + 3),
        (p) => p.dy > crest(p.dx) && p.dy < base + 3,
        (area.width * area.height * 0.3).round(),
        seed: seed * 13 + 5,
      ),
    );
    paintGrainShape(
      canvas,
      shape,
      _fClock,
      drift: 0.45,
      alpha: 0.75,
      ramp: _kAshGrains,
      glint: 0.004,
      width: 1.5,
      trail: 0.035,
    );
  }

  // ── Urns, crystals and sockets ───────────────────────────

  void _drawUrn(Canvas canvas, FuneralRoom fr, bool ghost) {
    final at = fr.urn!;
    // Bigger than life: the urn is the thing every room is about.
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1.3);
    canvas.translate(-at.dx, -at.dy);
    _drawUrnBody(canvas, fr, ghost);
    canvas.restore();
  }

  /// THE URN: an amphora carved in near-black, lit only along the edge the
  /// moon catches (in the past, a cold translucent ghost of it). Its one
  /// bright thing is its glass band — the puzzle surface.
  void _drawUrnBody(Canvas canvas, FuneralRoom fr, bool ghost) {
    final at = fr.urn!;
    final id = fr.urnId!;
    final r = _run;
    final k = ghost ? 0.5 : 1.0;
    final emptied = r.fitted.contains(funeralUrnById(id)!.socketId);
    final hasAsh =
        !emptied &&
        !r.crystals.contains(id) &&
        (id != 'urn_empty' || r.urnFilled);
    final ready =
        !ghost &&
        r.canCrystallize(id) &&
        funeralPairReady(_elementsNear(at, _kUrnPairReach));
    // The carving's three tones: body, the dark it turns into, and its rim.
    final body = ghost
        ? _fCold.withValues(alpha: 0.24)
        : const Color(0xFF1F2430);
    final deep = ghost
        ? _fCold.withValues(alpha: 0.08)
        : const Color(0xFF06070B);
    final rim = ghost
        ? _fCold.withValues(alpha: 0.75)
        : _fMoonRim.withValues(alpha: 0.5);
    // Its shadow and its foot.
    canvas.drawOval(
      Rect.fromCenter(center: at.translate(0, 24), width: 50, height: 12),
      Paint()..color = _fVoid.withValues(alpha: 0.45),
    );
    if (ghost) {
      canvas.drawOval(
        Rect.fromCenter(center: at.translate(0, 18), width: 26, height: 9),
        Paint()..color = _fCold.withValues(alpha: 0.35),
      );
    } else {
      paintCarvedDisc(canvas, at.translate(0, 15), 13, 4.5, 5, _kGraveStone);
    }
    // Handles at the shoulders, carved, behind the body.
    for (final side in const [-1.0, 1.0]) {
      _funeralCarve(
        canvas,
        Path()
          ..moveTo(at.dx + side * 8, at.dy - 20)
          ..quadraticBezierTo(
            at.dx + side * 24,
            at.dy - 22,
            at.dx + side * 18,
            at.dy - 8,
          )
          ..lineTo(at.dx + side * 15, at.dy - 9)
          ..quadraticBezierTo(
            at.dx + side * 19,
            at.dy - 18,
            at.dx + side * 8,
            at.dy - 16,
          )
          ..close(),
        body: body,
        deep: deep,
        rim: rim,
        lift: 1.2,
      );
    }
    // THE BODY: an amphora — narrow neck, wide shoulder, full belly, a
    // waist to the foot.
    final shape = Path()
      ..moveTo(at.dx - 7, at.dy - 24)
      ..quadraticBezierTo(at.dx - 7, at.dy - 16, at.dx - 17, at.dy - 11)
      ..quadraticBezierTo(at.dx - 23, at.dy + 2, at.dx - 9, at.dy + 15)
      ..lineTo(at.dx + 9, at.dy + 15)
      ..quadraticBezierTo(at.dx + 23, at.dy + 2, at.dx + 17, at.dy - 11)
      ..quadraticBezierTo(at.dx + 7, at.dy - 16, at.dx + 7, at.dy - 24)
      ..close();
    _funeralCarve(canvas, shape, body: body, deep: deep, rim: rim);
    // THE GLASS BAND round its belly — the urn's one puzzle surface: ash
    // grey while its ashes are in it, lit when the pair stands ready, dark
    // once the memory has gone out of it.
    final band = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at.translate(0, 0), width: 36, height: 7),
          const Radius.circular(3),
        ),
      );
    canvas.save();
    canvas.clipPath(shape);
    paintPane(
      canvas,
      band,
      ready
          ? _kWraithGlass.live.withValues(alpha: 0.7 + 0.25 * sin(_fClock * 3))
          : hasAsh
          ? _fAsh.withValues(alpha: 0.85 * k)
          : _kWraithGlass.smoke.withValues(alpha: 0.9 * k),
      _kWraithGlass,
      lead: 1.4,
    );
    canvas.restore();
    // The lid, its rim catching the light, and its finial.
    _funeralCarve(
      canvas,
      Path()..addOval(
        Rect.fromCenter(center: at.translate(0, -24), width: 18, height: 6),
      ),
      body: body,
      deep: deep,
      rim: rim,
      lift: 1.2,
    );
    _funeralCarve(
      canvas,
      Path()..addOval(Rect.fromCircle(center: at.translate(0, -28), radius: 3)),
      body: body,
      deep: deep,
      rim: rim,
      lift: 1.0,
    );
    if (ghost) return;
    // READINESS, read-only: with the pair standing here the ashes rise out
    // of its mouth as grains, winding up into the faint outline of the
    // crystal they will make. ~30 grains.
    if (r.canCrystallize(id) &&
        funeralPairReady(_elementsNear(at, _kUrnPairReach))) {
      final outline = at.translate(0, -44);
      _drawMemoryCrystal(
        canvas,
        outline,
        id,
        alpha: 0.22 + 0.08 * sin(_fClock * 3),
      );
      final mouth = at.translate(0, -26);
      const n = 30;
      for (var j = 0; j < n; j++) {
        final u = ((_fClock * 0.55) + j / n) % 1.0;
        final u0 = u - 0.03;
        if (u0 < 0) continue;
        Offset pos(double q) {
          final turn = q * pi * 3 + j * 2.39996;
          final reach = 5.5 * sin(pi * q) * (0.6 + 0.4 * sin(j * 1.7));
          return Offset.lerp(
            mouth,
            outline,
            q,
          )!.translate(cos(turn) * reach, 0);
        }

        _funeralInk.add(
          pos(u0),
          pos(u),
          _kAshGrains[u < 0.3 ? 1 : (u < 0.7 ? 2 : 3)],
          0.85 * (1 - u) * min(1.0, u * 8),
        );
      }
      _funeralInk.paint(canvas, width: 1.3);
    }
    if (r.crystalAtUrn(id)) {
      final flash = funeral.craftUrn == id && funeral.craftT >= 0
          ? 1 - funeral.craftT / _kCraftFlash
          : 0.0;
      if (flash > 0) {
        canvas.drawCircle(
          at.translate(0, -40),
          34,
          Paint()
            ..shader = ui.Gradient.radial(at.translate(0, -40), 34, [
              _fCrystal.withValues(alpha: 0.5 * flash),
              _fCrystal.withValues(alpha: 0.0),
            ]),
        );
      }
      _drawMemoryCrystal(
        canvas,
        at.translate(0, -38 + sin(_fClock * 1.6) * 2),
        id,
      );
    }
  }

  /// A MEMORY CRYSTAL: a leaded, faceted prism with the motion it remembers
  /// turning inside it.
  void _drawMemoryCrystal(
    Canvas canvas,
    Offset c,
    String urnId, {
    double alpha = 1.0,
    double scale = 1.0,
  }) {
    final w = 13.0 * scale, h = 20.0 * scale;
    final outer = Path()
      ..moveTo(c.dx, c.dy - h)
      ..lineTo(c.dx + w, c.dy - h * 0.35)
      ..lineTo(c.dx + w * 0.8, c.dy + h * 0.55)
      ..lineTo(c.dx, c.dy + h)
      ..lineTo(c.dx - w * 0.8, c.dy + h * 0.55)
      ..lineTo(c.dx - w, c.dy - h * 0.35)
      ..close();
    canvas.drawPath(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(c.translate(-w, -h), c.translate(w, h), [
          Color.lerp(
            _fCrystal,
            Colors.white,
            0.3,
          )!.withValues(alpha: 0.85 * alpha),
          const Color(0xFF6C7FD8).withValues(alpha: 0.65 * alpha),
        ]),
    );
    // Two lit facets.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - h)
        ..lineTo(c.dx + w, c.dy - h * 0.35)
        ..lineTo(c.dx, c.dy - h * 0.1)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.35 * alpha),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * scale
        ..color = const Color(0xFF1B1A26).withValues(alpha: 0.8 * alpha),
    );
    // The motion inside: small figures, doing what they did.
    final t = _fClock;
    final ink = const Color(0xFF1F2A48).withValues(alpha: 0.75 * alpha);
    void dot(Offset p, double r) =>
        canvas.drawCircle(p, r * scale, Paint()..color = ink);
    switch (urnId) {
      case 'urn_keeper':
        // A figure, stepping down.
        dot(c.translate(0, -4 * scale + (sin(t * 3) > 0 ? 2 * scale : 0)), 2.6);
        dot(c.translate(0, 4 * scale), 3.4);
      case 'urn_bearers':
        // Two figures walking, one behind the other.
        final s = (t * 0.8) % 1.0;
        for (final k in const [0.0, 0.5]) {
          final x = (((s + k) % 1.0) - 0.5) * w * 1.1;
          dot(c.translate(x, 0), 2.6);
        }
      case 'urn_mourners':
        for (var k = -1; k <= 1; k++) {
          dot(c.translate(k * 5.0 * scale, 4 * scale), 2.2);
        }
      default:
        // YOURS: three figures, each in its own colour.
        var k = -1;
        for (final c2 in creatures.take(3)) {
          canvas.drawCircle(
            c.translate(k * 5.0 * scale, 3 * scale),
            2.4 * scale,
            Paint()
              ..color = elementColor(
                c2.member.element,
              ).withValues(alpha: alpha),
          );
          k++;
        }
    }
  }

  /// A SOCKET: a carved block with a six-sided hollow for the crystal, and a
  /// shallow groove running out of it for the pulse.
  void _drawSocket(Canvas canvas, FuneralSocket sk, bool ghost) {
    final at = sk.at;
    final r = _run;
    final fitted = r.fitted.contains(sk.id);
    final pulsing = switch (sk.id) {
      'sk_treadle' => funeral.bellT >= 0,
      'sk_doorstep' => funeral.walkDist >= 0,
      'sk_name' => funeral.nameT >= 0,
      _ => funeral.riteT >= 0,
    };
    // The plinth.
    final block = Rect.fromCenter(center: at, width: 58, height: 30);
    paintCarvedBlock(canvas, block, 8, _kWraithGlass, radius: 6);
    // THE PULSE GROOVE, cut into its top from the right-hand edge to the
    // setting: carved dark, and running red while a pulse goes through it.
    final groove = RRect.fromRectAndRadius(
      Rect.fromLTRB(at.dx + 8, at.dy - 3, block.right - 4, at.dy + 3),
      const Radius.circular(3),
    );
    canvas.drawRRect(groove, Paint()..color = const Color(0xFF05060B));
    if (pulsing) {
      final t = (_fClock * 2.2) % 1.0;
      canvas.drawRRect(
        groove,
        Paint()
          ..shader = ui.Gradient.linear(
            groove.outerRect.centerRight,
            groove.outerRect.centerLeft,
            [
              _fBlood.withValues(alpha: 0.95),
              Color.lerp(_fBlood, Colors.white, 0.3)!,
              _fBlood.withValues(alpha: 0.6),
            ],
            [0.0, t, 1.0],
          ),
      );
    }
    // THE SETTING: a six-sided hollow in a gold rim.
    List<Offset> hex(double rx, double ry) => [
      for (var i = 0; i < 6; i++)
        at +
            Offset(
              cos(i * pi / 3 + pi / 6) * rx,
              sin(i * pi / 3 + pi / 6) * ry,
            ),
    ];
    canvas.drawPath(
      Path()..addPolygon(hex(13, 10), true),
      Paint()
        ..shader = ui.Gradient.linear(
          at.translate(-13, -10),
          at.translate(13, 10),
          [
            Color.lerp(_kWraithGlass.gold, Colors.white, 0.2)!,
            _kWraithGlass.goldDeep,
          ],
        ),
    );
    canvas.drawPath(
      Path()..addPolygon(hex(9, 7), true),
      Paint()..color = const Color(0xFF05060B),
    );
    if (fitted) {
      _drawMemoryCrystal(
        canvas,
        at.translate(0, -8),
        _urnForSocket(sk.id),
        scale: 0.9,
        alpha: ghost ? 0.4 : 1.0,
      );
    }
  }

  String _urnForSocket(String socketId) {
    for (final u in kFuneralUrns) {
      if (u.socketId == socketId) return u.id;
    }
    return '';
  }

  /// The crystal the party is carrying, over the active creature.
  void _renderFuneralCarried(Canvas canvas) {
    final held = _run.held;
    final a = active;
    if (held == null || a == null) return;
    _drawMemoryCrystal(
      canvas,
      a.position.translate(0, -52 + sin(_fClock * 2.2) * 3),
      held,
      scale: 0.85,
    );
  }

  // ── STAR 1 — the bell court ──────────────────────────────

  /// Pair, crystallize, carry, fit, pulse, then let the bell answer.
  double get _keeperLoop => (_fClock % 14.0);

  void _renderBellCourt(Canvas canvas, FuneralRoom fr, bool ghost) {
    final bell = fr.bell!;
    final treadle = fr.socket!.at;
    final rung = _run.bellRung || hasStar(0);
    // THE CHAIN, in whichever world is moving it. The present moves only
    // when the pulse drives it; the past moves on the keeper's step.
    double step; // 0..1 treadle down
    double swing; // bell angle
    if (!ghost) {
      final t = funeral.bellT;
      step = t < 0 ? 0 : (t / _kBellLever).clamp(0.0, 1.0);
      if (t >= _kBellGate) step = 1 - ((t - _kBellGate) / 1.0).clamp(0.0, 1.0);
      swing = t >= _kBellSwing && t < _kBellDone
          ? sin((t - _kBellSwing) * 9) * 0.35 * (1 - (t - _kBellSwing) / 2)
          : 0;
    } else {
      final t = _keeperLoop;
      step = t >= 9.0 && t < 11.5 ? ((t - 9.0) / 0.4).clamp(0.0, 1.0) : 0;
      swing = t >= 9.4 && t < 11.0
          ? sin((t - 9.4) * 9) * 0.35 * (1 - (t - 9.4) / 1.6)
          : 0;
    }
    // The timber, carved: near-black, lit only along the edge the moon
    // catches (the past's cold and translucent). No grain stripes, no bright
    // faces — the belfry is a silhouette against the wall.
    final wood = ghost
        ? _fCold.withValues(alpha: 0.22)
        : const Color(0xFF261F21);
    final woodDeep = ghost
        ? _fCold.withValues(alpha: 0.07)
        : const Color(0xFF060405);
    final woodRim = ghost
        ? _fCold.withValues(alpha: 0.7)
        : _fMoonRim.withValues(alpha: 0.36);
    const ironBand = Color(0xFF0E0D12);
    void timber(Path p, {double lift = 1.8}) => _funeralCarve(
      canvas,
      p,
      body: wood,
      deep: woodDeep,
      rim: woodRim,
      lift: lift,
    );
    Path beamPath(Offset a, Offset b, double w) {
      final v = b - a;
      final n = Offset(-v.dy, v.dx) / max(0.001, v.distance) * (w / 2);
      return Path()..addPolygon([a + n, b + n, b - n, a - n], true);
    }

    // THE BELFRY: two timber posts either side of the gate and a beam
    // across, the bell hung from its middle on a wheel.
    final beamY = bell.dy - 44;
    for (final side in const [-1.0, 1.0]) {
      final post = Rect.fromCenter(
        center: Offset(bell.dx + side * 70, beamY + 44),
        width: 14,
        height: 96,
      );
      paintContactShadow(
        canvas,
        post.bottomCenter.translate(0, 3),
        26,
        8,
        opacity: 0.55,
      );
      timber(Path()..addRect(post));
    }
    final beam = Rect.fromCenter(
      center: Offset(bell.dx, beamY),
      width: 160,
      height: 14,
    );
    timber(Path()..addRect(beam));
    for (final dx in const [-58.0, 58.0]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(bell.dx + dx, beamY),
          width: 5,
          height: 16,
        ),
        Paint()..color = ironBand,
      );
    }
    // The bell's wheel, turning with the swing: a carved rim and three
    // spokes, dark, lit along their upper edges.
    final wheel = Offset(bell.dx + 26, beamY + 10);
    timber(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCircle(center: wheel, radius: 12))
        ..addOval(Rect.fromCircle(center: wheel, radius: 8.5)),
      lift: 1.2,
    );
    for (var k = 0; k < 3; k++) {
      final a = swing * 3 + k * pi / 3;
      _drawBeam(
        canvas,
        wheel - Offset(cos(a), sin(a)) * 9,
        wheel + Offset(cos(a), sin(a)) * 9,
        2.4,
        Color.lerp(wood, woodRim, 0.25)!,
      );
    }
    // THE LEVER: a heavy timber on an iron-bound post, one end over the
    // treadle, the other on the bell's rope.
    final pivot = Offset(treadle.dx - 70, treadle.dy - 70);
    final tilt = -0.18 + 0.34 * step;
    final dir = Offset(cos(0.8 + tilt), sin(0.8 + tilt));
    final armA = pivot + dir * 90;
    final armB = pivot - dir * 70;
    final post = Rect.fromCenter(
      center: pivot.translate(0, 26),
      width: 14,
      height: 52,
    );
    paintContactShadow(
      canvas,
      post.bottomCenter.translate(0, 3),
      26,
      8,
      opacity: 0.55,
    );
    timber(Path()..addRect(post));
    timber(beamPath(armA, armB, 16));
    for (final t in const [0.15, 0.85]) {
      final c = Offset.lerp(armB, armA, t)!;
      _drawBeam(canvas, c - dir * 3, c + dir * 3, 18, ironBand);
    }
    canvas.drawCircle(pivot, 8, Paint()..color = ironBand);
    canvas.drawCircle(
      pivot,
      3.5,
      Paint()..color = (ghost ? _fCold : _fMoonRim).withValues(alpha: 0.55),
    );
    // The rope from the lever's far end up to the wheel.
    _drawBeam(
      canvas,
      armB,
      wheel + const Offset(10, 4),
      3.2,
      ghost ? _fCold.withValues(alpha: 0.45) : const Color(0xFF5E5040),
    );
    // The bell, hung from the beam: dark bronze, lit only where its
    // shoulder and waist turn to the light — not a polished cartoon bell.
    canvas.save();
    canvas.translate(bell.dx, beamY + 6);
    canvas.rotate(swing);
    canvas.scale(1.4);
    canvas.drawRect(
      const Rect.fromLTRB(-3, 0, 3, 6),
      Paint()..color = ironBand,
    );
    canvas.translate(0, 6);
    final b = Path()
      ..moveTo(-8, 0)
      ..quadraticBezierTo(-10, 18, -22, 34)
      ..lineTo(22, 34)
      ..quadraticBezierTo(10, 18, 8, 0)
      ..close();
    // The clapper, just showing under the lip.
    canvas.drawCircle(
      Offset(swing * -12, 36.5),
      3,
      Paint()..color = ghost ? _fCold.withValues(alpha: 0.4) : ironBand,
    );
    _funeralCarve(
      canvas,
      b,
      body: ghost ? _fCold.withValues(alpha: 0.3) : const Color(0xFF2E2418),
      deep: ghost ? _fCold.withValues(alpha: 0.1) : const Color(0xFF0A0705),
      rim: ghost
          ? _fCold.withValues(alpha: 0.85)
          : const Color(0xFFC9A066).withValues(alpha: 0.75),
      lift: 2.2,
    );
    // The lip: a band of darker bronze, its edge just caught.
    canvas.drawRect(
      const Rect.fromLTRB(-22, 31, 22, 34),
      Paint()
        ..color = ghost
            ? _fCold.withValues(alpha: 0.35)
            : const Color(0xFF120D08),
    );
    canvas.drawRect(
      const Rect.fromLTRB(-21, 31, 4, 31.9),
      Paint()
        ..color = (ghost ? _fCold : const Color(0xFFC9A066)).withValues(
          alpha: 0.5,
        ),
    );
    canvas.restore();
    // The treadle plate itself, pressed down by the step: a carved slab.
    final plate = Rect.fromCenter(
      center: treadle.translate(0, 26 + step * 3),
      width: 64,
      height: 9,
    );
    if (ghost) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(plate, const Radius.circular(4)),
        Paint()..color = _fCold.withValues(alpha: 0.8),
      );
    } else {
      paintCarvedBlock(canvas, plate, 4, _kGraveStone, radius: 3);
      canvas.drawRect(
        Rect.fromLTWH(plate.left + 3, plate.top, plate.width - 6, 1.4),
        Paint()..color = _fMoonRim.withValues(alpha: 0.45),
      );
    }
    // The past's lesson is drawn after the urn and socket so its crystal
    // stays visible over both fixtures.
    if (!ghost && rung) {
      // At rest: a small stone laid flat by the treadle.
      paintCarvedBlock(
        canvas,
        Rect.fromCenter(
          center: treadle.translate(-46, 28),
          width: 26,
          height: 9,
        ),
        3,
        _kGraveStone,
        radius: 3,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: treadle.translate(-46, 24),
          width: 20,
          height: 1.4,
        ),
        Paint()..color = _fMoonRim.withValues(alpha: 0.4),
      );
    }
  }

  /// A read-only demonstration: two elemental echoes form a crystal, then
  /// the keeper carries it to the treadle. It never edits puzzle state.
  void _drawKeeperLesson(Canvas canvas, FuneralRoom fr) {
    final t = _keeperLoop;
    final urn = fr.urn!;
    final socket = fr.socket!.at;
    final fade = (t / 0.6).clamp(0.0, 1.0) * ((14.0 - t) / 1.5).clamp(0.0, 1.0);
    final alpha = fade * ((_run.bellRung || hasStar(0)) ? 0.4 : 0.9);
    final left = urn.translate(-52, 26);
    final right = urn.translate(52, 26);
    final carry = ((t - 5.0) / 2.0).clamp(0.0, 1.0);
    final keeper = Offset.lerp(left, socket.translate(-42, 28), carry)!;
    _drawGhost(canvas, keeper, alpha: alpha, phase: 1);
    _drawGhost(canvas, right, alpha: alpha, phase: 3);

    // Element-colored offerings pass from BOTH hands into the ashes: a
    // stream of grains in each hand's colour, arcing over and thinning out
    // as it lands. ~40 grains a hand.
    const dust = Color(0xFFCBB58A);
    const spirit = Color(0xFF9B8CFF);
    if (t >= 1 && t < 4) {
      final into =
          ((t - 1) / 0.4).clamp(0.0, 1.0) * ((4 - t) / 0.5).clamp(0.0, 1.0);
      for (final (from, col) in [(keeper, dust), (right, spirit)]) {
        final ramp = grainRampFrom(col);
        final a = from.translate(0, -30), z = urn.translate(0, -42);
        Offset pos(double f, int i) => Offset.lerp(a, z, f)!.translate(
          sin(i * 2.39996) * 3.2 * (1 - f),
          -sin(f * pi) * 15 + cos(i * 1.7) * 2.4 * (1 - f),
        );
        const n = 56;
        for (var i = 0; i < n; i++) {
          final f = ((t - 1) * 0.7 + i / n) % 1.0;
          final f0 = f - 0.018;
          if (f0 < 0) continue;
          _funeralInk.add(
            pos(f0, i),
            pos(f, i),
            ramp[i % 3 == 0 ? 2 : 1],
            alpha * into * min(1.0, f * 6) * (1 - f * 0.6),
          );
        }
      }
      _funeralInk.paint(canvas, width: 1.8);
    }
    if (t >= 3.0) {
      final formed = ((t - 3) / 1.0).clamp(0.0, 1.0);
      final aboveUrn = urn.translate(0, -44);
      final hand = keeper.translate(18, -36);
      final crystal = t < 5
          ? Offset.lerp(aboveUrn, hand, ((t - 4) / 1.0).clamp(0.0, 1.0))!
          : t < 7
          ? hand
          : Offset.lerp(
              hand,
              socket.translate(0, -14),
              ((t - 7) / 0.8).clamp(0.0, 1.0),
            )!;
      _drawMemoryCrystal(
        canvas,
        crystal,
        'urn_keeper',
        alpha: alpha * formed,
        scale: 1.2 * formed,
      );
    }
    // The fitted groove glows red before the remembered step rings the bell.
    if (t >= 8 && t < 10) {
      final beat = sin(((t - 8) / 2) * pi);
      canvas.drawLine(
        socket.translate(36, 0),
        socket,
        Paint()
          ..color = const Color(0xFFE86479).withValues(alpha: alpha * beat)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// A filled beam from [a] to [b], [w] wide — material, not a line.
  void _drawBeam(Canvas canvas, Offset a, Offset b, double w, Color color) {
    final v = b - a;
    final n = Offset(-v.dy, v.dx) / max(0.001, v.distance) * (w / 2);
    canvas.drawPath(
      Path()..addPolygon([a + n, b + n, b - n, a - n], true),
      Paint()..color = color,
    );
  }

  /// THE KEEPER'S NICHE: a recess in the west wall. Drifted with dust in the
  /// present until Dust clears it; in the past, the keepsake glints in it
  /// once the keeper has set it there.
  void _drawNiche(Canvas canvas, Offset at, bool ghost) {
    final arch = Path()
      ..moveTo(at.dx - 4, at.dy + 26)
      ..lineTo(at.dx - 4, at.dy - 14)
      ..quadraticBezierTo(at.dx + 18, at.dy - 34, at.dx + 40, at.dy - 14)
      ..lineTo(at.dx + 40, at.dy + 26)
      ..close();
    canvas.drawPath(arch, Paint()..color = _fVoid.withValues(alpha: 0.85));
    if (ghost) {
      if (_keeperLoop > 0.8) {
        canvas.drawCircle(
          at.translate(18, 6),
          4 + sin(_fClock * 3),
          Paint()..color = _fCold.withValues(alpha: 0.8),
        );
      }
      return;
    }
    if (!_run.nicheCleared) {
      _drawDustDrift(canvas, Rect.fromLTWH(at.dx - 6, at.dy - 8, 50, 36), 3);
    }
  }

  // ── STAR 2 — the bearers' court ──────────────────────────

  void _renderBearersCourt(Canvas canvas, FuneralRoom fr, bool ghost) {
    final flags = _run.flags;
    const n = kBearerCols * kBearerCols;
    // The flags: carved slabs set proud of the court.
    for (var i = 0; i < n; i++) {
      final r = fr.flagRect(i).deflate(6);
      final level = ghost || flags.isLevel(i);
      if (ghost) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()
            ..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, [
              _fCold.withValues(alpha: 0.26),
              _fCold.withValues(alpha: 0.10),
            ]),
        );
        continue;
      }
      if (level) {
        paintCarvedBlock(
          canvas,
          Rect.fromLTRB(r.left, r.top, r.right, r.bottom - 7),
          7,
          _kWraithGlass,
          radius: 5,
          topColor: Color.lerp(_kWraithGlass.stoneTop, _fSod, 0.45),
        );
        // A worn hollow in the middle, where feet have gone.
        canvas.drawOval(
          Rect.fromCenter(
            center: r.center.translate(0, -3),
            width: r.width * 0.5,
            height: r.height * 0.3,
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.10),
        );
        continue;
      }
      // TIPPED: the pit where it lay, deep at the far edge; the slab stood on
      // its near edge, its top face lit and its underside dark.
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()
          ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
            const Color(0xFF010205),
            _fCut.withValues(alpha: 0.9),
          ]),
      );
      final face = Path()
        ..moveTo(r.left + 4, r.bottom - 12)
        ..lineTo(r.right - 4, r.bottom - 12)
        ..lineTo(r.right - 14, r.top + 22)
        ..lineTo(r.left + 14, r.top + 22)
        ..close();
      canvas.drawPath(
        face,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(r.center.dx, r.top + 22),
            Offset(r.center.dx, r.bottom - 12),
            [
              Color.lerp(_kWraithGlass.stoneTop, _fSod, 0.3)!,
              _kWraithGlass.stoneFace,
            ],
          ),
      );
      // Its edge, standing on the pit's lip.
      canvas.drawRect(
        Rect.fromLTRB(r.left + 4, r.bottom - 12, r.right - 4, r.bottom - 5),
        Paint()..color = _kWraithGlass.stoneFoot,
      );
      // A chip out of one corner.
      canvas.drawPath(
        Path()
          ..moveTo(r.right - 14, r.top + 22)
          ..lineTo(r.right - 26, r.top + 22)
          ..lineTo(r.right - 17, r.top + 32)
          ..close(),
        Paint()..color = const Color(0xFF010205),
      );
    }
    // THE BEAMS: a strip of leaded glass joining two flags, riveted into
    // each — the present's machinery. The past has none.
    if (!ghost) {
      // Standing on a flag, it and every flag its beams run to light warm:
      // exactly what a press would flip, before it is pressed.
      final under = _flagUnderHand;
      if (under != null && !_run.bierArrived && funeral.walkDist < 0) {
        final pulse = 0.6 + 0.4 * sin(_fClock * 3);
        for (final g in [under, ...bearerLinked(under)]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              fr.flagRect(g).deflate(6),
              const Radius.circular(6),
            ),
            Paint()
              ..color = _fEmber.withValues(
                alpha: (g == under ? 0.16 : 0.24) * pulse,
              ),
          );
        }
      }
      for (final (a, b) in kBearerBeams) {
        final pa = fr.flagCentre(a), pb = fr.flagCentre(b);
        _drawBeam(canvas, pa, pb, 14, _fVoid.withValues(alpha: 0.28));
        _drawBeam(
          canvas,
          pa,
          pb,
          8,
          _kWraithGlass.smoke.withValues(alpha: 0.45),
        );
        _drawBeam(canvas, pa, pb, 3, _fEmber.withValues(alpha: 0.28));
        for (final end in [pa, pb]) {
          canvas.drawCircle(
            end,
            8,
            Paint()..color = _fVoid.withValues(alpha: 0.35),
          );
          canvas.drawCircle(
            end,
            5,
            Paint()..color = _fEmber.withValues(alpha: 0.45),
          );
        }
      }
    }
    final path = fr.bearerPath;
    final total = _pathLength(path);
    if (ghost) {
      // THE PAST: the bearers walk their route, leaving footprints on the
      // flags they tread. The prints stay lit for the whole walk, so the
      // full route stands on the floor at once when they reach the door,
      // and fade together in the pause before the next walk.
      final period = total / _kBearerSpeed + 2.0;
      final d = (_fClock % period) * _kBearerSpeed;
      for (final f in kBearerRoute) {
        final c = fr.flagCentre(f);
        var passedAt = -1.0;
        var acc = 0.0;
        for (var i = 1; i < path.length; i++) {
          final seg = (path[i] - path[i - 1]).distance;
          if (path[i] == c) passedAt = acc + seg;
          acc += seg;
        }
        if (passedAt >= 0 && d >= passedAt) {
          final a = d <= total
              ? 1.0
              : (1 - (d - total) / (_kBearerSpeed * 2.0)).clamp(0.0, 1.0);
          _drawFootprints(canvas, c, a);
        }
      }
      if (d <= total) {
        final at = _pathPoint(path, d);
        _drawBierWagon(canvas, at, ghostly: true);
        _drawGhost(canvas, at.translate(-26, 8), alpha: 0.8, phase: 0.2);
        _drawGhost(canvas, at.translate(26, 8), alpha: 0.8, phase: 1.7);
      }
      return;
    }
    // THE PRESENT: the bier at the doorstep, on its way, or at the chapel.
    if (_run.bierArrived || hasStar(1)) {
      _drawBierWagon(canvas, path.last.translate(-60, 0));
      return;
    }
    final walking = funeral.walkDist >= 0;
    if (!walking) {
      _drawBierWagon(canvas, fr.doorstep!.translate(-70, 0));
      return;
    }
    final at = _pathPoint(path, funeral.walkDist);
    final waited = funeral.walkWait;
    final fade = waited <= _kBearerWait
        ? 1.0
        : (1 - (waited - _kBearerWait) / _kBearerFade).clamp(0.0, 1.0);
    _drawBierWagon(canvas, at, ghostly: true, alpha: fade);
    _drawGhost(canvas, at.translate(-26, 8), alpha: 0.8 * fade, phase: 0.2);
    _drawGhost(canvas, at.translate(26, 8), alpha: 0.8 * fade, phase: 1.7);
    if (funeral.walkStop != null) {
      for (var i = 1; i < path.length - 1; i++) {
        final seg = _pathLength(path.sublist(0, i + 1));
        if (seg >= funeral.walkDist) {
          _drawFootprints(canvas, at, 0.5 * fade);
          break;
        }
      }
    }
  }

  void _drawFootprints(Canvas canvas, Offset c, double a) {
    if (a <= 0.01) return;
    for (final (dx, dy) in const [(-10.0, -6.0), (10.0, 6.0)]) {
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(dx, dy), width: 9, height: 15),
        Paint()..color = _fCold.withValues(alpha: 0.7 * a),
      );
    }
  }

  /// The bier on its wheels, shrouded: a dark carved bed on two carved
  /// wheels, and on it a body under a sheet — a drape with a head, a chest
  /// and feet in it, not a pill and a ball.
  void _drawBierWagon(
    Canvas canvas,
    Offset at, {
    bool ghostly = false,
    double alpha = 1.0,
  }) {
    if (alpha <= 0.01) return;
    final body = ghostly
        ? _fCold.withValues(alpha: 0.4 * alpha)
        : const Color(0xFF231E28);
    final deep = ghostly
        ? _fCold.withValues(alpha: 0.15 * alpha)
        : const Color(0xFF09070B);
    final rim = ghostly
        ? _fCold.withValues(alpha: 0.75 * alpha)
        : _fMoonRim.withValues(alpha: 0.45);
    for (final dx in const [-24.0, 24.0]) {
      _funeralCarve(
        canvas,
        Path()
          ..addOval(Rect.fromCircle(center: at.translate(dx, 14), radius: 7)),
        body: body,
        deep: deep,
        rim: rim,
        lift: 1.3,
      );
    }
    _funeralCarve(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 76, height: 16),
          const Radius.circular(4),
        ),
      ),
      body: body,
      deep: deep,
      rim: rim,
    );
    _paintDrape(
      canvas,
      at.translate(-1, -8),
      70,
      17,
      ghostly ? _fCold : const Color(0xFF8C96A8),
      (ghostly ? 0.6 : 1.0) * alpha,
    );
  }

  /// A SHEET OVER A BODY, head to the left: one smooth drape — the round of
  /// the head, the dip of the neck, the chest, the long fall to the knees and
  /// the feet turned up — carved like the rest, lit along its crest.
  void _paintDrape(
    Canvas canvas,
    Offset c,
    double len,
    double h,
    Color cloth,
    double alpha,
  ) {
    if (alpha <= 0.01) return;
    final x0 = c.dx - len / 2, y0 = c.dy + h * 0.4;
    Offset at(double u, double v) => Offset(x0 + u * len, y0 - v * h);
    final p = Path()..moveTo(x0 + 3, y0);
    void curve(List<(double, double)> k) {
      final a = at(k[0].$1, k[0].$2),
          b = at(k[1].$1, k[1].$2),
          e = at(k[2].$1, k[2].$2);
      p.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
    }

    curve(const [(0.0, 0.2), (0.0, 0.98), (0.085, 1.0)]); // the head
    curve(const [(0.15, 1.0), (0.15, 0.6), (0.195, 0.6)]); // the neck
    curve(const [(0.24, 0.6), (0.25, 0.86), (0.36, 0.86)]); // the chest
    curve(const [(0.55, 0.86), (0.62, 0.68), (0.8, 0.6)]); // to the knees
    curve(const [(0.87, 0.58), (0.89, 0.84), (0.935, 0.83)]); // the feet
    curve(const [(0.99, 0.8), (1.0, 0.3), (0.985, 0.0)]); // and down
    p.close();
    _funeralCarve(
      canvas,
      p,
      body: cloth.withValues(alpha: 0.9 * alpha),
      deep: Color.lerp(
        cloth,
        Colors.black,
        0.6,
      )!.withValues(alpha: 0.92 * alpha),
      rim: Color.lerp(
        cloth,
        Colors.white,
        0.45,
      )!.withValues(alpha: 0.95 * alpha),
      lift: 2.6,
    );
  }

  // ── THE RITE — the vigil chapel ──────────────────────────

  void _renderChapel(
    Canvas canvas,
    DungeonRoom room,
    FuneralRoom fr,
    bool ghost,
  ) {
    final done = _run.riteDone || guardianAwake || hasStar(2);
    final t = funeral.riteT;
    for (final st in fr.stones) {
      _drawKneeler(canvas, st, ghost);
    }
    // The bier on its trestles, until it is carried through.
    final bierWall = room.walls.first;
    if (!done || t >= 0) {
      var lift = 0.0, carry = 0.0;
      if (t >= 0) {
        lift = ((t - _kRiteRise) / (_kRiteLift - _kRiteRise)).clamp(0.0, 1.0);
        carry = ((t - _kRiteLift) / (_kRiteDone - _kRiteLift)).clamp(0.0, 1.0);
      }
      _drawTrestles(canvas, bierWall, ghost);
      final door = Offset(450, 20);
      final from = bierWall.center.translate(0, -8 * lift);
      final at = Offset.lerp(from, door, carry)!;
      _drawShroud(canvas, at, ghost, alpha: 1 - carry * 0.8);
      if (t >= 0) {
        // The mourners' ghosts rise beside the party and carry it.
        final rise = (t / _kRiteRise).clamp(0.0, 1.0);
        for (final i in kMournerStones) {
          final s = fr.stones[i];
          final foot = Offset.lerp(
            s.translate(-26, 0),
            at.translate((i - 2) * 20.0, 24),
            carry,
          )!;
          _drawGhost(
            canvas,
            foot,
            alpha: 0.8 * rise * (1 - carry * 0.6),
            kneel: 1 - lift,
            phase: i.toDouble(),
            tint: _mournerTint(i),
          );
        }
      }
    } else {
      _drawTrestles(canvas, bierWall, ghost);
    }
    // THE PAST: three mourners kneel at their stones.
    if (ghost && !done) {
      for (final i in kMournerStones) {
        _drawGhost(
          canvas,
          fr.stones[i].translate(0, -4),
          alpha: 0.85,
          kneel: 1,
          phase: i * 1.3,
          tint: _mournerTint(i),
        );
      }
    }
  }

  /// A mourner's colour: its element, cooled a little into the past.
  Color _mournerTint(int stone) =>
      Color.lerp(elementColor(kMournerAt[stone] ?? 'Spirit'), _fCold, 0.3)!;

  void _drawTrestles(Canvas canvas, Rect w, bool ghost) {
    final wood = ghost
        ? _fCold.withValues(alpha: 0.5)
        : const Color(0xFF26222E);
    for (final x in [w.left + 18, w.right - 18]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, w.center.dy + 6),
          width: 8,
          height: w.height + 8,
        ),
        Paint()..color = wood,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(w.deflate(4), const Radius.circular(3)),
      Paint()..color = wood,
    );
  }

  /// The body on the bier, under its sheet (see [_paintDrape]).
  void _drawShroud(Canvas canvas, Offset c, bool ghost, {double alpha = 1}) {
    _paintDrape(
      canvas,
      c.translate(-1, -1),
      118,
      24,
      ghost ? _fCold : const Color(0xFF8C96A8),
      (ghost ? 0.55 : 1.0) * alpha,
    );
  }

  /// A KNEELER: a carved stone step, and on it a cushion worn to the shape
  /// of the knees that used it — faded in the present, whole in the past.
  void _drawKneeler(Canvas canvas, Offset st, bool ghost) {
    final pal = ghost ? _kPastGlass : _kWraithGlass;
    paintCarvedBlock(
      canvas,
      Rect.fromCenter(center: st.translate(0, -2), width: 56, height: 22),
      8,
      pal,
      radius: 5,
    );
    final cushion = RRect.fromRectAndRadius(
      Rect.fromCenter(center: st.translate(0, -4), width: 40, height: 13),
      const Radius.circular(6),
    );
    final velvet = ghost ? _fCold : const Color(0xFF5A2430);
    canvas.drawRRect(
      cushion,
      Paint()
        ..shader = ui.Gradient.linear(
          cushion.outerRect.topCenter,
          cushion.outerRect.bottomCenter,
          [
            Color.lerp(
              velvet,
              Colors.white,
              0.15,
            )!.withValues(alpha: ghost ? 0.5 : 0.95),
            Color.lerp(
              velvet,
              Colors.black,
              0.4,
            )!.withValues(alpha: ghost ? 0.3 : 0.95),
          ],
        ),
    );
    for (final dx in const [-8.0, 8.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: st.translate(dx, -4), width: 11, height: 6),
        Paint()..color = Colors.black.withValues(alpha: 0.2),
      );
    }
  }

  // ── THE MAXIM — the quiet alcove ─────────────────────────

  /// The six kneelers round the empty urn, and the echoes the alcove kept of
  /// the party: bright kneeling figures in the past, each in its creature's
  /// colour, and faint in the present — the one room where your own past
  /// shows through.
  void _renderAlcove(Canvas canvas, FuneralRoom fr, bool ghost) {
    final r = _run;
    final done = r.urnFilled || discoveredClouds.contains(kSpiritEmptyUrnEgg);
    for (var i = 0; i < fr.stones.length; i++) {
      _drawKneeler(canvas, fr.stones[i], ghost);
      // A vigil that fell short lights the kneelers that were held.
      if (!ghost &&
          funeral.riteMissT >= 0 &&
          funeral.riteMissShown.contains(i)) {
        final a = (1 - funeral.riteMissT / _kRiteMiss).clamp(0.0, 1.0);
        canvas.drawOval(
          Rect.fromCenter(center: fr.stones[i], width: 70, height: 34),
          Paint()
            ..shader = ui.Gradient.radial(fr.stones[i], 35, [
              _fEmber.withValues(alpha: 0.45 * a),
              _fEmber.withValues(alpha: 0.0),
            ]),
        );
      }
    }
    if (done) return;
    for (final (p, element) in r.echoes) {
      _drawGhost(
        canvas,
        p.translate(0, -2),
        alpha: ghost ? 0.85 : 0.32,
        kneel: 1,
        phase: p.dx * 0.01,
        tint: Color.lerp(elementColor(element), _fCold, 0.35),
      );
    }
  }

  // ── THE MAXIM — the uncut name stone ─────────────────────

  void _drawNameStone(Canvas canvas, FuneralRoom fr, bool ghost) {
    final foot = fr.nameStone!.translate(0, 34);
    final found = discoveredClouds.contains(kSpiritEmptyUrnEgg);
    final stone = Path()
      ..moveTo(foot.dx - 24, foot.dy)
      ..lineTo(foot.dx - 21, foot.dy - 60)
      ..quadraticBezierTo(foot.dx, foot.dy - 78, foot.dx + 21, foot.dy - 60)
      ..lineTo(foot.dx + 24, foot.dy)
      ..close();
    // Near-black slate, the moon along its shoulder: the names cut into it
    // are the only light on it.
    paintContactShadow(canvas, foot.translate(3, 2), 60, 12, opacity: 0.5);
    _funeralCarve(
      canvas,
      stone,
      body: ghost ? _fCold.withValues(alpha: 0.2) : _kGraveStone.stoneTop,
      deep: ghost ? _fCold.withValues(alpha: 0.06) : _kGraveStone.stoneFoot,
      rim: ghost
          ? _fCold.withValues(alpha: 0.7)
          : _fMoonRim.withValues(alpha: 0.6),
      lift: 2.2,
    );
    // The face where the names go, dressed a shade smoother.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(foot.dx - 17, foot.dy - 62, foot.dx + 17, foot.dy - 18),
        const Radius.circular(3),
      ),
      Paint()
        ..color = (ghost ? _fCold : const Color(0xFF3A4252)).withValues(
          alpha: ghost ? 0.06 : 0.18,
        ),
    );
    // The names: none, then cut one by one, then standing cut.
    final cut = found
        ? 3
        : funeral.nameT >= 0
        ? (funeral.nameT / _kNameCut * 3.2).floor().clamp(0, 3)
        : 0;
    var k = 0;
    for (final c in creatures.take(3)) {
      if (k >= cut) break;
      final y = foot.dy - 54 + k * 14.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(foot.dx, y), width: 26, height: 5),
          const Radius.circular(2.5),
        ),
        Paint()
          ..color = Color.lerp(
            elementColor(c.member.element),
            _fEmber,
            0.4,
          )!.withValues(alpha: 0.9),
      );
      k++;
    }
  }

  // ── STAR 3 — the vigil chime ─────────────────────────────

  void _renderVigil(Canvas canvas, DungeonRoom room, FuneralRoom fr) {
    final at = fr.chime!;
    // The chime's dais: a carved round step it stands on.
    // Near-black slate, the moon along its far lip, so the chime and the
    // channel plate on it are what read.
    paintCarvedDisc(canvas, at.translate(0, 26), 58, 22, 8, _kGraveStone);
    canvas.drawArc(
      Rect.fromCenter(center: at.translate(0, 26), width: 116, height: 44),
      pi + 0.35,
      pi - 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _fMoonRim.withValues(alpha: 0.35),
    );
    canvas.save();
    canvas.translate(at.dx, at.dy + 20);
    canvas.scale(1.45);
    canvas.translate(-at.dx, -at.dy - 20);
    _renderVigilChime(canvas, room, fr);
    canvas.restore();
    _renderVigilShadow(canvas);
  }

  void _renderVigilChime(Canvas canvas, DungeonRoom room, FuneralRoom fr) {
    final at = fr.chime!;
    final f = funeral;
    // The frame: two posts and a bar, and a tube hanging from it.
    // Carved dark, lit along the edge the moon catches.
    void post(Rect r) => _funeralCarve(
      canvas,
      Path()..addRect(r),
      body: const Color(0xFF26222E),
      deep: const Color(0xFF07060A),
      rim: _fMoonRim.withValues(alpha: 0.4),
      lift: 1.6,
    );
    for (final dx in const [-26.0, 26.0]) {
      post(
        Rect.fromCenter(center: at.translate(dx, -20), width: 7, height: 70),
      );
    }
    post(Rect.fromCenter(center: at.translate(0, -54), width: 66, height: 7));
    final ring = f.chimeHeld ? f.chimeWindow : 0.0;
    final shake = ring > 0 ? sin(_fClock * 30) * 1.5 : 0.0;
    final tube = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at.translate(shake, -18), width: 14, height: 58),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      tube,
      Paint()
        ..shader = ui.Gradient.linear(
          tube.outerRect.topLeft,
          tube.outerRect.bottomRight,
          f.chimeWarm
              ? [const Color(0xFFFFE0A0), const Color(0xFFB0702E)]
              : [const Color(0xFF9A8058), const Color(0xFF3A2A18)],
        ),
    );
    // THE CHANNEL: hair-fine, finer than any groove before it — the Blood
    // Pip's gate, shown on the thing itself.
    final base = Rect.fromCenter(
      center: at.translate(0, 22),
      width: 60,
      height: 16,
    );
    paintCarvedBlock(canvas, base, 5, _kWraithGlass, radius: 4);
    canvas.drawLine(
      at.translate(-22, 22),
      at.translate(22, 22),
      Paint()
        ..strokeWidth = 1.0
        ..color = (f.chimeWarm || ring > 0 ? _fBlood : _fVoid).withValues(
          alpha: 0.95,
        ),
    );
    if (f.chimeWarm) {
      // WARM: the tube glows like metal from a forge and breathes — the one
      // thing in the fight that says "now", seen from across the room.
      final pulse = 0.5 + 0.5 * sin(_fClock * 4);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          at.translate(0, -18),
          70 + 10 * pulse,
          _fEmber.withValues(alpha: 0.45 + 0.2 * pulse),
        );
      }
      canvas.drawCircle(
        at.translate(0, -18),
        44,
        Paint()
          ..shader = ui.Gradient.radial(at.translate(0, -18), 44, [
            _fEmber.withValues(alpha: 0.35 + 0.15 * pulse),
            _fEmber.withValues(alpha: 0.0),
          ]),
      );
    }
    if (ring > 0) {
      final k = 1 - ring / max(0.1, _guardianLullSeconds);
      canvas.drawCircle(
        at.translate(0, -18),
        30 + 70 * k,
        Paint()
          ..shader = ui.Gradient.radial(
            at.translate(0, -18),
            30 + 70 * k,
            [
              _fCold.withValues(alpha: 0.0),
              _fCold.withValues(alpha: 0.18 * (1 - k)),
              _fCold.withValues(alpha: 0.0),
            ],
            const [0.7, 0.9, 1.0],
          ),
      );
    }
    // THE LESSON AT THE DOOR: the last keeper's echo strikes the chime.
    if (f.introT >= 0 && f.introT < _kVigilIntro) {
      final a = f.introT < 0.4
          ? f.introT / 0.4
          : (1 - (f.introT - 1.6) / 1.0).clamp(0.0, 1.0);
      _drawGhost(canvas, at.translate(40, 30), alpha: 0.8 * a);
    }
  }

  void _renderVigilShadow(Canvas canvas) {
    final f = funeral;
    final ring = f.chimeHeld ? f.chimeWindow : 0.0;
    // WRAITHORD'S SHADOW: gathered round it, or scattered by the note.
    final boss = _guardianEnemy;
    if (boss != null && !boss.isDead && guardianAwake) {
      final p = boss.position;
      if (ring > 0) {
        for (var i = 0; i < 6; i++) {
          final ang = i * pi / 3 + _fClock;
          final d = 60 + 40 * (1 - ring / max(0.1, _guardianLullSeconds));
          canvas.drawCircle(
            p + Offset(cos(ang), sin(ang)) * d,
            8,
            Paint()..color = const Color(0xFF1A0F24).withValues(alpha: 0.5),
          );
        }
      } else {
        canvas.drawCircle(
          p,
          70,
          Paint()
            ..shader = ui.Gradient.radial(
              p,
              70,
              [
                const Color(0xFF1A0F24).withValues(alpha: 0.0),
                const Color(0xFF1A0F24).withValues(alpha: 0.55),
                const Color(0xFF1A0F24).withValues(alpha: 0.0),
              ],
              const [0.35, 0.75, 1.0],
            ),
        );
      }
    }
  }

  // ── Over the doors ───────────────────────────────────────

  /// The glass opening a wall door fills, and the way it faces — the same
  /// rect and arch the shared glass door draws, so a gate sits IN its
  /// doorway rather than pasted over it.
  (Rect, AxisDirection) _funeralDoorGlass(DungeonRoom room, DungeonDoor d) {
    final b = room.bounds;
    final r = d.rect;
    if (r.top <= b.top + 1) {
      return (
        Rect.fromLTRB(
          r.left + 10,
          b.top - 2,
          r.right - 10,
          b.top + kGlassWallFace + 4,
        ),
        AxisDirection.up,
      );
    }
    if (r.bottom >= b.bottom - 1) {
      return (
        Rect.fromLTRB(r.left + 10, r.top + 2, r.right - 10, r.bottom + 6),
        AxisDirection.down,
      );
    }
    if (r.left <= b.left + 1) {
      return (
        Rect.fromLTRB(r.left - 6, r.top + 8, r.right - 2, r.bottom - 8),
        AxisDirection.left,
      );
    }
    return (
      Rect.fromLTRB(r.left + 2, r.top + 8, r.right + 6, r.bottom - 8),
      AxisDirection.right,
    );
  }

  /// THE FUNERAL GATE (wrought iron, under the bell) and THE CHAPEL DOOR
  /// (strapped oak): each drawn inside its doorway's arch, and each swinging
  /// open — the gate on the bell's last beat, the door as the bier arrives.
  /// No bars-and-keyhole: neither has a key, and a keyhole sends players
  /// hunting for one.
  void _renderFuneralOverDoors(Canvas canvas, DungeonRoom room) {
    for (final d in room.doors) {
      final bellGate =
          room.id == 'bell_court' && d.targetRoomId == 'bearers_court';
      final chapel =
          room.id == 'bearers_court' && d.targetRoomId == 'vigil_chapel';
      if (!bellGate && !chapel) continue;
      var open = _funeralDoorBlocked(room, d) ? 0.0 : 1.0;
      if (bellGate && funeral.bellT >= _kBellGate) {
        open = ((funeral.bellT - _kBellGate) / (_kBellDone - _kBellGate)).clamp(
          0.0,
          1.0,
        );
      } else if (bellGate && _run.isGhost && !(_run.bellRung || hasStar(0))) {
        // The past opens it on the keeper's step.
        final t = _keeperLoop;
        open = t >= 9.6 && t < 12.0
            ? Curves.easeOut.transform(((t - 9.6) / 0.7).clamp(0.0, 1.0))
            : 0.0;
      }
      if (chapel && _run.isGhost && !(_run.bierArrived || hasStar(1))) {
        // The past opens it as the bearers' bier reaches it.
        open = _bearersPastDoorOpen(room);
      }
      if (open >= 1) continue;
      final (glass, out) = _funeralDoorGlass(room, d);
      final arch = lancetPath(glass, out);
      canvas.save();
      canvas.clipPath(arch);
      if (bellGate) {
        _drawIronGate(canvas, glass, open, cold: _run.isGhost);
      } else {
        _drawOakDoor(canvas, glass, out, open);
      }
      canvas.restore();
      paintLead(canvas, arch, _kWraithGlass, width: 3.2);
    }
  }

  /// How far open the chapel door stands in the past, on the bearers' loop:
  /// it swings as the bier comes within reach and closes again in the pause.
  double _bearersPastDoorOpen(DungeonRoom room) {
    final fr = room.funeral;
    if (fr?.doorstep == null) return 0;
    final path = fr!.bearerPath;
    final total = _pathLength(path);
    final d = (_fClock % (total / _kBearerSpeed + 2.0)) * _kBearerSpeed;
    final toDoor = total - d;
    if (d > total)
      return (1 - (d - total) / (_kBearerSpeed * 1.2)).clamp(0.0, 1.0);
    return Curves.easeOut.transform((1 - toDoor / 160).clamp(0.0, 1.0));
  }

  /// Two wrought-iron leaves meeting in the middle: tapered bars with spear
  /// heads, two rails, dog bars low down, a ring where they meet. [open]
  /// swings each leaf back toward its jamb.
  void _drawIronGate(Canvas canvas, Rect g, double open, {bool cold = false}) {
    final iron = cold
        ? _fCold.withValues(alpha: 0.55)
        : const Color(0xFF211F29);
    final hi = cold ? _fCold.withValues(alpha: 0.95) : const Color(0xFF77738A);
    // The dark of the passage behind it.
    canvas.drawRect(g, Paint()..color = _fVoid.withValues(alpha: 0.55));
    final half = g.width / 2;
    final leafW = half * (1 - 0.82 * open);
    for (final side in const [-1, 1]) {
      final leaf = side < 0
          ? Rect.fromLTWH(g.left, g.top, leafW, g.height)
          : Rect.fromLTWH(g.right - leafW, g.top, leafW, g.height);
      // Rails.
      for (final y in [g.top + g.height * 0.34, g.bottom - g.height * 0.14]) {
        final rail = Rect.fromLTRB(leaf.left, y - 2.5, leaf.right, y + 2.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rail, const Radius.circular(2)),
          Paint()
            ..shader = ui.Gradient.linear(rail.topCenter, rail.bottomCenter, [
              hi,
              iron,
            ]),
        );
      }
      // Bars, each tapering to a spear head.
      const n = 4;
      for (var i = 0; i < n; i++) {
        final x = leaf.left + leaf.width * (i + 0.5) / n;
        final top = g.top + 8;
        final bar = Path()
          ..moveTo(x - 2.2, g.bottom)
          ..lineTo(x - 1.6, top + 6)
          ..lineTo(x - 3.6, top + 7)
          ..lineTo(x, top - 2)
          ..lineTo(x + 3.6, top + 7)
          ..lineTo(x + 1.6, top + 6)
          ..lineTo(x + 2.2, g.bottom)
          ..close();
        canvas.drawPath(
          bar,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x - 3, 0),
              Offset(x + 3, 0),
              [iron, hi, iron],
              const [0.0, 0.5, 1.0],
            ),
        );
      }
      // Dog bars between them, low down.
      for (var i = 0; i < n - 1; i++) {
        final x = leaf.left + leaf.width * (i + 1) / n;
        canvas.drawRect(
          Rect.fromLTRB(x - 1.2, g.bottom - g.height * 0.14, x + 1.2, g.bottom),
          Paint()..color = iron,
        );
      }
    }
    if (open < 0.05) {
      // The ring where the two leaves meet.
      final c = Offset(g.center.dx, g.top + g.height * 0.34);
      canvas.drawCircle(c, 7, Paint()..color = iron);
      canvas.drawCircle(
        c,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = hi.withValues(alpha: 0.8),
      );
      canvas.drawCircle(c, 2.5, Paint()..color = hi);
    }
  }

  /// A strapped oak door in a side wall's slit: planks, three iron straps
  /// with rivets, a ring pull. Two leaves; [open] folds them to the jambs.
  void _drawOakDoor(Canvas canvas, Rect g, AxisDirection out, double open) {
    canvas.drawRect(g, Paint()..color = _fVoid.withValues(alpha: 0.6));
    const oak = Color(0xFF3E2C24), oakDark = Color(0xFF1B130F);
    const strap = Color(0xFF26242C), strapHi = Color(0xFF6A6676);
    final halfH = g.height / 2;
    final leafH = halfH * (1 - 0.85 * open);
    for (final side in const [-1, 1]) {
      final leaf = side < 0
          ? Rect.fromLTWH(g.left, g.top, g.width, leafH)
          : Rect.fromLTWH(g.left, g.bottom - leafH, g.width, leafH);
      canvas.drawRect(
        leaf,
        Paint()
          ..shader = ui.Gradient.linear(
            leaf.centerLeft,
            leaf.centerRight,
            [oakDark, oak, oakDark],
            const [0.0, 0.55, 1.0],
          ),
      );
      // Plank seams, as darker filled grooves.
      for (final t in const [0.33, 0.66]) {
        final x = leaf.left + leaf.width * t;
        canvas.drawRect(
          Rect.fromLTRB(x - 0.8, leaf.top, x + 0.8, leaf.bottom),
          Paint()..color = oakDark.withValues(alpha: 0.8),
        );
      }
      // Straps with rivets.
      for (final t in const [0.25, 0.75]) {
        final y = leaf.top + leaf.height * t;
        final band = Rect.fromLTRB(leaf.left, y - 3, leaf.right, y + 3);
        canvas.drawRect(
          band,
          Paint()
            ..shader = ui.Gradient.linear(band.topCenter, band.bottomCenter, [
              strapHi,
              strap,
            ]),
        );
        for (final x in [band.left + 5, band.right - 5]) {
          canvas.drawCircle(Offset(x, y), 1.6, Paint()..color = strapHi);
        }
      }
    }
    if (open < 0.05) {
      final c = Offset(
        out == AxisDirection.right
            ? g.left + g.width * 0.35
            : g.right - g.width * 0.35,
        g.center.dy,
      );
      canvas.drawCircle(
        c,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = strapHi,
      );
    }
  }
}

// ── Props pass helpers (2026-10-08) ─────────────────────────

/// A carved silhouette: [shape] in near-black, lit only along the edges that
/// face the light (up and to the left) — the rim the moon catches. The rim is
/// the shape's own edge, shifted out from under the body, so it never reads
/// as a drawn outline: it is widest where an edge faces the light, gone where
/// it faces away, and rolls off in steps into the dark of the body.
void _funeralCarve(
  Canvas canvas,
  Path shape, {
  required Color body,
  required Color deep,
  required Color rim,
  double lift = 2.4,
}) {
  final b = shape.getBounds();
  // The light comes from up and to the left: the edge is brightest at the
  // thing's top-left and has gone by its far foot.
  Paint fall(Color from) => Paint()
    ..shader = ui.Gradient.linear(
      b.topLeft,
      b.bottomRight,
      [from, Color.lerp(from, body, 0.7)!, body],
      const [0.0, 0.5, 1.0],
    );
  canvas.drawPath(shape, fall(rim));
  canvas.save();
  canvas.clipPath(shape);
  const steps = [0.3, 0.6];
  for (final s in steps) {
    canvas.drawPath(
      shape.shift(Offset(lift * s, lift * s * 0.9)),
      fall(Color.lerp(rim, body, 0.35 + s * 0.6)!),
    );
  }
  canvas.drawPath(
    shape.shift(Offset(lift, lift * 0.9)),
    Paint()
      ..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, [body, deep]),
  );
  canvas.restore();
}

/// Tiny lit grains drawn as short trailed strokes, gathered per colour and
/// alpha step so a frame's flames, ashes and offerings are a few
/// drawPoints calls. Callers draw from small fixed ramps, so the runs stay
/// few.
class _FuneralInk {
  static const double width = 1.6;
  final Map<int, List<Offset>> _runs = {};
  final Paint _paint = Paint()..strokeCap = StrokeCap.round;

  void add(Offset from, Offset to, Color c, double alpha) {
    final a = (alpha.clamp(0.0, 1.0) * 8).round();
    if (a == 0) return;
    final key = ((c.toARGB32() & 0xFFFFFF) << 4) | a;
    final run = _runs.putIfAbsent(key, () => <Offset>[]);
    // A trail too short to draw still leaves a grain.
    run
      ..add((to - from).distanceSquared < 0.09 ? to.translate(-0.3, 0) : from)
      ..add(to);
  }

  void paint(Canvas canvas, {double? width}) {
    _paint.strokeWidth = width ?? _FuneralInk.width;
    for (final e in _runs.entries) {
      if (e.value.isEmpty) continue;
      _paint.color = Color(
        0xFF000000 | (e.key >> 4),
      ).withValues(alpha: (e.key & 15) / 8);
      canvas.drawPoints(ui.PointMode.lines, e.value, _paint);
      e.value.clear();
    }
  }
}
