// lib/games/cosmic/element_ground_art.dart
//
// WHAT AN ELEMENT LEAVES ON THE GROUND, WITH NO OUTLINE.
//
// Every ground effect used to be a rounded patch with things drawn on it,
// and the patch is what the eye read: a blob, whatever was on top. Here
// nothing has an edge. Each element is grains whose density, direction and
// light make the shape, thinning to nothing at the rim, and each has a form
// of its own, so they are told apart by shape before colour:
//
//   Fire tongues · Lava cells · Water rings · Ice needles · Plant leaves ·
//   Lightning branches · Steam vents · Earth a spring among stones ·
//   Mud folds · Dust ripples · Crystal shards · Air a turning gust ·
//   Poison banks · Spirit wisps · Dark a hole · Light rays · Blood veins
//
// Dark is the one exception: it is the shared void (drawVfxVoid in
// vfx_shapes.dart), a dark hole in a violet haze with wisps falling in. In
// grains it came out a black disc with a bright rim, and the user judged
// that worse than the void.
//
// The designs were approved as frames first
// (test/element_ground_design_preview_test.dart); these are the same forms
// at a play-size budget: a few hundred grains an effect, in at most eight
// point draws, no blur, no shaders, nothing allocated per frame.
//
// Drawn round the origin: the caller translates to the effect.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'vfx_shapes.dart';

const _ink = ui.Color(0xFF07060B);
const _white = ui.Color(0xFFFFF6E4);
const _tau = pi * 2;

double _h(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

const int _tones = 8;
final List<Float32List> _buf = List.generate(_tones, (_) => Float32List(1024));
final List<int> _n = List.filled(_tones, 0);
final ui.Paint _pt = ui.Paint()
  ..strokeCap = ui.StrokeCap.round
  ..style = ui.PaintingStyle.stroke;

void _g(int tone, double x, double y) {
  var b = _buf[tone];
  final i = _n[tone];
  if (i + 2 > b.length) {
    _buf[tone] = b = Float32List(b.length * 2)..setAll(0, b);
  }
  b[i] = x;
  b[i + 1] = y;
  _n[tone] = i + 2;
}

/// Paints what was added, tone by tone: [look] is each tone's colour and its
/// size as a multiple of [grain].
void _flush(ui.Canvas canvas, double grain, List<(ui.Color, double)> look) {
  for (var t = 0; t < look.length; t++) {
    final n = _n[t];
    if (n == 0) continue;
    _n[t] = 0;
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_buf[t], 0, n),
      _pt
        ..color = look[t].$1
        ..strokeWidth = grain * look[t].$2,
    );
  }
}

/// A scatter of [tone] densest in the middle and gone by [r]: the ground
/// under an effect, with no edge to it.
void _bed(int tone, double r, int n, int salt, {double squash = 0.8}) {
  if (!_withBed) return;
  if (!_bedBuilt) _buildBed();
  // One layout for every bed, turned and entered at a place of its own
  // [salt]'s: the same look for a fraction of the work per grain.
  final ca = cos(salt * 0.37), sa = sin(salt * 0.37);
  var j = (salt * 131) % _kBedN;
  for (var i = 0; i < n; i++, j = (j + 1) % _kBedN) {
    final x = _bedX[j] * r, y = _bedY[j] * r;
    _g(tone, x * ca - y * sa, (x * sa + y * ca) * squash);
  }
}

const int _kBedN = 4096;
final Float32List _bedX = Float32List(_kBedN);
final Float32List _bedY = Float32List(_kBedN);
bool _bedBuilt = false;

void _buildBed() {
  _bedBuilt = true;
  for (var i = 0; i < _kBedN; i++) {
    final rho = pow(_h(i, 1), 0.62).toDouble();
    final a = _h(i, 2) * _tau;
    _bedX[i] = rho * cos(a);
    _bedY[i] = rho * sin(a);
  }
}

/// The elements this file draws.
const kElementGrounds = {
  'Fire', 'Lava', 'Water', 'Ice', 'Plant', 'Lightning', 'Steam', 'Earth',
  'Mud', 'Dust', 'Crystal', 'Air', 'Poison', 'Spirit', 'Dark', 'Light',
  'Blood', //
};

/// Paints [element]'s ground effect round the origin, out to [r]. [seed] is
/// any number that stays the same for one effect, so no two look alike.
/// [mends] is for ground that heals what stands on it (Earth shows its
/// spring). [bed] false leaves out the dark scatter under it, for a field
/// wide enough to lie over the orb, where it reads as dirt on the glass.
/// False for an element it has no form for.
bool paintElementGround(
  ui.Canvas canvas,
  String element,
  double r,
  double time,
  double seed, {
  bool reduced = false,
  bool mends = false,
  bool bed = true,
}) {
  if (r < 6 || !kElementGrounds.contains(element)) return false;
  _mends = mends;
  _withBed = bed;
  // Things that stand up off the ground (a flame, a plume, a shard) keep a
  // sensible height however wide the effect is; a wide one has more of
  // them instead.
  final k = min(r / 120, 0.62);
  // Up to the size of a Wing's field (r ~300): past r ~140 the caps used to
  // hold, and a big field thinned to a scatter of dots.
  _many = pow(max(1.0, r / 75), 1.6).clamp(1.0, 5.0).toDouble();
  _fq = reduced ? 0.55 : 1.0;
  final grain = (r * 0.03).clamp(1.7, 3.0);
  // Grains by the area they have to cover: a large effect at a small one's
  // count is a scatter of dots, and its form is lost.
  final q = (reduced ? 0.55 : 1.0) * pow(r / 55, 1.5).clamp(0.6, 12.0);
  final sd = (seed * 17).floor() & 511;
  final t = time + (sd % 37) * 0.31;
  int n(num v) => (v * q).round();
  switch (element) {
    case 'Fire':
      _fire(canvas, r, k, grain, t, sd, n);
    case 'Lava':
      _lava(canvas, r, grain, t, sd, n);
    case 'Water':
      _water(canvas, r, grain, t, sd, n);
    case 'Ice':
      _ice(canvas, r, grain, t, sd, reduced);
    case 'Plant':
      _plant(canvas, r, k, grain, t, sd, n);
    case 'Lightning':
      _lightning(canvas, r, grain, t, sd, n);
    case 'Steam':
      _steam(canvas, r, k, grain, t, sd, n);
    case 'Earth':
      _earth(canvas, r, k, grain, t, sd, n);
    case 'Mud':
      _mud(canvas, r, grain, t, sd, n);
    case 'Dust':
      _dust(canvas, r, grain, t, sd, n);
    case 'Crystal':
      _crystal(canvas, r, k, grain, t, sd, n);
    case 'Air':
      _air(canvas, r, grain, t, sd, n);
    case 'Poison':
      _poison(canvas, r, k, grain, t, sd, n);
    case 'Spirit':
      _spirit(canvas, r, k, grain, t, sd, n);
    case 'Dark':
      // The void: a dark hole in a violet haze, wisps falling in over its
      // lip. Grains made it a black disc with a bright rim, which the user
      // judged worse twice (Dark Mane, then Horn's leftover).
      drawVfxVoid(canvas, ui.Offset.zero, vfxMaterial('Dark'), r * 0.6, seed, time);
    case 'Light':
      _light(canvas, r, grain, t, sd, n);
    case 'Blood':
      _blood(canvas, r, grain, t, sd, n);
  }
  return true;
}

typedef _N = int Function(num v);

// Set for the effect being painted: how many more standing things a wide
// effect has, and the share of grains each keeps at reduced quality.
double _many = 1, _fq = 1;
bool _withBed = true;
bool _mends = false;
int _count(int base) => (base * _many).round();
int _nf(num v) => (v * _fq).round();

// Fire: tongues of grains climbing off a scatter of char and embers.
// What Fire's embers and flames need of each grain, worked out once.
const int _kEmberN = 1024;
final Float32List _emberX = Float32List(_kEmberN);
final Float32List _emberY = Float32List(_kEmberN);
final Float32List _emberRate = Float32List(_kEmberN);
const int _kTongues = 32, _kTongueGrains = 64;
final Float32List _tongueStart = Float32List(_kTongues * _kTongueGrains);
final Float32List _tongueAcross = Float32List(_kTongues * _kTongueGrains);
final Float32List _tongueThin = Float32List(_kTongueGrains);
// sin(pi * s^0.55) * (1 - 0.55 s) at 256 steps of s.
final Float32List _flameWidth = Float32List(256);
bool _fireBuilt = false;

void _buildFire() {
  _fireBuilt = true;
  for (var i = 0; i < _kEmberN; i++) {
    final rho = pow(_h(i, 12), 0.8) * 0.86;
    final a = _h(i, 13) * _tau;
    _emberX[i] = rho * cos(a);
    _emberY[i] = rho * sin(a);
    _emberRate[i] = 4 + 3 * _h(i, 11);
  }
  for (var j = 0; j < _kTongues; j++) {
    for (var i = 0; i < _kTongueGrains; i++) {
      _tongueStart[j * _kTongueGrains + i] = _h(i + j * 331, 23);
      _tongueAcross[j * _kTongueGrains + i] = _h(i + j * 331, 25) * 2 - 1;
    }
  }
  for (var i = 0; i < _kTongueGrains; i++) {
    _tongueThin[i] = _h(i, 26);
  }
  for (var i = 0; i < 256; i++) {
    final s = (i + 0.5) / 256;
    _flameWidth[i] = sin(pi * pow(s, 0.55)) * (1 - 0.55 * s);
  }
}

void _fire(
  ui.Canvas c,
  double r,
  double k,
  double grain,
  double t,
  int sd,
  _N n,
) {
  if (!_fireBuilt) _buildFire();
  _bed(0, r, n(120), sd);
  // Embers through the char, each on its own clock: their places and
  // clocks come from a table, turned by the effect's seed.
  final ca = cos(sd * 0.53), sa = sin(sd * 0.53);
  final embers = min(n(70), _kEmberN);
  for (var i = 0; i < embers; i++) {
    final glow = sin(t * _emberRate[i] + i * 1.9);
    if (glow < -0.2) continue;
    final x = _emberX[i] * r, y = _emberY[i] * r;
    _g(
      glow > 0.6 ? 3 : (glow > 0.1 ? 2 : 1),
      x * ca - y * sa,
      (x * sa + y * ca) * 0.8,
    );
  }
  for (var j = 0; j < _count(6); j++) {
    final a = j * 2.399 + 0.4 + sd;
    final rho = r * 0.58 * sqrt((j + 0.5) / _count(6));
    final bx = rho * cos(a), by = rho * sin(a) * 0.8;
    // Short and broad, and each at its own tilt: a tall thin upright
    // flame, repeated across a field, reads as streaks of rain (it did, at
    // 40-66 tall by 17-25 wide, all straight up).
    final tall = (28 + 18 * _h(j, 21 + sd)) * k;
    final wide = (21 + 9 * _h(j, 22 + sd)) * k;
    final tilt = (_h(j, 27 + sd) - 0.5) * 0.7;
    final ct = cos(tilt), st = sin(tilt);
    final rate = 0.55 + 0.3 * _h(j, 24);
    final sway1 = 12 * sin(t * 2.3 + j * 1.7) * k;
    final sway2 = 6 * sin(t * 5 + j) * k;
    final row = (j % _kTongues) * _kTongueGrains;
    for (var i = 0; i < min(_nf(56), _kTongueGrains); i++) {
      final s = (_tongueStart[row + i] + t * rate) % 1.0;
      // The flame's width up its height, looked up rather than worked out.
      final half = wide * _flameWidth[(s * 255).floor()];
      final across = _tongueAcross[row + i];
      final lean = sway1 * s * s + sway2 * s;
      final core = across.abs() < 0.45;
      if (s > 0.85 && _tongueThin[i] < (s - 0.85) / 0.15) continue;
      final lx = across * half + lean, ly = -s * tall;
      _g(
        s < 0.22 && core ? 4 : (s < 0.5 ? (core ? 3 : 2) : (s < 0.8 ? 2 : 1)),
        bx + lx * ct - ly * st,
        by + lx * st + ly * ct,
      );
    }
  }
  for (var i = 0; i < n(10); i++) {
    final s = (_h(i, 31 + sd) + t * 0.3) % 1.0;
    _g(2, (_h(i, 32 + sd) - 0.5) * r * 1.5, (-60 - s * 110) * k);
  }
  _flush(c, grain, const [
    (ui.Color(0xFF0B0809), 1.15),
    (ui.Color(0xFFC2371A), 0.9),
    (ui.Color(0xFFFF8A2E), 1.0),
    (ui.Color(0xFFFFC24A), 1.05),
    (ui.Color(0xFFFFF1C2), 1.1),
  ]);
}

// Lava: plates of crust with molten seams between them. The plates are laid
// out once (which grain is crust, edge or seam never changes); each pool
// turns the layout its own way, and the seams breathe.
const int _kLavaN = 1200;
final Float32List _lavaX = Float32List(_kLavaN);
final Float32List _lavaY = Float32List(_kLavaN);
final Float32List _lavaSeam = Float32List(_kLavaN);
bool _lavaBuilt = false;
// A small pool's layout: fewer, larger cells, so at a small size the cells
// still read instead of breaking into speckle.
final Float32List _lavaSmallX = Float32List(_kLavaN);
final Float32List _lavaSmallY = Float32List(_kLavaN);
final Float32List _lavaSmallSeam = Float32List(_kLavaN);
bool _lavaSmallBuilt = false;

void _buildLava({bool small = false}) {
  if (small) {
    _lavaSmallBuilt = true;
  } else {
    _lavaBuilt = true;
  }
  final xs = small ? _lavaSmallX : _lavaX;
  final ys = small ? _lavaSmallY : _lavaY;
  final seams = small ? _lavaSmallSeam : _lavaSeam;
  final cells = small ? 7 : 11;
  final sx = <double>[], sy = <double>[];
  for (var j = 0; j < cells; j++) {
    final rho = 0.8 * sqrt((j + 0.5) / cells);
    sx.add(rho * cos(j * 2.399));
    sy.add(rho * sin(j * 2.399));
  }
  for (var i = 0; i < _kLavaN; i++) {
    final rho = pow(_h(i, 41), 0.58).toDouble();
    final a = _h(i, 42) * _tau;
    final x = rho * cos(a), y = rho * sin(a);
    var d1 = 1e9, d2 = 1e9;
    for (var j = 0; j < sx.length; j++) {
      final d = sqrt((sx[j] - x) * (sx[j] - x) + (sy[j] - y) * (sy[j] - y));
      if (d < d1) {
        d2 = d1;
        d1 = d;
      } else if (d < d2) {
        d2 = d;
      }
    }
    xs[i] = x;
    ys[i] = y;
    seams[i] = d2 - d1;
  }
}

void _lava(ui.Canvas c, double r, double grain, double t, int sd, _N n) {
  final small = r < 70;
  if (small ? !_lavaSmallBuilt : !_lavaBuilt) _buildLava(small: small);
  final xs = small ? _lavaSmallX : _lavaX;
  final ys = small ? _lavaSmallY : _lavaY;
  final seams = small ? _lavaSmallSeam : _lavaSeam;
  final ca = cos(sd * 0.7), sa = sin(sd * 0.7);
  // By area, but never so few that a small pool is speckle: a pool r 50
  // had ~450 grains of 1.7 and its cells did not read.
  final count = min(max(n(520), (r * r * 0.3 * _fq).round()), _kLavaN);
  if (small) grain = max(grain, 2.0);
  for (var i = 0; i < count; i++) {
    final x = xs[i], y = ys[i];
    final rim = sqrt(x * x + y * y);
    // Cooled and scattering at the rim.
    if (rim > 0.78 && _h(i, 43) < (rim - 0.78) / 0.22) continue;
    final pulse = 0.5 + 0.5 * sin(t * 1.4 + i * 0.37);
    final seam = seams[i];
    _g(
      seam < 0.045 + 0.025 * pulse
          ? 3
          : (seam < 0.1 + 0.03 * pulse ? 2 : (seam < 0.18 ? 1 : 0)),
      (x * ca - y * sa) * r,
      (x * sa + y * ca) * r * 0.82,
    );
  }
  // Gas welling up through it in spreading clumps, and heat lifting off.
  for (var j = 0; j < n(4); j++) {
    final clock = t * 0.5 + _h(j, 51 + sd) * 3;
    final s = clock % 1.0;
    if (s > 0.8) continue;
    final beat = clock.floor();
    final a = _h(j * 7 + beat, 52) * _tau;
    final rho = r * 0.5 * sqrt(_h(j * 7 + beat, 53));
    for (var i = 0; i < 7; i++) {
      final d = r * 0.12 * s * sqrt((i + 0.5) / 7);
      _g(
        3,
        rho * cos(a) + d * cos(i * 2.399),
        rho * sin(a) * 0.82 + d * sin(i * 2.399) * 0.8 - r * 0.06 * s,
      );
    }
  }
  for (var i = 0; i < n(14); i++) {
    final s = (_h(i, 54 + sd) + t * 0.2) % 1.0;
    _g(4, (_h(i, 55 + sd) - 0.5) * r * 1.5, -s * r);
  }
  _flush(c, grain, const [
    (ui.Color(0xFF1A0C0A), 1.25),
    (ui.Color(0xFFD2401A), 1.0),
    (ui.Color(0xFFFF9A2A), 1.0),
    (ui.Color(0xFFFFE9A8), 1.1),
    (ui.Color(0x99FF8A3A), 0.75),
  ]);
}

// Water: rings going out from the middle, a lit crest and a dark trough.
void _water(ui.Canvas c, double r, double grain, double t, int sd, _N n) {
  _bed(0, r, n(170), sd);
  for (var ring = 0; ring < 4; ring++) {
    final s = (ring / 4 + t * 0.16) % 1.0;
    final rr = r * (0.08 + 0.9 * s);
    // Dense enough that a small pool's rings read as rings, not a few dots.
    final count = (rr * 2.4).clamp(16, 220).round();
    for (var i = 0; i < count; i++) {
      // Broken in runs, so a ring is water and not a row of dots.
      if (_h((i ~/ 6) + ring * 97, 61 + sd) < 0.12 + 0.4 * s) continue;
      final a = i / count * _tau;
      final light = cos(a - pi * 1.25);
      final wob = r * 0.02 * sin(a * 5 + ring + t);
      final ca = cos(a), sa = sin(a) * 0.8;
      if (s < 0.75 || _h(i, 62) > (s - 0.75) / 0.25) {
        _g(
          light > 0.3 ? 4 : (light > -0.3 ? 3 : 2),
          (rr + wob) * ca,
          (rr + wob) * sa,
        );
      }
      _g(1, (rr - r * 0.05 + wob) * ca, (rr - r * 0.05 + wob) * sa);
    }
  }
  for (var i = 0; i < n(36); i++) {
    if (sin(t * (2 + 2 * _h(i, 63 + sd)) + i * 2.3) < 0.5) continue;
    final rho = pow(_h(i, 64 + sd), 0.7) * r * 0.85;
    final a = _h(i, 65 + sd) * _tau;
    _g(4, rho * cos(a), rho * sin(a) * 0.8);
  }
  _flush(c, max(grain, 2.1), const [
    (ui.Color(0xFF0F3F66), 1.2),
    (ui.Color(0xFF06182A), 1.2),
    (ui.Color(0xFF1F5F8E), 1.0),
    (ui.Color(0xFF5FB6E8), 1.05),
    (ui.Color(0xFFCFF2FF), 1.15),
  ]);
}

// Ice: frost in straight needles, six ways, each throwing smaller ones.
void _iceNeedle(
  double x,
  double y,
  double a,
  double len,
  int depth,
  double step,
  int maxDepth,
) {
  final count = (len / step).round();
  final ca = cos(a), sa = sin(a) * 0.86;
  final lit = cos(a - pi * 1.25) > 0;
  for (var i = 0; i < count; i++) {
    final s = i / count;
    final px = x + ca * len * s, py = y + sa * len * s;
    _g(s > 0.9 ? 4 : (lit ? 3 : 2), px, py);
    if (depth == 0) _g(0, px + step * 0.8, py + step * 0.8);
  }
  if (depth >= maxDepth) return;
  final twigs = depth == 0 ? 5 : 2;
  for (var j = 1; j <= twigs; j++) {
    final s = j / (twigs + 1);
    final l = len * (0.42 - 0.26 * s);
    final px = x + ca * len * s, py = y + sa * len * s;
    _iceNeedle(px, py, a + pi / 3, l, depth + 1, step, maxDepth);
    _iceNeedle(px, py, a - pi / 3, l, depth + 1, step, maxDepth);
  }
}

void _ice(ui.Canvas c, double r, double grain, double t, int sd, bool reduced) {
  _bed(1, r, reduced ? 40 : 80, sd);
  final grow = 0.86 + 0.14 * sin(t * 0.8);
  final step = grain * (reduced ? 1.9 : 1.45);
  for (var j = 0; j < 6; j++) {
    _iceNeedle(
      0,
      0,
      j * pi / 3 + 0.26 + sd,
      r * 0.92 * grow,
      0,
      step,
      reduced ? 1 : 2,
    );
  }
  for (var i = 0; i < 24; i++) {
    if (sin(t * (1.5 + 2 * _h(i, 72 + sd)) + i * 1.7) < 0.7) continue;
    final rho = pow(_h(i, 73 + sd), 0.7) * r * 0.9;
    final a = (_h(i, 74 + sd) * 6).floor() * pi / 3 + 0.26 + sd;
    _g(5, rho * cos(a), rho * sin(a) * 0.86);
  }
  _flush(c, grain, const [
    (ui.Color(0xFF0B1F2C), 0.9),
    (ui.Color(0x809AD6EA), 0.9),
    (ui.Color(0xFF6DB7D8), 0.95),
    (ui.Color(0xFFD8F6FF), 1.0),
    (_white, 1.1),
    (_white, 1.5),
  ]);
}

// Plant: a rosette of leaves, lit on one side of the midrib, with tendrils.
void _plant(
  ui.Canvas c,
  double r,
  double k,
  double grain,
  double t,
  int sd,
  _N n,
) {
  _bed(0, r * 0.9, n(110), sd);
  for (var ring = 0; ring < 2; ring++) {
    final count = ring == 0 ? 7 : 5;
    for (var j = 0; j < count; j++) {
      final a = j * _tau / count + ring * 0.45 + sd + 0.05 * sin(t * 0.9 + j);
      final len = ring == 0 ? r * 0.92 : r * 0.56;
      final wide = (ring == 0 ? 20.0 : 15.0) * k;
      final ca = cos(a), sa = sin(a);
      for (var i = 0; i < n(ring == 0 ? 34 : 22); i++) {
        final id = i + j * 211 + ring * 5000;
        final s = _h(id, 81), across = _h(id, 82) * 2 - 1;
        final half = wide * sin(pi * pow(s, 0.7));
        final curl = 10 * k * s * s * sin(t * 0.7 + j);
        final along = len * (0.08 + 0.92 * s);
        final x = ca * along - sa * (across * half + curl);
        final y = sa * along + ca * (across * half + curl);
        _g(
          across.abs() < 0.12
              ? 0
              : (across * (ca - sa) < 0 ? (_h(id, 83) > 0.6 ? 3 : 2) : 1),
          x,
          y * 0.86,
        );
      }
    }
  }
  for (var j = 0; j < 4; j++) {
    for (var i = 0; i <= 16; i++) {
      final s = i / 16;
      final a =
          j * _tau / 4 +
          0.6 +
          sd +
          0.95 * s * s +
          0.25 * sin(t * 1.3 + j + s * 4);
      final rr = r * (0.3 + 0.75 * s);
      _g(i == 16 ? 4 : (s < 0.6 ? 2 : 3), rr * cos(a), rr * sin(a) * 0.86);
    }
  }
  _flush(c, grain, const [
    (ui.Color(0xFF0D2012), 1.15),
    (ui.Color(0xFF2E7A3A), 1.0),
    (ui.Color(0xFF7FD46A), 1.0),
    (ui.Color(0xFFD9F7A8), 1.0),
    (ui.Color(0xFFE6FFC2), 1.7),
  ]);
}

// Lightning: bolts walking out from the strike, forking, with charged air.
void _bolt(
  double x,
  double y,
  double a,
  double len,
  int depth,
  int id,
  double step,
  double t,
) {
  var px = x, py = y, dir = a;
  final steps = (len / step).round();
  final live = sin(t * 9 + id * 2.1) > -0.35;
  for (var i = 0; i < steps; i++) {
    dir += (_h(id * 53 + i, 91) - 0.5) * 1.3;
    dir += (a - dir) * 0.35;
    final qx = px + cos(dir) * step, qy = py + sin(dir) * step * 0.86;
    for (var j = 0; j < 2; j++) {
      final mx = px + (qx - px) * j / 2, my = py + (qy - py) * j / 2;
      if (live) _g(depth == 0 ? 3 : 2, mx, my);
      _g(
        1,
        mx + (_h(id * 53 + i * 4 + j, 92) - 0.5) * step * 1.3,
        my + (_h(id * 53 + i * 4 + j, 93) - 0.5) * step * 1.3,
      );
    }
    if (depth < 1 && _h(id * 53 + i, 94) < 0.3) {
      _bolt(
        qx,
        qy,
        dir + (i.isEven ? 0.8 : -0.8),
        len * 0.42,
        1,
        id * 13 + i,
        step,
        t,
      );
    }
    px = qx;
    py = qy;
  }
  if (live) _g(4, px, py);
}

void _lightning(ui.Canvas c, double r, double grain, double t, int sd, _N n) {
  _bed(0, r * 0.8, n(90), sd);
  for (var j = 0; j < n(6); j++) {
    _bolt(
      0,
      0,
      j * _tau / 6 + 0.3 + sd,
      r * 0.9,
      0,
      j + 1 + sd,
      grain * 3.2,
      t,
    );
  }
  _g(4, 0, 0);
  _flush(c, grain, const [
    (ui.Color(0xFF0A0A14), 1.2),
    (ui.Color(0xB38E7BFF), 0.9),
    (ui.Color(0xFFF4F0FF), 1.0),
    (ui.Color(0xFFF4F0FF), 1.3),
    (_white, 2.0),
  ]);
}

// Steam: vents in the floor, each breathing out a plume that billows.
void _steam(
  ui.Canvas c,
  double r,
  double k,
  double grain,
  double t,
  int sd,
  _N n,
) {
  // A light bed: where many of these overlap, a heavy dark scatter read
  // as soot.
  _bed(0, r, n(45), sd);
  for (var j = 0; j < _count(4); j++) {
    final a = j * 2.399 + 1.1 + sd;
    final rho = r * 0.6 * sqrt((j + 0.5) / _count(4));
    final vx = rho * cos(a), vy = rho * sin(a) * 0.8;
    // The vent: a dark mouth with its lip lit on the side toward the
    // light only (a full ring of grains read as a hoop).
    for (var i = 0; i < 12; i++) {
      final b = pi * 1.25 + (i / 11 - 0.5) * 2.2;
      _g(3, vx + 11 * k * cos(b), vy + 7 * k * sin(b));
    }
    for (var i = 0; i < 14; i++) {
      final rr = 9 * k * sqrt((i + 0.5) / 14);
      _g(0, vx + rr * cos(i * 2.399), vy + rr * 0.64 * sin(i * 2.399));
    }
    final puff = 0.5 + 0.5 * sin(t * 1.6 + j * 1.3);
    for (var i = 0; i < _nf(46); i++) {
      final id = i + j * 400;
      final s = (_h(id, 203) + t * (0.3 + 0.12 * _h(j, 204))) % 1.0;
      if (s > 0.6 && _h(id, 207) < (s - 0.6) / 0.4) continue;
      final wide = (5 + 34 * pow(s, 0.8)) * k;
      final roll = sin(s * 9 + _h(id, 205) * _tau + t);
      _g(
        s < 0.25 ? 4 : (roll > 0.2 ? 3 : 2),
        vx + (_h(id, 206) * 2 - 1) * wide + 9 * k * roll * s,
        vy - (16 + 96 * s) * k * (0.8 + 0.3 * puff),
      );
    }
  }
  _flush(c, grain, const [
    (_ink, 1.2),
    (ui.Color(0xFF3A4648), 1.0),
    (ui.Color(0xFF7F9094), 1.1),
    (ui.Color(0xFFCBD8DA), 1.1),
    (ui.Color(0xFFF2FBFB), 0.95),
  ]);
}

// Earth: standing stones. Where the ground mends (a Mask's healing pool)
// they ring a spring of green-gold light; anywhere else they are broken
// ground, stones thrown up all across it.
void _earth(
  ui.Canvas c,
  double r,
  double k,
  double grain,
  double t,
  int sd,
  _N n,
) {
  _bed(0, r, n(70), sd);
  for (var i = 0; i < (_mends ? n(130) : 0); i++) {
    final s = (_h(i, 211 + sd) + t * 0.16) % 1.0;
    if (s > 0.6 && _h(i, 210) < (s - 0.6) / 0.4) continue;
    final a = _h(i, 212 + sd) * _tau + 0.4 * s;
    final rr = r * 0.62 * pow(s, 0.8);
    _g(
      s < 0.2 ? 7 : (sin(s * 12 - t * 2) > 0.3 ? 6 : 5),
      rr * cos(a),
      rr * sin(a) * 0.8 - 6 * k * (1 - s),
    );
  }
  final stones = _mends ? 6 : _count(9);
  for (var j = 0; j < stones; j++) {
    final a = _mends ? j * _tau / 6 + 0.3 + sd : j * 2.399 + sd;
    final out = _mends ? 0.78 : 0.8 * sqrt((j + 0.5) / stones);
    final sx = r * out * cos(a), sy = r * out * 0.8 * sin(a);
    final w = (13 + 7 * _h(j, 213 + sd)) * k,
        h = (20 + 16 * _h(j, 214 + sd)) * k;
    final tilt = (_h(j, 215 + sd) - 0.5) * 0.5;
    for (var i = 0; i < 7; i++) {
      _g(
        1,
        sx + (0.3 + _h(i + j * 90, 216)) * w,
        sy + (0.1 + _h(i + j * 90, 217)) * 6 * k,
      );
    }
    for (var i = 0; i < _nf(34); i++) {
      final u = _h(i + j * 300, 218) * 2 - 1, v = _h(i + j * 300, 219);
      _g(
        v > 0.9 ? 4 : (u < -0.1 ? 3 : 2),
        sx + u * w * (1 - 0.45 * v) + tilt * v * h,
        sy - v * h,
      );
    }
  }
  _flush(c, grain, const [
    (ui.Color(0xFF0E120C), 1.2),
    (_ink, 1.2),
    (ui.Color(0xFF4A4234), 1.1),
    (ui.Color(0xFFB8A888), 1.1),
    (ui.Color(0xFFE6DCC0), 1.1),
    (ui.Color(0xFF5FA860), 0.95),
    (ui.Color(0xFFC8F0A0), 1.05),
    (ui.Color(0xFFFFF4C2), 1.1),
  ]);
}

// Mud: wet earth in thick folds, with bubbles doming up through it.
// A disc of grains laid out once, with what Mud and Dust need of each grain
// worked out ahead: its place (rim distance, angle), the fixed part of
// Mud's folds and of Dust's ripples, and its two thinning draws. They used
// a pow, four or five sines and three hashes per grain per frame.
const int _kDiscN = 4096;
final Float32List _discRim = Float32List(_kDiscN);
final Float32List _discCos = Float32List(_kDiscN);
final Float32List _discSin = Float32List(_kDiscN);
final Float32List _discThin = Float32List(_kDiscN);
final Float32List _discThin2 = Float32List(_kDiscN);
final Float32List _discLit = Float32List(_kDiscN);
final Float32List _discS2 = Float32List(_kDiscN);
final Float32List _discC2 = Float32List(_kDiscN);
final Float32List _discMudFold = Float32List(_kDiscN);
final Float32List _discDustWarp = Float32List(_kDiscN);
bool _discBuilt = false;

void _buildDisc() {
  _discBuilt = true;
  for (var i = 0; i < _kDiscN; i++) {
    final rim = pow(_h(i, 231), 0.6).toDouble();
    final a = _h(i, 232) * _tau;
    _discRim[i] = rim;
    _discCos[i] = cos(a);
    _discSin[i] = sin(a);
    _discThin[i] = _h(i, 233);
    _discThin2[i] = _h(i, 246);
    _discLit[i] = cos(a - pi * 1.25);
    _discS2[i] = sin(a * 2);
    _discC2[i] = cos(a * 2);
    _discMudFold[i] = rim * 20 + 0.8 * sin(a * 5);
    _discDustWarp[i] = 0.9 * sin(rim * sin(a) * 0.8 * 4.8);
  }
}

void _mud(ui.Canvas c, double r, double grain, double t, int sd, _N n) {
  if (!_discBuilt) _buildDisc();
  // The folds' fixed part comes from the disc's table; the effect's own
  // twist (its seed) is one sine and cosine for all of it.
  final cs = cos(0.6 + sd), ss = sin(0.6 + sd);
  final count = min(n(520), _kDiscN);
  for (var i = 0; i < count; i++) {
    final rim = _discRim[i];
    if (rim > 0.8 && _discThin[i] < (rim - 0.8) / 0.2) continue;
    final fold = sin(
      _discMudFold[i] + 1.7 * (_discS2[i] * cs + _discC2[i] * ss) - t * 0.4,
    );
    _g(
      fold > 0.82 && _discLit[i] > 0
          ? 3
          : (fold > 0.35 ? 2 : (fold > -0.35 ? 1 : 0)),
      rim * r * _discCos[i],
      rim * r * _discSin[i] * 0.8,
    );
  }
  for (var j = 0; j < n(4); j++) {
    final clock = t * 0.35 + _h(j, 234 + sd) * 5;
    final s = clock % 1.0;
    if (s > 0.9) continue;
    final beat = clock.floor();
    final a = _h(j * 7 + beat, 235) * _tau;
    final rho = r * 0.65 * sqrt(_h(j * 7 + beat, 236));
    final dome = r * (0.035 + 0.075 * sin(s * pi * 0.9));
    for (var i = 0; i < 12; i++) {
      final rr = dome * sqrt((i + 0.5) / 12);
      final b = i * 2.399;
      _g(
        cos(b - pi * 1.25) > 0.3 && i > 4 ? 4 : 2,
        rho * cos(a) + rr * cos(b),
        rho * sin(a) * 0.8 + rr * sin(b) * 0.8 - dome * 0.3,
      );
    }
  }
  _flush(c, grain, const [
    (ui.Color(0xFF2A1D12), 1.2),
    (ui.Color(0xFF5C432A), 1.15),
    (ui.Color(0xFF8A6A44), 1.1),
    (ui.Color(0xFFD9C29A), 1.05),
    (ui.Color(0xFFE8D6B0), 1.1),
  ]);
}

// Dust: sand in wind ripples, and sand carried across in low runs.
void _dust(ui.Canvas c, double r, double grain, double t, int sd, _N n) {
  if (!_discBuilt) _buildDisc();
  final wx = cos(sd * 0.9), wy = sin(sd * 0.9);
  final count = min(n(700), _kDiscN);
  for (var i = 0; i < count; i++) {
    final rim = _discRim[i];
    if (rim > 0.7 && _discThin[i] < (rim - 0.7) / 0.3) continue;
    final x = rim * _discCos[i], y = rim * _discSin[i] * 0.8;
    final wave = sin((x * wx + y * wy) * 13 + _discDustWarp[i] - t * 0.5);
    // The ripples are told by where the grains lie: the troughs mostly bare,
    // the crests bright. In four close browns over an even cover they read
    // as a speckle at play size.
    if (wave < -0.1 && _discThin2[i] < 0.92) continue;
    _g(wave > 0.55 ? 3 : (wave > 0.2 ? 2 : (wave > -0.1 ? 1 : 0)), x * r, y * r);
  }
  for (var i = 0; i < n(12); i++) {
    final s = (_h(i, 244 + sd) + t * 0.5) % 1.0;
    final across = (_h(i, 245 + sd) - 0.5) * r * 1.5;
    final along = -r * 1.2 + s * r * 2.4;
    for (var j = 0; j < 4; j++) {
      if (sin(s * pi) < 0.3) continue;
      final al = along - j * grain * 2.6;
      _g(
        j == 0 ? 3 : 2,
        al * wx - across * wy,
        (al * wy + across * wx) * 0.8 - r * 0.1,
      );
    }
  }
  _flush(c, grain, const [
    (ui.Color(0xFF4A3922), 1.15),
    (ui.Color(0xFF8E7148), 1.1),
    (ui.Color(0xFFC9A873), 1.05),
    (ui.Color(0xFFF2DDB0), 1.05),
  ]);
}

// Crystal: shards standing out of the floor, two facets on a bright ridge.
void _crystal(
  ui.Canvas c,
  double r,
  double k,
  double grain,
  double t,
  int sd,
  _N n,
) {
  _bed(0, r, n(70), sd);
  for (var jj = 0; jj < _count(8); jj++) {
    final j = jj;
    final a = j * 2.399 + sd;
    final rho = r * 0.6 * sqrt((j + 0.5) / _count(8));
    final bx = rho * cos(a), by = rho * sin(a) * 0.8;
    final tall = (46 + 50 * _h(j, 251 + sd)) * k;
    final wide = (9 + 8 * _h(j, 252 + sd)) * k;
    final lean = cos(a) * 0.45;
    for (var i = 0; i < _nf(40); i++) {
      final v = _h(i + j * 300, 253), u = _h(i + j * 300, 254) * 2 - 1;
      final half = wide * (v < 0.3 ? 0.55 + 1.5 * v : (1 - v) / 0.7);
      _g(
        u.abs() < 0.1 ? 5 : (u < 0 ? (v > 0.5 ? 4 : 3) : (v > 0.5 ? 2 : 1)),
        bx + u * half + lean * v * tall,
        by - v * tall,
      );
    }
    if (sin(t * 2.2 + j * 1.9) > 0.3) _g(6, bx + lean * tall, by - tall);
  }
  _flush(c, grain, const [
    (ui.Color(0xFF0D0B16), 1.2),
    (ui.Color(0xFF3A2C70), 1.1),
    (ui.Color(0xFF6A56B0), 1.1),
    (ui.Color(0xFF9E86E8), 1.1),
    (ui.Color(0xFFD8CCFF), 1.1),
    (ui.Color(0xFFF2ECFF), 1.0),
    (_white, 1.9),
  ]);
}

// Air: no body of its own, only what it carries, swept round an empty eye.
void _air(ui.Canvas c, double r, double grain, double t, int sd, _N n) {
  for (var arm = 0; arm < 4; arm++) {
    for (var i = 0; i < n(62); i++) {
      final id = i + arm * 600;
      final s = _h(id, 261);
      if (s > 0.6 && _h(id, 265) < (s - 0.6) / 0.5) continue;
      final a = arm * _tau / 4 + sd + s * 4.2 - t * (1.6 - 0.9 * s);
      final rr = r * (0.14 + 0.86 * s) + (_h(id, 262) - 0.5) * r * 0.13 * s;
      _g(
        cos(a - pi * 1.25) > 0.2 ? (s < 0.4 ? 2 : 1) : 0,
        rr * cos(a),
        rr * sin(a) * 0.8,
      );
    }
  }
  for (var i = 0; i < n(8); i++) {
    final s = 0.3 + 0.7 * _h(i, 263 + sd);
    final a = _h(i, 264 + sd) * _tau - t * (1.4 - 0.8 * s);
    for (var j = 0; j < 3; j++) {
      _g(
        3,
        r * s * cos(a + j * 0.06),
        r * s * sin(a + j * 0.06) * 0.8 - r * 0.05,
      );
    }
  }
  _flush(c, grain, const [
    (ui.Color(0xB38FB3B0), 0.95),
    (ui.Color(0xCCE9F6F4), 0.95),
    (ui.Color(0xFFE9F6F4), 1.15),
    (ui.Color(0xFFCFE8D0), 1.2),
  ]);
}

// Poison: banks of it lying low, sickly bright on top, dark underneath.
void _poison(
  ui.Canvas c,
  double r,
  double k,
  double grain,
  double t,
  int sd,
  _N n,
) {
  _bed(0, r, n(80), sd);
  for (var j = 0; j < _count(9); j++) {
    final a = j * 2.399 + 0.5 + sd;
    final rho = r * 0.7 * sqrt((j + 0.5) / _count(9));
    final bx = rho * cos(a) + 6 * k * sin(t * 0.5 + j);
    final by = rho * sin(a) * 0.8;
    final big =
        (20 + 14 * _h(j, 271 + sd)) * k * (0.9 + 0.12 * sin(t * 0.9 + j * 2));
    for (var i = 0; i < _nf(34); i++) {
      final rr = big * sqrt(_h(i + j * 300, 272));
      final b = _h(i + j * 300, 273) * _tau;
      final y = rr * sin(b) * 0.62;
      final top = -y / (big * 0.62);
      _g(
        top > 0.45 ? 3 : (top > -0.1 ? 2 : 1),
        bx + rr * cos(b),
        by + y - 6 * k,
      );
    }
  }
  for (var i = 0; i < n(10); i++) {
    final s = (_h(i, 274 + sd) + t * 0.22) % 1.0;
    if (s > 0.8) continue;
    final x = (_h(i, 275 + sd) - 0.5) * r * 1.4 + 7 * k * sin(t * 1.2 + i);
    for (var j = 0; j < 4; j++) {
      _g(
        4,
        x + 3.5 * k * cos(j * _tau / 4),
        -r * (0.07 + 0.66 * s) + 3.5 * k * sin(j * _tau / 4),
      );
    }
  }
  _flush(c, grain, const [
    (ui.Color(0xFF0E120A), 1.2),
    (ui.Color(0xFF4A5A1E), 1.1),
    (ui.Color(0xFF9DB53A), 1.1),
    (ui.Color(0xFFE2F07A), 1.1),
    (ui.Color(0xCCD6E86A), 0.8),
  ]);
}

// Spirit: wisps risen from the floor, a bright head on a winding tail.
void _spirit(
  ui.Canvas c,
  double r,
  double k,
  double grain,
  double t,
  int sd,
  _N n,
) {
  _bed(0, r, n(70), sd);
  for (var j = 0; j < _count(5); j++) {
    final a = j * 2.399 + 0.2 + sd;
    final rho = r * 0.6 * sqrt((j + 0.5) / _count(5));
    final bx = rho * cos(a), by = rho * sin(a) * 0.8;
    final tall = (54 + 34 * _h(j, 281 + sd) + 8 * sin(t * 1.3 + j)) * k;
    for (var i = 0; i < _nf(46); i++) {
      final s = _h(i + j * 300, 282);
      if (s < 0.3 && _h(i, 287) > s / 0.3) continue;
      final sway = 14 * k * sin(s * 5 - t * 2 + j) * (1 - s * 0.4);
      final head = s > 0.78;
      final rel = ((s - 0.89) / 0.11).clamp(-1.0, 1.0);
      final half = head ? 9 * k * sqrt(1 - rel * rel) : (1.5 + 5 * s) * k;
      final u = _h(i + j * 300, 283) * 2 - 1;
      _g(
        head ? (u.abs() < 0.4 ? 3 : 2) : 1,
        bx + sway + u * half,
        by - s * tall,
      );
    }
  }
  for (var i = 0; i < n(14); i++) {
    final s = (_h(i, 284 + sd) + t * 0.18) % 1.0;
    if (sin(s * pi) < 0.4) continue;
    _g(
      2,
      (_h(i, 285 + sd) - 0.5) * r * 1.5,
      (_h(i, 286 + sd) - 0.5) * r * 0.3 - s * r * 0.6,
    );
  }
  _flush(c, grain, const [
    (ui.Color(0xFF0B0E16), 1.2),
    (ui.Color(0xCC8FB4E8), 0.9),
    (ui.Color(0xFFCFE4FF), 1.1),
    (_white, 1.15),
  ]);
}

// Light: rays of unequal length going out from one point, slowly turning.
void _light(ui.Canvas c, double r, double grain, double t, int sd, _N n) {
  for (var j = 0; j < 11; j++) {
    final a = j * _tau / 11 + sd + t * 0.12 + 0.2 * sin(j * 3.1);
    final long =
        r * (0.55 + 0.45 * _h(j, 301 + sd)) * (0.9 + 0.1 * sin(t * 1.7 + j));
    final wide = 0.07 + 0.05 * _h(j, 302 + sd);
    for (var i = 0; i < n(30); i++) {
      final s = pow(_h(i + j * 300, 303), 0.8).toDouble();
      if (s > 0.55 && _h(i, 307) < (s - 0.55) / 0.5) continue;
      final off = (_h(i + j * 300, 304) * 2 - 1) * wide * (1 - 0.6 * s);
      final rr = r * 0.11 + long * s;
      _g(
        off.abs() < wide * 0.3 && s < 0.6 ? 2 : (s < 0.5 ? 1 : 0),
        rr * cos(a + off),
        rr * sin(a + off) * 0.86,
      );
    }
  }
  for (var i = 0; i < n(20); i++) {
    final s = (_h(i, 305 + sd) + t * 0.2) % 1.0;
    if (sin(s * pi) < 0.4) continue;
    final a = _h(i, 306 + sd) * _tau;
    _g(2, r * s * cos(a), r * s * sin(a) * 0.86);
  }
  _g(3, 0, 0);
  _flush(c, grain, const [
    (ui.Color(0xFFE8B95A), 0.95),
    (ui.Color(0xFFFFE9A8), 1.05),
    (_white, 1.1),
    (_white, 5.0),
  ]);
}

// Blood: a deep pool with veins running out from it, a pulse going down
// each.
void _vein(
  double x,
  double y,
  double a,
  double len,
  int depth,
  int id,
  double step,
  double t,
) {
  var px = x, py = y, dir = a;
  final steps = (len / step).round();
  for (var i = 0; i < steps; i++) {
    dir += (_h(id * 61 + i, 313) - 0.5) * 0.5;
    dir += (a - dir) * 0.2;
    px += cos(dir) * step;
    py += sin(dir) * step * 0.8;
    final s = i / steps;
    final pulse = ((s - t * 0.5 + id * 0.13) % 1.0) < 0.14;
    _g(pulse ? 4 : (depth == 0 && s < 0.6 ? 3 : 2), px, py);
    if (depth < 1 && _h(id * 61 + i, 314) < 0.16) {
      _vein(
        px,
        py,
        dir + (i.isEven ? 0.7 : -0.7),
        len * 0.5,
        1,
        id * 17 + i,
        step,
        t,
      );
    }
  }
}

void _blood(ui.Canvas c, double r, double grain, double t, int sd, _N n) {
  _bed(0, r, n(60), sd);
  final beat = 0.5 + 0.5 * sin(t * 2.4);
  final pool = r * (0.4 + 0.03 * beat);
  for (var i = 0; i < n(190); i++) {
    final rho = pow(_h(i, 311 + sd), 0.6) * pool;
    final a = _h(i, 312 + sd) * _tau;
    final x = rho * cos(a), y = rho * sin(a) * 0.78;
    final dx = x + r * 0.12, dy = y + r * 0.1;
    _g(
      dx * dx + dy * dy < r * r * 0.005 ? 5 : ((x + y) / pool < -0.2 ? 3 : 1),
      x,
      y,
    );
  }
  for (var j = 0; j < n(6); j++) {
    final a = j * _tau / 6 + 0.4 + sd;
    _vein(
      cos(a) * r * 0.36,
      sin(a) * r * 0.36 * 0.78,
      a,
      r * 0.62,
      0,
      j + 1 + sd,
      grain * 1.5,
      t,
    );
  }
  _flush(c, grain, const [
    (ui.Color(0xFF12080A), 1.2),
    (ui.Color(0xFF5A0A12), 1.2),
    (ui.Color(0xFFA81624), 0.95),
    (ui.Color(0xFFC21E2E), 1.15),
    (ui.Color(0xFFFF8A8A), 1.3),
    (ui.Color(0xFFFFC2C2), 1.1),
  ]);
}
