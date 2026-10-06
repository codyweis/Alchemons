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

part of 'planet_dungeon_game.dart';

/// Porphyry walls: near-black garnet, lit only at the arris.
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
  stoneTop: Color(0xFF2C1C20),
  stoneFace: Color(0xFF170C0F),
  stoneFoot: Color(0xFF060203),
  floor: Color(0xFF2A1E21),
  floorAlt: Color(0xFF241A1D),
  joint: Color(0xFF080305),
);

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

  void _riteWall(Canvas c, Rect r, int x) {
    paintCarvedBlock(
      c,
      Rect.fromLTRB(r.left, r.top - 8, r.right, r.bottom - 16),
      16,
      _kRiteWall,
      radius: 1,
    );
    c.drawRect(
      Rect.fromLTWH(r.left + 3, r.top + 12 + (x % 2) * 8, r.width - 6, 1),
      Paint()..color = Colors.black.withValues(alpha: .45),
    );
  }

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
      case RiteKind.arena:
        _riteDrawShell(canvas);
    }
    // The moments, over the room: loose grains, then a release in play.
    rites.grains.paint(canvas, rites.batch);
    rites.release?.paint(canvas, rites.batch, _time);
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
          Rect.fromLTRB(at.dx - half, at.dy + rel.crestLocal, at.dx + half, at.dy + half),
        );
      }
      final ticker = ally?.ticker;
      if (ticker != null) {
        canvas.translate(at.dx, at.dy);
        canvas.scale(ally!.spriteScale * kRiteCaptiveScale, ally.spriteScale * kRiteCaptiveScale);
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
          ..addOval(Rect.fromCenter(center: Offset(cx, at.dy + 2), width: 10 * sw, height: 40 * sw))
          ..addOval(
            Rect.fromCenter(
              center: Offset(cx + k * 2, at.dy + 2),
              width: 6 * sw + bands * 4,
              height: 34 * sw + bands * 6,
            ),
          )
          ..fillType = PathFillType.evenOdd;
        canvas.drawPath(path, Paint()..color = _kRiteBlood.withValues(alpha: .85 * a));
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
      if (run > .01) _riteStream(canvas, door, Offset.lerp(door, cup, run)!, el);
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
      final lvl = full ? _riteEase((_time - (rites.cupT[el] ?? -99) - .7) / 1.0) : 0.0;
      if (lvl > .01) {
        canvas.drawOval(
          Rect.fromCenter(center: p, width: (bowl.width - 6) * lvl, height: (bowl.height - 6) * lvl),
          Paint()
            ..shader = ui.Gradient.radial(p - const Offset(4, 3), 18, [
              _kRiteBloodHot,
              _kRiteBlood,
              _kRiteBloodDeep,
            ], const [0, .35, 1]),
        );
        canvas.drawCircle(
          p,
          4 * lvl,
          Paint()..color = elementColor(el).withValues(alpha: .9),
        );
      }
      paintLead(canvas, Path()..addOval(bowl), _kRiteWall, width: 2.4);
    }
    // The seal in the middle.
    final open = rites.cups.length == 4 && guardianRiteUnlocked;
    _riteSeal(canvas, c, open);
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
          ..shader = ui.Gradient.radial(c, 90, [
            const Color(0xFFFFF4D8).withValues(alpha: .6 * k),
            _kRiteGold.withValues(alpha: .22 * k),
            _kRiteGold.withValues(alpha: 0),
          ], const [0, .4, 1]),
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
    for (var y = 0; y < kRiteCircleSize; y += 64) {
      for (var x = 0; x < kRiteCircleSize; x += 64) {
        final r = Rect.fromLTWH(x.toDouble(), y.toDouble(), 64, 64);
        if ((r.center - ctr).distance > kRiteCircleRadius + 60) {
          _riteWall(c, r, x ~/ 64);
        }
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
        ..shader = ui.Gradient.radial(Offset.zero, r2, [
          _kRiteWall.stoneTop,
          Color.lerp(_kRiteWall.stoneTop, Colors.white, .06)!,
          _kRiteWall.stoneFace,
        ], [r1 / r2, (r1 + r2) / 2 / r2, 1]),
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
        ..shader = ui.Gradient.linear(a, b, [_kRiteBlood, _kRiteBloodHot.withValues(alpha: .9)]),
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
    paintCarvedDisc(canvas, c, kRiteSealRadius, kRiteSealRadius * .9, 8, _kRiteWall);
    const ir = kRiteSealRadius - 10;
    canvas.drawCircle(c, ir, Paint()..color = const Color(0xFF050203));
    if (k > 0) {
      canvas.drawCircle(
        c,
        ir,
        Paint()
          ..shader = ui.Gradient.radial(c, ir, [
            _kRiteBlood.withValues(alpha: (.18 + .08 * sin(_time * 2)) * k),
            _kRiteBloodDeep.withValues(alpha: .5 * k),
            Colors.black.withValues(alpha: 0),
          ], const [0, .6, 1]),
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
        ..lineTo(o.dx + cos(a0 + pi / 3) * ir * 1.15, o.dy + sin(a0 + pi / 3) * ir * 1.15)
        ..close();
      canvas.drawPath(
        leaf,
        Paint()
          ..shader = ui.Gradient.linear(
            o,
            o + dir * ir,
            [const Color(0xFF241517), const Color(0xFF130A0C)],
          ),
      );
      // A lit edge where one leaf meets the next.
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy)
          ..lineTo(o.dx + cos(a0) * ir * 1.15, o.dy + sin(a0) * ir * 1.15)
          ..lineTo(o.dx + cos(a0) * ir * 1.15 + 1.6, o.dy + sin(a0) * ir * 1.15 + 1.6)
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
          ..color = (lit
                  ? Color.lerp(_kRiteGold, elementColor(el), .35)!
                  : _kRiteBronze.withValues(alpha: .55))
              .withValues(alpha: 1 - .6 * k),
      );
    }
  }

  // ═══════════════════════════ EARTH ════════════════════════════════════

  void _riteDrawEarth(Canvas canvas) {
    final f = rites.earthFloor;
    canvas.drawPicture(_riteBake('earth', (c) {
      for (var y = 0; y < f.h; y++) {
        for (var x = 0; x < f.w; x++) {
          final r = _riteSq(x, y);
          if (f.plateOf(x, y) >= 0) {
            _riteFlag(c, r, x * 31 + y * 17);
            continue;
          }
          final ch = f.base[y][x];
          if (ch == '.' ) {
            _riteFlag(c, r, x * 31 + y * 17);
          } else {
            _riteWall(c, r, x);
          }
        }
      }
    }));
    // The plates, turned, and everything standing on them.
    for (var i = 0; i < f.plates.length; i++) {
      final p = f.plates[i];
      final cc = riteCentreOf(p.cx, p.cy);
      canvas.save();
      canvas.translate(cc.dx, cc.dy);
      canvas.rotate(rites.plateAng[i]);
      const rr = kRiteCell * 1.52;
      canvas.drawCircle(
        const Offset(0, 4),
        rr,
        Paint()..color = Colors.black.withValues(alpha: .4),
      );
      canvas.drawCircle(
        Offset.zero,
        rr,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, rr, [
            const Color(0xFF3A282A),
            const Color(0xFF2A1C1F),
          ]),
      );
      canvas.drawCircle(
        Offset.zero,
        rr - 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = _kRiteGold.withValues(alpha: .3),
      );
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final ch = f.base[p.cy + dy][p.cx + dx];
          final o = Offset(dx * kRiteCell, dy * kRiteCell);
          if (ch == 'X') {
            paintCarvedBlock(
              canvas,
              Rect.fromCenter(center: o - const Offset(0, 6), width: 50, height: 40),
              12,
              _kRiteWall,
              radius: 3,
            );
          } else if (TendrilFloor.isRoot(ch)) {
            _riteRoot(canvas, o, ch);
          } else if (ch == 'C') {
            canvas.drawCircle(o, 26, Paint()..color = const Color(0xFF0D0708));
            canvas.drawCircle(
              o,
              26,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = elementColor('Earth').withValues(alpha: .45),
            );
          }
        }
      }
      canvas.restore();
    }
    // Wall roots: bulbs pushing out of the stone.
    for (var y = 0; y < f.h; y++) {
      for (var x = 0; x < f.w; x++) {
        final ch = f.base[y][x];
        if (!TendrilFloor.isRoot(ch) || f.plateOf(x, y) >= 0) continue;
        final inward = Offset(
          x == 0 ? 18 : x == f.w - 1 ? -18 : 0,
          y == 0 ? 18 : y == f.h - 1 ? -18 : 0,
        );
        _riteRoot(canvas, riteCentreOf(x, y) + inward, ch);
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
    // The hub of each plate, on top.
    for (var i = 0; i < f.plates.length; i++) {
      final p = f.plates[i];
      final cc = riteCentreOf(p.cx, p.cy);
      final locked = tendrilLineOnPlate(f, rites.earth, i);
      paintCarvedDisc(canvas, cc, 20, 18, 5, _kRiteWall);
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
    // The captive in its hearth (it turns with the plate).
    final cpos = _riteCaptiveAt('Earth');
    _riteDrawCaptive(canvas, _riteEarthCaptiveShown(cpos), 'Earth');
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
    if (lead) {
      canvas.drawCircle(
        at,
        34,
        Paint()
          ..shader = ui.Gradient.radial(at, 34, [
            col.withValues(alpha: .4),
            col.withValues(alpha: 0),
          ]),
      );
    }
    canvas.drawCircle(
      at,
      19 * pulse,
      Paint()
        ..shader = ui.Gradient.radial(at - const Offset(6, 6), 21, [
          Color.lerp(col, Colors.white, .35)!,
          col,
          Color.lerp(col, Colors.black, .5)!,
        ], const [0, .55, 1]),
    );
    // Its mark, so pairs read without colour too: one to three pips.
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
    if (id == 'd' || id == 'w') {
      _riteElementSign(
        canvas,
        at,
        id == 'd' ? 'Earth' : 'Water',
        Colors.black.withValues(alpha: .45),
      );
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
                x == 0 ? 18 : x == f.w - 1 ? -18 : 0,
                y == 0 ? 18 : y == f.h - 1 ? -18 : 0,
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
    canvas.drawPath(path, tube(19, done ? col : Color.lerp(col, Colors.black, .18)!));
    canvas.save();
    canvas.translate(-2.5, -3);
    canvas.drawPath(
      path,
      tube(5, Color.lerp(col, Colors.white, .5)!.withValues(alpha: done ? .55 : .32)),
    );
    canvas.restore();
    // Led: a living head at the tip, swelling as it reaches.
    if (tip != null) {
      final sw = 1 + .08 * sin(_time * 6);
      canvas.drawCircle(tip, 15 * sw, Paint()..color = Color.lerp(col, Colors.black, .55)!);
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

  void _riteDrawWater(Canvas canvas) {
    final r = rites.waterRoom;
    canvas.drawPicture(_riteBake('water', (c) {
      for (var y = 0; y < r.h; y++) {
        for (var x = 0; x < r.w; x++) {
          final ch = r.fixed[y][x];
          final sq = _riteSq(x, y);
          if (ch == '#') {
            _riteWall(c, sq, x);
            continue;
          }
          _riteFlag(c, sq, x * 31 + y * 17 + 3);
          if (ch == '=') {
            c.drawRect(sq.deflate(6), Paint()..color = const Color(0xFF0B0607));
            for (var k = 1; k < 5; k++) {
              c.drawRect(
                Rect.fromLTWH(sq.left + 6 + k * 10.4 - 2, sq.top + 8, 4, sq.height - 16),
                Paint()..color = const Color(0xFF5E4E44),
              );
            }
          } else if (ch == 'C') {
            // The basin: a sunken trough in porphyry, glass-lined.
            c.drawRect(sq.deflate(4), Paint()..color = const Color(0xFF0E0709));
            c.drawRect(
              Rect.fromLTWH(sq.left + 4, sq.top + 4, sq.width - 8, 6),
              Paint()..color = Colors.black.withValues(alpha: .5),
            );
          }
        }
      }
    }));
    // THE TURN. The room tips over its middle: it narrows edge-on, darkening
    // as it goes, and opens the other way up. Nothing slides until it is
    // done (the play holds the settle back).
    final turning = rites.flipT < 1;
    final sq = turning ? cos(_riteEase(rites.flipT) * pi).abs() : 1.0;
    canvas.save();
    final mid = r.h * kRiteCell / 2;
    canvas.translate(0, mid);
    canvas.scale(1, max(.04, sq));
    canvas.translate(0, -mid);
    final from = rites.waterFrom;
    final playing = rites.waterFrames.isNotEmpty && from != null;
    // The fixed things as the pass being left has them; each one's moment
    // starts as its pass lands.
    final cells = playing ? from.cells : rites.water.cells;
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
            _riteBrazier(canvas, cc, since < .5, flame: 1 - _riteEase(since / .5));
          case '_':
            canvas.drawRect(
              _riteSq(x, y).deflate(5),
              Paint()
                ..shader = ui.Gradient.radial(cc, 32, [
                  Colors.black,
                  const Color(0xFF1A0D10),
                ]),
            );
          case 'p':
            final since = _time - (rites.pitT[k] ?? -99);
            final fill = _riteEase(since / .6);
            final rr = _riteSq(x, y).deflate(4);
            canvas.drawRect(rr, Paint()..color = Colors.black);
            canvas.drawRect(
              rr,
              Paint()
                ..shader = ui.Gradient.radial(cc, 34 * max(.2, fill), [
                  const Color(0xFF05121F),
                  const Color(0xFF1D4A72),
                ]),
            );
            // Rings on deep water, slow.
            for (var n = 0; n < 2; n++) {
              final t = ((_time * .45 + n * .5) % 1);
              canvas.drawCircle(
                cc,
                6 + t * 22,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3 * (1 - t)
                  ..color = const Color(0xFFC8E6FF).withValues(alpha: .28 * (1 - t) * fill),
              );
            }
          case 'c':
            // A basin square filling: the level rises.
            final since = _time - (rites.basinT[k] ?? -99);
            final lvl = _riteEase(since / .7);
            final sqr = _riteSq(x, y).deflate(4);
            final h = sqr.height * lvl;
            final top = rites.water.down == 2 ? sqr.bottom - h : sqr.top;
            _riteFluid(canvas, [Rect.fromLTWH(sqr.left, top, sqr.width, h)], 1, surfaceUp: rites.water.down == 2);
        }
      }
    }
    // The captive across the basin.
    _riteDrawCaptive(canvas, _riteCaptiveAt('Water'), 'Water');
    // The loose things, slid part-way along this pass.
    final items = _riteWaterItems();
    final waterRects = <Rect>[];
    final down = kRiteDy[rites.water.down].toDouble();
    for (final (kind, c, a, vel) in items) {
      final rr = Rect.fromCenter(center: c, width: kRiteCell, height: kRiteCell);
      if (kind == 'I') {
        canvas.saveLayer(rr.inflate(6), Paint()..color = Colors.white.withValues(alpha: a));
        _riteIce(canvas, rr);
        canvas.restore();
      } else {
        if (a > .98) waterRects.add(rr.deflate(2));
        // Moving water stretches back along its way, like water does.
        if (vel.distance > 1 && a > .98) {
          final dir = vel / vel.distance;
          final back = rr.deflate(2).shift(-dir * 22);
          waterRects.add(Rect.fromLTRB(
            min(back.left, rr.left + 2) + (dir.dx == 0 ? 8 : 0),
            min(back.top, rr.top + 2) + (dir.dy == 0 ? 8 : 0),
            max(back.right, rr.right - 2) - (dir.dx == 0 ? 8 : 0),
            max(back.bottom, rr.bottom - 2) - (dir.dy == 0 ? 8 : 0),
          ));
        }
        if (a <= .98) _riteFluid(canvas, [rr.deflate(2)], a, surfaceUp: down > 0);
      }
    }
    if (waterRects.isNotEmpty) _riteFluid(canvas, waterRects, 1, surfaceUp: down > 0);
    // Ice that has just melted, still going: it shrinks into its water.
    for (final e in rites.meltT.entries) {
      final since = _time - e.value;
      if (since > .7 || since < 0) continue;
      final p = e.key.split(',').map(int.parse).toList();
      final k = _riteEase(since / .7);
      final rr = Rect.fromCenter(
        center: riteCentreOf(p[0], p[1]) + Offset(0, down * 10 * k),
        width: kRiteCell * (1 - .55 * k),
        height: kRiteCell * (1 - .7 * k),
      );
      canvas.saveLayer(rr.inflate(8), Paint()..color = Colors.white.withValues(alpha: 1 - k));
      _riteIce(canvas, rr);
      canvas.restore();
    }
    // The ghost of the next flip: where things will come to rest.
    if (!playing && !turning && !flipSolved(rites.water)) {
      final next = flipTurn(r, rites.water).state!;
      final ghost = .26 + .06 * sin(_time * 3);
      for (final e in next.loose.entries) {
        if (rites.water.loose[e.key] == e.value) continue;
        final p = e.key.split(',').map(int.parse).toList();
        final rr = _riteSq(p[0], p[1]);
        canvas.saveLayer(rr.inflate(4), Paint()..color = Colors.white.withValues(alpha: ghost));
        if (e.value == 'I') {
          _riteIce(canvas, rr);
        } else {
          _riteFluid(canvas, [rr.deflate(2)], 1, surfaceUp: rites.water.down != 2);
        }
        canvas.restore();
      }
      for (var y = 0; y < r.h; y++) {
        for (var x = 0; x < r.w; x++) {
          if (rites.water.cells[y][x] == 'F' && next.cells[y][x] == 'f') {
            canvas.drawCircle(
              riteCentreOf(x, y),
              24,
              Paint()..color = const Color(0xFF3A6A9A).withValues(alpha: .22),
            );
          }
          if (rites.water.cells[y][x] == 'C' && next.cells[y][x] == 'c') {
            canvas.drawRect(
              _riteSq(x, y).deflate(8),
              Paint()..color = const Color(0xFF5AA7E0).withValues(alpha: .18),
            );
          }
        }
      }
    }
    // Edge-on, the room is in its own shadow.
    if (turning) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, r.w * kRiteCell, r.h * kRiteCell),
        Paint()..color = Colors.black.withValues(alpha: .6 * (1 - sq)),
      );
    }
    canvas.restore();
    // Downhill: two columns of filled chevrons at the side walls.
    final dn = rites.water.down == 2 ? 1.0 : -1.0;
    for (final side in [kRiteCell * .5, (r.w - .5) * kRiteCell]) {
      for (var k = 0; k < 3; k++) {
        final y = mid + (k - 1) * 30 + dn * ((_time * 30) % 30);
        final chev = Path()
          ..moveTo(side - 9, y - dn * 6)
          ..lineTo(side, y + dn * 4)
          ..lineTo(side + 9, y - dn * 6)
          ..lineTo(side + 9, y - dn * 1)
          ..lineTo(side, y + dn * 9)
          ..lineTo(side - 9, y - dn * 1)
          ..close();
        canvas.drawPath(chev, Paint()..color = _kRiteGold.withValues(alpha: .5 * (turning ? sq : 1)));
      }
    }
  }

  /// Every loose thing as it is drawn this frame — kind, centre, opacity
  /// and velocity — slid part-way through the pass being played: the moves
  /// the rules recorded, and whatever a pit or the basin is taking, fading.
  /// While the room turns, everything holds where it was.
  List<(String, Offset, double, Offset)> _riteWaterItems() {
    Offset centre(String k) {
      final p = k.split(',').map(int.parse).toList();
      return riteCentreOf(p[0], p[1]);
    }

    final from = rites.waterFrom;
    final to = rites.waterFrames.isNotEmpty ? rites.waterFrames.first : null;
    if (from == null || to == null || rites.flipT < 1) {
      final src = from?.loose ?? rites.water.loose;
      return [for (final e in src.entries) (e.value, centre(e.key), 1.0, Offset.zero)];
    }
    final k = (rites.waterFrameT / kRiteWaterPass).clamp(0.0, 1.0);
    final out = <(String, Offset, double, Offset)>[];
    for (final e in to.loose.entries) {
      final old = to.moves[e.key];
      if (old == null) {
        out.add((e.value, centre(e.key), 1.0, Offset.zero));
      } else {
        final a = centre(old), b = centre(e.key);
        out.add((e.value, Offset.lerp(a, b, k)!, 1.0, (b - a) / kRiteWaterPass));
      }
    }
    for (final e in to.gone.entries) {
      final kind = from.loose[e.key] ?? '~';
      final a = centre(e.key), b = centre(e.value);
      out.add((kind, Offset.lerp(a, b, k)!, 1 - k, (b - a) / kRiteWaterPass));
    }
    return out;
  }

  /// Water as one body: the squares it fills, run together, deep below and
  /// lit at its surface (the side away from downhill), with a slow shimmer.
  void _riteFluid(Canvas canvas, List<Rect> rects, double alpha, {required bool surfaceUp}) {
    if (rects.isEmpty) return;
    var body = Path();
    for (final r in rects) {
      body = Path.combine(
        PathOperation.union,
        body,
        Path()..addRRect(RRect.fromRectAndRadius(r.inflate(3), const Radius.circular(9))),
      );
    }
    final b = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          surfaceUp ? b.topCenter : b.bottomCenter,
          surfaceUp ? b.bottomCenter : b.topCenter,
          [
            const Color(0xFF5AA7E0).withValues(alpha: .92 * alpha),
            const Color(0xFF2F6E9E).withValues(alpha: .92 * alpha),
            const Color(0xFF18405F).withValues(alpha: .95 * alpha),
          ],
          const [0, .45, 1],
        ),
    );
    // The surface: a lit band along every top that has no water above it.
    final keys = {for (final r in rects) '${r.center.dx.round()},${r.center.dy.round()}'};
    for (final r in rects) {
      final above = Offset(r.center.dx, r.center.dy + (surfaceUp ? -kRiteCell : kRiteCell));
      if (keys.contains('${above.dx.round()},${above.dy.round()}')) continue;
      final y = surfaceUp ? r.top + 2 : r.bottom - 6;
      final w = sin(_time * 2.2 + r.left * .05) * 3;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 3, y, r.width - 6, 4), const Radius.circular(2)),
        Paint()..color = const Color(0xFFD8F0FF).withValues(alpha: .55 * alpha),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + 14 + w, y + (surfaceUp ? 9 : -7), r.width - 30, 2.5),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withValues(alpha: .22 * alpha),
      );
    }
  }

  void _riteIce(Canvas canvas, Rect sq) {
    final r = sq.deflate(5);
    canvas.drawRect(
      r.shift(const Offset(0, 4)),
      Paint()..color = Colors.black.withValues(alpha: .35),
    );
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, [
          const Color(0xFFE4F7FD),
          const Color(0xFF8FCDE3),
          const Color(0xFF3D7F9C),
        ], const [0, .5, 1]),
    );
    paintStreak(canvas, r.deflate(8), opacity: .8);
    paintLead(canvas, Path()..addRect(r), kFrostGlass, width: 2.4, opacity: .7);
  }

  void _riteBrazier(Canvas canvas, Offset c, bool lit, {double flame = 1}) {
    paintCarvedDisc(canvas, c + const Offset(0, 8), 22, 13, 8, _kRiteWall);
    canvas.drawOval(
      Rect.fromCenter(center: c + const Offset(0, 4), width: 34, height: 14),
      Paint()..color = _kRiteBronze,
    );
    if (lit) {
      canvas.drawCircle(
        c,
        46,
        Paint()
          ..shader = ui.Gradient.radial(c, 46, [
            const Color(0xFFEE7A3A).withValues(alpha: .3 + .06 * sin(_time * 9)),
            const Color(0x00EE7A3A),
          ]),
      );
      const cols = [Color(0xFFE2502A), Color(0xFFF08A3A), Color(0xFFFFD27A)];
      for (var k = 0; k < 3; k++) {
        final h = (26 + 5 * sin(_time * (7 + k) + k * 2)) * flame;
        final w = (11.0 - k * 2.5) * (.4 + .6 * flame);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - w, c.dy + 4)
            ..quadraticBezierTo(c.dx - w * .7, c.dy - h * .5, c.dx, c.dy - h + k * 3)
            ..quadraticBezierTo(c.dx + w * .7, c.dy - h * .5, c.dx + w, c.dy + 4)
            ..close(),
          Paint()..color = cols[k],
        );
      }
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: c + const Offset(0, 3), width: 26, height: 9),
        Paint()..color = const Color(0xFF120B0B),
      );
      for (var k = 0; k < 2; k++) {
        final t = (_time * .5 + k * .5) % 1;
        canvas.drawCircle(
          c + Offset(sin(t * 6 + k) * 5, -t * 30),
          4 + t * 6,
          Paint()..color = const Color(0xFFA09890).withValues(alpha: .22 * (1 - t)),
        );
      }
    }
  }

  // ═══════════════════════════ FIRE ═════════════════════════════════════

  void _riteDrawFire(Canvas canvas) {
    final r = rites.fireRoom;
    canvas.drawPicture(_riteBake('fire', (c) {
      for (var y = 0; y < r.h; y++) {
        for (var x = 0; x < r.w; x++) {
          final ch = r.cells[y][x];
          final sq = _riteSq(x, y);
          if (ch == '#') {
            _riteWall(c, sq, x);
          } else if (ch == '|' || ch == 'H') {
            c.drawRect(sq, Paint()..color = const Color(0xFF240A10));
          } else {
            _riteFlag(c, sq, x * 31 + y * 17 + 7);
            if (ch == 'O') {
              c.drawCircle(
                sq.center,
                26,
                Paint()
                  ..shader = ui.Gradient.radial(sq.center, 26, [
                    Colors.black,
                    const Color(0xFF1A0D10),
                  ]),
              );
            }
          }
        }
      }
    }));
    // The pool: blood, moving slowly, with the mirror's seam down its middle.
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        final ch = r.cells[y][x];
        if (ch != '|' && ch != 'H') continue;
        final sq = _riteSq(x, y);
        canvas.drawRect(
          Rect.fromLTRB(sq.left + 7, sq.top, sq.right - 7, sq.bottom),
          Paint()
            ..shader = ui.Gradient.linear(sq.centerLeft, sq.centerRight, [
              _kRiteBloodDeep,
              const Color(0xFFA01C2C),
              _kRiteBloodDeep,
            ], const [0, .5, 1]),
        );
        final o = sin(_time * 1.5 + y) * 4;
        canvas.drawRect(
          Rect.fromCenter(center: sq.center + Offset(o, 0), width: 2, height: sq.height * .7),
          Paint()..color = const Color(0x33FFD0D0),
        );
      }
    }
    final on = twinPressed(r, rites.fire);
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        final ch = r.cells[y][x];
        final cc = riteCentreOf(x, y);
        final sq = _riteSq(x, y);
        switch (ch) {
          case 'H':
            paintCarvedDisc(canvas, cc, 30, 26, 6, _kRiteWall);
            final hot = discoveredClouds.contains(riteFreedId('Fire')) ||
                rites.freedT.containsKey('Fire');
            if (hot) _riteBrazier(canvas, cc, true);
            _riteDrawCaptive(canvas, cc, 'Fire');
          case 'B':
            // Bellows: two boards and a leather fold, pointed at the hearth.
            final dir = r.cells[y][x + 1] == '|' || r.cells[y][x + 1] == 'H' ? 1.0 : -1.0;
            canvas.drawPath(
              Path()
                ..moveTo(cc.dx - dir * 22, cc.dy - 17)
                ..lineTo(cc.dx + dir * 18, cc.dy - 5)
                ..lineTo(cc.dx + dir * 18, cc.dy + 5)
                ..lineTo(cc.dx - dir * 22, cc.dy + 17)
                ..close(),
              Paint()..color = const Color(0xFF4A2F1F),
            );
            canvas.drawRect(
              Rect.fromCenter(center: cc + Offset(dir * 24, 0), width: 12, height: 7),
              Paint()..color = _kRiteBronze,
            );
            if (rites.fire.b == (x: x, y: y)) {
              canvas.drawCircle(
                cc + Offset(dir * 34, 0),
                22,
                Paint()
                  ..shader = ui.Gradient.radial(cc + Offset(dir * 34, 0), 22, [
                    elementColor('Air').withValues(alpha: .45),
                    elementColor('Air').withValues(alpha: 0),
                  ]),
              );
            }
          case 'L':
            canvas.drawRect(sq.deflate(6), Paint()..color = const Color(0xFF140A08));
            canvas.drawRect(
              Rect.fromLTWH(sq.left + 10, sq.top + 22, sq.width - 20, 20),
              Paint()
                ..shader = ui.Gradient.linear(sq.centerLeft, sq.centerRight, [
                  const Color(0xFFFF9A3D),
                  const Color(0xFFA3240F),
                ]),
            );
            canvas.drawCircle(
              cc,
              40,
              Paint()
                ..shader = ui.Gradient.radial(cc, 40, [
                  const Color(0xFFFF7A2A).withValues(alpha: .25 + .07 * sin(_time * 4)),
                  const Color(0x00FF7A2A),
                ]),
            );
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
            // The portcullis slides up into the lintel as it opens.
            final lift = sq.height * .62 * _riteEase(shown);
            for (var k = 1; k < 4; k++) {
              canvas.drawRect(
                Rect.fromLTWH(sq.left + k * sq.width / 4 - 2.5, sq.top + 4, 5, sq.height - 8 - lift),
                Paint()..color = Color.lerp(col, Colors.black, .35)!.withValues(alpha: 1 - .55 * shown),
              );
            }
            canvas.drawRect(
              Rect.fromLTWH(sq.left + 6, sq.top + sq.height / 2 - 3 - lift / 2, sq.width - 12, 6),
              Paint()..color = col.withValues(alpha: .9 - .45 * shown),
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
          ..colorFilter = const ColorFilter.mode(Color(0xCC8A1626), BlendMode.srcATop),
      );
      canvas.restore();
    } else {
      canvas.drawCircle(t, 16, Paint()..color = const Color(0xFF8A1626));
    }
  }

  // ═══════════════════════════ AIR ══════════════════════════════════════

  void _riteDrawAir(Canvas canvas) {
    final r = rites.airRoom;
    canvas.drawPicture(_riteBake('air', (c) {
      for (var y = 0; y < r.h; y++) {
        for (var x = 0; x < r.w; x++) {
          final ch = r.cells[y][x];
          final sq = _riteSq(x, y);
          if (ch == '#') {
            _riteWall(c, sq, x);
            continue;
          }
          // Open air: the floor is far below, dim and soft.
          final v = _riteHash(x * 7 + y * 13);
          c.drawRect(sq, Paint()..color = Color.lerp(const Color(0xFF140E12), const Color(0xFF1C1418), v)!);
          if (ch == '*') {
            c.drawRect(
              sq,
              Paint()
                ..shader = ui.Gradient.radial(sq.center, 46, [
                  const Color(0x66FFECB4),
                  const Color(0x00FFECB4),
                ]),
            );
          }
        }
      }
    }));
    // Motes: the room has no floor to settle on.
    for (var i = 0; i < 40; i++) {
      final fx = _riteHash(i * 3), fy = _riteHash(i * 5 + 1), sp = _riteHash(i * 7 + 2);
      final x = kRiteCell + ((fx + _time * .01 * (sp - .5)) % 1) * (r.w - 2) * kRiteCell;
      final y = kRiteCell + ((fy - _time * .015 * (.3 + sp)) % 1 + 1) % 1 * (r.h - 2) * kRiteCell;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 1.6, 1.6),
        Paint()..color = const Color(0xFFDCE6F0).withValues(alpha: .12 + .12 * sp),
      );
    }
    // Sunlight falling through the roof.
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        if (r.cells[y][x] != '*') continue;
        final sq = _riteSq(x, y);
        canvas.drawRect(sq.deflate(6), Paint()..color = const Color(0xFFFFF0C8).withValues(alpha: .14));
        for (var k = 0; k < 4; k++) {
          final t = (_time * .4 + k / 4) % 1;
          canvas.drawRect(
            Rect.fromLTWH(sq.left + 12 + 40 * _riteHash(x * 9 + y * 3 + k), sq.top + 6 + 52 * t, 2, 2),
            Paint()..color = const Color(0xFFFFF0C8).withValues(alpha: .6 * (1 - t)),
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
            Paint()..color = (i % 3 == 0 ? const Color(0xFFFFE6A0) : const Color(0xFFDCEBF2)).withValues(alpha: .75),
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
          ..arcToPoint(Offset(cc.dx + 25, cc.dy - 4), radius: const Radius.circular(25))
          ..lineTo(cc.dx + 25, cc.dy + 26)
          ..close();
        paintPaneFill(canvas, dome, const Color(0x22D2E6F0));
        paintStreak(canvas, Rect.fromLTWH(cc.dx - 20, cc.dy - 24, 18, 36), opacity: .6);
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
    final end = drifting
        ? (rites.iceMelted ?? rites.icePath.last)
        : null;
    for (final k in rites.air.ice) {
      final p = k.split(',').map(int.parse).toList();
      if (end != null && rites.iceMelted == null && p[0] == end.x && p[1] == end.y) {
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
        canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: 1 - max(0.0, (rites.driftT - .6) / .4)));
      }
      _riteIce(canvas, Rect.fromLTWH(at.dx, at.dy, kRiteCell, kRiteCell));
      if (rites.iceMelted != null) canvas.restore();
      canvas.restore();
    }
  }

  // ═══════════════════════════ THE VAULT, THE SHELL ═════════════════════

  void _riteDrawVault(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(_riteBake('vault', (c) {
      for (var y = 0.0; y < b.height; y += 64) {
        for (var x = 0.0; x < b.width; x += 64) {
          final r = Rect.fromLTWH(x, y, 64, 64);
          final edge = y == 0 || x == 0 || x + 64 >= b.width || y + 64 >= b.height;
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
    }));
  }

  /// Sanguorath's shell: a sphere of the element its opposite breaks.
  void _riteDrawShell(Canvas canvas) {
    // The sacrifice plays over everything: the ally, its grains, and the
    // shell shedding as it takes them.
    final sac = rites.sacrifice;
    final g = _guardianEnemy;
    final el = rites.shellUp ? rites.shellElement : (sac != null ? rites.shedElement : null);
    if (el != null && g != null && !g.isDead) {
      _riteShellBody(canvas, g.position, el, sac?.shedK ?? 0, taken: sac?.takenK ?? 0);
    }
    if (sac != null) {
      final c = rites.sacrificed;
      final at = sac.from;
      // Blood rises round it before it goes.
      final rise = sac.riseK;
      if (rise > .01) {
        canvas.drawOval(
          Rect.fromCenter(center: at + const Offset(0, 16), width: 60 * rise, height: 18 * rise),
          Paint()..color = _kRiteBlood.withValues(alpha: .55 * rise),
        );
      }
      // The body above the crest is still itself.
      final ticker = c?.ticker;
      if (sac.cut < 1) {
        canvas.save();
        if (sac.cut > 0) {
          const half = kRiteSnapBox / 2;
          canvas.clipRect(Rect.fromLTRB(at.dx - half, at.dy - half, at.dx + half, at.dy + sac.crestLocal));
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
  void _riteShellBody(Canvas canvas, Offset c, String el, double shed, {double taken = 0}) {
    final col = Color.lerp(elementColor(el), _kRiteBlood, taken)!;
    final k = _riteEase((_time - rites.shellT) / .7);
    final r = 64 * k * (1 + shed * .5);
    final a = 1 - shed;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(c, r, [
          col.withValues(alpha: 0),
          col.withValues(alpha: .18 * a),
          col.withValues(alpha: .5 * a),
        ], const [0, .7, 1]),
    );
    for (var i = 0; i < 18; i++) {
      final ang = i * pi * 2 / 18 + _time * (el == 'Air' ? 1.6 : .3) + shed * _riteHash(i) * 1.5;
      final p = c + Offset(cos(ang), sin(ang)) * (r + shed * 40 * _riteHash(i + 3));
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
            Paint()..color = const Color(0xFFF08A3A).withValues(alpha: .85 * pa),
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
              ..lineTo(p.dx + n.dx * 14 + cos(ang) * 3, p.dy + n.dy * 14 + sin(ang) * 3)
              ..lineTo(p.dx + n.dx * 14 - cos(ang) * 3, p.dy + n.dy * 14 - sin(ang) * 3)
              ..close(),
            Paint()..color = const Color(0xFFDCEBF2).withValues(alpha: .7 * pa),
          );
      }
    }
  }
}
