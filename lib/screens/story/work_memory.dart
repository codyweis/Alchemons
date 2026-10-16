// lib/screens/story/work_memory.dart
//
// YOUR WORK. The memory the first descent's last line opens onto ("You made
// it to hide your work from yourself"), between that line and the planet's
// light. All of it in grains, drained to brass, on black: remembered, not
// happening.
//
// Two wild Alchemons drift in open space, turning round each other. Your
// ship -- the hull you fly now -- slides in, and ropes of grain go out and
// take one, then the other. They pull against it; the ropes hold. The
// collector's card from the opening is read here, while they strain. Then
// they are pushed into each other: their grains come away nearest-first and
// wind into one sphere, and one of them pulls back out of it once before it
// is taken anyway. The sphere settles into a single creature -- the kind
// that stands at the head of your party now, made from the two kinds the
// recipe tables most often make it from -- and the grains it did not need
// drift off and go out. The ship goes, the memory thins, and the new one,
// still in brass, crosses to where the lead stands in the room and shrinks
// to its size there: it is the lead (the cinematic fades the real one in
// on it as its grains go).
//
// Pure, time-driven Dart, like the fusion fx: [WorkMemory.paint] draws the
// scene at time t (with a free-running clock for what keeps moving while a
// line is read). A few thousand points in bucketed drawRawPoints calls; no
// blur, no images.

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/cosmic_ship_emblem.dart' show ShipGrains;
import 'package:alchemons/widgets/fx/fusion_particles.dart'
    show GrainBatch, SpecimenGrains;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

/// Who the memory is about: the two taken, the one made of them, and the
/// ship that took them.
class WorkMemoryCast {
  const WorkMemoryCast({
    required this.taken,
    required this.made,
    this.ship,
    this.madeReadScale = 1,
  });

  /// The two wild ones, as grains.
  final List<SpecimenGrains> taken;

  /// The one they were made into.
  final SpecimenGrains made;
  final ShipGrains? ship;

  /// How many logical px of [made] there are to one unit of the lead as its
  /// own painter draws it at scale 1: what takes it back to the lead's size
  /// in the room.
  final double madeReadScale;
}

/// The two kinds (family, element) the recipe tables most often make a
/// [family] [element] Alchemon from: the family formula likeliest to give
/// its family, and the element formula likeliest to give its element (not
/// counting an element alone, which only makes itself). A family no formula
/// makes (a Mystic) is made from two of its own.
Future<List<(String, String)>> workMemoryParents(
  String family,
  String element,
) async {
  final fam = family.toLowerCase();
  (String, String) best(Map<String, dynamic> recipes, String target) {
    var top = -1.0;
    (String, String)? pair;
    for (final entry in recipes.entries) {
      final parts = entry.key.split('+').map((s) => s.trim()).toList();
      if (parts.length != 2) continue;
      final dist = entry.value;
      if (dist is! Map) continue;
      final w = (dist[target] as num?)?.toDouble() ?? 0;
      if (w > top) {
        top = w;
        pair = (parts[0], parts[1]);
      }
    }
    return top > 0 && pair != null ? pair : (target, target);
  }

  final families =
      jsonDecode(
            await rootBundle.loadString(
              'assets/data/alchemons_family_recipes.json',
            ),
          )['recipes']
          as Map<String, dynamic>;
  final elements =
      jsonDecode(
            await rootBundle.loadString(
              'assets/data/alchemons_element_recipes.json',
            ),
          )['recipes']
          as Map<String, dynamic>;
  final (fa, fb) = best(families, fam);
  final (ea, eb) = best(elements, element);
  return [(fa, ea), (fb, eb)];
}

/// What [paint] draws in a [box] (logical px, centred on the canvas's
/// origin), read into grains.
Future<SpecimenGrains?> readSpecimenGrains(
  Size box,
  void Function(Canvas canvas) paint, {
  double pixelRatio = 2,
  int maxGrains = 1500,
}) async {
  final w = (box.width * pixelRatio).round();
  final h = (box.height * pixelRatio).round();
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)
    ..scale(pixelRatio)
    ..translate(box.width / 2, box.height / 2);
  paint(canvas);
  final picture = rec.endRecording();
  final image = await picture.toImage(w, h);
  picture.dispose();
  try {
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) return null;
    final grains = SpecimenGrains.fromRgba(
      data.buffer.asUint8List(),
      w,
      h,
      pixelRatio: pixelRatio,
      maxGrains: maxGrains,
    );
    return grains.length < 60 ? null : grains;
  } finally {
    image.dispose();
  }
}

double _sm(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _smoother(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

/// The brass every grain is drained to, darkest first.
const int _levels = 12;
final List<Color> _brass = [
  for (var i = 0; i < _levels; i++) _brassAt(i / (_levels - 1)),
];

Color _brassAt(double t) {
  const stops = [
    Color(0xFF241A0E),
    Color(0xFF6B4E26),
    Color(0xFFB88F45),
    Color(0xFFE4C16A),
    Color(0xFFF7EBC8),
  ];
  final f = t * (stops.length - 1);
  final i = f.floor().clamp(0, stops.length - 2);
  return Color.lerp(stops[i], stops[i + 1], f - i)!;
}

/// A colour's level of brass: its own light, lifted so a dark body still
/// reads on the black.
int _levelOf(Color c) {
  final l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
  return (2 + math.pow(l, 0.85) * (_levels - 3)).round().clamp(1, _levels - 1);
}

/// One body read into grains, drained to brass.
class _Body {
  _Body(SpecimenGrains g, math.Random rng, {double scale = 1})
    : hx = scale == 1
          ? g.hx
          : Float32List.fromList([for (final x in g.hx) x * scale]),
      hy = scale == 1
          ? g.hy
          : Float32List.fromList([for (final y in g.hy) y * scale]),
      step = g.step * scale,
      level = Uint8List(g.length),
      rnd = Float32List(g.length),
      sx = Float32List(g.length),
      sy = Float32List(g.length),
      lon = Float32List(g.length),
      lat = Float32List(g.length),
      rank = Float32List(g.length) {
    final levels = [for (final c in g.tones) _levelOf(c)];
    for (var i = 0; i < g.length; i++) {
      level[i] = levels[g.tone[i].clamp(0, levels.length - 1)];
      rnd[i] = rng.nextDouble();
      final a = rng.nextDouble() * 2 * math.pi;
      final r = math.sqrt(rng.nextDouble());
      sx[i] = math.cos(a) * r;
      sy[i] = math.sin(a) * r;
      lon[i] = rng.nextDouble() * 2 * math.pi;
      lat[i] = math.asin(2 * rng.nextDouble() - 1) * 0.9;
    }
  }

  final Float32List hx, hy;
  final double step;
  final Uint8List level;

  /// Per grain: a random share, a scatter it gathers from, its place on
  /// the sphere, and how soon it leaves its body for it.
  final Float32List rnd, sx, sy, lon, lat, rank;

  int get length => hx.length;

  /// Ranks the grains by how near they are to [towards] (from the body's
  /// own centre), nearest 0: they leave in that order.
  void rankTowards(Offset towards) {
    final d = towards.distance;
    if (d < 1e-3) return;
    final ux = towards.dx / d, uy = towards.dy / d;
    var lo = double.infinity, hi = -double.infinity;
    for (var i = 0; i < length; i++) {
      final p = -(hx[i] * ux + hy[i] * uy);
      rank[i] = p;
      lo = math.min(lo, p);
      hi = math.max(hi, p);
    }
    final span = math.max(1e-3, hi - lo);
    for (var i = 0; i < length; i++) {
      rank[i] = ((rank[i] - lo) / span) * 0.85 + 0.15 * rnd[i];
    }
  }
}

class WorkMemory {
  /// [landAt] is where the lead stands in the room, on the screen, and
  /// [landZoom] the scale the room draws it at: where the one made crosses
  /// to at the end. Without it, it goes out where it was made.
  WorkMemory(this.cast, this.size, {this.landAt, this.landZoom = 1}) {
    final rng = math.Random(23);
    _a = _Body(cast.taken[0], rng);
    _b = _Body(cast.taken[1], rng);
    // The one made of them stands a little taller than either: read from
    // a sprite with more empty frame round it, it would come out smaller.
    final made = _heightOf(cast.made);
    final want =
        1.1 * math.max(_heightOf(cast.taken[0]), _heightOf(cast.taken[1]));
    _mScale = made > 1 ? (want / made).clamp(0.6, 2.2) : 1.0;
    _m = _Body(cast.made, rng, scale: _mScale);
    final ship = cast.ship;
    if (ship != null) {
      _shipLevel = Uint8List(ship.hx.length);
      final levels = [for (final c in ship.colors) _levelOf(c)];
      for (var i = 0; i < ship.hx.length; i++) {
        _shipLevel[i] = levels[ship.tone[i].clamp(0, levels.length - 1)];
      }
    }
    _starX = Float32List(_starCount);
    _starY = Float32List(_starCount);
    _starPh = Float32List(_starCount);
    _starL = Uint8List(_starCount);
    for (var i = 0; i < _starCount; i++) {
      _starX[i] = rng.nextDouble() * size.width;
      _starY[i] = rng.nextDouble() * size.height;
      _starPh[i] = rng.nextDouble() * 2 * math.pi;
      _starL[i] = 6 + rng.nextInt(_levels - 6);
    }
    _ember = Float32List(math.max(0, _a.length + _b.length - _m.length) * 2);
    for (var i = 0; i < _ember.length; i += 2) {
      final a = rng.nextDouble() * 2 * math.pi;
      _ember[i] = math.cos(a);
      _ember[i + 1] = math.sin(a) - 0.35;
    }
    // Each leaves for the sphere nearest-first.
    _a.rankTowards(_meet - _pullA);
    _b.rankTowards(_meet - _pullB);
  }

  final WorkMemoryCast cast;
  final Size size;
  final Offset? landAt;
  final double landZoom;

  /// What the one made was scaled by to stand beside its makers.
  late final double _mScale;

  static double _heightOf(SpecimenGrains g) {
    var lo = double.infinity, hi = -double.infinity;
    for (final y in g.hy) {
      lo = math.min(lo, y);
      hi = math.max(hi, y);
    }
    return hi > lo ? hi - lo : 0;
  }

  /// From the first grain gathering to the last one gone.
  static const double duration = 30.6;

  /// From here the memory thins and the room comes back.
  static const double thinsAt = 26.4;

  /// The one made has crossed to the lead's place by then, and its grains
  /// go out as the lead is shown.
  static const double landedAt = 29.2;

  /// While they strain on the ropes: the collector's card is read here, and
  /// the scene waits (what keeps moving runs off the clock).
  static const double holdAt = 12.0;

  late final _Body _a, _b, _m;
  Uint8List _shipLevel = Uint8List(0);
  late final Float32List _starX, _starY, _starPh;
  late final Uint8List _starL;
  late final Float32List _ember;
  static const int _starCount = 300;

  /// Bodies, the ship, and the fine things (stars, ropes), each in brass
  /// levels × alpha steps.
  static const int _alphas = 4;
  static const int _group = _levels * _alphas;
  final GrainBatch _batch = GrainBatch(_group * 3);

  double get _w => size.width;
  double get _h => size.height;

  /// How big a body stands: read at this height.
  double get _scale => 1.0;

  // ── where things are ────────────────────────────────────────────────

  /// Where the two drift, round each other.
  Offset get _drift => Offset(_w * 0.66, _h * 0.66);

  /// Where they are made one, and where each is pulled to first.
  Offset get _meet => Offset(_w * 0.47, _h * 0.64);
  Offset get _pullA => _meet + Offset(-_w * 0.03, -_h * 0.1);
  Offset get _pullB => _meet + Offset(_w * 0.035, _h * 0.1);

  /// The ship: in from the left, and its nose.
  Offset _shipAt(double t, double clock) {
    final come = _smoother((t - 4.4) / 3.0);
    final go = _smoother((t - 25.6) / 2.8);
    final from = Offset(-_w * 0.25, _h * 0.56);
    final at = Offset(_w * 0.17, _h * 0.52);
    final away = Offset(-_w * 0.3, _h * 0.46);
    final p = Offset.lerp(Offset.lerp(from, at, come)!, away, go)!;
    return p + Offset(0, _h * 0.006 * math.sin(clock * 1.1));
  }

  double get _shipK => _h * 0.34 / 45;
  Offset _noseOf(Offset ship) => ship + Offset(_shipK * 24, 0);

  /// How far round each other the two have turned: slowing to a stop once
  /// roped (the integral of a speed that eases from 1 to 0).
  double _turned(double t) {
    const a = 8.2, b = 10.6;
    if (t < a) return t;
    if (t > b) return a + (b - a) / 2;
    final x = (t - a) / (b - a);
    return t - (b - a) * (x * x * x - x * x * x * x / 2);
  }

  Offset _free(int side, double t, double clock) {
    final th = 0.3 + 0.34 * _turned(t);
    final r = _w * 0.085;
    final o = Offset(r * math.cos(th), 0.55 * r * math.sin(th));
    final bob = Offset(0, _h * 0.01 * math.sin(clock * 1.3 + side * 2.1));
    return side == 0 ? _drift + o + bob : _drift - o + bob;
  }

  /// When each is roped, and how far it has been hauled to its first place.
  static const _ropeAt = [7.0, 8.6];
  double _haul(int side, double t) =>
      side == 0 ? _sm(8.4, 14.6, t) : _sm(9.8, 15.0, t);

  /// How far each has gone into the sphere. The second pulls back out of
  /// it once before it is taken anyway.
  double _pour(int side, double t) {
    if (side == 0) return _sm(15.0, 18.6, t);
    if (t < 15.4) return 0;
    if (t < 16.4) return 0.32 * _sm(15.4, 16.4, t);
    if (t < 17.4) return 0.32 - 0.28 * _sm(16.4, 17.4, t);
    return 0.04 + 0.96 * _sm(17.5, 19.8, t);
  }

  /// Where body [side] stands at [t], before any of it has left: drifting,
  /// then hauled on the rope, pulling against it.
  Offset _bodyAt(int side, double t, double clock) {
    final free = _free(side, t, clock);
    final g = _haul(side, t);
    final to = side == 0 ? _pullA : _pullB;
    final p = Offset.lerp(free, to, g)!;
    // Pulling back against the rope, hardest halfway.
    final resist =
        _w *
        0.022 *
        4 *
        g *
        (1 - g) *
        (0.6 + 0.4 * math.sin(clock * 2.3 + side));
    final away = p - _meet;
    final d = math.max(1.0, away.distance);
    return p + away / d * resist;
  }

  /// How hard body [side] strains away from the rope: its grains drawn out
  /// on the far side.
  double _strain(int side, double t, double clock) {
    final on = _sm(_ropeAt[side] + 1.0, _ropeAt[side] + 2.0, t);
    final off = 1 - _sm(15.0, 16.5, t);
    return on * off * (0.12 + 0.09 * math.sin(clock * 2.3 + side * 1.7));
  }

  Offset _sphere(_Body body, int i, double t, int spin) {
    final rs = _h * 0.14 * (1 - 0.25 * _sm(19, 21, t));
    final lon = body.lon[i] + spin * 0.9 * t;
    final lat = body.lat[i];
    return _meet +
        Offset(rs * math.cos(lat) * math.sin(lon), rs * math.sin(lat));
  }

  double _sphereDepth(_Body body, int i, double t, int spin) {
    final lon = body.lon[i] + spin * 0.9 * t;
    return 0.6 + 0.4 * math.cos(body.lat[i]) * math.cos(lon);
  }

  // ── drawing ─────────────────────────────────────────────────────────

  void _put(int group, int level, double alpha, double x, double y) {
    if (alpha < 0.06) return;
    final a = (alpha * _alphas).ceil().clamp(1, _alphas) - 1;
    _batch.add(group * _group + level * _alphas + a, x, y);
  }

  void paint(Canvas canvas, double t, double clock) {
    _batch.clear();
    if (t >= duration) return;
    final all = 1 - _sm(thinsAt, thinsAt + 2.4, t);
    _paintStars(t, clock, all);
    final ship = _shipAt(t, clock);
    final nose = _noseOf(ship);
    _paintShip(ship, t, all);
    _paintTaken(t, clock, nose, all);
    _paintMade(t, clock);
    _flush(canvas);
  }

  void _flush(Canvas canvas) {
    final body = math.max(1.3, _a.step * 1.1);
    final ship = cast.ship == null
        ? 1.4
        : math.max(1.2, cast.ship!.step * _shipK * 1.15);
    const fine = 1.5;
    for (var g = 0; g < 3; g++) {
      final d = g == 0
          ? body
          : g == 1
          ? ship
          : fine;
      for (var l = 0; l < _levels; l++) {
        for (var a = 0; a < _alphas; a++) {
          _batch.draw(
            canvas,
            g * _group + l * _alphas + a,
            d,
            _brass[l].withValues(alpha: (a + 1) / _alphas),
          );
        }
      }
    }
  }

  void _paintStars(double t, double clock, double all) {
    final lit = _sm(0, 1.6, t) * all;
    for (var i = 0; i < _starCount; i++) {
      final tw = 0.35 + 0.35 * (0.5 + 0.5 * math.sin(clock * 0.9 + _starPh[i]));
      var x = _starX[i] - clock * 3;
      x %= _w;
      if (x < 0) x += _w;
      _put(2, _starL[i], tw * lit, x, _starY[i]);
    }
  }

  void _paintShip(Offset at, double t, double all) {
    final s = cast.ship;
    if (s == null) return;
    final k = _shipK;
    final alpha = _sm(4.4, 5.6, t) * (1 - _sm(26.0, 28.2, t)) * all;
    if (alpha <= 0.05) return;
    for (var i = 0; i < s.hx.length; i++) {
      // Nose up in its own units; turned to face right.
      _put(1, _shipLevel[i], alpha, at.dx - s.hy[i] * k, at.dy + s.hx[i] * k);
    }
  }

  /// A rope of grain from [from] to [to], run out [reach] of the way, its
  /// grains flowing back towards the ship.
  void _rope(Offset from, Offset to, double reach, double clock, double alpha) {
    if (reach <= 0 || alpha <= 0.05) return;
    final mid = Offset.lerp(from, to, 0.5)!;
    final d = to - from;
    final len = d.distance;
    final sag = Offset(0, len * 0.08);
    final c = mid + sag;
    const n = 90;
    for (var k = 0; k < n; k++) {
      var u = (k / n - clock * 0.35) % 1.0;
      if (u < 0) u += 1;
      u *= reach;
      final a = (1 - u) * (1 - u), b = 2 * (1 - u) * u, e = u * u;
      final x = a * from.dx + b * c.dx + e * to.dx;
      final y = a * from.dy + b * c.dy + e * to.dy;
      _put(2, 8 + (k % 3), alpha * (0.55 + 0.45 * math.sin(k * 1.7)), x, y);
    }
  }

  void _paintTaken(double t, double clock, Offset nose, double all) {
    final gather = t;
    for (var side = 0; side < 2; side++) {
      final body = side == 0 ? _a : _b;
      final at = _bodyAt(side, t, clock);
      final pour = _pour(side, t);
      final strain = _strain(side, t, clock);
      final away = at - nose;
      final ad = math.max(1.0, away.distance);
      final ux = away.dx / ad, uy = away.dy / ad;
      final spin = side == 0 ? 1 : -1;
      final formed = t >= 21.0;
      for (var i = 0; i < body.length; i++) {
        final j = side == 0 ? i : _a.length + i;
        // Gathered out of the dark as the memory opens.
        final g = _smoother((gather - 0.3 - 1.4 * body.rnd[i]) / 1.6);
        var x = body.hx[i] * _scale, y = body.hy[i] * _scale;
        // Drawn out on the side away from the rope.
        final along = x * ux + y * uy;
        if (along > 0 && strain > 0) {
          x += ux * along * strain;
          y += uy * along * strain;
        }
        var px = at.dx + x, py = at.dy + y;
        if (g < 1) {
          final r = _h * 0.4;
          px = at.dx + body.sx[i] * r + (x - body.sx[i] * r) * g;
          py = at.dy + body.sy[i] * r + (y - body.sy[i] * r) * g;
        }
        var alpha = _sm(0.0, 0.6, g) * all;
        var level = body.level[i];
        // Into the sphere, nearest first, curling.
        final f = ((pour - body.rank[i] * 0.8) / 0.2).clamp(0.0, 1.0);
        if (f > 0) {
          final e = _smoother(f);
          final s = _sphere(body, i, t, spin);
          final dx = s.dx - px, dy = s.dy - py;
          final curl = 0.22 * math.sin(math.pi * e) * spin;
          px += dx * e - dy * curl;
          py += dy * e + dx * curl;
          alpha *= 1 - (1 - _sphereDepth(body, i, t, spin)) * e;
        }
        if (formed) {
          // The sphere settles into the one made of them; what it did not
          // need drifts off and goes out.
          if (j < _m.length) continue; // drawn by _paintMade
          final e0 = _sphere(body, i, 21.0, spin);
          final k = (j - _m.length) * 2;
          final drift = (t - 21) * _h * (0.05 + 0.04 * body.rnd[i]);
          px = e0.dx + _ember[k] * drift;
          py = e0.dy + _ember[k + 1] * drift;
          alpha = 0.8 * (1 - _sm(21.2, 23.4 + 1.4 * body.rnd[i], t)) * all;
          level = math.max(1, level - 2);
        }
        _put(0, level, alpha, px, py);
      }
      // The rope on it, from the ship's nose, until it is in the sphere.
      final ropeOut = _sm(_ropeAt[side], _ropeAt[side] + 1.2, t);
      final ropeIn = 1 - _sm(19.6 + side * 0.3, 20.6 + side * 0.3, t);
      final held = pour < 0.85
          ? at
          : Offset.lerp(at, _meet, (pour - 0.85) / 0.15)!;
      _rope(nose, held, ropeOut * ropeIn, clock, 0.95 * all);
    }
  }

  void _paintMade(double t, double clock) {
    if (t < 21.0) return;
    // Across to where the lead stands in the room, down to its size there,
    // as the memory thins round it; gone as the lead is shown.
    final land = landAt;
    final cross = land == null ? 0.0 : _smoother((t - 26.6) / 2.6);
    final bob = Offset(0, _h * 0.008 * math.sin(clock * 1.4) * (1 - cross));
    final centre = Offset.lerp(_meet, land ?? _meet, cross)! + bob;
    final to = landZoom / math.max(1e-3, cast.madeReadScale * _mScale);
    final scale = 1 + (to - 1) * cross;
    // Loosening a little on the way, as if carried.
    final loose = 1 + 0.12 * math.sin(math.pi * cross);
    final gone = land == null
        ? 1 - _sm(thinsAt, thinsAt + 2.4, t)
        : 1 - _sm(landedAt, landedAt + 1.2, t);
    final n = _a.length + _b.length;
    for (var j = 0; j < _m.length; j++) {
      final target = Offset(
        centre.dx + _m.hx[j] * scale * loose,
        centre.dy + _m.hy[j] * scale * loose,
      );
      double alpha;
      Offset p;
      int level = _m.level[j];
      if (j < n) {
        final side = j < _a.length ? 0 : 1;
        final body = side == 0 ? _a : _b;
        final i = side == 0 ? j : j - _a.length;
        final u = _smoother((t - 21.0 - 0.9 * body.rnd[i]) / 1.5);
        final s = _sphere(body, i, t, side == 0 ? 1 : -1);
        p = Offset.lerp(s, target, u)!;
        alpha = gone;
        if (u < 0.5) level = body.level[i];
      } else {
        // More of it than there was of them: the rest comes up out of the
        // middle.
        final u = _sm(22.0, 24.0, t);
        p = Offset.lerp(_meet, target, u)!;
        alpha = u * gone;
      }
      _put(0, level, alpha, p.dx, p.dy);
    }
  }
}

/// The memory's cast for a party led by a [family] [element] Alchemon,
/// read [side] logical px high: the two kinds it is made from
/// ([workMemoryParents]), as [firstFrameOf] draws them (a sprite sheet's
/// first frame, say), the lead as [paintLead] draws it (centred, its middle
/// [leadHalfHeight] above its feet at scale 1) and the hull [skin].
Future<WorkMemoryCast?> workMemoryCast({
  required String family,
  required String element,
  required double side,
  required double leadHalfHeight,
  required void Function(Canvas canvas) paintLead,
  required Future<ui.Image?> Function(String family, String element)
  firstFrameOf,
  String? skin,
}) async {
  final box = Size(side, side);
  final taken = <SpecimenGrains>[];
  for (final (f, e) in await workMemoryParents(family, element)) {
    final frame = await firstFrameOf(f, e);
    if (frame == null) return null;
    final fw = frame.width.toDouble(), fh = frame.height.toDouble();
    final k = side * 0.84 / math.max(fw, fh);
    final grains = await readSpecimenGrains(box, (c) {
      c.drawImageRect(
        frame,
        Rect.fromLTWH(0, 0, fw, fh),
        Rect.fromCenter(center: Offset.zero, width: fw * k, height: fh * k),
        Paint()..filterQuality = FilterQuality.medium,
      );
    });
    frame.dispose();
    if (grains == null) return null;
    taken.add(grains);
  }
  final k = side * 0.42 / math.max(1.0, leadHalfHeight);
  final made = await readSpecimenGrains(box, (c) {
    c.scale(k);
    paintLead(c);
  });
  if (made == null) return null;
  ShipGrains? ship;
  try {
    ship = await ShipGrains.of(skin);
  } catch (_) {}
  return WorkMemoryCast(taken: taken, made: made, ship: ship, madeReadScale: k);
}
