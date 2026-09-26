// lib/games/planet_dungeon/planet_dungeon_game_spirit_art.dart
//
// REQUIA, IN GLASS (docs/dungeons.md §7.11) — Spirit's stone and the glass it
// signals with, as a part of planet_dungeon_game.dart.
//
// The grave-field was a translucent wash under pale fog with hollow outlines
// for doors, and every barrow read as the same fogged slab. It now stands
// inside a CHURCHYARD WALL (baked, the same in both worlds — the wall is the
// one thing the dead and the living agree on), under a low cold mist, with
// grave glass in its doorways. The glass:
//
//   · a crossing the OTHER world holds is drawn over its shut glass, doubled
//     and cold, so the road the other body would have is always visible;
//   · a barrow's sigil stone is a rondel of twelve panes — the living half
//     lit ember to a warm eye, the whole ring gold once the mark has taken;
//   · and STUFF OF DREAMS — the maxim — used to leave three scratches on a
//     run-state stone. The blank headstone of the undug grave is now a lancet
//     of leaded glass: a pane lights for each name told (yours), the star at
//     its head last, and it stands lit in both worlds on every later descent.

part of 'planet_dungeon_game.dart';

const GlassPalette _kWraithGlass = kWraithGlass;

final Map<String, ui.Picture> _graveShellCache = {};

extension EchoGraveArt on PlanetDungeonGame {
  void _updateSpiritGlass(double dt) {
    final target =
        discoveredClouds.contains(kSpiritStuffOfDreamsEgg) ||
            _ritePendingEgg == kSpiritStuffOfDreamsEgg
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

  /// The churchyard wall, baked once per room.
  void _renderGraveShell(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _graveShellCache.putIfAbsent(
        '${room.id}|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          paintCarvedRoomShell(
            Canvas(rec),
            b,
            _kWraithGlass,
            GlassRng(glassSeed(room.id, b)),
            doors: [
              for (final d in room.doors)
                if (_doorOnWall(room, d)) d.rect,
            ],
            faceDepth: 44,
            // Blind arches on this face read as a row of black humps.
            arcade: false,
            flags: false,
          );
          return rec.endRecording();
        },
      ),
    );
  }

  /// WHY A WAY IS SHUT, drawn in its doorway over the glass (the 2026-09-25
  /// review: every shut way wore the shared bars and keyhole, and a road the
  /// other world holds was a doubled hairline box).
  ///
  ///  · a crossing a restless dead one blocks, for the living: the stone
  ///    that killed them, lying across it;
  ///  · one a finished dead one has let fall, for the dead: its lintel;
  ///  · salted ground, for the dead: a line of salt across the sill;
  ///  · and if the OTHER body could take it, the doorway carries a faint
  ///    pane of that world's light (cold for the dead, warm for the living).
  ///
  /// And at an open crossing whose dead one you are standing at, ready to
  /// hear out, the lintel that will fall is ghosted in, breathing.
  void _renderGraveOverDoors(Canvas canvas, DungeonRoom room) {
    final a = active;
    for (final door in room.doors) {
      final x = _graveCrossingFor(room, door);
      if (x == null || isDoorHidden(room, door)) continue;
      final r = door.rect;
      if (_field.crossingOpen(x)) {
        if (x.cut != GraveCut.revenant || !_field.isGhost || a == null) {
          continue;
        }
        final dead = graveRevenantById(x.revenantId!);
        if (dead == null || dead.toldAt != room.id) continue;
        if (a.member.element != 'Spirit') continue;
        if ((a.position - dead.seat).distance > _kGraveReach) continue;
        _drawFallenLintel(canvas, r, cold: true, ghosted: true);
        continue;
      }
      final other = _field.openTo(x, otherWorld(_field.world));
      if (other) {
        final pulse = 0.5 + 0.2 * sin(_time * 1.4);
        final tint = _field.isGhost
            ? const Color(0xFFD9A24C)
            : _kWraithGlass.live;
        canvas.drawRect(
          r.deflate(4),
          Paint()
            ..shader = ui.Gradient.radial(r.center, r.longestSide * 0.6, [
              tint.withValues(alpha: 0.30 * pulse),
              tint.withValues(alpha: 0.0),
            ]),
        );
      }
      switch (x.cut) {
        case GraveCut.revenant:
          _drawFallenLintel(canvas, r, cold: _field.isGhost);
        case GraveCut.livingOnly:
          _drawSaltLine(canvas, room, r);
        default:
          break;
      }
    }
  }

  /// Salt across a sill: a band of white grains on the threshold.
  void _drawSaltLine(Canvas canvas, DungeonRoom room, Rect door) {
    final vertical = door.height > door.width;
    final band = vertical
        ? Rect.fromCenter(
            center: door.center,
            width: 10,
            height: door.height * 0.8,
          )
        : Rect.fromCenter(
            center: door.center,
            width: door.width * 0.8,
            height: 10,
          );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(5)),
      Paint()..color = const Color(0xFFE8ECEE).withValues(alpha: 0.75),
    );
    for (var k = 0; k < 9; k++) {
      final t = (k + 0.5) / 9;
      final p = vertical
          ? Offset(
              band.center.dx + (k.isEven ? 4 : -4),
              band.top + band.height * t,
            )
          : Offset(
              band.left + band.width * t,
              band.center.dy + (k.isEven ? 4 : -4),
            );
      canvas.drawCircle(
        p,
        1.6,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  /// A sigil stone: twelve panes on a stone disc.
  void _drawSigilGlass(
    Canvas canvas,
    Offset c,
    int half, {
    required bool warm,
    required bool stamped,
  }) {
    paintCarvedDisc(canvas, c.translate(0, 4), 34, 22, 6, _kWraithGlass);
    for (var i = 0; i < 12; i++) {
      // The living half: six panes from [half], clockwise.
      final inHalf = ((i - half) % 12 + 12) % 12 < 6;
      final a0 = i / 12 * 2 * pi;
      final pane = ellipseSectorPath(c, 8, 5.5, 28, 18, a0, a0 + 2 * pi / 12);
      final fill = stamped
          ? _kWraithGlass.gold
          : warm && inHalf
          ? const Color(0xFFD9A24C)
          : _kWraithGlass.frostAt(i);
      paintPane(canvas, pane, fill, _kWraithGlass, lead: 1.6);
    }
    paintRondel(
      canvas,
      c,
      6,
      _kWraithGlass,
      fill: stamped ? _kWraithGlass.liveCore : _kWraithGlass.smoke,
      rim: stamped ? 1 : 0.4,
      lead: 1.4,
    );
  }

  /// STUFF OF DREAMS: the blank stone as a lancet window, standing on [foot].
  void _drawDreamWindow(Canvas canvas, Offset foot) {
    // Big enough to find from the walk's mouth: it is the room's trophy.
    canvas.save();
    canvas.translate(foot.dx, foot.dy);
    canvas.scale(1.5);
    canvas.translate(-foot.dx, -foot.dy);
    _drawDreamWindowBody(canvas, foot);
    canvas.restore();
  }

  void _drawDreamWindowBody(Canvas canvas, Offset foot) {
    final o = _dreamShown.clamp(0.0, 1.0);
    final r = Rect.fromLTWH(foot.dx - 17, foot.dy - 64, 34, 64);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        r.center,
        70,
        _kWraithGlass.live.withValues(
          alpha: o < 1 ? 0.3 * o : 0.18 + 0.05 * sin(_time * 0.8),
        ),
      );
    }
    // The stone it is cut in.
    paintCarvedBlock(
      canvas,
      Rect.fromLTRB(r.left - 6, r.top - 4, r.right + 6, foot.dy),
      6,
      _kWraithGlass,
      radius: 6,
      topColor: _kWraithGlass.stoneFace,
    );
    final arch = lancetPath(r, AxisDirection.up);
    paintPaneFill(canvas, arch, _kWraithGlass.smoke);
    // Three lights, one per name told (yours), bottom to top.
    for (var i = 0; i < 3; i++) {
      final k = ((o - i * 0.2) / 0.3).clamp(0.0, 1.0);
      final band = Rect.fromLTWH(
        r.left,
        r.bottom - 14.0 * (i + 1),
        r.width,
        14,
      );
      final pane = Path.combine(
        PathOperation.intersect,
        Path()..addRect(band),
        arch,
      );
      paintPane(
        canvas,
        pane,
        Color.lerp(_kWraithGlass.frostAt(i), _kWraithGlass.silver, k)!,
        _kWraithGlass,
        lead: 1.8,
      );
    }
    // The head of the arch: a star, last.
    final star = ((o - 0.65) / 0.35).clamp(0.0, 1.0);
    final head = Path.combine(
      PathOperation.intersect,
      Path()..addRect(Rect.fromLTRB(r.left, r.top, r.right, r.bottom - 42)),
      arch,
    );
    paintPane(
      canvas,
      head,
      Color.lerp(_kWraithGlass.smoke, _kWraithGlass.gold, star)!,
      _kWraithGlass,
      lead: 1.8,
    );
    paintLead(canvas, arch, _kWraithGlass, width: 2.6);
    paintStreak(canvas, r.deflate(5), opacity: 0.5 * o);
  }
}
