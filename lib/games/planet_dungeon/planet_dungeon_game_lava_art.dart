// lib/games/planet_dungeon/planet_dungeon_game_lava_art.dart
//
// THE MOLTEN RELIQUARY, IN GLASS (docs/dungeons.md §7.11) — the works' stone
// and the glass it signals with, as a part of planet_dungeon_game.dart.
//
// The works stay MACHINERY (§5.5: a Lava screenshot must not read as Fire):
// a crust of cooled basalt that has not finished cooling, iron fixtures, and
// square-headed factory glass rather than lancets. What changes is the
// hierarchy. The fissures were the loudest thing in every room and meant
// nothing; they are baked now, and mostly dead. The glass is where the works
// tells you something:
//
//   · every lever stands on a glass base, and its notches are glass beads with
//     the setting it is in alight;
//   · every mold's flask is rimmed in glass the colour of the metal it takes
//     (white-hot plain · blue-white warded · green gassed), silver once it
//     holds a good casting and smoked once it has been spoiled;
//   · the crucible has a sight-glass, the accumulator a gauge, the purge cowl
//     glass louvres, the chiller hood a frosted lip, each lit by its state;
//   · a ward lock's keyhole is glass that pulses while you carry its key and
//     goes silver once it is turned;
//   · and the Black Glass — the maxim — sets in the slag pit as a leaded
//     obsidian mirror, shard by shard, and stays there for good.
//
// COST. The crust, the walls and the channels' brick are baked once per room
// into a Picture, and the walkways into a second one that goes over the metal.
// The old floor regenerated 26 plates and 34 branching fissures every frame.

part of 'planet_dungeon_game.dart';

const GlassPalette _kWorksGlass = kBasaltGlass;

/// One room of the works, baked.
class _WorksFabric {
  _WorksFabric(this.under, this.over, this.hot);

  /// Crust, walls, channel brick — everything under the metal.
  final ui.Picture under;

  /// The walkways, which cross over the metal.
  final ui.Picture over;

  /// The few fissures that still carry heat: where they breathe, and how hot.
  final List<(Offset, double)> hot;
}

final Map<String, _WorksFabric> _worksFabricCache = {};

extension MoltenReliquaryArt on PlanetDungeonGame {
  // ── Eased display state ─────────────────────────────────

  void _updateWorksGlass(double dt) {
    // The Black Glass sets as the rite binds, and is simply there after.
    final found = discoveredClouds.contains(kLavaBlackGlassEggId);
    final target = found || _ritePendingEgg == kLavaBlackGlassEggId ? 1.0 : 0.0;
    final v = works.blackGlass;
    if (v < 0) {
      works.blackGlass = target; // first sight: snap to the truth
    } else if (v < target) {
      works.blackGlass = min(target, v + dt / 2.6);
    } else if (v > target) {
      works.blackGlass = target;
    }
  }

  // ── The fabric ──────────────────────────────────────────

  _WorksFabric _worksFabric(DungeonRoom room) {
    final b = room.bounds;
    final key = '${room.id}|${b.width.round()}x${b.height.round()}';
    return _worksFabricCache.putIfAbsent(key, () => _bakeWorks(room));
  }

  /// The ground and the walls, and the heat still in them.
  void _renderWorksFabric(Canvas canvas, DungeonRoom room) {
    final f = _worksFabric(room);
    canvas.drawPicture(f.under);
    // The hot fissures BREATHE — the one thing about the crust that moves,
    // and a handful of glow blits rather than 34 repainted cracks.
    if (_fx.ready) {
      for (var i = 0; i < f.hot.length; i++) {
        final (at, heat) = f.hot[i];
        final breath = 0.5 + 0.5 * sin(works.clock * (0.5 + heat) + i * 1.3);
        drawGlow(
          canvas,
          _fx.glow!,
          at,
          26 + 22 * heat,
          _worksEdge.withValues(alpha: (0.05 + 0.10 * heat) * breath),
        );
      }
    }
    // EMBERS drifting up off the crust: what makes a still image of this floor
    // read as a place that is still burning.
    final b = room.bounds;
    final pulse = 0.5 + 0.5 * sin(works.clock * 0.8);
    for (var i = 0; i < 16; i++) {
      final ex = b.left + ((i * 0.6180339) % 1.0) * b.width;
      final base = b.top + ((i * 0.4142135 + 0.3) % 1.0) * b.height;
      final t = ((works.clock * (0.10 + 0.06 * (i % 4)) + i / 16) % 1.0);
      canvas.drawCircle(
        Offset(ex + sin(t * 5 + i) * 9, base - 54 * t),
        1.6 + 1.4 * (1 - t),
        Paint()
          ..color = Color.lerp(
            _worksCore,
            _worksEdge,
            t,
          )!.withValues(alpha: 0.42 * (1 - t) * pulse),
      );
    }
  }

  /// The walkways, over the metal.
  void _renderWorksOver(Canvas canvas, DungeonRoom room) =>
      canvas.drawPicture(_worksFabric(room).over);

  _WorksFabric _bakeWorks(DungeonRoom room) {
    final b = room.bounds;
    final rng = GlassRng(glassSeed(room.id, b));
    final hot = <(Offset, double)>[];

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);

    // A CRUST WITH SOMETHING UNDER IT. Not a floor anyone laid: the top of a
    // flow that stopped. Twice it was drawn regular (a ruled grid, then plates
    // in running bond) and play said "too tiley" and "it needs to look
    // dangerous" — regularity reads as safe. So: irregular plates, and
    // fissures that wander and fork. Translucent (§8), so the planet's
    // shader still shows through the thin places.
    canvas.drawRect(
      b,
      Paint()
        ..shader = ui.Gradient.linear(
          b.topCenter,
          b.bottomCenter,
          [
            const Color(0xFF0A0907).withValues(alpha: 0.72),
            const Color(0xFF16100C).withValues(alpha: 0.72),
            const Color(0xFF241410).withValues(alpha: 0.72),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    for (var i = 0; i < 26; i++) {
      final cx = b.left + rng.next() * b.width;
      final cy = b.top + rng.next() * b.height;
      final rx = 70 + rng.next() * 130;
      final ry = 50 + rng.next() * 90;
      final rot = rng.next() * pi;
      final sides = 5 + (rng.next() * 3).floor();
      final path = Path();
      for (var k = 0; k <= sides; k++) {
        final a = rot + k * 2 * pi / sides;
        final wob = 0.72 + rng.next() * 0.5;
        final pt = Offset(cx + cos(a) * rx * wob, cy + sin(a) * ry * wob);
        k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF15120F),
            const Color(0xFF0B0A09),
            rng.next(),
          )!.withValues(alpha: 0.8),
      );
    }

    // THE FISSURES — mostly DEAD. A crust is mostly cold; the hot ones are
    // frightening because they are the exception, and they must never outshine
    // a lever. Heat is skewed hard toward zero.
    void crack(Offset from, double len, double angle, double heat, int idx) {
      const steps = 7;
      var at = from;
      var a = angle;
      final pts = <Offset>[at];
      for (var k = 0; k < steps; k++) {
        a += (rng.next() - 0.5) * 0.8;
        at = at + Offset(cos(a), sin(a)) * (len / steps);
        pts.add(at);
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      final w = 1.4 + 3.4 * heat * heat;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w + 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF070605).withValues(alpha: 0.9),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(
            const Color(0xFF2A0E04),
            _worksEdge,
            heat * heat * 0.7,
          )!.withValues(alpha: 0.26 + 0.30 * heat),
      );
      if (heat > 0.55) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round
            ..color = _worksCore.withValues(alpha: 0.18 * heat),
        );
        hot.add((pts[3], heat));
      }
      if (len > 120 && idx % 3 != 2) {
        crack(
          pts[3],
          len * 0.45,
          a + (rng.next() < 0.5 ? 1.1 : -1.1),
          heat * 0.7,
          idx + 41,
        );
      }
    }

    for (var i = 0; i < 30; i++) {
      crack(
        Offset(b.left + rng.next() * b.width, b.top + rng.next() * b.height),
        70 + rng.next() * 130,
        rng.next() * 2 * pi,
        pow(rng.next(), 2.6).toDouble(),
        i,
      );
    }
    for (var i = 0; i < 30; i++) {
      final at = Offset(
        b.left + rng.next() * b.width,
        b.top + rng.next() * b.height,
      );
      canvas.drawCircle(
        at,
        2.0 + rng.next() * 5,
        Paint()
          ..color = const Color(
            0xFF2A241E,
          ).withValues(alpha: 0.35 + rng.next() * 0.3),
      );
    }

    // The runs are hotter than anything around them, and the ground knows.
    final segs = [
      for (final ch in works.line.line.channelsIn(room.id))
        for (final seg in ch.segments)
          if (seg.roomId == room.id) seg,
    ];
    for (final seg in segs) {
      canvas.drawRect(
        seg.rect.inflate(34),
        Paint()..color = const Color(0xFF491A08).withValues(alpha: 0.14),
      );
      canvas.drawRect(
        seg.rect.inflate(15),
        Paint()..color = const Color(0xFF5E2109).withValues(alpha: 0.18),
      );
    }

    // THE WALLS: basalt, with the works' iron bolted up the north face.
    paintCarvedRoomShell(
      canvas,
      b,
      _kWorksGlass,
      rng,
      doors: room.doors.map((d) => d.rect),
      arcade: false,
      flags: false,
    );
    for (var x = b.left + 70; x < b.right - 40; x += 150) {
      final r = Rect.fromLTWH(x - 5, b.top + 8, 10, kGlassWallFace - 10);
      if (room.doors.any((d) => d.rect.inflate(14).overlaps(r))) continue;
      _ironPlate(canvas, r, radius: 1);
      for (final y in [r.top + 6, r.bottom - 6]) {
        canvas.drawCircle(
          Offset(r.center.dx, y),
          1.8,
          Paint()..color = const Color(0xFF778796).withValues(alpha: 0.6),
        );
      }
    }

    // REFRACTORY LIPS — firebrick in courses along every run, glazed at the
    // metal. Stone, so it is baked; the metal in it is live.
    for (final seg in segs) {
      final r = seg.rect;
      final horiz = seg.horizontal;
      canvas.drawRect(r.inflate(9), Paint()..color = const Color(0xFF15181B));
      canvas.drawRect(r.inflate(7), Paint()..color = const Color(0xFF2C2620));
      final course = Paint()
        ..strokeWidth = 1
        ..color = const Color(0xFF15110D).withValues(alpha: 0.8);
      final span = horiz ? r.width : r.height;
      for (var k = 22.0; k < span; k += 26) {
        if (horiz) {
          canvas.drawLine(
            Offset(r.left + k, r.top - 7),
            Offset(r.left + k, r.top - 1),
            course,
          );
          canvas.drawLine(
            Offset(r.left + k, r.bottom + 1),
            Offset(r.left + k, r.bottom + 7),
            course,
          );
        } else {
          canvas.drawLine(
            Offset(r.left - 7, r.top + k),
            Offset(r.left - 1, r.top + k),
            course,
          );
          canvas.drawLine(
            Offset(r.right + 1, r.top + k),
            Offset(r.right + 7, r.top + k),
            course,
          );
        }
      }
      canvas.drawRect(
        r.inflate(2),
        Paint()..color = const Color(0xFF6B3411).withValues(alpha: 0.85),
      );
    }
    final under = rec.endRecording();

    // THE WALKWAYS, over the metal: a grated deck with handrails, so the
    // party crosses where the works meant them to.
    final rec2 = ui.PictureRecorder();
    final over = Canvas(rec2);
    for (final br in works.line.line.bridgesIn(room.id)) {
      final r = br.rect;
      final acrossX = r.width >= r.height;
      paintContactShadow(
        over,
        r.center + const Offset(0, 4),
        r.width + 10,
        r.height + 10,
        opacity: 0.35,
      );
      _ironPlate(over, r, radius: 2);
      final grate = Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF10141A).withValues(alpha: 0.7);
      if (acrossX) {
        for (var x = r.left + 7; x < r.right - 4; x += 9) {
          over.drawLine(Offset(x, r.top + 4), Offset(x, r.bottom - 4), grate);
        }
      } else {
        for (var y = r.top + 7; y < r.bottom - 4; y += 9) {
          over.drawLine(Offset(r.left + 4, y), Offset(r.right - 4, y), grate);
        }
      }
      final rail = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = _worksIronLit;
      final posts = Paint()..color = const Color(0xFF8898A6);
      if (acrossX) {
        for (final y in [r.top - 5.0, r.bottom + 5.0]) {
          over.drawLine(Offset(r.left + 3, y), Offset(r.right - 3, y), rail);
          for (var x = r.left + 5; x < r.right - 2; x += 18) {
            over.drawCircle(Offset(x, y), 2.2, posts);
          }
        }
      } else {
        for (final x in [r.left - 5.0, r.right + 5.0]) {
          over.drawLine(Offset(x, r.top + 3), Offset(x, r.bottom - 3), rail);
          for (var y = r.top + 5; y < r.bottom - 2; y += 18) {
            over.drawCircle(Offset(x, y), 2.2, posts);
          }
        }
      }
    }
    return _WorksFabric(under, rec2.endRecording(), hot);
  }

  // ── The glass the works signals with ───────────────────

  /// A lever's glass base: a squashed gold-rimmed rondel the stand is set in —
  /// the mark of a thing you can act on.
  void _drawLeverBase(Canvas canvas, Offset lever) {
    final c = lever + const Offset(0, 16);
    paintContactShadow(canvas, c + const Offset(0, 4), 64, 18, opacity: 0.4);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 0.36);
    paintRondel(
      canvas,
      Offset.zero,
      28,
      _kWorksGlass,
      fill: _kWorksGlass.frostAt(1),
    );
    canvas.restore();
  }

  /// One notch of a lever's quadrant, as a bead of glass: the setting it is
  /// in burns, the others are smoked.
  void _drawNotchBead(Canvas canvas, Offset at, bool set) {
    paintRondel(
      canvas,
      at,
      4.2,
      _kWorksGlass,
      fill: set ? _kWorksGlass.heat(0.9) : _kWorksGlass.smoke,
      rim: set ? 1.0 : 0.5,
      lead: 1.6,
    );
    if (set && _fx.ready) {
      drawGlow(canvas, _fx.glow!, at, 12, _worksEdge.withValues(alpha: 0.35));
    }
  }

  /// A mold flask's glass rim — the form SAYING what it takes. [tint] is the
  /// colour of the metal it wants; [heat] how strongly the rim shows it.
  void _drawFlaskGlass(Canvas canvas, Rect cavity, Color tint, double alpha) {
    final outer = cavity.inflate(7);
    final strips = [
      Rect.fromLTRB(outer.left, outer.top, outer.right, cavity.top),
      Rect.fromLTRB(outer.left, cavity.bottom, outer.right, outer.bottom),
      Rect.fromLTRB(outer.left, cavity.top, cavity.left, cavity.bottom),
      Rect.fromLTRB(cavity.right, cavity.top, outer.right, cavity.bottom),
    ];
    for (final s in strips) {
      paintPane(
        canvas,
        Path()..addRect(s),
        tint,
        _kWorksGlass,
        lead: 1.6,
        opacity: alpha,
      );
    }
    // Mullions across the long strips, so it reads as leaded, not painted.
    final lead = Path();
    for (final t in const [0.25, 0.5, 0.75]) {
      final x = outer.left + outer.width * t;
      lead
        ..moveTo(x, outer.top)
        ..lineTo(x, cavity.top)
        ..moveTo(x, cavity.bottom)
        ..lineTo(x, outer.bottom);
    }
    paintLead(canvas, lead, _kWorksGlass, width: 1.4, opacity: alpha);
  }

  /// The crucible's sight-glass: smoked until the tap wakes, then the melt
  /// itself, shimmering behind leaded glass.
  void _drawCrucibleGlass(Canvas canvas, Rect belly, bool woken) {
    final win = Rect.fromCenter(
      center: belly.center + const Offset(0, 2),
      width: 40,
      height: 18,
    );
    for (var i = 0; i < 3; i++) {
      final pane = Rect.fromLTWH(
        win.left + i * win.width / 3,
        win.top,
        win.width / 3,
        win.height,
      );
      final heat = woken ? 0.72 + 0.14 * sin(works.clock * 2.2 + i * 1.7) : 0.0;
      paintPane(
        canvas,
        Path()..addRect(pane),
        woken ? _kWorksGlass.heat(heat) : _kWorksGlass.smoke,
        _kWorksGlass,
        lead: 2,
      );
    }
    canvas.drawRect(
      win.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _kWorksGlass.gold.withValues(alpha: woken ? 0.8 : 0.4),
    );
  }

  /// The ward lock's keyhole, in glass: smoked while locked, burning while you
  /// hold its key, silver once turned.
  void _drawWardGlass(
    Canvas canvas,
    Offset at, {
    required bool turned,
    required bool holding,
  }) {
    final pulse = 0.5 + 0.5 * sin(works.clock * 3.4);
    final fill = turned
        ? _kWorksGlass.silver
        : holding
        ? _kWorksGlass.heat(0.7 + 0.25 * pulse)
        : _kWorksGlass.smoke;
    paintRondel(
      canvas,
      at - const Offset(0, 4),
      8,
      _kWorksGlass,
      fill: fill,
      rim: turned || holding ? 1.0 : 0.6,
      lead: 2,
    );
    // The keyhole cut through it — the shape of the key.
    final hole = Paint()..color = const Color(0xFF0B0D10);
    canvas.drawCircle(at - const Offset(0, 6), 2.6, hole);
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - 1.8, at.dy - 5)
        ..lineTo(at.dx + 1.8, at.dy - 5)
        ..lineTo(at.dx + 1.2, at.dy + 1)
        ..lineTo(at.dx - 1.2, at.dy + 1)
        ..close(),
      hole,
    );
  }

  // ── The maxim: the Black Glass ──────────────────────────

  /// The obsidian mirror's shards, fitted to the pit.
  List<Path> _blackGlassShards(Offset p) => _collarCache.putIfAbsent(
    'blackglass@${p.dx},${p.dy}',
    () => [
      for (var k = 0; k < 5; k++)
        ellipseSectorPath(
          p,
          0,
          0,
          15,
          9,
          k * 2 * pi / 5 + 0.3,
          (k + 1) * 2 * pi / 5 + 0.3,
          steps: 5,
        ),
      for (var k = 0; k < 9; k++)
        ellipseSectorPath(
          p,
          15,
          9,
          38,
          21,
          k * 2 * pi / 9,
          (k + 1) * 2 * pi / 9,
          steps: 5,
        ),
    ],
  );

  /// THE BLACK GLASS, SET. Melt cooled too fast to be iron, in the one place
  /// the works calls waste — and it gives back your own face. It crystallises
  /// out from the heart of the pit as the rite binds (each shard flashes white
  /// as it takes and cools to black), and after that it is simply there, on
  /// every descent, with the works' fires moving across it.
  void _drawBlackGlass(Canvas canvas, Offset p) {
    final set = works.blackGlass.clamp(0.0, 1.0);
    if (set <= 0) return;
    final shards = _blackGlassShards(p);
    for (var i = 0; i < shards.length; i++) {
      final at = i / shards.length * 0.7;
      final k = ((set - at) / 0.3).clamp(0.0, 1.0);
      if (k <= 0) continue;
      // White as it takes, then down to obsidian.
      final fill = Color.lerp(
        _worksCore,
        i.isEven ? const Color(0xFF07070B) : const Color(0xFF0E1018),
        Curves.easeOut.transform(k),
      )!;
      paintPaneFill(canvas, shards[i], fill, opacity: k);
      paintLead(
        canvas,
        shards[i],
        _kWorksGlass,
        width: 1.8,
        opacity: k,
        light: const Color(0xFFBFD4E2),
      );
    }
    if (set < 1) return;
    // The room's own fires moving across its face.
    final t = (works.clock * 0.18) % 1.0;
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCenter(center: p, width: 76, height: 42)),
    );
    canvas.drawLine(
      p + Offset(-44 + 88 * t, -22),
      p + Offset(-30 + 88 * t, 22),
      Paint()
        ..strokeWidth = 7
        ..color = _worksEdge.withValues(alpha: 0.22 * sin(t * pi)),
    );
    canvas.drawLine(
      p + Offset(-34 + 88 * t, -22),
      p + Offset(-26 + 88 * t, 22),
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFFCFE2F2).withValues(alpha: 0.4 * sin(t * pi)),
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 78, height: 44),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _kWorksGlass.silver.withValues(alpha: 0.55),
    );
    // A TROPHY HAS TO BE SEEN: a cool halo the room's heat never makes, and a
    // glint that catches now and then on the upper shard — enough to find it
    // walking in, never louder than a lever.
    final glint = pow(0.5 + 0.5 * sin(works.clock * 0.9), 6).toDouble();
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        p,
        58,
        _kWorksGlass.silver.withValues(alpha: 0.10 + 0.05 * glint),
      );
    }
    final g = p + const Offset(-13, -8);
    final spark = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.35 + 0.6 * glint);
    final arm = 3 + 5 * glint;
    canvas.drawLine(g - Offset(arm, 0), g + Offset(arm, 0), spark);
    canvas.drawLine(g - Offset(0, arm), g + Offset(0, arm), spark);
  }
}
