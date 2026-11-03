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

/// A BLAST, in grains: parcels are born at the throat for as long as the
/// blast runs ([birthing] seconds so far), each rising fast, slowing and
/// opening as it cools. So the column grows up out of the mouth, mushrooms,
/// and once the blast stops it lifts off and thins away instead of switching
/// off. Later parcels leave weaker — the jet spends itself across [blast].
/// Worked out from [since] (seconds since the blast opened) alone.
void _addGeyserBlast(
  Offset mouth,
  double since, {
  required double birthing,
  required double blast,
  required double height,
  required double width,
  required int perSecond,
  double life = 1.5,
  int seed = 0,
  double alpha = 0.75,
}) {
  final first = max(0, ((since - life) * perSecond).ceil());
  final last = (min(since, birthing) * perSecond).floor();
  for (var i = first; i < last; i++) {
    final birth = i / perSecond;
    final age = since - birth;
    if (age <= 0 || age >= life) continue;
    final h1 = _vaporHash(seed * 7919 + i);
    final h2 = _vaporHash(seed * 1543 + i * 3 + 1);
    final h3 = _vaporHash(seed * 31 + i * 7 + 2);
    final jet =
        0.5 + 0.5 * pow(1 - (birth / blast).clamp(0.0, 1.0), 1.3).toDouble();
    // Crowded to the middle: two hashes summed fall mostly near zero.
    final side = h2 + h3 - 1;
    // Each parcel billows on its own beat as it cools — steam is a churn,
    // not a spray.
    final beat = h3 * 20 + seed;
    Offset at(double a) {
      final u = (a / life).clamp(0.0, 1.0);
      final along =
          height * jet * (0.8 + 0.3 * h1) * (1 - pow(1 - u, 2.6).toDouble());
      final open = pow(u, 0.6).toDouble();
      final spread = width * (0.12 + 0.88 * open) * side;
      final curl = width * 0.3 * u * sin(along / 80 - birth * 3 + seed);
      final billow = width * 0.22 * open;
      return mouth +
          Offset(
            spread + curl + billow * sin(a * 2.3 + beat),
            -along + billow * 0.6 * cos(a * 1.9 + beat),
          );
    }

    final q = at(age);
    final p = age > 0.012 ? at(age - 0.012) : q;
    final u = age / life;
    final fade = min(1.0, u * 14) * pow(1 - u, 1.5).toDouble();
    final shade = h1 > 0.985
        ? 3
        : (u < 0.18 && side.abs() < 0.35)
        ? 2
        : h1 > 0.3
        ? 1
        : 0;
    _vaporBatch.add(p, q, shade, alpha * fade);
  }
}

/// THE SKIRT: condensate flung out along the floor as a blast opens, a ring
/// of grains running from the lip to [reach] — the shove's own reach, said by
/// the steam rather than by a drawn circle. [bt] is 0..1 through the blast.
void _addBlastSkirt(Offset c, double r, double reach, double bt, int seed) {
  if (bt >= 0.85) return;
  final go = Curves.easeOutCubic.transform(bt / 0.85);
  final a = 0.5 * pow(1 - bt / 0.85, 1.2).toDouble();
  for (var i = 0; i < 220; i++) {
    final h1 = _vaporHash(seed * 131 + i);
    final h2 = _vaporHash(seed * 17 + i * 5 + 3);
    final h3 = _vaporHash(seed * 7 + i * 13 + 5);
    final ang = h1 * 2 * pi;
    final dir = Offset(cos(ang), sin(ang) * 0.9);
    // A low sheet rolling outward, thickest at its leading edge — the edge
    // is how far the blast throws, and it is said by the steam.
    final k = sqrt(h2);
    final q = c + dir * (r + (reach - r) * go * k) + Offset(0, -3 * h3);
    _vaporBatch.add(q - dir * 1.2, q, h3 > 0.8 ? 2 : 1, a * (0.3 + 0.7 * k));
  }
}

/// A rough closed outline round [c]: [n] points at radius [r], each pushed in
/// or out by up to [jag] of it — a stone or a hole that is never a circle.
Path _roughOutline(
  Offset c,
  double r,
  int n,
  double jag,
  GlassRng rng, {
  double squash = 1,
}) {
  final p = Path();
  for (var i = 0; i < n; i++) {
    final a = i * 2 * pi / n + rng.range(-0.12, 0.12);
    final rr = r * (1 + rng.range(-jag, jag));
    final x = c.dx + cos(a) * rr, y = c.dy + sin(a) * rr * squash;
    if (i == 0) {
      p.moveTo(x, y);
    } else {
      p.lineTo(x, y);
    }
  }
  return p..close();
}

/// A stable seed from an id (String.hashCode is not promised to be stable).
int _steamSeed(String id) {
  var h = 7;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x3fffffff;
  }
  return h;
}

/// Grit off a stone: shadow, body, lit, glint.
const List<Color> _kGritRamp = [
  Color(0xFF231A13),
  Color(0xFF4E4034),
  Color(0xFF7C6A56),
  Color(0xFFB8A48A),
];

/// The vents' rock, baked once per mouth.
final Map<String, ui.Picture> _ventGeologyCache = {};

/// The haze the open sky's vapour rises through, baked per viewport.
final Map<String, ui.Picture> _vaporSkyHaze = {};

/// Where the open sky's columns stand, as fractions of the view's width.
const List<double> _kVaporSkyColumns = [0.08, 0.5, 0.92];

extension BoilerRingArt on PlanetDungeonGame {
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
  /// slow wisps of grains that open and dissolve as they climb, over a breath
  /// of haze. (As thin threads they read as static; they are breath now.)
  /// ~1,100 grains.
  void _paintForgeWisps(Canvas canvas, Rect b, double t) {
    final rise = min(240.0, b.height * 0.4);
    for (var i = 0; i < 3; i++) {
      final x = b.left + b.width * ((i + 0.5) / 3) + 22 * sin(t * 0.13 + i);
      final foot = Offset(x, b.bottom - 34);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          foot - Offset(0, rise * 0.4),
          rise * 0.38,
          _kVaporRamp[1].withValues(alpha: 0.07),
        );
      }
      _addVaporRun(
        foot,
        const Offset(0, -1),
        rise,
        t,
        count: 380,
        rate: 0.08,
        w0: 10,
        w1: 64,
        ease: 1.2,
        curl: 20,
        wave: 160,
        alpha: 0.38,
        seed: 40 + i,
        trail: 0.02,
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

  // ── THE FIELD, IN STONE (2026-11-03) ───────────────────────

  /// A mouth's rock: sinter shelves laid unevenly round it, the wet lip, and
  /// a throat you look down into — its far wall catching what light there
  /// is. A riser wears a riveted iron collar: the one throat the boiler was
  /// built around, too wide for a body to smother. Baked once per mouth.
  void _drawVentGeology(Canvas canvas, GeyserMouth gy, double r) {
    final pic = _ventGeologyCache.putIfAbsent('${gy.id}|${r.round()}', () {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final rng = GlassRng(_steamSeed(gy.id));
      // Sinter: the mineral a hot spring lays down as it dries, in shelves
      // that build unevenly because one side always runs wetter.
      for (var t = 3; t >= 1; t--) {
        final lean = Offset(rng.range(-5, 5), rng.range(-3, 4));
        final shelf = _roughOutline(lean, r + t * 7.5, 18, 0.09, rng);
        c.drawPath(
          shelf.shift(const Offset(0, 3)),
          Paint()..color = const Color(0x66000000),
        );
        c.drawPath(
          shelf,
          Paint()
            ..color = Color.lerp(
              const Color(0xFF8C8273),
              const Color(0xFF433A31),
              t / 3,
            )!,
        );
        // The shelf's dry edge, pale where the mineral has whitened.
        c.drawPath(
          shelf,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFFB9B0A0).withValues(alpha: 0.22),
        );
      }
      // The lip that never dries.
      c.drawPath(
        _roughOutline(Offset.zero, r + 5, 20, 0.07, rng),
        Paint()..color = const Color(0xFF29221C),
      );
      final throat = _roughOutline(Offset.zero, r, 20, 0.06, rng);
      c.drawPath(throat, Paint()..color = const Color(0xFF0B0907));
      c.save();
      c.clipPath(throat);
      // Looking down from the south you see the FAR inner wall, lit, and
      // the shaft dropping away below it.
      c.drawOval(
        Rect.fromCenter(
          center: Offset(0, -r * 0.62),
          width: r * 2.3,
          height: r * 1.25,
        ),
        Paint()..color = const Color(0xFF3B3129),
      );
      c.drawOval(
        Rect.fromCenter(
          center: Offset(0, r * 0.18),
          width: r * 1.75,
          height: r * 1.55,
        ),
        Paint()..color = const Color(0xFF050404),
      );
      c.restore();
      if (gy.isRiser) {
        c.drawCircle(
          Offset.zero,
          r + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..color = const Color(0xFF303136),
        );
        c.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r + 6.5),
          pi + 0.4,
          pi - 0.8,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = const Color(0x55D8E4EA),
        );
        for (var k = 0; k < 12; k++) {
          final a = k * pi / 6 + 0.13;
          c.drawCircle(
            Offset(cos(a), sin(a)) * (r + 4),
            1.9,
            Paint()..color = const Color(0xFF8A8A90),
          );
        }
      }
      return rec.endRecording();
    });
    canvas.save();
    canvas.translate(gy.position.dx, gy.position.dy);
    canvas.drawPicture(pic);
    canvas.restore();
  }

  /// A vent a crucible corner has shut for good, plugged with what shut it:
  /// Steam's sinter crust, Earth's seated stone, or Fire's slag.
  void _drawVentPlug(Canvas canvas, Offset c, double r, String by) {
    final rng = GlassRng(_steamSeed('plug$by${c.dx.round()}${c.dy.round()}'));
    switch (by) {
      case 'Steam':
        final crust = _roughOutline(c, r + 2, 16, 0.08, rng);
        canvas.drawPath(crust, Paint()..color = const Color(0xFF9A9284));
        for (var k = 1; k <= 3; k++) {
          canvas.drawPath(
            _roughOutline(c, (r + 2) * (1 - k * 0.24), 14, 0.1, rng),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = const Color(0xFFD8D2C4).withValues(alpha: 0.35),
          );
        }
      case 'Earth':
        _drawSteamStone(canvas, c, r * 0.95, _steamSeed('seat$c'));
      default:
        // Slag: glassy black, still showing a little of the heat that set it.
        final slag = _roughOutline(c, r + 3, 15, 0.14, rng);
        canvas.drawPath(slag, Paint()..color = const Color(0xFF141012));
        canvas.drawPath(
          _roughOutline(c - Offset(r * 0.2, r * 0.25), r * 0.5, 9, 0.2, rng),
          Paint()..color = const Color(0x22D8E4EA),
        );
        final ember = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFB5400F).withValues(alpha: 0.55);
        for (var k = 0; k < 3; k++) {
          final a = rng.range(0, 2 * pi);
          final p0 = c + Offset(cos(a), sin(a)) * r * 0.2;
          final p1 = c + Offset(cos(a + 0.3), sin(a + 0.3)) * r * 0.75;
          canvas.drawLine(p0, p1, ember);
        }
    }
  }

  /// THE STONE an Earth hand raises: a rough boulder, lit from the upper
  /// left, with a dark foot so it stands off the brick. While [rise] < 1 it
  /// is still heaving up through the floor — the floor hides what has not
  /// come up yet, the brick cracks open round it and grit slides off it.
  /// [heat] (0..1) is the forge's melt working at its foot.
  void _drawSteamStone(
    Canvas canvas,
    Offset at,
    double rr,
    int seed, {
    double rise = 1,
    double heat = 0,
  }) {
    final rng = GlassRng(seed);
    final body = _roughOutline(Offset.zero, rr, 11, 0.13, rng, squash: 0.9);
    final facet = _roughOutline(
      Offset(-rr * 0.2, -rr * 0.3),
      rr * 0.52,
      7,
      0.16,
      rng,
    );
    final up = Curves.easeOutBack.transform(rise.clamp(0.0, 1.0));
    final sink = (1 - up) * rr * 1.5;
    paintContactShadow(
      canvas,
      at + Offset(0, rr * 0.7),
      rr * 2.4 * (0.45 + 0.55 * rise),
      rr * 0.85 * (0.45 + 0.55 * rise),
      opacity: 0.15 + 0.35 * rise,
    );
    if (rise < 1) {
      // The floor torn open where it is coming through.
      canvas.drawPath(
        _roughOutline(at + Offset(0, rr * 0.25), rr * 1.12, 14, 0.2, rng),
        Paint()..color = const Color(0xFF0E0A07).withValues(alpha: 0.85),
      );
    }
    canvas.save();
    if (rise < 1) {
      canvas.clipRect(
        Rect.fromLTRB(
          at.dx - rr * 2,
          at.dy - rr * 3,
          at.dx + rr * 2,
          at.dy + rr * 0.85,
        ),
      );
    }
    canvas.translate(at.dx, at.dy + sink);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF85745F), Color(0xFF4C4034), Color(0xFF1C1611)],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: rr)),
    );
    canvas.drawPath(
      facet,
      Paint()..color = const Color(0xFF9C8B74).withValues(alpha: 0.45),
    );
    // A seam and two pits, so it reads as broken rock and not a pebble.
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xAA1A140F);
    final a0 = rng.range(0.2, 1.2);
    canvas.drawLine(
      Offset(cos(a0), sin(a0)) * rr * 0.15,
      Offset(cos(a0 + 0.5), sin(a0 + 0.5)) * rr * 0.8,
      seam,
    );
    for (var k = 0; k < 2; k++) {
      canvas.drawCircle(
        Offset(rng.range(-0.4, 0.4), rng.range(-0.1, 0.5)) * rr,
        rr * 0.07,
        Paint()..color = const Color(0x881A140F),
      );
    }
    if (heat > 0.02) {
      canvas.save();
      canvas.clipPath(body);
      canvas.drawRect(
        Rect.fromLTRB(-rr, rr * 0.15, rr, rr),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0x00C4531A),
              const Color(0xFFC4531A).withValues(alpha: 0.75 * heat),
            ],
          ).createShader(Rect.fromLTRB(-rr, rr * 0.15, rr, rr)),
      );
      canvas.restore();
    }
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFF15100C),
    );
    canvas.restore();
    if (rise < 1) {
      // Grit sliding off its shoulders as it comes.
      final t = _moltenPulse;
      for (var i = 0; i < 46; i++) {
        final h1 = _vaporHash(seed + i * 7);
        final h2 = _vaporHash(seed * 3 + i * 11);
        final u = (t * (1.6 + h2) + h1) % 1.0;
        final side = h1 < 0.5 ? -1.0 : 1.0;
        final x = at.dx + side * rr * (0.55 + 0.45 * h2);
        final y0 = at.dy + sink - rr * (0.5 - h1 * 0.4);
        final q = Offset(x + side * 6 * u, y0 + rr * 0.9 * u * u);
        final p = Offset(x + side * 6 * max(0.0, u - 0.08), q.dy - 2.2);
        _vaporBatch.add(p, q, h2 > 0.8 ? 2 : 1, (1 - u) * (1 - rise));
      }
      _vaporBatch.paint(canvas, _kGritRamp, width: 2.0);
    }
  }

  /// A heap of broken rock choking a mouth.
  void _drawRubblePlug(Canvas canvas, Offset c, double r, int seed) {
    final rng = GlassRng(seed);
    final stones = <(Offset, double)>[
      for (var k = 0; k < 6; k++)
        (
          c +
              Offset(
                rng.range(-r * 0.75, r * 0.75),
                rng.range(-r * 0.6, r * 0.6),
              ),
          rng.range(r * 0.32, r * 0.55),
        ),
    ]..sort((a, b) => a.$1.dy.compareTo(b.$1.dy));
    for (var k = 0; k < stones.length; k++) {
      _drawSteamStone(canvas, stones[k].$1, stones[k].$2, seed + k * 97);
    }
  }

  // ── THE FIELD'S BREATH, IN GRAINS (2026-11-03) ─────────────
  //
  // The plumes were the last of Steam's sprite puffs — a stack of little grey
  // cloud stamps over a cyan ring — left in on budget grounds when the rest
  // of the planet went to grains. They are grains now, drawn OVER the party
  // so a body standing in a blast stands in it: the mutter between blasts,
  // the blast itself born at the throat and lifting off when it stops, the
  // skirt that says how far it throws, the leak under every held mouth, and
  // the heart's standing column once the field is won.
  void _renderSteamOverParty(Canvas canvas, DungeonRoom room) {
    if (room.geysers.isEmpty) return;
    final t = _moltenPulse;
    final cap = room.capstone;
    final solved = cap != null && hasStar(cap.starIndex);
    const up = Offset(0, -1);
    if (!solved) {
      final sealedVents = <String>{
        for (final seal in room.crucibleSeals)
          if (sealedCorners.contains(seal.id)) ...seal.vents,
      };
      final charge = geyserCharge;
      final p = geyserPressure;
      final force = min(2.6, 1.0 + 0.38 * p);
      final since = _geyserBlastAt < 0 ? -1.0 : (t - _geyserBlastAt) % 1000.0;
      // Twelve blowing at once (the crucible on arrival) is a forest, not a
      // plume: each is thinned so the room carries about as many grains as
      // five would.
      final open = room.geysers
          .where(
            (g) =>
                !g.blockedAtStart &&
                !sealedVents.contains(g.id) &&
                !cappedGeysers.contains(g.id),
          )
          .length;
      final crowd = open <= 5 ? 1.0 : sqrt(5 / open);
      for (final gy in room.geysers) {
        final r = gy.isRiser ? 34.0 : 24.0;
        final seed = _steamSeed(gy.id) & 0xffff;
        if (gy.blockedAtStart || sealedVents.contains(gy.id)) continue;
        if (cappedGeysers.contains(gy.id)) {
          // HELD — but a held mouth is not a dead one: its head has gone
          // into the rest of the field, and it hisses out from under
          // whatever is holding it, hardest just before the field blows.
          final strain = (0.25 + 0.55 * charge) * (0.6 + 0.1 * p);
          for (var k = 0; k < 3; k++) {
            final a = pi + 0.5 + k * 1.05 + 0.3 * sin(t * 0.7 + k);
            final dir = Offset(cos(a), sin(a) * 0.6 - 1.0);
            final n = dir / dir.distance;
            _addVaporRun(
              gy.position + Offset(cos(a), sin(a)) * (r - 3),
              n,
              14 + 24 * strain,
              t,
              count: (10 + 22 * strain).round(),
              rate: 0.9,
              w0: 1,
              w1: 5 + 6 * strain,
              ease: 1.6,
              curl: 3,
              wave: 30,
              alpha: 0.3 + 0.45 * strain,
              seed: seed + k,
              trail: 0.02,
              hot: 0.3,
            );
          }
          continue;
        }
        // Between blasts: a slow mutter, building with the head.
        if (!_geyserBlasting) {
          _addVaporRun(
            gy.position - const Offset(0, 4),
            up,
            22 + 40 * charge,
            t,
            count: (26 + 64 * charge).round(),
            rate: 0.45 + 0.4 * charge,
            w0: 2,
            w1: r * 0.45 + 10 * charge,
            ease: 1.5,
            curl: 4 + 4 * charge,
            wave: 60,
            alpha: 0.3 + 0.38 * charge,
            seed: seed,
            trail: 0.025,
            hot: 0.2,
          );
        }
        if (since >= 0) {
          final birthing = min(since, _geyserBlastLen);
          final height = 168 * force;
          _addGeyserBlast(
            gy.position - const Offset(0, 2),
            since,
            birthing: birthing,
            blast: _kGeyserBlast,
            height: height,
            width: r * (2.0 + 0.3 * min(p, 4)),
            perSecond: ((380 + 90 * min(p, 4)) * crowd).round(),
            life: 1.7,
            seed: seed,
          );
          // The column's body: a faint haze for the grains to stand in,
          // lifting with the parcels and thinning as they do.
          final lift = since - birthing;
          final body = (1 - lift / 1.7).clamp(0.0, 1.0);
          if (_fx.ready && body > 0 && since < birthing + 1.7) {
            for (var k = 0; k < 3; k++) {
              final f = 0.3 + 0.3 * k;
              final grow = min(1.0, since / (0.35 + 0.35 * k));
              drawGlow(
                canvas,
                _fx.glow!,
                gy.position -
                    Offset(0, height * f * grow + lift * height * 0.25),
                r * (1.2 + 1.1 * k) * (0.6 + 0.4 * grow),
                const Color(
                  0xFFDCEFF6,
                ).withValues(alpha: (0.10 - 0.02 * k) * body * grow),
              );
            }
          }
          if (_geyserBlasting && !gy.isRiser) {
            _addBlastSkirt(
              gy.position,
              r,
              _kBlastReach,
              (since / _kGeyserBlast).clamp(0.0, 1.0),
              seed,
            );
          }
        }
      }
    }

    // THE HEART, ONCE IT IS OPEN: the whole field's head comes up through it
    // and never stops — the room's standing trophy.
    if (cap != null &&
        !room.geysers.any((g) => g.isRiser) &&
        (capstoneBurst || solved)) {
      _addVaporRun(
        cap.position - const Offset(0, 6),
        up,
        340,
        t,
        count: 1500,
        rate: 0.16,
        w0: 14,
        w1: 120,
        ease: 1.3,
        curl: 26,
        wave: 210,
        alpha: 0.6,
        seed: 77,
        trail: 0.018,
        hot: 0.12,
      );
      if (_fx.ready) {
        for (var k = 0; k < 3; k++) {
          drawGlow(
            canvas,
            _fx.glow!,
            cap.position - Offset(0, 70 + 85.0 * k),
            50 + 26.0 * k,
            const Color(0xFFDCEFF6).withValues(alpha: 0.08 - 0.015 * k),
          );
        }
      }
      _addVaporRun(
        cap.position - const Offset(0, 6),
        up,
        96,
        t,
        count: 130,
        rate: 0.95,
        w0: 3,
        w1: 12,
        ease: 2.0,
        curl: 1,
        alpha: 0.8,
        seed: 78,
        trail: 0.015,
        hot: 0.8,
      );
    } else if (cap != null &&
        !room.geysers.any((g) => g.isRiser) &&
        room.geysers.isNotEmpty) {
      // Before it goes: a thread squeezing out of the seam as the field is
      // shut around it.
      final frac = (geyserPressure / room.geysers.length).clamp(0.0, 1.0);
      if (frac > 0.5) {
        _addVaporRun(
          cap.position - const Offset(0, 4),
          up,
          18 + 36 * frac,
          t,
          count: (20 + 50 * frac).round(),
          rate: 0.6,
          w0: 1.5,
          w1: 10,
          ease: 1.5,
          curl: 4,
          wave: 50,
          alpha: 0.25 + 0.4 * frac,
          seed: 79,
          trail: 0.02,
          hot: 0.3,
        );
      }
    }
    _vaporBatch.paint(canvas, _kVaporRamp);
  }

  /// THE CAST SPAN — the way home, which is the thing the forge made. Until
  /// the star is banked there is nothing over the gap but a stone sill on
  /// each lip where it will land; then a casting, iron-dark and still warm
  /// along its seams.
  void _drawCastSpan(Canvas canvas, DungeonRoom room) {
    final span = room.castSpan;
    if (span == null) return;
    final cap = room.capstone;
    final set = cap != null && hasStar(cap.starIndex);
    final stone = kVaporGlass;
    if (!set) {
      for (final x in [span.left - 10.0, span.right - 2.0]) {
        paintCarvedBlock(
          canvas,
          Rect.fromLTWH(x, span.top + 6, 12, span.height - 16),
          6,
          stone,
          radius: 2,
        );
      }
      return;
    }
    paintContactShadow(
      canvas,
      span.bottomCenter + const Offset(0, 6),
      span.width * 1.2,
      14,
      opacity: 0.5,
    );
    final body = RRect.fromRectAndRadius(span, const Radius.circular(4));
    canvas.drawRRect(
      body.shift(const Offset(0, 7)),
      Paint()..color = const Color(0xFF15110E),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF2E2824));
    canvas.save();
    canvas.clipRRect(body);
    final rng = GlassRng(_steamSeed('castspan'));
    // The skin it set with: dull plates, warm where they meet.
    for (var y = span.top + 4; y < span.bottom; y += 15) {
      canvas.drawLine(
        Offset(span.left, y + rng.range(-2, 2)),
        Offset(span.right, y + rng.range(-2, 2)),
        Paint()
          ..strokeWidth = 1.3
          ..color = const Color(
            0xFFC9702A,
          ).withValues(alpha: 0.28 + 0.12 * sin(_moltenPulse * 1.3 + y * 0.1)),
      );
    }
    canvas.restore();
    canvas.drawLine(
      span.topLeft + const Offset(3, 1),
      span.topRight + const Offset(-3, 1),
      Paint()
        ..strokeWidth = 1.4
        ..color = const Color(0x55E4C16A),
    );
  }

  /// THE CASTING MOAT: a trough cut down the far shore with a stone sill at
  /// its head, and the melt that has run down it so far — molten under a
  /// crust that breaks into plates as it goes, fresh and bright at the
  /// front, which is where the work has got to.
  void _drawCastingMoat(Canvas canvas, DungeonRoom room) {
    final moat = room.castingMoat;
    if (moat == null) return;
    final ch = moat.channel;
    final stone = kVaporGlass;
    // The trough: a dark bed between two low kerbs.
    canvas.drawRRect(
      RRect.fromRectAndRadius(ch.inflate(2), const Radius.circular(6)),
      Paint()..color = const Color(0xFF0D0907),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(ch.deflate(4), const Radius.circular(4)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1A130E), Color(0xFF241A13), Color(0xFF16100C)],
        ).createShader(ch),
    );
    for (final x in [ch.left - 9.0, ch.right - 1.0]) {
      paintCarvedBlock(
        canvas,
        Rect.fromLTWH(x, ch.top - 4, 10, ch.height + 6),
        5,
        stone,
        radius: 3,
      );
    }
    final cast = room.capstone != null && hasStar(room.capstone!.starIndex);
    if (cast) {
      // The cast that set: dull iron down the whole trough, still warm at
      // its seams.
      final run = ch.deflate(4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(run, const Radius.circular(4)),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF4A423B), Color(0xFF5C534A), Color(0xFF3A332D)],
          ).createShader(run),
      );
      for (var y = run.top + 12; y < run.bottom - 4; y += 19) {
        canvas.drawLine(
          Offset(run.left + 3, y),
          Offset(run.right - 3, y + 3),
          Paint()
            ..strokeWidth = 1.2
            ..color = const Color(0xFFC9702A).withValues(
              alpha: 0.22 + 0.1 * sin(_moltenPulse * 1.2 + y * 0.07),
            ),
        );
      }
    } else if (moatFill > 0.004) {
      final h = (ch.height - 6) * moatFill.clamp(0.0, 1.0);
      final run = Rect.fromLTWH(ch.left + 3, ch.top + 3, ch.width - 6, h);
      final pulse = 0.55 + 0.45 * sin(_moltenPulse * 2.2);
      final rr = _moltenRunPath(
        run,
        _moltenPulse * 0.9,
        tongue: (ch.bottom - 4 - run.bottom).clamp(0.0, 7.0),
      );
      canvas.drawPath(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF7A2408),
              Color.lerp(
                const Color(0xFFC4531A),
                const Color(0xFFFF9A4A),
                pulse * 0.6,
              )!,
            ],
          ).createShader(run.inflate(8)),
      );
      canvas.save();
      canvas.clipPath(rr);
      // The crust: dark plates riding the run down, closing up behind the
      // front as the melt cools, so the old run reads as crusted and only
      // the new reach is open bright.
      final rng = GlassRng(_steamSeed('moatcrust'));
      for (var k = 0; k < 40; k++) {
        final len = rng.range(14, 24);
        final y =
            run.top + ((k * 23.0 + _moltenPulse * 9) % (ch.height + 30)) - 20;
        if (y > run.bottom - 18) continue;
        final cool = ((run.bottom - y) / max(1.0, run.height)).clamp(0.0, 1.0);
        final w = run.width * (0.35 + 0.5 * cool) * rng.range(0.8, 1.1);
        final cx = run.center.dx + rng.range(-5, 5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, y), width: w, height: len),
            const Radius.circular(5),
          ),
          Paint()
            ..color = const Color(
              0xFF2A0F06,
            ).withValues(alpha: 0.25 + 0.6 * cool),
        );
      }
      canvas.restore();
      final front = Offset(run.center.dx, run.bottom);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          front,
          40,
          const Color(0xFFFF7A33).withValues(alpha: 0.30 + 0.20 * pulse),
        );
      }
      paintGrainBed(
        canvas,
        front - const Offset(0, 4),
        run.width * 0.45,
        6,
        _moltenPulse,
        count: 40,
        seed: 31,
      );
    }
    // The sill at the head, and the stone on it — which visibly wears down
    // as it melts, glowing at its foot while Fire works it.
    paintCarvedBlock(
      canvas,
      Rect.fromCenter(center: moat.boulderAt, width: 50, height: 22),
      8,
      stone,
      radius: 4,
    );
    if (boulderCharge > 0.05 && !cast) {
      _drawSteamStone(
        canvas,
        moat.boulderAt - const Offset(0, 10),
        9 + 9 * boulderCharge,
        _steamSeed('moatstone'),
        heat: (1 - boulderCharge) * 0.8,
      );
    }
  }

  /// THE MOULD at the moat's foot, which is the far shore's star: a basin
  /// cut in a squat plinth, empty and beckoning across the gap until the
  /// melt reaches it, then full and gold.
  void _drawForgeMould(Canvas canvas, DungeonRoom room) {
    final ped = room.capstone;
    if (ped == null || !room.geysers.any((g) => g.isRiser)) return;
    final taken = hasStar(ped.starIndex);
    final stone = kVaporGlass;
    final c = ped.position;
    paintCarvedDisc(canvas, c + const Offset(0, 6), 36, 18, 16, stone);
    // The basin.
    final basin = Rect.fromCenter(
      center: c + const Offset(0, 6),
      width: 50,
      height: 22,
    );
    canvas.drawOval(basin, Paint()..color = const Color(0xFF0D0907));
    final fill = taken ? 1.0 : (moatFill - 0.85).clamp(0.0, 0.15) / 0.15;
    if (fill > 0) {
      canvas.drawOval(
        basin.deflate(3),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFC4531A),
            const Color(0xFFE4C16A),
            taken ? 1.0 : 0.0,
          )!.withValues(alpha: 0.4 + 0.6 * fill),
      );
    }
    // Unclaimed, it breathes a beacon — the one bright thing across the gap,
    // which is how the room says "there".
    if (_fx.ready) {
      final pulse = taken ? 0.34 : 0.22 + 0.14 * sin(_moltenPulse * 1.6);
      drawGlow(
        canvas,
        _fx.glow!,
        c + const Offset(0, 2),
        taken ? 56 : 46,
        const Color(0xFFE4C16A).withValues(alpha: pulse),
      );
    }
  }

  /// THE CAPSTONE at the causeway's heart: a dressed stone lid set flush in
  /// the floor, splitting wider and lighter the more of the field is held —
  /// so the goal reads from across the room — and, once it goes, a throat
  /// with the broken lid standing round it.
  void _drawCapstoneSlab(Canvas canvas, DungeonRoom room) {
    final cap = room.capstone;
    if (cap == null || room.geysers.any((g) => g.isRiser)) return;
    final burst = capstoneBurst || hasStar(cap.starIndex);
    final frac = room.geysers.isEmpty
        ? 0.0
        : (geyserPressure / room.geysers.length).clamp(0.0, 1.0);
    final c = cap.position;
    final rng = GlassRng(_steamSeed('capstone'));
    final lid = _roughOutline(c, 36, 8, 0.03, rng);
    canvas.drawPath(
      lid.shift(const Offset(0, 3)),
      Paint()..color = const Color(0x88000000),
    );
    if (burst) {
      canvas.drawPath(lid, Paint()..color = const Color(0xFF2A221B));
      canvas.drawPath(
        _roughOutline(c, 27, 16, 0.1, rng),
        Paint()..color = const Color(0xFF07090A),
      );
      // The broken lid, stood up round the throat in shards.
      for (var k = 0; k < 6; k++) {
        final a = k * pi / 3 + 0.35 + rng.range(-0.15, 0.15);
        final at = c + Offset(cos(a), sin(a) * 0.9) * 31;
        final w = rng.range(9, 14);
        paintCarvedBlock(
          canvas,
          Rect.fromCenter(center: at - const Offset(0, 4), width: w, height: 7),
          rng.range(5, 9),
          kVaporGlass,
          radius: 2,
        );
      }
      return;
    }
    canvas.drawPath(lid, Paint()..color = const Color(0xFF4E443A));
    canvas.drawPath(
      _roughOutline(c, 29, 8, 0.03, rng),
      Paint()..color = const Color(0xFF433A31),
    );
    canvas.drawPath(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF1A140F),
    );
    // Cracks: they reach further and run lighter as the field is shut.
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 + 2.2 * frac
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Color.lerp(
        const Color(0xFF1A140F),
        const Color(0xFFBFF2FF),
        frac,
      )!.withValues(alpha: 0.6 + 0.4 * frac);
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * pi / 5 + 0.4 + rng.range(-0.2, 0.2);
      final path = Path()..moveTo(c.dx, c.dy);
      final reach = 34 * (0.35 + 0.65 * frac);
      for (var seg = 1; seg <= 4; seg++) {
        final d = reach * seg / 4;
        final wob = rng.range(-0.25, 0.25);
        path.lineTo(c.dx + cos(a + wob) * d, c.dy + sin(a + wob) * d);
      }
      canvas.drawPath(path, crack);
    }
    if (_fx.ready && frac > 0.25) {
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        30 + 26 * frac,
        const Color(0xFFBFF2FF).withValues(alpha: 0.06 + 0.26 * frac),
      );
    }
  }

  /// A LEDGE OF THE BOILER HOUSE, where the forge and the crucible stand
  /// over the pit. They were the generic floating island — pale slate slabs
  /// over a void, a different planet from the brick rooms either side of
  /// them. Now the same firebrick, an iron rim riveted round the edge you can
  /// fall from, and a brick pier dropping away into the dark under it.
  /// Baked once per ledge. The cast span is not ground until the forge's star
  /// is banked, and the casting draws it then.
  void _renderVaporLedge(Canvas canvas, Rect rect) {
    final room = currentRoom;
    if (rect == room.castSpan) return;
    final key =
        'ledge|${rect.left.round()},${rect.top.round()},'
        '${rect.width.round()},${rect.height.round()}';
    canvas.drawPicture(
      _vaporFabricCache.putIfAbsent(key, () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        final top = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        // The pier: brick courses under the near edge, sinking into the pit.
        const face = 54.0;
        final pier = Rect.fromLTWH(
          rect.left + 4,
          rect.bottom,
          rect.width - 8,
          face,
        );
        c.save();
        c.clipRect(pier);
        final rng = GlassRng(glassSeed('pier', rect));
        for (var y = pier.top; y < pier.bottom; y += 14) {
          final off = ((y - pier.top) / 14).round().isOdd ? 20.0 : 0.0;
          for (var x = pier.left - off; x < pier.right; x += 40) {
            final depth = (y - pier.top) / face;
            c.drawRect(
              Rect.fromLTWH(x + 0.5, y + 0.5, 39, 13),
              Paint()
                ..color = Color.lerp(
                  Color.lerp(
                    const Color(0xFF2C2119),
                    const Color(0xFF38281C),
                    rng.next(),
                  )!,
                  const Color(0xFF050403),
                  depth * 0.9,
                )!,
            );
          }
        }
        c.drawRect(
          pier,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x55000000), Color(0x00000000), Color(0xFF040302)],
              stops: [0, 0.25, 1],
            ).createShader(pier),
        );
        // Soot run down the face from the heat underneath.
        for (var k = 0; k < (pier.width / 90).ceil(); k++) {
          final x = pier.left + rng.range(0, pier.width);
          final w = rng.range(10, 26);
          final streak = Rect.fromLTWH(x, pier.top, w, face);
          c.drawRect(
            streak,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x55000000), Color(0x00000000)],
              ).createShader(streak),
          );
        }
        c.restore();
        // The top: the same firebrick as every room.
        c.save();
        c.clipRRect(top);
        c.drawRect(rect, Paint()..color = const Color(0xFF1C1611));
        _paintFirebrick(c, rect, alpha: 0.95);
        c.restore();
        // The rim: iron plate riveted round the edge you can fall from.
        c.drawRRect(
          top.deflate(3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = const Color(0xFF2E2F34),
        );
        c.drawLine(
          Offset(rect.left + 8, rect.top + 1.5),
          Offset(rect.right - 8, rect.top + 1.5),
          Paint()
            ..strokeWidth = 1.2
            ..color = const Color(0x44D8E4EA),
        );
        c.drawLine(
          Offset(rect.left + 6, rect.bottom - 0.8),
          Offset(rect.right - 6, rect.bottom - 0.8),
          Paint()
            ..strokeWidth = 1.4
            ..color = const Color(0x66E0A24A),
        );
        final rivet = Paint()..color = const Color(0xFF85858C);
        void rivets(Offset a, Offset b) {
          final n = max(1, ((b - a).distance / 32).floor());
          for (var k = 0; k <= n; k++) {
            c.drawCircle(Offset.lerp(a, b, k / n)!, 1.6, rivet);
          }
        }

        final r = rect.deflate(3);
        rivets(r.topLeft + const Offset(8, 0), r.topRight - const Offset(8, 0));
        rivets(
          r.bottomLeft + const Offset(8, 0),
          r.bottomRight - const Offset(8, 0),
        );
        rivets(
          r.topLeft + const Offset(0, 8),
          r.bottomLeft - const Offset(0, 8),
        );
        rivets(
          r.topRight + const Offset(0, 8),
          r.bottomRight - const Offset(0, 8),
        );
        return rec.endRecording();
      }),
    );
  }

  // ── THE BOILER HOUSE'S FURNITURE (2026-11-03) ──────────────

  /// THE FURNACE HEART's fire-mouths: two arched furnaces built into the
  /// north wall either side of the door, fire behind their grates, so the
  /// room Boilrog broods in is a furnace and not an empty brick box. Wall,
  /// not floor — nothing here asks to be worked.
  void _drawFurnaceMouths(Canvas canvas, DungeonRoom room) {
    final b = room.bounds;
    final t = _moltenPulse;
    for (final fx in const [0.2, 0.8]) {
      final x = b.left + b.width * fx;
      final y0 = b.top + 14;
      const w = 136.0, faceTop = 16.0, h = 96.0;
      final breast = Rect.fromLTWH(x - w / 2, y0, w, h);
      paintContactShadow(canvas, Offset(x, y0 + h + 4), w * 1.05, 16);
      // The breast's face: firebrick, darker for the soot.
      final face = Rect.fromLTWH(breast.left, y0 + faceTop, w, h - faceTop);
      canvas.save();
      canvas.clipRect(face);
      _paintFirebrick(canvas, face, alpha: 1);
      canvas.drawRect(face, Paint()..color = const Color(0x55000000));
      canvas.restore();
      paintCarvedBlock(
        canvas,
        Rect.fromLTWH(breast.left - 4, y0, w + 8, faceTop),
        0,
        kVaporGlass,
        radius: 3,
        topColor: const Color(0xFF3A2C22),
      );
      // The mouth: an arch in an iron frame, the fire behind its grate.
      const mw = 78.0, mh = 58.0;
      final mouth = Rect.fromLTWH(x - mw / 2, y0 + faceTop + 14, mw, mh);
      final arch = Path()
        ..moveTo(mouth.left, mouth.bottom)
        ..lineTo(mouth.left, mouth.top + mw / 2)
        ..arcToPoint(
          Offset(mouth.right, mouth.top + mw / 2),
          radius: const Radius.circular(mw / 2),
        )
        ..lineTo(mouth.right, mouth.bottom)
        ..close();
      canvas.drawPath(arch, Paint()..color = const Color(0xFF1A0804));
      canvas.save();
      canvas.clipPath(arch);
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          Offset(x, mouth.bottom - 10),
          mw * 0.7,
          const Color(0xFFFF7A33).withValues(alpha: 0.55),
        );
      }
      paintGrainBed(
        canvas,
        Offset(x, mouth.bottom - 6),
        mw * 0.42,
        5,
        t,
        count: 70,
        seed: (fx * 10).round(),
      );
      for (var k = 0; k < 3; k++) {
        paintGrainFlame(
          canvas,
          Offset(x - 20 + 20.0 * k, mouth.bottom - 6),
          24 + 6.0 * ((k + 1) % 2),
          t,
          phase: k * 1.7 + fx * 5,
          alpha: 0.9,
        );
      }
      canvas.restore();
      final iron = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF2E2F34);
      canvas.drawPath(arch, iron);
      final bar = Paint()
        ..strokeWidth = 3
        ..color = const Color(0xFF3A3B40);
      for (var k = 1; k < 6; k++) {
        final bx = mouth.left + mw * k / 6;
        canvas.drawLine(
          Offset(bx, mouth.top + mh * 0.45),
          Offset(bx, mouth.bottom),
          bar,
        );
      }
      for (final p in [
        Offset(mouth.left - 1, mouth.bottom - 4),
        Offset(mouth.right + 1, mouth.bottom - 4),
        Offset(mouth.left - 1, mouth.top + mw / 2),
        Offset(mouth.right + 1, mouth.top + mw / 2),
      ]) {
        canvas.drawCircle(p, 2, Paint()..color = const Color(0xFF8A8A90));
      }
      // Its light spilling out over the floor in front of it.
      if (_fx.ready) {
        drawGlow(
          canvas,
          _fx.glow!,
          Offset(x, y0 + h + 24),
          86,
          const Color(
            0xFFFF7A33,
          ).withValues(alpha: 0.12 + 0.05 * sin(t * 1.7 + fx * 9)),
        );
      }
    }
  }

  /// THE GATE'S RELIEF VALVE: a branch off the ring main, down to a valve
  /// body with its wheel — hissing at its seat until Steam bleeds it, still
  /// once it has.
  void _drawReliefValve(Canvas canvas, Offset v, Rect b, {required bool open}) {
    final mainFoot = b.top + b.height * 0.13 + 26;
    final pipe = Rect.fromLTRB(v.dx - 8, mainFoot - 2, v.dx + 8, v.dy - 8);
    canvas.drawRect(pipe.inflate(3), Paint()..color = const Color(0x66120D09));
    canvas.drawRect(pipe, Paint()..color = const Color(0xFF3B3B40));
    canvas.drawRect(
      Rect.fromLTWH(pipe.left + 2, pipe.top, 4, pipe.height),
      Paint()..color = const Color(0x3AD8E4EA),
    );
    for (final y in [mainFoot + 2, pipe.bottom - 4]) {
      final fl = Rect.fromCenter(center: Offset(v.dx, y), width: 26, height: 7);
      canvas.drawRect(fl, Paint()..color = const Color(0xFF4C4C52));
      for (final bx in [fl.left + 4, fl.right - 4]) {
        canvas.drawCircle(
          Offset(bx, y),
          1.6,
          Paint()..color = const Color(0xFF8A8A90),
        );
      }
    }
    // The valve body, standing.
    paintContactShadow(canvas, v + const Offset(0, 16), 54, 14);
    final body = Rect.fromCenter(center: v, width: 42, height: 22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body.translate(0, 8).inflate(1),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF1C1D21),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(6)),
      Paint()..color = const Color(0xFF45464C),
    );
    // The wheel: still until it is turned, and left where it was turned to.
    final hub = v - const Offset(0, 6);
    const r = 18.0;
    final turn = open ? 0.62 : 0.0;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF5E6067);
    for (var k = 0; k < 5; k++) {
      final a = turn + k * 2 * pi / 5 - pi / 2;
      canvas.drawLine(
        hub,
        hub + Offset(cos(a), sin(a) * 0.82) * r,
        Paint()
          ..strokeWidth = 2.6
          ..color = const Color(0xFF55575E),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: hub, width: r * 2, height: r * 1.64),
      rim,
    );
    canvas.drawArc(
      Rect.fromCenter(center: hub, width: r * 2, height: r * 1.64),
      pi + 0.3,
      pi - 0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x66D8E4EA),
    );
    _drawGaugeHub(canvas, hub, lit: !open);
    if (!open) {
      for (var k = 0; k < 2; k++) {
        final side = k == 0 ? -1.0 : 1.0;
        _addVaporRun(
          v + Offset(side * 20, 4),
          Offset(side * 0.8, -0.6),
          26,
          _moltenPulse,
          count: 40,
          rate: 1.1,
          w0: 1,
          w1: 7,
          ease: 1.6,
          curl: 3,
          wave: 24,
          alpha: 0.55,
          seed: 60 + k,
          trail: 0.015,
          hot: 0.4,
        );
      }
      _vaporBatch.paint(canvas, _kVaporRamp);
      if (_fx.ready) {
        drawGlow(canvas, _fx.glow!, hub, 24, const Color(0x338FE0EC));
      }
    }
  }

  /// A FIREBOX: an iron box standing on the floor with its flue, the fire
  /// seen through the sight-glass in its face.
  void _drawFirebox(Canvas canvas, Offset p) {
    final pulse = 0.5 + 0.5 * sin(_moltenPulse * 1.8);
    paintContactShadow(canvas, p + const Offset(0, 32), 92, 18);
    // The flue, rising out of its back to the main.
    final flue = Rect.fromLTWH(p.dx + 16, p.dy - 62, 14, 40);
    canvas.drawRect(flue, Paint()..color = const Color(0xFF34353A));
    canvas.drawRect(
      Rect.fromLTWH(flue.left + 2, flue.top, 3, flue.height),
      Paint()..color = const Color(0x33D8E4EA),
    );
    final top = Rect.fromLTWH(p.dx - 40, p.dy - 30, 80, 16);
    final face = Rect.fromLTWH(p.dx - 40, p.dy - 14, 80, 44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(top, const Radius.circular(4)),
      Paint()..color = const Color(0xFF48494F),
    );
    canvas.drawRect(face, Paint()..color = const Color(0xFF26262B));
    _drawFireboxGlass(canvas, face.deflate(4), pulse);
    for (final c in [
      face.topLeft + const Offset(5, 5),
      face.topRight + const Offset(-5, 5),
      face.bottomLeft + const Offset(5, -5),
      face.bottomRight + const Offset(-5, -5),
    ]) {
      canvas.drawCircle(c, 1.8, Paint()..color = const Color(0xFF8A8A90));
    }
    if (_fx.ready) {
      drawGlow(
        canvas,
        _fx.glow!,
        p + const Offset(0, 40),
        46,
        const Color(0xFFFF7A33).withValues(alpha: 0.10 + 0.12 * pulse),
      );
    }
  }

  /// THE BURST-DISC: a riveted dome in a heavy flanged ring over the vault
  /// shaft, stamped with what it takes. Blown, it is torn petals curled back
  /// from a dark shaft that still breathes.
  void _drawBurstDisc(Canvas canvas, Offset c, int threshold) {
    final rng = GlassRng(_steamSeed('burstdisc'));
    canvas.drawCircle(c, 33, Paint()..color = const Color(0x66120D09));
    canvas.drawCircle(c, 30, Paint()..color = const Color(0xFF2E2F34));
    for (var k = 0; k < 12; k++) {
      final a = k * pi / 6;
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * 26,
        1.9,
        Paint()..color = const Color(0xFF8A8A90),
      );
    }
    if (burstDiscBlown) {
      canvas.drawCircle(c, 22, Paint()..color = const Color(0xFF07090A));
      for (var k = 0; k < 6; k++) {
        final a = k * pi / 3 + rng.range(-0.2, 0.2);
        final petal = Path()
          ..moveTo(c.dx + cos(a - 0.26) * 20, c.dy + sin(a - 0.26) * 20)
          ..lineTo(c.dx + cos(a) * 31, c.dy + sin(a) * 31)
          ..lineTo(c.dx + cos(a + 0.26) * 20, c.dy + sin(a + 0.26) * 20)
          ..close();
        canvas.drawPath(petal, Paint()..color = const Color(0xFF5A6068));
      }
      _addVaporRun(
        c,
        const Offset(0, -1),
        70,
        _moltenPulse,
        count: 160,
        rate: 0.3,
        w0: 6,
        w1: 30,
        ease: 1.4,
        curl: 8,
        wave: 60,
        alpha: 0.45,
        seed: 51,
        trail: 0.02,
        hot: 0.1,
      );
      _vaporBatch.paint(canvas, _kVaporRamp);
      return;
    }
    canvas.drawCircle(
      c,
      21,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [Color(0xFF7A828A), Color(0xFF3A4048), Color(0xFF1E2227)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: 21)),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '$threshold',
        style: const TextStyle(
          color: Color(0xFFE4C16A),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    if (_fx.ready && boilerPressure >= threshold) {
      final pulse = 0.6 + 0.4 * sin(_moltenPulse * 3.0);
      drawGlow(
        canvas,
        _fx.glow!,
        c,
        36,
        const Color(0xFFE4C16A).withValues(alpha: 0.10 + 0.16 * pulse),
      );
    }
  }
}
