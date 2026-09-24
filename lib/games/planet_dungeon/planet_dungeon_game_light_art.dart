// lib/games/planet_dungeon/planet_dungeon_game_light_art.dart
//
// LUMENHOLD, IN GLASS (docs/dungeons.md §7.11) — Light's stone and the glass
// it signals with, as a part of planet_dungeon_game.dart.
//
// The archive's fabric was already baked; it is now clipped square inside
// baked limestone WALLS, with archive glass in its doorways. The glass:
//
//   · the catalogue's ten cells are panes of archive glass, gold where the
//     hall is lit and smoked where it is not — still the live map it was;
//   · and AFRAID OF THE LIGHT — the maxim — used to leave an empty slab. The
//     volume that would only come out in the dark now lies in it: a book of
//     smoked night glass on a gold clasp that opens as the rite binds, its
//     pages lit from inside, and lies open on every later descent.

part of 'planet_dungeon_game.dart';

const GlassPalette _kLumenGlass = kLumenGlass;

final Map<String, ui.Picture> _archiveShellCache = {};

extension BeaconArchiveArt on PlanetDungeonGame {
  void _updateLightGlass(double dt) {
    final target =
        discoveredClouds.contains(kLightAfraidEggId) ||
            _ritePendingEgg == kLightAfraidEggId
        ? 1.0
        : 0.0;
    if (_volumeShown < 0) {
      _volumeShown = target;
    } else if (_volumeShown < target) {
      _volumeShown = min(target, _volumeShown + dt / 2.2);
    } else if (_volumeShown > target) {
      _volumeShown = target;
    }
  }

  void _renderArchiveShell(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _archiveShellCache.putIfAbsent(
        '${room.id}|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          paintCarvedRoomShell(
            Canvas(rec),
            b,
            _kLumenGlass,
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

  /// One cell of the catalogue, as a pane.
  void _drawIndexPane(Canvas canvas, Rect pane, bool lit, int seed) {
    paintPane(
      canvas,
      Path()..addRect(pane),
      lit ? _kLumenGlass.live : _kLumenGlass.frostAt(seed),
      _kLumenGlass,
      lead: 2,
    );
    if (lit) paintStreak(canvas, pane.deflate(3), opacity: 0.45);
  }

  /// AFRAID OF THE LIGHT: the volume, lying open in its slab.
  void _drawAfraidVolume(Canvas canvas, Offset at) {
    // Big enough to find across the stair: it is the room's trophy.
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1.6);
    canvas.translate(-at.dx, -at.dy);
    _drawAfraidVolumeBody(canvas, at);
    canvas.restore();
  }

  void _drawAfraidVolumeBody(Canvas canvas, Offset at) {
    final o = _volumeShown < 0 ? 1.0 : _volumeShown.clamp(0.0, 1.0);
    final open = Curves.easeInOut.transform(o);
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        50 + 20 * open,
        _kLumenGlass.live.withValues(
          alpha: o < 1 ? 0.3 * open : 0.16 + 0.04 * sin(_time * 1.4),
        ),
      );
    }
    // The slab's dark mouth.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: 52, height: 34),
        const Radius.circular(3),
      ),
      Paint()..color = _kLumenGlass.smoke,
    );
    // The pages: lit from inside, showing as the covers part.
    final pages = Rect.fromCenter(center: at, width: 36, height: 24);
    paintPane(
      canvas,
      Path()..addRect(pages),
      Color.lerp(_kLumenGlass.smoke, _kLumenGlass.liveCore, open)!,
      _kLumenGlass,
      lead: 1.4,
    );
    canvas.drawLine(
      pages.topCenter,
      pages.bottomCenter,
      Paint()
        ..strokeWidth = 1.4
        ..color = _kLumenGlass.lead,
    );
    for (var k = 0; k < 3; k++) {
      for (final side in const [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(at.dx + side * 4, pages.top + 6 + k * 5),
          Offset(at.dx + side * 14, pages.top + 6 + k * 5),
          Paint()
            ..strokeWidth = 1
            ..color = _kLumenGlass.goldDeep.withValues(alpha: 0.6 * open),
        );
      }
    }
    // The two covers of night glass, swung back from the spine.
    for (final side in const [-1.0, 1.0]) {
      final w = 18.0 * (1 - open) + 6 * open;
      final inner = at.dx;
      final outer = inner + side * (18 + 8 * open);
      final cover = Path()
        ..moveTo(inner, pages.top - 1)
        ..lineTo(outer - side * (18 - w), pages.top - 3 * open)
        ..lineTo(outer - side * (18 - w), pages.bottom + 3 * open)
        ..lineTo(inner, pages.bottom + 1)
        ..close();
      if (open < 0.98) {
        paintPane(
          canvas,
          cover,
          const Color(0xFF1C2030),
          _kLumenGlass,
          lead: 1.6,
          opacity: 1 - 0.7 * open,
        );
      }
    }
    // The clasp, gold, on the spine.
    paintRondel(
      canvas,
      Offset(at.dx, pages.bottom + 2),
      3.5,
      _kLumenGlass,
      fill: _kLumenGlass.gold,
      lead: 1.2,
    );
  }
}
