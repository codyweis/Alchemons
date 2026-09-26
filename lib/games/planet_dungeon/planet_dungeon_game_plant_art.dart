// lib/games/planet_dungeon/planet_dungeon_game_plant_art.dart
//
// VERDANTHOS, IN GLASS (docs/dungeons.md §7.11) — Plant's glass, as a part of
// planet_dungeon_game.dart.
//
// The crypt already had its architecture (the wall course, loculi, columns)
// and a floor built to be read at two sizes, so the stone stays; its ledger
// stones — ~60 slabs, each clipped and stroked every frame — are now BAKED
// once per room at each size. Doors are garden glass in the stone. The glass:
//
//   · a grave-lamp burns in a chimney of leaded glass, smoked while dead;
//   · the growth altar's bowl is three panes — loam, seed, sun — each lit as
//     its step is laid, with a gold heart once the bloom wakes;
//   · and THE UNSEEN SHADE — the maxim — used to leave a run-state tree that
//     was gone next descent. What grew in the shade is now a tree of leaded
//     glass: the trunk rises, then the canopy opens pane by pane as the rite
//     binds, and it stands in the gallery on every later descent.

part of 'planet_dungeon_game.dart';

const GlassPalette _kVerdantGlass = kVerdantGlass;

final Map<String, ui.Picture> _cryptLedgerCache = {};

extension VerdantCryptArt on PlanetDungeonGame {
  void _updatePlantGlass(double dt) {
    final target =
        discoveredClouds.contains(kPlantUnseenShadeEggId) ||
            _ritePendingEgg == kPlantUnseenShadeEggId
        ? 1.0
        : 0.0;
    if (_shadeGrown < 0) {
      _shadeGrown = target;
    } else if (_shadeGrown < target) {
      _shadeGrown = min(target, _shadeGrown + dt / 2.6);
    } else if (_shadeGrown > target) {
      _shadeGrown = target;
    }
    // A bed grows over ~1.8s: a creeper unrolls, a trunk rises and reaches.
    for (final id in _bedGrow.keys.toList()) {
      final v = _bedGrow[id]!;
      if (v < 1) _bedGrow[id] = min(1.0, v + dt / 1.8);
    }
    if (_scaleFade > 0) _scaleFade = max(0.0, _scaleFade - dt / 0.7);
    final open = (conduitEnergy['B'] ?? 0) > 0 ? 1.0 : 0.0;
    if (_sepulchreSlide < 0 || open < _sepulchreSlide) {
      _sepulchreSlide = open;
    } else if (_sepulchreSlide < open) {
      _sepulchreSlide = min(open, _sepulchreSlide + dt / 1.3);
    }
  }

  /// How small the ground is drawn, 0 (your own size) → 1 (small), eased
  /// across a size change so a thing drawn at both sizes swells or shrinks.
  double get _tinyMix {
    final f = Curves.easeInOut.transform(_scaleFade.clamp(0.0, 1.0));
    return crypt.isTiny ? 1 - f : f;
  }

  // ── THE BEDS (2026-09-25 review) ─────────────────────────
  //
  // The planet's one world-edit was a dark slit you could walk past, and what
  // it grew was a rounded rectangle with a green circle on top, appearing in
  // one frame. Now:
  //   · a bare bed is a kerbed plot of turned soil with the split down it;
  //   · a CREEPER unrolls from the bed along the floor to the very door it
  //     opens, so the road it made is the thing you watch it make;
  //   · a TRUNK rises out of the split and puts its bough out to the door it
  //     opens, and bark swells over the crack it filled;
  //   · and standing at a bare bed shows, ghosted, what a seed set at the
  //     size you are NOW would grow — the rule the whole planet turns on was
  //     a sentence in the primer and a surprise at the bed.

  static const Color _vGreen = Color(0xFF4E8B4A);
  static const Color _vLeafDark = Color(0xFF2F5A31);
  static const Color _vLeafLit = Color(0xFF8CC060);
  static const Color _vBark = Color(0xFF6B4E33);
  static const Color _vBarkDark = Color(0xFF3A2A19);
  static const Color _vBarkLit = Color(0xFF9A7650);
  static const Color _vSoil = Color(0xFF3A2C1A);

  /// The door in [b]'s own room that the span of kind [need] runs through.
  DungeonDoor? _bedDoor(SeedBed b, SpanNeed need) {
    final room = layout.rooms[b.roomId]!;
    for (final sp in kCryptSpans) {
      if (sp.bedId != b.id || sp.need != need) continue;
      final other = sp.from == b.roomId ? sp.to : sp.from;
      for (final d in room.doors) {
        if (d.targetRoomId == other) return d;
      }
    }
    return null;
  }

  /// Just inside a doorway, where a road reaching it ends.
  Offset _doorLanding(DungeonRoom room, DungeonDoor d, [double inset = 30]) {
    final c = d.rect.center;
    final b = room.bounds;
    if (d.rect.top <= b.top + 1) return c + Offset(0, inset);
    if (d.rect.bottom >= b.bottom - 1) return c - Offset(0, inset);
    if (d.rect.left <= b.left + 1) return c + Offset(inset, 0);
    return c - Offset(inset, 0);
  }

  /// A quadratic bezier sampled into [n]+1 points.
  List<Offset> _curve(Offset a, Offset ctrl, Offset z, int n) => [
    for (var i = 0; i <= n; i++)
      () {
        final u = i / n;
        return Offset.lerp(
          Offset.lerp(a, ctrl, u)!,
          Offset.lerp(ctrl, z, u)!,
          u,
        )!;
      }(),
  ];

  /// A filled ribbon along [pts] up to fraction [upTo], [w0] wide at the
  /// start and [w1] at the end — never a stroked line.
  Path _ribbon(List<Offset> pts, double upTo, double w0, double w1) {
    final last = ((pts.length - 1) * upTo.clamp(0.0, 1.0));
    final k = last.floor();
    final run = <Offset>[...pts.take(k + 1)];
    if (k < pts.length - 1 && last > k) {
      run.add(Offset.lerp(pts[k], pts[k + 1], last - k)!);
    }
    if (run.length < 2) return Path();
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i < run.length; i++) {
      final a = run[max(0, i - 1)], z = run[min(run.length - 1, i + 1)];
      final t = z - a;
      final tl = t.distance == 0 ? 1.0 : t.distance;
      final u = i / (pts.length - 1);
      final hw = (w0 + (w1 - w0) * u) / 2;
      final nn = Offset(-t.dy / tl, t.dx / tl) * hw;
      left.add(run[i] + nn);
      right.add(run[i] - nn);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// An almond leaf at [at], pointing along [dir], [len] long.
  void _leaf(Canvas canvas, Offset at, double dir, double len, Color c) {
    if (len < 0.5) return;
    final tip = at + Offset(cos(dir), sin(dir)) * len;
    final side = Offset(-sin(dir), cos(dir)) * len * 0.28;
    final mid = Offset.lerp(at, tip, 0.5)!;
    canvas.drawPath(
      Path()
        ..moveTo(at.dx, at.dy)
        ..quadraticBezierTo(mid.dx + side.dx, mid.dy + side.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(mid.dx - side.dx, mid.dy - side.dy, at.dx, at.dy),
      Paint()..color = c,
    );
    // The lit half.
    canvas.drawPath(
      Path()
        ..moveTo(at.dx, at.dy)
        ..quadraticBezierTo(mid.dx + side.dx, mid.dy + side.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, at.dx, at.dy),
      Paint()..color = _vLeafLit.withValues(alpha: 0.45 * c.a),
    );
  }

  /// A bare bed: a kerb of small stones round turned soil, the split down it.
  void _drawBareBed(Canvas canvas, SeedBed b, {required bool near}) {
    final c = b.crown;
    final plot = Rect.fromCenter(center: c, width: 112, height: 46);
    canvas.drawOval(
      plot.inflate(8).translate(0, 5),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.28),
    );
    canvas.drawOval(plot, Paint()..color = _vSoil);
    // Furrows: filled slivers, lighter where the soil was turned up.
    for (var i = -2; i <= 2; i++) {
      final y = c.dy + i * 7.0;
      final hw = 46 * sqrt(max(0.0, 1 - pow(i / 3.0, 2).toDouble()));
      canvas.drawPath(
        _ribbon([Offset(c.dx - hw, y), Offset(c.dx + hw, y)], 1, 3.2, 1.2),
        Paint()..color = const Color(0xFF5C4629).withValues(alpha: 0.7),
      );
    }
    // The kerb.
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * 2 * pi;
      final p = c + Offset(cos(a) * 60, sin(a) * 27);
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 15, height: 10),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF6F6A58),
            const Color(0xFFB5AC90),
            near ? 0.8 : 0.45,
          )!,
      );
    }
    // The split: a tapered crack, deepest in the middle.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 4, c.dy - 22)
        ..quadraticBezierTo(c.dx + 7, c.dy - 4, c.dx + 3, c.dy + 22)
        ..quadraticBezierTo(c.dx - 5, c.dy + 2, c.dx - 4, c.dy - 22),
      Paint()..color = const Color(0xFF0B0805),
    );
  }

  /// A creeper, from its bed to the door it opens, grown to [g].
  void _drawCreeper(Canvas canvas, SeedBed b, double g, {double tinyK = -1}) {
    final door = _bedDoor(b, SpanNeed.creeper);
    if (door == null) return;
    final room = layout.rooms[b.roomId]!;
    final k = tinyK < 0 ? _tinyMix : tinyK;
    final a = b.crown, z = _doorLanding(room, door, 10);
    final d = z - a;
    final n = Offset(-d.dy, d.dx) / max(1.0, d.distance);
    const steps = 48;
    final pts = [
      for (var i = 0; i <= steps; i++)
        Offset.lerp(a, z, i / steps)! +
            n * sin(i / steps * pi * 3.2) * sin(i / steps * pi) * 16,
    ];
    final w = 2.6 + 5.4 * k;
    final e = Curves.easeOut.transform(g.clamp(0.0, 1.0));
    canvas.drawPath(
      _ribbon(pts, e, w, w * 0.7).shift(const Offset(1.5, 3)),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.3),
    );
    canvas.drawPath(_ribbon(pts, e, w, w * 0.7), Paint()..color = _vLeafDark);
    canvas.drawPath(
      _ribbon(pts, e, w * 0.45, w * 0.3).shift(const Offset(0, -0.8)),
      Paint()..color = _vGreen,
    );
    final head = e * steps;
    final leafLen = 7 + 13 * k;
    for (var i = 3; i < steps; i += 4) {
      if (i > head) break;
      final t = pts[i + 1] - pts[i - 1];
      final dir = atan2(t.dy, t.dx) + ((i ~/ 4).isEven ? -1.0 : 1.0) * 1.0;
      final grown = ((head - i) / 5).clamp(0.0, 1.0);
      final sway = sin(_time * 1.3 + i) * 0.12;
      _leaf(canvas, pts[i], dir + sway, leafLen * grown, _vGreen);
    }
    if (e < 1) {
      // The growing tip, a curled bud.
      final tip = pts[head.floor().clamp(0, steps)];
      canvas.drawCircle(tip, w * 0.9 + 1.5, Paint()..color = _vLeafLit);
    }
  }

  /// A trunk risen out of its bed, bough out to its door, grown to [g].
  void _drawTrunk(Canvas canvas, SeedBed b, double g) {
    final c = b.crown + const Offset(0, 16);
    final rise = Curves.easeOutCubic.transform((g / 0.45).clamp(0.0, 1.0));
    final reach = Curves.easeOut.transform(((g - 0.3) / 0.5).clamp(0.0, 1.0));
    final leaf = Curves.easeOutBack.transform(
      ((g - 0.55) / 0.45).clamp(0.0, 1.0),
    );
    const h = 96.0;
    final top = c - Offset(0, h * rise);

    // Root flare, spreading as it rises.
    for (final (ang, len) in const [
      (pi * 0.92, 44.0),
      (pi * 0.62, 30.0),
      (pi * 0.36, 32.0),
      (pi * 0.06, 42.0),
    ]) {
      final z = c + Offset(cos(ang), sin(ang) * 0.45) * len * rise;
      canvas.drawPath(
        _ribbon([c, Offset.lerp(c, z, 0.5)! + const Offset(0, 3), z], 1, 20, 2),
        Paint()..color = _vBarkDark,
      );
    }

    // The bough's shadow on the floor, then the column, then the bough: it
    // is a limb you walk ALONG, so it has to read as up in the air.
    final door = _bedDoor(b, SpanNeed.trunk);
    List<Offset>? bough;
    if (door != null && reach > 0) {
      final room = layout.rooms[b.roomId]!;
      final z = _doorLanding(room, door, 6);
      final from = c - const Offset(0, h * 0.85);
      final mid = Offset.lerp(from, z, 0.5)! - const Offset(0, 50);
      bough = _curve(from, mid, z, 28);
      canvas.drawPath(
        _ribbon(bough, reach, 26, 10).shift(const Offset(10, 60)),
        Paint()..color = const Color(0xFF000000).withValues(alpha: 0.22),
      );
    }

    final col = Path()
      ..moveTo(c.dx - 25, c.dy)
      ..quadraticBezierTo(c.dx - 20, (c.dy + top.dy) / 2, top.dx - 17, top.dy)
      ..lineTo(top.dx + 17, top.dy)
      ..quadraticBezierTo(c.dx + 22, (c.dy + top.dy) / 2, c.dx + 25, c.dy)
      ..close();
    canvas.drawPath(
      col,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - 25, 0),
          Offset(c.dx + 25, 0),
          const [_vBarkLit, _vBark, _vBarkDark],
          const [0.0, 0.45, 1.0],
        ),
    );
    // Bark: long filled slivers, not ruled lines.
    for (final (dx, len) in const [(-9.0, 0.7), (3.0, 0.9), (12.0, 0.55)]) {
      final y0 = c.dy - 6, y1 = c.dy - (c.dy - top.dy) * len;
      if (y0 - y1 < 4) continue;
      canvas.drawPath(
        _ribbon(
          [Offset(c.dx + dx, y0), Offset(c.dx + dx * 0.8, y1)],
          1,
          3,
          0.6,
        ),
        Paint()..color = _vBarkDark.withValues(alpha: 0.7),
      );
    }

    if (bough != null) {
      canvas.drawPath(_ribbon(bough, reach, 26, 10), Paint()..color = _vBark);
      canvas.drawPath(
        _ribbon(bough, reach, 9, 3).shift(const Offset(0, -5)),
        Paint()..color = _vBarkLit.withValues(alpha: 0.7),
      );
    }

    // Leaf clusters: the crown, one along the bough, one at its end.
    void cluster(Offset at, double r) {
      if (r < 1) return;
      const offs = [
        Offset(0, 0),
        Offset(-0.55, 0.2),
        Offset(0.55, 0.15),
        Offset(-0.25, -0.45),
        Offset(0.3, -0.4),
      ];
      for (var i = 0; i < offs.length; i++) {
        final sway = sin(_time * 0.9 + at.dx * 0.01 + i) * r * 0.04;
        canvas.drawOval(
          Rect.fromCenter(
            center: at + offs[i] * r + Offset(sway, 0),
            width: r * 1.2,
            height: r * 0.95,
          ),
          Paint()..color = i.isEven ? _vLeafDark : _vGreen,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: at + Offset(-r * 0.2, -r * 0.3),
          width: r * 0.7,
          height: r * 0.45,
        ),
        Paint()..color = _vLeafLit.withValues(alpha: 0.55),
      );
    }

    cluster(top - const Offset(0, 14), 44 * leaf);
    if (bough != null) {
      cluster(bough[15], 28 * leaf);
      cluster(bough.last, 24 * leaf);
    }
  }

  /// Under the doors: the beds, their products, and the far end of every
  /// grown road that comes into this room from a bed in another.
  void _renderCryptSpans(Canvas canvas, DungeonRoom room) {
    for (final d in room.doors) {
      final span = cryptSpanBetween(room.id, d.targetRoomId);
      final id = span?.bedId;
      if (span == null || id == null || !crypt.spanExists(span)) continue;
      final bed = cryptBedById(id)!;
      if (bed.roomId == room.id) continue;
      final g = _bedGrow[id] ?? 1.0;
      final z = _doorLanding(room, d, 8);
      final inward = room.bounds.center - z;
      final into = z + inward / max(1.0, inward.distance) * 90 * g;
      if (span.need == SpanNeed.creeper) {
        final pts = _curve(
          z,
          Offset.lerp(z, into, 0.5)! + const Offset(12, 0),
          into,
          16,
        );
        final w = 2.6 + 5.4 * _tinyMix;
        canvas.drawPath(
          _ribbon(pts, 1, w * 0.7, w * 0.3),
          Paint()..color = _vLeafDark,
        );
        for (var i = 4; i < 16; i += 5) {
          final t = pts[i + 1] - pts[i - 1];
          _leaf(
            canvas,
            pts[i],
            atan2(t.dy, t.dx) + (i.isEven ? 1 : -1),
            (7 + 13 * _tinyMix) * g,
            _vGreen,
          );
        }
      } else if (span.need == SpanNeed.trunk) {
        final pts = _curve(
          z,
          Offset.lerp(z, into, 0.5)! - const Offset(0, 20),
          into,
          16,
        );
        canvas.drawPath(
          _ribbon(pts, 1, 12, 22).shift(const Offset(8, 40)),
          Paint()..color = const Color(0xFF000000).withValues(alpha: 0.2),
        );
        canvas.drawPath(_ribbon(pts, 1, 12, 22), Paint()..color = _vBark);
        canvas.drawPath(
          _ribbon(pts, 1, 4, 8).shift(const Offset(0, -4)),
          Paint()..color = _vBarkLit.withValues(alpha: 0.7),
        );
      }
    }
  }

  void _renderCryptBeds(Canvas canvas, DungeonRoom room) {
    final a = active;
    for (final b in cryptBedsIn(room.id)) {
      final g = _bedGrow[b.id] ?? 1.0;
      final near = a != null && (a.position - b.crown).distance < 110;
      switch (crypt.stateOf(b.id)) {
        case VineState.bare:
          _drawBareBed(canvas, b, near: near);
        case VineState.creeper:
          _drawBareBed(canvas, b, near: false);
          _drawCreeper(canvas, b, g);
        case VineState.trunk:
          _drawTrunk(canvas, b, g);
      }
    }
  }

  /// Over the doors: bark swelling over a crack a trunk has filled, and — at
  /// a bare bed — the ghost of what a seed set at your size now would grow.
  void _renderCryptOverDoors(Canvas canvas, DungeonRoom room) {
    for (final d in room.doors) {
      final span = cryptSpanBetween(room.id, d.targetRoomId);
      if (span?.need != SpanNeed.fissure || crypt.spanExists(span!)) continue;
      final g = _bedGrow[span.bedId] ?? 1.0;
      _drawFilledCrack(canvas, d, Curves.easeOut.transform(g), 1);
    }

    final a = active;
    if (a == null) return;
    for (final b in cryptBedsIn(room.id)) {
      if (crypt.stateOf(b.id) != VineState.bare) continue;
      final dist = (a.position - b.crown).distance;
      if (dist > 130) continue;
      // Fades in as you come up to it; breathes so it reads as a maybe.
      final o =
          ((130 - dist) / 50).clamp(0.0, 1.0) *
          (0.42 + 0.08 * sin(_time * 2.2));
      canvas.saveLayer(
        room.bounds.inflate(40),
        Paint()..color = Colors.white.withValues(alpha: o),
      );
      if (crypt.productFor(crypt.scale) == VineState.creeper) {
        _drawCreeper(canvas, b, 1);
      } else {
        _drawTrunk(canvas, b, 1);
        final crack = _bedDoor(b, SpanNeed.fissure);
        if (crack != null) _drawFilledCrack(canvas, crack, 1, 1);
      }
      canvas.restore();
    }
  }

  /// Bark grown over a doorway: the crack a trunk filled.
  void _drawFilledCrack(Canvas canvas, DungeonDoor d, double g, double o) {
    if (g <= 0) return;
    final r = d.rect.inflate(8);
    final c = r.center;
    final w = r.width * g, h = r.height * g;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(2, 4), width: w, height: h),
        Radius.circular(min(w, h) / 2),
      ),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.3 * o),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: w, height: h),
        Radius.circular(min(w, h) / 2),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          r.topLeft,
          r.bottomRight,
          const [_vBarkLit, _vBark, _vBarkDark],
          const [0.0, 0.5, 1.0],
        ),
    );
    final along = r.width > r.height;
    for (var i = -1; i <= 1; i++) {
      final p0 = along
          ? Offset(c.dx - w * 0.4, c.dy + i * h * 0.22)
          : Offset(c.dx + i * w * 0.22, c.dy - h * 0.4);
      final p1 = along
          ? Offset(c.dx + w * 0.4, c.dy + i * h * 0.22)
          : Offset(c.dx + i * w * 0.22, c.dy + h * 0.4);
      canvas.drawPath(
        _ribbon([p0, Offset.lerp(p0, p1, 0.5)!, p1], 1, 2.6, 0.8),
        Paint()..color = _vBarkDark.withValues(alpha: 0.7),
      );
    }
  }

  // ── THE SEPULCHRE ────────────────────────────────────────

  /// A stone chest with a carved lid, its seam smeared with clay. When the
  /// rite opens it the clay drops away and the lid slides aside.
  void _drawSepulchre(Canvas canvas, Offset at) {
    final t = _sepulchreSlide < 0 ? 0.0 : _sepulchreSlide;
    final clay = 1 - (t / 0.35).clamp(0.0, 1.0);
    final slide = Curves.easeInOut.transform(((t - 0.3) / 0.7).clamp(0.0, 1.0));
    final box = Rect.fromCenter(center: at, width: 136, height: 64);
    // Contact shadow and the near face.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box.inflate(6).translate(3, 10),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.35),
    );
    canvas.drawRect(
      Rect.fromLTRB(box.left, box.bottom - 4, box.right, box.bottom + 14),
      Paint()..color = const Color(0xFF4F4838),
    );
    canvas.drawRect(box, Paint()..color = const Color(0xFF7F7660));
    // The dark inside, uncovered as the lid moves.
    canvas.drawRect(box.deflate(9), Paint()..color = const Color(0xFF0E0C08));
    // The lid.
    canvas.save();
    canvas.translate(at.dx + slide * 58, at.dy - slide * 10);
    canvas.rotate(slide * 0.16);
    final lid = Rect.fromCenter(center: Offset.zero, width: 140, height: 66);
    canvas.drawRect(
      lid.translate(0, 5),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.3),
    );
    canvas.drawRect(
      lid,
      Paint()
        ..shader = ui.Gradient.linear(lid.topCenter, lid.bottomCenter, const [
          Color(0xFFB5AC90),
          Color(0xFF8C826A),
        ]),
    );
    // A carved leaf-cross on it.
    for (final dir in const [0.0, pi / 2, pi, 3 * pi / 2]) {
      _leaf(
        canvas,
        Offset.zero,
        dir,
        dir == pi / 2 ? 24 : 18,
        const Color(0xFF5E5643),
      );
    }
    canvas.restore();
    // The clay along the seam, falling away as it softens.
    if (clay > 0) {
      for (var i = 0; i < 7; i++) {
        final x = box.left + 10 + i * 19.0;
        final y = (i.isEven ? box.top : box.bottom) + (1 - clay) * 16;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: 22 * clay,
            height: 12 * clay,
          ),
          Paint()
            ..color = const Color(0xFF7A5634).withValues(alpha: 0.95 * clay),
        );
      }
    }
  }

  void _renderCryptLedger(
    Canvas canvas,
    DungeonRoom room,
    _CryptGround g,
    bool tiny,
  ) {
    final b = room.bounds;
    canvas.drawPicture(
      _cryptLedgerCache.putIfAbsent(
        '${room.id}|$tiny|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          final c = Canvas(rec);
          _paintCryptLedger(c, g, tiny);
          _paintCryptMotif(c, room);
          return rec.endRecording();
        },
      ),
    );
  }

  /// A grave-lamp's chimney: two leaded panes round the flame.
  void _drawLampChimney(Canvas canvas, Offset at, double k, bool lit) {
    final top = at.dy - 40 * k, foot = at.dy - 6 * k;
    for (final side in const [-1.0, 1.0]) {
      final pane = Path()
        ..moveTo(at.dx, top)
        ..lineTo(at.dx + side * 11 * k, top + 4 * k)
        ..lineTo(at.dx + side * 14 * k, foot)
        ..lineTo(at.dx, foot)
        ..close();
      paintPane(
        canvas,
        pane,
        lit
            ? _kVerdantGlass.live.withValues(alpha: 0.3)
            : _kVerdantGlass.smoke.withValues(alpha: 0.7),
        _kVerdantGlass,
        lead: 1.6 * k.clamp(0.7, 1.0),
      );
    }
    if (lit) {
      paintStreak(
        canvas,
        Rect.fromLTRB(at.dx - 12 * k, top, at.dx, foot),
        opacity: 0.5,
      );
    }
  }

  /// The growth altar's bowl: loam, seed and sun, a pane each.
  void _drawAltarGlass(Canvas canvas, Offset c, Rect bowl) {
    const tones = [Color(0xFFB8864A), Color(0xFF8CC060), Color(0xFFF2D287)];
    final rx = bowl.width / 2, ry = bowl.height / 2;
    for (var i = 0; i < 3; i++) {
      final a0 = -pi / 2 + i * 2 * pi / 3 + 0.05;
      final pane = ellipseSectorPath(
        c,
        rx * 0.3,
        ry * 0.3,
        rx * 0.92,
        ry * 0.92,
        a0,
        a0 + 2 * pi / 3 - 0.1,
      );
      final laid = crypt.bloomStep > i;
      paintPane(
        canvas,
        pane,
        laid ? tones[i] : _kVerdantGlass.frostAt(i),
        _kVerdantGlass,
        lead: 2,
        opacity: laid ? 0.9 : 0.7,
      );
      if (laid) paintStreak(canvas, pane.getBounds().deflate(4), opacity: 0.35);
    }
    paintRondel(
      canvas,
      c,
      rx * 0.28,
      _kVerdantGlass,
      fill: crypt.bloomWoken ? _kVerdantGlass.liveCore : _kVerdantGlass.smoke,
      rim: crypt.bloomWoken ? 1 : 0.4,
      lead: 2,
    );
    if (crypt.bloomWoken && _fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        rx * 1.4,
        _kVerdantGlass.gold.withValues(alpha: 0.22),
      );
    }
  }

  /// THE UNSEEN SHADE: a tree of leaded glass, grown where the shade lay.
  void _drawShadeTree(Canvas canvas, Offset root) {
    // A found maxim stands even before this frame's easing has caught up.
    final o = _shadeGrown < 0 ? 1.0 : _shadeGrown.clamp(0.0, 1.0);
    if (o <= 0) return;
    final rise = (o / 0.35).clamp(0.0, 1.0);
    final crown = root - Offset(0, 150 * rise);
    // The trunk, carved bark, rising.
    paintContactShadow(canvas, root + const Offset(0, 6), 70, 18);
    final trunk = Path()
      ..moveTo(root.dx - 16, root.dy)
      ..quadraticBezierTo(
        root.dx - 8,
        root.dy - 70 * rise,
        crown.dx - 6,
        crown.dy + 40,
      )
      ..lineTo(crown.dx + 6, crown.dy + 40)
      ..quadraticBezierTo(
        root.dx + 8,
        root.dy - 70 * rise,
        root.dx + 16,
        root.dy,
      )
      ..close();
    canvas.drawPath(trunk, Paint()..color = VerdantCryptDungeon._kCryptBark);
    if (rise < 1) return;
    final open = ((o - 0.35) / 0.65).clamp(0.0, 1.0);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        crown,
        110,
        _kVerdantGlass.live.withValues(
          alpha: o < 1 ? 0.28 * open : 0.16 + 0.04 * sin(_time * 0.9),
        ),
      );
    }
    // The canopy: leaves of leaded glass fanned out from the crown — a back
    // layer of long dark ones, then a front layer of short bright ones —
    // opening in turn as the rite binds, the fruit last.
    const leaf = [
      Color(0xFF6FA84E),
      Color(0xFF4E8B4A),
      Color(0xFF8CC060),
      Color(0xFF3E7240),
    ];
    for (final (n, len, wide, spread, delay, shade) in const [
      (9, 78.0, 30.0, 1.25, 0.0, 0.25),
      (7, 52.0, 24.0, 1.05, 0.4, 0.0),
    ]) {
      for (var i = 0; i < n; i++) {
        final k = ((open - delay - i * 0.03) / 0.35).clamp(0.0, 1.0);
        if (k <= 0) continue;
        // Fanned over the top: from low-left, up, to low-right.
        final a = -pi / 2 + (i / (n - 1) - 0.5) * 2 * spread;
        final dir = Offset(cos(a), sin(a) * 0.85);
        final tip = crown + dir * (len * k);
        final base = crown + dir * 6;
        final side = Offset(-dir.dy, dir.dx) * (wide * 0.5 * k);
        final mid = Offset.lerp(base, tip, 0.5)!;
        final pane = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            mid.dx + side.dx,
            mid.dy + side.dy,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            mid.dx - side.dx,
            mid.dy - side.dy,
            base.dx,
            base.dy,
          )
          ..close();
        paintPane(
          canvas,
          pane,
          Color.lerp(leaf[(i * 3 + n) % leaf.length], Colors.black, shade)!,
          _kVerdantGlass,
          lead: 2,
        );
        // The midrib, in the lead.
        canvas.drawLine(
          base,
          Offset.lerp(base, tip, 0.85)!,
          Paint()
            ..strokeWidth = 1.1
            ..color = _kVerdantGlass.lead.withValues(alpha: 0.8),
        );
      }
    }
    final heart = ((open - 0.8) / 0.2).clamp(0.0, 1.0);
    if (heart > 0) {
      paintRondel(
        canvas,
        crown,
        12 * heart,
        _kVerdantGlass,
        fill: const Color(0xFFF2D287),
        lead: 2,
      );
    }
    paintStreak(
      canvas,
      Rect.fromCenter(
        center: crown - const Offset(0, 30),
        width: 90,
        height: 60,
      ),
      opacity: 0.4 * open,
    );
  }

  /// THE ROOM'S OWN CARVING (2026-09-24). With the paving quietened, half
  /// the crypt was one chamber: joints, vines, a fixture. Each room now has
  /// one thing cut into its floor that no other room has.
  void _paintCryptMotif(Canvas c, DungeonRoom room) {
    final r = room.bounds;
    Offset at(double fx, double fy) =>
        Offset(r.left + r.width * fx, r.top + r.height * fy);
    void groove(Path path, {double w = 3}) {
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 1.6 + 2
          ..strokeCap = StrokeCap.round
          ..color = VerdantCryptDungeon._kCryptSeam.withValues(alpha: 0.85),
      );
      c.drawPath(
        path.shift(const Offset(0, 2.2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, w * 0.4)
          ..strokeCap = StrokeCap.round
          ..color = VerdantCryptDungeon._kCryptBone.withValues(alpha: 0.32),
      );
    }

    void ring(Offset o, double rad, {double w = 3}) => groove(
      Path()..addOval(Rect.fromCircle(center: o, radius: rad)),
      w: w,
    );
    void petals(Offset o, int n, double r0, double r1, {double w = 2}) {
      for (var i = 0; i < n; i++) {
        final a = i / n * 2 * pi;
        final dir = Offset(cos(a), sin(a));
        final side = Offset(-dir.dy, dir.dx) * (r1 - r0) * 0.32;
        final base = o + dir * r0, tip = o + dir * r1;
        final mid = Offset.lerp(base, tip, 0.5)!;
        groove(
          Path()
            ..moveTo(base.dx, base.dy)
            ..quadraticBezierTo(
              mid.dx + side.dx,
              mid.dy + side.dy,
              tip.dx,
              tip.dy,
            )
            ..quadraticBezierTo(
              mid.dx - side.dx,
              mid.dy - side.dy,
              base.dx,
              base.dy,
            ),
          w: w,
        );
      }
    }

    // ONLY TWO ROOMS KEEP A CARVING (2026-09-25 review). The porch's root-boss,
    // the walk's chevron runner, the court's jointed ring, the gallery's frond
    // kerbs and the hall's flower were decoration that read as machinery — an
    // arrowed runner says "this way", a ring of joints says "a dial" — on a
    // planet whose floor is already a map of what your size lets through.
    // The niche's effigy is the grave the third lamp burns for; the arena's
    // ring is the fight's floor.
    switch (room.id) {
      case 'crypt_niche':
        // A ledger slab with its effigy: a figure laid out in a leaf shroud.
        final o = at(0.5, 0.64);
        final slab = Rect.fromCenter(center: o, width: 170, height: 64);
        groove(Path()..addRect(slab), w: 3);
        groove(Path()..addRect(slab.deflate(8)), w: 1.2);
        groove(
          Path()
            ..addOval(Rect.fromCircle(center: o.translate(-58, 0), radius: 13)),
          w: 2,
        );
        groove(
          Path()
            ..moveTo(o.dx - 44, o.dy)
            ..quadraticBezierTo(o.dx + 10, o.dy - 22, o.dx + 70, o.dy)
            ..quadraticBezierTo(o.dx + 10, o.dy + 22, o.dx - 44, o.dy),
          w: 2,
        );
      case 'botanica_heart':
        // The arena: a ring of petals round the flower's own floor.
        final o = at(0.5, 0.5);
        ring(o, 230, w: 3.4);
        petals(o, 16, 230, 290, w: 1.8);
    }
  }
}
