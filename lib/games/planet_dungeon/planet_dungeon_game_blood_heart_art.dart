// lib/games/planet_dungeon/planet_dungeon_game_blood_heart_art.dart
//
// HEMAVORN — THE HEART, drawn as a THEATRE (the author, 2026-10-06: "stages
// on the bottom with the open space like area up top where a theatre of
// elements can occur" — no cave). A stage of carved porphyry runs along the
// bottom, its altars and split stage set into it; above it the room is open
// dark, lit from the stage's edge, each altar's column faintly lit up into
// it. In that open space elements hang and drift, each in grains of itself
// (a Spirit wisp, a Lava glob, an Earth clod), and Blood is bound at the top.
// Then the moments — bodies coming apart and gathering, every element rising
// up its column (blood_heart_fx.dart), what hangs there drawn into it as the
// two fuse, and what they make pouring down.
// Stone and dark baked once; per frame only what moves. No blur.

part of 'planet_dungeon_game.dart';

/// Where the stage's top begins (its back edge, against the open space).
const double _kHeartStageTop = 6 * kRiteCell;

/// Where the stage's front face begins.
const double _kHeartStageFront = 8 * kRiteCell;

extension BloodHeartArt on PlanetDungeonGame {
  void _heartDraw(Canvas canvas) {
    final h = rites.heart;
    final r = h.room;
    canvas.drawPicture(_riteBake('heart_theatre', (c) => _heartBake(c, r)));
    _heartMotes(canvas);
    _heartBinding(canvas);
    _heartAltars(canvas);
    _heartSplitStage(canvas);
    if (h.freed) _heartWayDown(canvas);
    // The elements hanging in the open space, and any being drawn into
    // what rose to it.
    for (var y = 0; y < r.h; y++) {
      for (var x = 0; x < r.w; x++) {
        final k = '$x,$y';
        final hanging =
            h.pending[k] ??
            (h.state.cells[y][x] == kHeartHanging ? h.state.holds[k] : null);
        if (hanging != null) _heartHanging(canvas, hanging, x, y);
        final gone = h.broke[k];
        if (gone != null) {
          final since = _time - gone.$2;
          if (since < .8) {
            _heartMeet(canvas, gone.$1, x, y, since);
          } else {
            h.broke.remove(k);
            _heartMeetGrains.remove(k);
          }
        }
      }
    }
    // Every element rising up its column, in grains of the creature that
    // made it, and the creature coming back as they land.
    for (final p in h.powers) {
      final t = p.t - kHeartPowerAt;
      if (t < 0) continue;
      final a = p.fx.spriteAlpha(t);
      if (a > .01) _heartSprite(canvas, p.made, p.fx.at, alpha: a);
      p.fx.paint(canvas, rites.batch, t, _time);
    }
    // Bodies coming apart and gathering.
    for (final m in h.morphs) {
      for (var i = 0; i < m.sources.length; i++) {
        final (c, at) = m.sources[i];
        if (m.fx.cut >= 1) continue;
        const half = kRiteSnapBox / 2;
        final crest = i < m.fx.sources.length ? m.fx.crestLocal(i) : -half;
        _heartSprite(
          canvas,
          c,
          at,
          clip: Rect.fromLTRB(at.dx - half, at.dy + crest, at.dx + half, at.dy + half),
        );
      }
      for (final (c, at) in m.targets) {
        final a = m.fx.reveal;
        if (a > .01) _heartSprite(canvas, c, at, alpha: a);
      }
      m.fx.paint(canvas, rites.batch, _time);
    }
    // The names of what was tapped, coming out of it and drifting away.
    for (final w in h.words.values) {
      w.paint(canvas, rites.batch, _time);
    }
    // A pair that would not fuse: a breath of their colours, and nothing.
    final fz = h.fizzleAt;
    if (fz != null && _time - h.fizzleT < .9) {
      paintHeartFizzle(rites.batch, fz, _time - h.fizzleT, h.fizzleCols[0], h.fizzleCols[1]);
      rites.batch.paint(canvas);
    }
  }

  /// A creature's sprite, as the engine would draw it but plain: at [alpha],
  /// and only inside [clip].
  void _heartSprite(
    Canvas canvas,
    DungeonCreature c,
    Offset at, {
    double alpha = 1,
    Rect? clip,
    double scale = 1,
    ColorFilter? tint,
  }) {
    final ticker = c.ticker;
    canvas.save();
    if (clip != null) canvas.clipRect(clip);
    if (ticker != null) {
      canvas.translate(at.dx, at.dy);
      canvas.scale(c.spriteScale * scale, c.spriteScale * scale);
      ticker.getSprite().render(
        canvas,
        anchor: Anchor.center,
        overridePaint: Paint()
          ..filterQuality = ui.FilterQuality.high
          ..colorFilter = tint
          ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    } else {
      canvas.drawCircle(
        at,
        15 * scale,
        Paint()..color = elementColor(c.member.element).withValues(alpha: .8 * alpha),
      );
    }
    canvas.restore();
  }

  // ── The bake: the open space and the stage ───────────────

  void _heartBake(Canvas c, HeartRoom r) {
    final b = Rect.fromLTWH(0, 0, r.w * kRiteCell, r.h * kRiteCell);
    final world = b.inflate(640);
    // The open space: black, warming toward the stage.
    c.drawRect(world, Paint()..color = const Color(0xFF040102));
    c.drawRect(
      Rect.fromLTRB(world.left, b.top - 120, world.right, _kHeartStageTop),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, b.top - 120),
          const Offset(0, _kHeartStageTop),
          const [Color(0xFF040102), Color(0xFF0B0405), Color(0xFF1A0A0D)],
          const [0, .6, 1],
        ),
    );
    // The stage's edge throws its light up into the open space.
    c.drawRect(
      Rect.fromLTRB(b.left, _kHeartStageTop - 190, b.right, _kHeartStageTop),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, _kHeartStageTop),
          const Offset(0, _kHeartStageTop - 190),
          [_kRiteBlood.withValues(alpha: .13), _kRiteBlood.withValues(alpha: 0)],
        ),
    );
    // Far grains, hanging still in the dark.
    final grain = Paint();
    for (var i = 0; i < 170; i++) {
      final p = Offset(
        b.left - 120 + _riteHash(i * 7 + 1) * (b.width + 240),
        b.top - 100 + _riteHash(i * 11 + 3) * (_kHeartStageTop - b.top + 70),
      );
      final warm = _riteHash(i * 5 + 2);
      grain.color = Color.lerp(const Color(0xFFE8D2CC), _kRiteBlood, warm)!
          .withValues(alpha: .07 + .22 * _riteHash(i * 13 + 4));
      c.drawCircle(p, .6 + 1.3 * _riteHash(i * 17 + 5), grain);
    }
    // Each altar's column, faintly lit up into the open space.
    for (final a in r.altars) {
      final cx = riteCentreOf(a.front.x, a.front.y).dx;
      for (final (w, k) in const [(54.0, .07), (24.0, .06)]) {
        c.drawRect(
          Rect.fromLTRB(cx - w / 2, b.top - 60, cx + w / 2, _kHeartStageTop),
          Paint()
            ..shader = ui.Gradient.linear(
              const Offset(0, _kHeartStageTop),
              Offset(0, b.top - 60),
              [_kRiteGold.withValues(alpha: k), _kRiteGold.withValues(alpha: 0)],
            ),
        );
      }
    }
    // The stage top: carved flags from end to end.
    for (var y = 6; y <= 7; y++) {
      for (var x = 1; x < r.w - 1; x++) {
        _riteFlag(c, _riteSq(x, y), x * 31 + y * 17 + 5);
      }
    }
    // Its back edge against the open space: the arris lit, a gold inlay just
    // in from it.
    final edge = Rect.fromLTRB(kRiteCell, _kHeartStageTop, b.right - kRiteCell, _kHeartStageTop + 3);
    c.drawRect(edge, Paint()..color = const Color(0xFF8A5A60));
    c.drawRect(
      Rect.fromLTWH(edge.left + 6, edge.top + 8, edge.width - 12, 2),
      Paint()..color = _kRiteGold.withValues(alpha: .28),
    );
    // Its front face, carved, going down into the dark.
    final face = Rect.fromLTRB(b.left, _kHeartStageFront, b.right, b.bottom + 40);
    c.drawRect(
      face,
      Paint()
        ..shader = ui.Gradient.linear(face.topCenter, face.bottomCenter, [
          _kRiteWall.stoneFace,
          _kRiteWall.stoneFoot,
          const Color(0xFF040102),
        ], const [0, .6, 1]),
    );
    for (var x = 0; x < r.w; x++) {
      // Panels: a sunk field in each, its lower lip catching the light.
      final p = Rect.fromLTWH(x * kRiteCell + 8, _kHeartStageFront + 14, kRiteCell - 16, 30);
      c.drawRect(p, Paint()..color = Colors.black.withValues(alpha: .32));
      c.drawRect(Rect.fromLTWH(p.left, p.bottom - 1.6, p.width, 1.6), Paint()..color = const Color(0xFF3A2026));
      c.drawRect(
        Rect.fromLTWH(x * kRiteCell, _kHeartStageFront, 1.4, 56),
        Paint()..color = Colors.black.withValues(alpha: .5),
      );
    }
    c.drawRect(
      Rect.fromLTWH(b.left, _kHeartStageFront + 6, b.width, 2),
      Paint()..color = _kRiteGold.withValues(alpha: .3),
    );
    c.drawRect(
      Rect.fromLTWH(b.left, _kHeartStageFront, b.width, 2.2),
      Paint()..color = Color.lerp(_kRiteWall.stoneTop, const Color(0xFFF2CFC8), .45)!.withValues(alpha: .85),
    );
    // The stage's two ends: porphyry posts standing up above it.
    for (final x in [0, r.w - 1]) {
      for (final y in const [6, 7]) {
        _riteWallCell(
          c,
          _riteSq(x, y),
          x * 31 + y * 17,
          front: y == 7,
          shadow: false,
          back: y == 6,
          left: x > 0,
          right: x == 0,
        );
      }
    }
  }

  /// A few grains rising slowly through the open space.
  void _heartMotes(Canvas canvas) {
    final paint = Paint();
    final w = rites.heart.room.w * kRiteCell;
    for (var i = 0; i < 26; i++) {
      final period = 9 + 6 * _riteHash(i * 3 + 1);
      final ph = (_time / period + _riteHash(i * 7 + 2)) % 1;
      final x = _riteHash(i * 11 + 5) * w + sin(_time * .4 + i) * 10;
      final y = _kHeartStageTop - 10 - ph * (_kHeartStageTop + 20);
      paint.color = Color.lerp(const Color(0xFFF0D6CC), _kRiteBlood, _riteHash(i))!
          .withValues(alpha: .35 * sin(ph * pi));
      canvas.drawCircle(Offset(x, y), 1 + _riteHash(i * 5 + 3), paint);
    }
  }

  // ── Blood, bound ─────────────────────────────────────────

  /// Blood bound at the top of the open space, held in bands of its own
  /// blood. Before it is taken the binding waits there, empty and faint.
  void _heartBinding(Canvas canvas) {
    final h = rites.heart;
    if (h.freed && !h.bound) return;
    final at = riteCentreOf(h.room.blood.x, h.room.blood.y);
    final b = h.blood;
    final held = h.bound && b != null;
    // Its glow beats with the planet's heart.
    final beat = riteBeat;
    vfxSpill(canvas, at, (held ? 78 : 52) + 10 * beat, _kRiteBlood, (held ? .2 : .08) + .14 * beat);
    if (held) _heartSprite(canvas, b, at, alpha: .92);
    // The bands, blood running round them: closing on it as it is bound,
    // letting go at the end; while it waits, a ghost of them.
    paintHeartBands(
      rites.batch,
      at,
      held ? _riteEase((_time - h.boundT) / .7) : 1,
      h.bandsK,
      _time,
      alpha: held ? 1 : .3,
      beat: beat,
    );
    rites.batch.paint(canvas);
  }

  // ── The stage ────────────────────────────────────────────

  /// Each altar: two carved stones, the front one notched the way its power
  /// goes (up into the open space).
  void _heartAltars(Canvas canvas) {
    final h = rites.heart;
    for (final a in h.room.altars) {
      final d = Offset(kRiteDx[a.dir].toDouble(), kRiteDy[a.dir].toDouble());
      for (final (cell, isFront) in [(a.back, false), (a.front, true)]) {
        final c = riteCentreOf(cell.x, cell.y);
        vfxSpill(canvas, c, 40, _kRiteBlood, .1);
        paintCarvedDisc(canvas, c + const Offset(0, 4), 24, 18, 7, _kRiteWall,
            topColor: isFront ? const Color(0xFF55343B) : null);
        // The stone's face: a shallow dish with a ring of gold inlay.
        canvas.drawOval(
          Rect.fromCenter(center: c + const Offset(0, 4), width: 30, height: 20),
          Paint()..color = const Color(0xFF1C0E12),
        );
        final inlay = Path()
          ..addOval(Rect.fromCenter(center: c + const Offset(0, 4), width: 30, height: 20))
          ..addOval(Rect.fromCenter(center: c + const Offset(0, 4), width: 25, height: 15))
          ..fillType = PathFillType.evenOdd;
        canvas.drawPath(inlay, Paint()..color = _kRiteGold.withValues(alpha: isFront ? .55 : .35));
        if (isFront) {
          // The notch: a filled point the way the power goes.
          final tip = c + const Offset(0, 4) + d * 24;
          final side = Offset(-d.dy, d.dx) * 6;
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(tip.dx - d.dx * 10 + side.dx, tip.dy - d.dy * 10 + side.dy)
              ..lineTo(tip.dx - d.dx * 10 - side.dx, tip.dy - d.dy * 10 - side.dy)
              ..close(),
            Paint()..color = _kRiteGold.withValues(alpha: .75),
          );
        }
      }
    }
  }

  /// The split stage: a disc cut clean in two, its halves apart, faint gold
  /// in the cut.
  void _heartSplitStage(Canvas canvas) {
    for (final s in rites.heart.room.splits) {
      final c = riteCentreOf(s.x, s.y) + const Offset(0, 4);
      vfxSpill(canvas, c, 36, _kRiteGold, .12 + .03 * sin(_time * 1.4));
      for (final k in const [-1.0, 1.0]) {
        canvas.save();
        canvas.clipRect(k < 0
            ? Rect.fromLTRB(c.dx - 40, c.dy - 40, c.dx - 2, c.dy + 40)
            : Rect.fromLTRB(c.dx + 2, c.dy - 40, c.dx + 40, c.dy + 40));
        paintCarvedDisc(canvas, c + Offset(k * 3, 0), 24, 18, 7, _kRiteWall);
        canvas.restore();
      }
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 3, height: 30),
        Paint()..color = _kRiteGold.withValues(alpha: .4 + .15 * sin(_time * 2)),
      );
    }
  }

  /// Once Blood is free, the stage opens: steps going down into the dark.
  void _heartWayDown(Canvas canvas) {
    final c = riteCentreOf(kRiteHeartWayDown.x, kRiteHeartWayDown.y);
    final hole = Rect.fromCenter(center: c, width: 48, height: 48);
    canvas.drawRRect(RRect.fromRectAndRadius(hole, const Radius.circular(6)), Paint()..color = const Color(0xFF030102));
    for (var i = 0; i < 4; i++) {
      final y = hole.top + 6 + i * 10.0;
      canvas.drawRect(
        Rect.fromLTWH(hole.left + 6 + i * 2, y, hole.width - 12 - i * 4, 5),
        Paint()..color = Color.lerp(_kRiteWall.stoneTop, Colors.black, .3 + i * .17)!,
      );
    }
    vfxSpill(canvas, c, 40, _kRiteBlood, .2 + .05 * sin(_time * 2));
  }

  // ── What hangs in the open space ─────────────────────────

  /// Everything up there drifts a little, each at its own pace.
  Offset _heartBob(int x, int y) => Offset(0, sin(_time * .9 + x * 1.7 + y * .6) * 3);

  /// The element hanging at (x, y): its Codex orb (made once, by element
  /// and square).
  ElementOrb _heartOrb(String el, int x, int y) => _heartOrbCache.putIfAbsent(
    '$el$x,$y',
    () => ElementOrb(EssenceElement.of(el), radius: kHeartOrbRadius),
  );

  /// Each orb turns on its own clock, so no two turn together.
  double _heartOrbTime(int x, int y) => _time + x * 1.7 + y * .9;

  /// An element hanging in the open space: its orb, drifting.
  void _heartHanging(Canvas canvas, String el, int x, int y) {
    final c = _riteSq(x, y).center + _heartBob(x, y);
    _heartOrb(el, x, y).paint(canvas, c, _heartOrbTime(x, y));
  }

  /// An orb reached by what rose and fusing with it: its glass goes and its
  /// grains swirl in ([paintHeartMeet]).
  void _heartMeet(Canvas canvas, String el, int x, int y, double since) {
    final c = _riteSq(x, y).center + _heartBob(x, y);
    final orb = _heartOrb(el, x, y);
    final g = _heartMeetGrains.putIfAbsent('$x,$y', () => orb.grainsAt(_heartOrbTime(x, y)));
    final glass = 1 - _riteEase(since / .3);
    if (glass > .01) orb.paint(canvas, c, _heartOrbTime(x, y), grains: false, opacity: glass);
    paintHeartMeet(rites.batch, g, c, since);
    rites.batch.paint(canvas);
  }
}

final Map<String, ElementOrb> _heartOrbCache = {};
final Map<String, SpecimenGrains> _heartMeetGrains = {};
