// lib/games/planet_dungeon/planet_dungeon_game_crystal_art.dart
//
// VITREA, IN GLASS (docs/dungeons.md §7.11) — Crystal's maxim mark, as a part
// of planet_dungeon_game.dart.
//
// Vitrea is the one planet made of glass already, so the repaint is in its
// own file (planet_dungeon_game_crystal.dart): a chamber is glazed as a
// WINDOW — a border of its colour, a light lattice, a medallion whose petal
// count is its mark — rather than a sheet cut through by long black cracks,
// and it is baked per chamber. The doors are prism glass in the stone.
//
// KNOW THYSELF used to show only while the Black Cell stood wedged in its
// corner again, so on a later descent it was gone. Now the Black Cell's own
// medallion silvers, petal after petal, as the rite binds — black glass gone
// to a mirror — and it stays silver wherever the keep puts the cell.

part of 'planet_dungeon_game.dart';

const GlassPalette _kPrismGlass = kPrismGlass;

/// The lamp's beam, as a course for its grains: down the middle of the band.
final List<Offset> _kBeamCourse = [
  Offset(kBeamBand.left, kBeamBand.center.dy),
  Offset(kBeamBand.right, kBeamBand.center.dy),
];

/// The beam's grains at each step of the wheel, built once.
final Map<int, List<Color>> _beamGrainRamps = {};

/// The closed elliptical courses held notes circle on, by key.
final Map<String, List<Offset>> _noteCourses = {};

/// The beam's grains for wheel step [hue]: its colour, lit toward white.
List<Color> _beamGrainRamp(int hue) => _beamGrainRamps.putIfAbsent(hue, () {
  final c = PrismLabyrinthKeep._wheelColour(hue);
  return [
    Color.lerp(c, const Color(0xFF0A0810), 0.4)!,
    c,
    Color.lerp(c, Colors.white, 0.5)!,
    Colors.white,
  ];
});

extension PrismLabyrinthArt on PlanetDungeonGame {
  /// A note held in the glass (2026-10-08): grains of brass light circling
  /// an ellipse [rx] × [ry] about [c] in a band, each at its own pace, so
  /// the ring shears and never stands still. 260 grains.
  void _paintNoteRing(
    Canvas canvas,
    Offset c,
    double rx,
    double ry,
    String key, {
    double alpha = 0.85,
  }) {
    final course = _noteCourses.putIfAbsent(
      '$key@${c.dx},${c.dy}',
      () => [
        for (var i = 0; i <= 48; i++)
          c + Offset(cos(i / 48 * 2 * pi) * rx, sin(i / 48 * 2 * pi) * ry),
      ],
    );
    paintGrainStream(
      canvas,
      course,
      _time,
      ramp: const [
        Color(0xFF6E5A30),
        Color(0xFFC9A24E),
        Color(0xFFE4C16A),
        Color(0xFFFFF2C8),
      ],
      count: 260,
      speed: 0.09,
      jitter: ry * 0.3,
      alpha: alpha,
      width: 1.6,
      trail: 0.12,
      loop: true,
    );
  }

  void _updateCrystalGlass(double dt) {
    final target =
        discoveredClouds.contains(kCrystalKnowThyselfEgg) ||
            _ritePendingEgg == kCrystalKnowThyselfEgg
        ? 1.0
        : 0.0;
    if (_mirrorShown < 0) {
      _mirrorShown = target;
    } else if (_mirrorShown < target) {
      _mirrorShown = min(target, _mirrorShown + dt / 2.4);
    } else if (_mirrorShown > target) {
      _mirrorShown = target;
    }
  }

  /// The Black Cell's medallion, silvered: ten petals of mirror glass, and
  /// at the heart a bright eye looking back.
  void _drawKnowThyselfMirror(Canvas canvas, Offset c) {
    final o = _mirrorShown.clamp(0.0, 1.0);
    if (o <= 0) return;
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        70,
        _kPrismGlass.silver.withValues(
          alpha: o < 1 ? 0.3 * o : 0.16 + 0.04 * sin(_time * 1.1),
        ),
      );
    }
    const n = 10;
    for (var k = 0; k < n; k++) {
      final s = ((o - k * 0.06) / 0.4).clamp(0.0, 1.0);
      if (s <= 0) continue;
      final a0 = -pi / 2 + k * 2 * pi / n;
      final pane = sectorPath(c, 16, 50, a0, a0 + 2 * pi / n);
      paintPane(
        canvas,
        pane,
        Color.lerp(
          const Color(0xFF2A2733),
          k.isEven ? _kPrismGlass.silver : const Color(0xFFC8C4D6),
          s,
        )!,
        _kPrismGlass,
        lead: 2.0,
      );
    }
    final eye = ((o - 0.65) / 0.35).clamp(0.0, 1.0);
    if (eye > 0) {
      paintRondel(
        canvas,
        c,
        14,
        _kPrismGlass,
        fill: Color.lerp(const Color(0xFF2A2733), Colors.white, eye),
        lead: 2.0,
      );
      canvas.drawCircle(c, 4 * eye, Paint()..color = const Color(0xFF16121E));
    }
    paintStreak(
      canvas,
      Rect.fromCircle(center: c, radius: 40),
      opacity: 0.55 * o,
    );
  }
}
