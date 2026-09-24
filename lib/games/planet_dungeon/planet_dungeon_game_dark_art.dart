// lib/games/planet_dungeon/planet_dungeon_game_dark_art.dart
//
// NYTHRALOR, IN GLASS (docs/dungeons.md §7.11) — Dark's stone and the glass
// it signals with, as a part of planet_dungeon_game.dart.
//
// The vault keeps its inside-out ground (corona stone, umbra edges); it gains
// WALLS — baked, iron-dark ashlar — umbra glass in its doorways, and a low
// violet dust instead of the pale sky fog that lay over every lit quarter.
// The glass:
//
//   · every gnomon is what its comment always said it was — a finger of
//     BLACK GLASS, now leaded in two facets, the lit one catching violet;
//   · and THE FOURTH FINGER — the maxim — rises from the well to stand at
//     the rim as the rite binds, lit from inside, and stands there on every
//     later descent.

part of 'planet_dungeon_game.dart';

const GlassPalette _kUmbraGlass = kUmbraGlass;

final Map<String, ui.Picture> _vaultShellCache = {};

extension EclipseVaultArt on PlanetDungeonGame {
  void _updateDarkGlass(double dt) {
    final target =
        discoveredClouds.contains(kDarkAbyssEggId) ||
            _ritePendingEgg == kDarkAbyssEggId
        ? 1.0
        : 0.0;
    if (_fingerShown < 0) {
      _fingerShown = target;
    } else if (_fingerShown < target) {
      _fingerShown = min(target, _fingerShown + dt / 2.2);
    } else if (_fingerShown > target) {
      _fingerShown = target;
    }
  }

  void _renderVaultShell(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    canvas.drawPicture(
      _vaultShellCache.putIfAbsent(
        '${room.id}|${b.width.round()}x${b.height.round()}',
        () {
          final rec = ui.PictureRecorder();
          paintCarvedRoomShell(
            Canvas(rec),
            b,
            _kUmbraGlass,
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

  /// A finger of black glass: two leaded facets on a point. [lit] 0..1
  /// fills it with violet from inside.
  void _drawGlassFinger(
    Canvas canvas,
    Offset at,
    double h,
    double w, {
    required double lit,
  }) {
    final foot = at.dy + h * 0.3;
    final shoulder = at.dy - h * 0.5;
    final tip = Offset(at.dx, at.dy - h * 0.66);
    final left = Path()
      ..moveTo(at.dx - w / 2, foot)
      ..lineTo(at.dx - w * 0.3, shoulder)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(at.dx, foot)
      ..close();
    final right = Path()
      ..moveTo(at.dx, foot)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(at.dx + w * 0.3, shoulder)
      ..lineTo(at.dx + w / 2, foot)
      ..close();
    paintPane(
      canvas,
      left,
      Color.lerp(_kUmbraGlass.smoke, _kUmbraGlass.liveDeep, 0.3 + 0.7 * lit)!,
      _kUmbraGlass,
      lead: 1.8,
    );
    paintPane(
      canvas,
      right,
      Color.lerp(const Color(0xFF3A2E52), _kUmbraGlass.live, lit)!,
      _kUmbraGlass,
      lead: 1.8,
    );
    // One cold gleam down the lit facet.
    canvas.drawLine(
      Offset(at.dx + w * 0.12, shoulder + 4),
      Offset(at.dx + w * 0.2, foot - 8),
      Paint()
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35 + 0.3 * lit),
    );
  }

  /// THE FOURTH FINGER, risen and kept.
  void _drawFourthFinger(Canvas canvas, Offset at) {
    // A found maxim stands even before the easing has caught up.
    final o = _fingerShown < 0 ? 1.0 : _fingerShown.clamp(0.0, 1.0);
    final rise = Curves.easeOut.transform(o);
    final stand = at + Offset(0, 40 * (1 - rise));
    if (_fx.ready && o > 0) {
      drawGlow(
        canvas,
        _fx.glow!,
        stand,
        60 + 20 * o,
        _kUmbraGlass.live.withValues(
          alpha: o < 1 ? 0.35 * o : 0.2 + 0.05 * sin(_time * 1.2),
        ),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: stand + const Offset(0, 24),
        width: 46,
        height: 16,
      ),
      Paint()..color = const Color(0xFF6B5A2E).withValues(alpha: 0.9),
    );
    _drawGlassFinger(canvas, stand, 72 + 8 * o, 18, lit: o);
  }
}
