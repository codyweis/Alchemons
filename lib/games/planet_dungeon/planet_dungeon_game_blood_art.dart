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
