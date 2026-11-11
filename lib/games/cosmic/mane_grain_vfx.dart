// lib/games/cosmic/mane_grain_vfx.dart
//
// MANE'S SHOTS IN GRAINS: Lava, Water and Blood in flight, and the frost an
// Ice shot trails behind its glass.
//
// Each of these was one smooth filled shape under a gradient (a boulder, a
// crescent, a teardrop shared with Mud and Poison), with a ruled crack or
// crest drawn on top. Here density makes the mass, light makes it round, it
// thins to nothing at the rim, and each has a form of its own: Lava is cells
// of melt rolling over, Water a wall with froth at its crest, Blood a clot
// with veins. They were approved as design frames first
// (test/mane_shot_design_preview_test.dart,
// docs/ability_vfx_audit/mane_designs_1111.png).
//
// What a shot leaves on the floor (Lava's dribble, Water's foam lace,
// Blood's spatter, Ice's frost) lies still on the ground. A Mane catapult
// flies straight, so the painter lays it along the path back to the launch,
// [Projectile.flown] behind it, and ages it by the shot's speed. A template
// of the track is built once and repeated along the path.
//
// Budget: under ~1,500 grains a shot in at most twelve point draws; every
// template built once; nothing allocated per frame; no blur, no shaders.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'cosmic_data.dart';

const _tau = pi * 2;

double _h(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _sm(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

// ── Grains ─────────────────────────────────────────────────────────────────

const int _tones = 12;
final List<Float32List> _buf = List.generate(_tones, (_) => Float32List(2048));
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

/// Paints what was added, tone by tone: [look] is each tone's colour and
/// its grain size in world units.
void _flush(ui.Canvas canvas, List<(ui.Color, double)> look) {
  for (var t = 0; t < _tones; t++) {
    final n = _n[t];
    if (n == 0) continue;
    _n[t] = 0;
    if (t >= look.length) continue;
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_buf[t], 0, n),
      _pt
        ..color = look[t].$1
        ..strokeWidth = look[t].$2,
    );
  }
}

// ── A shot's path ──────────────────────────────────────────────────────────

final Expando<double> _born = Expando<double>('maneShotBorn');

/// Seconds since [p] was first drawn, for things that only ease in (a pool
/// growing where it was dropped). The games pass their own running clock as
/// [time]; a clock that went back (a new run) starts it again.
double maneShotAge(Projectile p, double time) {
  final b = _born[p];
  if (b == null || time < b) {
    _born[p] = time;
    return 0;
  }
  return time - b;
}

/// Where a shot is in its flight: the way it faces, the way across it, how
/// fast it goes and how far it has come.
class _Flight {
  double dx = 1, dy = 0, v = 0, gone = 0, px = 0, py = 0;
  void set(Projectile p, ui.Offset at, double time) {
    dx = cos(p.angle);
    dy = sin(p.angle);
    v = max(1.0, Projectile.speed * p.speedMultiplier);
    gone = p.flown;
    px = at.dx;
    py = at.dy;
  }

  /// Adds a grain [along] the shot's travel and [across] it, measured from
  /// the shot.
  void local(int tone, double along, double across) =>
      _g(tone, px + dx * along - dy * across, py + dy * along + dx * across);

  /// Adds a grain on the ground [a] along the path from the launch.
  void ground(int tone, double a, double across) =>
      local(tone, a - gone, across);
}

final _f = _Flight();

/// A ground track: grains laid once over a stretch [period] long and
/// repeated down the path. [a] is each grain's place along the stretch.
class _Track {
  final double period;
  final Float32List a;
  final Float32List c;
  final Uint8List kind;
  const _Track(this.period, this.a, this.c, this.kind);
}

// ── Lava: cells of melt rolling over, a dribble cooling behind ─────────────

const int _kBallN = 1100;
final _ballX = Float32List(_kBallN);
final _ballY = Float32List(_kBallN);
final _ballU = Float32List(_kBallN);
final _ballRim = Float32List(_kBallN);
const int _kSeamU = 96, _kSeamV = 40;
final _seamTab = Float32List(_kSeamU * _kSeamV);
_Track? _dribble;

void _buildLava() {
  for (var i = 0; i < _kBallN; i++) {
    final u = sqrt(_h(i, 1));
    final a = _h(i, 2) * _tau;
    final x = u * cos(a), y = u * sin(a);
    _ballX[i] = x;
    _ballY[i] = y;
    _ballRim[i] = u;
    // Where the point sits on the turning surface: its longitude, 0 to 1
    // across the face we see.
    final band = sqrt(max(1e-6, 1 - y * y));
    _ballU[i] = asin((x / band).clamp(-1.0, 1.0)) / pi + 0.5;
  }
  // Cells all the way round (u 0..2 is a full turn): seam = how much nearer
  // the nearest seed is than the next, as an arc on the ball.
  // Few and large: at play size a seam has to be a few grains wide to read.
  const seeds = 10;
  final su = [for (var k = 0; k < seeds; k++) _h(k, 80) * 2];
  final sv = [for (var k = 0; k < seeds; k++) (_h(k, 81) * 2 - 1) * 0.95];
  for (var iu = 0; iu < _kSeamU; iu++) {
    for (var iv = 0; iv < _kSeamV; iv++) {
      final u = (iu + 0.5) / _kSeamU * 2;
      final v = (iv + 0.5) / _kSeamV * 2 - 1;
      final lat = asin(v);
      var d1 = 1e9, d2 = 1e9;
      for (var k = 0; k < seeds; k++) {
        var du = (u - su[k]).abs();
        du = min(du, 2 - du) * pi * cos(lat);
        final dv = lat - asin(sv[k]);
        final d = sqrt(du * du + dv * dv);
        if (d < d1) {
          d2 = d1;
          d1 = d;
        } else if (d < d2) {
          d2 = d;
        }
      }
      _seamTab[iu * _kSeamV + iv] = d2 - d1;
    }
  }
  // The dribble: a short band of fresh melt right behind, then drops, each
  // a little splat of grains.
  const period = 180.0;
  final a = <double>[], c = <double>[], kind = <int>[];
  for (var i = 0; i < 110; i++) {
    a.add(_h(i, 60) * period);
    c.add((_h(i, 61) * 2 - 1) * 0.22);
    kind.add(0);
  }
  for (var d = 0; d < 30; d++) {
    final at = _h(d, 62) * period;
    final across = (_h(d, 63) * 2 - 1) * 0.36;
    final spread = 1 + 2.5 * _h(d, 64);
    for (var i = 0; i < 8; i++) {
      final ang = _h(d * 8 + i, 65) * _tau;
      final r = spread * sqrt(_h(d * 8 + i, 66));
      a.add(at + r * cos(ang) * 1.3);
      // Across is stored in units of the ball's radius, with the splat's own
      // spread folded in at the decent-band ball (31).
      c.add(across + r * sin(ang) / 31);
      kind.add(1);
    }
  }
  _dribble = _Track(
    period,
    Float32List.fromList(a),
    Float32List.fromList(c),
    Uint8List.fromList(kind),
  );
}

const _lavaLook = [
  (ui.Color(0xFFFFF2B8), 2.3), // 0 white-hot seam
  (ui.Color(0xFFFFC53A), 2.3), // 1 seam
  (ui.Color(0xFFFF7A1E), 2.3), // 2 melt
  (ui.Color(0xFFC92F0E), 2.3), // 3 cooling melt
  (ui.Color(0xFF1C0B0B), 2.3), // 4 crust
  (ui.Color(0xFF8A2410), 2.3), // 5 melt turning away at the limb
  (ui.Color(0x6607060B), 2.6), // 6 shadow
  (ui.Color(0xD9FFC53A), 1.7), // 7 heat, close in
  (ui.Color(0x99E0451A), 1.7), // 8 heat, cooling
  (ui.Color(0xFFFFE9A0), 2.0), // 9 a drop, just fallen
  (ui.Color(0xFFFFA22E), 2.0), // 10 a drop, cooling
  (ui.Color(0xFFE0451A), 2.0), // 11 a drop, cooler
];

/// The Lava catapult in flight, [r] the ball's radius in world units.
void paintManeLavaShot(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double r, {
  double fade = 1,
}) {
  if (_dribble == null) _buildLava();
  final f = _f..set(p, at, time);

  // The dribble, cooling where it fell.
  final track = _dribble!;
  const life = 0.6;
  final back = r * 0.72;
  final hi = f.gone - back;
  final lo = hi - f.v * life;
  if (hi > 0) {
    for (
      var kk = (max(0.0, lo) / track.period).floor();
      kk <= (hi / track.period).floor();
      kk++
    ) {
      for (var i = 0; i < track.a.length; i++) {
        final a = kk * track.period + track.a[i];
        if (a < lo || a > hi) continue;
        final age = (hi - a) / f.v;
        if (track.kind[i] == 0 && age > 0.11) continue;
        if (age > life * 0.75 &&
            _h(i + kk * 977, 5) < (age - life * 0.75) / (life * 0.25)) {
          continue;
        }
        final s = age / life;
        f.ground(
          s < 0.1 ? 9 : (s < 0.28 ? 10 : (s < 0.55 ? 11 : (s < 0.8 ? 5 : 4))),
          a,
          track.c[i] * r,
        );
      }
    }
  }

  // Its shadow, then the ball: cells of melt turning over, the seams
  // white-hot on its leading face, dark crust riding round to its back.
  final k = r / 31;
  for (var i = 0; i < 90; i++) {
    final rho = pow(_h(i, 41), 0.6) * r;
    final a = _h(i, 42) * _tau;
    _g(6, at.dx + 4 * k + rho * cos(a), at.dy + 7 * k + rho * sin(a) * 0.8);
  }
  final roll = time * 0.42;
  final count = (900 * (k * k).clamp(0.6, 1.22)).round();
  for (var i = 0; i < count; i++) {
    final rim = _ballRim[i];
    if (rim > 0.86 && _h(i, 3) < (rim - 0.86) / 0.14) continue;
    if (fade < 1 && _h(i, 9) > fade) continue;
    final x = _ballX[i], y = _ballY[i];
    final u = (_ballU[i] + roll) % 2.0;
    final iu = min(_kSeamU - 1, (u / 2 * _kSeamU).floor());
    final iv = min(_kSeamV - 1, ((y + 1) / 2 * _kSeamV).floor());
    final seam = _seamTab[iu * _kSeamV + iv];
    int tone;
    if (seam < 0.1) {
      tone = x > -0.1 ? 0 : 1;
    } else if (seam < 0.22) {
      tone = rim > 0.8 ? 5 : 2;
    } else if (seam < 0.34) {
      tone = rim > 0.8 ? 5 : 3;
    } else {
      tone = 4;
    }
    f.local(tone, x * r, y * r);
  }
  // Heat lifting off it.
  for (var i = 0; i < 30; i++) {
    if (sin(time * 11 + i * 1.3) < 0) continue;
    final q = (time * 0.9 + _h(i, 90)) % 1.0;
    if (_h(i, 93) > 1 - q) continue;
    final a = _h(i, 91) * _tau;
    final d = r * 0.9 + 22 * k * q;
    f.local(q < 0.4 ? 7 : 8, d * cos(a) - 14 * k * q, d * sin(a) * 0.85);
  }
  _flush(canvas, _lavaLook);
}

// ── Lava pools: cells anchored to the world ───────────────────────────────

const int _kPoolN = 1600;
final _poolX = Float32List(_kPoolN);
final _poolY = Float32List(_kPoolN);
final _poolRim = Float32List(_kPoolN);
bool _poolBuilt = false;

/// The cells under one pool, worked out once a pool a frame.
const int _kPoolGrid = 20;
final _cellX = Float32List(_kPoolGrid * _kPoolGrid);
final _cellY = Float32List(_kPoolGrid * _kPoolGrid);
final _cellPulse = Float32List(_kPoolGrid * _kPoolGrid);

/// The size of a cell of crust in a Mane Lava pool, in world units.
const double _kPoolCell = 30;

const _poolLook = [
  (ui.Color(0xFFFFE9A8), 2.1), // 0 white-hot seam
  (ui.Color(0xFFFF9A2A), 2.1), // 1 melt
  (ui.Color(0xFFD2401A), 2.1), // 2 cooling melt
  (ui.Color(0xFF1A0C0A), 2.1), // 3 crust
];

/// A Mane Lava pool, [r] its reach. The cells belong to the ground, not to
/// the pool: a shot drops its pools on bodies that crowd together, and
/// pools that overlap agree on where the seams are, so they run together
/// into one field of lava instead of a heap of unrelated speckle.
void paintManeLavaPool(
  ui.Canvas canvas,
  ui.Offset at,
  double r,
  double time, {
  bool reduced = false,
  double heat = 1,
  double fade = 1,
}) {
  if (r < 6 || fade <= 0.01) return;
  if (!_poolBuilt) {
    _poolBuilt = true;
    for (var i = 0; i < _kPoolN; i++) {
      final u = sqrt(_h(i, 200));
      final a = _h(i, 202) * _tau;
      _poolX[i] = u * cos(a);
      _poolY[i] = u * sin(a) * 0.82;
      _poolRim[i] = u;
    }
  }
  // The seeds of the cells this pool covers, and how bright each cell's rim
  // is now, worked out once for the pool rather than for every grain.
  final gx0 = ((at.dx - r) / _kPoolCell).floor() - 1;
  final gy0 = ((at.dy - r * 0.82) / _kPoolCell).floor() - 1;
  final gw = min(_kPoolGrid, (2 * r / _kPoolCell).ceil() + 3);
  final gh = min(_kPoolGrid, (2 * r * 0.82 / _kPoolCell).ceil() + 3);
  for (var ix = 0; ix < gw; ix++) {
    for (var iy = 0; iy < gh; iy++) {
      final id = (gx0 + ix) * 131 + (gy0 + iy) * 977;
      final j = ix * _kPoolGrid + iy;
      _cellX[j] = (gx0 + ix + 0.15 + 0.7 * _h(id, 205)) * _kPoolCell;
      _cellY[j] = (gy0 + iy + 0.15 + 0.7 * _h(id, 206)) * _kPoolCell;
      // A whole cell's rim brightens and cools together.
      _cellPulse[j] = 0.5 + 0.5 * sin(time * 1.6 + id * 1.7);
    }
  }
  final count = min(_kPoolN, (r * r * (reduced ? 0.22 : 0.45)).round());
  for (var i = 0; i < count; i++) {
    final u = _poolRim[i];
    if (u > 0.72 && _h(i, 201) < (u - 0.72) / 0.28) continue;
    // Dissolving: each grain goes at its own point as [fade] falls.
    if (fade < 1 && _h(i, 207) > fade) continue;
    final wx = at.dx + _poolX[i] * r, wy = at.dy + _poolY[i] * r;
    final cx = (wx / _kPoolCell).floor() - gx0;
    final cy = (wy / _kPoolCell).floor() - gy0;
    var d1 = 1e18, d2 = 1e18;
    var near = 0;
    for (var ox = max(0, cx - 1); ox <= min(gw - 1, cx + 1); ox++) {
      for (var oy = max(0, cy - 1); oy <= min(gh - 1, cy + 1); oy++) {
        final j = ox * _kPoolGrid + oy;
        final dx = _cellX[j] - wx, dy = _cellY[j] - wy;
        final d = dx * dx + dy * dy;
        if (d < d1) {
          d2 = d1;
          d1 = d;
          near = j;
        } else if (d < d2) {
          d2 = d;
        }
      }
    }
    final seam = sqrt(d2) - sqrt(d1);
    final pulse = _cellPulse[near];
    // As it cools ([heat] toward 0) the seams narrow and dim to crust.
    final w = 0.35 + 0.65 * heat.clamp(0.0, 1.0);
    var tone = seam < (1.8 + 1.0 * pulse) * w
        ? 0
        : (seam < 4.6 * w ? 1 : (seam < 7.4 * w ? 2 : 3));
    if (heat < 0.5 && tone < 2) tone += 1;
    _g(tone, wx, wy);
  }
  _flush(canvas, _poolLook);
}

// ── Water: a wall with froth at its crest, foam lace behind it ─────────────

int _wallN = 0;
final _wallS = Float32List(1400);
final _wallU = Float32List(1400);
final _wallTone = Uint8List(1400);
_Track? _lace;

/// Lace: grains only along the threads where a slow noise, made to repeat
/// every [period], crosses zero.
double _laceNoise(double a, double s, double period) {
  final w = _tau / period;
  return 0.5 * sin(a * w * 3 + s * 6.5) +
      0.3 * sin(a * w * 5 - s * 9.4 + 1.7) +
      0.2 * sin(a * w * 9 + s * 16.6 + 0.4);
}

void _buildWater() {
  for (var i = 0; i < 1400 && _wallN < 1400; i++) {
    final raw = _h(i, 20) * 2 - 1;
    final s = raw.sign * pow(raw.abs(), 0.85).toDouble();
    final u = pow(_h(i, 21), 1.5).toDouble();
    final keep = (1 - _sm(0.78, 1.0, s.abs())) * (1 - _sm(0.62, 1.0, u) * 0.92);
    if (_h(i, 22) > keep) continue;
    _wallS[_wallN] = s;
    _wallU[_wallN] = u;
    _wallTone[_wallN] = u < 0.07
        ? 0
        : (u < 0.2 ? 1 : (u < 0.42 ? 2 : (u < 0.7 ? 3 : 4)));
    _wallN++;
  }
  const period = 300.0;
  final a = <double>[], c = <double>[], kind = <int>[];
  for (var j = 0; j < 90000 && a.length < 2400; j++) {
    final at = _h(j, 70) * period;
    final s = _h(j, 71) * 2 - 1;
    final v = _laceNoise(at, s, period).abs();
    if (v > 0.1) continue;
    a.add(at);
    c.add(s);
    // How near the thread's middle, in steps: fresh lace is thicker.
    kind.add((v * 100).round());
  }
  _lace = _Track(
    period,
    Float32List.fromList(a),
    Float32List.fromList(c),
    Uint8List.fromList(kind),
  );
}

const _waterLook = [
  (ui.Color(0xFFF4FCFF), 1.9), // 0 froth
  (ui.Color(0xFFA6EDFA), 2.1), // 1 lit water under the crest
  (ui.Color(0xFF3FB2DE), 2.1), // 2
  (ui.Color(0xFF16679C), 2.1), // 3
  (ui.Color(0xFF0B3A60), 2.1), // 4 deep, going to nothing
  (ui.Color(0x73A6EDFA), 1.6), // 5 rushing, behind 1
  (ui.Color(0x733FB2DE), 1.6), // 6 rushing, behind 2
  (ui.Color(0x7316679C), 1.6), // 7 rushing, behind 3
  (ui.Color(0xFFFFFFFF), 1.7), // 8 spray and breaking clumps
  (ui.Color(0xD9CFF4FC), 1.7), // 9 lace, fresh
  (ui.Color(0xCC5FC2E6), 1.7), // 10 lace
  (ui.Color(0xB32A78AA), 1.7), // 11 lace, drying
];

/// The Water catapult in flight: a wall [hh] tall each side of its path.
void paintManeWaterShot(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double hh, {
  double fade = 1,
}) {
  if (_lace == null) _buildWater();
  final f = _f..set(p, at, time);
  final k = hh / 96;
  double front(double s) => k * (14 * (1 - s * s) - 26 * pow(s.abs(), 4));
  double depth(double s) => k * (8 + 40 * sqrt(max(0.0, 1 - s * s)));

  // Foam lace on the floor behind it, drying out.
  final track = _lace!;
  const life = 0.6;
  final hi = f.gone - depth(0) * 0.55;
  final lo = hi - f.v * life;
  if (hi > 0) {
    for (
      var kk = (max(0.0, lo) / track.period).floor();
      kk <= (hi / track.period).floor();
      kk++
    ) {
      for (var i = 0; i < track.a.length; i++) {
        final a = kk * track.period + track.a[i];
        if (a < lo || a > hi) continue;
        final age = (hi - a) / f.v / life;
        if (track.kind[i] > 6 + 4 * (1 - age)) continue;
        final s = track.c[i];
        final h = _h(i + kk * 911, 72);
        if (h > pow(1 - age, 1.4)) continue;
        if (s.abs() > 0.75 && h < _sm(0.75, 1, s.abs())) continue;
        f.ground(age < 0.25 ? 9 : (age < 0.55 ? 10 : 11), a, s * hh * 0.97);
      }
    }
  }

  // The wall: froth at the front, lit water behind going deep blue and then
  // to nothing; its tips curl back; the water rushes.
  for (var i = 0; i < _wallN; i++) {
    if (fade < 1 && _h(i, 9) > fade) continue;
    final s = _wallS[i], u = _wallU[i];
    final tone = _wallTone[i];
    if (tone == 0 &&
        0.5 * sin((s * 16 + time * 2.2) * 1.7 + (u * 30 + time) * 0.9) +
                0.3 *
                    sin((s * 16 + time * 2.2) * 0.63 - (u * 30 + time) * 1.31) +
                0.2 * sin((s * 16 + time * 2.2) * 2.9 + (u * 30 + time) * 2.3) >
            0.42) {
      continue;
    }
    final x =
        front(s) - u * depth(s) + 2.5 * k * sin(time * 7 + s * 11 + u * 5);
    final y = s * hh + 2.5 * k * sin(time * 3 + u * 7 + s * 3);
    f.local(tone, x, y);
    if (tone >= 1 && tone <= 3 && u < 0.6) f.local(tone + 4, x - 3.5, y);
  }
  // Clumps breaking along the crest, rolling over forward.
  for (var c = 0; c < 11; c++) {
    final s = -0.85 + c * 0.17 + 0.05 * sin(c * 3.1);
    final phase = (time * 1.6 + _h(c, 30)) % 1.0;
    final keep = (1 - _sm(0.75, 1.0, s.abs())) * (1 - phase * 0.6) * fade;
    final bx = front(s) + 2 * k + 7 * k * phase;
    final by = s * hh;
    for (var i = 0; i < 14; i++) {
      if (_h(i + c * 31, 33) > keep) continue;
      final a = _h(i + c * 31, 31) * _tau;
      final r = k * (1.5 + 4.5 * _h(i + c * 31, 32) * sin(phase * pi));
      f.local(8, bx + r * cos(a), by + r * sin(a) * 1.3);
    }
  }
  // Spray thrown ahead of the crest.
  for (var i = 0; i < 90; i++) {
    final q = (time * 2.2 + _h(i, 50)) % 1.0;
    final s = _h(i, 51) * 1.7 - 0.85;
    if (_h(i, 53) > (1 - q) * (1 - _sm(0.7, 0.85, s.abs())) * fade) continue;
    final d = k * (8 + 26 * _h(i, 52)) * (1 - exp(-3 * q));
    f.local(8, front(s) + 3 * k + d, s * hh + s * d * 0.5);
  }
  _flush(canvas, _waterLook);
}

// ── Blood: a clot with veins, spatter behind it ────────────────────────────

const int _kClotN = 900;
final _clotX = Float32List(_kClotN);
final _clotY = Float32List(_kClotN);
final _clotTone = Uint8List(_kClotN);
_Track? _spatter;

void _buildBlood() {
  for (var i = 0; i < _kClotN; i++) {
    final ang = _h(i, 801) * _tau;
    final e = 1 + 0.1 * sin(3 * ang + 0.5) + 0.06 * sin(5 * ang);
    final u = sqrt(_h(i, 802));
    final x = e * u * cos(ang), y = e * u * sin(ang);
    _clotX[i] = x;
    _clotY[i] = y;
    if (u > 0.86 && _h(i, 803) < (u - 0.86) / 0.14) {
      _clotTone[i] = 255;
      continue;
    }
    final nz = sqrt(max(0.0, 1 - u * u));
    final s = -0.42 * u * cos(ang) - 0.58 * u * sin(ang) + 0.7 * nz - 0.25;
    // Mostly dark: at play size the veins and a wet glint carry it, and a
    // lit body read as a red puff.
    _clotTone[i] = (s > 0.66 && sin(x * 45 + y * 65) > 0.85)
        ? 0
        : (s > 0.6 ? 1 : (s > 0.25 ? 2 : (s > -0.1 ? 3 : 4)));
  }
  const period = 200.0;
  final a = <double>[], c = <double>[], kind = <int>[];
  for (var d = 0; d < 34; d++) {
    final at = _h(d, 810) * period;
    final across = (_h(d, 811) * 2 - 1) * 1.35;
    final ang = pi + (_h(d, 813) - 0.5) * 1.6;
    for (var j = 0; j < 4; j++) {
      a.add(at + cos(ang) * j * 1.5);
      // Across in units of the clot's radius at the decent band (24).
      c.add(across + sin(ang) * j * 1.5 / 24);
      kind.add(j);
    }
  }
  _spatter = _Track(
    period,
    Float32List.fromList(a),
    Float32List.fromList(c),
    Uint8List.fromList(kind),
  );
}

const _bloodLook = [
  (ui.Color(0xFFFFB3B3), 2.3), // 0 a wet glint
  (ui.Color(0xFFE02436), 2.3), // 1 lit
  (ui.Color(0xFF9A0E1E), 2.3), // 2
  (ui.Color(0xFF5A0610), 2.3), // 3
  (ui.Color(0xFF2A0306), 2.3), // 4 deep
  (ui.Color(0xFFFF5A68), 2.1), // 5 a vein, the beat in it
  (ui.Color(0xB3E8253A), 1.8), // 6 a vein between beats
  (ui.Color(0x6607060B), 2.6), // 7 shadow
  (ui.Color(0xFFE8253A), 1.8), // 8 spatter, fresh
  (ui.Color(0xFF8A0C1A), 1.7), // 9 spatter
  (ui.Color(0xFF45060C), 1.7), // 10 spatter, dried
];

/// The Blood catapult in flight, [r] the clot's radius in world units.
void paintManeBloodShot(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double r, {
  double fade = 1,
}) {
  if (_spatter == null) _buildBlood();
  final f = _f..set(p, at, time);
  final k = r / 24;

  // Spatter behind it, going dark.
  final track = _spatter!;
  const life = 0.9;
  final back = r * 0.5;
  final hi = f.gone - back;
  final lo = hi - f.v * life;
  if (hi > 0) {
    for (
      var kk = (max(0.0, lo) / track.period).floor();
      kk <= (hi / track.period).floor();
      kk++
    ) {
      for (var i = 0; i < track.a.length; i++) {
        final a = kk * track.period + track.a[i];
        if (a < lo || a > hi) continue;
        final age = (hi - a) / f.v / life;
        if (age > 0.75 && _h(i ~/ 4 + kk * 71, 814) < (age - 0.75) / 0.25) {
          continue;
        }
        f.ground(age < 0.25 ? 8 : (age < 0.6 ? 9 : 10), a, track.c[i] * r);
      }
    }
  }

  // Its shadow, the clot, and the veins with the beat running out along
  // them past its edge.
  for (var i = 0; i < 80; i++) {
    final rho = pow(_h(i, 41), 0.6) * r;
    final a = _h(i, 42) * _tau;
    _g(7, at.dx + 4 * k + rho * cos(a), at.dy + 7 * k + rho * sin(a) * 0.8);
  }
  final beat = pow(0.5 + 0.5 * sin(time * 7), 3).toDouble();
  final rr = r * (1 + 0.05 * beat);
  final count = (_kClotN * 0.75 * (k * k).clamp(0.6, 1.33)).round();
  for (var i = 0; i < count; i++) {
    final tone = _clotTone[i];
    if (tone == 255) continue;
    if (fade < 1 && _h(i, 9) > fade) continue;
    f.local(tone, _clotX[i] * rr, _clotY[i] * rr);
  }
  for (var v = 0; v < 3; v++) {
    final a0 = v * 2.1 + 0.4 + time * 0.15;
    final len = rr * (1.05 + 0.3 * _h(v, 50));
    var j = 0;
    for (var s = 0.0; s < len; s += 1.3, j++) {
      final q = s / len;
      final ang = a0 + 0.5 * sin(q * 3 + v);
      final pulse = 0.5 + 0.5 * sin(s / k * 0.3 - time * 7);
      final out = s > rr * 0.9 ? 1 - _sm(rr * 0.9, len, s) : 1.0;
      if (_h(j + v * 97, 51) > out * fade) continue;
      final x = s * cos(ang), y = s * sin(ang);
      final tone = pulse > 0.5 ? 5 : 6;
      f.local(tone, x, y);
      // Two grains across inside the clot, so a vein reads at play size.
      if (s < rr * 0.95) f.local(tone, x - sin(ang) * 1.2, y + cos(ang) * 1.2);
      if (s > rr * 0.6 && s < len * 0.85 && j % 7 == 3) {
        final ba = ang + (v.isEven ? 0.8 : -0.8);
        for (var b = 1; b < 5; b++) {
          f.local(6, x + cos(ba) * b * 1.3, y + sin(ba) * b * 1.3);
        }
      }
    }
  }
  _flush(canvas, _bloodLook);
}

// ── Ice: frost swept back off the glass, a frost track behind ──────────────

_Track? _rime;

/// Each frond's scatter, worked out once: how far along it a grain lies,
/// how far across (a share of the frond's width there) and when it goes.
const int _kFrondN = 400;
final _frondQ = Float32List(11 * _kFrondN);
final _frondW = Float32List(11 * _kFrondN);
final _frondFade = Float32List(11 * _kFrondN);

void _buildIce() {
  for (var g = 0; g < 11 * _kFrondN; g++) {
    final q = pow(_h(g, 54), 0.8).toDouble();
    _frondQ[g] = q;
    _frondW[g] = pow(1 - q, 0.8) * (_h(g, 55) * 2 - 1);
    _frondFade[g] = _h(g, 9);
  }
  const period = 160.0;
  final a = <double>[], c = <double>[], kind = <int>[];
  // Fine frost, thinning to the sides.
  for (var i = 0; i < 260; i++) {
    final side = _h(i, 17) * 2 - 1;
    a.add(_h(i, 16) * period);
    c.add(side.sign * pow(side.abs(), 1.6) * 1.2);
    kind.add(0);
  }
  // Needles lying back along the track.
  for (var n = 0; n < 12; n++) {
    final at = _h(n, 11) * period;
    final across = (_h(n, 12) * 2 - 1) * 0.9;
    final ang = (_h(n, 13) - 0.5) * 0.7;
    final len = 4 + 8 * _h(n, 15);
    for (var s = 0.0; s <= len; s += 1.4) {
      // Lying back: it points the way the shot came from.
      a.add(at - cos(ang) * s);
      c.add(across + sin(ang) * s / 21);
      kind.add(1);
    }
  }
  _rime = _Track(
    period,
    Float32List.fromList(a),
    Float32List.fromList(c),
    Uint8List.fromList(kind),
  );
}

const _iceLook = [
  (ui.Color(0xE67CC6EA), 1.9), // 0 a frond at its root
  (ui.Color(0xCCB8E4F4), 1.8), // 1 along it
  (ui.Color(0x99E6F8FF), 1.6), // 2 thinning to its tip
  (ui.Color(0x99BDE6F7), 1.4), // 3 frost, fresh
  (ui.Color(0x804F8DB4), 1.4), // 4 frost, melting
  (ui.Color(0xD9D6F3FF), 1.6), // 5 a needle on the ground
  (ui.Color(0x996FA7CC), 1.6), // 6 a needle, melting
];

/// What an Ice catapult trails behind its glass: fronds of frost swept back
/// off it by its flight and a frost track on the ground. [r] is the glass's
/// radius in world units. Paint it before the glass.
void paintManeIceFrost(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double r, {
  double fade = 1,
}) {
  if (_rime == null) _buildIce();
  final f = _f..set(p, at, time);
  final k = r / 21;

  final track = _rime!;
  const life = 1.2;
  final hi = f.gone - r * 0.5;
  final lo = hi - f.v * life;
  if (hi > 0) {
    for (
      var kk = (max(0.0, lo) / track.period).floor();
      kk <= (hi / track.period).floor();
      kk++
    ) {
      for (var i = 0; i < track.a.length; i++) {
        final a = kk * track.period + track.a[i];
        if (a < lo || a > hi) continue;
        final age = (hi - a) / f.v / life;
        final needle = track.kind[i] == 1;
        if (!needle && _h(i + kk * 613, 18) > (1 - age) * 0.9) continue;
        if (needle && age > 0.7 && _h(i + kk * 613, 19) < (age - 0.7) / 0.3) {
          continue;
        }
        final tone = needle ? (age < 0.4 ? 5 : 6) : (age < 0.4 ? 3 : 4);
        f.ground(tone, a, track.c[i] * r);
      }
    }
  }

  // Fronds: plumes of frost swept back off it, a few short ones at the
  // front. Each is grains scattered through a wedge that tapers to its tip:
  // a needle one grain wide read as a white line at play size.
  for (var n = 0; n < 11; n++) {
    final backward = n < 8;
    final ang = backward
        ? pi + (_h(n, 50) * 2 - 1) * 1.0
        : (_h(n, 50) * 2 - 1) * 1.3;
    final len =
        k *
        (backward ? 12 + 20 * _h(n, 51) : 4 + 5 * _h(n, 51)) *
        (0.92 + 0.08 * sin(time * 1.7 + n));
    final lean = ang + (backward ? (_h(n, 52) - 0.5) * 0.3 : 0);
    final ca = cos(lean), sa = sin(lean);
    final bx = cos(ang) * r * 0.7, by = sin(ang) * r * 0.7;
    final width = (backward ? 4.5 : 2.4) * k;
    final grains = min(_kFrondN, (len * width * 0.8).round());
    for (var i = 0; i < grains; i++) {
      final g = n * _kFrondN + i;
      if (fade < 1 && _frondFade[g] > fade) continue;
      final q = _frondQ[g];
      final w = width * _frondW[g];
      final s = len * q;
      f.local(
        q < 0.3 ? 0 : (q < 0.7 ? 1 : 2),
        bx + ca * s - sa * w,
        by + sa * s + ca * w,
      );
    }
  }
  _flush(canvas, _iceLook);
}

// ── Blood: what each pierced body gives, running home ──────────────────────

const _runLook = [
  (ui.Color(0xFFFF3A4A), 2.2), // 0 a drop
  (ui.Color(0xFFFFB8C0), 2.2), // 1 a drop catching the light
  (ui.Color(0xB3FF3A4A), 1.6), // 2 its tail
  (ui.Color(0x66FF3A4A), 1.5), // 3 the end of its tail
];

/// What a Mane Blood shot takes from each body it pierces, running home to
/// what the pierce heals (the orb in survival, the ship in open space, the
/// caster in a dungeon): a loose current of drops, braided in four strands,
/// each drop at its own pace, wide in the middle of the run and gathering
/// again as they arrive. Each mode keeps one, adds a run where a pierce
/// heals and paints it with where home is now.
class ManeBloodRuns {
  /// Most runs at once; the oldest makes way.
  static const int cap = 16;

  /// How long a run lasts, start to the last drop home.
  static const double span = 1.9;

  final List<ui.Offset> _from = [];
  final List<double> _at = [];

  bool get isEmpty => _from.isEmpty;

  void add(ui.Offset from, double time) {
    if (_from.length >= cap) {
      _from.removeAt(0);
      _at.removeAt(0);
    }
    _from.add(from);
    _at.add(time);
  }

  void clear() {
    _from.clear();
    _at.clear();
  }

  void paint(ui.Canvas canvas, ui.Offset home, double time) {
    while (_at.isNotEmpty && (time - _at.first > span || time < _at.first)) {
      _from.removeAt(0);
      _at.removeAt(0);
    }
    for (var r = 0; r < _from.length; r++) {
      final p0 = _from[r];
      final dx = home.dx - p0.dx, dy = home.dy - p0.dy;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 12) continue;
      // Bowed to one side, the side and depth its own.
      final seed = (_at[r] * 997).floor();
      final bow =
          (_h(seed, 820) < 0.5 ? -1 : 1) * dist * (0.18 + 0.14 * _h(seed, 821));
      final cx = (p0.dx + home.dx) / 2 - dy / dist * bow;
      final cy = (p0.dy + home.dy) / 2 + dx / dist * bow;
      // Home is reached at its edge, not its middle.
      final ex = home.dx - dx / dist * 10, ey = home.dy - dy / dist * 10;
      for (var i = 0; i < 48; i++) {
        final strand = i % 4;
        final dur = 0.8 + 0.6 * _h(i + seed, 822);
        final age = time - (_at[r] + _h(i + seed, 823) * 0.5);
        if (age < 0 || age > dur) continue;
        final lin = age / dur;
        final p = lin * lin * (3 - 2 * lin);
        if (_h(i + seed, 826) < _sm(0.88, 1.0, p)) continue;
        for (var j = 0; j < 3; j++) {
          final q = max(0.0, p - j * 0.012);
          final u = 1 - q;
          final x = u * u * p0.dx + 2 * u * q * cx + q * q * ex;
          final y = u * u * p0.dy + 2 * u * q * cy + q * q * ey;
          // Across the run: the strand's own sway, plus each drop's.
          final tx = 2 * u * (cx - p0.dx) + 2 * q * (ex - cx);
          final ty = 2 * u * (cy - p0.dy) + 2 * q * (ey - cy);
          final tl = max(1e-6, sqrt(tx * tx + ty * ty));
          final lateral =
              sin(q * pi) *
              (9 * sin(strand * 1.7 + q * 5 + time * 1.5) +
                  4 * (_h(i + seed, 824) - 0.5));
          _g(
            j == 0 ? (strand == 1 ? 1 : 0) : (j == 1 ? 2 : 3),
            x - ty / tl * lateral,
            y + tx / tl * lateral,
          );
        }
      }
    }
    _flush(canvas, _runLook);
  }
}

// ── Mud: a wet clod with folds in it, splats behind ────────────────────────

const int _kClodN = 800;
final _clodX = Float32List(_kClodN);
final _clodY = Float32List(_kClodN);
final _clodShade = Float32List(_kClodN);
final _clodKeep = Uint8List(_kClodN);
_Track? _splats;

void _buildMud() {
  for (var i = 0; i < _kClodN; i++) {
    final ang = _h(i, 901) * _tau;
    final e =
        1 +
        0.16 * sin(3 * ang + 1.1) +
        0.1 * sin(5 * ang + 0.3) +
        0.06 * sin(7 * ang);
    final u = sqrt(_h(i, 902));
    final x = e * u * cos(ang), y = e * u * sin(ang);
    _clodX[i] = x;
    _clodY[i] = y;
    _clodKeep[i] = (u > 0.84 && _h(i, 903) < (u - 0.84) / 0.16) ? 0 : 1;
    final nz = sqrt(max(0.0, 1 - u * u));
    _clodShade[i] =
        -0.42 * u * cos(ang) - 0.58 * u * sin(ang) + 0.7 * nz - 0.25;
  }
  const period = 220.0;
  final a = <double>[], c = <double>[], kind = <int>[];
  for (var d = 0; d < 16; d++) {
    final at = _h(d, 910) * period;
    final across = (_h(d, 911) * 2 - 1) * 0.9;
    final size = 1.5 + 3 * _h(d, 912);
    for (var i = 0; i < 9; i++) {
      final ang = _h(d * 9 + i, 913) * _tau;
      final r = size * sqrt(_h(d * 9 + i, 914));
      a.add(at + r * cos(ang) * 1.4);
      c.add(across + r * sin(ang) / 26);
      // One wet glint in each splat.
      kind.add(i == 0 ? 1 : 0);
    }
  }
  _splats = _Track(
    period,
    Float32List.fromList(a),
    Float32List.fromList(c),
    Uint8List.fromList(kind),
  );
}

const _mudLook = [
  (ui.Color(0xFF140D08), 2.4), // 0 deep, near black
  (ui.Color(0xFF2A1D12), 2.4), // 1
  (ui.Color(0xFF5C432A), 2.4), // 2
  (ui.Color(0xFF8A6A44), 2.3), // 3 a fold catching the light
  (ui.Color(0xFFE8D6B0), 2.0), // 4 a wet glint
  (ui.Color(0x6607060B), 2.6), // 5 shadow
  (ui.Color(0xFF3A2A1A), 2.1), // 6 a splat
  (ui.Color(0xFF1E140C), 2.1), // 7 a splat, drying
  (ui.Color(0xCCD9C29A), 1.8), // 8 a splat's wet glint
];

/// The Mud catapult (and the ten clods it breaks into), [r] its radius.
void paintManeMudShot(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double r, {
  double fade = 1,
}) {
  if (_splats == null) _buildMud();
  final f = _f..set(p, at, time);
  final k = r / 26;

  final track = _splats!;
  const life = 1.1;
  final hi = f.gone - r * 0.6;
  final lo = hi - f.v * life;
  if (hi > 0) {
    for (
      var kk = (max(0.0, lo) / track.period).floor();
      kk <= (hi / track.period).floor();
      kk++
    ) {
      for (var i = 0; i < track.a.length; i++) {
        final a = kk * track.period + track.a[i];
        if (a < lo || a > hi) continue;
        final age = (hi - a) / f.v / life;
        if (age > 0.7 && _h(i ~/ 9 + kk * 53, 915) < (age - 0.7) / 0.3) {
          continue;
        }
        f.ground(
          track.kind[i] == 1 && age < 0.5 ? 8 : (age < 0.5 ? 6 : 7),
          a,
          track.c[i] * r,
        );
      }
    }
  }

  for (var i = 0; i < 70; i++) {
    final rho = pow(_h(i, 41), 0.6) * r;
    final a = _h(i, 42) * _tau;
    _g(5, at.dx + 4 * k + rho * cos(a), at.dy + 7 * k + rho * sin(a) * 0.8);
  }
  // It wobbles as it flies, and its folds roll round it.
  final sq = sin(time * 5 + p.angle * 3);
  final ax = 1 + 0.08 * sq, ay = 1 - 0.07 * sq;
  final count = (_kClodN * (k * k).clamp(0.5, 1.0)).round();
  for (var i = 0; i < count; i++) {
    if (_clodKeep[i] == 0) continue;
    if (fade < 1 && _h(i, 9) > fade) continue;
    final x = _clodX[i], y = _clodY[i];
    final dx = x + 0.3, dy = y + 0.2;
    final fold = sin(sqrt(dx * dx + dy * dy) * 13 - time * 1.4);
    final s = _clodShade[i];
    int tone;
    if (s > 0.55 && sin(x * 41 + y * 57) > 0.82) {
      tone = 4;
    } else if (fold > 0.55 && s > -0.1) {
      tone = 3;
    } else {
      tone = s > 0.3 ? 2 : (s > -0.15 ? 1 : 0);
    }
    f.local(tone, x * r * ax, y * r * ay);
  }
  // Globs flung off its back.
  for (var g = 0; g < 6; g++) {
    final q = (time * 1.3 + _h(g, 920)) % 1.0;
    final side = g.isEven ? 1.0 : -1.0;
    final bx = -r * (0.7 + 1.1 * q);
    final by = side * r * (0.35 + 0.5 * q * _h(g, 921));
    for (var i = 0; i < 6; i++) {
      if (_h(i + g * 6, 922) < q * 0.8) continue;
      final a = _h(i + g * 6, 923) * _tau;
      final d = 2.2 * k * sqrt(_h(i + g * 6, 924));
      f.local(i == 0 ? 3 : 1, bx + d * cos(a), by + d * sin(a));
    }
  }
  _flush(canvas, _mudLook);
}

// ── Poison: a cluster of bubbles, drips behind ─────────────────────────────

const _poisonLook = [
  (ui.Color(0xFF0E120A), 2.2), // 0 a bubble's dark heart
  (ui.Color(0xFF2E3A12), 2.2), // 1
  (ui.Color(0xFF4A5A1E), 2.2), // 2
  (ui.Color(0xFF9DB53A), 2.1), // 3 a bubble's lit rim
  (ui.Color(0xFFE2F07A), 2.0), // 4 its glint
  (ui.Color(0x80D6E86A), 1.5), // 5 haze
  (ui.Color(0xD99DB53A), 1.9), // 6 a drip, fresh
  (ui.Color(0x994A5A1E), 1.8), // 7 a drip, soaking in
];

_Track? _drips;

void _buildPoison() {
  const period = 180.0;
  final a = <double>[], c = <double>[], kind = <int>[];
  for (var d = 0; d < 22; d++) {
    final at = _h(d, 930) * period;
    final across = (_h(d, 931) * 2 - 1) * 0.8;
    for (var i = 0; i < 4; i++) {
      final ang = _h(d * 4 + i, 932) * _tau;
      final r = 1.6 * sqrt(_h(d * 4 + i, 933));
      a.add(at + r * cos(ang));
      c.add(across + r * sin(ang) / 26);
      kind.add(0);
    }
  }
  _drips = _Track(
    period,
    Float32List.fromList(a),
    Float32List.fromList(c),
    Uint8List.fromList(kind),
  );
}

/// The Poison catapult: a cluster of bubbles that swell and burst, a haze
/// round it and drips behind. [r] is its radius.
void paintManePoisonShot(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double r, {
  double fade = 1,
}) {
  if (_drips == null) _buildPoison();
  final f = _f..set(p, at, time);
  final k = r / 26;

  final track = _drips!;
  const life = 0.9;
  final hi = f.gone - r * 0.6;
  final lo = hi - f.v * life;
  if (hi > 0) {
    for (
      var kk = (max(0.0, lo) / track.period).floor();
      kk <= (hi / track.period).floor();
      kk++
    ) {
      for (var i = 0; i < track.a.length; i++) {
        final a = kk * track.period + track.a[i];
        if (a < lo || a > hi) continue;
        final age = (hi - a) / f.v / life;
        if (age > 0.6 && _h(i ~/ 4 + kk * 37, 934) < (age - 0.6) / 0.4) {
          continue;
        }
        f.ground(age < 0.35 ? 6 : 7, a, track.c[i] * r);
      }
    }
  }

  // The glob: a lump of it, dark olive, acid where the light catches it.
  if (_splats == null) _buildMud();
  final count = (_kClodN * 0.85 * (k * k).clamp(0.5, 1.0)).round();
  final wob = sin(time * 4 + p.angle * 3);
  for (var i = 0; i < count; i++) {
    if (_clodKeep[i] == 0) continue;
    if (fade < 1 && _h(i, 9) > fade) continue;
    final x = _clodX[i], y = _clodY[i];
    final sh = _clodShade[i];
    final tone = sh > 0.6 && sin(x * 37 + y * 53) > 0.85
        ? 4
        : (sh > 0.52 ? 3 : (sh > 0.15 ? 2 : (sh > -0.2 ? 1 : 0)));
    f.local(tone, x * r * (1 + 0.05 * wob), y * r * (1 - 0.05 * wob));
  }
  // Bubbles swelling on its skin and bursting, another welling up in each
  // one's place: a dark pit with a lit rim on the side the light comes from.
  for (var b = 0; b < 4; b++) {
    final beat = time * (0.6 + 0.25 * _h(b, 940)) + _h(b, 941);
    final q = beat % 1.0;
    final round = beat.floor();
    final ca = b * _tau / 4 + (_h(b * 31 + round, 942) - 0.5) * 1.2;
    final cr = r * (0.3 + 0.35 * _h(b * 31 + round, 943));
    final cx = cr * cos(ca), cy = cr * sin(ca);
    final br = r * (0.22 + 0.12 * _h(b, 944)) * (0.5 + 0.5 * _sm(0, 0.85, q));
    final bursting = q > 0.88;
    for (var i = 0; i < 60; i++) {
      if (fade < 1 && _h(i + b * 61, 9) > fade) continue;
      final u = sqrt(_h(i + b * 61, 945));
      final a = _h(i + b * 61, 946) * _tau;
      if (bursting) {
        if (_h(i + b * 61, 947) > 0.35) continue;
        final d = br * (1 + 3 * (q - 0.88) / 0.12) * u;
        f.local(4, cx + d * cos(a), cy + d * sin(a));
        continue;
      }
      final lx = u * cos(a), ly = u * sin(a);
      final light = -0.55 * lx - 0.8 * ly;
      final tone = u > 0.72 ? (light > 0.1 ? 4 : 2) : 0;
      f.local(tone, cx + lx * br, cy + ly * br);
    }
  }
  // A haze round it, streaming off behind.
  for (var i = 0; i < 70; i++) {
    final q = (time * 0.8 + _h(i, 950)) % 1.0;
    if (_h(i, 951) > (1 - q) * fade) continue;
    final a = _h(i, 952) * _tau;
    final d = r * (0.8 + 0.6 * q);
    f.local(5, d * cos(a) - r * 1.2 * q * k, d * sin(a) * 0.8);
  }
  _flush(canvas, _poisonLook);
}

// ── Air: a bow wave of wind, curling at its ends ───────────────────────────

const _airLook = [
  (ui.Color(0xFFE9F6F4), 2.0), // 0 the front
  (ui.Color(0xCCE9F6F4), 1.8), // 1
  (ui.Color(0x998FB3B0), 1.6), // 2 thinning behind
  (ui.Color(0xFFCFE8D0), 1.9), // 3 a curl
];

/// The Air catapult: a bow wave of wind streaks [w] each side of its path,
/// swept back, each end curling over. It moves at twice a catapult's speed,
/// so it is mostly speed.
void paintManeAirShot(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double w, {
  double fade = 1,
}) {
  final f = _f..set(p, at, time);
  final k = w / 32;
  for (var i = 0; i < 90; i++) {
    if (fade < 1 && _h(i, 9) > fade) continue;
    final s = _h(i, 960) * 2 - 1;
    final front = k * (12 * (1 - s * s) - 4);
    final depth = _h(i, 961);
    final x0 = front - depth * k * 26 * (1 - 0.4 * s * s);
    final y = s * w + 1.5 * k * sin(time * 9 + i);
    // A streak: a short run along the travel, fading back.
    final len = 3 + (5 * _h(i, 962)).floor();
    for (var j = 0; j < len; j++) {
      final tone = depth < 0.25 && j == 0 ? 0 : (j < len ~/ 2 ? 1 : 2);
      f.local(tone, x0 - j * 2.6 * k, y);
    }
  }
  // Each end curls over, turning.
  for (final side in const [-1.0, 1.0]) {
    for (var i = 0; i < 34; i++) {
      if (fade < 1 && _h(i, 9) > fade) continue;
      final q = i / 34;
      final ang = q * 2.6 * pi + time * 7 * side;
      final rr = k * 7 * (1 - q * 0.8);
      f.local(
        q < 0.4 ? 3 : 1,
        k * (-8 - 6 * q) + rr * cos(ang),
        side * (w + rr * sin(ang) * 0.8),
      );
    }
  }
  _flush(canvas, _airLook);
}

// ── Spirit: a wisp, its tail curling behind it ─────────────────────────────

const _spiritLook = [
  (ui.Color(0xFFF4F8FF), 2.2), // 0 its heart
  (ui.Color(0xFFCFE4FF), 2.0), // 1
  (ui.Color(0xCC8FB4E8), 1.8), // 2 its tail
  (ui.Color(0x998E6AE0), 1.6), // 3 its tail, going violet and out
];

/// The Spirit catapult (each shot of its stream): a wisp, a bright heart
/// with a tail that curls behind it. [r] is the heart's radius.
void paintManeSpiritShot(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double r, {
  double fade = 1,
}) {
  final f = _f..set(p, at, time);
  final ph = time * 6 + p.angle * 5 + (p.flown * 0.01);
  for (var i = 0; i < 70; i++) {
    if (fade < 1 && _h(i, 9) > fade) continue;
    final u = pow(_h(i, 970), 0.7).toDouble();
    final a = _h(i, 971) * _tau;
    f.local(u < 0.45 ? 0 : 1, u * r * cos(a), u * r * sin(a) * 0.85);
  }
  final len = r * 6;
  for (var i = 0; i < 140; i++) {
    final q = _h(i, 972);
    if (_h(i, 973) < q * 0.6 || (fade < 1 && _h(i, 9) > fade)) continue;
    final x = -q * len;
    final y =
        r * 1.4 * q * sin(q * 6 - ph) + (_h(i, 974) - 0.5) * r * 1.2 * (1 - q);
    f.local(q < 0.3 ? 1 : (q < 0.65 ? 2 : 3), x, y);
  }
  _flush(canvas, _spiritLook);
}

// ── Steam: a roiling ball of it, puffs left behind ─────────────────────────

const _steamLook = [
  (ui.Color(0xFF3A4648), 2.3), // 0 shadowed steam
  (ui.Color(0xFF7F9094), 2.3), // 1
  (ui.Color(0xFFCBD8DA), 2.2), // 2
  (ui.Color(0xFFF2FBFB), 2.1), // 3 lit
  (ui.Color(0xFFFFF1DC), 2.0), // 4 its hot heart
  (ui.Color(0x99CBD8DA), 1.9), // 5 a puff, thinning
];

/// The Steam catapult: a ball of steam roiling, billows turning over it,
/// a hot heart, puffs spreading behind. [r] is its radius.
void paintManeSteamShot(
  ui.Canvas canvas,
  Projectile p,
  ui.Offset at,
  double time,
  double r, {
  double fade = 1,
}) {
  final f = _f..set(p, at, time);
  // Puffs it leaves, spreading and thinning as they fall behind.
  for (var b = 0; b < 4; b++) {
    final q = (time * 1.1 + b / 4) % 1.0;
    final px = -r * (0.7 + 1.8 * q), py = (b.isEven ? 1 : -1) * r * 0.3 * q;
    final pr = r * (0.4 + 0.5 * q);
    for (var i = 0; i < 40; i++) {
      if (_h(i + b * 41, 980) > (1 - q) * fade) continue;
      final u = sqrt(_h(i + b * 41, 981));
      final a = _h(i + b * 41, 982) * _tau;
      f.local(5, px + u * pr * cos(a), py + u * pr * sin(a));
    }
  }
  // Billows turning over the ball, each lit on its upper side.
  for (var b = 0; b < 6; b++) {
    final a0 = b * 1.047 + time * (0.9 + 0.2 * _h(b, 983));
    final cr = b == 0 ? 0.0 : r * 0.45;
    final cx = cr * cos(a0), cy = cr * sin(a0) * 0.8;
    final br = r * (b == 0 ? 0.62 : 0.42 + 0.1 * sin(time * 2 + b));
    final n = (br * br * 0.8).round().clamp(10, 300);
    for (var i = 0; i < n; i++) {
      if (fade < 1 && _h(i + b * 307, 9) > fade) continue;
      final u = sqrt(_h(i + b * 307, 984));
      if (u > 0.82 && _h(i + b * 307, 985) < (u - 0.82) / 0.18) continue;
      final a = _h(i + b * 307, 986) * _tau;
      final lx = u * cos(a), ly = u * sin(a);
      final light = -0.5 * lx - 0.85 * ly + 0.3 * sqrt(max(0.0, 1 - u * u));
      final tone = b == 0 && u < 0.3
          ? 4
          : (light > 0.55 ? 3 : (light > 0.15 ? 2 : (light > -0.3 ? 1 : 0)));
      f.local(tone, cx + lx * br, cy + ly * br);
    }
  }
  _flush(canvas, _steamLook);
}
