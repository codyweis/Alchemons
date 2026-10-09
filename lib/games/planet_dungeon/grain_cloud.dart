// lib/games/planet_dungeon/grain_cloud.dart
//
// A SHAPE HELD IN GRAINS — Air's clouds, plumes and veils as lit grains that
// wander about their places, the way the essence forms and the dust ring do.
// No puff sprites, no outlines, no blur.
//
// A [GrainShape] is a list of homes, each with a shade (0 belly .. 1 crown)
// and a seed. Drawing it is time alone: every grain sits at its home plus a
// slow drift (and, for a ring, its orbit), with a short trail back to where
// it was a moment ago, so a cloud that is standing still is still moving.
//
// COST. Shapes are built once and cached by the caller. Drawing is two plain
// passes over typed arrays — no per-grain allocation, drift shared out of 32
// precomputed wobbles, orbits out of 12 precomputed turns — and then one
// drawRawPoints per shade (≤25 calls). A few thousand grains is a fraction
// of a millisecond.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Air's grains, from the essence look: shadow, body, lit, glint.
const List<Color> kAirGrainRamp = [
  Color(0xFF3D5A66),
  Color(0xFF86AEBB),
  Color(0xFFC9E6EC),
  Color(0xFFFFFFFF),
];

/// A four-step ramp around one color, for grains tinted to a state.
List<Color> grainRampFrom(Color c) {
  final o = c.withValues(alpha: 1);
  return [
    Color.lerp(o, const Color(0xFF0A1018), 0.55)!,
    o,
    Color.lerp(o, const Color(0xFFFFFFFF), 0.45)!,
    const Color(0xFFFFFFFF),
  ];
}

double _frac(double v) => v - v.floorToDouble();

double _hash(int n) => _frac(math.sin(n * 127.1 + 311.7) * 43758.5453);

const int _kLevels = 8; // shade steps
const int _kFades = 3; // a veil's grains fading in and out at its ends
const int _kGroups = _kLevels * _kFades + 1; // + the glinting ones
const int _kWobbles = 32;
const int _kTurns = 12;

class GrainShape {
  GrainShape._(this.xs, this.ys, this.level, this.wobble)
    : _buf = Float32List(xs.length * 4),
      _group = Uint8List(xs.length);

  final Float32List xs, ys;

  /// Shade, in [_kLevels] steps (0 belly .. 7 crown).
  final Uint8List level;

  /// Which shared wobble each grain drifts by.
  final Uint8List wobble;

  /// A ring's orbit: the centre, a turn rate per [_kTurns] band, and the band
  /// each grain is in. Null for a shape that only drifts.
  Offset? _orbitAbout;
  Float32List? _turnRate;
  Uint8List? _turn;

  final Float32List _buf;
  final Uint8List _group;
  final Int32List _count = Int32List(_kGroups);
  final Int32List _start = Int32List(_kGroups);

  int get length => xs.length;

  static GrainShape _of(List<Offset> pts, List<double> shades, int seed) {
    final n = pts.length;
    final xs = Float32List(n), ys = Float32List(n);
    final lv = Uint8List(n), wb = Uint8List(n);
    for (var i = 0; i < n; i++) {
      xs[i] = pts[i].dx;
      ys[i] = pts[i].dy;
      lv[i] = (shades[i].clamp(0.0, 1.0) * (_kLevels - 1)).round();
      wb[i] = (_hash(seed * 7919 + i) * _kWobbles).floor() % _kWobbles;
    }
    return GrainShape._(xs, ys, lv, wb);
  }

  /// Turns every grain about [centre] at [rate] (radians/s) for its distance
  /// out — inner faster than outer, so clumps shear the way the dust ring's
  /// do.
  void orbit(Offset centre, double Function(double radius) rate) {
    var lo = double.infinity, hi = 0.0;
    final r = Float32List(length);
    for (var i = 0; i < length; i++) {
      r[i] = (Offset(xs[i], ys[i]) - centre).distance;
      lo = math.min(lo, r[i]);
      hi = math.max(hi, r[i]);
    }
    final rates = Float32List(_kTurns);
    final band = Uint8List(length);
    for (var k = 0; k < _kTurns; k++) {
      rates[k] = rate(lo + (hi - lo) * (k + 0.5) / _kTurns);
    }
    for (var i = 0; i < length; i++) {
      final u = hi > lo ? (r[i] - lo) / (hi - lo) : 0.0;
      band[i] = math.min(_kTurns - 1, (u * _kTurns).floor());
    }
    _orbitAbout = centre;
    _turnRate = rates;
    _turn = band;
  }

  /// Grains through a union of discs — a cloud built from puffs — lit from
  /// above: high in its puff is crown, low is belly. Thinner toward the
  /// outline, so the edge billows instead of stopping.
  factory GrainShape.puffs(
    List<(Offset, double)> puffs,
    int count, {
    int seed = 1,
  }) {
    var box = Rect.zero;
    for (final (o, r) in puffs) {
      final b = Rect.fromCircle(center: o, radius: r);
      box = box == Rect.zero ? b : box.expandToInclude(b);
    }
    final rng = math.Random(seed);
    final pts = <Offset>[];
    final shades = <double>[];
    var tries = 0;
    while (pts.length < count && tries < count * 60) {
      tries++;
      final p = Offset(
        box.left + rng.nextDouble() * box.width,
        box.top + rng.nextDouble() * box.height,
      );
      // The puff it is deepest in decides its depth and its light.
      var depth = -1.0;
      var lit = 0.0;
      for (final (o, r) in puffs) {
        final d = 1 - (p - o).distance / r;
        if (d > depth) {
          depth = d;
          lit = 0.5 + 0.5 * (o.dy - p.dy) / r;
        }
      }
      if (depth <= 0) continue;
      if (rng.nextDouble() > 0.3 + 0.7 * math.sqrt(depth)) continue;
      // Light comes from the top of the whole cloud as well as each puff.
      final high = 1 - (p.dy - box.top) / math.max(1.0, box.height);
      pts.add(p);
      shades.add(0.65 * lit + 0.35 * high);
    }
    return _of(pts, shades, seed);
  }

  /// Grains through any region that can be tested, shaded top to bottom.
  factory GrainShape.region(
    Rect box,
    bool Function(Offset) inside,
    int count, {
    int seed = 1,
  }) {
    final rng = math.Random(seed);
    final pts = <Offset>[];
    final shades = <double>[];
    var tries = 0;
    while (pts.length < count && tries < count * 60) {
      tries++;
      final p = Offset(
        box.left + rng.nextDouble() * box.width,
        box.top + rng.nextDouble() * box.height,
      );
      if (!inside(p)) continue;
      pts.add(p);
      shades.add(1 - (p.dy - box.top) / math.max(1.0, box.height));
    }
    return _of(pts, shades, seed);
  }

  /// Grains laid where the caller says, with the light it says.
  factory GrainShape.points(
    List<Offset> pts,
    List<double> shades, {
    int seed = 1,
  }) => _of(pts, shades, seed);

  /// A plume, centred on the origin and lying along +x: a bright quill, and
  /// barbs swept toward the tip on both sides, each barb a short run of
  /// grains — so it reads as a feather by its grain, not by an outline.
  factory GrainShape.feather(double len, {int seed = 3}) {
    final half = len * 0.5;
    final maxW = len * 0.20;
    Offset spine(double t) =>
        Offset(-half + t * len, -math.sin(t * math.pi) * len * 0.06);
    double vane(double t) {
      final u = ((t - 0.18) / 0.82).clamp(0.0, 1.0);
      return maxW *
          math.pow(math.sin(u * math.pi), 0.65).toDouble() *
          (1.0 - u * 0.22);
    }

    final rng = math.Random(seed);
    final pts = <Offset>[];
    final shades = <double>[];
    final step = math.max(1.6, len / 46);
    // The quill, bare below the vane.
    for (var s = -0.13; s <= 1.0; s += step / len) {
      final p = s < 0 ? spine(0) + Offset(s * len, -s * len * 0.27) : spine(s);
      pts.add(p);
      shades.add(1.0);
    }
    // Barbs: from the quill out and forward, upper side longer.
    final barbs = (len / 3.2).round().clamp(8, 60);
    for (var k = 0; k < barbs; k++) {
      final t = 0.18 + (k + rng.nextDouble() * 0.6) / barbs * 0.82;
      final p = spine(t);
      final w = vane(t);
      for (final side in const [-1.0, 0.72]) {
        final reach = w * side.abs();
        final n = math.max(2, (reach / step).round());
        for (var j = 1; j <= n; j++) {
          final u = j / n;
          // Swept toward the tip, curling a little at the end.
          final q =
              p +
              Offset(
                reach * (0.42 * u + 0.18 * u * u),
                side.sign * reach * u * (1 - 0.08 * u),
              );
          pts.add(q + Offset(rng.nextDouble() - 0.5, rng.nextDouble() - 0.5));
          shades.add(side < 0 ? 0.9 - 0.45 * u : 0.6 - 0.4 * u);
        }
      }
    }
    // Down where the vane meets the quill.
    for (var j = 0; j < (len / 8).round(); j++) {
      final p =
          spine(0.16) +
          Offset(-3 + rng.nextDouble() * 7, -4 + rng.nextDouble() * 9);
      pts.add(p);
      shades.add(0.45);
    }
    return _of(pts, shades, seed);
  }
}

final Float32List _wx = Float32List(_kWobbles), _wy = Float32List(_kWobbles);
final Float32List _px = Float32List(_kWobbles), _py = Float32List(_kWobbles);
final Float32List _tc = Float32List(_kTurns), _ts = Float32List(_kTurns);
final Float32List _pc = Float32List(_kTurns), _ps = Float32List(_kTurns);
final Paint _grainPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

/// Draws [s] at time [t].
///
/// [drift] is how far a grain wanders from home. [rotation] turns the whole
/// shape about [origin]; [spin] is how fast that turn is moving (radians/s),
/// so the trails follow it. [fall] runs every grain down through a band of
/// that height and back in at the top (a veil); [glint] lights that share of
/// grains white for a moment (twinkle, or a thundercloud's flicker).
/// [trail] is how far back, in seconds, each grain's streak reaches.
void paintGrainShape(
  Canvas canvas,
  GrainShape s,
  double t, {
  Offset origin = Offset.zero,
  double scale = 1,
  double rotation = 0,
  double spin = 0,
  double drift = 3,
  double alpha = 1,
  List<Color> ramp = kAirGrainRamp,
  double fall = 0,
  double fallSpeed = 0,
  double glint = 0,
  double width = 1.8,
  double trail = 0.09,
}) {
  final n = s.length;
  if (alpha <= 0.02 || n == 0) return;

  // The shared wobbles, now and a moment ago.
  for (var k = 0; k < _kWobbles; k++) {
    final a = _hash(k * 31 + 7) * 6.2832, b = _hash(k * 17 + 3) * 40;
    double wx(double tt) =>
        drift * (0.6 * math.sin(tt * 0.7 + a) + 0.4 * math.sin(tt * 1.9 + b));
    double wy(double tt) =>
        drift *
        (0.6 * math.cos(tt * 0.6 + b) + 0.4 * math.sin(tt * 1.4 + a * 3));
    _wx[k] = wx(t);
    _wy[k] = wy(t);
    _px[k] = wx(t - trail);
    _py[k] = wy(t - trail);
  }
  final about = s._orbitAbout, rates = s._turnRate, turn = s._turn;
  if (rates != null) {
    for (var k = 0; k < _kTurns; k++) {
      _tc[k] = math.cos(rates[k] * t);
      _ts[k] = math.sin(rates[k] * t);
      _pc[k] = math.cos(rates[k] * (t - trail));
      _ps[k] = math.sin(rates[k] * (t - trail));
    }
  }

  // Pass one: which group each grain draws in, and how many in each.
  final group = s._group, count = s._count, start = s._start;
  count.fillRange(0, _kGroups, 0);
  final flick = (t * 9).floor();
  final top = -fall / 2;
  for (var i = 0; i < n; i++) {
    var fade = _kFades - 1;
    if (fall > 0) {
      final u = _frac((s.ys[i] - top) / fall + t * fallSpeed / fall);
      final f = math.min(u, 1 - u) * 5;
      fade = f < 0.34 ? 0 : (f < 0.67 ? 1 : 2);
    }
    final g = glint > 0 && _hash(flick * 131 + i) < glint
        ? _kGroups - 1
        : s.level[i] * _kFades + fade;
    group[i] = g;
    count[g]++;
  }
  var acc = 0;
  for (var g = 0; g < _kGroups; g++) {
    start[g] = acc;
    acc += count[g];
  }

  // Pass two: where each grain is and was, written into its group's run.
  final buf = s._buf;
  final cr = math.cos(rotation), sr = math.sin(rotation);
  final rp = rotation - spin * trail;
  final cp = math.cos(rp), sp = math.sin(rp);
  final ox = origin.dx, oy = origin.dy;
  for (var i = 0; i < n; i++) {
    var hx = s.xs[i], hy = s.ys[i];
    var qx = hx, qy = hy;
    if (about != null) {
      final k = turn![i];
      final rx = hx - about.dx, ry = hy - about.dy;
      hx = about.dx + rx * _tc[k] - ry * _ts[k];
      hy = about.dy + rx * _ts[k] + ry * _tc[k];
      qx = about.dx + rx * _pc[k] - ry * _ps[k];
      qy = about.dy + rx * _ps[k] + ry * _pc[k];
    }
    if (fall > 0) {
      final u = _frac((hy - top) / fall + t * fallSpeed / fall);
      hy = top + u * fall;
      qy = hy - fallSpeed * trail;
    }
    final w = s.wobble[i];
    final x = (hx + _wx[w]) * scale, y = (hy + _wy[w]) * scale;
    var px = (qx + _px[w]) * scale, py = (qy + _py[w]) * scale;
    // A trail too short to draw is nudged so the cap still makes a grain.
    if ((x - px).abs() + (y - py).abs() < 0.3) px -= 0.3;
    final o = start[group[i]]++ * 4;
    buf[o] = ox + px * cp - py * sp;
    buf[o + 1] = oy + px * sp + py * cp;
    buf[o + 2] = ox + x * cr - y * sr;
    buf[o + 3] = oy + x * sr + y * cr;
  }

  // One call per group.
  var from = 0;
  for (var g = 0; g < _kGroups; g++) {
    final c = count[g];
    if (c == 0) continue;
    final glinting = g == _kGroups - 1;
    final lv = glinting ? _kLevels - 1 : g ~/ _kFades;
    final fade = glinting ? 1.0 : const [0.3, 0.65, 1.0][g % _kFades];
    final shade = lv / (_kLevels - 1);
    final col = glinting
        ? ramp.last
        : ramp[(shade * (ramp.length - 1)).round()];
    _grainPaint
      ..strokeWidth = glinting ? width * 1.35 : width
      ..color = col.withValues(
        alpha: (alpha * fade * (glinting ? 1 : 0.45 + 0.55 * shade)).clamp(
          0.0,
          1.0,
        ),
      );
    canvas.drawRawPoints(
      PointMode.lines,
      Float32List.sublistView(buf, from * 4, (from + c) * 4),
      _grainPaint,
    );
    from += c;
  }
}
