// lib/games/planet_dungeon/cinder_grains.dart
//
// FIRE IN GRAINS — the Cinder Cathedral's flames, coals, ash and smoke as lit
// grains in motion, the way the essence forms and the dust ring are drawn
// (2026-10-08). Every vector flame drawn for this planet read as a cartoon;
// the planet's own look is embers rising, white-gold at the root and cooling
// to red as they climb.
//
//  · [paintGrainFlame] — a flame as a few dozen to a few hundred grains, each
//    born at the root, rising and drawing in to a tip on its own clock, with
//    a short trail. One in eight or so slips the tip as a loose ember.
//  · [paintGrainBed] — coals or cold ash lying in an ellipse: grains that sit
//    still and breathe (coals flicker between red and gold; ash only glints).
//  · [paintAshBank] — ash blown and banked in one direction: a dense head
//    that thins out downwind, so the bank is a pointer made of material.
//  · [paintSmokeRoll] — smoke boiling up off a disc and rolling outward as it
//    clears ([progress] 0 → 1).
//
// COST. No allocation per frame: every grain's seeds come from fixed tables,
// positions are written into one scratch Float32List per shade/alpha group,
// and each group is one drawRawPoints. A 32px flame is ~190 grains.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Fire's grains, from the essence look: deep, body, lit, white-hot.
const List<Color> kEmberRamp = [
  Color(0xFF5A1405),
  Color(0xFFB8300A),
  Color(0xFFEE7A12),
  Color(0xFFFFD27A),
];

/// A small, hot flame (a candle, a wick): the ramp one step brighter, so a
/// flame a few grains tall still reads gold and not red.
const List<Color> kCandleRamp = [
  Color(0xFFB8300A),
  Color(0xFFEE7A12),
  Color(0xFFFFD27A),
  Color(0xFFFFF0C8),
];

/// Ash: soot-grey to bone, never white.
const List<Color> kAshRamp = [
  Color(0xFF3A332D),
  Color(0xFF6E6359),
  Color(0xFFA39582),
  Color(0xFFD2C4AC),
];

/// Smoke: warm greys, lit from the fire below.
const List<Color> kSmokeRamp = [
  Color(0xFF221D1A),
  Color(0xFF443B35),
  Color(0xFF6E625A),
  Color(0xFF9A8C80),
];

/// A draught of air through the cathedral: pale, cool, never white.
const List<Color> kWindRamp = [
  Color(0xFF3D5A66),
  Color(0xFF86AEBB),
  Color(0xFFBFD4E0),
  Color(0xFFE8F2FA),
];

/// A billow of smoke over the glass: soft greys, paler than the floor.
const List<Color> kBillowRamp = [
  Color(0xFF4E4641),
  Color(0xFF6E655E),
  Color(0xFF928880),
  Color(0xFFB4AAA0),
];

/// A four-step ramp for a flame drawn in other colors ([outer] its body,
/// [core] its root): deep, outer, core, and the core gone white.
List<Color> flameRampOf(Color core, Color outer) => [
  Color.lerp(outer, const Color(0xFF000000), 0.35)!,
  outer,
  core,
  Color.lerp(core, const Color(0xFFFFFFFF), 0.5)!,
];

const int _kSeeds = 512;
const int _kShades = 4;
const int _kAlphas = 3;
const int _kGroups = _kShades * _kAlphas;

final Float32List _s1 = _seedTable(11);
final Float32List _s2 = _seedTable(23);
final Float32List _s3 = _seedTable(37);
final Float32List _s4 = _seedTable(53);

Float32List _seedTable(int seed) {
  final r = math.Random(seed);
  final t = Float32List(_kSeeds);
  for (var i = 0; i < _kSeeds; i++) {
    t[i] = r.nextDouble();
  }
  return t;
}

final Float32List _buf = Float32List(_kGroups * _kSeeds * 4);
final Int32List _count = Int32List(_kGroups);
final Paint _paint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

const List<double> _kAlphaOf = [0.32, 0.64, 1.0];

double _frac(double v) => v - v.floorToDouble();

void _begin() => _count.fillRange(0, _kGroups, 0);

/// Writes one grain (a segment from where it was to where it is) into its
/// group, [shade] 0..3 and [a] 0..1.
void _put(double px, double py, double x, double y, int shade, double a) {
  if (a < 0.1) return;
  final al = a > 0.78 ? 2 : (a > 0.45 ? 1 : 0);
  final g = shade * _kAlphas + al;
  final k = _count[g];
  if (k >= _kSeeds) return;
  // A trail too short to draw is nudged so the cap still makes a grain.
  if ((x - px).abs() + (y - py).abs() < 0.3) px -= 0.3;
  final o = (g * _kSeeds + k) * 4;
  _buf[o] = px;
  _buf[o + 1] = py;
  _buf[o + 2] = x;
  _buf[o + 3] = y;
  _count[g] = k + 1;
}

void _flush(Canvas canvas, List<Color> ramp, double alpha, double width) {
  for (var g = 0; g < _kGroups; g++) {
    final c = _count[g];
    if (c == 0) continue;
    final shade = g ~/ _kAlphas;
    final a = _kAlphaOf[g % _kAlphas] * alpha * (0.62 + 0.38 * shade / 3);
    if (a <= 0.02) continue;
    _paint
      ..strokeWidth = width
      ..color = ramp[shade].withValues(alpha: a.clamp(0.0, 1.0));
    final o = g * _kSeeds * 4;
    canvas.drawRawPoints(
      PointMode.lines,
      Float32List.sublistView(_buf, o, o + c * 4),
      _paint,
    );
  }
}

/// A flame of height [h] standing on [base] at time [t], in grains.
///
/// [phase] keeps flames side by side from beating together. [spread] widens
/// or narrows the body; [lean] leans the tip (a fraction of [h] per unit of
/// height). [embers] is the share of grains that slip the tip and climb on as
/// loose sparks, cooling to red. [life] slows (>1) or quickens the climb.
void paintGrainFlame(
  Canvas canvas,
  Offset base,
  double h,
  double t, {
  List<Color> ramp = kEmberRamp,
  double phase = 0,
  double alpha = 1,
  double spread = 1,
  double lean = 0,
  double embers = 0.12,
  double life = 1,
  double sway = 1,
  int? count,
  double width = 1.7,
  double trail = 0.035,
}) {
  if (h < 1.5 || alpha <= 0.02) return;
  final n = (count ?? (h * h * 0.15 + h * 3.0).round()).clamp(14, _kSeeds);
  final off = (phase * 97).floor() & (_kSeeds - 1);
  final halfW = h * 0.3 * spread;
  final lifeScale = math.sqrt(h / 30).clamp(0.55, 1.6) * life;
  _begin();
  for (var j = 0; j < n; j++) {
    final i = (j + off) & (_kSeeds - 1);
    final s1 = _s1[i], s2 = _s2[i], s3 = _s3[i], s4 = _s4[i];
    final ember = s4 < embers;
    final period = (0.42 + 0.4 * s2) * lifeScale * (ember ? 1.7 : 1.0);
    final u = _frac(t / period + s3);
    final u0 = u - trail / period;
    final lat = s1 * 2 - 1;
    final reach = ember ? h * (1.45 + 0.9 * s2) : h * (0.95 + 0.5 * s4 * s4);
    final x =
        base.dx +
        _flameX(u, t, ember, lat, halfW, h, phase, s1, s3, sway, lean);
    final y = base.dy - reach * (0.5 * u + 0.5 * u * u);
    double px, py;
    if (u0 < 0) {
      px = x;
      py = y;
    } else {
      px =
          base.dx +
          _flameX(
            u0,
            t - trail,
            ember,
            lat,
            halfW,
            h,
            phase,
            s1,
            s3,
            sway,
            lean,
          );
      py = base.dy - reach * (0.5 * u0 + 0.5 * u0 * u0);
    }
    int shade;
    double a;
    if (ember) {
      shade = u < 0.25 ? 3 : (u < 0.5 ? 2 : (u < 0.75 ? 1 : 0));
      a = math.min(1.0, u / 0.1) * (1 - u);
    } else {
      final hot = (1 - u) * (1 - 0.4 * lat.abs());
      shade = hot > 0.7 ? 3 : (hot > 0.42 ? 2 : (hot > 0.18 ? 1 : 0));
      a = math.min(1.0, u / 0.06) * math.min(1.0, (1 - u) / 0.25);
    }
    _put(px, py, x, y, shade, a);
  }
  _flush(canvas, ramp, alpha, width);
}

/// Where a flame grain stands across the flame at age [uu] and time [tt]:
/// drawn in to a tip, with a wave running up the body.
double _flameX(
  double uu,
  double tt,
  bool ember,
  double lat,
  double halfW,
  double h,
  double phase,
  double s1,
  double s3,
  double sway,
  double lean,
) {
  final wave =
      math.sin(tt * 4.6 + phase - uu * 3.0) * h * 0.085 * uu * sway +
      math.sin(tt * 9.7 + s3 * 6.28) * h * 0.022 * uu * sway;
  if (ember) {
    return lat * halfW * 0.45 +
        math.sin(uu * 5 + s1 * 6.28 + tt * 1.3) * h * 0.22 * uu +
        wave +
        lean * h * uu;
  }
  final prof = math.pow(1 - uu, 1.1) * (0.65 + 1.6 * uu);
  return lat * halfW * prof + wave + lean * h * uu;
}

/// Grains lying in an ellipse ([rx] × [ry]) about [c]: a bed of coals when
/// [flicker] > 0 (each grain breathes between the ramp's red and its gold on
/// its own beat), cold ash when 0. They barely move — a coal does not drift.
void paintGrainBed(
  Canvas canvas,
  Offset c,
  double rx,
  double ry,
  double t, {
  List<Color> ramp = kEmberRamp,
  int count = 90,
  double flicker = 1,
  double alpha = 1,
  int seed = 0,
  double width = 1.8,
}) {
  if (alpha <= 0.02) return;
  final n = count.clamp(1, _kSeeds);
  final off = (seed * 131) & (_kSeeds - 1);
  _begin();
  for (var j = 0; j < n; j++) {
    final i = (j + off) & (_kSeeds - 1);
    final s1 = _s1[i], s2 = _s2[i], s3 = _s3[i], s4 = _s4[i];
    // Denser toward the middle, and a heap: higher at the back than the lip.
    final r = math.sqrt(s1) * (0.35 + 0.65 * s1);
    final a = s2 * 2 * math.pi;
    final x = c.dx + math.cos(a) * rx * r;
    final y = c.dy + math.sin(a) * ry * r - (1 - r) * ry * 0.5;
    final shimmer = math.sin(t * (1.1 + s4 * 2.3) + s3 * 6.28);
    int shade;
    double al;
    if (flicker > 0) {
      // Coals: the middle runs hottest; each breathes on its own beat.
      final heat = (1 - r) * 0.55 + 0.45 * (0.5 + 0.5 * shimmer) * flicker;
      shade = heat > 0.72 ? 3 : (heat > 0.5 ? 2 : (heat > 0.28 ? 1 : 0));
      al = 0.55 + 0.45 * heat;
    } else {
      shade = s4 > 0.95 && shimmer > 0.7
          ? 2
          : (s3 < 0.4 ? 0 : (s3 < 0.85 ? 1 : 2));
      al = 0.5 + 0.3 * (1 - r);
    }
    final dx = shimmer * 0.35;
    _put(x - dx, y + 0.2, x + dx, y, shade, al);
  }
  _flush(canvas, ramp, alpha, width);
}

/// Ash blown into a bank along [dir] (a unit vector, in screen space) from
/// [c]: a dense head that thins and narrows downwind over [len], squashed to
/// lie on the floor. Each grain is a short streak lying with the wind that
/// laid it, so the bank points the way the smoke went.
void paintAshBank(
  Canvas canvas,
  Offset c,
  Offset dir,
  double len,
  double t, {
  List<Color> ramp = kAshRamp,
  int count = 120,
  double alpha = 1,
  int seed = 0,
  double width = 1.6,
  double squash = 0.45,
}) {
  if (alpha <= 0.02) return;
  final d = dir.distance < 1e-6 ? const Offset(1, 0) : dir / dir.distance;
  final n = Offset(-d.dy, d.dx);
  final cnt = count.clamp(1, _kSeeds);
  final off = (seed * 173) & (_kSeeds - 1);
  _begin();
  for (var j = 0; j < cnt; j++) {
    final i = (j + off) & (_kSeeds - 1);
    final s1 = _s1[i], s2 = _s2[i], s3 = _s3[i], s4 = _s4[i];
    // Most of the ash sits in the head; the tail is a thinning wisp.
    final along = s1 * s1 * len;
    final u = along / len;
    final halfW = len * 0.28 * (1 - u * 0.75) * (0.4 + 0.6 * math.sqrt(1 - u));
    final across = (s2 * 2 - 1) * halfW;
    final p = c + d * along + n * across;
    final y = c.dy + (p.dy - c.dy) * squash;
    final x = p.dx;
    final streak = 0.8 + 1.8 * s3 * (0.4 + u);
    final glint = math.sin(t * (0.7 + s4) + s3 * 6.28) > 0.97;
    final shade = glint
        ? 3
        : (u < 0.35
              ? (s4 > 0.3 ? 2 : 1)
              : (u < 0.7 ? (s4 > 0.6 ? 2 : 1) : (s4 > 0.5 ? 1 : 0)));
    final al = (1 - u * 0.7) * (0.65 + 0.35 * s2);
    _put(x - d.dx * streak, y - d.dy * streak * squash, x, y, shade, al);
  }
  _flush(canvas, ramp, alpha, width);
}

/// Smoke billowing up off a disc of radius [r] at [c] and drifting away as
/// it clears: [progress] runs 0 (thick over the disc) → 1 (gone), over
/// [duration] seconds.
///
/// It BILLOWS, it does not burst (2026-10-08): the grains are gathered in
/// seven lobes over the disc — dense at each lobe's heart, lit on its crown
/// and dim in its belly — and each lobe rises and drifts outward slowly on
/// an eased curve while it turns on itself and swells, every grain on a small
/// curl of its own. The lobes thin out grain by grain rather than all at
/// once. Speeds are a few tens of px/s, so a [trail] of ~0.016 s leaves a soft
/// grain, never a streak. [haze] is called once per lobe (centre, radius,
/// strength) so the caller can lay the soft body under it — the baked glow
/// sprite, never a blur. (The first version flung every grain radially at
/// once, and read as a hairy shock burst.)
void paintSmokeRoll(
  Canvas canvas,
  Offset c,
  double r,
  double progress,
  double t, {
  List<Color> ramp = kBillowRamp,
  int count = 512,
  double alpha = 1,
  double width = 1.7,
  double trail = 0.016,
  double duration = 1.6,
  void Function(Offset centre, double radius, double strength)? haze,
}) {
  final p = progress.clamp(0.0, 1.0);
  if (p >= 1 || alpha <= 0.02) return;
  final cnt = count.clamp(1, _kSeeds);
  if (haze != null) {
    final e = math.sin(p * math.pi / 2);
    for (var lobe = 0; lobe < _kBillowLobes; lobe++) {
      final (lx, ly, lr) = _billowLobe(lobe, e, c, r);
      // Thick at first, thinning as its grains let go.
      final k = ((0.85 - p) / 0.85).clamp(0.0, 1.0);
      haze(Offset(lx, ly), lr * 1.9, k * math.min(1.0, 0.4 + p / 0.08));
    }
  }
  _begin();
  for (var i = 0; i < cnt; i++) {
    final q = _billowAt(i, p, t, c, r);
    final q0 = _billowAt(
      i,
      math.max(0.0, p - trail / duration),
      t - trail,
      c,
      r,
    );
    final s4 = _s4[i];
    // Each grain lets go on its own beat: the billow thins, then is gone.
    final end = 0.4 + 0.6 * s4;
    final a = ((end - p) / 0.3).clamp(0.0, 1.0) * math.min(1.0, 0.4 + p / 0.08);
    // Lit from above: the crown of each lobe is the palest, its belly dim.
    final up = math.sin(_s1[i] * 2 * math.pi) * _s2[i]; // -1 crown .. 1 belly
    final shade = up < -0.45 ? 3 : (up < 0 ? 2 : (up < 0.45 ? 1 : 0));
    _put(q0.dx, q0.dy, q.dx, q.dy, shade, a * (0.75 + 0.25 * _s3[i]));
  }
  _flush(canvas, ramp, alpha, width);
}

const int _kBillowLobes = 7;

/// A billow lobe's centre and radius at eased progress [e].
(double, double, double) _billowLobe(int lobe, double e, Offset c, double r) {
  final li = (lobe * 37 + 5) & (_kSeeds - 1);
  final la = _s1[li], lb = _s2[li], lc = _s3[li];
  final angle = lobe == 0
      ? -math.pi / 2
      : (lobe - 1) / (_kBillowLobes - 1) * 2 * math.pi + 0.3 + la * 0.4;
  final dist = lobe == 0 ? r * 0.05 : r * (0.5 + 0.12 * lb);
  final out = r * 0.24 * e * (0.6 + 0.6 * lc);
  final rise = e * (24 + 28 * lb);
  final lr = r * (0.22 + 0.05 * lc) * (1 + 0.8 * e);
  return (
    c.dx + math.cos(angle) * (dist + out),
    c.dy + math.sin(angle) * (dist + out) - rise,
    lr,
  );
}

/// Where billow grain [i] is at progress [p] and time [tt].
Offset _billowAt(int i, double p, double tt, Offset c, double r) {
  final s1 = _s1[i], s2 = _s2[i], s3 = _s3[i], s4 = _s4[i];
  final lobe = (i * 3) % _kBillowLobes;
  final lc = _s3[(lobe * 37 + 5) & (_kSeeds - 1)];
  // Eased out: it leaves the glass briskly and slows as it spreads.
  final e = math.sin(p * math.pi / 2);
  final (cx, cy, lr) = _billowLobe(lobe, e, c, r);
  // The lobe turns slowly on itself; its grains crowd its heart.
  final turn = tt * 0.3 * (lc > 0.5 ? 1 : -1) + e * 0.7;
  final spread = lr * math.pow(s2, 1.3);
  final ga = s1 * 2 * math.pi + turn;
  // And every grain curls on a little loop of its own.
  final cr = 1.5 + 4 * s3 * (0.5 + e);
  final ca = tt * (1.0 + 0.8 * s4) * (s3 > 0.5 ? 1 : -1) + s4 * 6.28;
  return Offset(
    cx + math.cos(ga) * spread + math.cos(ca) * cr,
    cy + math.sin(ga) * spread * 0.85 + math.sin(ca) * cr * 0.7,
  );
}

/// Sprigs of growth standing up from [base], in grains: [blades] runs of
/// grains [spacing] apart, each [height] tall, curving and swaying on their
/// own beat — a vine's new shoots, not a drawn tuft. [ramp] runs from the
/// root's shadow to the lit tip.
void paintGrainSprigs(
  Canvas canvas,
  Offset base,
  double height,
  double t, {
  required List<Color> ramp,
  int blades = 3,
  double spacing = 9,
  int perBlade = 13,
  double sway = 3,
  double alpha = 1,
  int seed = 0,
  double width = 1.7,
}) {
  if (alpha <= 0.02) return;
  _begin();
  final off = (seed * 59) & (_kSeeds - 1);
  for (var b = 0; b < blades; b++) {
    final bi = (off + b * 17) & (_kSeeds - 1);
    final x0 = base.dx + (b - (blades - 1) / 2) * spacing + (_s1[bi] - 0.5) * 3;
    final tall = height * (0.75 + 0.45 * _s2[bi]);
    final bend = (_s3[bi] - 0.5) * height * 0.5;
    final ph = _s4[bi] * 6.28 + seed;
    final sw = math.sin(t * 1.3 + ph) * sway;
    final sw0 = math.sin((t - 0.06) * 1.3 + ph) * sway;
    for (var j = 0; j < perBlade; j++) {
      final i = (bi + j * 3 + 1) & (_kSeeds - 1);
      final u = (j + 0.5 * _s1[i]) / perBlade;
      final lean = bend * u * u;
      final jx = (_s2[i] - 0.5) * 1.6 * (1 - u);
      final x = x0 + lean + sw * u * u + jx;
      final x0p = x0 + lean + sw0 * u * u + jx;
      final y = base.dy - tall * u;
      final shade = u > 0.82 ? 3 : (u > 0.5 ? 2 : (u > 0.2 ? 1 : 0));
      _put(x0p, y + 0.4, x, y, shade, 0.7 + 0.3 * u);
    }
  }
  _flush(canvas, ramp, alpha, width);
}

/// Grains streaming along a polyline [line] (at least two points), each
/// carried from its start to its end and round again, a little to either
/// side of it — wind, or a draught of smoke, given a course. [speed] is in
/// laps per second; grains thin in and out at the ends, unless [loop] (a
/// closed course, its last point on its first) carries them round for good.
void paintGrainStream(
  Canvas canvas,
  List<Offset> line,
  double t, {
  List<Color> ramp = kWindRamp,
  int count = 60,
  double speed = 0.3,
  double jitter = 2.5,
  double alpha = 1,
  double width = 1.6,
  double trail = 0.05,
  bool loop = false,
}) {
  if (line.length < 2 || alpha <= 0.02) return;
  final segs = line.length - 1;
  final cnt = count.clamp(1, _kSeeds);
  _begin();
  for (var i = 0; i < cnt; i++) {
    final s1 = _s1[i], s2 = _s2[i], s3 = _s3[i], s4 = _s4[i];
    final sp = speed * (0.75 + 0.5 * s2);
    final u = _frac(t * sp + s1);
    var u0 = u - trail * sp;
    if (loop && u0 < 0) u0 += 1;
    final side =
        (s3 * 2 - 1) *
        jitter *
        (loop ? 1.0 : 0.4 + 0.6 * math.sin(u * math.pi));
    final f = u.clamp(0.0, 0.9999) * segs;
    final k = f.floor();
    final a = line[k], b = line[k + 1];
    final m = f - k;
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final nx = len < 1e-6 ? 0.0 : -dy / len;
    final ny = len < 1e-6 ? 0.0 : dx / len;
    final x = a.dx + dx * m + nx * side;
    final y = a.dy + dy * m + ny * side;
    var px = x, py = y;
    if (u0 >= 0) {
      final f0 = u0 * segs;
      final k0 = f0.floor();
      final a0 = line[k0], b0 = line[k0 + 1];
      final m0 = f0 - k0;
      px = a0.dx + (b0.dx - a0.dx) * m0 + nx * side;
      py = a0.dy + (b0.dy - a0.dy) * m0 + ny * side;
    }
    final edge = loop ? 1.0 : math.min(1.0, math.min(u, 1 - u) * 6);
    final shade = s4 > 0.9 ? 3 : (s4 > 0.3 ? 2 : 1);
    _put(px, py, x, y, shade, edge * (0.6 + 0.4 * s2));
  }
  _flush(canvas, ramp, alpha, width);
}
