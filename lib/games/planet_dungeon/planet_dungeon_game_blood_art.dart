// lib/games/planet_dungeon/planet_dungeon_game_blood_art.dart
//
// HEMAVORN, IN GLASS (docs/dungeons.md §7.11) — Blood's stone and the glass it
// signals with, as a part of planet_dungeon_game.dart.
//
// A living heart is not a building, so its carved edge is PORPHYRY — dark,
// garnet-veined, the stone the heart looks cut from — baked, with garnet glass
// in its doorways and a low dark-red haze in place of the grey fog that lay
// over every chamber. The tissue floor, which beats, is untouched. The glass:
//
//   · a stopcock's stub is a vessel of garnet glass — lit crimson and
//     flowing while it carries, smoked while it is dead, dull untouched;
//   · and THE BLOOD IS THE LIFE — the maxim — used to leave run state only.
//     Once found, every cock in the eight wears a garnet heart of leaded
//     glass, lighting in turn as the rite binds: every road carries, for
//     good.

part of 'planet_dungeon_game.dart';

const GlassPalette _kSanguineGlass = kSanguineGlass;

final Map<String, ui.Picture> _heartShellCache = {};

extension SanguineOrreryArt on PlanetDungeonGame {
  void _updateBloodGlass(double dt) {
    final target =
        discoveredClouds.contains(kBloodLifeEggId) ||
            _ritePendingEgg == kBloodLifeEggId
        ? 1.0
        : 0.0;
    if (_lifeShown < 0) {
      _lifeShown = target;
    } else if (_lifeShown < target) {
      _lifeShown = min(target, _lifeShown + dt / 2.4);
    } else if (_lifeShown > target) {
      _lifeShown = target;
    }
  }

  void _renderHeartShell(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _heartShellCache.putIfAbsent(
        '${room.id}|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          paintCarvedRoomShell(
            Canvas(rec),
            b,
            _kSanguineGlass,
            GlassRng(glassSeed(room.id, b)),
            doors: [
              for (final d in room.doors)
                if (_doorOnWall(room, d)) d.rect,
            ],
            faceDepth: 36,
            arcade: false,
            flags: false,
          );
          return rec.endRecording();
        },
      ),
    );
  }

  /// A cock's stub of vessel, as a leaded glass tube.
  void _drawVesselGlass(
    Canvas canvas,
    Rect stub, {
    required bool grafted,
    required bool dead,
  }) {
    final tube = Path()
      ..addRRect(RRect.fromRectAndRadius(stub, const Radius.circular(8)));
    paintPane(
      canvas,
      tube,
      grafted
          ? _kSanguineGlass.live
          : dead
          ? _kSanguineGlass.smoke
          : _kSanguineGlass.frostAt(1),
      _kSanguineGlass,
      lead: 2,
    );
    // Two cames across it: it is glazed in three lengths.
    for (final t in const [0.34, 0.67]) {
      final y = stub.top + stub.height * t;
      canvas.drawLine(
        Offset(stub.left + 1, y),
        Offset(stub.right - 1, y),
        Paint()
          ..strokeWidth = 1.6
          ..color = _kSanguineGlass.lead,
      );
    }
    if (grafted) {
      paintStreak(canvas, stub.deflate(3), opacity: 0.5);
    }
  }

  /// THE BLOOD IS THE LIFE: a garnet heart of leaded glass on a cock. [i]
  /// staggers the lighting round the eight as the rite binds.
  void _drawLifeHeart(Canvas canvas, Offset at, int i) {
    final o = ((_lifeShown - i * 0.06) / 0.5).clamp(0.0, 1.0);
    if (o <= 0) return;
    final c = at + const Offset(0, -40);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        34,
        _kSanguineGlass.live.withValues(
          alpha: o < 1 ? 0.4 * o : 0.22 + 0.06 * sin(_time * 3 + i),
        ),
      );
    }
    final s = 15 * o;
    Path lobe(double side) => Path()
      ..moveTo(c.dx, c.dy + s * 1.1)
      ..cubicTo(
        c.dx + side * s * 1.6,
        c.dy + s * 0.2,
        c.dx + side * s * 1.1,
        c.dy - s * 1.1,
        c.dx,
        c.dy - s * 0.35,
      )
      ..close();
    paintPane(
      canvas,
      lobe(-1),
      _kSanguineGlass.live,
      _kSanguineGlass,
      lead: 1.8,
    );
    paintPane(
      canvas,
      lobe(1),
      Color.lerp(_kSanguineGlass.live, _kSanguineGlass.liveDeep, 0.35)!,
      _kSanguineGlass,
      lead: 1.8,
    );
    paintStreak(
      canvas,
      Rect.fromCenter(center: c - Offset(s * 0.5, 0), width: s, height: s),
      opacity: 0.6 * o,
    );
  }
}

// ── THE OBSTACLES, AS BODY (2026-09-25 review) ─────────────
//
// Every room's obstacle was the shared renderer's rounded bar in a crimson
// tint: a fallen rib, a collapsed span, a keystone, a baffle and a knot of
// capillary all arrived as the same pill. Each is now the thing its layout
// comment names, with the footing every solid object in the set carries (a
// contact shadow and a near face), and the tissue ones swell a little on the
// beat like the walls do.

const Color _kObBone = Color(0xFFE2D3BA);
const Color _kObBoneShade = Color(0xFF9A8468);
const Color _kObMeat = Color(0xFF6E1826);
const Color _kObMeatLit = Color(0xFFA83A48);
const Color _kObVessel = Color(0xFF3A0A14);

extension SanguineOrreryObstacles on PlanetDungeonGame {
  void _renderHeartObstacles(Canvas canvas, DungeonRoom room) {
    final swell = _heartSwell();
    for (final w in room.walls) {
      // Footing: a wide faint pool and a tight dark one.
      canvas.drawOval(
        w.inflate(10).translate(3, 9),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.22),
      );
      canvas.drawOval(
        w.inflate(2).translate(2, 6),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.35),
      );
      switch (room.id) {
        case 'pericard_gate':
          _drawBone(canvas, w, curve: 14);
        case 'aortic_arch':
          _drawKeystone(canvas, w);
        case 'vena_crossing':
          _drawBaffle(canvas, w, swell);
        case 'capillary_weave':
          _drawCapillaryKnot(canvas, w, swell);
        default:
          _drawCollapsedVessel(canvas, w, swell);
      }
    }
  }

  /// A rib: a long curved bone, knuckled at both ends, lit along its crest.
  void _drawBone(Canvas canvas, Rect w, {double curve = 0}) {
    final a = Offset(w.left + 8, w.center.dy + curve * 0.3);
    final z = Offset(w.right - 8, w.center.dy + curve * 0.3);
    final mid = Offset(w.center.dx, w.center.dy - curve);
    Path band(double hw, double lift) {
      final p = Path();
      const n = 16;
      final top = <Offset>[], bot = <Offset>[];
      for (var i = 0; i <= n; i++) {
        final u = i / n;
        final pt = Offset.lerp(
          Offset.lerp(a, mid, u)!,
          Offset.lerp(mid, z, u)!,
          u,
        )!;
        final h = hw * (0.75 + 0.25 * (4 * (u - 0.5) * (u - 0.5)));
        top.add(pt - Offset(0, h + lift));
        bot.add(pt + Offset(0, h - lift));
      }
      p.moveTo(top.first.dx, top.first.dy);
      for (final q in top.skip(1)) {
        p.lineTo(q.dx, q.dy);
      }
      for (final q in bot.reversed) {
        p.lineTo(q.dx, q.dy);
      }
      return p..close();
    }

    final hw = w.height * 0.45;
    // Near face, then the bone, then its lit crest.
    canvas.drawPath(band(hw, -5), Paint()..color = _kObBoneShade);
    canvas.drawPath(band(hw, 0), Paint()..color = _kObBone);
    canvas.drawPath(
      band(hw * 0.35, hw * 0.35),
      Paint()..color = const Color(0xFFFFF6E6).withValues(alpha: 0.5),
    );
    // Knuckles.
    for (final e in [a, z]) {
      for (final d in const [-1.0, 1.0]) {
        canvas.drawCircle(
          e + Offset(0, d * hw * 0.7),
          hw * 0.72,
          Paint()..color = _kObBone,
        );
      }
      canvas.drawCircle(
        e + Offset(0, hw * 0.7 + 3),
        hw * 0.5,
        Paint()..color = _kObBoneShade.withValues(alpha: 0.6),
      );
    }
  }

  /// A keystone of calcified plaque: a wedge of ivory, cracked across.
  void _drawKeystone(Canvas canvas, Rect w) {
    final face = Path()
      ..moveTo(w.left, w.top)
      ..lineTo(w.right, w.top)
      ..lineTo(w.right - 14, w.bottom)
      ..lineTo(w.left + 14, w.bottom)
      ..close();
    canvas.drawPath(
      face.shift(const Offset(0, 8)),
      Paint()..color = _kObBoneShade,
    );
    canvas.drawPath(
      face,
      Paint()
        ..shader = ui.Gradient.linear(
          w.topCenter,
          w.bottomCenter,
          const [Color(0xFFF1E6D0), _kObBone, Color(0xFFBFAE90)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(w.center.dx - 8, w.top)
        ..lineTo(w.center.dx + 4, w.center.dy)
        ..lineTo(w.center.dx - 2, w.bottom)
        ..lineTo(w.center.dx + 1, w.center.dy)
        ..close(),
      Paint()..color = const Color(0xFF5A4630).withValues(alpha: 0.8),
    );
  }

  /// A baffle: a valve leaf left standing — a pale fleshy flap, veined.
  void _drawBaffle(Canvas canvas, Rect w, double swell) {
    final r = w.inflate(swell * 2);
    Path leaf(double drop) => Path()
      ..moveTo(r.left, r.center.dy + drop)
      ..quadraticBezierTo(
        r.center.dx,
        r.top - 10 + drop,
        r.right,
        r.center.dy + drop,
      )
      ..quadraticBezierTo(
        r.center.dx,
        r.bottom + 12 + drop,
        r.left,
        r.center.dy + drop,
      )
      ..close();
    canvas.drawPath(leaf(6), Paint()..color = _kObMeat);
    canvas.drawPath(
      leaf(0),
      Paint()
        ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, const [
          Color(0xFFD99AA0),
          Color(0xFFB0606A),
        ]),
    );
    for (final dx in const [-0.3, 0.0, 0.3]) {
      final x = r.center.dx + r.width * dx;
      canvas.drawPath(
        Path()
          ..moveTo(x - 2, r.bottom + 2)
          ..quadraticBezierTo(x + dx * 20, r.center.dy, x, r.top + 2)
          ..lineTo(x + 2, r.top + 2)
          ..quadraticBezierTo(x + dx * 20 + 2, r.center.dy, x + 2, r.bottom + 2)
          ..close(),
        Paint()..color = _kObMeat.withValues(alpha: 0.55),
      );
    }
  }

  /// A span of vessel collapsed flat: a pinched tube, its lumen a slit.
  void _drawCollapsedVessel(Canvas canvas, Rect w, double swell) {
    final r = w.inflate(swell * 1.5);
    final body = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
    canvas.drawRRect(
      body.shift(const Offset(0, 6)),
      Paint()..color = _kObVessel,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          const [_kObMeatLit, _kObMeat, _kObVessel],
          const [0.0, 0.5, 1.0],
        ),
    );
    // Pinch points: the tube buckled where it fell.
    for (final u in const [0.3, 0.68]) {
      final x = r.left + r.width * u;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, r.center.dy),
          width: 10,
          height: r.height,
        ),
        Paint()..color = _kObVessel.withValues(alpha: 0.7),
      );
    }
    // The lumen, pressed to a slit.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: r.center, width: r.width * 0.8, height: 3),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF14060A),
    );
  }

  /// A knot of collapsed capillary: many fine vessels balled together.
  void _drawCapillaryKnot(Canvas canvas, Rect w, double swell) {
    final c = w.center;
    canvas.drawOval(w.inflate(4).translate(0, 6), Paint()..color = _kObVessel);
    for (var i = 0; i < 9; i++) {
      final a = i * 0.7;
      final rx = w.width * (0.24 + 0.05 * (i % 3)) + swell * 2;
      final ry = w.height * (0.34 + 0.06 * (i % 2)) + swell;
      final o = c + Offset(cos(a) * w.width * 0.2, sin(a) * w.height * 0.18);
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addOval(Rect.fromCenter(center: o, width: rx * 2, height: ry * 2))
        ..addOval(
          Rect.fromCenter(center: o, width: rx * 2 - 7, height: ry * 2 - 7),
        );
      canvas.drawPath(
        ring,
        Paint()
          ..color = (i.isEven ? _kObMeatLit : _kObMeat).withValues(alpha: 0.9),
      );
    }
  }
}
