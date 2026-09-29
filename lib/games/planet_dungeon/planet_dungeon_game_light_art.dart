// lib/games/planet_dungeon/planet_dungeon_game_light_art.dart
//
// SOLARIN — THE SHADOW FLOOR, drawn. A sanctuary: ivory marble ledges,
// leaded glass over a lightwell of white-gold light, and shadow that falls
// across the glass and SETS — black stone, gold seams. Glass only on puzzle
// things (the lightwell's panes ARE the puzzle here), material never lines.
//
// COST. Every room's stone, glass, walls and furniture are baked once into a
// ui.Picture. Per frame: one glow per starlight, one filled wedge per caster
// per starlight, the squares that hold (cached until the floor changes), the
// starlights' rays, and whatever moment is playing. No blur anywhere.
//
// THE STARLIGHTS are shards of Solarin's star: a white core, a corona (the
// shared glow sprite) and filled tapered rays that turn slowly and twinkle.
// One that shines one way fans its long rays into its cone.

part of 'planet_dungeon_game.dart';

const GlassPalette _kLumenGlass = kLumenGlass;

/// Baked rooms, keyed on room id (and, for the key room, nothing else — its
/// live half is drawn over the bake).
final Map<String, ui.Picture> _shadowBakeCache = {};

/// Each grid room's glass, as one path (the light is laid on it alone).
final Map<String, Path> _glassPaths = {};

// The sanctuary's materials.
const Color _kIvory = Color(0xFFEDE5D2);
const Color _kIvoryAlt = Color(0xFFE2D8C1);
const Color _kIvoryJoint = Color(0xFFB39A62);
const Color _kGoldInlay = Color(0xFFC9A55A);
const Color _kGlassDeep = Color(0xFFFFF1CC);
const Color _kGlassHot = Color(0xFFFFFBEE);
const Color _kObsidian = Color(0xFF17141E);
const Color _kShade = Color(0xFF2A2536);
const Color _kStarGold = Color(0xFFFFE9A8);

GlassPalette _sanctuaryStone({
  required Color top,
  required Color face,
  required Color foot,
}) => GlassPalette(
  lead: kLumenGlass.lead,
  leadLight: kLumenGlass.leadLight,
  frost: kLumenGlass.frost,
  liveDeep: kLumenGlass.liveDeep,
  live: kLumenGlass.live,
  liveCore: kLumenGlass.liveCore,
  smoke: kLumenGlass.smoke,
  silver: kLumenGlass.silver,
  gold: kLumenGlass.gold,
  goldDeep: kLumenGlass.goldDeep,
  stoneTop: top,
  stoneFace: face,
  stoneFoot: foot,
  floor: _kIvory,
  floorAlt: _kIvoryAlt,
  joint: _kIvoryJoint,
);

final GlassPalette _kPaleStone = _sanctuaryStone(
  top: const Color(0xFFF4EEDF),
  face: const Color(0xFFCABFA4),
  foot: const Color(0xFF6E644E),
);
final GlassPalette _kWallStone = _sanctuaryStone(
  top: const Color(0xFFB7AB90),
  face: const Color(0xFF6E6552),
  foot: const Color(0xFF2A2620),
);
final GlassPalette _kBlankStone = _sanctuaryStone(
  top: const Color(0xFFEDE4CF),
  face: const Color(0xFFB9AD90),
  foot: const Color(0xFF5A5242),
);
final GlassPalette _kBrass = _sanctuaryStone(
  top: const Color(0xFFD9B46A),
  face: const Color(0xFF8A6A38),
  foot: const Color(0xFF3A2A14),
);

extension ShadowFloorArt on PlanetDungeonGame {
  void _updateLightGlass(double dt) {
    // ROOM II's starlight glides to the stud it was set on.
    final e = 1 - pow(0.002, dt).toDouble();
    archive.keyShowX += (archive.keyLampX - archive.keyShowX) * e;
    archive.keyShowY += (archive.keyLampY - archive.keyShowY) * e;
    // What holds is tracked on the game's clock, not the renderer's, so a
    // square's setting moment is when it came to hold.
    final room = currentRoom;
    final def = room.hall?.def;
    if (def != null) _heldNow(room, def, archive.state(def.id));
  }

  void _renderArchive(Canvas canvas, DungeonRoom room) {
    final bay = room.hall;
    if (bay == null) return;
    canvas.drawPicture(
      _shadowBakeCache.putIfAbsent(room.id, () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        switch (bay.kind) {
          case 'hall':
            _bakeHall(c, room);
          case 'key':
            _bakeKeyRoom(c, room);
          default:
            _bakeGrid(c, room, bay.def!);
        }
        return rec.endRecording();
      }),
    );
    switch (bay.kind) {
      case 'hall':
        _renderHallLive(canvas, room);
      case 'key':
        _renderKeyLive(canvas, room);
      default:
        _renderGridLive(canvas, room, bay.def!);
    }
    _renderGlassDoorPlugs(canvas, room);
  }

  // ═══════════════════════════ THE BAKE ═════════════════════════════════

  void _bakeShell(Canvas c, DungeonRoom room, {double face = 44}) {
    paintCarvedRoomShell(
      c,
      room.bounds,
      _kPaleStone,
      GlassRng(glassSeed(room.id, room.bounds)),
      doors: [
        for (final d in room.doors)
          if (_doorOnWall(room, d)) d.rect,
      ],
      faceDepth: face,
      arcade: false,
      flags: false,
    );
  }

  /// One ivory flag, with its own tint, a lit top edge and a gold joint.
  void _ivoryFlag(Canvas c, Rect r, int seed) {
    final t = ((sin(seed * 12.9898) * 43758.5453) % 1).abs();
    c.drawRect(r, Paint()..color = Color.lerp(_kIvory, _kIvoryAlt, t)!);
    c.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 2),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    final joint = Paint()..color = _kIvoryJoint.withValues(alpha: 0.28);
    c.drawRect(Rect.fromLTWH(r.left, r.bottom - 1, r.width, 1), joint);
    c.drawRect(Rect.fromLTWH(r.right - 1, r.top, 1, r.height), joint);
  }

  /// One pane of the lightwell: glass lit from below, in lead.
  /// One pane of the lightwell: glass lit from below, set in bronze. Amber
  /// at its edge and white-hot at its heart, each pane cut a little off
  /// square and a few of them stained, so the well reads as a window you are
  /// standing over and not a grid.
  void _wellPane(Canvas c, Rect r, int seed, {bool deep = false}) {
    final h = ((sin(seed * 78.233) * 43758.5453) % 1).abs();
    final edge = switch (seed % 7) {
      0 => const Color(0xFFF2C9A8), // a rose pane
      3 => const Color(0xFFE9D9A6),
      5 => const Color(0xFFD9E2D6), // a pale sea pane
      _ => deep ? const Color(0xFFF0C36E) : const Color(0xFFF2CE7E),
    };
    final heart = Offset(
      r.left + r.width * (.35 + .3 * h),
      r.top + r.height * (.35 + .3 * (1 - h)),
    );
    // Each pane is a quad with its corners nudged, so the leading bends.
    Offset j(Offset p, int k) {
      final t = ((sin((seed * 4 + k) * 12.9898) * 43758.5453) % 1) - .5;
      return p + Offset(t * 5, -t * 4);
    }

    final q = r.deflate(2);
    final pane = Path()
      ..moveTo(j(q.topLeft, 0).dx, j(q.topLeft, 0).dy)
      ..lineTo(j(q.topRight, 1).dx, j(q.topRight, 1).dy)
      ..lineTo(j(q.bottomRight, 2).dx, j(q.bottomRight, 2).dy)
      ..lineTo(j(q.bottomLeft, 3).dx, j(q.bottomLeft, 3).dy)
      ..close();
    c.drawRect(r, Paint()..color = const Color(0xFF6E5530));
    c.drawPath(
      pane,
      Paint()
        ..shader = ui.Gradient.radial(
          heart,
          r.width * .75,
          [_kGlassHot, Color.lerp(_kGlassDeep, edge, .35)!, edge],
          const [0, .45, 1],
        ),
    );
    if (seed % 4 == 0) paintStreak(c, r.deflate(r.width * .24), opacity: .3);
    paintLead(c, pane, _kLumenGlass, width: 1.8, opacity: .7);
  }

  void _bakeGrid(Canvas c, DungeonRoom room, ShadowRoomDef def) {
    final b = room.bounds;
    // The lightwell under everything: the room floats over it.
    c.drawRect(b, Paint()..color = const Color(0xFFFFF4D8));
    _bakeShell(c, room);
    for (var y = 0; y < def.rows; y++) {
      for (var x = 0; x < def.cols; x++) {
        final r = Rect.fromLTWH(
          x * kShadowCell,
          kShadowTop + y * kShadowCell,
          kShadowCell,
          kShadowCell,
        );
        final ch = def.at(x, y);
        final seed = x * 31 + y * 17 + room.id.length;
        switch (ch) {
          case '~':
            _wellPane(c, r, seed);
          case '#':
            // Dressed stone standing up out of the floor: its top, lit, and a
            // face dropping to a dark foot.
            paintCarvedBlock(
              c,
              Rect.fromLTRB(r.left, r.top - 10, r.right, r.bottom - 12),
              22,
              _kWallStone,
              radius: 1,
            );
          case 'B':
            // THE BLANK WALL: courses of dressed stone, and no door in it.
            paintCarvedBlock(
              c,
              Rect.fromLTRB(r.left, r.top - 10, r.right, r.bottom - 12),
              22,
              _kBlankStone,
              radius: 1,
            );
            c.drawRect(
              Rect.fromLTWH(r.left + 4, r.center.dy - 1, r.width - 8, 2),
              Paint()..color = const Color(0xFF6E644E).withValues(alpha: .3),
            );
          default:
            _ivoryFlag(c, r, seed);
        }
        switch (ch) {
          case 'G':
            // Gold stone: warm, and edged with a gilt band where the region
            // meets the rest of the room.
            c.drawRect(
              r,
              Paint()..color = const Color(0xFFE8C77A).withValues(alpha: .22),
            );
            final band = Paint()..color = _kGoldInlay.withValues(alpha: .7);
            bool g(int dx, int dy) =>
                def.inside(x + dx, y + dy) && def.at(x + dx, y + dy) == 'G';
            if (!g(-1, 0))
              c.drawRect(Rect.fromLTWH(r.left, r.top, 4, r.height), band);
            if (!g(1, 0))
              c.drawRect(Rect.fromLTWH(r.right - 4, r.top, 4, r.height), band);
            if (!g(0, -1))
              c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 4), band);
            if (!g(0, 1))
              c.drawRect(Rect.fromLTWH(r.left, r.bottom - 4, r.width, 4), band);
          case 'V':
            paintCarvedDisc(c, r.center, 22, 12, 4, _kBrass);
            final grate = Paint()..color = const Color(0xFF3A2A14);
            for (var k = -2; k <= 2; k++) {
              c.drawRect(
                Rect.fromCenter(
                  center: r.center + Offset(k * 7.0, 0),
                  width: 3,
                  height: 14,
                ),
                grate,
              );
            }
          case 'p':
            paintCarvedDisc(c, r.center, 20, 11, 6, _kBrass);
            c.drawOval(
              Rect.fromCenter(center: r.center, width: 26, height: 13),
              Paint()..color = const Color(0xFF1C140A),
            );
          case 'C':
            paintCarvedDisc(c, r.center, 18, 10, 6, _kBrass);
          case 'd':
            paintCarvedDisc(c, r.center, 28, 16, 5, _kPaleStone);
            c.drawCircle(
              r.center,
              9,
              Paint()..color = _kGoldInlay.withValues(alpha: .5),
            );
          case 'n':
            // The rail: a brass channel the starlight rides.
            c.drawRect(
              Rect.fromCenter(center: r.center, width: 16, height: r.height),
              Paint()..color = const Color(0xFF5A4424),
            );
            c.drawRect(
              Rect.fromCenter(center: r.center, width: 8, height: r.height),
              Paint()..color = const Color(0xFF2A1E10),
            );
            c.drawCircle(r.center, 6, Paint()..color = const Color(0xFFD2AB58));
        }
      }
    }
    // One gilt rosette at the heart of the gold stone.
    final gs = [
      for (var y = 0; y < def.rows; y++)
        for (var x = 0; x < def.cols; x++)
          if (def.at(x, y) == 'G') shadowCentre(x, y),
    ];
    if (gs.isNotEmpty) {
      final cc = gs.reduce((a, b) => a + b) / gs.length.toDouble();
      final gold = Paint()..color = _kGoldInlay.withValues(alpha: .8);
      for (var i = 0; i < 16; i++) {
        final a = i * pi / 8;
        final dir = Offset(cos(a), sin(a));
        final n = Offset(-dir.dy, dir.dx) * 4;
        final tip = cc + dir * (i.isEven ? 30.0 : 19.0);
        c.drawPath(
          Path()
            ..moveTo(cc.dx + n.dx, cc.dy + n.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(cc.dx - n.dx, cc.dy - n.dy)
            ..close(),
          gold,
        );
      }
      c.drawCircle(cc, 8, Paint()..color = const Color(0xFFF2DC9A));
    }
    // The stone things, carved.
    for (final f in def.fixedCasters) {
      final cc = shadowCentre(f.x, f.y);
      final rr = f.r * kShadowCell;
      switch (f.id[0]) {
        case 'P':
          paintCarvedDisc(
            c,
            cc + const Offset(0, 8),
            rr,
            rr * .55,
            8,
            _kWallStone,
          );
          paintCarvedDisc(
            c,
            cc - const Offset(0, 14),
            rr * .82,
            rr * .45,
            26,
            _kPaleStone,
          );
        case 'M':
          // THE MONOLITH: a door carved in the round, standing in front of
          // nothing. Its shadow is the only door this room will ever have.
          paintContactShadow(c, cc + const Offset(0, 16), 52, 18);
          final door = Path()
            ..moveTo(cc.dx - 18, cc.dy + 20)
            ..lineTo(cc.dx - 18, cc.dy - 12)
            ..quadraticBezierTo(cc.dx - 18, cc.dy - 34, cc.dx, cc.dy - 38)
            ..quadraticBezierTo(cc.dx + 18, cc.dy - 34, cc.dx + 18, cc.dy - 12)
            ..lineTo(cc.dx + 18, cc.dy + 20)
            ..close();
          c.drawPath(door, Paint()..color = const Color(0xFFD6CCB2));
          c.drawPath(
            Path()
              ..moveTo(cc.dx - 10, cc.dy + 20)
              ..lineTo(cc.dx - 10, cc.dy - 10)
              ..quadraticBezierTo(cc.dx - 10, cc.dy - 24, cc.dx, cc.dy - 27)
              ..quadraticBezierTo(
                cc.dx + 10,
                cc.dy - 24,
                cc.dx + 10,
                cc.dy - 10,
              )
              ..lineTo(cc.dx + 10, cc.dy + 20)
              ..close(),
            Paint()..color = const Color(0xFF8E846C),
          );
        case 'R':
          paintCarvedBlock(
            c,
            Rect.fromCenter(
              center: cc + const Offset(0, 4),
              width: 40,
              height: 24,
            ),
            12,
            _kPaleStone,
            radius: 3,
          );
      }
    }
  }

  void _bakeHall(Canvas c, DungeonRoom room) {
    final b = room.bounds;
    c.drawRect(b, Paint()..color = const Color(0xFFFFF0C8));
    _bakeShell(c, room);
    for (var y = 0; y < kHallRows; y++) {
      for (var x = 0; x < kHallCols; x++) {
        final r = Rect.fromLTWH(
          x * kShadowCell,
          kShadowTop + y * kShadowCell,
          kShadowCell,
          kShadowCell,
        );
        final ch = kHallMap[y][x];
        if (ch == '.') {
          _ivoryFlag(c, r, x * 13 + y * 7);
        } else {
          _wellPane(c, r, x * 5 + y, deep: true);
        }
      }
    }
    // The gilt band round the ledges' lip, where stone meets the well.
    final lip = Paint()..color = _kGoldInlay.withValues(alpha: .45);
    for (final x in const [3, 5, 8, 10]) {
      c.drawRect(
        Rect.fromLTWH(
          x * kShadowCell - 3,
          kShadowTop,
          6,
          kHallRows * kShadowCell,
        ),
        lip,
      );
    }
    // The star's stand, dark iron and brass.
    paintCarvedDisc(c, kHallKindle + const Offset(0, 14), 22, 12, 10, _kBrass);
  }

  void _bakeKeyRoom(Canvas c, DungeonRoom room) {
    _bakeShell(c, room, face: kKeyFace - 6);
    // The floor.
    for (var y = 0; y < 6; y++) {
      for (var x = 0; x < 10; x++) {
        _ivoryFlag(
          c,
          Rect.fromLTWH(x * kKeyU, kKeyFace + y * kKeyU, kKeyU, kKeyU),
          x * 11 + y * 29,
        );
      }
    }
    // The arch, carved into the north face: its frame, and the pale sill.
    final arch = _archPath();
    c.drawPath(
      arch.shift(const Offset(0, 4)),
      Paint()..color = const Color(0xFF6E644E).withValues(alpha: .5),
    );
    paintLead(
      c,
      arch,
      _kLumenGlass,
      width: 9,
      opacity: .35,
      light: const Color(0xFFF4EEDF),
    );
    // The rail of brass studs.
    for (final sy in kKeyStudY) {
      c.drawRect(
        Rect.fromLTRB(
          (kKeyStudX.first - .3) * kKeyU,
          keyFloor(0, sy).dy - 3,
          (kKeyStudX.last + .3) * kKeyU,
          keyFloor(0, sy).dy + 3,
        ),
        Paint()..color = const Color(0xFF8A6A38).withValues(alpha: .35),
      );
      for (final sx in kKeyStudX) {
        paintCarvedDisc(c, keyFloor(sx, sy), 7, 4, 2, _kBrass);
      }
    }
    // The plinth and its tiny key.
    final pk = keyFloor(kKeyX, kKeyY);
    paintCarvedBlock(
      c,
      Rect.fromCenter(center: pk + const Offset(0, -6), width: 40, height: 16),
      10,
      _kPaleStone,
      radius: 2,
    );
    final key = Paint()..color = const Color(0xFFC9A24E);
    c.drawCircle(pk + const Offset(-10, -8), 4, key);
    c.drawRect(Rect.fromLTWH(pk.dx - 7, pk.dy - 9.2, 20, 2.4), key);
    c.drawRect(Rect.fromLTWH(pk.dx + 9, pk.dy - 9.2, 2.5, 5), key);
  }

  // ═══════════════════════════ THE STARLIGHT ════════════════════════════

  /// A STARLIGHT: a shard of Solarin's star. [s] scales it; [big] is Solarin.
  void _drawStarlight(
    Canvas canvas,
    Offset at, {
    double s = 1,
    double? face,
    double half = 0,
    bool big = false,
    double bloom = 1,
  }) {
    final tw = 0.92 + 0.08 * sin(_time * 5.3 + at.dx * .01);
    final corona = (big ? 150.0 : 86.0) * s * bloom;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        corona,
        _kStarGold.withValues(alpha: .85),
      );
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        corona * .45,
        Colors.white.withValues(alpha: .9),
      );
    }
    final spin = _time * (big ? .22 : .38);
    // A starlight that shines one way fans many rays across its cone.
    final n = big ? 12 : (face != null ? 18 : 8);
    final ray = Paint();
    for (var i = 0; i < n; i++) {
      final a = spin + i / n * pi * 2;
      var long = i.isEven ? 1.0 : .55;
      if (face != null) {
        var d = a - face;
        d = atan2(sin(d), cos(d));
        long *= d.abs() <= half ? 1.5 : .35;
      }
      final len = (big ? 80.0 : 44.0) * long * s * tw * bloom;
      final w = (big ? 10.0 : 5.5) * s;
      final ca = cos(a), sa = sin(a);
      ray.color = const Color(
        0xFFFFF0C4,
      ).withValues(alpha: .8 * min(1.0, long));
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - sa * w, at.dy + ca * w)
          ..lineTo(at.dx + ca * len, at.dy + sa * len)
          ..lineTo(at.dx + sa * w, at.dy - ca * w)
          ..close(),
        ray,
      );
    }
    final core = (big ? 26.0 : 12.0) * s * bloom;
    canvas.drawCircle(
      at,
      core,
      Paint()
        ..shader = ui.Gradient.radial(
          at,
          core,
          [Colors.white, const Color(0xFFFFF4C8), const Color(0x00FFE08C)],
          const [0, .6, 1],
        ),
    );
  }

  // ═══════════════════════════ GRID ROOMS, LIVE ═════════════════════════

  /// Where each starlight is DRAWN (the railed one glides; Solarin swings).
  List<ShadowLamp> _drawnLamps(ShadowRoomDef def, ShadowState s) {
    final out = def.fixedLamps;
    if (def.rail != null) {
      final to = def.rail![s.rail];
      var x = to.x.toDouble(), y = to.y.toDouble();
      final t = ((_time - archive.railT) / .5).clamp(0.0, 1.0);
      if (archive.railFrom >= 0 && t < 1) {
        final e = t * t * (3 - 2 * t);
        final fr = def.rail![archive.railFrom.toInt()];
        x = fr.x + (to.x - fr.x) * e;
        y = fr.y + (to.y - fr.y) * e;
      }
      out.add(ShadowLamp(x, y, kind: 'rail'));
    }
    if (def.orbit != null) {
      final p = _solarinDrawn(def);
      out.add(
        ShadowLamp(
          p.dx / kShadowCell - .5,
          (p.dy - kShadowTop) / kShadowCell - .5,
          kind: 'solarin',
        ),
      );
    }
    return out;
  }

  /// Which glass holds for someone right now — derived once per change.
  Set<int> _heldNow(DungeonRoom room, ShadowRoomDef def, ShadowState s) {
    final key = '${room.id}|${s.encoded}';
    if (archive.heldKey == key) return archive.held;
    if (archive.heldRoom != room.id) {
      archive.heldSince.clear();
      archive.heldRoom = room.id;
    }
    final held = <int>{};
    for (var y = 0; y < def.rows; y++) {
      for (var x = 0; x < def.cols; x++) {
        if (!def.isGlass(x, y)) continue;
        if (shadowHolds(def, s, x, y, null)) held.add(sqKey(x, y));
      }
    }
    for (final k in held) {
      archive.heldSince.putIfAbsent(k, () => _time);
    }
    archive.heldSince.removeWhere((k, _) => !held.contains(k));
    archive
      ..heldKey = key
      ..held = held;
    return held;
  }

  /// The shadow a square wall throws from starlight [l]: from its two
  /// outermost corners, out to the room's edge.
  Path _squareShadow(ShadowLamp l, int x, int y) {
    final lx = l.x + .5, ly = l.y + .5;
    final cx = x + .5, cy = y + .5;
    final base = atan2(cy - ly, cx - lx);
    Offset w(double gx, double gy) =>
        Offset(gx * kShadowCell, kShadowTop + gy * kShadowCell);
    final corners = [
      (x.toDouble(), y.toDouble()),
      (x + 1.0, y.toDouble()),
      (x + 1.0, y + 1.0),
      (x.toDouble(), y + 1.0),
    ];
    double rel((double, double) c) {
      var a = atan2(c.$2 - ly, c.$1 - lx) - base;
      return atan2(sin(a), cos(a));
    }

    corners.sort((a, b) => rel(a).compareTo(rel(b)));
    final lo = corners.first, hi = corners.last;
    const far = 40.0;
    Offset out((double, double) c) {
      final dx = c.$1 - lx, dy = c.$2 - ly;
      final d = sqrt(dx * dx + dy * dy);
      return w(lx + dx / d * far, ly + dy / d * far);
    }

    final a = w(lo.$1, lo.$2), b = w(hi.$1, hi.$2);
    final fa = out(lo), fb = out(hi);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(fa.dx, fa.dy)
      ..lineTo(fb.dx, fb.dy)
      ..lineTo(b.dx, b.dy)
      ..close();
  }

  Path _wedge(ShadowLamp l, double cx, double cy, double r) {
    final lx = l.x + .5, ly = l.y + .5;
    final dx = cx - lx, dy = cy - ly, d = sqrt(dx * dx + dy * dy);
    final p = Path();
    if (d <= r) return p;
    final base = atan2(dy, dx), half = asin(r / d), tl = sqrt(d * d - r * r);
    const far = 40.0;
    Offset w(double gx, double gy) =>
        Offset(gx * kShadowCell, kShadowTop + gy * kShadowCell);
    final a0 = base - half, a1 = base + half;
    final n0 = w(lx + cos(a0) * tl, ly + sin(a0) * tl);
    final f0 = w(lx + cos(a0) * far, ly + sin(a0) * far);
    final f1 = w(lx + cos(a1) * far, ly + sin(a1) * far);
    final n1 = w(lx + cos(a1) * tl, ly + sin(a1) * tl);
    return p
      ..moveTo(n0.dx, n0.dy)
      ..lineTo(f0.dx, f0.dy)
      ..lineTo(f1.dx, f1.dy)
      ..lineTo(n1.dx, n1.dy)
      ..close();
  }

  void _renderGridLive(Canvas canvas, DungeonRoom room, ShadowRoomDef def) {
    final s = archive.state(def.id);
    final floor = Rect.fromLTWH(
      0,
      kShadowTop,
      def.cols * kShadowCell,
      def.rows * kShadowCell,
    );
    final lamps = _drawnLamps(def, s);

    canvas.save();
    canvas.clipRect(floor);
    // THE LIGHT ON THE WELL: each starlight's glow, cut to its cone and laid
    // on the GLASS only — the stone and the walls keep their own colour, so
    // the lightwell is the one bright thing in the room.
    final glass = _glassPaths.putIfAbsent(def.id, () {
      final p = Path();
      for (var y = 0; y < def.rows; y++) {
        for (var x = 0; x < def.cols; x++) {
          if (!def.isGlass(x, y)) continue;
          p.addRect(
            Rect.fromLTWH(
              x * kShadowCell,
              kShadowTop + y * kShadowCell,
              kShadowCell,
              kShadowCell,
            ),
          );
        }
      }
      return p;
    });
    for (final l in lamps) {
      final at =
          shadowCentre(0, 0) + Offset(l.x * kShadowCell, l.y * kShadowCell);
      canvas.save();
      canvas.clipPath(glass);
      if (l.face != null) {
        canvas.clipPath(
          Path()
            ..moveTo(at.dx, at.dy)
            ..arcTo(
              Rect.fromCircle(center: at, radius: 2000),
              l.face! - l.half,
              l.half * 2,
              false,
            )
            ..close(),
        );
      }
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          at,
          620,
          const Color(0xFFFFF0C0).withValues(alpha: .38),
        );
      }
      canvas.restore();
    }
    // Caustics drifting in the well.
    canvas.save();
    canvas.clipPath(glass);
    final caustic = Paint()..color = Colors.white.withValues(alpha: .16);
    for (var i = 0; i < 7; i++) {
      final x = ((i * 131 + _time * 22) % (floor.width + 120)) - 60;
      final y =
          floor.top + floor.height * (.12 + (i % 5) * .19) + sin(_time + i) * 9;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 70, height: 16),
        caustic,
      );
    }

    canvas.restore();

    // THE SHADOWS: bodies where they really are (so they sweep as you
    // walk), the veil, and the stone things.
    final casters = <(double, double, double)>[
      for (final n in kShadowNames)
        if (_shadowBody(n) case final c?)
          (
            c.position.dx / kShadowCell,
            (c.position.dy - kShadowTop) / kShadowCell,
            kShadowBodyR,
          ),
      if (s.veil != null) (s.veil!.x + .5, s.veil!.y + .5, kShadowVeilR),
      for (final f in def.fixedCasters) (f.cx, f.cy, f.r),
    ];
    final shade = Paint()
      ..color = _kShade.withValues(alpha: lamps.length > 1 ? .20 : .32);
    final eclipse = Paint()
      ..color = _kShade.withValues(alpha: lamps.length > 1 ? .26 : .40);
    for (final l in lamps) {
      canvas.save();
      if (l.face != null) {
        final at =
            shadowCentre(0, 0) + Offset(l.x * kShadowCell, l.y * kShadowCell);
        canvas.clipPath(
          Path()
            ..moveTo(at.dx, at.dy)
            ..arcTo(
              Rect.fromCircle(center: at, radius: 2000),
              l.face! - l.half,
              l.half * 2,
              false,
            )
            ..close(),
        );
      }
      for (final (cx, cy, r) in casters) {
        canvas.drawPath(_wedge(l, cx, cy, r), shade);
      }
      // THE ECLIPSE: a wall blocks a starlight outright, so it throws the
      // deepest shadow in the room — and walking the star walks it.
      for (var y = 0; y < def.rows; y++) {
        for (var x = 0; x < def.cols; x++) {
          if (def.at(x, y) != '#') continue;
          canvas.drawPath(_squareShadow(l, x, y), eclipse);
        }
      }
      canvas.restore();
    }

    // WHERE IT HOLDS, GLASS BECOMES STONE — square by square as it lands.
    final held = _heldNow(room, def, s);
    for (final k in held) {
      final q = sqOf(k);
      final r = Rect.fromLTWH(
        q.x * kShadowCell,
        kShadowTop + q.y * kShadowCell,
        kShadowCell,
        kShadowCell,
      );
      final pinned = s.pinned.contains(k);
      final since = archive.heldSince[k] ?? _time;
      final a = ((_time - since) / .22).clamp(0.0, 1.0);
      final inset = (1 - a) * 14 + 3;
      final tile = r.deflate(inset);
      if (!pinned) {
        // The glass under a shadow that holds turns to smoked stone: dark
        // at its heart, a cool sheen along its top.
        canvas.drawRRect(
          RRect.fromRectAndRadius(tile, const Radius.circular(3)),
          Paint()
            ..shader = ui.Gradient.linear(tile.topLeft, tile.bottomRight, [
              const Color(0xFF3E3950).withValues(alpha: .9 * a),
              const Color(0xFF221E2C).withValues(alpha: .9 * a),
            ]),
        );
        canvas.drawRect(
          Rect.fromLTWH(tile.left + 3, tile.top + 2, tile.width - 6, 2),
          Paint()..color = const Color(0xFF8A84A2).withValues(alpha: .45 * a),
        );
      }
    }
    // SOLARIN'S NEXT MOVE, shown: a faint gold outline wherever the floor
    // will be once it swings on — so placing someone ahead of it is a plan,
    // not a guess.
    if (def.orbit != null) {
      final next = s.copyWith(orbit: (s.orbit + 1) % def.orbit!.length);
      final key = '${def.id}|${next.encoded}';
      if (archive.nextHeldKey != key) {
        archive
          ..nextHeldKey = key
          ..nextHeld = {
            for (var y = 0; y < def.rows; y++)
              for (var x = 0; x < def.cols; x++)
                if (def.isGlass(x, y) && shadowHolds(def, next, x, y, null))
                  sqKey(x, y),
          };
      }
      final pulse = .5 + .5 * sin(_time * 2.4);
      final rim = Paint()
        ..color = const Color(0xFFF2D68A).withValues(alpha: .22 + .18 * pulse);
      for (final k in archive.nextHeld) {
        final q = sqOf(k);
        final r = Rect.fromLTWH(
          q.x * kShadowCell,
          kShadowTop + q.y * kShadowCell,
          kShadowCell,
          kShadowCell,
        ).deflate(9);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1.6), rim);
        canvas.drawRect(
          Rect.fromLTWH(r.left, r.bottom - 1.6, r.width, 1.6),
          rim,
        );
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, 1.6, r.height), rim);
        canvas.drawRect(
          Rect.fromLTWH(r.right - 1.6, r.top, 1.6, r.height),
          rim,
        );
      }
    }
    // WHAT A PIN WOULD SET: with Dark standing on a shadow it could pin, the
    // squares that would turn to stone glow a soft pulsing gold — so the verb
    // shows itself, and what it would do, before it is pressed.
    final a0 = active;
    if (a0 != null && _shadowName(a0) == 'Dark' && s.pins > 0) {
      final here = s.pos['Dark']!;
      if (def.isGlass(here.x, here.y) &&
          !s.pinned.contains(sqKey(here.x, here.y))) {
        final key = '${def.id}|${s.encoded}';
        if (archive.pinPreviewKey != key) {
          archive
            ..pinPreviewKey = key
            ..pinPreview = shadowPinCells(def, s) ?? const [];
        }
        final pulse = .5 + .5 * sin(_time * 3.2);
        final glow = Paint()
          ..color = const Color(
            0xFFE8C66A,
          ).withValues(alpha: .10 + .12 * pulse);
        final rim = Paint()
          ..color = const Color(0xFFE8C66A).withValues(alpha: .35 + .3 * pulse);
        for (final k in archive.pinPreview) {
          final q = sqOf(k);
          final r = Rect.fromLTWH(
            q.x * kShadowCell,
            kShadowTop + q.y * kShadowCell,
            kShadowCell,
            kShadowCell,
          ).deflate(4);
          canvas.drawRect(r, glow);
          canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 2), rim);
          canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 2, r.width, 2), rim);
          canvas.drawRect(Rect.fromLTWH(r.left, r.top, 2, r.height), rim);
          canvas.drawRect(Rect.fromLTWH(r.right - 2, r.top, 2, r.height), rim);
        }
      }
    }
    // PINNED: obsidian, and gold seams that draw themselves as it sets.
    for (final k in s.pinned) {
      final q = sqOf(k);
      if (!def.isGlass(q.x, q.y) && def.at(q.x, q.y) != 'B') continue;
      final r = Rect.fromLTWH(
        q.x * kShadowCell,
        kShadowTop + q.y * kShadowCell,
        kShadowCell,
        kShadowCell,
      );
      final t0 = archive.stoneRoom == def.id ? (archive.stoneSet[k] ?? -9) : -9;
      final a = ((_time - t0) / .45).clamp(0.0, 1.0);
      if (a <= 0) continue;
      final e = 1 - pow(1 - a, 3).toDouble();
      final tile = r.deflate(2 + (1 - e) * 12);
      canvas.drawRect(tile, Paint()..color = _kObsidian);
      canvas.drawRect(
        Rect.fromLTWH(tile.left, tile.top, tile.width, 3),
        Paint()..color = const Color(0xFF3A3448),
      );
      // Set in stone: a fine gold frame drawn round it as it sets, and a
      // gold heart.
      final seam = Paint()
        ..color = const Color(0xFFD2AB58).withValues(alpha: .9);
      final f = tile.deflate(3);
      final w = f.width * e;
      canvas.drawRect(Rect.fromLTWH(f.left, f.top, w, 1.8), seam);
      canvas.drawRect(Rect.fromLTWH(f.right - w, f.bottom - 1.8, w, 1.8), seam);
      canvas.drawRect(Rect.fromLTWH(f.left, f.bottom - w, 1.8, w), seam);
      canvas.drawRect(Rect.fromLTWH(f.right - 1.8, f.top, 1.8, w), seam);
      canvas.drawPath(
        Path()
          ..moveTo(r.center.dx, r.center.dy - 4 * e)
          ..lineTo(r.center.dx + 4 * e, r.center.dy)
          ..lineTo(r.center.dx, r.center.dy + 4 * e)
          ..lineTo(r.center.dx - 4 * e, r.center.dy)
          ..close(),
        seam,
      );
      if (def.at(q.x, q.y) == 'B') {
        // A doorway cut through the blank wall by a pinned shadow.
        canvas.drawRect(Rect.fromLTWH(r.left + 3, r.top, 3, r.height), seam);
        canvas.drawRect(Rect.fromLTWH(r.right - 6, r.top, 3, r.height), seam);
      }
      if (a < 1 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          r.center,
          46,
          const Color(0xFFFFE08C).withValues(alpha: .5 * (1 - a)),
        );
      }
    }
    // A SOLVED ROOM: the gold stones glow for the party that reached them.
    if (archive.solved.contains(def.id) && def.orbit == null && _fx.ready) {
      final t = ((_time - archive.solvedT) / 1.6).clamp(0.0, 1.0);
      for (var y = 0; y < def.rows; y++) {
        for (var x = 0; x < def.cols; x++) {
          if (def.at(x, y) != 'G') continue;
          drawGlow(
            canvas,
            _fx.glow!,
            shadowCentre(x, y),
            38,
            const Color(0xFFFFE08C).withValues(alpha: .30 * t),
          );
        }
      }
    }
    canvas.restore();

    // The crank, turning as it walks the starlight on.
    for (var y = 0; y < def.rows; y++) {
      for (var x = 0; x < def.cols; x++) {
        if (def.at(x, y) != 'C') continue;
        final c = shadowCentre(x, y) - const Offset(0, 6);
        final t = ((_time - archive.railT) / .5).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(t * pi * 2);
        canvas.drawRect(
          const Rect.fromLTWH(-3, -18, 6, 18),
          Paint()..color = const Color(0xFFD2AB58),
        );
        canvas.drawCircle(
          const Offset(0, -18),
          5,
          Paint()..color = const Color(0xFFF2DC9A),
        );
        canvas.restore();
      }
    }
    // The veil, hanging where it was breathed.
    if (s.veil != null) {
      final a = ((_time - archive.veilT) / 1).clamp(0.0, 1.0);
      _drawVeil(canvas, shadowCentre(s.veil!.x, s.veil!.y), a < .01 ? 1 : a);
    }
    // The starlights themselves (Solarin is its own, far larger).
    for (final l in lamps) {
      final at =
          shadowCentre(0, 0) + Offset(l.x * kShadowCell, l.y * kShadowCell);
      final big = l.kind == 'solarin';
      final flash = big
          ? (1 + (guardianHitFlash / .3).clamp(0.0, 1.0) * .4)
          : 1.0;
      _drawStarlight(
        canvas,
        at,
        face: l.face,
        half: l.half,
        big: big,
        bloom: flash,
      );
    }
    // SOLARIN: a ghost of it where it swings next, and its flare gathering
    // on whoever stands in its light.
    if (def.orbit != null) {
      final nx = def.orbit![(s.orbit + 1) % def.orbit!.length];
      final ghost = shadowCentre(nx.x, nx.y);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          ghost,
          70,
          const Color(
            0xFFFFE9A8,
          ).withValues(alpha: .22 + .1 * sin(_time * 2.4)),
        );
      }
      canvas.drawCircle(
        ghost,
        10,
        Paint()..color = Colors.white.withValues(alpha: .35),
      );
      final at = archive.flareAt;
      final body = at == null ? null : _shadowBody(at);
      if (body != null) {
        final from = _solarinDrawn(def);
        final t = ((_time - archive.flareT) / 1.1).clamp(0.0, 1.0);
        final dir = body.position - from;
        final len = dir.distance;
        if (len > 1) {
          final n = Offset(-dir.dy, dir.dx) / len;
          final w = 4 + 16 * t;
          canvas.drawPath(
            Path()
              ..moveTo(from.dx + n.dx * w, from.dy + n.dy * w)
              ..lineTo(body.position.dx, body.position.dy)
              ..lineTo(from.dx - n.dx * w, from.dy - n.dy * w)
              ..close(),
            Paint()
              ..color = const Color(
                0xFFFFF4D0,
              ).withValues(alpha: .15 + .45 * t),
          );
        }
        canvas.drawCircle(
          body.position,
          26 - 10 * t,
          Paint()
            ..color = const Color(0xFFFFE08C).withValues(alpha: .25 + .35 * t),
        );
      }
      final hit = 1 - ((_time - archive.flareHitT) / .5).clamp(0.0, 1.0);
      if (hit > 0 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          _solarinDrawn(def),
          260,
          Colors.white.withValues(alpha: .5 * hit),
        );
      }
    }
    // Anyone who just fell lands in a ring of light.
    for (final e in archive.fellT.entries) {
      final c = _shadowBody(e.key);
      if (c == null) continue;
      final f = 1 - ((_time - e.value) / .7).clamp(0.0, 1.0);
      if (f <= 0) continue;
      canvas.drawCircle(
        c.position,
        22 + 30 * (1 - f),
        Paint()..color = const Color(0xFFFFF6D6).withValues(alpha: .55 * f),
      );
    }
  }

  void _drawVeil(Canvas canvas, Offset at, double a) {
    if (!_fx.ready) return;
    for (var i = 0; i < 5; i++) {
      final t = _time * .6 + i * 1.3;
      drawPuff(
        canvas,
        _fx.puff!,
        at + Offset(sin(t) * 7, -8 - i * 6 + cos(t) * 3),
        (58 - i * 6) * a,
        Colors.white.withValues(alpha: .55 * a),
      );
    }
  }

  // ═══════════════════════════ THE HALL, LIVE ═══════════════════════════

  void _renderHallLive(Canvas canvas, DungeonRoom room) {
    // The wells breathe: light welling up from below, and motes rising.
    final wells = [
      Rect.fromLTWH(
        3 * kShadowCell,
        kShadowTop,
        2 * kShadowCell,
        kHallRows * kShadowCell,
      ),
      Rect.fromLTWH(
        8 * kShadowCell,
        kShadowTop,
        2 * kShadowCell,
        kHallRows * kShadowCell,
      ),
    ];
    for (final w in wells) {
      canvas.save();
      canvas.clipRect(w);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          w.center + Offset(0, sin(_time * .7) * 30),
          260,
          Colors.white.withValues(alpha: .35),
        );
      }
      final mote = Paint()..color = Colors.white.withValues(alpha: .6);
      for (var i = 0; i < 9; i++) {
        final y = w.bottom - ((i * 57 + _time * 26) % w.height);
        final x = w.left + ((i * 37) % w.width) + sin(_time + i) * 6;
        canvas.drawCircle(Offset(x, y), i.isEven ? 1.6 : 1.1, mote);
      }
      canvas.restore();
    }
    // THE SPANS: shadow-stone set across the well, one per solved room.
    for (final e in kHallSpans.entries) {
      final t0 = archive.spanSet[e.key];
      if (t0 == null) continue;
      final t = ((_time - t0) / 1.2).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final e3 = 1 - pow(1 - t, 3).toDouble();
      final r = Rect.fromLTWH(
        e.value.x * kShadowCell,
        kShadowTop + e.value.y * kShadowCell,
        kShadowCell,
        kShadowCell,
      );
      // The shadow falls on the well, then sets.
      canvas.drawRect(
        r.inflate(18 * (1 - e3)),
        Paint()..color = _kShade.withValues(alpha: .45 * (1 - e3)),
      );
      canvas.drawRect(
        r.deflate(1),
        Paint()..color = _kObsidian.withValues(alpha: e3),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: r.center,
          width: (r.width - 10) * e3,
          height: 3,
        ),
        Paint()..color = const Color(0xFFD2AB58),
      );
      if (t < 1 && _fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          r.center,
          70,
          const Color(0xFFFFE08C).withValues(alpha: .6 * (1 - t)),
        );
      }
    }
    // THE GOLD SUN, inlaid in the far well where nobody would stand.
    {
      final c = shadowCentre(kHallSun.x, kHallSun.y);
      final found = discoveredClouds.contains(kLightEggId);
      final gold = Paint()
        ..color = const Color(0xFFC9A24E).withValues(alpha: found ? .95 : .55);
      for (var i = 0; i < 12; i++) {
        final a = i * pi / 6 + _time * .08;
        final len = i.isOdd ? 20.0 : 28.0;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + cos(a + .2) * 11, c.dy + sin(a + .2) * 11)
            ..lineTo(c.dx + cos(a) * len, c.dy + sin(a) * len)
            ..lineTo(c.dx + cos(a - .2) * 11, c.dy + sin(a - .2) * 11)
            ..close(),
          gold,
        );
      }
      canvas.drawCircle(c, 12, gold);
    }
    // THE HALL'S STAR on its stand: dark, until Light wakes it.
    final top = kHallKindle - const Offset(0, 22);
    if (entryDoorRevealed) {
      final t = ((_time - archive.keyT) / 1.2).clamp(0.0, 1.0);
      final bloom = archive.keyT < 0
          ? 1.0
          : .4 + .6 * (1 - pow(1 - t, 3).toDouble());
      _drawStarlight(canvas, top, s: 1.1, bloom: bloom);
    } else {
      canvas.drawCircle(top, 10, Paint()..color = const Color(0xFF6E644E));
      canvas.drawCircle(top, 5, Paint()..color = const Color(0xFF3A3448));
    }
  }

  // ═══════════════════════════ ROOM II, LIVE ════════════════════════════

  Offset _arch(double x, double z) =>
      Offset(x * kKeyU, kKeyFace - 8 - z * (kKeyFace - 20) / 2.6);

  Path _archPath() {
    final l = _arch(kArchL, 0), r = _arch(kArchR, 0);
    final sl = _arch(kArchL, kArchSpring), sr = _arch(kArchR, kArchSpring);
    final apex = _arch((kArchL + kArchR) / 2, kArchApex + .12);
    return Path()
      ..moveTo(l.dx, l.dy)
      ..lineTo(sl.dx, sl.dy)
      ..quadraticBezierTo(sl.dx, _arch(0, kArchApex).dy, apex.dx, apex.dy)
      ..quadraticBezierTo(sr.dx, _arch(0, kArchApex).dy, sr.dx, sr.dy)
      ..lineTo(r.dx, r.dy)
      ..close();
  }

  /// The key cut-out projected onto the arch from a starlight at (lx, ly).
  Path _keyShadow(double lx, double ly, {double grow = 1}) {
    final p = Path();
    Offset at(double x, double z) {
      final gx = kKeyX + (x - kKeyX) * grow, gz = kKeyZ + (z - kKeyZ) * grow;
      final (sx, sz) = keyProject(lx, ly, gx, gz);
      return _arch(sx, sz);
    }

    void ring(double cx, double cz, double r) {
      for (var i = 0; i <= 24; i++) {
        final a = i / 24 * pi * 2;
        final q = at(cx + cos(a) * r, cz + sin(a) * r);
        if (i == 0) {
          p.moveTo(q.dx, q.dy);
        } else {
          p.lineTo(q.dx, q.dy);
        }
      }
      p.close();
    }

    void rect(double x0, double z0, double x1, double z1) {
      final a = at(x0, z0), b = at(x1, z0), c = at(x1, z1), d = at(x0, z1);
      p
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close();
    }

    ring(kKeyX - .16, kKeyZ, .1);
    ring(kKeyX - .16, kKeyZ, .045);
    rect(kKeyX - .07, kKeyZ - .025, kKeyX + .25, kKeyZ + .025);
    rect(kKeyX + .14, kKeyZ - .1, kKeyX + .18, kKeyZ - .025);
    rect(kKeyX + .2, kKeyZ - .08, kKeyX + .25, kKeyZ - .025);
    return p..fillType = PathFillType.evenOdd;
  }

  void _renderKeyLive(Canvas canvas, DungeonRoom room) {
    final solved = archive.solved.contains('key_room');
    final arch = _archPath();
    final lx = archive.keyShowX, ly = archive.keyShowY;
    canvas.save();
    canvas.clipPath(arch);
    // The opening is pure light.
    final b = arch.getBounds();
    canvas.drawRect(
      b,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          _kGlassHot,
          const Color(0xFFFFE9AD),
        ]),
    );
    final shaft = Paint()..color = Colors.white.withValues(alpha: .35);
    for (var i = 0; i < 5; i++) {
      final x = b.left + ((i * 57 + _time * 22) % (b.width + 40)) - 20;
      canvas.drawRect(Rect.fromLTWH(x, b.top, 6, b.height), shaft);
    }
    // The keyhole: leaded gold glass, set in the light.
    final hole = _keyShadow(kKeyAnswerX, kKeyAnswerY, grow: 1.08);
    canvas.drawPath(hole, Paint()..color = _kGoldInlay.withValues(alpha: .22));
    paintLead(canvas, hole, _kLumenGlass, width: 3, opacity: .8);
    // The veil: something for a shadow to land on.
    final veil = archive.keyVeil
        ? (archive.veilT < 0
              ? 1.0
              : ((_time - archive.veilT) / 1.1).clamp(0.0, 1.0))
        : 0.0;
    if (veil > 0) {
      if (_fx.ready) {
        for (var i = 0; i < 8; i++) {
          final t = _time * .25 + i * 1.7;
          drawPuff(
            canvas,
            _fx.puff!,
            Offset(
              b.left + ((i * 41 + sin(t) * 14) % b.width),
              b.top + b.height * (.2 + (i % 4) * .2) + cos(t) * 4,
            ),
            170,
            Colors.white.withValues(alpha: .62 * veil),
          );
        }
      }
      canvas.drawRect(
        b,
        Paint()..color = const Color(0xFFE2E8EE).withValues(alpha: .5 * veil),
      );
      final keyT = archive.keyT;
      if (archive.keyPinned) {
        // Set in stone, and turning in the lock.
        final t = ((_time - keyT) / 1.1).clamp(0.0, 1.0);
        final e = 1 - pow(1 - t, 3).toDouble();
        final (bx, bz) = keyProject(
          kKeyAnswerX,
          kKeyAnswerY,
          kKeyX - .16,
          kKeyZ,
        );
        final bow = _arch(bx, bz);
        canvas.save();
        canvas.translate(bow.dx, bow.dy);
        canvas.rotate(-e * pi / 2);
        canvas.translate(-bow.dx, -bow.dy);
        final kp = _keyShadow(kKeyAnswerX, kKeyAnswerY);
        canvas.drawPath(kp, Paint()..color = _kObsidian);
        paintLead(
          canvas,
          kp,
          _kLumenGlass,
          width: 2.4,
          opacity: 1,
          light: const Color(0xFFD2AB58),
        );
        canvas.restore();
      } else {
        final shake = keyT < 0 && _time + keyT < .5
            ? sin(_time * 60) * 6 * (.5 - (_time + keyT))
            : 0.0;
        canvas.save();
        canvas.translate(shake, 0);
        canvas.drawPath(
          _keyShadow(lx, ly),
          Paint()
            ..color = const Color(0xFF1C1824).withValues(alpha: .72 * veil),
        );
        canvas.restore();
      }
    }
    if (solved) {
      final t = ((_time - archive.solvedT) / 1.4).clamp(0.0, 1.0);
      canvas.drawRect(
        b,
        Paint()
          ..color = const Color(
            0xFFFFFCEE,
          ).withValues(alpha: .9 * (archive.solvedT < 0 ? 1 : t)),
      );
    }
    canvas.restore();
    // The light from the arch pooling on the floor.
    final pool = Rect.fromLTWH(
      (kArchL - .5) * kKeyU,
      kKeyFace,
      (kArchR - kArchL + 1) * kKeyU,
      2 * kKeyU,
    );
    canvas.drawRect(
      pool,
      Paint()
        ..shader = ui.Gradient.linear(pool.topCenter, pool.bottomCenter, [
          const Color(0xFFFFF0C4).withValues(alpha: .55),
          const Color(0x00FFF0C4),
        ]),
    );
    // The key's shadow on the floor, running from the plinth to the wall.
    if (!solved) {
      final a = keyFloor(kKeyX - .25, kKeyY), c = keyFloor(kKeyX + .25, kKeyY);
      double wall(double x) {
        final m = keyMagnify(ly);
        return (lx + (x - lx) * m) * kKeyU;
      }

      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(wall(kKeyX - .25), kKeyFace)
          ..lineTo(wall(kKeyX + .25), kKeyFace)
          ..lineTo(c.dx, c.dy)
          ..close(),
        Paint()..color = _kShade.withValues(alpha: .34),
      );
    }
    _drawStarlight(canvas, keyFloor(lx, ly), s: .9);
  }
}
