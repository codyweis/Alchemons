// lib/widgets/stadium_trophy.dart
//
// THE TRIALS' cup in grains (the author, 2026-10-12: "a trophy on the
// home screen ... where the alchemy orb used to live in the middle"). A
// loving cup — a glass bowl in metal fittings, two handles, a knopped stem,
// a stepped foot — in the metal (or the stone) of the cup: copper, silver,
// gold; ruby, sapphire, emerald. The bowl holds the cup's light, standing
// in it to the share of its races won ("more alchemical": a vessel of
// glowing liquid, bubbling); full, it brims over in motes. A glint runs
// over it now and then.
//
// The same cup stands on the stadium's shelf (screens/stadium/cup_shelf.dart)
// and carries the player there (stadium_passage.dart): its grains loosen,
// rim first, into a turning ring while the phone turns, and the ring pours
// back into the cup, foot first, where it stands on the shelf.
//
// Points in tone buckets and radial gradients; no blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// What a cup is made of: the race cups' metals, the gem cups' stones
/// (gem_cups.dart), or ash while it is shut.
enum TrophyMetal { copper, silver, gold, ruby, sapphire, emerald, ash }

/// A cup as it shows: its metal, and how much light is in its bowl.
@immutable
class TrophyLook {
  const TrophyLook(this.metal, {this.fill = 0});

  final TrophyMetal metal;

  /// Light in the bowl, 0..1: the share of the cup's races won.
  final double fill;

  /// The metal [kRaceCups]' cup [index] is made of.
  static TrophyMetal metalOf(int index) => switch (index) {
    0 => TrophyMetal.copper,
    1 => TrophyMetal.silver,
    _ => TrophyMetal.gold,
  };

  /// Cup [index] as [progress] leaves it: ash until it is open.
  static TrophyLook ofCup(int index, RaceProgress progress) {
    final cup = kRaceCups[index];
    if (!progress.cupOpen(index)) return const TrophyLook(TrophyMetal.ash);
    return TrophyLook(
      metalOf(index),
      fill: progress.wonIn(cup) / cup.courses.length,
    );
  }

  /// The stone [kGemCups]' cup [index] is cut from.
  static TrophyMetal gemOf(int index) => switch (index) {
    0 => TrophyMetal.ruby,
    1 => TrophyMetal.sapphire,
    _ => TrophyMetal.emerald,
  };

  /// Gem cup [index] as [progress] leaves it: ash until it is open.
  static TrophyLook ofGem(int index, RaceProgress progress) {
    final cup = kGemCups[index];
    if (!progress.gemOpen(index)) return const TrophyLook(TrophyMetal.ash);
    return TrophyLook(
      gemOf(index),
      fill: progress.wonInGem(cup) / cup.bouts.length,
    );
  }

  /// The cup the player is racing for: the first not yet done, or the last
  /// once every one is.
  static int currentCup(RaceProgress progress) {
    for (var c = 0; c < kRaceCups.length; c++) {
      if (!progress.cupDone(kRaceCups[c])) return c;
    }
    return kRaceCups.length - 1;
  }

  @override
  bool operator ==(Object other) =>
      other is TrophyLook && other.metal == metal && other.fill == fill;

  @override
  int get hashCode => Object.hash(metal, fill);
}

/// A trophy's grains loosened into a turning ring about [centre] ([loose]
/// 0 the cup .. 1 all of it turning), lit [lit] (the ring goes out while
/// the phone turns).
@immutable
class TrophyRing {
  const TrophyRing({
    required this.centre,
    required this.radius,
    required this.loose,
    this.lit = 1,
    this.clock,
    this.inner = 0.76,
  });

  final Offset centre;
  final double radius;
  final double loose;
  final double lit;

  /// What turns the ring (seconds); the paint's own time when null. A
  /// passage that holds still through a turn of the phone stops it.
  final double? clock;

  /// The ring's inner edge, as a share of [radius].
  final double inner;
}

// ── metals ───────────────────────────────────────────────────────────────

class _Metal {
  const _Metal(this.shade, this.base, this.hi, this.glint, this.light);

  /// Dark side → lit body → highlight → the glint's white.
  final Color shade, base, hi, glint;

  /// What fills the bowl.
  final Color light;
}

const Map<TrophyMetal, _Metal> _kMetals = {
  TrophyMetal.copper: _Metal(
    Color(0xFF3E1D10),
    Color(0xFF9C5A2E),
    Color(0xFFDB9661),
    Color(0xFFFFE0BF),
    Color(0xFFFFC48E),
  ),
  TrophyMetal.silver: _Metal(
    Color(0xFF2E3237),
    Color(0xFF8F959D),
    Color(0xFFD3D8DF),
    Color(0xFFFFFFFF),
    Color(0xFFE4ECFA),
  ),
  TrophyMetal.gold: _Metal(
    Color(0xFF4A3818),
    Color(0xFFB08D4C),
    Color(0xFFE2C98F),
    Color(0xFFFBF1D4),
    Color(0xFFF2E3BC),
  ),
  TrophyMetal.ruby: _Metal(
    Color(0xFF3A0812),
    Color(0xFF9E1F35),
    Color(0xFFE35A6E),
    Color(0xFFFFD3DA),
    Color(0xFFFF8FA0),
  ),
  TrophyMetal.sapphire: _Metal(
    Color(0xFF0A1636),
    Color(0xFF2A4FAE),
    Color(0xFF6A97EE),
    Color(0xFFDCE8FF),
    Color(0xFF9EC2FF),
  ),
  TrophyMetal.emerald: _Metal(
    Color(0xFF052719),
    Color(0xFF1C8556),
    Color(0xFF5BD199),
    Color(0xFFD6FFE9),
    Color(0xFF9AF0C4),
  ),
  TrophyMetal.ash: _Metal(
    Color(0xFF1E1D1C),
    Color(0xFF494744),
    Color(0xFF6E6B66),
    Color(0xFF8E8A82),
    Color(0xFF8E8A82),
  ),
};

/// The light that fills a cup of [metal]'s bowl.
Color trophyLight(TrophyMetal metal) => _kMetals[metal]!.light;

/// Tone levels a cup is drawn in, shade (0) to glint ([_kTones] - 1).
const int _kTones = 9;

Color _toneColor(_Metal m, int level) {
  final t = level / (_kTones - 1);
  if (t < 0.4) return Color.lerp(m.shade, m.base, t / 0.4)!;
  if (t < 0.78) return Color.lerp(m.base, m.hi, (t - 0.4) / 0.38)!;
  return Color.lerp(m.hi, m.glint, (t - 0.78) / 0.22)!;
}

// ── the shape ────────────────────────────────────────────────────────────

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

double _easeInOut(double t) =>
    t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

/// The mouth: the rim's half width and its depth, in cup heights.
const double _kRimW = 0.31, _kRimD = 0.055;

/// Half the cup's width [v] of the way down it (0 the rim .. 1 the foot's
/// floor), in cup heights.
double _halfWidth(double v) {
  if (v < 0.5) {
    // The bowl: full under the rim, rounding in to the stem.
    final q = v / 0.5;
    return 0.06 + 0.25 * math.cos(math.pi / 2 * math.pow(q, 1.7));
  }
  if (v < 0.69) {
    // The stem, with a knop.
    final k = (v - 0.585) / 0.03;
    return 0.044 + 0.036 * math.exp(-k * k);
  }
  if (v < 0.8) {
    // The foot flaring out.
    final q = (v - 0.69) / 0.11;
    return 0.044 + 0.152 * q * q;
  }
  // A collar, then the plinth.
  return v < 0.845 ? 0.205 : 0.232;
}

class _Grain {
  const _Grain(
    this.x,
    this.y,
    this.tone,
    this.sweep,
    this.v,
    this.h, {
    this.slot = 0,
    this.handle = false,
  });

  /// One of the handles' (always metal, whatever the bowl is).
  final bool handle;

  /// Its place in a ring: grains in fours a quarter turn apart, so the ring
  /// looks the same turned (see [TrophyRing]).
  final int slot;

  _Grain withSlot(int slot) =>
      _Grain(x, y, tone, sweep, v, h, slot: slot, handle: handle);

  /// Where, in cup heights from the cup's centre (y down).
  final double x, y;

  /// How lit it stands, before the glint: 0 dark .. 1.
  final double tone;

  /// Its place across the glint's path.
  final double sweep;

  /// 0 at the rim .. 1 at the foot: the order it loosens in.
  final double v;

  /// Its own hash.
  final double h;
}

/// The light on a turned surface whose normal faces [nx] across (−1 left
/// edge, 1 right): lit from the upper left and the front, a highlight a
/// little left of centre, and a cool rim of back light down the right.
double _lightAt(double nx) {
  final n = nx.clamp(-1.0, 1.0);
  final nz = math.sqrt(math.max(0.0, 1 - n * n));
  final diffuse = math.max(0.0, -0.6 * n + 0.8 * nz);
  final spec = math.pow(math.max(0.0, -0.32 * n + 0.95 * nz), 44).toDouble();
  final rim = _smooth(0.78, 1, n) * 0.45;
  return 0.08 + 0.64 * diffuse + 0.32 * spec + rim;
}

/// The cup's body: bowl, stem, foot and handles, packed as grains a
/// little under [_kStep] apart.
const double _kStep = 0.022;

final List<_Grain> _body = () {
  final out = <_Grain>[];
  var i = 0;
  // The body, row by row, every other row half a step over.
  var row = 0;
  for (var v = 0.0; v <= 1.0; v += _kStep * 0.88, row++) {
    final w = _halfWidth(v);
    final y = v - 0.5;
    for (var x = -w + (row.isOdd ? _kStep / 2 : 0); x <= w; x += _kStep) {
      i++;
      final jx = (_h(i, 1) - .5) * _kStep * .35;
      final jy = (_h(i, 2) - .5) * _kStep * .35;
      final gx = x + jx, gy = y + jy;
      // Above the near lip of the mouth is the mouth itself.
      final lip =
          -0.5 +
          _kRimD * math.sqrt(_clamp01(1 - (gx / _kRimW) * (gx / _kRimW)));
      if (v < 0.12 && gy < lip) continue;
      var tone = _lightAt(gx / w);
      // The foot's collar and the plinth's top edge catch the light; the
      // band between them is a groove.
      if ((v - 0.845).abs() < _kStep * .6) tone *= .55;
      if ((v - 0.8).abs() < _kStep * .6) tone = tone * .7 + .3;
      // The bowl's lower curve turns away from the lamp.
      if (v > .32 && v < .5) tone *= 1 - .35 * _smooth(.32, .5, v);
      out.add(_Grain(gx, gy, tone, gx + .55 * gy, v, _h(i, 3)));
    }
  }
  // The handles: ears from just under the rim out and down to the bowl's
  // waist, two grains thick.
  const p0 = Offset(0.29, -0.43), c1 = Offset(0.53, -0.5);
  const c2 = Offset(0.5, -0.12), p3 = Offset(0.17, -0.1);
  const n = 46;
  for (var side = -1; side <= 1; side += 2) {
    for (var k = 0; k <= n; k++) {
      final t = k / n;
      final u = 1 - t;
      final p =
          p0 * (u * u * u) +
          c1 * (3 * u * u * t) +
          c2 * (3 * u * t * t) +
          p3 * (t * t * t);
      final d =
          (c1 - p0) * (3 * u * u) +
          (c2 - c1) * (6 * u * t) +
          (p3 - c2) * (3 * t * t);
      final len = d.distance;
      final nrm = len == 0 ? Offset.zero : Offset(-d.dy, d.dx) / len;
      for (var layer = -1; layer <= 1; layer += 2) {
        i++;
        final q = p + nrm * (layer * 0.012);
        final x = q.dx * side;
        // A round bar: lit along its upper-left edge on the left handle,
        // its outer edge rim-lit on the right.
        final face = side < 0 ? (layer > 0 ? .95 : .55) : (layer > 0 ? .5 : .3);
        final tone = face * (side < 0 ? 1.0 : .8) + (side > 0 ? .22 * t : 0);
        out.add(
          _Grain(
            x,
            q.dy,
            tone,
            x + .55 * q.dy,
            .08 + .3 * t,
            _h(i, 3),
            handle: true,
          ),
        );
      }
    }
  }
  // Whole sets of four only (see [_Grain.slot]).
  return [
    for (var k = 0; k < out.length - out.length % 4; k++) out[k].withSlot(k),
  ];
}();

/// The mouth's floor: grains inside the rim's ellipse, which hold the
/// light (or, empty, the dark inside of the bowl).
final List<_Grain> _mouth = () {
  final out = <_Grain>[];
  var i = 9000;
  for (var y = -_kRimD; y <= _kRimD; y += _kStep * .7) {
    final half = _kRimW * math.sqrt(_clamp01(1 - (y / _kRimD) * (y / _kRimD)));
    for (var x = -half + _kStep * .5; x < half; x += _kStep) {
      i++;
      out.add(_Grain(x, y - 0.5, 0, x, 0, _h(i, 3)));
    }
  }
  return [
    for (var k = 0; k < out.length - out.length % 4; k++)
      out[k].withSlot(100000 + k),
  ];
}();

/// The rim's lip, all the way round.
final List<_Grain> _lip = () {
  const n = 64;
  return [
    for (var k = 0; k < n; k++)
      () {
        final a = k / n * math.pi * 2;
        final x = math.cos(a) * _kRimW, y = math.sin(a) * _kRimD - 0.5;
        // The near half is the bright lip; the far half the inside's edge.
        final near = math.sin(a) > 0;
        final tone = near ? _lightAt(math.cos(a)) * .7 + .35 : .5;
        return _Grain(x, y, tone, x + .55 * y, 0, _h(k, 41), slot: 200000 + k);
      }(),
  ];
}();

/// How many grains a cup is drawn in (tests read it).
@visibleForTesting
int get stadiumTrophyGrainCount => _body.length + _mouth.length + _lip.length;

// ── painting ─────────────────────────────────────────────────────────────

/// A growable run of point coordinates, kept between frames.
class _Run {
  Float32List _buf = Float32List(512);
  int _n = 0;

  bool get isEmpty => _n == 0;

  void add(double x, double y) {
    if (_n + 2 > _buf.length) {
      _buf = Float32List(_buf.length * 2)..setAll(0, _buf);
    }
    _buf[_n++] = x;
    _buf[_n++] = y;
  }

  Float32List get view => Float32List.sublistView(_buf, 0, _n);
  void clear() => _n = 0;
}

/// Points per tone level, drawn one call per level.
class _Buckets {
  final List<_Run> pts = [for (var i = 0; i < _kTones; i++) _Run()];
  final List<_Run> trails = [for (var i = 0; i < _kTones; i++) _Run()];
  final Paint _paint = Paint()..strokeCap = StrokeCap.round;

  void flush(
    Canvas canvas,
    _Metal m,
    double width,
    double alpha, {
    double trailAlpha = .3,
  }) {
    for (var l = 0; l < _kTones; l++) {
      final c = _toneColor(m, l);
      final t = trails[l];
      if (!t.isEmpty) {
        _paint
          ..strokeWidth = width * .8
          ..color = c.withValues(alpha: (alpha * trailAlpha).clamp(0.0, 1.0));
        canvas.drawRawPoints(ui.PointMode.lines, t.view, _paint);
        t.clear();
      }
      final p = pts[l];
      if (!p.isEmpty) {
        _paint
          ..strokeWidth = width
          ..color = c.withValues(alpha: alpha.clamp(0.0, 1.0));
        canvas.drawRawPoints(ui.PointMode.points, p.view, _paint);
        p.clear();
      }
    }
  }
}

final _Buckets _buckets = _Buckets();

/// Clear glass, dark to its lit edges; and smoked, for a shut cup.
const _Metal _kGlass = _Metal(
  Color(0xFF1C2630),
  Color(0xFF5C7286),
  Color(0xFFB8CCDC),
  Color(0xFFFFFFFF),
  Color(0xFFDDE8F2),
);
const _Metal _kSmokedGlass = _Metal(
  Color(0xFF121416),
  Color(0xFF2A2E33),
  Color(0xFF4A5056),
  Color(0xFF6E747A),
  Color(0xFF4A5056),
);
final Paint _glowPaint = Paint();

void _glow(Canvas canvas, Offset c, double r, Color color, double alpha) {
  if (alpha <= .003 || r <= 0) return;
  _glowPaint.shader = ui.Gradient.radial(
    c,
    r,
    [
      color.withValues(alpha: alpha.clamp(0.0, 1.0)),
      color.withValues(alpha: alpha.clamp(0.0, 1.0) * .35),
      color.withValues(alpha: 0),
    ],
    const [0, .42, 1],
  );
  canvas.drawCircle(c, r, _glowPaint);
  _glowPaint.shader = null;
}

/// The grain width a cup [height] tall is drawn with.
double trophyGrainWidth(double height) => (height * .019).clamp(1.4, 2.9);

/// How a cup [height] tall sits in a box: [height] is the cup's own, the
/// box a little wider for its handles and taller for its light.
Size trophyBoxFor(double height) => Size(height * 1.05, height * 1.3);

/// Paints the cup [look] [height] tall, centred on [at], at [time] seconds.
///
/// [still] leaves out what moves (the glint and the motes). [ring]
/// loosens it into a turning ring. [alpha] fades the whole of it.
/// [glint], when given, runs the glint across it now (0..1 of its way),
/// whatever the time.
void paintStadiumTrophy(
  Canvas canvas,
  Offset at,
  double height,
  TrophyLook look,
  double time, {
  double alpha = 1,
  bool still = false,
  TrophyRing? ring,
  double? glint,
}) {
  if (alpha <= .01 || height <= 2) return;
  final m = _kMetals[look.metal]!;
  final ash = look.metal == TrophyMetal.ash;
  final loose = ring?.loose ?? 0;
  final whole = 1 - _smooth(0, .35, loose);
  final fill = ash ? 0.0 : look.fill.clamp(0.0, 1.0);
  final width = trophyGrainWidth(height);

  // The light round it, under it, and over its bowl.
  if (whole > .01) {
    _glow(
      canvas,
      at + Offset(0, -height * .1),
      height * .95,
      m.base,
      (ash ? .03 : .07) * alpha * whole,
    );
    _glow(
      canvas,
      at + Offset(0, height * .52),
      height * .5,
      m.hi,
      (ash ? .02 : .09) * alpha * whole,
    );
    if (fill > 0) {
      _glow(
        canvas,
        at + Offset(0, -height * .56),
        height * (.32 + .22 * fill),
        m.light,
        (.1 + .22 * fill) * alpha * whole,
      );
    }
  }
  if (ring != null && ring.loose > 0) {
    _glow(
      canvas,
      ring.centre,
      ring.radius * 1.5,
      m.light,
      .12 * alpha * ring.lit * _smooth(0, .6, ring.loose),
    );
  }

  // The glint: a bright band runs across the metal for a moment every few
  // seconds.
  const period = 6.5, run = 1.5;
  final phase = time % period;
  final forced = glint != null && glint > 0 && glint < 1;
  final glintOn = !ash && (forced || (!still && phase < run));
  final glintAt = -1.0 + 2.0 * _easeInOut(forced ? glint : phase / run);

  final b = _buckets;
  final lit = ring?.lit ?? 1;

  void place(_Grain g, int level, {double tilt = 0}) {
    final home = at + Offset(g.x * height, g.y * height);
    if (ring == null || ring.loose <= 0) {
      b.pts[level].add(home.dx, home.dy);
      return;
    }
    // Rim first on the way out; foot first on the way back.
    final u = _clamp01((ring.loose - .35 * g.v - .08 * g.h) / .57);
    if (u <= 0) {
      b.pts[level].add(home.dx, home.dy);
      return;
    }
    final (p, prev) = _loosened(home, g, ring, u, time);
    // Loose, it takes the ring's own light — by its set of four, so the
    // ring is the same a quarter turn round, colour and all.
    final ringLevel = _kTones - 2 - (_h(g.slot ~/ 4, 73) * 3).floor();
    final hot = (level + (ringLevel - level) * u).round().clamp(0, _kTones - 1);
    b.trails[hot]
      ..add(prev.dx, prev.dy)
      ..add(p.dx, p.dy);
    b.pts[hot].add(p.dx, p.dy);
  }

  int levelOf(double tone) =>
      (tone * (_kTones - 1)).round().clamp(0, _kTones - 1);

  // The bowl is glass in metal fittings (the author, 2026-10-12: "more
  // alchemical"): the light it holds stands in it to the share of the
  // cup's races won. Full to the brim, its surface is the mouth.
  if (fill >= .999) {
    for (final g in _mouth) {
      final level = fill > 0
          ? (5 +
                    (3 * fill * (.6 + .4 * math.sin(time * 2.2 + g.h * 30)))
                        .round())
                .clamp(0, _kTones - 1)
          : (g.y < -.5 ? 1 : 0);
      place(g, level);
    }
    b.flush(canvas, m, width, alpha * lit * (fill > 0 ? .55 + .45 * fill : .5));
  }

  // The light it holds, rocking a little and bubbling; then the glass
  // over it, clear but at its edges.
  bool inBowl(_Grain g) => !g.handle && g.v < .44;
  {
    final level = .44 - .4 * fill;
    final liquid = _Metal(m.base, m.hi, m.light, m.glint, m.light);
    for (final g in _body) {
      if (!inBowl(g)) continue;
      final surface = level + .012 * math.sin(time * 1.8 + g.x * 14);
      if (fill <= 0 || g.v < surface) continue;
      final depth = (g.v - surface) / math.max(.02, .44 - surface);
      final shimmer = .5 + .5 * math.sin(time * 2.4 + g.h * 40);
      final top = g.v - surface < .03;
      final tone = top ? 1.0 : (.85 - .45 * depth + .12 * shimmer);
      place(g, (tone * (_kTones - 1)).round().clamp(0, _kTones - 1));
    }
    // Bubbles rising through it.
    if (fill > 0 && !still) {
      for (var i = 0; i < 10; i++) {
        final life = (time * (.25 + .2 * _h(i, 91)) + _h(i, 92)) % 1.0;
        final v = .43 - life * (.43 - level);
        final half = _halfWidth(v) * .8;
        final x = (_h(i, 93) - .5) * 2 * half + math.sin(life * 9 + i) * .01;
        final p = at + Offset(x * height, (v - .5) * height);
        b.pts[_kTones - 1].add(p.dx, p.dy);
      }
    }
    b.flush(canvas, liquid, width, alpha * lit * (.75 + .25 * fill));
    // The glass: its edges catching the light, a few grains of it across
    // the front, smoked dark while the cup is shut.
    for (final g in _body) {
      if (!inBowl(g)) continue;
      final edge = (g.x.abs() / math.max(.02, _halfWidth(g.v))).clamp(0.0, 1.0);
      if (edge < .8 && g.h > .14) continue;
      var tone = edge > .8 ? .55 + .45 * g.tone : .35;
      if (glintOn) {
        final d = g.sweep - glintAt;
        tone += .9 * math.exp(-d * d / .004);
      }
      place(g, levelOf(tone));
    }
    b.flush(
      canvas,
      ash ? _kSmokedGlass : _kGlass,
      width * .85,
      alpha * lit * (ash ? .6 : .75),
    );
  }

  for (final g in _body) {
    if (inBowl(g)) continue;
    var tone = g.tone;
    if (glintOn) {
      final d = g.sweep - glintAt;
      tone += .9 * math.exp(-d * d / .004);
    }
    place(g, levelOf(tone));
  }
  for (final g in _lip) {
    var tone = g.tone;
    if (glintOn) {
      final d = g.sweep - glintAt;
      tone += .7 * math.exp(-d * d / .004);
    }
    place(g, levelOf(tone));
  }
  b.flush(canvas, m, width, alpha * (ash ? .7 : 1) * lit);

  // Motes of the light lifting off a bowl that has any.
  if (fill > 0 && !still && whole > .01) {
    final n = (5 + 21 * fill).round();
    final top = at + Offset(0, -height * .5);
    for (var i = 0; i < n; i++) {
      final speed = .22 + .16 * _h(i, 61);
      final life = (time * speed + _h(i, 62)) % 1.0;
      final x0 = (_h(i, 63) - .5) * 2 * _kRimW * height * .85;
      final sway = math.sin(life * 4.2 + i) * height * .04;
      final p = top + Offset(x0 * (1 - .4 * life) + sway, -life * height * .62);
      final level = life < .5 ? _kTones - 1 : _kTones - 2;
      b.pts[level].add(p.dx, p.dy);
    }
    b.flush(
      canvas,
      _Metal(m.light, m.light, m.light, m.glint, m.light),
      width * .9,
      alpha * whole * (.35 + .5 * fill),
    );
  }
}

/// Where grain [g] is, [u] of the way from [home] into [ring], and where
/// it was a moment before (for its trail).
(Offset, Offset) _loosened(
  Offset home,
  _Grain g,
  TrophyRing ring,
  double u,
  double time,
) {
  final c = ring.centre;
  // Its place in the ring: in a set of four a quarter turn apart (the ring
  // looks the same turned, so a turn of the phone under it cannot show),
  // in a band, the inside turning faster.
  final set = g.slot ~/ 4, quarter = g.slot % 4;
  final span = 1 - ring.inner;
  final f = _h(set, 71);
  final band = ring.inner + span * f;
  final r1 = ring.radius * band;
  final w = 0.55 + 0.4 * (1 - f);
  final a1 =
      _h(set, 72) * math.pi / 2 +
      quarter * math.pi / 2 +
      (ring.clock ?? time) * w;

  Offset at(double e) {
    final d0 = home - c;
    final r0 = d0.distance;
    final a0 = math.atan2(d0.dy, d0.dx);
    // Round the long way, so every grain spirals in the ring's own turn.
    var da = (a1 - a0) % (math.pi * 2);
    if (da < math.pi * .5) da += math.pi * 2;
    final a = a0 + da * e;
    final r = r0 + (r1 - r0) * e;
    return c + Offset(math.cos(a), math.sin(a)) * r;
  }

  final e = Curves.easeInOutCubic.transform(u);
  final p = at(e);
  if (u >= 1) {
    // In the ring: its trail is the arc it has just come round.
    final a = a1 - w * .05;
    return (p, c + Offset(math.cos(a), math.sin(a)) * r1);
  }
  return (p, at(Curves.easeInOutCubic.transform(math.max(0, u - .045))));
}

// ── the emblem ───────────────────────────────────────────────────────────

/// The cup on home: the icon, with its own clock. Leaves its place empty
/// while [lifted] (it is away carrying the player to the stadium).
class StadiumTrophyEmblem extends StatefulWidget {
  const StadiumTrophyEmblem({
    super.key,
    required this.height,
    required this.look,
    this.animate = true,
    this.lifted,
  });

  /// The cup's own height; the box is [trophyBoxFor] it.
  final double height;
  final TrophyLook look;
  final bool animate;
  final ValueListenable<bool>? lifted;

  @override
  State<StadiumTrophyEmblem> createState() => _StadiumTrophyEmblemState();
}

class _StadiumTrophyEmblemState extends State<StadiumTrophyEmblem>
    with GlyphClockLease {
  bool _visible = true;
  double _stilled = 0;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (!wantsClock) _stilled = GlyphClock.instance.seconds.value;
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      _sync();
    }
  }

  @override
  void didUpdateWidget(covariant StadiumTrophyEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = trophyBoxFor(widget.height);
    Widget paint(bool away) => CustomPaint(
      size: box,
      willChange: widget.animate && !away,
      painter: away
          ? null
          : _EmblemPainter(
              height: widget.height,
              look: widget.look,
              clock: glyphClock,
              time: glyphClock == null ? _stilled : null,
            ),
    );
    final lifted = widget.lifted;
    return RepaintBoundary(
      child: lifted == null
          ? paint(false)
          : ValueListenableBuilder<bool>(
              valueListenable: lifted,
              builder: (_, away, _) => paint(away),
            ),
    );
  }
}

/// Where the cup stands in a box from [trophyBoxFor]: a little below the
/// middle, so its light has room over it.
Offset trophyCentreIn(Rect box) =>
    Offset(box.center.dx, box.top + box.height * .6);

class _EmblemPainter extends CustomPainter {
  _EmblemPainter({
    required this.height,
    required this.look,
    this.clock,
    this.time,
  }) : super(repaint: clock);

  final double height;
  final TrophyLook look;
  final ValueListenable<double>? clock;
  final double? time;

  @override
  void paint(Canvas canvas, Size size) {
    paintStadiumTrophy(
      canvas,
      trophyCentreIn(Offset.zero & size),
      height,
      look,
      time ?? clock?.value ?? 0,
    );
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) =>
      old.height != height ||
      old.look != look ||
      old.clock != clock ||
      old.time != time;
}
