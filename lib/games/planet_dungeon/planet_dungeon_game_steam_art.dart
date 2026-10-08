// lib/games/planet_dungeon/planet_dungeon_game_steam_art.dart
//
// VAPORIS, IN GLASS (docs/dungeons.md §7.11) — Steam's stone and the glass it
// signals with, as a part of planet_dungeon_game.dart.
//
// The boiler house kept its brickwork (firebrick courses, the ring-main sunk
// in the floor, the condensate grate — the 2026-09-02 pass, and it was right).
// What changes is that it is BAKED, it gets walls, and the working parts wear
// gauge glass, which is the one glass a boiler house really has:
//
//   · a junction's release wheel has a glass hub, lit when the main can pay;
//   · the firebox is seen through a sight-glass;
//   · a crucible corner's wanted elements are panes of that element's glass,
//     silver-capped once sealed;
//   · the entry vent's wheel carries a glass hub;
//   · and HIDDEN HARMONY — the maxim — used to leave only an empty socket.
//     Now the sigil you took sinks INTO the plinth as the rite binds and
//     stays there as an inlay of steam glass, condensation running on it.

part of 'planet_dungeon_game.dart';

const GlassPalette _kGaugeGlass = kVaporGlass;

final Map<String, ui.Picture> _vaporFabricCache = {};

// ── VAPOUR, IN GRAINS (2026-10-08) ──────────────────────────
//
// Steam on this planet was sprite puffs and soft glows: the sky's drifting
// cloud blobs, grey smudges climbing the rooms, a pale lozenge for the split
// main's jet. It is grains now, the way the rest of the game draws breath and
// smoke — many small lights on real motion, short trails, a little twinkle.
// The geyser plumes keep their puffs: they are the blast's telegraph, twelve
// of them go at once in the crucible, and in grains that is past the budget.

/// Steam's grains: shadow, body, lit, glint.
const List<Color> _kVaporRamp = [
  Color(0xFF4A5560),
  Color(0xFF8A97A6),
  Color(0xFFC8D0DA),
  Color(0xFFF6E9EE),
];

/// The batch every vapour run is drawn through: grains bucketed by shade and
/// by one of [_kVaporFades] alphas, so a run of hundreds is a handful of
/// draws. Fine grains (1.6), which is what makes vapour read as vapour.
class _VaporBatch {
  final List<List<Offset>> _lines = [
    for (var i = 0; i < 4 * _kVaporFades; i++) <Offset>[],
  ];
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void add(Offset p, Offset q, int shade, double alpha) {
    if (alpha <= 0.02) return;
    final f = min(_kVaporFades - 1, (alpha * _kVaporFades).floor());
    // A trail too short to draw is nudged so the cap still makes a grain.
    final from = (p - q).distanceSquared < 0.09 ? q - const Offset(0.3, 0) : p;
    _lines[shade * _kVaporFades + f]
      ..add(from)
      ..add(q);
  }

  void paint(Canvas canvas, List<Color> ramp, {double width = 1.6}) {
    _paint.strokeWidth = width;
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.isEmpty) continue;
      final f = (i % _kVaporFades + 1) / _kVaporFades;
      _paint.color = ramp[i ~/ _kVaporFades].withValues(alpha: f);
      canvas.drawPoints(ui.PointMode.lines, l, _paint);
      l.clear();
    }
  }
}

const int _kVaporFades = 5;
final _VaporBatch _vaporBatch = _VaporBatch();

double _vaporHash(int n) {
  final v = sin(n * 127.1 + 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

/// A WISP OF VAPOUR: [count] grains leave [from] along [dir] (a unit
/// vector), each taking about 1/[rate] seconds to travel [length] — quick off
/// the mouth and slowing as it spends itself when [ease] > 1 — and opening
/// from [w0] to [w1] across the run as it climbs. The whole wisp snakes: a
/// curl [curl] wide at the top travels up it, so it reads as ONE thread of
/// steam turning in the air rather than a spray of separate grains. Grains
/// crowd its middle and thin to its edges. Worked out from time alone, so
/// nothing is kept between frames. Added to [_vaporBatch]; the caller paints.
void _addVaporRun(
  Offset from,
  Offset dir,
  double length,
  double t, {
  required int count,
  required double rate,
  double w0 = 2,
  double w1 = 18,
  double ease = 1.4,
  double curl = 10,
  double wave = 120,
  double alpha = 0.6,
  int seed = 0,
  double trail = 0.02,
  double hot = 0.2,
}) {
  final perp = Offset(-dir.dy, dir.dx);
  final phase = seed * 1.7;
  for (var i = 0; i < count; i++) {
    final h1 = _vaporHash(seed * 7919 + i);
    final h2 = _vaporHash(seed * 1543 + i * 3 + 1);
    final h3 = _vaporHash(seed * 31 + i * 7 + 2);
    final speed = rate * (0.85 + 0.3 * h3);
    // Crowded to the middle: two hashes summed fall mostly near zero.
    final side = h2 + h3 - 1;
    Offset at(double tt) {
      final u = (tt * speed + h1) % 1.0;
      final along = length * (1 - pow(1 - u, ease).toDouble());
      final snake =
          curl *
          pow(u, 0.8).toDouble() *
          sin(along / wave * 2 * pi - tt * 1.6 + phase);
      final spread = (w0 + (w1 - w0) * pow(u, 1.1).toDouble()) * side;
      return from + dir * along + perp * (snake + spread);
    }

    final u = (t * speed + h1) % 1.0;
    final u0 = ((t - trail) * speed + h1) % 1.0;
    final q = at(t);
    // Just born this frame: a grain, not a streak back across the run.
    final p = u0 > u ? q : at(t - trail);
    final fade = min(1.0, u * 8) * pow(1 - u, 1.5).toDouble();
    final shade = h1 > 0.985
        ? 3
        : (u < hot && side.abs() < 0.3) || h1 > 0.8
        ? 2
        : h1 > 0.3
        ? 1
        : 0;
    _vaporBatch.add(p, q, shade, alpha * fade);
  }
}

/// The haze the open sky's vapour rises through, baked per viewport.
final Map<String, ui.Picture> _vaporSkyHaze = {};

/// Where the open sky's columns stand, as fractions of the view's width.
const List<double> _kVaporSkyColumns = [0.08, 0.5, 0.92];

extension MoltenLabyrinthArt on PlanetDungeonGame {
  void _updateSteamGlass(double dt) {
    final target =
        discoveredClouds.contains(kSteamHiddenHarmonyEggId) ||
            _ritePendingEgg == kSteamHiddenHarmonyEggId
        ? 1.0
        : 0.0;
    if (_harmonySet < 0) {
      _harmonySet = target;
    } else if (_harmonySet < target) {
      _harmonySet = min(target, _harmonySet + dt / 2.4);
    } else if (_harmonySet > target) {
      _harmonySet = target;
    }
  }

  /// The boiler house's floor and walls, baked once per room.
  void _renderVaporFabric(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final key = '${room.id}|${b.width.round()}x${b.height.round()}';
    canvas.drawPicture(
      _vaporFabricCache.putIfAbsent(key, () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        _renderPlainFloor(c, b, false);
        _drawFoundryFloor(c, room);
        paintCarvedRoomShell(
          c,
          b,
          _kGaugeGlass,
          GlassRng(glassSeed(room.id, b)),
          doors: room.doors.map((d) => d.rect),
          arcade: false,
          flags: false,
        );
        return rec.endRecording();
      }),
    );
  }

  /// A wheel's glass hub: lit gauge-glass when it can act, smoked when not.
  void _drawGaugeHub(
    Canvas canvas,
    Offset p, {
    required bool lit,
    double r = 6,
  }) {
    paintRondel(
      canvas,
      p,
      r,
      _kGaugeGlass,
      fill: lit
          ? _kGaugeGlass.heat(0.78 + 0.1 * sin(_moltenPulse * 2.4))
          : _kGaugeGlass.smoke,
      rim: lit ? 1.0 : 0.5,
      lead: 1.8,
    );
  }

  /// The firebox, seen through its sight-glass: three panes of fire.
  void _drawFireboxGlass(Canvas canvas, Rect box, double pulse) {
    final win = box.deflate(8);
    for (var k = 0; k < 3; k++) {
      final pane = Rect.fromLTWH(
        win.left + win.width * k / 3,
        win.top,
        win.width / 3,
        win.height,
      );
      paintPane(
        canvas,
        Path()..addRect(pane),
        Color.lerp(
          const Color(0xFF7A2A0A),
          const Color(0xFFFFA24A),
          pulse * (0.7 + 0.3 * ((k + 1) % 2)),
        )!,
        _kGaugeGlass,
        lead: 2.2,
      );
    }
    paintLead(
      canvas,
      Path()..addRect(win),
      _kGaugeGlass,
      width: 2.6,
      light: _kGaugeGlass.gold,
    );
  }

  /// A crucible corner's wanted elements, as panes of their own glass in the
  /// socket's ring — silver-capped once the corner is sealed.
  void _drawCornerGlass(
    Canvas canvas,
    Offset c,
    List<String> wants,
    bool shut,
  ) {
    const r0 = 16.0, r1 = 28.0;
    final sweep = 2 * pi / wants.length;
    for (var i = 0; i < wants.length; i++) {
      final a0 = -pi / 2 + i * sweep + (wants.length > 1 ? 0.08 : 0.0);
      final a1 = a0 + sweep - (wants.length > 1 ? 0.16 : 0.0);
      final col = Color.lerp(elementColor(wants[i]), Colors.white, 0.34)!;
      paintPane(
        canvas,
        sectorPath(c, r0, r1, a0, a1),
        shut ? col : Color.lerp(_kGaugeGlass.frostAt(i), col, 0.55)!,
        _kGaugeGlass,
        lead: 2.2,
      );
    }
    paintRondel(
      canvas,
      c,
      r0 - 2,
      _kGaugeGlass,
      fill: shut ? _kGaugeGlass.silver : _kGaugeGlass.smoke,
      rim: shut ? 1.0 : 0.5,
    );
  }

  /// HIDDEN HARMONY, SET. The sigil sinks into the plinth as the rite binds —
  /// the ring shrinking down onto the stone, the triangle following — and
  /// then it is an inlay of steam glass for good, with condensation running
  /// down its panes. What you took leaves a mark, not a hole.
  void _drawHarmonyInlay(Canvas canvas, Offset cache) {
    final s = _harmonySet.clamp(0.0, 1.0);
    if (s <= 0) return;
    final seat = cache + const Offset(0, 16);
    final sink = Curves.easeInOutCubic.transform(s);
    // Descending: the sigil drops from where it hung to the plinth's top.
    final at = Offset.lerp(cache, seat, sink)!;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, 1 - 0.38 * sink); // lying down into the stone
    const r = 26.0;
    for (var k = 0; k < 3; k++) {
      final a0 = -pi / 2 + k * 2 * pi / 3;
      final a1 = a0 + 2 * pi / 3;
      final tri = Path()
        ..moveTo(0, 0)
        ..lineTo(cos(a0) * r, sin(a0) * r)
        ..lineTo(cos(a1) * r, sin(a1) * r)
        ..close();
      paintPane(
        canvas,
        tri,
        Color.lerp(
          _kGaugeGlass.live,
          _kGaugeGlass.liveCore,
          0.25 + 0.2 * k,
        )!.withValues(alpha: 0.4 + 0.5 * sink),
        _kGaugeGlass,
        lead: 2.2,
      );
    }
    paintLead(
      canvas,
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)),
      _kGaugeGlass,
      width: 3,
      light: _kGaugeGlass.gold,
    );
    canvas.restore();
    if (s >= 1) {
      // Condensation: beads forming at the rim and running down the glass.
      for (var i = 0; i < 4; i++) {
        final t = ((_moltenPulse * 0.25 + i / 4) % 1.0);
        final x = seat.dx - 14 + i * 9.0;
        canvas.drawCircle(
          Offset(x, seat.dy - 8 + 14 * t),
          1.4,
          Paint()..color = Colors.white.withValues(alpha: 0.55 * (1 - t)),
        );
      }
    }
    if (_fx.ready) {
      // Found, it keeps a cool light of its own in a room the foundry forgot.
      drawGlow(
        canvas,
        _fx.glow!,
        at,
        40 + 12 * s,
        _kGaugeGlass.live.withValues(
          alpha: s < 1
              ? 0.35 * (1 - s) + 0.12
              : 0.14 + 0.04 * sin(_moltenPulse),
        ),
      );
    }
  }

  // ── Vapour ──────────────────────────────────────────────

  /// Steam coming up through the condensate grate in a plain chamber: three
  /// slow wisps of grains, each a thread that turns as it climbs and opens
  /// and dissolves at the top, over a breath of haze. ~600 grains.
  void _paintForgeWisps(Canvas canvas, Rect b, double t) {
    final rise = min(240.0, b.height * 0.4);
    for (var i = 0; i < 3; i++) {
      final x = b.left + b.width * ((i + 0.5) / 3) + 22 * sin(t * 0.13 + i);
      final foot = Offset(x, b.bottom - 34);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          foot - Offset(0, rise * 0.45),
          rise * 0.32,
          _kVaporRamp[1].withValues(alpha: 0.05),
        );
      }
      _addVaporRun(
        foot,
        const Offset(0, -1),
        rise,
        t,
        count: 200,
        rate: 0.09,
        w0: 2,
        w1: 30,
        ease: 1.25,
        curl: 16,
        wave: 150,
        alpha: 0.55,
        seed: 40 + i,
        trail: 0.03,
        hot: 0,
      );
    }
    _vaporBatch.paint(canvas, _kVaporRamp);
  }

  /// THE SPLIT MAIN'S JET, countable: a hard narrow stream at the tear that
  /// slows and opens into a turning plume [h] tall — taller, thicker and
  /// denser with every mark on the gauge. ~135 grains a mark (675 at a full
  /// main).
  void _paintSplitJet(Canvas canvas, Offset c, double h, int marks) {
    final t = _moltenPulse;
    final mouth = c - const Offset(0, 4);
    if (_fx.ready) {
      // The plume's body: a faint haze for the grains to stand in.
      drawGlow(
        canvas,
        _fx.glow!,
        mouth - Offset(0, h * 0.5),
        10 + 5.0 * marks,
        _kVaporRamp[2].withValues(alpha: 0.05 + 0.014 * marks),
      );
    }
    // The plume it opens into, spending itself as it climbs.
    _addVaporRun(
      mouth,
      const Offset(0, -1),
      h,
      t,
      count: 110 * marks,
      rate: 0.34 + 0.05 * marks,
      w0: 1.5 + 0.5 * marks,
      w1: 10 + 5.0 * marks,
      ease: 1.8,
      curl: 3 + 2.4 * marks,
      wave: 40 + 14.0 * marks,
      alpha: 0.5 + 0.08 * marks,
      seed: 12,
      trail: 0.02,
      hot: 0.25,
    );
    // The throat: fast and bright, barely wider than the tear — the part
    // that says PRESSURE rather than weather.
    _addVaporRun(
      mouth,
      const Offset(0, -1),
      h * 0.3,
      t,
      count: 25 * marks,
      rate: 1.3,
      w0: 0.8,
      w1: 1.5 + 0.8 * marks,
      ease: 2.0,
      curl: 0.5,
      alpha: 0.85,
      seed: 11,
      trail: 0.012,
      hot: 0.8,
    );
    _vaporBatch.paint(canvas, _kVaporRamp);
  }

  /// The cellar mouth breathing out: a slow thread of grains curling up and
  /// away from the collar. ~170 grains.
  void _paintCellarBreath(Canvas canvas, Offset m) {
    _addVaporRun(
      m + const Offset(12, -4),
      const Offset(0.88, -0.47),
      60,
      _moltenPulse,
      count: 170,
      rate: 0.22,
      w0: 2,
      w1: 16,
      ease: 1.4,
      curl: 7,
      wave: 50,
      alpha: 0.6,
      seed: 23,
      trail: 0.03,
      hot: 0.15,
    );
    _vaporBatch.paint(canvas, _kVaporRamp);
  }

  /// STEAM'S OPEN SKY: vapour climbing out of the boiler below in three slow
  /// turning columns of grains over a faint haze — in place of the generic
  /// puff clouds, which on the crucible's open sky read as cartoon cloud
  /// blobs between the islands. Screen-space, as the clouds were, and only
  /// where the room is open to the sky: through a closed chamber's
  /// translucent brick they would only read as noise. ~2,400 grains.
  void _drawVaporSky(Canvas canvas, Size vp, DungeonRoom room) {
    if (room.platforms.isEmpty && room.gaps.isEmpty) return;
    final key = '${vp.width.round()}x${vp.height.round()}';
    final rise = vp.height * 0.62;
    canvas.drawPicture(
      _vaporSkyHaze.putIfAbsent(key, () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        for (final fx in _kVaporSkyColumns) {
          final o = Offset(vp.width * fx, vp.height - rise * 0.4);
          final r = Rect.fromCenter(center: o, width: 220, height: rise);
          c.drawOval(
            r,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  const Color(0xFFB8C4D0).withValues(alpha: 0.07),
                  const Color(0x00B8C4D0),
                ],
              ).createShader(r),
          );
        }
        return rec.endRecording();
      }),
    );
    for (var k = 0; k < _kVaporSkyColumns.length; k++) {
      _addVaporRun(
        Offset(
          vp.width * _kVaporSkyColumns[k] + 20 * sin(_time * 0.05 + k * 2),
          vp.height + 20,
        ),
        const Offset(0, -1),
        rise,
        _time,
        count: 800,
        rate: 0.05,
        w0: 18,
        w1: 84,
        ease: 1.25,
        curl: 36,
        wave: 300,
        alpha: 0.6 + 0.2 * _skyMood,
        seed: 90 + k,
        trail: 0.03,
        hot: 0,
      );
    }
    _vaporBatch.paint(canvas, _kVaporRamp);
  }
}
