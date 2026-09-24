// lib/games/planet_dungeon/planet_dungeon_game_glass.dart
//
// THE GLASS-INLAY PIECES EVERY PLANET SHARES (docs/dungeons.md §7.11), as a
// part of planet_dungeon_game.dart: doorways of glass in the stone, hidden
// doors bricked back as wall, and the live pane that warms over its baked
// dormant self. A planet opts in with a palette in [_glassPalettes]; its own
// rooms live in its *_art.dart file.

part of 'planet_dungeon_game.dart';

/// The planets repainted in glass, and the glass each is made of.
const Map<String, GlassPalette> _glassPalettes = {
  'Fire': kCinderGlass,
  'Lava': kBasaltGlass,
  'Air': kZephyrGlass,
  'Lightning': kVoltGlass,
  'Earth': kBarrowGlass,
  'Water': kTempleGlass,
  'Steam': kVaporGlass,
  'Poison': kVenomGlass,
  'Ice': kFrostGlass,
  'Mud': kPeatGlass,
  'Dust': kSandGlass,
  'Crystal': kPrismGlass,
  'Plant': kVerdantGlass,
  'Spirit': kWraithGlass,
  'Dark': kUmbraGlass,
  'Light': kLumenGlass,
  'Blood': kSanguineGlass,
};

extension DungeonGlassArt on PlanetDungeonGame {
  bool get _isGlassPlanet => _glassPalettes.containsKey(layout.element);

  GlassPalette get _glass => _glassPalettes[layout.element] ?? kCinderGlass;

  /// Machinery wants a square head; a cathedral wants a point.
  bool get _glassSquareHeads =>
      const {'Lava', 'Lightning', 'Steam'}.contains(layout.element);

  /// A door that has not been revealed is WALL, not a gap in it: the baked
  /// stone leaves every doorway open, so a hidden one is bricked back here —
  /// and the entry door splits its way open on the entry reveal's clock.
  /// Is [d] cut through one of the room's walls? Some planets have doors
  /// standing out in the room (Mud's wallows); those keep their own look.
  bool _doorOnWall(DungeonRoom room, DungeonDoor d) {
    final b = room.bounds, r = d.rect;
    return r.top <= b.top + 1 ||
        r.bottom >= b.bottom - 1 ||
        r.left <= b.left + 1 ||
        r.right >= b.right - 1;
  }

  void _renderGlassDoorPlugs(Canvas canvas, DungeonRoom room) {
    for (final d in room.doors) {
      if (!_doorOnWall(room, d)) continue;
      final entry = layout.entranceRevealDoor?.matches(room, d) ?? false;
      if (isDoorHidden(room, d)) {
        _drawSealedWall(canvas, room, d, 1.0);
      } else if (entry && _entryReveal < 1.0) {
        _drawSealedWall(canvas, room, d, 1.0 - _entryReveal);
      }
    }
  }

  // ── Doors: glass set in the stone ───────────────────────

  /// A doorway: a window of the planet's live glass set in carved jambs —
  /// pointed on a planet of arches, square-headed on a planet of machines.
  /// Open, it glows and breathes light outward; sealed, it is smoked glass
  /// under iron bars, and the finale's bars carry the two stars that open it.
  void _drawGlassDoor(Canvas canvas, DungeonRoom room, DungeonDoor d) {
    // The entry door comes up out of the splitting stone on the hearth's own
    // clock, rather than appearing whole the frame the fire takes.
    final entry = layout.entranceRevealDoor?.matches(room, d) ?? false;
    if (entry && _entryReveal < 1.0) {
      final appear = Curves.easeIn.transform(_entryReveal.clamp(0.0, 1.0));
      if (appear <= 0.01) return;
      canvas.saveLayer(
        d.rect.inflate(40),
        Paint()..color = Colors.white.withValues(alpha: appear),
      );
      _drawGlassDoorBody(canvas, room, d);
      canvas.restore();
      return;
    }
    _drawGlassDoorBody(canvas, room, d);
  }

  void _drawGlassDoorBody(Canvas canvas, DungeonRoom room, DungeonDoor d) {
    final b = room.bounds;
    final r = d.rect;
    final AxisDirection out;
    if (r.top <= b.top + 1) {
      out = AxisDirection.up;
    } else if (r.bottom >= b.bottom - 1) {
      out = AxisDirection.down;
    } else if (r.left <= b.left + 1) {
      out = AxisDirection.left;
    } else {
      out = AxisDirection.right;
    }
    final vertical = out == AxisDirection.left || out == AxisDirection.right;
    // The glass fills the doorway and reaches back into the wall's depth.
    final glass = switch (out) {
      AxisDirection.up => Rect.fromLTRB(
        r.left + 10,
        b.top - 2,
        r.right - 10,
        b.top + kGlassWallFace + 4,
      ),
      AxisDirection.down => Rect.fromLTRB(
        r.left + 10,
        r.top + 2,
        r.right - 10,
        r.bottom + 6,
      ),
      AxisDirection.left => Rect.fromLTRB(
        r.left - 6,
        r.top + 8,
        r.right - 2,
        r.bottom - 8,
      ),
      AxisDirection.right => Rect.fromLTRB(
        r.left + 2,
        r.top + 8,
        r.right + 6,
        r.bottom - 8,
      ),
    };
    final locked = isDoorLocked(room, d);
    final arch = _glassSquareHeads
        ? archedHeadPath(glass, out)
        : lancetPath(glass, out);

    // Carved jambs either side of the opening.
    final jambs = vertical
        ? [
            Rect.fromLTWH(glass.left - 1, glass.top - 12, glass.width + 2, 8),
            Rect.fromLTWH(glass.left - 1, glass.bottom + 2, glass.width + 2, 8),
          ]
        : [
            Rect.fromLTWH(glass.left - 13, glass.bottom - 12, 11, 12),
            Rect.fromLTWH(glass.right + 2, glass.bottom - 12, 11, 12),
          ];
    for (final j in jambs) {
      paintCarvedBlock(canvas, j, 5, _glass, radius: 2);
    }

    final pulse = 0.5 + 0.5 * sin(_time * 1.6 + r.left * 0.013 + r.top * 0.01);
    if (!locked) {
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          glass.center,
          glass.longestSide * 0.95,
          _glass.live.withValues(alpha: 0.10 + 0.06 * pulse),
        );
      }
      paintPaneFill(
        canvas,
        arch,
        _glass.heat(0.52 + 0.08 * pulse),
        opacity: 0.92,
      );
    } else {
      paintPaneFill(canvas, arch, _glass.smoke, opacity: 0.96);
    }

    // The tracery: a mullion down the middle, two transoms, and a roundel in
    // the arch's head.
    final lead = Path()..addPath(arch, Offset.zero);
    final head = switch (out) {
      AxisDirection.up => Offset(
        glass.center.dx,
        glass.top + glass.height * 0.26,
      ),
      AxisDirection.down => Offset(
        glass.center.dx,
        glass.bottom - glass.height * 0.26,
      ),
      AxisDirection.left => Offset(
        glass.left + glass.width * 0.26,
        glass.center.dy,
      ),
      AxisDirection.right => Offset(
        glass.right - glass.width * 0.26,
        glass.center.dy,
      ),
    };
    final roundel = glass.shortestSide * 0.18;
    lead.addOval(Rect.fromCircle(center: head, radius: roundel));
    if (vertical) {
      lead
        ..moveTo(glass.left, glass.center.dy)
        ..lineTo(glass.right, glass.center.dy);
      for (final t in const [0.55, 0.8]) {
        final x = out == AxisDirection.left
            ? glass.left + glass.width * t
            : glass.right - glass.width * t;
        lead
          ..moveTo(x, glass.top)
          ..lineTo(x, glass.bottom);
      }
    } else {
      lead
        ..moveTo(glass.center.dx, glass.top)
        ..lineTo(glass.center.dx, glass.bottom);
      for (final t in const [0.55, 0.8]) {
        final y = out == AxisDirection.up
            ? glass.top + glass.height * t
            : glass.bottom - glass.height * t;
        lead
          ..moveTo(glass.left, y)
          ..lineTo(glass.right, y);
      }
    }
    canvas.save();
    canvas.clipPath(arch);
    if (!locked) paintStreak(canvas, glass.deflate(4), opacity: 0.5);
    paintLead(canvas, lead, _glass, width: 2.2);
    canvas.restore();
    paintLead(canvas, arch, _glass, width: 3.2);

    if (!locked) {
      // Light breathing OUT through the glass: motes riding outward, so a
      // doorway reads as a way on before it reads as a window.
      if (_fx.ready) {
        final dir = switch (out) {
          AxisDirection.up => const Offset(0, -1),
          AxisDirection.down => const Offset(0, 1),
          AxisDirection.left => const Offset(-1, 0),
          AxisDirection.right => const Offset(1, 0),
        };
        final across = Offset(-dir.dy, dir.dx);
        for (var i = 0; i < 3; i++) {
          final t = ((_time * 0.35 + i / 3) % 1.0).toDouble();
          final p =
              glass.center -
              dir * (glass.longestSide * 0.35) +
              dir * (glass.longestSide * 0.8 * t) +
              across * (sin(_time * 2.1 + i * 2.3) * glass.shortestSide * 0.22);
          drawGlow(
            canvas,
            _fx.mote!,
            p,
            3.2,
            _glass.liveCore.withValues(alpha: 0.55 * sin(t * pi)),
          );
        }
      }
      return;
    }

    // SEALED: iron bars across, and what opens it shown on the bars.
    final bar = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF221A15);
    final barHi = Paint()
      ..strokeWidth = 1
      ..color = _glass.stoneTop.withValues(alpha: 0.6);
    for (final t in const [0.34, 0.66]) {
      final (a, z) = vertical
          ? (
              Offset(glass.left + 2, glass.top + glass.height * t),
              Offset(glass.right - 2, glass.top + glass.height * t),
            )
          : (
              Offset(glass.left + glass.width * t, glass.top + 2),
              Offset(glass.left + glass.width * t, glass.bottom - 2),
            );
      canvas.drawLine(a, z, bar);
      canvas.drawLine(
        a + const Offset(-0.5, -1),
        z + const Offset(-0.5, -1),
        barHi,
      );
    }
    final isFinale = layout.finaleDoor?.matches(room, d) ?? false;
    final lockPulse = 0.55 + 0.25 * sin(_time * 1.8);
    if (isFinale) {
      for (var i = 0; i < 2; i++) {
        final delta = (i == 0 ? -1 : 1) * glass.shortestSide * 0.28;
        final gp = vertical
            ? glass.center + Offset(0, delta)
            : glass.center + Offset(delta, 0);
        final lit = hasStar(i);
        paintRondel(
          canvas,
          gp,
          7.5,
          _glass,
          fill: lit ? _glass.heat(0.9) : _glass.smoke,
          rim: lit ? 1.0 : 0.55,
          lead: 2.4,
        );
        if (lit && _fx.ready) {
          drawGlow(
            canvas,
            _fx.glow!,
            gp,
            14,
            _glass.gold.withValues(alpha: 0.35 + 0.12 * sin(_time * 2.4 + i)),
          );
        }
        _drawStarGlyph(
          canvas,
          gp,
          4.6,
          (lit ? const Color(0xFF3A1206) : _glass.goldDeep).withValues(
            alpha: lit ? 0.9 : 0.7,
          ),
        );
      }
    } else {
      paintRondel(
        canvas,
        glass.center,
        8,
        _glass,
        fill: const Color(0xFF120C0A),
        rim: lockPulse,
        lead: 2.4,
      );
      canvas.drawCircle(
        glass.center + const Offset(0, -1.5),
        1.8,
        Paint()..color = _glass.gold.withValues(alpha: lockPulse),
      );
      canvas.drawLine(
        glass.center + const Offset(0, -0.5),
        glass.center + const Offset(0, 3.5),
        Paint()
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = _glass.gold.withValues(alpha: lockPulse),
      );
    }
  }

  /// Stone laid back over a doorway that is not open yet. [solid] 1 is whole
  /// wall; as it falls toward 0 the stone splits along glowing seams and
  /// fades — the inner doors grinding apart as the hearth catches.
  void _drawSealedWall(
    Canvas canvas,
    DungeonRoom room,
    DungeonDoor d,
    double solid,
  ) {
    if (solid <= 0.01) return;
    final b = room.bounds;
    final r = d.rect;
    final Rect plug;
    if (r.top <= b.top + 1) {
      plug = Rect.fromLTRB(
        r.left - 6,
        b.top,
        r.right + 6,
        b.top + kGlassWallFace,
      );
    } else if (r.bottom >= b.bottom - 1) {
      plug = Rect.fromLTRB(
        r.left - 6,
        b.bottom - kGlassWallTop,
        r.right + 6,
        b.bottom,
      );
    } else if (r.left <= b.left + 1) {
      plug = Rect.fromLTRB(
        b.left,
        r.top - 6,
        b.left + kGlassWallTop,
        r.bottom + 6,
      );
    } else {
      plug = Rect.fromLTRB(
        b.right - kGlassWallTop,
        r.top - 6,
        b.right,
        r.bottom + 6,
      );
    }
    final face = plug.height > plug.width && plug.height > kGlassWallFace;
    canvas.drawRect(
      plug,
      Paint()
        ..color =
            (plug.height == kGlassWallFace ? _glass.stoneFace : _glass.stoneTop)
                .withValues(alpha: 0.95 * solid),
    );
    if (plug.height == kGlassWallFace) {
      canvas.drawRect(
        Rect.fromLTRB(plug.left, plug.top, plug.right, plug.top + 7),
        Paint()..color = _glass.stoneTop.withValues(alpha: solid),
      );
    }
    final seam = Paint()
      ..strokeWidth = 1.2
      ..color = _glass.joint.withValues(alpha: 0.6 * solid);
    if (face || plug.width < plug.height) {
      for (var y = plug.top + 14; y < plug.bottom; y += 16) {
        canvas.drawLine(Offset(plug.left, y), Offset(plug.right, y), seam);
      }
    }
    if (solid < 1.0) {
      // Splitting: seams of hearth-light open through the stone.
      final crack = Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = _glass.live.withValues(alpha: 0.9 * (1 - solid) * solid * 3);
      final c = plug.center;
      final along = plug.height > plug.width
          ? Offset(0, plug.height * 0.4)
          : Offset(plug.width * 0.4, 0);
      canvas.drawLine(c - along, c + along * 0.2 + const Offset(2, 3), crack);
      canvas.drawLine(c + along * 0.2 + const Offset(2, 3), c + along, crack);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          c,
          plug.longestSide * 0.7,
          _glass.live.withValues(alpha: 0.3 * (1 - solid)),
        );
      }
    }
  }

  /// A live pane over its baked dormant self: the glass warming toward [heat].
  void _heatPane(
    Canvas canvas,
    Path pane,
    double heat, {
    double opacity = 0.95,
    Color? cold,
    double lead = 2.2,
  }) {
    if (heat <= 0.01) return;
    final o = opacity * min(1.0, heat * 2.2);
    paintPaneFill(canvas, pane, _glass.heat(heat, cold: cold), opacity: o);
    // The lead stays over the light: lit glass is still leaded glass, and a
    // run of lit panes without it melts into one flat shape.
    paintLead(canvas, pane, _glass, width: lead, opacity: o);
  }
}
