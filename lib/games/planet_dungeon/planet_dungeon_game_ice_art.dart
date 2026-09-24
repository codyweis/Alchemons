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
