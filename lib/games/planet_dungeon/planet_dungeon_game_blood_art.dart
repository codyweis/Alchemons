// lib/games/planet_dungeon/planet_dungeon_game_blood_art.dart
//
// HEMAVORN — THE BLOOD RITES, drawn (docs/dungeons.md §7.11, glass inlay).
// Carved porphyry — dark, garnet-veined — for every room's stone; glass only
// on the things the puzzles are made of: the Circle's cups and seal, the
// Water room's basin, the Air room's bell. The captives are the real
// creatures, held by bands of blood until their room frees them.
//
// COST. Each room's stone is baked once into a picture. Per frame: what
// moves (tendrils, plates, ice, water, flames, the twin, the rings and the
// streams) and whatever moment is playing. Material, never hairlines; no
// blur anywhere (the game's known jank source).
//
// WHAT STOPS YOU READS AS SOLID (2026-10-06, the author: "so many times I'm
// walking and can't tell something is blocking my path"). The first pass
// gave wall tops the floor's own colour, so a lone wall square in a room
// was a faint seam. Walls now stand up out of a darker floor: a lighter
// porphyry top, a lit arris and a dark face toward the viewer, their shadow
// thrown on the floor in front; a wall with wall in front runs on unbroken.
// The stones on the Earth plates are boulders that stand upright as the
// plate turns, and Blood pressing into anything shows it (_riteDrawBump).

part of 'planet_dungeon_game.dart';

/// Porphyry: tops a dark garnet lighter than any floor, lit at the arris.
const GlassPalette _kRiteWall = GlassPalette(
  lead: Color(0xFF0A0406),
  leadLight: Color(0xFFF0C8C8),
  frost: [
    Color(0xFF2E1A1E),
    Color(0xFF341E22),
    Color(0xFF2A161A),
    Color(0xFF3A2026),
    Color(0xFF301A1E),
  ],
  liveDeep: Color(0xFF6A0E20),
  live: Color(0xFFD8334E),
  liveCore: Color(0xFFFFE4E8),
  smoke: Color(0xFF120A0C),
  silver: Color(0xFFE8DCDC),
  gold: Color(0xFFD4A656),
  goldDeep: Color(0xFF6B4E26),
  stoneTop: Color(0xFF44282E),
  stoneFace: Color(0xFF1E0E12),
  stoneFoot: Color(0xFF070203),
  floor: Color(0xFF1E1517),
  floorAlt: Color(0xFF1A1214),
  joint: Color(0xFF070304),
);

/// How tall a wall stands (world units): its top is drawn this far up, and
/// this much of its face shows below it.
const double _kRiteWallH = 16;

const Color _kRiteBlood = Color(0xFFC8283C);
const Color _kRiteBloodDeep = Color(0xFF5A0F1A);
const Color _kRiteBloodHot = Color(0xFFFF8A94);
const Color _kRiteGold = Color(0xFFD4A656);
const Color _kRiteBronze = Color(0xFF7B5A2A);

const Map<String, Color> _kRitePair = {
  'a': Color(0xFFD0283C),
  'b': Color(0xFF9B2F73),
  'c': Color(0xFFE2623A),
  'd': Color(0xFFD4B072),
  'w': Color(0xFF4F9BD8),
};

final Map<String, ui.Picture> _riteBakeCache = {};

/// The Water room's next-flip ghost, by the state it was worked out from.
final Map<String, FlipState> _riteGhostCache = {};

double _riteHash(int n) {
  final s = sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

double _riteEase(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

extension BloodRitesArt on PlanetDungeonGame {
  // ═══════════════════════════ THE BAKE ═════════════════════════════════

  ui.Picture _riteBake(String key, void Function(Canvas c) paint) =>
      _riteBakeCache.putIfAbsent(key, () {
        final rec = ui.PictureRecorder();
        paint(Canvas(rec));
        return rec.endRecording();
      });

  void _riteFlag(Canvas c, Rect r, int seed) {
    final t = _riteHash(seed);
    c.drawRect(
      r,
      Paint()..color = Color.lerp(_kRiteWall.floor, _kRiteWall.floorAlt, t)!,
    );
    c.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 1.5),
      Paint()..color = Colors.white.withValues(alpha: 0.045),
    );
    final joint = Paint()..color = _kRiteWall.joint.withValues(alpha: 0.7);
    c.drawRect(Rect.fromLTWH(r.left, r.bottom - 1, r.width, 1), joint);
    c.drawRect(Rect.fromLTWH(r.right - 1, r.top, 1, r.height), joint);
    // A thread of garnet in some stones.
    if (seed % 4 == 0) {
      c.drawRect(
        Rect.fromLTWH(
          r.left + r.width * .18,
          r.top + r.height * (.3 + .4 * t),
          r.width * .64,
          1.2,
        ),
        Paint()..color = _kRiteBlood.withValues(alpha: .07),
      );
    }
  }

  /// A wall square [r] from three-quarters, drawn after every floor square
  /// round it. [front]/[left]/[right]/[back]: is that neighbour open floor
  /// (its edge shows), and does the floor in front take its shadow
  /// ([shadow]; not past the room's edge)?
  void _riteWallCell(
    Canvas c,
    Rect r,
    int seed, {
    bool front = true,
    bool back = false,
    bool left = false,
    bool right = false,
    bool shadow = true,
  }) {
    const h = _kRiteWallH;
    final top = r.shift(const Offset(0, -h));
    if (front) {
      if (shadow) {
        // Its shadow on the floor in front.
        c.drawRect(
          Rect.fromLTWH(r.left - 2, r.bottom, r.width + 4, 20),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, r.bottom),
              Offset(0, r.bottom + 20),
              [
                Colors.black.withValues(alpha: .55),
                Colors.black.withValues(alpha: 0),
              ],
            ),
        );
      }
      // The face: dark, darkest at its foot.
      final face = Rect.fromLTRB(r.left, top.bottom, r.right, r.bottom);
      c.drawRect(
        face,
        Paint()
          ..shader = ui.Gradient.linear(face.topCenter, face.bottomCenter, [
            _kRiteWall.stoneFace,
            _kRiteWall.stoneFoot,
          ]),
      );
      // Courses in the face.
      final j = 10 + 30 * _riteHash(seed + 5);
      c.drawRect(
        Rect.fromLTWH(r.left + j, face.top + 3, 1.6, face.height - 4),
        Paint()..color = Colors.black.withValues(alpha: .5),
      );
    }
    if (right) {
      // A little shadow thrown to the right, on the floor beside it.
      c.drawRect(
        Rect.fromLTWH(r.right, top.top + 6, 9, r.height),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(r.right, 0),
            Offset(r.right + 9, 0),
            [
              Colors.black.withValues(alpha: .35),
              Colors.black.withValues(alpha: 0),
            ],
          ),
      );
    }
    // The top: porphyry, lighter toward the light, with garnet in it. Each
    // block a shade apart from the next, and the joints between them cut,
    // so a run of wall reads as laid stone.
    final v = _riteHash(seed * 3 + 1);
    final stone = Color.lerp(
      _kRiteWall.stoneTop,
      v < .5 ? Colors.black : const Color(0xFFB07A80),
      (v - .5).abs() * .22,
    )!;
    c.drawRect(
      top,
      Paint()
        ..shader = ui.Gradient.linear(
          top.topLeft,
          top.bottomRight,
          [
            Color.lerp(stone, const Color(0xFFB07A80), .12)!,
            stone,
            Color.lerp(stone, Colors.black, .2)!,
          ],
          const [0, .55, 1],
        ),
    );
    final cut = Paint()..color = Colors.black.withValues(alpha: .38);
    if (!left)
      c.drawRect(Rect.fromLTWH(top.left, top.top, 1.2, top.height), cut);
    if (!back) {
      c.drawRect(Rect.fromLTWH(top.left, top.top, top.width, 1.2), cut);
    }
    for (var k = 0; k < 4; k++) {
      final fx = _riteHash(seed * 7 + k * 3), fy = _riteHash(seed * 5 + k * 11);
      c.drawRect(
        Rect.fromLTWH(
          top.left + 6 + fx * (top.width - 14),
          top.top + 6 + fy * (top.height - 14),
          k.isEven ? 3 : 2,
          k.isEven ? 2 : 3,
        ),
        Paint()
          ..color = (k == 0 ? _kRiteBlood : const Color(0xFFD8B0B4)).withValues(
            alpha: k == 0 ? .22 : .07,
          ),
      );
    }
    // Its edges: lit where it faces the light and the viewer, dark behind.
    final lit = Paint()
      ..color = Color.lerp(
        _kRiteWall.stoneTop,
        const Color(0xFFF2CFC8),
        .45,
      )!.withValues(alpha: .85);
    if (front) {
      c.drawRect(
        Rect.fromLTWH(top.left, top.bottom - 2.2, top.width, 2.2),
        lit,
      );
    }
    if (left)
      c.drawRect(Rect.fromLTWH(top.left, top.top, 1.8, top.height), lit);
    final dark = Paint()..color = Colors.black.withValues(alpha: .45);
    if (back)
      c.drawRect(Rect.fromLTWH(top.left, top.top, top.width, 1.6), dark);
    if (right) {
      c.drawRect(
        Rect.fromLTWH(top.right - 1.8, top.top, 1.8, top.height),
        dark,
      );
    }
  }

  /// A grid room's stone: every floor square, then every wall square row by
  /// row (so a wall's top covers the face of the wall behind it).
  /// [floor] draws one open square (a flag, unless it says otherwise).
  void _riteBakeGrid(
    Canvas c,
    int w,
    int h,
    bool Function(int x, int y) wall,
    void Function(Canvas c, int x, int y, Rect r) floor,
  ) {
    bool solid(int x, int y) =>
        x < 0 || y < 0 || x >= w || y >= h || wall(x, y);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!wall(x, y)) floor(c, x, y, _riteSq(x, y));
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!wall(x, y)) continue;
        _riteWallCell(
          c,
          _riteSq(x, y),
          x * 31 + y * 17,
          front: y == h - 1 || !solid(x, y + 1),
          shadow: y < h - 1,
          back: y > 0 && !solid(x, y - 1),
          left: x > 0 && !solid(x - 1, y),
          right: x < w - 1 && !solid(x + 1, y),
        );
      }
    }
  }

  /// The old single-square call (the Circle and the vault lay their stone
  /// on a plain 64 grid): a wall square with its face showing.
  void _riteWall(Canvas c, Rect r, int x) => _riteWallCell(c, r, x * 13 + 7);

  Rect _riteSq(int x, int y) =>
      Rect.fromLTWH(x * kRiteCell, y * kRiteCell, kRiteCell, kRiteCell);

  // ═══════════════════════════ DISPATCH ═════════════════════════════════

  void _renderRites(Canvas canvas, DungeonRoom room) {
    final bay = room.rite;
    if (bay == null) return;
    switch (bay.kind) {
      case RiteKind.circle:
        _riteDrawCircle(canvas);
      case RiteKind.earth:
        _riteDrawEarth(canvas);
      case RiteKind.water:
        _riteDrawWater(canvas);
      case RiteKind.fire:
        _riteDrawFire(canvas);
      case RiteKind.air:
        _riteDrawAir(canvas);
      case RiteKind.vault:
        _riteDrawVault(canvas, room);
      case RiteKind.heart:
        _heartDraw(canvas);
      case RiteKind.arena:
        _riteDrawShell(canvas);
    }
    _riteDrawBump(canvas);
    // The moments, over the room: loose grains, then a release in play.
    rites.grains.paint(canvas, rites.batch);
    rites.release?.paint(canvas, rites.batch, _time);
  }

  /// Blood pressed into something it can't enter: a pool of pale light on
  /// the near face of what is there, gone in half a second (the grit it
  /// knocked off is a grain in the room's field).
  void _riteDrawBump(Canvas canvas) {
    final from = rites.bumpFrom;
    if (from == null || currentRoom.rite?.isGrid != true) return;
    final since = _time - rites.bumpT;
    if (since < 0 || since > .55) return;
    final k = 1 - since / .55;
    final a = k * k;
    final n = Offset(
      kRiteDx[rites.bumpDir].toDouble(),
      kRiteDy[rites.bumpDir].toDouble(),
    );
    final edge = riteCentreOf(from.x, from.y) + n * (kRiteCell / 2);
    final c = edge + n * 12;
    canvas.drawCircle(
      c,
      44,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          44,
          [
            const Color(0xFFF6DCD6).withValues(alpha: .34 * a),
            const Color(0xFFF6DCD6).withValues(alpha: .1 * a),
            const Color(0x00F6DCD6),
          ],
          const [0, .45, 1],
        ),
    );
    // The face it met, lit along the edge it was pressed at.
    final along = Offset(-n.dy, n.dx);
    final p = Path()
      ..moveTo(edge.dx - along.dx * 28, edge.dy - along.dy * 28)
      ..lineTo(edge.dx + along.dx * 28, edge.dy + along.dy * 28)
      ..lineTo(
        edge.dx + along.dx * 20 + n.dx * 7,
        edge.dy + along.dy * 20 + n.dy * 7,
      )
      ..lineTo(
        edge.dx - along.dx * 20 + n.dx * 7,
        edge.dy - along.dy * 20 + n.dy * 7,
      )
      ..close();
    canvas.drawPath(
      p,
      Paint()..color = const Color(0xFFF6DCD6).withValues(alpha: .28 * a),
    );
  }

  // ═══════════════════════════ THE CAPTIVE ══════════════════════════════

  /// A captive at [at]: its real body, dimmed and held by bands of blood.
  /// While its release plays, the bands let go and the body is drawn only
  /// below the crest (above it, it is grains — the release paints those).
  /// Freed before, it is gone.
  void _riteDrawCaptive(Canvas canvas, Offset at, String el) {
    final rel = rites.releaseEl == el ? rites.release : null;
    final wasFreed = discoveredClouds.contains(riteFreedId(el)) || hasStar(0);
    if (rel == null && wasFreed) return;
    final ally = rites.allies.where((c) => c.member.element == el).firstOrNull;
    final col = elementColor(el);
    final cut = rel?.cut ?? 0;
    final bands = rel?.bandsK ?? 0;
    // Its own light, going as it goes.
    final glow = (1 - cut) * (.26 + .06 * sin(_time * 1.8));
    if (glow > .01) {
      canvas.drawCircle(
        at,
        30,
        Paint()
          ..shader = ui.Gradient.radial(at, 30, [
            col.withValues(alpha: glow),
            col.withValues(alpha: 0),
          ]),
      );
    }
    if (cut < 1) {
      canvas.save();
      if (rel != null && !rel.spriteWhole) {
        // The crest runs top to bottom: the sprite is left below it.
        const half = kRiteSnapBox / 2;
        canvas.clipRect(
          Rect.fromLTRB(
            at.dx - half,
            at.dy + rel.crestLocal,
            at.dx + half,
            at.dy + half,
          ),
        );
      }
      final ticker = ally?.ticker;
      if (ticker != null) {
        canvas.translate(at.dx, at.dy);
        canvas.scale(
          ally!.spriteScale * kRiteCaptiveScale,
          ally.spriteScale * kRiteCaptiveScale,
        );
        ticker.getSprite().render(
          canvas,
          anchor: Anchor.center,
          overridePaint: Paint()
            ..filterQuality = ui.FilterQuality.high
            ..color = Colors.white.withValues(alpha: rel == null ? .78 : .95),
        );
      } else {
        canvas.drawCircle(at, 15, Paint()..color = col.withValues(alpha: .7));
      }
      canvas.restore();
    }
    // The bands of blood that hold it: they swell, thin and let go.
    if (bands < 1) {
      final sw = 1 + .05 * sin(_time * 1.8) + bands * .6;
      final a = 1 - bands;
      for (final k in const [-1.0, 1.0]) {
        final cx = at.dx + k * (6 + bands * 10);
        final path = Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(cx, at.dy + 2),
              width: 10 * sw,
              height: 40 * sw,
            ),
          )
          ..addOval(
            Rect.fromCenter(
              center: Offset(cx + k * 2, at.dy + 2),
              width: 6 * sw + bands * 4,
              height: 34 * sw + bands * 6,
            ),
          )
          ..fillType = PathFillType.evenOdd;
        canvas.drawPath(
          path,
          Paint()..color = _kRiteBlood.withValues(alpha: .85 * a),
        );
      }
    }
  }

  // ═══════════════════════════ THE CIRCLE ═══════════════════════════════

  void _riteDrawCircle(Canvas canvas) {
    canvas.drawPicture(_riteBake('circle', _riteBakeCircle));
    const c = kRiteCircleCentre;
    final freed = riteFreed;
    // The rings: carved annuli, turned; their grooves cut clean through.
    _riteRing(canvas, kRiteOuterBand, kRiteOuterGrooves, rites.outerAng);
    _riteRing(canvas, kRiteInnerBand, kRiteInnerGrooves, rites.innerAng);
    // The streams.
    for (final el in kRiteElements) {
      if (!freed.contains(el)) continue;
      final dir = riteDoorDir(el);
      final door = c + dir * (kRiteCircleRadius + 10);
      final cup = c + dir * kRiteCupRadius;
      // A newly freed stream arrives: it runs down its channel first.
      final since = _time - (rites.cupT[el] ?? -99);
      final run = _riteEase(since / .9);
      if (run > .01)
        _riteStream(canvas, door, Offset.lerp(door, cup, run)!, el);
      if (riteStreamToCentre(el, rites.outerTurn, rites.innerTurn)) {
        _riteStream(canvas, cup, c + dir * (kRiteSealRadius + 4), el);
      }
    }
    // The cups: glass bowls in bronze, filled with that element's blood.
    for (final el in kRiteElements) {
      final p = c + riteDoorDir(el) * kRiteCupRadius;
      paintCarvedDisc(canvas, p, 24, 16, 6, _kRiteWall);
      final full = rites.cups.contains(el);
      final bowl = Rect.fromCenter(center: p, width: 36, height: 22);
      canvas.drawOval(bowl, Paint()..color = const Color(0xFF120709));
      // It fills once its stream has reached it.
      final lvl = full
          ? _riteEase((_time - (rites.cupT[el] ?? -99) - .7) / 1.0)
          : 0.0;
      if (lvl > .01) {
        canvas.drawOval(
          Rect.fromCenter(
            center: p,
            width: (bowl.width - 6) * lvl,
            height: (bowl.height - 6) * lvl,
          ),
          Paint()
            ..shader = ui.Gradient.radial(
              p - const Offset(4, 3),
              18,
              [_kRiteBloodHot, _kRiteBlood, _kRiteBloodDeep],
              const [0, .35, 1],
            ),
        );
        canvas.drawCircle(
          p,
          4 * lvl,
          Paint()..color = elementColor(el).withValues(alpha: .9),
        );
      }
      paintLead(canvas, Path()..addOval(bowl), _kRiteWall, width: 2.4);
    }
    // The seal in the middle, the planet's heart beating under it.
    final open = _riteSealOpen;
    final beat = riteBeat;
    vfxSpill(canvas, c, 70 + 14 * beat, _kRiteBlood, .05 + .13 * beat);
    _riteSeal(canvas, c, open);
    // The maxim found, the seal opens: the quintessence the four made is
    // drawn down into it, the four streams' grains turning in on the middle
    // as its leaves draw back.
    final ss = rites.sealT >= 0 ? _time - rites.sealT : -1.0;
    if (ss >= 0 && ss < 3.6) {
      for (var e = 0; e < kRiteElements.length; e++) {
        final col = elementColor(kRiteElements[e]);
        for (var i = 0; i < 70; i++) {
          final u = ((ss - i * .025) / 2.4).clamp(0.0, 1.0);
          if (u <= 0 || u >= 1) continue;
          final h = _riteHash(e * 97 + i);
          final ang = e * pi / 2 + u * 5.2 + h * .6;
          final rr = (1 - u * u) * (78 + 18 * h);
          final p = c + Offset(cos(ang) * rr, sin(ang) * rr * .82);
          final q = c + Offset(cos(ang - .08) * rr * 1.03, sin(ang - .08) * rr * 1.03 * .82);
          rites.batch.add(q.dx, q.dy, p.dx, p.dy, col, alpha: (1 - u) * .95, width: i % 4 == 0 ? 2.6 : 2);
        }
      }
      rites.batch.paint(canvas);
    }
    // What pools in the middle.
    final mid = riteCentre(freed, rites.outerTurn, rites.innerTurn);
    final since = _time - rites.centreT;
    if (mid.kind == RiteCentreKind.fusion && mid.result != null) {
      final col = elementColor(mid.result!);
      final k = _riteEase(since / .8);
      canvas.drawCircle(
        c,
        52 * k,
        Paint()
          ..shader = ui.Gradient.radial(c, 52, [
            col.withValues(alpha: .55),
            col.withValues(alpha: 0),
          ]),
      );
      for (var i = 0; i < 36; i++) {
        final a = _time * (1.1 + (i % 5) * .12) + i * 2.4;
        final r = (8 + (i % 7) * 6.0) * k;
        canvas.drawRect(
          Rect.fromCenter(
            center: c + Offset(cos(a) * r, sin(a) * r),
            width: 2.6,
            height: 2.6,
          ),
          Paint()..color = col.withValues(alpha: .8),
        );
      }
    }
    if (mid.kind == RiteCentreKind.quintessence ||
        discoveredClouds.contains(kBloodEggId)) {
      final live = mid.kind == RiteCentreKind.quintessence;
      final k = live ? _riteEase(since / 1.6) : .35;
      canvas.drawCircle(
        c,
        90 * k,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            90,
            [
              const Color(0xFFFFF4D8).withValues(alpha: .6 * k),
              _kRiteGold.withValues(alpha: .22 * k),
              _kRiteGold.withValues(alpha: 0),
            ],
            const [0, .4, 1],
          ),
      );
      for (var i = 0; i < 80; i++) {
        final a = i * 2.39996 + _time * .4;
        final r = 46 * sqrt((i + 1) / 80) * k;
        canvas.drawRect(
          Rect.fromCenter(
            center: c + Offset(cos(a) * r, sin(a) * r),
            width: 2,
            height: 2,
          ),
          Paint()
            ..color = (i % 3 == 0 ? const Color(0xFFFFF4D8) : _kRiteGold)
                .withValues(alpha: .85 * k),
        );
      }
    }
  }

  void _riteBakeCircle(Canvas c) {
    const ctr = kRiteCircleCentre;
    // Stone all round, the floor a disc of flags.
    c.drawRect(
      const Rect.fromLTWH(0, 0, kRiteCircleSize, kRiteCircleSize),
      Paint()..color = _kRiteWall.stoneFoot,
    );
    // Solid stone everywhere outside the floor (under the rim's edge too),
    // except the four ways in, which are floor out to the doors.
    bool way(Rect r) =>
        (r.center.dx - ctr.dx).abs() < 60 || (r.center.dy - ctr.dy).abs() < 60;
    bool stone(Rect r) => (r.center - ctr).distance > kRiteCircleRadius - 46;
    for (var y = 0; y < kRiteCircleSize; y += 64) {
      for (var x = 0; x < kRiteCircleSize; x += 64) {
        final r = Rect.fromLTWH(x.toDouble(), y.toDouble(), 64, 64);
        if (stone(r) && way(r)) _riteFlag(c, r, x ~/ 64 * 7 + y ~/ 64 * 3);
      }
    }
    for (var y = 0; y < kRiteCircleSize; y += 64) {
      for (var x = 0; x < kRiteCircleSize; x += 64) {
        final r = Rect.fromLTWH(x.toDouble(), y.toDouble(), 64, 64);
        if (stone(r) && !way(r)) _riteWall(c, r, x ~/ 64 + y ~/ 64 * 5);
      }
    }
    c.save();
    c.clipPath(
      Path()..addOval(Rect.fromCircle(center: ctr, radius: kRiteCircleRadius)),
    );
    for (var y = 0; y < kRiteCircleSize; y += 64) {
      for (var x = 0; x < kRiteCircleSize; x += 64) {
        _riteFlag(
          c,
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 64, 64),
          x ~/ 64 * 31 + y ~/ 64 * 17,
        );
      }
    }
    c.restore();
    // The rim: a band of carved stone with a lit edge.
    c.drawCircle(
      ctr,
      kRiteCircleRadius + 14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..color = _kRiteWall.stoneTop,
    );
    c.drawCircle(
      ctr,
      kRiteCircleRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kRiteGold.withValues(alpha: .28),
    );
    // Each door's mouth through the rim, and the channel cut to its cup.
    for (final el in kRiteElements) {
      final d = riteDoorDir(el);
      final mouth = ctr + d * (kRiteCircleRadius + 14);
      final along = d.dx == 0;
      c.drawRect(
        Rect.fromCenter(
          center: mouth,
          width: along ? 92 : 44,
          height: along ? 44 : 92,
        ),
        Paint()..color = Color.lerp(_kRiteWall.floor, Colors.black, .2)!,
      );
      final a = ctr + d * (kRiteCircleRadius + 30);
      final b = ctr + d * kRiteCupRadius;
      c.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF0E0608),
      );
      // The element's sign at the threshold, inlaid in brass.
      final sign = ctr + d * (kRiteCircleRadius - 26);
      _riteElementSign(c, sign, el, _kRiteBronze.withValues(alpha: .7));
    }
  }

  /// The classical sign of an element: Fire △, Water ▽, Air △ with a bar,
  /// Earth ▽ with a bar — filled triangles with their bars cut out.
  void _riteElementSign(Canvas c, Offset p, String el, Color col) {
    final up = el == 'Fire' || el == 'Air';
    const s = 11.0;
    final tri = Path()
      ..moveTo(p.dx, p.dy + (up ? -s : s))
      ..lineTo(p.dx + s, p.dy + (up ? s * .7 : -s * .7))
      ..lineTo(p.dx - s, p.dy + (up ? s * .7 : -s * .7))
      ..close();
    final inner = Path()
      ..moveTo(p.dx, p.dy + (up ? -s * .45 : s * .45))
      ..lineTo(p.dx + s * .5, p.dy + (up ? s * .42 : -s * .42))
      ..lineTo(p.dx - s * .5, p.dy + (up ? s * .42 : -s * .42))
      ..close();
    final ring = Path.combine(PathOperation.difference, tri, inner);
    c.drawPath(ring, Paint()..color = col);
    if (el == 'Air' || el == 'Earth') {
      c.drawRect(
        Rect.fromCenter(center: p, width: s * 2.2, height: 2.4),
        Paint()..color = col,
      );
    }
  }

  void _riteRing(
    Canvas canvas,
    (double, double) band,
    List<int> grooves,
    double ang,
  ) {
    const c = kRiteCircleCentre;
    final (r1, r2) = band;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(ang);
    final ann = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r2))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r1))
      ..fillType = PathFillType.evenOdd;
    // A drop shadow under the ring, then the ring's own carved top.
    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(ann, Paint()..color = Colors.black.withValues(alpha: .45));
    canvas.restore();
    canvas.drawPath(
      ann,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r2,
          [
            _kRiteWall.stoneTop,
            Color.lerp(_kRiteWall.stoneTop, Colors.white, .06)!,
            _kRiteWall.stoneFace,
          ],
          [r1 / r2, (r1 + r2) / 2 / r2, 1],
        ),
    );
    // Sector joints.
    final joint = Paint()..color = Colors.black.withValues(alpha: .5);
    for (var s = 0; s < 8; s++) {
      canvas.save();
      canvas.rotate((s + .5) * pi / 4 - pi / 2);
      canvas.drawRect(Rect.fromLTWH(r1, -.6, r2 - r1, 1.2), joint);
      canvas.restore();
    }
    // Grooves: dark slots, with a lit lip on one side.
    for (final s in grooves) {
      canvas.save();
      canvas.rotate(s * pi / 4 - pi / 2);
      canvas.drawRect(
        Rect.fromLTWH(r1 - 1, -9, r2 - r1 + 2, 18),
        Paint()..color = const Color(0xFF0B0507),
      );
      canvas.drawRect(
        Rect.fromLTWH(r1 - 1, -9, r2 - r1 + 2, 1.6),
        Paint()..color = _kRiteGold.withValues(alpha: .22),
      );
      canvas.restore();
    }
    canvas.drawCircle(
      Offset.zero,
      r2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _kRiteGold.withValues(alpha: .25),
    );
    canvas.restore();
  }

  /// A running stream of blood: a dark bed, the flow, and grains riding it.
  void _riteStream(Canvas canvas, Offset a, Offset b, String el) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..color = _kRiteBloodDeep,
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(a, b, [
          _kRiteBlood,
          _kRiteBloodHot.withValues(alpha: .9),
        ]),
    );
    final len = (b - a).distance;
    final col = Color.lerp(elementColor(el), Colors.white, .3)!;
    for (var k = 0.0; k < len; k += 22) {
      final t = ((_time * 46 + k) % len) / len;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.lerp(a, b, t)!, width: 3, height: 3),
        Paint()..color = col.withValues(alpha: .8),
      );
    }
  }

  void _riteSeal(Canvas canvas, Offset c, bool open) {
    // How far the seal has opened: six leaves of stone that turn and draw
    // back into the rim, uncovering the dark — and the blood — below.
    final k = !open
        ? 0.0
        : rites.sealT == -99
        ? 1.0
        : rites.sealT < 0
        ? 0.0
        // It waits for the last cup to finish filling.
        : _riteEase((_time - rites.sealT - 1.6) / 1.8);
    paintCarvedDisc(
      canvas,
      c,
      kRiteSealRadius,
      kRiteSealRadius * .9,
      8,
      _kRiteWall,
    );
    const ir = kRiteSealRadius - 10;
    canvas.drawCircle(c, ir, Paint()..color = const Color(0xFF050203));
    if (k > 0) {
      canvas.drawCircle(
        c,
        ir,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            ir,
            [
              _kRiteBlood.withValues(alpha: (.18 + .08 * sin(_time * 2)) * k),
              _kRiteBloodDeep.withValues(alpha: .5 * k),
              Colors.black.withValues(alpha: 0),
            ],
            const [0, .6, 1],
          ),
      );
    }
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: ir)));
    for (var i = 0; i < 6; i++) {
      final a0 = i * pi / 3 + k * .9;
      final out = k * ir * .95;
      final dir = Offset(cos(a0 + pi / 6), sin(a0 + pi / 6));
      final o = c + dir * out;
      final leaf = Path()
        ..moveTo(o.dx, o.dy)
        ..lineTo(o.dx + cos(a0) * ir * 1.15, o.dy + sin(a0) * ir * 1.15)
        ..lineTo(
          o.dx + cos(a0 + pi / 3) * ir * 1.15,
          o.dy + sin(a0 + pi / 3) * ir * 1.15,
        )
        ..close();
      canvas.drawPath(
        leaf,
        Paint()
          ..shader = ui.Gradient.linear(o, o + dir * ir, [
            const Color(0xFF241517),
            const Color(0xFF130A0C),
          ]),
      );
      // A lit edge where one leaf meets the next.
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy)
          ..lineTo(o.dx + cos(a0) * ir * 1.15, o.dy + sin(a0) * ir * 1.15)
          ..lineTo(
            o.dx + cos(a0) * ir * 1.15 + 1.6,
            o.dy + sin(a0) * ir * 1.15 + 1.6,
          )
          ..lineTo(o.dx + 1.6, o.dy + 1.6)
          ..close(),
        Paint()..color = _kRiteGold.withValues(alpha: .18),
      );
    }
    canvas.restore();
    // The seal's sign: four brass bars, each lit while its cup is full; they
    // draw back with the leaves.
    for (var i = 0; i < 4; i++) {
      final el = kRiteElements[i];
      final d = riteDoorDir(el);
      final lit = rites.cups.contains(el);
      final p = c + d * (26 + k * 30);
      canvas.drawRect(
        Rect.fromCenter(
          center: p,
          width: d.dx == 0 ? 34 * (1 - .5 * k) : 6,
          height: d.dx == 0 ? 6 : 34 * (1 - .5 * k),
        ),
        Paint()
          ..color =
              (lit
                      ? Color.lerp(_kRiteGold, elementColor(el), .35)!
                      : _kRiteBronze.withValues(alpha: .55))
                  .withValues(alpha: 1 - .6 * k),
      );
    }
  }

  // ═══════════════════════════ EARTH ════════════════════════════════════

  void _riteDrawEarth(Canvas canvas) {
    final f = rites.earthFloor;
    canvas.drawPicture(
      _riteBake(
        'earth',
        (c) => _riteBakeGrid(
          c,
          f.w,
          f.h,
          (x, y) => f.plateOf(x, y) < 0 && f.base[y][x] != '.',
          (c, x, y, r) => _riteFlag(c, r, x * 31 + y * 17),
        ),
      ),
    );
    // Wall roots: bulbs pushing out of the stone.
    for (var y = 0; y < f.h; y++) {
      for (var x = 0; x < f.w; x++) {
        final ch = f.base[y][x];
        if (!TendrilFloor.isRoot(ch) || f.plateOf(x, y) >= 0) continue;
        final inward = Offset(
          x == 0
              ? 18
              : x == f.w - 1
              ? -18
              : 0,
          y == 0
              ? 18
              : y == f.h - 1
              ? -18
              : 0,
        );
        _riteRoot(canvas, riteCentreOf(x, y) + inward, ch);
      }
    }
    // The plates: each disc turns; what stands on it is carried round but
    // stays upright (a boulder's face is always toward you).
    final upright = <(double, VoidCallback)>[];
    for (var i = 0; i < f.plates.length; i++) {
      final p = f.plates[i];
      final cc = riteCentreOf(p.cx, p.cy);
      final ang = rites.plateAng[i];
      _ritePlate(canvas, cc, ang);
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final ch = f.base[p.cy + dy][p.cx + dx];
          final ox = dx * kRiteCell, oy = dy * kRiteCell;
          final at =
              cc +
              Offset(
                ox * cos(ang) - oy * sin(ang),
                ox * sin(ang) + oy * cos(ang),
              );
          final seed = (p.cx + dx) * 31 + (p.cy + dy) * 17;
          if (ch == 'X') {
            upright.add((at.dy, () => _riteBoulder(canvas, at, seed)));
          } else if (TendrilFloor.isRoot(ch)) {
            upright.add((at.dy - 1, () => _riteRoot(canvas, at, ch)));
          } else if (ch == 'C') {
            upright.add((at.dy - 2, () => _riteHearth(canvas, at)));
          }
        }
      }
    }
    // The tendrils.
    final g = f.grid(rites.earth.turns);
    final jobs = f.jobs(g);
    for (final e in rites.earth.lines.entries) {
      final job = jobs.where((j) => j.id == e.key).firstOrNull;
      final lead = rites.leading == e.key;
      _riteTendril(
        canvas,
        e.key,
        e.value,
        job != null && tendrilJoined(job, e.value),
        // The tendril you lead reaches for you, wherever you are mid-step.
        tip: lead ? active?.position : null,
      );
    }
    // Upright things, back to front, over the tendrils that reach them.
    upright.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in upright) {
      draw();
    }
    // The hub of each plate, on top.
    for (var i = 0; i < f.plates.length; i++) {
      final p = f.plates[i];
      final cc = riteCentreOf(p.cx, p.cy);
      final locked = tendrilLineOnPlate(f, rites.earth, i);
      paintCarvedDisc(canvas, cc, 20, 18, 7, _kRiteWall);
      canvas.drawCircle(
        cc,
        14,
        Paint()
          ..shader = ui.Gradient.radial(cc - const Offset(4, 4), 16, [
            locked ? const Color(0xFF6D6058) : const Color(0xFFE1C07A),
            locked ? const Color(0xFF2E2724) : const Color(0xFF7B5A26),
          ]),
      );
      canvas.save();
      canvas.translate(cc.dx, cc.dy);
      canvas.rotate(rites.plateAng[i]);
      canvas.drawRect(
        const Rect.fromLTWH(-2.5, -13, 5, 10),
        Paint()..color = const Color(0xFF1A1112),
      );
      canvas.restore();
    }
    // The captive in its hearth (carried round with the plate), and the
    // hearth's two glass sockets over it: one for each element tendril,
    // each lit once its tendril has come home.
    final cpos = _riteEarthCaptiveShown(_riteCaptiveAt('Earth'));
    _riteDrawCaptive(canvas, cpos, 'Earth');
    bool home(String id) => jobs
        .where((j) => j.id == id)
        .any((j) => tendrilJoined(j, rites.earth.lines[id]));
    _riteSocket(
      canvas,
      cpos + const Offset(-19, 26),
      _kRitePair['d']!,
      home('d'),
    );
    _riteSocket(
      canvas,
      cpos + const Offset(19, 26),
      _kRitePair['w']!,
      home('w'),
    );
  }

  /// A turning plate's disc, at [ang]: a slab of floor cut round, sunk in a
  /// groove, with joints that turn with it.
  void _ritePlate(Canvas canvas, Offset cc, double ang) {
    const rr = kRiteCell * 1.52;
    // The groove it turns in.
    canvas.drawCircle(cc, rr + 3, Paint()..color = const Color(0xFF080304));
    canvas.save();
    canvas.translate(cc.dx, cc.dy);
    canvas.rotate(ang);
    canvas.drawCircle(
      Offset.zero,
      rr,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(-20, -20), rr * 1.4, [
          const Color(0xFF34252A),
          const Color(0xFF241A1D),
        ]),
    );
    // Joints across it, so its turn is seen.
    final joint = Paint()..color = Colors.black.withValues(alpha: .45);
    for (final o in const [-kRiteCell / 2, kRiteCell / 2]) {
      canvas.drawRect(Rect.fromLTWH(o - .8, -rr + 10, 1.6, rr * 2 - 20), joint);
      canvas.drawRect(Rect.fromLTWH(-rr + 10, o - .8, rr * 2 - 20, 1.6), joint);
    }
    // A worn lip round its edge, lit on the side toward the light.
    final lip = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: rr))
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: rr - 5))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      lip,
      Paint()
        ..shader = ui.Gradient.linear(Offset(-rr, -rr), Offset(rr, rr), [
          const Color(0xFF6E4A4E).withValues(alpha: .7),
          const Color(0xFF120A0C).withValues(alpha: .8),
        ]),
    );
    canvas.restore();
  }

  /// A boulder standing on a plate: a rounded block of porphyry, upright,
  /// lighter than the floor, its shadow under it.
  void _riteBoulder(Canvas canvas, Offset at, int seed) {
    paintContactShadow(canvas, at + const Offset(0, 16), 60, 22, opacity: .6);
    final top = Rect.fromCenter(
      center: at - const Offset(0, 9),
      width: 50 + 4 * _riteHash(seed),
      height: 36,
    );
    final face = RRect.fromRectAndRadius(
      Rect.fromLTRB(top.left, top.center.dy, top.right, top.bottom + 15),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      face,
      Paint()
        ..shader = ui.Gradient.linear(
          face.outerRect.topCenter,
          face.outerRect.bottomCenter,
          [_kRiteWall.stoneFace, _kRiteWall.stoneFoot],
        ),
    );
    final t = RRect.fromRectAndRadius(top, const Radius.circular(13));
    canvas.drawRRect(
      t,
      Paint()
        ..shader = ui.Gradient.linear(
          top.topLeft,
          top.bottomRight,
          [
            Color.lerp(_kRiteWall.stoneTop, const Color(0xFFB07A80), .2)!,
            _kRiteWall.stoneTop,
            Color.lerp(_kRiteWall.stoneTop, Colors.black, .2)!,
          ],
          const [0, .5, 1],
        ),
    );
    // The lit near edge, a crescent along its front.
    canvas.drawPath(
      Path()
        ..moveTo(top.left + 6, top.bottom - 5)
        ..quadraticBezierTo(
          top.center.dx,
          top.bottom + 1,
          top.right - 6,
          top.bottom - 5,
        )
        ..quadraticBezierTo(
          top.center.dx,
          top.bottom - 2,
          top.left + 6,
          top.bottom - 5,
        )
        ..close(),
      Paint()..color = const Color(0xFFE8C0BC).withValues(alpha: .5),
    );
    // A vein of garnet.
    canvas.drawRect(
      Rect.fromLTWH(
        top.left + 12,
        top.top + 10 + 10 * _riteHash(seed + 3),
        18,
        2,
      ),
      Paint()..color = _kRiteBlood.withValues(alpha: .25),
    );
  }

  /// The captive's hearth: a carved disc with a dark bowl.
  void _riteHearth(Canvas canvas, Offset at) {
    paintCarvedDisc(canvas, at + const Offset(0, 6), 30, 22, 7, _kRiteWall);
    canvas.drawOval(
      Rect.fromCenter(center: at + const Offset(0, 6), width: 44, height: 28),
      Paint()..color = const Color(0xFF0D0708),
    );
  }

  /// One of the hearth's glass sockets: dim glass in an element's colour,
  /// full of light once that element's tendril is home.
  void _riteSocket(Canvas canvas, Offset at, Color col, bool lit) {
    final gem = Path()
      ..moveTo(at.dx, at.dy - 11)
      ..lineTo(at.dx + 8, at.dy)
      ..lineTo(at.dx, at.dy + 11)
      ..lineTo(at.dx - 8, at.dy)
      ..close();
    if (lit) {
      canvas.drawCircle(
        at,
        16,
        Paint()
          ..shader = ui.Gradient.radial(at, 16, [
            col.withValues(alpha: .55),
            col.withValues(alpha: 0),
          ]),
      );
    }
    canvas.drawPath(
      gem,
      Paint()
        ..shader = ui.Gradient.linear(
          at - const Offset(5, 7),
          at + const Offset(5, 7),
          [
            Color.lerp(
              col,
              Colors.white,
              lit ? .55 : .1,
            )!.withValues(alpha: lit ? 1 : .55),
            Color.lerp(
              col,
              Colors.black,
              lit ? .1 : .55,
            )!.withValues(alpha: lit ? 1 : .7),
          ],
        ),
    );
    paintLead(canvas, gem, _kRiteWall, width: 1.6);
  }

  /// The captive drawn where the plate's eased angle has it now.
  Offset _riteEarthCaptiveShown(Offset settled) {
    final f = rites.earthFloor;
    for (var y = 0; y < f.h; y++) {
      for (var x = 0; x < f.w; x++) {
        if (f.base[y][x] != 'C') continue;
        final i = f.plateOf(x, y);
        if (i < 0) return settled;
        final p = f.plates[i];
        final a = rites.plateAng[i];
        final dx = (x - p.cx) * kRiteCell, dy = (y - p.cy) * kRiteCell;
        return riteCentreOf(p.cx, p.cy) +
            Offset(dx * cos(a) - dy * sin(a), dx * sin(a) + dy * cos(a));
      }
    }
    return settled;
  }

  void _riteRoot(Canvas canvas, Offset at, String id) {
    final col = _kRitePair[id] ?? _kRiteBlood;
    final pulse = 1 + .05 * sin(_time * 3 + id.codeUnitAt(0));
    final lead = rites.leading == id;
    final element = id == 'd' || id == 'w';
    if (lead || element) {
      // The element roots glow in their own colour: they are not a pair.
      final gr = element ? 30.0 : 34.0;
      canvas.drawCircle(
        at,
        gr,
        Paint()
          ..shader = ui.Gradient.radial(at, gr, [
            col.withValues(alpha: lead ? .4 : .22 + .06 * sin(_time * 2)),
            col.withValues(alpha: 0),
          ]),
      );
    }
    final r = (element ? 21.0 : 19.0) * pulse;
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          at - const Offset(6, 6),
          r + 2,
          [
            Color.lerp(col, Colors.white, .35)!,
            col,
            Color.lerp(col, Colors.black, .5)!,
          ],
          const [0, .55, 1],
        ),
    );
    // Its mark, so pairs read without colour too: one to three pips; the
    // element roots carry their element (Dust a heap of grains, Water ▽).
    final n = switch (id) {
      'a' => 1,
      'b' => 2,
      'c' => 3,
      _ => 0,
    };
    for (var k = 0; k < n; k++) {
      canvas.drawCircle(
        at + Offset((k - (n - 1) / 2) * 7, 0),
        2.4,
        Paint()..color = Colors.black.withValues(alpha: .55),
      );
    }
    if (id == 'w') {
      _riteElementSign(canvas, at, 'Water', Colors.black.withValues(alpha: .5));
    } else if (id == 'd') {
      final ink = Paint()..color = Colors.black.withValues(alpha: .5);
      for (final o in const [
        Offset(0, -6),
        Offset(-5, -1),
        Offset(5, -1),
        Offset(-9, 5),
        Offset(-1, 5),
        Offset(7, 5),
      ]) {
        canvas.drawRect(
          Rect.fromCenter(center: at + o, width: 3.4, height: 3.4),
          ink,
        );
      }
    }
  }

  void _riteTendril(
    Canvas canvas,
    String id,
    List<RiteCell> pts,
    bool done, {
    Offset? tip,
  }) {
    if (pts.length < 2) return;
    final f = rites.earthFloor;
    final col = _kRitePair[id] ?? _kRiteBlood;
    Offset at(RiteCell c, int k) {
      if (k == 0) {
        final x = c.x, y = c.y;
        final edge = x == 0 || y == 0 || x == f.w - 1 || y == f.h - 1;
        if (edge) {
          return riteCentreOf(x, y) +
              Offset(
                x == 0
                    ? 18
                    : x == f.w - 1
                    ? -18
                    : 0,
                y == 0
                    ? 18
                    : y == f.h - 1
                    ? -18
                    : 0,
              );
        }
      }
      return riteCentreOf(c.x, c.y);
    }

    final path = Path()..moveTo(at(pts[0], 0).dx, at(pts[0], 0).dy);
    for (var k = 1; k < pts.length; k++) {
      final p = at(pts[k], k);
      path.lineTo(p.dx, p.dy);
    }
    if (tip != null) path.lineTo(tip.dx, tip.dy);
    Paint tube(double w, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, tube(26, Colors.black.withValues(alpha: .35)));
    canvas.restore();
    canvas.drawPath(path, tube(26, Color.lerp(col, Colors.black, .6)!));
    canvas.drawPath(
      path,
      tube(19, done ? col : Color.lerp(col, Colors.black, .18)!),
    );
    canvas.save();
    canvas.translate(-2.5, -3);
    canvas.drawPath(
      path,
      tube(
        5,
        Color.lerp(col, Colors.white, .5)!.withValues(alpha: done ? .55 : .32),
      ),
    );
    canvas.restore();
    // Led: a living head at the tip, swelling as it reaches.
    if (tip != null) {
      final sw = 1 + .08 * sin(_time * 6);
      canvas.drawCircle(
        tip,
        15 * sw,
        Paint()..color = Color.lerp(col, Colors.black, .55)!,
      );
      canvas.drawCircle(
        tip,
        12 * sw,
        Paint()
          ..shader = ui.Gradient.radial(tip - const Offset(4, 4), 14, [
            Color.lerp(col, Colors.white, .45)!,
            col,
          ]),
      );
    }
    // Joined: a bead of blood runs along it, home.
    if (done) {
      final n = pts.length - 1;
      final t = (_time * 1.4) % (n + 2) - 1;
      if (t >= 0 && t <= n) {
        final i = min(n - 1, t.floor());
        final p = Offset.lerp(at(pts[i], i), at(pts[i + 1], i + 1), t - i)!;
        canvas.drawCircle(
          p,
          18,
          Paint()
            ..shader = ui.Gradient.radial(p, 18, [
              Color.lerp(col, Colors.white, .5)!.withValues(alpha: .7),
              col.withValues(alpha: 0),
            ]),
        );
      }
    }
  }

  // ═══════════════════════════ WATER ════════════════════════════════════
  //
  // THE TURN, REDRAWN (2026-10-06, the author: the flip "happens so fast I
  // don't know what's going on and the visuals look really cheesy"). The
  // room used to squash flat edge-on and spring open again in under half a
  // second, with gold chevrons on the walls for downhill. Now nothing
  // pretends to spin: the room's SLOPE turns. Blood runs in a runnel cut
  // down each side wall, always downhill, pooling at the low end; on a flip
  // it slows, stops and runs back. The floor is shadowed toward the low end
  // and the shadow swings across. What is about to fall leans the new way
  // and trembles. Only then does anything slide, gathering speed, and it
  // lands — ice with a knock and a spray of frost, water with a splash.

  void _riteDrawWater(Canvas canvas) {
    final r = rites.waterRoom;
    canvas.drawPicture(
      _riteBake(
        'water',
        (c) => _riteBakeGrid(c, r.w, r.h, (x, y) => r.fixed[y][x] == '#', (
          c,
          x,
          y,
          sq,
        ) {
          _riteFlag(c, sq, x * 31 + y * 17 + 3);
          final ch = r.fixed[y][x];
          if (ch == '=') {
            c.drawRect(sq.deflate(6), Paint()..color = const Color(0xFF0B0607));
            for (var k = 1; k < 5; k++) {
              c.drawRect(
                Rect.fromLTWH(
                  sq.left + 6 + k * 10.4 - 2,
                  sq.top + 8,
                  4,
                  sq.height - 16,
                ),
                Paint()..color = const Color(0xFF5E4E44),
              );
            }
          } else if (ch == 'C') {
            // The basin: a trough sunk in the floor. Its far wall shows.
            final t = sq.deflate(4);
            c.drawRect(t, Paint()..color = const Color(0xFF0C0608));
            c.drawRect(
              Rect.fromLTWH(t.left, t.top, t.width, 13),
              Paint()
                ..shader = ui.Gradient.linear(
                  t.topCenter,
                  t.topCenter + const Offset(0, 13),
                  [const Color(0xFF2A161A), const Color(0xFF0C0608)],
                ),
            );
            c.drawRect(
              Rect.fromLTWH(t.left, t.bottom - 2, t.width, 2),
              Paint()..color = const Color(0xFF8A5A60).withValues(alpha: .5),
            );
          }
        }),
      ),
    );
    final slope = _riteWaterSlope;
    _riteSlopeShade(canvas, r, slope);
    _riteRunnels(canvas, r, slope);
    final turning = rites.flipT < 1;
    final from = rites.waterFrom;
    final playing = rites.waterFrames.isNotEmpty && from != null;
    // The fixed things as the pass being left has them; each one's moment
    // starts as its pass lands.
    final cells = playing ? from.cells : rites.water.cells;
    final down = kRiteDy[rites.water.down].toDouble();
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        final ch = cells[y][x];
        final cc = riteCentreOf(x, y);
        final k = '$x,$y';
        switch (ch) {
          case 'F':
            _riteBrazier(canvas, cc, true);
          case 'f':
            // A drowned fire: the flame sinks into its bowl as the steam goes.
            final since = _time - (rites.douseT[k] ?? -99);
            _riteBrazier(
              canvas,
              cc,
              since < .6,
              flame: 1 - _riteEase(since / .6),
            );
          case '_':
            _ritePit(canvas, _riteSq(x, y));
          case 'p':
            final since = _time - (rites.pitT[k] ?? -99);
            _ritePool(canvas, _riteSq(x, y), _riteEase(since / .8));
          case 'c':
            // A basin square filling: the level rises from its low side.
            final since = _time - (rites.basinT[k] ?? -99);
            final lvl = _riteEase(since / .8);
            final sqr = _riteSq(x, y).deflate(6);
            final h = sqr.height * lvl;
            final top = rites.water.down == 2 ? sqr.bottom - h : sqr.top;
            _riteFluid(
              canvas,
              [Rect.fromLTWH(sqr.left, top, sqr.width, h)],
              1,
              surfaceUp: rites.water.down == 2,
            );
        }
      }
    }
    // The captive across the basin.
    _riteDrawCaptive(canvas, _riteCaptiveAt('Water'), 'Water');
    // The loose things, slid part-way along this pass. While the room turns,
    // what the first pass will move leans the new way and trembles.
    final items = _riteWaterItems();
    final leanK = turning ? _riteEase((rites.flipT - .3) / .7) : 0.0;
    final first = rites.waterFrames.isNotEmpty ? rites.waterFrames.first : null;
    final leaners = <String>{
      if (first != null && turning) ...first.moves.values,
      if (first != null && turning) ...first.gone.keys,
    };
    final waterRects = <Rect>[];
    final solids = <(double, VoidCallback)>[];
    for (final (key, kind, c0, a, vel) in items) {
      var c = c0;
      if (leanK > 0 && leaners.contains(key)) {
        final h = _riteHash(key.hashCode);
        c += Offset(sin(_time * 41 + h * 9) * 1.4 * leanK, down * 6 * leanK);
      }
      final rr = Rect.fromCenter(
        center: c,
        width: kRiteCell,
        height: kRiteCell,
      );
      if (kind == 'I') {
        final since = _time - (rites.landT[key] ?? -99);
        final land = since >= 0 && since < .26
            ? pow(1 - since / .26, 2).toDouble()
            : 0.0;
        solids.add((
          c.dy,
          () {
            if (a < .98) {
              canvas.saveLayer(
                rr.inflate(10),
                Paint()..color = Colors.white.withValues(alpha: a),
              );
              _riteIce(canvas, rr, land: land);
              canvas.restore();
            } else {
              _riteIce(canvas, rr, land: land);
            }
          },
        ));
      } else {
        if (a > .98) waterRects.add(rr.deflate(3));
        // Moving water stretches back along its way, like water does.
        if (vel.distance > 1 && a > .98) {
          final dir = vel / vel.distance;
          final back = rr.deflate(3).shift(-dir * 24);
          waterRects.add(
            Rect.fromLTRB(
              min(back.left, rr.left + 3) + (dir.dx == 0 ? 9 : 0),
              min(back.top, rr.top + 3) + (dir.dy == 0 ? 9 : 0),
              max(back.right, rr.right - 3) - (dir.dx == 0 ? 9 : 0),
              max(back.bottom, rr.bottom - 3) - (dir.dy == 0 ? 9 : 0),
            ),
          );
        }
        if (a <= .98)
          _riteFluid(canvas, [rr.deflate(3)], a, surfaceUp: down > 0);
      }
    }
    if (waterRects.isNotEmpty)
      _riteFluid(canvas, waterRects, 1, surfaceUp: down > 0);
    solids.sort((p, q) => p.$1.compareTo(q.$1));
    for (final (_, draw) in solids) {
      draw();
    }
    // Ice melting against a fire: it shrinks and sinks into its own water.
    for (final e in rites.meltT.entries) {
      final since = _time - e.value;
      if (since > kRiteReactHold || since < 0) continue;
      final p = e.key.split(',').map(int.parse).toList();
      final k = _riteEase(since / kRiteReactHold);
      final rr = Rect.fromCenter(
        center: riteCentreOf(p[0], p[1]) + Offset(0, down * 10 * k),
        width: kRiteCell * (1 - .5 * k),
        height: kRiteCell * (1 - .6 * k),
      );
      canvas.saveLayer(
        rr.inflate(10),
        Paint()..color = Colors.white.withValues(alpha: 1 - k),
      );
      _riteIce(canvas, rr);
      canvas.restore();
    }
    // The ghost of the next flip: where things will come to rest.
    if (!playing && !turning && !flipSolved(rites.water)) {
      final next = _riteGhostCache.putIfAbsent(
        rites.water.key,
        () => flipTurn(r, rites.water).state!,
      );
      if (_riteGhostCache.length > 64) _riteGhostCache.clear();
      final ghost = .2 + .05 * sin(_time * 2.4);
      for (final e in next.loose.entries) {
        if (rites.water.loose[e.key] == e.value) continue;
        final p = e.key.split(',').map(int.parse).toList();
        final rr = _riteSq(p[0], p[1]);
        canvas.saveLayer(
          rr.inflate(10),
          Paint()..color = Colors.white.withValues(alpha: ghost),
        );
        if (e.value == 'I') {
          _riteIce(canvas, rr);
        } else {
          _riteFluid(
            canvas,
            [rr.deflate(3)],
            1,
            surfaceUp: rites.water.down != 2,
          );
        }
        canvas.restore();
      }
      for (var y = 0; y < r.h; y++) {
        for (var x = 0; x < r.w; x++) {
          final cc = riteCentreOf(x, y);
          if (rites.water.cells[y][x] == 'F' && next.cells[y][x] == 'f') {
            canvas.drawCircle(
              cc,
              26,
              Paint()
                ..shader = ui.Gradient.radial(cc, 26, [
                  const Color(0xFF4F8FC0).withValues(alpha: ghost),
                  const Color(0x004F8FC0),
                ]),
            );
          }
          if (rites.water.cells[y][x] == 'C' && next.cells[y][x] == 'c') {
            canvas.drawRect(
              _riteSq(x, y).deflate(10),
              Paint()
                ..color = const Color(0xFF5AA7E0).withValues(alpha: ghost * .7),
            );
          }
        }
      }
    }
  }

  /// The floor's slope: a shadow deepening toward the low end and a little
  /// warmth at the high end, swinging across as the room turns.
  void _riteSlopeShade(Canvas canvas, FlipRoom r, double slope) {
    final area = Rect.fromLTRB(
      kRiteCell,
      kRiteCell,
      (r.w - 1) * kRiteCell,
      (r.h - 1) * kRiteCell - _kRiteWallH,
    );
    final south = max(0.0, slope), north = max(0.0, -slope);
    canvas.drawRect(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          area.topCenter,
          area.bottomCenter,
          [
            Colors.black.withValues(alpha: .34 * north),
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: .34 * south),
          ],
          const [0, .55, 1],
        ),
    );
    canvas.drawRect(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          area.topCenter,
          area.bottomCenter,
          [
            const Color(0xFFF0C8B0).withValues(alpha: .06 * south),
            const Color(0x00F0C8B0),
            const Color(0xFFF0C8B0).withValues(alpha: .06 * north),
          ],
          const [0, .45, 1],
        ),
    );
  }

  /// Downhill, as the room itself shows it: a runnel cut down each side
  /// wall with blood running in it — the way things will fall — pooling at
  /// the low end. [slope] swings through level while the room turns, and
  /// the drops slow, hang and run back.
  void _riteRunnels(Canvas canvas, FlipRoom r, double slope) {
    final y0 = 1.25 * kRiteCell - _kRiteWallH;
    final y1 = 5.75 * kRiteCell - _kRiteWallH;
    final len = y1 - y0;
    final dir = slope.sign;
    final speed = slope.abs();
    for (final (i, side) in [
      (0, kRiteCell * .5),
      (1, (r.w - .5) * kRiteCell),
    ]) {
      final slot = RRect.fromRectAndRadius(
        Rect.fromLTRB(side - 6.5, y0, side + 6.5, y1),
        const Radius.circular(6.5),
      );
      canvas.drawRRect(slot, Paint()..color = const Color(0xFF0A0405));
      canvas.drawRect(
        Rect.fromLTWH(side - 6.5, y0 + 6, 1.6, len - 12),
        Paint()..color = Colors.black.withValues(alpha: .6),
      );
      canvas.drawRect(
        Rect.fromLTWH(side + 5, y0 + 6, 1.5, len - 12),
        Paint()..color = const Color(0xFFE8B8B8).withValues(alpha: .22),
      );
      canvas.save();
      canvas.clipRRect(slot);
      // What has run down collects at the low end.
      for (final (end, k) in [(y1, max(0.0, slope)), (y0, max(0.0, -slope))]) {
        if (k < .02) continue;
        final h = 16 * k;
        final pool = Rect.fromLTRB(
          side - 6.5,
          end == y1 ? y1 - h : y0,
          side + 6.5,
          end == y1 ? y1 : y0 + h,
        );
        canvas.drawRect(
          pool,
          Paint()
            ..shader = ui.Gradient.linear(pool.topCenter, pool.bottomCenter, [
              end == y1 ? _kRiteBlood : _kRiteBloodDeep,
              end == y1 ? _kRiteBloodDeep : _kRiteBlood,
            ]),
        );
      }
      // The drops.
      for (var k = 0; k < 4; k++) {
        final p =
            ((rites.runnel + k * len / 4 + i * len / 8) % len + len) % len;
        final y = y0 + p;
        final fade = (min(p, len - p) / 22).clamp(0.0, 1.0);
        if (fade < .03) continue;
        final tail = 2 + 11 * speed;
        final back = dir == 0 ? 0.0 : -dir;
        final drop = Path()
          ..moveTo(side - 3.6, y)
          ..quadraticBezierTo(
            side - 2.4,
            y + back * tail * .6,
            side,
            y + back * tail,
          )
          ..quadraticBezierTo(side + 2.4, y + back * tail * .6, side + 3.6, y)
          ..arcToPoint(
            Offset(side - 3.6, y),
            radius: const Radius.circular(3.6),
            clockwise: back < 0,
          )
          ..close();
        canvas.drawPath(
          drop,
          Paint()..color = _kRiteBlood.withValues(alpha: .95 * fade),
        );
        canvas.drawCircle(
          Offset(side - 1.1, y + dir * 1.2),
          1.3,
          Paint()..color = _kRiteBloodHot.withValues(alpha: .8 * fade),
        );
      }
      canvas.restore();
    }
  }

  /// Every loose thing as it is drawn this frame — its square, kind, centre,
  /// opacity and velocity — slid part-way through the pass being played:
  /// the moves the rules recorded, and whatever a pit or the basin is
  /// taking, fading. While the room turns, everything holds where it was.
  List<(String, String, Offset, double, Offset)> _riteWaterItems() {
    Offset centre(String k) {
      final p = k.split(',').map(int.parse).toList();
      return riteCentreOf(p[0], p[1]);
    }

    final from = rites.waterFrom;
    final to = rites.waterFrames.isNotEmpty ? rites.waterFrames.first : null;
    if (from == null || to == null || rites.flipT < 1) {
      final src = from?.loose ?? rites.water.loose;
      return [
        for (final e in src.entries)
          (e.key, e.value, centre(e.key), 1.0, Offset.zero),
      ];
    }
    final dur = rites.waterPassDur;
    final k = (rites.waterFrameT / dur).clamp(0.0, 1.0);
    final out = <(String, String, Offset, double, Offset)>[];
    for (final e in to.loose.entries) {
      final old = to.moves[e.key];
      if (old == null) {
        out.add((e.key, e.value, centre(e.key), 1.0, Offset.zero));
      } else {
        final a = centre(old), b = centre(e.key);
        out.add((old, e.value, Offset.lerp(a, b, k)!, 1.0, (b - a) / dur));
      }
    }
    for (final e in to.gone.entries) {
      final kind = from.loose[e.key] ?? '~';
      final a = centre(e.key), b = centre(e.value);
      out.add((e.key, kind, Offset.lerp(a, b, k)!, 1 - k, (b - a) / dur));
    }
    return out;
  }

  /// Water as one body: the squares it fills run together, deep and dark
  /// toward the low side, a lip of light trembling along every edge with no
  /// water beyond it uphill, and a few glints drifting on it.
  void _riteFluid(
    Canvas canvas,
    List<Rect> rects,
    double alpha, {
    required bool surfaceUp,
  }) {
    if (rects.isEmpty) return;
    var body = Path();
    for (final r in rects) {
      body = Path.combine(PathOperation.union, body, _riteWaterShape(r));
    }
    final b = body.getBounds();
    // Its edge, a shade darker where it meets the stone…
    canvas.drawPath(
      body,
      Paint()..color = const Color(0xFF07161F).withValues(alpha: .8 * alpha),
    );
    // …and the body inside it, deep toward the low side; the floor's dark
    // shows through it.
    canvas.save();
    canvas.translate(b.center.dx, b.center.dy);
    canvas.scale((b.width - 5) / b.width, (b.height - 5) / b.height);
    canvas.translate(-b.center.dx, -b.center.dy);
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          surfaceUp ? b.topCenter : b.bottomCenter,
          surfaceUp ? b.bottomCenter : b.topCenter,
          [
            const Color(0xFF3C82A6).withValues(alpha: .82 * alpha),
            const Color(0xFF1D5072).withValues(alpha: .8 * alpha),
            const Color(0xFF0D2A3D).withValues(alpha: .88 * alpha),
          ],
          const [0, .45, 1],
        ),
    );
    canvas.restore();
    final keys = {
      for (final r in rects) '${r.center.dx.round()},${r.center.dy.round()}',
    };
    final s = surfaceUp ? 1.0 : -1.0;
    for (final r in rects) {
      // The meniscus, where no water lies beyond it uphill.
      final above = Offset(r.center.dx, r.center.dy - s * kRiteCell);
      if (!keys.contains('${above.dx.round()},${above.dy.round()}')) {
        final y0 = surfaceUp ? r.top : r.bottom;
        final lip = Path();
        const n = 10;
        for (var i = 0; i <= n; i++) {
          final x = r.left + 5 + (r.width - 10) * i / n;
          final y = y0 + s * (1.5 + 1.6 * sin(_time * 2.6 + x * .12));
          i == 0 ? lip.moveTo(x, y) : lip.lineTo(x, y);
        }
        for (var i = n; i >= 0; i--) {
          final x = r.left + 5 + (r.width - 10) * i / n;
          final th = 2.2 + 1.8 * (.5 + .5 * sin(_time * 1.9 + x * .07 + 1));
          final y = y0 + s * (1.5 + 1.6 * sin(_time * 2.6 + x * .12) + th);
          lip.lineTo(x, y);
        }
        lip.close();
        canvas.drawPath(
          lip,
          Paint()
            ..color = const Color(0xFFCDEBF7).withValues(alpha: .6 * alpha),
        );
      }
      // Glints, drifting.
      for (var g = 0; g < 2; g++) {
        final h = _riteHash((r.left * 13 + r.top * 7).round() + g * 101);
        final gx =
            r.left + 10 + ((h + _time * .04 * (g + 1)) % 1) * (r.width - 20);
        final gy =
            r.top +
            14 +
            _riteHash((r.top * 3).round() + g * 17) * (r.height - 26);
        final ga = .32 * (.5 + .5 * sin(_time * 1.7 + h * 6.2)) * alpha;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(gx, gy), width: 8, height: 2.4),
          Paint()..color = Colors.white.withValues(alpha: ga),
        );
      }
    }
  }

  /// One square's worth of water: a squircle whose edge trembles, a little
  /// larger than its square so that neighbours run together.
  Path _riteWaterShape(Rect r) {
    final path = Path();
    const n = 28;
    final c = r.center;
    final hw = r.width / 2 + 5, hh = r.height / 2 + 5;
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * pi;
      final ca = cos(a), sa = sin(a);
      final k = pow(pow(ca.abs(), 5) + pow(sa.abs(), 5), -.2).toDouble();
      final wob =
          1 + .03 * sin(_time * 2.3 + i * 1.9 + r.left * .05 + r.top * .03);
      final p = c + Offset(ca * hw * k * wob, sa * hh * k * wob);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// A block of ice standing in square [sq], from three-quarters: a chipped
  /// top, a cold face below it, depth seen through it, frost on its near
  /// edge. [land] (1 → 0) squashes it as it sets down.
  void _riteIce(Canvas canvas, Rect sq, {double land = 0}) {
    final sx = 1 + .08 * land, sy = 1 - .12 * land;
    final w = (sq.width - 12) * sx;
    final cx = sq.center.dx;
    final foot = sq.bottom - 5;
    final faceTop = foot - 12 * sy;
    final top = Rect.fromLTRB(
      cx - w / 2,
      faceTop - 38 * sy,
      cx + w / 2,
      faceTop,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, foot), width: w + 10, height: 12),
      Paint()..color = Colors.black.withValues(alpha: .45),
    );
    final face = Path()
      ..moveTo(top.left, faceTop - 1)
      ..lineTo(top.right, faceTop - 1)
      ..lineTo(top.right - 2, foot)
      ..lineTo(top.left + 2, foot)
      ..close();
    canvas.drawPath(
      face,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, faceTop), Offset(0, foot), [
          const Color(0xFF4A8CA8),
          const Color(0xFF173A4C),
        ]),
    );
    const ch = 7.0;
    final t = Path()
      ..moveTo(top.left + ch, top.top)
      ..lineTo(top.right - ch * .6, top.top)
      ..lineTo(top.right, top.top + ch * .8)
      ..lineTo(top.right, top.bottom)
      ..lineTo(top.left, top.bottom)
      ..lineTo(top.left, top.top + ch)
      ..close();
    canvas.drawPath(
      t,
      Paint()
        ..shader = ui.Gradient.linear(
          top.topLeft,
          top.bottomRight,
          [
            const Color(0xFFE8F8FC),
            const Color(0xFFA4D6E8),
            const Color(0xFF6AA8C2),
          ],
          const [0, .45, 1],
        ),
    );
    // Its depth, seen through the top.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          top.left + 10,
          top.top + 9,
          top.right - 6,
          top.bottom - 5,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF3F84A2).withValues(alpha: .3),
    );
    // A crack: a thin wedge of light.
    canvas.drawPath(
      Path()
        ..moveTo(top.left + w * .3, top.top + 5)
        ..lineTo(top.left + w * .3 + 2.4, top.top + 5)
        ..lineTo(top.left + w * .52, top.bottom - 9)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .35),
    );
    // Frost along the near edge, and a glint at the far corner.
    canvas.drawRect(
      Rect.fromLTWH(top.left + 2, top.bottom - 3, top.width - 4, 3),
      Paint()..color = const Color(0xFFF2FCFF).withValues(alpha: .55),
    );
    canvas.drawPath(
      Path()
        ..moveTo(top.left + ch + 3, top.top + 3)
        ..lineTo(top.left + ch + 14, top.top + 3)
        ..lineTo(top.left + ch + 8, top.top + 7)
        ..lineTo(top.left + ch - 3, top.top + 7)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: .8),
    );
  }

  /// A hole in the floor: dark, its far wall showing, its near lip lit.
  void _ritePit(Canvas canvas, Rect cell) {
    final sq = cell.deflate(5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sq, const Radius.circular(5)),
      Paint()..color = const Color(0xFF030102),
    );
    canvas.drawRect(
      Rect.fromLTWH(sq.left + 2, sq.top + 2, sq.width - 4, 16),
      Paint()
        ..shader = ui.Gradient.linear(
          sq.topCenter,
          sq.topCenter + const Offset(0, 18),
          [const Color(0xFF2E181C), const Color(0xFF030102)],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(sq.left + 3, sq.bottom - 2, sq.width - 6, 2),
      Paint()..color = const Color(0xFF9A6A70).withValues(alpha: .45),
    );
  }

  /// The pit, flooded: deep still water filling in, glints on it.
  void _ritePool(Canvas canvas, Rect cell, double fill) {
    _ritePit(canvas, cell);
    final sq = cell.deflate(7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sq, const Radius.circular(5)),
      Paint()
        ..shader = ui.Gradient.linear(sq.topCenter, sq.bottomCenter, [
          const Color(0xFF2A6A92).withValues(alpha: .9 * fill),
          const Color(0xFF0A2232).withValues(alpha: .95 * fill),
        ]),
    );
    for (var g = 0; g < 3; g++) {
      final h = _riteHash(g * 37 + 3);
      final x =
          sq.left + 8 + ((h + _time * .03 * (g + 1)) % 1) * (sq.width - 16);
      final y = sq.top + 10 + h * (sq.height - 20);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 9, height: 2.2),
        Paint()
          ..color = Colors.white.withValues(
            alpha: .28 * fill * (.5 + .5 * sin(_time * 1.3 + g * 2)),
          ),
      );
    }
  }

  /// A brazier: a carved pedestal and a bronze bowl of coals. Lit, three
  /// tongues of flame sway over it (the middle tallest) with sparks lifting
  /// off, and it lights the floor round it; [flame] sinks them as it goes
  /// out. Out, it smokes.
  void _riteBrazier(Canvas canvas, Offset c, bool lit, {double flame = 1}) {
    if (lit) {
      canvas.drawCircle(
        c + const Offset(0, 8),
        56,
        Paint()
          ..shader = ui.Gradient.radial(c + const Offset(0, 8), 56, [
            const Color(
              0xFFEE7A3A,
            ).withValues(alpha: (.24 + .05 * sin(_time * 9)) * flame),
            const Color(0x00EE7A3A),
          ]),
      );
    }
    paintCarvedDisc(canvas, c + const Offset(0, 12), 21, 12, 9, _kRiteWall);
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 6), width: 36, height: 15),
      Paint()..color = const Color(0xFF4A3218),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 4.5), width: 30, height: 10),
      Paint()
        ..shader = ui.Gradient.radial(
          c + const Offset(0, 4),
          15,
          lit
              ? [
                  Color.lerp(
                    const Color(0xFF3A1E14),
                    const Color(0xFFFFB050),
                    flame,
                  )!,
                  Color.lerp(
                    const Color(0xFF120B0B),
                    const Color(0xFF8A2A10),
                    flame,
                  )!,
                ]
              : [const Color(0xFF2A2020), const Color(0xFF0E0909)],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(c.dx - 15, c.dy + 12, 30, 1.6),
      Paint()..color = const Color(0xFFC89A5A).withValues(alpha: .4),
    );
    if (lit && flame > .01) {
      const outer = Color(0xFFD8481F),
          mid = Color(0xFFF08A3A),
          core = Color(0xFFFFE0A0);
      for (final k in const [-1, 1, 0]) {
        final h =
            (k == 0 ? 32.0 : 21.0) *
            flame *
            (1 + .13 * sin(_time * (7.3 + k * 1.9) + k * 2));
        final w = k == 0 ? 9.5 : 6.5;
        final base = c + Offset(k * 7.5, 4);
        final sway = sin(_time * (3.1 + k * .7) + k) * 3.2 * flame;
        Path tongue(double s) => Path()
          ..moveTo(base.dx - w * s, base.dy)
          ..quadraticBezierTo(
            base.dx - w * s * .95,
            base.dy - h * s * .55,
            base.dx + sway * s,
            base.dy - h * s,
          )
          ..quadraticBezierTo(
            base.dx + w * s * .95,
            base.dy - h * s * .55,
            base.dx + w * s,
            base.dy,
          )
          ..close();
        canvas.drawPath(
          tongue(1),
          Paint()
            ..shader = ui.Gradient.linear(base, base - Offset(-sway, h), [
              outer,
              mid.withValues(alpha: .9),
            ]),
        );
        if (k == 0) {
          canvas.drawPath(
            tongue(.55),
            Paint()..color = core.withValues(alpha: .9),
          );
        }
      }
      for (var i = 0; i < 3; i++) {
        final t = (_time * .8 + i * .37) % 1;
        canvas.drawRect(
          Rect.fromCenter(
            center:
                c + Offset(sin(t * 6 + i * 2) * 7 + (i - 1) * 4, -14 - t * 38),
            width: 2,
            height: 2,
          ),
          Paint()
            ..color = const Color(
              0xFFFFC870,
            ).withValues(alpha: .85 * (1 - t) * flame),
        );
      }
    } else if (!lit) {
      for (var k = 0; k < 2; k++) {
        final t = (_time * .5 + k * .5) % 1;
        canvas.drawCircle(
          c + Offset(sin(t * 6 + k) * 5, -t * 30),
          4 + t * 6,
          Paint()
            ..color = const Color(0xFFA09890).withValues(alpha: .2 * (1 - t)),
        );
      }
    }
  }

  // ═══════════════════════════ FIRE ═════════════════════════════════════

  void _riteDrawFire(Canvas canvas) {
    final r = rites.fireRoom;
    canvas.drawPicture(
      _riteBake(
        'fire',
        (c) => _riteBakeGrid(c, r.w, r.h, (x, y) => r.cells[y][x] == '#', (
          c,
          x,
          y,
          sq,
        ) {
          final ch = r.cells[y][x];
          if (ch == '|' || ch == 'H') {
            c.drawRect(sq, Paint()..color = const Color(0xFF240A10));
            return;
          }
          _riteFlag(c, sq, x * 31 + y * 17 + 7);
          if (ch == 'O') _ritePit(c, sq);
        }),
      ),
    );
    // The pool: blood, moving slowly, with the mirror's seam down its middle.
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        final ch = r.cells[y][x];
        if (ch != '|' && ch != 'H') continue;
        final sq = _riteSq(x, y);
        canvas.drawRect(
          Rect.fromLTRB(sq.left + 7, sq.top, sq.right - 7, sq.bottom),
          Paint()
            ..shader = ui.Gradient.linear(
              sq.centerLeft,
              sq.centerRight,
              [_kRiteBloodDeep, const Color(0xFFA01C2C), _kRiteBloodDeep],
              const [0, .5, 1],
            ),
        );
        final o = sin(_time * 1.5 + y) * 4;
        canvas.drawRect(
          Rect.fromCenter(
            center: sq.center + Offset(o, 0),
            width: 2,
            height: sq.height * .7,
          ),
          Paint()..color = const Color(0x33FFD0D0),
        );
      }
    }
    final on = twinPressed(r, rites.fire, freed: _riteFireDone);
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        final ch = r.cells[y][x];
        final cc = riteCentreOf(x, y);
        final sq = _riteSq(x, y);
        switch (ch) {
          case 'H':
            paintCarvedDisc(canvas, cc, 30, 26, 6, _kRiteWall);
            final hot =
                discoveredClouds.contains(riteFreedId('Fire')) ||
                rites.freedT.containsKey('Fire');
            if (hot) _riteBrazier(canvas, cc, true);
            _riteDrawCaptive(canvas, cc, 'Fire');
          case 'B':
            _riteBellows(
              canvas,
              cc,
              r.cells[y][x + 1] == '|' || r.cells[y][x + 1] == 'H' ? 1.0 : -1.0,
              rites.fire.b == (x: x, y: y),
            );
          case 'L':
            _riteSluice(canvas, sq);
          case '1':
          case '2':
          case '3':
            final down = on.contains(ch);
            final col = ch == '1' ? _kRiteGold : const Color(0xFF9FB7C9);
            paintCarvedDisc(canvas, cc, 22, 20, down ? 1 : 5, _kRiteWall);
            for (var k = 0; k < int.parse(ch); k++) {
              canvas.drawCircle(
                cc + Offset((k - (int.parse(ch) - 1) / 2) * 10, down ? 0 : -3),
                3.4,
                Paint()..color = col.withValues(alpha: down ? 1 : .6),
              );
            }
          case 'a':
          case 'b':
          case 'c':
            final shown = rites.gateShown['$x,$y'] ?? 0;
            final col = ch == 'a' ? _kRiteGold : const Color(0xFF9FB7C9);
            // A portcullis between two stone posts. Shut, it is a grille of
            // heavy bars that throws a shadow; it slides up into its lintel
            // as it opens, and only the posts are left.
            final e = _riteEase(shown);
            final lift = (sq.height - 10) * e;
            final inner = Rect.fromLTRB(
              sq.left + 9,
              sq.top - 8,
              sq.right - 9,
              sq.bottom - 6,
            );
            if (e < .98) {
              canvas.drawRect(
                Rect.fromLTWH(
                  inner.left,
                  inner.bottom - 2,
                  inner.width,
                  10 * (1 - e),
                ),
                Paint()..color = Colors.black.withValues(alpha: .45 * (1 - e)),
              );
              canvas.save();
              canvas.clipRect(
                Rect.fromLTRB(
                  inner.left,
                  inner.top,
                  inner.right,
                  inner.bottom - lift,
                ),
              );
              final bar = Color.lerp(col, Colors.black, .45)!;
              final lit = Color.lerp(col, Colors.white, .15)!;
              for (var k = 0; k < 4; k++) {
                final bx = inner.left + 4 + k * (inner.width - 8) / 3;
                final b = Rect.fromLTRB(
                  bx - 3,
                  inner.top,
                  bx + 3,
                  inner.bottom - lift,
                );
                canvas.drawRect(b, Paint()..color = bar);
                canvas.drawRect(
                  Rect.fromLTWH(b.left, b.top, 1.6, b.height),
                  Paint()..color = lit.withValues(alpha: .7),
                );
                // Its point, at the foot.
                canvas.drawPath(
                  Path()
                    ..moveTo(b.left, b.bottom)
                    ..lineTo(b.right, b.bottom)
                    ..lineTo(b.center.dx, b.bottom + 6)
                    ..close(),
                  Paint()..color = bar,
                );
              }
              for (final fy in const [.32, .7]) {
                final y = inner.top + (inner.height - lift) * fy;
                canvas.drawRect(
                  Rect.fromLTWH(inner.left, y - 3, inner.width, 6),
                  Paint()..color = Color.lerp(col, Colors.black, .2)!,
                );
                canvas.drawRect(
                  Rect.fromLTWH(inner.left, y - 3, inner.width, 1.6),
                  Paint()..color = lit.withValues(alpha: .8),
                );
              }
              canvas.restore();
            }
            // The posts and the lintel.
            for (final px in [sq.left + 2, sq.right - 9]) {
              paintCarvedBlock(
                canvas,
                Rect.fromLTWH(px, sq.top - 12, 7, sq.height - 4),
                6,
                _kRiteWall,
                radius: 1,
              );
            }
            canvas.drawRect(
              Rect.fromLTWH(sq.left + 2, sq.top - 14, sq.width - 4, 8),
              Paint()..color = Color.lerp(_kRiteWall.stoneTop, col, .25)!,
            );
        }
      }
    }
    // The twin: Blood's own body, seen in the pool's mirror.
    final a = active;
    final t = rites.twinShown == Offset.zero
        ? riteCentreOf(rites.fire.t.x, rites.fire.t.y)
        : rites.twinShown;
    canvas.drawCircle(
      t,
      32,
      Paint()
        ..shader = ui.Gradient.radial(t, 32, [
          _kRiteBlood.withValues(alpha: .3),
          _kRiteBlood.withValues(alpha: 0),
        ]),
    );
    final ticker = a?.ticker;
    if (ticker != null) {
      canvas.save();
      canvas.translate(t.dx, t.dy);
      canvas.scale(-a!.spriteScale, a.spriteScale);
      ticker.getSprite().render(
        canvas,
        anchor: Anchor.center,
        overridePaint: Paint()
          ..filterQuality = ui.FilterQuality.high
          ..colorFilter = const ColorFilter.mode(
            Color(0xCC8A1626),
            BlendMode.srcATop,
          ),
      );
      canvas.restore();
    } else {
      canvas.drawCircle(t, 16, Paint()..color = const Color(0xFF8A1626));
    }
  }

  /// The bellows, pointed at the hearth along [dir]: two boards of dark
  /// wood over a pleated leather fold, a brass nozzle. Stood on, they
  /// breathe (the air itself is grains, from the play).
  void _riteBellows(Canvas canvas, Offset c, double dir, bool pressed) {
    final squeeze = pressed ? .55 + .2 * sin(_time * 9) : 1.0;
    paintContactShadow(canvas, c + const Offset(0, 14), 56, 18, opacity: .5);
    final back = c.dx - dir * 24, nose = c.dx + dir * 16;
    final half = 15.0 * squeeze;
    // The leather, pleated.
    final fold = Path()..moveTo(back, c.dy + 4 - half);
    for (var k = 0; k <= 6; k++) {
      final t = k / 6;
      final x = back + (nose - back) * t;
      final hy = half * (1 - .6 * t) + (k.isEven ? 0 : 3);
      fold.lineTo(x, c.dy + 4 - hy);
    }
    for (var k = 6; k >= 0; k--) {
      final t = k / 6;
      final x = back + (nose - back) * t;
      final hy = half * (1 - .6 * t) + (k.isEven ? 0 : 3);
      fold.lineTo(x, c.dy + 4 + hy * .6);
    }
    fold.close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFF3A1E14));
    // The top board, its grain, and a handle at the back.
    final board = Path()
      ..moveTo(back - dir * 4, c.dy - 2 - half)
      ..lineTo(nose, c.dy - 2 - half * .4)
      ..lineTo(nose, c.dy + 2 - half * .4)
      ..lineTo(back - dir * 4, c.dy + 4 - half)
      ..close();
    canvas.drawPath(
      board,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(back, c.dy - half),
          Offset(nose, c.dy),
          [const Color(0xFF7A5034), const Color(0xFF4A2E1C)],
        ),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(back - dir * 9, c.dy - half + 1),
        width: 10,
        height: 4,
      ),
      Paint()..color = const Color(0xFF4A2E1C),
    );
    // The nozzle.
    final n0 = Offset(nose, c.dy + 2);
    canvas.drawPath(
      Path()
        ..moveTo(n0.dx, n0.dy - 4)
        ..lineTo(n0.dx + dir * 14, n0.dy - 1.6)
        ..lineTo(n0.dx + dir * 14, n0.dy + 1.6)
        ..lineTo(n0.dx, n0.dy + 4)
        ..close(),
      Paint()..color = _kRiteBronze,
    );
    canvas.drawRect(
      Rect.fromLTWH(min(n0.dx, n0.dx + dir * 14), n0.dy - 2.5, 14, 1.2),
      Paint()..color = const Color(0xFFE8C080).withValues(alpha: .55),
    );
  }

  /// The lava sluice: a stone trough of molten rock, its crust drifting,
  /// lighting the floor round it.
  void _riteSluice(Canvas canvas, Rect sq) {
    final cc = sq.center;
    canvas.drawCircle(
      cc,
      48,
      Paint()
        ..shader = ui.Gradient.radial(cc, 48, [
          const Color(0xFFFF7A2A).withValues(alpha: .26 + .06 * sin(_time * 3)),
          const Color(0x00FF7A2A),
        ]),
    );
    final trough = Rect.fromLTRB(
      sq.left + 8,
      sq.top + 14,
      sq.right - 8,
      sq.bottom - 10,
    );
    paintCarvedBlock(canvas, trough.inflate(4), 7, _kRiteWall, radius: 4);
    final melt = trough.deflate(3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(melt, const Radius.circular(3)),
      Paint()
        ..shader = ui.Gradient.linear(
          melt.topCenter,
          melt.bottomCenter,
          [
            const Color(0xFFFFC45A),
            const Color(0xFFF0622A),
            const Color(0xFF9A2410),
          ],
          const [0, .45, 1],
        ),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(melt, const Radius.circular(3)));
    for (var k = 0; k < 4; k++) {
      final h = _riteHash(k * 19 + 2);
      final x = melt.left + ((h + _time * .05) % 1.2 - .1) * melt.width;
      final y = melt.top + 4 + h * (melt.height - 10);
      canvas.drawPath(
        vfxBlob(Offset(x, y), 5 + 3 * h, k * 3.1, n: 7, squash: .55),
        Paint()..color = const Color(0xFF3A120A).withValues(alpha: .75),
      );
    }
    canvas.restore();
  }

  // ═══════════════════════════ AIR ══════════════════════════════════════

  void _riteDrawAir(Canvas canvas) {
    final r = rites.airRoom;
    canvas.drawPicture(
      _riteBake(
        'air',
        (c) => _riteBakeGrid(c, r.w, r.h, (x, y) => r.cells[y][x] == '#', (
          c,
          x,
          y,
          sq,
        ) {
          // Open air: the floor is far below, dim and soft.
          final v = _riteHash(x * 7 + y * 13);
          c.drawRect(
            sq,
            Paint()
              ..color = Color.lerp(
                const Color(0xFF140E12),
                const Color(0xFF1C1418),
                v,
              )!,
          );
          if (r.cells[y][x] == '*') {
            c.drawRect(
              sq,
              Paint()
                ..shader = ui.Gradient.radial(sq.center, 46, [
                  const Color(0x66FFECB4),
                  const Color(0x00FFECB4),
                ]),
            );
          }
        }),
      ),
    );
    // Motes: the room has no floor to settle on.
    for (var i = 0; i < 40; i++) {
      final fx = _riteHash(i * 3),
          fy = _riteHash(i * 5 + 1),
          sp = _riteHash(i * 7 + 2);
      final x =
          kRiteCell +
          ((fx + _time * .01 * (sp - .5)) % 1) * (r.w - 2) * kRiteCell;
      final y =
          kRiteCell +
          ((fy - _time * .015 * (.3 + sp)) % 1 + 1) % 1 * (r.h - 2) * kRiteCell;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 1.6, 1.6),
        Paint()
          ..color = const Color(0xFFDCE6F0).withValues(alpha: .12 + .12 * sp),
      );
    }
    // Sunlight falling through the roof.
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        if (r.cells[y][x] != '*') continue;
        final sq = _riteSq(x, y);
        canvas.drawRect(
          sq.deflate(6),
          Paint()..color = const Color(0xFFFFF0C8).withValues(alpha: .14),
        );
        for (var k = 0; k < 4; k++) {
          final t = (_time * .4 + k / 4) % 1;
          canvas.drawRect(
            Rect.fromLTWH(
              sq.left + 12 + 40 * _riteHash(x * 9 + y * 3 + k),
              sq.top + 6 + 52 * t,
              2,
              2,
            ),
            Paint()
              ..color = const Color(0xFFFFF0C8).withValues(alpha: .6 * (1 - t)),
          );
        }
      }
    }
    // The bell, and the captive inside it.
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        if (r.cells[y][x] != 'C') continue;
        final cc = riteCentreOf(x, y);
        _riteDrawCaptive(canvas, cc + const Offset(0, 4), 'Air');
        final fill = (rites.air.air / r.need).clamp(0.0, 1.0);
        // The air it holds, turning inside the glass.
        for (var i = 0; i < rites.air.air * 18; i++) {
          final h = _riteHash(i * 13 + 5);
          final ang = _time * (1.1 + h) + i * 2.4;
          final rad = 6 + 15 * _riteHash(i * 7 + 1);
          final mp = cc + Offset(cos(ang) * rad, sin(ang) * rad * .7 - 2);
          canvas.drawCircle(
            mp,
            1.3,
            Paint()
              ..color =
                  (i % 3 == 0
                          ? const Color(0xFFFFE6A0)
                          : const Color(0xFFDCEBF2))
                      .withValues(alpha: .75),
          );
        }
        if (fill > 0) {
          canvas.drawCircle(
            cc,
            30,
            Paint()
              ..shader = ui.Gradient.radial(cc, 30, [
                elementColor('Air').withValues(alpha: .3 * fill),
                elementColor('Air').withValues(alpha: 0),
              ]),
          );
        }
        final dome = Path()
          ..moveTo(cc.dx - 25, cc.dy + 26)
          ..lineTo(cc.dx - 25, cc.dy - 4)
          ..arcToPoint(
            Offset(cc.dx + 25, cc.dy - 4),
            radius: const Radius.circular(25),
          )
          ..lineTo(cc.dx + 25, cc.dy + 26)
          ..close();
        paintPaneFill(canvas, dome, const Color(0x22D2E6F0));
        paintStreak(
          canvas,
          Rect.fromLTWH(cc.dx - 20, cc.dy - 24, 18, 36),
          opacity: .6,
        );
        paintLead(canvas, dome, kFrostGlass, width: 2.6);
        canvas.drawRect(
          Rect.fromLTWH(cc.dx - 29, cc.dy + 24, 58, 6),
          Paint()..color = _kRiteBronze,
        );
        for (var k = 0; k < r.need; k++) {
          final full = k < rites.air.air;
          canvas.drawCircle(
            cc + Offset((k - (r.need - 1) / 2) * 13, -36),
            4,
            Paint()
              ..color = full
                  ? elementColor('Air')
                  : const Color(0xFFD2E6F0).withValues(alpha: .2),
          );
        }
      }
    }
    // The ice — one may be drifting, or melting into the light.
    final drifting = rites.driftT < 1 && rites.icePath.length > 1;
    final end = drifting ? (rites.iceMelted ?? rites.icePath.last) : null;
    for (final k in rites.air.ice) {
      final p = k.split(',').map(int.parse).toList();
      if (end != null &&
          rites.iceMelted == null &&
          p[0] == end.x &&
          p[1] == end.y) {
        continue;
      }
      _riteIce(canvas, _riteSq(p[0], p[1]));
    }
    if (drifting) {
      final from = rites.icePath.first;
      final e = 1 - (1 - rites.driftT) * (1 - rites.driftT);
      final at = Offset.lerp(
        _riteSq(from.x, from.y).topLeft,
        _riteSq(end!.x, end.y).topLeft,
        e,
      )!;
      canvas.save();
      if (rites.iceMelted != null) {
        canvas.saveLayer(
          null,
          Paint()
            ..color = Colors.white.withValues(
              alpha: 1 - max(0.0, (rites.driftT - .6) / .4),
            ),
        );
      }
      _riteIce(canvas, Rect.fromLTWH(at.dx, at.dy, kRiteCell, kRiteCell));
      if (rites.iceMelted != null) canvas.restore();
      canvas.restore();
    }
  }

  // ═══════════════════════════ THE VAULT, THE SHELL ═════════════════════

  void _riteDrawVault(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _riteBake('vault', (c) {
        for (var y = 0.0; y < b.height; y += 64) {
          for (var x = 0.0; x < b.width; x += 64) {
            final r = Rect.fromLTWH(x, y, 64, 64);
            final edge =
                y == 0 || x == 0 || x + 64 >= b.width || y + 64 >= b.height;
            if (edge && !(y == 0 && x == 192)) {
              _riteWall(c, r, (x ~/ 64));
            } else {
              _riteFlag(c, r, (x ~/ 64) * 7 + (y ~/ 64) * 3 + 11);
            }
          }
        }
        // Still water at the foot of the shaft.
        c.drawRect(
          const Rect.fromLTWH(198, 64, 52, 40),
          Paint()..color = const Color(0xFF1D4A72).withValues(alpha: .7),
        );
      }),
    );
  }

  /// Sanguorath's shell: a sphere of the element its opposite breaks.
  void _riteDrawShell(Canvas canvas) {
    // The sacrifice plays over everything: the ally, its grains, and the
    // shell shedding as it takes them.
    final sac = rites.sacrifice;
    final g = _guardianEnemy;
    final el = rites.shellUp
        ? rites.shellElement
        : (sac != null ? rites.shedElement : null);
    if (el != null && g != null && !g.isDead) {
      _riteShellBody(
        canvas,
        g.position,
        el,
        sac?.shedK ?? 0,
        taken: sac?.takenK ?? 0,
      );
    }
    if (sac != null) {
      final c = rites.sacrificed;
      final at = sac.from;
      // Blood rises round it before it goes.
      final rise = sac.riseK;
      if (rise > .01) {
        canvas.drawOval(
          Rect.fromCenter(
            center: at + const Offset(0, 16),
            width: 60 * rise,
            height: 18 * rise,
          ),
          Paint()..color = _kRiteBlood.withValues(alpha: .55 * rise),
        );
      }
      // The body above the crest is still itself.
      final ticker = c?.ticker;
      if (sac.cut < 1) {
        canvas.save();
        if (sac.cut > 0) {
          const half = kRiteSnapBox / 2;
          canvas.clipRect(
            Rect.fromLTRB(
              at.dx - half,
              at.dy - half,
              at.dx + half,
              at.dy + sac.crestLocal,
            ),
          );
        }
        if (ticker != null) {
          canvas.translate(at.dx, at.dy);
          canvas.scale(c!.spriteScale, c.spriteScale);
          ticker.getSprite().render(
            canvas,
            anchor: Anchor.center,
            overridePaint: Paint()..filterQuality = ui.FilterQuality.high,
          );
        } else {
          canvas.drawCircle(at, 15, Paint()..color = sac.allyColor);
        }
        canvas.restore();
      }
      sac.paint(canvas, rites.batch, _time);
    }
  }

  /// Sanguorath's shell: a sphere of the element its opposite breaks. As an
  /// ally gives itself ([shed] 0 → 1) the shell thins and its pieces drift
  /// off and go out.
  void _riteShellBody(
    Canvas canvas,
    Offset c,
    String el,
    double shed, {
    double taken = 0,
  }) {
    final col = Color.lerp(elementColor(el), _kRiteBlood, taken)!;
    final k = _riteEase((_time - rites.shellT) / .7);
    final r = 64 * k * (1 + shed * .5);
    final a = 1 - shed;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            col.withValues(alpha: 0),
            col.withValues(alpha: .18 * a),
            col.withValues(alpha: .5 * a),
          ],
          const [0, .7, 1],
        ),
    );
    for (var i = 0; i < 18; i++) {
      final ang =
          i * pi * 2 / 18 +
          _time * (el == 'Air' ? 1.6 : .3) +
          shed * _riteHash(i) * 1.5;
      final p =
          c + Offset(cos(ang), sin(ang)) * (r + shed * 40 * _riteHash(i + 3));
      final pa = a * (1 - shed * _riteHash(i + 9) * .5);
      if (pa <= .02) continue;
      switch (el) {
        case 'Fire':
          final h = 14 + 6 * sin(_time * 8 + i);
          final n = Offset(cos(ang), sin(ang));
          final side = Offset(-n.dy, n.dx) * 5;
          canvas.drawPath(
            Path()
              ..moveTo(p.dx + side.dx, p.dy + side.dy)
              ..lineTo(p.dx + n.dx * h, p.dy + n.dy * h)
              ..lineTo(p.dx - side.dx, p.dy - side.dy)
              ..close(),
            Paint()
              ..color = const Color(0xFFF08A3A).withValues(alpha: .85 * pa),
          );
        case 'Water':
          canvas.drawCircle(
            p + Offset(0, 3 * sin(_time * 3 + i)),
            6,
            Paint()..color = const Color(0xFF5AA7E0).withValues(alpha: .7 * pa),
          );
        case 'Earth':
          canvas.save();
          canvas.translate(p.dx, p.dy);
          canvas.rotate(ang);
          canvas.drawRect(
            const Rect.fromLTWH(-6, -9, 12, 18),
            Paint()..color = const Color(0xFF8A6A3E).withValues(alpha: pa),
          );
          canvas.restore();
        case 'Air':
          final n = Offset(-sin(ang), cos(ang));
          canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy)
              ..lineTo(
                p.dx + n.dx * 14 + cos(ang) * 3,
                p.dy + n.dy * 14 + sin(ang) * 3,
              )
              ..lineTo(
                p.dx + n.dx * 14 - cos(ang) * 3,
                p.dy + n.dy * 14 - sin(ang) * 3,
              )
              ..close(),
            Paint()..color = const Color(0xFFDCEBF2).withValues(alpha: .7 * pa),
          );
      }
    }
  }
}
