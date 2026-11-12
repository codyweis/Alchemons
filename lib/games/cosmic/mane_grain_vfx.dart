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

/// Makes room in [tone] for [count] more grains, so a loop can [_put] them
/// with no check per grain ([_put] is [_g] without its check).
void _room(int tone, int count) {
  final b = _buf[tone];
  final need = _n[tone] + count * 2;
  if (need <= b.length) return;
  var len = b.length * 2;
  while (len < need) {
    len *= 2;
  }
  _buf[tone] = Float32List(len)..setAll(0, b);
}

void _put(int tone, double x, double y) {
  final b = _buf[tone];
  final i = _n[tone];
  b[i] = x;
  b[i + 1] = y;
  _n[tone] = i + 2;
}

/// `x % 1.0` and `x % 2.0`, bit for bit, for every finite [x] (each is the
/// one rounding of the same exact value, and +0 for a multiple), without
/// the runtime call Dart makes for a double's `%`.
double _fract(double x) => x - x.floorToDouble();
double _mod2(double x) => x - (x * 0.5).floorToDouble() * 2.0;

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
// What never changes for a grain of the ball, worked out once from the
// tables above exactly as the frame did: whether the rim thins it out, its
// row of the seam table, and the point at which it goes as the shot fades.
final _ballRow = Uint8List(_kBallN);
final _ballGoesAt = Float64List(_kBallN);
// The grains the rim keeps, in order, so the frame never tests the rest.
final _ballLive = Uint16List(_kBallN);
int _ballLiveN = 0;
// A grain's side of the ball: 1 if it is on the face we see (x > -0.1), 2
// if it is near the rim (rim > 0.8); and a cell of the seam table's band:
// 0 a seam (< 0.1), 1 and 2 melt (< 0.22, < 0.34), 3 crust. Its tone is then
// [_ballTone] at band * 4 + side, the choice the frame used to branch on.
final _ballSide = Uint8List(_kBallN);
final _seamBand = Uint8List(_kSeamU * _kSeamV);
final _ballTone = Uint8List.fromList(const [
  1, 0, 1, 0, // a seam: white-hot on the face we see
  2, 2, 5, 5, // melt, turning away at the rim
  3, 3, 5, 5, // cooling melt, the same
  4, 4, 4, 4, // crust
]);
// The shadow's grains and the heat's, the same.
final _shadowRho = Float64List(90);
final _shadowCos = Float64List(90);
final _shadowSin = Float64List(90);
final _heatStart = Float64List(30);
final _heatGone = Float64List(30);
final _heatCos = Float64List(30);
final _heatSin = Float64List(30);
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
    // Read back from the float tables, as the frame reads them.
    final rim = _ballRim[i], bx = _ballX[i], by = _ballY[i];
    if (!(rim > 0.86 && _h(i, 3) < (rim - 0.86) / 0.14)) {
      _ballLive[_ballLiveN++] = i;
    }
    _ballRow[i] = min(_kSeamV - 1, ((by + 1) / 2 * _kSeamV).floor());
    _ballGoesAt[i] = _h(i, 9);
    _ballSide[i] = (bx > -0.1 ? 1 : 0) | (rim > 0.8 ? 2 : 0);
  }
  for (var i = 0; i < 90; i++) {
    _shadowRho[i] = pow(_h(i, 41), 0.6).toDouble();
    final a = _h(i, 42) * _tau;
    _shadowCos[i] = cos(a);
    _shadowSin[i] = sin(a);
  }
  for (var i = 0; i < 30; i++) {
    _heatStart[i] = _h(i, 90);
    _heatGone[i] = _h(i, 93);
    final a = _h(i, 91) * _tau;
    _heatCos[i] = cos(a);
    _heatSin[i] = sin(a);
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
      final seam = _seamTab[iu * _kSeamV + iv];
      _seamBand[iu * _kSeamV + iv] = seam < 0.1
          ? 0
          : (seam < 0.22 ? 1 : (seam < 0.34 ? 2 : 3));
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
    final kk0 = (max(0.0, lo) / track.period).floor();
    final kk1 = (hi / track.period).floor();
    final ta = track.a, tc = track.c, kind = track.kind;
    final room = ta.length * (kk1 - kk0 + 1);
    for (final tone in const [4, 5, 9, 10, 11]) {
      _room(tone, room);
    }
    final v = f.v, gone = f.gone;
    final px = f.px, py = f.py, dx = f.dx, dy = f.dy;
    for (var kk = kk0; kk <= kk1; kk++) {
      final base = kk * track.period;
      for (var i = 0; i < ta.length; i++) {
        final a = base + ta[i];
        if (a < lo || a > hi) continue;
        final age = (hi - a) / v;
        if (kind[i] == 0 && age > 0.11) continue;
        if (age > life * 0.75 &&
            _h(i + kk * 977, 5) < (age - life * 0.75) / (life * 0.25)) {
          continue;
        }
        final s = age / life;
        // [_Flight.ground], written out.
        final along = a - gone, across = tc[i] * r;
        _put(
          s < 0.1 ? 9 : (s < 0.28 ? 10 : (s < 0.55 ? 11 : (s < 0.8 ? 5 : 4))),
          px + dx * along - dy * across,
          py + dy * along + dx * across,
        );
      }
    }
  }

  // Its shadow, then the ball: cells of melt turning over, the seams
  // white-hot on its leading face, dark crust riding round to its back.
  // What is fixed for each grain comes from tables ([_buildLava]); only
  // the roll, the fade and the shot's place are done here.
  final k = r / 31;
  final sx = at.dx + 4 * k, sy = at.dy + 7 * k;
  _room(6, 90);
  for (var i = 0; i < 90; i++) {
    final rho = _shadowRho[i] * r;
    _put(6, sx + rho * _shadowCos[i], sy + rho * _shadowSin[i] * 0.8);
  }
  final roll = time * 0.42;
  final count = (900 * (k * k).clamp(0.6, 1.22)).round();
  for (var tone = 0; tone <= 5; tone++) {
    _room(tone, count);
  }
  final px = f.px, py = f.py, dx = f.dx, dy = f.dy;
  for (var j = 0; j < _ballLiveN; j++) {
    final i = _ballLive[j];
    if (i >= count) break;
    if (fade < 1 && _ballGoesAt[i] > fade) continue;
    final u = _mod2(_ballU[i] + roll);
    final iu = min(_kSeamU - 1, (u / 2 * _kSeamU).floor());
    final tone =
        _ballTone[_seamBand[iu * _kSeamV + _ballRow[i]] * 4 + _ballSide[i]];
    final along = _ballX[i] * r, across = _ballY[i] * r;
    _put(tone, px + dx * along - dy * across, py + dy * along + dx * across);
  }
  // Heat lifting off it.
  for (var i = 0; i < 30; i++) {
    if (sin(time * 11 + i * 1.3) < 0) continue;
    final q = _fract(time * 0.9 + _heatStart[i]);
    if (_heatGone[i] > 1 - q) continue;
    final d = r * 0.9 + 22 * k * q;
    f.local(
      q < 0.4 ? 7 : 8,
      d * _heatCos[i] - 14 * k * q,
      d * _heatSin[i] * 0.85,
    );
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

final _poolThinned = Uint8List(_kPoolN);
final _poolGoesAt = Float64List(_kPoolN);

/// What one pool keeps between frames: for each of its grains where it
/// lies, which cell of the ground it is in and how far it is from the seam
/// between that cell and the next; and each cell's place in the pulse.
class _PoolLayout {
  double x = double.nan, y = double.nan, r = 0;
  int count = -1, cells = 0;
  final px = Float32List(_kPoolN), py = Float32List(_kPoolN);
  final seam = Float64List(_kPoolN);
  final near = Uint16List(_kPoolN);
  final cellPhase = Float64List(_kPoolGrid * _kPoolGrid);

  /// The cells this pool covers, as indexes into the grid.
  final cellAt = Uint16List(_kPoolGrid * _kPoolGrid);

  /// What a frame need not work out again while the heat holds ([fixedW],
  /// [fixedCool]) and nothing dissolves. A grain further from a seam than
  /// the white-hot seam ever reaches (at the top of its pulse) keeps its
  /// tone, and the tones only such grains take (2 and 3; 3 alone when the
  /// heat is low) are kept as points, in order ([fixed], [fixedFrom] to
  /// [fixedTo] for each). The rest, in order, are worked out each frame
  /// ([live]).
  double fixedW = double.nan;
  bool fixedCool = false;
  final live = Uint16List(_kPoolN);
  int liveN = 0;
  final fixed = Float32List(_kPoolN * 2);
  final fixedFrom = Int32List(4), fixedTo = Int32List(4);

  void fix(double w, bool cool) {
    fixedW = w;
    fixedCool = cool;
    // The frame's seam test at the pulse's top, worked out as it does: no
    // pulse puts the seam further out.
    const top = 1.0;
    final widest = (1.8 + 1.0 * top) * w;
    final melt = 4.6 * w, cooling = 7.4 * w;
    final firstFixed = cool ? 3 : 2;
    int fixedTone(double s) {
      var tone = s < melt ? 1 : (s < cooling ? 2 : 3);
      if (cool && tone < 2) tone += 1;
      return tone;
    }

    var o = 0;
    for (var t = 0; t < 4; t++) {
      fixedFrom[t] = o;
      if (t >= firstFixed) {
        for (var i = 0; i < count; i++) {
          if (_poolThinned[i] == 1) continue;
          final s = seam[i];
          if (s < widest || fixedTone(s) != t) continue;
          fixed[o++] = px[i];
          fixed[o++] = py[i];
        }
      }
      fixedTo[t] = o;
    }
    liveN = 0;
    for (var i = 0; i < count; i++) {
      if (_poolThinned[i] == 1) continue;
      final s = seam[i];
      if (!(s < widest) && fixedTone(s) >= firstFixed) continue;
      live[liveN++] = i;
    }
  }

  void lay(ui.Offset at, double radius, int n) {
    fixedW = double.nan;
    x = at.dx;
    y = at.dy;
    r = radius;
    count = n;
    final gx0 = ((at.dx - r) / _kPoolCell).floor() - 1;
    final gy0 = ((at.dy - r * 0.82) / _kPoolCell).floor() - 1;
    final gw = min(_kPoolGrid, (2 * r / _kPoolCell).ceil() + 3);
    final gh = min(_kPoolGrid, (2 * r * 0.82 / _kPoolCell).ceil() + 3);
    cells = 0;
    for (var ix = 0; ix < gw; ix++) {
      for (var iy = 0; iy < gh; iy++) {
        final id = (gx0 + ix) * 131 + (gy0 + iy) * 977;
        final j = ix * _kPoolGrid + iy;
        _cellX[j] = (gx0 + ix + 0.15 + 0.7 * _h(id, 205)) * _kPoolCell;
        _cellY[j] = (gy0 + iy + 0.15 + 0.7 * _h(id, 206)) * _kPoolCell;
        cellPhase[j] = id * 1.7;
        cellAt[cells++] = j;
      }
    }
    final ax = at.dx, ay = at.dy;
    final thinned = _poolThinned, poolX = _poolX, poolY = _poolY;
    final cellX = _cellX, cellY = _cellY;
    for (var i = 0; i < n; i++) {
      if (thinned[i] == 1) continue;
      final wx = ax + poolX[i] * r, wy = ay + poolY[i] * r;
      final cx = (wx / _kPoolCell).floor() - gx0;
      final cy = (wy / _kPoolCell).floor() - gy0;
      var d1 = 1e18, d2 = 1e18;
      var nearest = 0;
      final ox1 = min(gw - 1, cx + 1);
      final oy0 = max(0, cy - 1), oy1 = min(gh - 1, cy + 1);
      for (var ox = max(0, cx - 1); ox <= ox1; ox++) {
        for (var oy = oy0; oy <= oy1; oy++) {
          final j = ox * _kPoolGrid + oy;
          final dx = cellX[j] - wx, dy = cellY[j] - wy;
          final d = dx * dx + dy * dy;
          if (d < d1) {
            d2 = d1;
            d1 = d;
            nearest = j;
          } else if (d < d2) {
            d2 = d;
          }
        }
      }
      px[i] = wx;
      py[i] = wy;
      seam[i] = sqrt(d2) - sqrt(d1);
      near[i] = nearest;
    }
  }
}

/// The pools on the field now, by where each lies. Emptied when it fills,
/// so a long run never holds more than a field's worth.
const int _kPoolLayoutCap = 160;
final Map<int, _PoolLayout> _poolLayouts = {};

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
      // Which grains the rim thins out, and the point at which each one
      // goes as a pool dissolves: the same for every pool, every frame.
      _poolThinned[i] = u > 0.72 && _h(i, 201) < (u - 0.72) / 0.28 ? 1 : 0;
      _poolGoesAt[i] = _h(i, 207);
    }
  }
  // A pool lies where it was dropped, and its cells belong to the ground, so
  // which cell each of its grains is in and how far that grain is from a
  // seam never change: they are worked out once and kept ([_PoolLayout]).
  // Only what moves is done each frame: the cells' pulse, the heat, the fade.
  final count = min(_kPoolN, (r * r * (reduced ? 0.22 : 0.45)).round());
  final key = Object.hash(at.dx, at.dy);
  var lay = _poolLayouts[key];
  if (lay == null) {
    if (_poolLayouts.length >= _kPoolLayoutCap) _poolLayouts.clear();
    lay = _poolLayouts[key] = _PoolLayout();
  }
  final laid =
      lay.x != at.dx || lay.y != at.dy || lay.r != r || lay.count != count;
  if (laid) lay.lay(at, r, count);
  final cells = lay.cells;
  for (var c = 0; c < cells; c++) {
    final j = lay.cellAt[c];
    // A whole cell's rim brightens and cools together.
    _cellPulse[j] = 0.5 + 0.5 * sin(time * 1.6 + lay.cellPhase[j]);
  }
  // As it cools ([heat] toward 0) the seams narrow and dim to crust.
  final w = 0.35 + 0.65 * heat.clamp(0.0, 1.0);
  final seams = lay.seam, nears = lay.near, px = lay.px, py = lay.py;
  if (!laid && !(fade < 1) && w >= 0.35) {
    // Whole, at a steady heat and size: only the grains whose tone can
    // change (and those sharing a tone with them) are worked out; the rest
    // are laid in as they stand ([_PoolLayout.fix]). The same grains, in the
    // same order. (A pool still spreading is laid afresh each frame, so it
    // keeps nothing.)
    final cool = heat < 0.5;
    if (lay.fixedW != w || lay.fixedCool != cool) lay.fix(w, cool);
    final live = lay.live;
    for (var k = 0; k < lay.liveN; k++) {
      final i = live[k];
      final seam = seams[i];
      final pulse = _cellPulse[nears[i]];
      var tone = seam < (1.8 + 1.0 * pulse) * w
          ? 0
          : (seam < 4.6 * w ? 1 : (seam < 7.4 * w ? 2 : 3));
      if (heat < 0.5 && tone < 2) tone += 1;
      _g(tone, px[i], py[i]);
    }
    for (var t = 0; t < 4; t++) {
      final from = lay.fixedFrom[t], to = lay.fixedTo[t];
      if (to == from) continue;
      _room(t, (to - from) ~/ 2);
      final at = _n[t];
      _buf[t].setRange(at, at + to - from, lay.fixed, from);
      _n[t] = at + to - from;
    }
    _flush(canvas, _poolLook);
    return;
  }
  for (var i = 0; i < count; i++) {
    if (_poolThinned[i] == 1) continue;
    // Dissolving: each grain goes at its own point as [fade] falls.
    if (fade < 1 && _poolGoesAt[i] > fade) continue;
    final seam = seams[i];
    final pulse = _cellPulse[nears[i]];
    var tone = seam < (1.8 + 1.0 * pulse) * w
        ? 0
        : (seam < 4.6 * w ? 1 : (seam < 7.4 * w ? 2 : 3));
    if (heat < 0.5 && tone < 2) tone += 1;
    _g(tone, px[i], py[i]);
  }
  _flush(canvas, _poolLook);
}

// ── Water: a wall with froth at its crest, foam lace behind it ─────────────

int _wallN = 0;
final _wallS = Float32List(1400);
final _wallU = Float32List(1400);
final _wallTone = Uint8List(1400);
// What the frame works out for each wall grain that never changes: its
// front and depth before the wall's scale (`front(s) / k`, `depth(s) / k`),
// and the point at which it goes as the shot fades.
final _wallFront = Float64List(1400);
final _wallDepth = Float64List(1400);
final _wallGoesAt = Float64List(1400);
// The crest's clumps (11 of 14 grains) and the spray (90), the same.
final _clumpS = Float64List(11), _clumpEdge = Float64List(11);
final _clumpFront = Float64List(11), _clumpStart = Float64List(11);
final _clumpKeep = Float64List(11 * 14), _clumpSize = Float64List(11 * 14);
final _clumpCos = Float64List(11 * 14), _clumpSin = Float64List(11 * 14);
final _sprayStart = Float64List(90), _sprayS = Float64List(90);
final _sprayKeep = Float64List(90), _sprayEdge = Float64List(90);
final _sprayReach = Float64List(90), _sprayFront = Float64List(90);
// Lace that has strayed to the edge of the path thins there.
Float64List _laceEdge = Float64List(0);
_Track? _lace;

/// The lace's hash for each grain on stretch [kk] of a path (`_h(i + kk *
/// 911, 72)`): it depends on the stretch and the grain alone, so it is
/// worked out once a stretch and kept for every frame and shot on it.
final Map<int, Float64List> _laceHashes = {};

Float64List _laceHash(int kk, int n) {
  var row = _laceHashes[kk];
  if (row == null) {
    if (_laceHashes.length >= 16) _laceHashes.clear();
    row = _laceHashes[kk] = Float64List(n);
    for (var i = 0; i < n; i++) {
      row[i] = _h(i + kk * 911, 72);
    }
  }
  return row;
}

/// The wall's front at [s] across it, before its scale.
double _waterFront(double s) => 14 * (1 - s * s) - 26 * pow(s.abs(), 4);

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
  // Read back from the float tables, as the frame reads them.
  for (var i = 0; i < _wallN; i++) {
    final s = _wallS[i];
    _wallFront[i] = _waterFront(s);
    _wallDepth[i] = 8 + 40 * sqrt(max(0.0, 1 - s * s));
    _wallGoesAt[i] = _h(i, 9);
  }
  final lc = _lace!.c;
  _laceEdge = Float64List(lc.length);
  for (var i = 0; i < lc.length; i++) {
    final s = lc[i];
    _laceEdge[i] = s.abs() > 0.75 ? _sm(0.75, 1, s.abs()) : 0;
  }
  for (var c = 0; c < 11; c++) {
    final s = -0.85 + c * 0.17 + 0.05 * sin(c * 3.1);
    _clumpS[c] = s;
    _clumpEdge[c] = 1 - _sm(0.75, 1.0, s.abs());
    _clumpFront[c] = _waterFront(s);
    _clumpStart[c] = _h(c, 30);
    for (var i = 0; i < 14; i++) {
      final at = c * 14 + i;
      _clumpKeep[at] = _h(i + c * 31, 33);
      final a = _h(i + c * 31, 31) * _tau;
      _clumpCos[at] = cos(a);
      _clumpSin[at] = sin(a);
      _clumpSize[at] = _h(i + c * 31, 32);
    }
  }
  for (var i = 0; i < 90; i++) {
    _sprayStart[i] = _h(i, 50);
    final s = _h(i, 51) * 1.7 - 0.85;
    _sprayS[i] = s;
    _sprayKeep[i] = _h(i, 53);
    _sprayEdge[i] = 1 - _sm(0.7, 0.85, s.abs());
    _sprayReach[i] = _h(i, 52);
    _sprayFront[i] = _waterFront(s);
  }
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
  // [_waterFront] and the depth, scaled; the tables hold them unscaled.
  double depth(double s) => k * (8 + 40 * sqrt(max(0.0, 1 - s * s)));

  // Foam lace on the floor behind it, drying out.
  final track = _lace!;
  const life = 0.6;
  final hi = f.gone - depth(0) * 0.55;
  final lo = hi - f.v * life;
  if (hi > 0) {
    final kk0 = (max(0.0, lo) / track.period).floor();
    final kk1 = (hi / track.period).floor();
    for (var kk = kk0; kk <= kk1; kk++) {
      final base = kk * track.period;
      final hashes = _laceHash(kk, track.a.length);
      for (var i = 0; i < track.a.length; i++) {
        final a = base + track.a[i];
        if (a < lo || a > hi) continue;
        final age = (hi - a) / f.v / life;
        if (track.kind[i] > 6 + 4 * (1 - age)) continue;
        final s = track.c[i];
        final h = hashes[i];
        // Each test drops the grain, so their order does not matter: the
        // cheap ones first. (1 - age)^1.4 is at most 1 - age, and for
        // 1 - age up to 0.999999 at least a two-millionth of itself below
        // it, far more than pow's error (under an ulp): a hash past 1 - age
        // is past the power too, without working the power out.
        if (s.abs() > 0.75 && h < _laceEdge[i]) continue;
        final left = 1 - age;
        if (left >= 0 && left <= 0.999999 && h > left) continue;
        if (h > pow(left, 1.4)) continue;
        f.ground(age < 0.25 ? 9 : (age < 0.55 ? 10 : 11), a, s * hh * 0.97);
      }
    }
  }

  // The wall: froth at the front, lit water behind going deep blue and then
  // to nothing; its tips curl back; the water rushes.
  for (var i = 0; i < _wallN; i++) {
    if (fade < 1 && _wallGoesAt[i] > fade) continue;
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
        k * _wallFront[i] -
        u * (k * _wallDepth[i]) +
        2.5 * k * sin(time * 7 + s * 11 + u * 5);
    final y = s * hh + 2.5 * k * sin(time * 3 + u * 7 + s * 3);
    f.local(tone, x, y);
    if (tone >= 1 && tone <= 3 && u < 0.6) f.local(tone + 4, x - 3.5, y);
  }
  // Clumps breaking along the crest, rolling over forward.
  for (var c = 0; c < 11; c++) {
    final s = _clumpS[c];
    final phase = _fract(time * 1.6 + _clumpStart[c]);
    final keep = _clumpEdge[c] * (1 - phase * 0.6) * fade;
    final bx = k * _clumpFront[c] + 2 * k + 7 * k * phase;
    final by = s * hh;
    final swell = sin(phase * pi);
    for (var i = 0; i < 14; i++) {
      final at = c * 14 + i;
      if (_clumpKeep[at] > keep) continue;
      final r = k * (1.5 + 4.5 * _clumpSize[at] * swell);
      f.local(8, bx + r * _clumpCos[at], by + r * _clumpSin[at] * 1.3);
    }
  }
  // Spray thrown ahead of the crest.
  for (var i = 0; i < 90; i++) {
    final q = _fract(time * 2.2 + _sprayStart[i]);
    final s = _sprayS[i];
    if (_sprayKeep[i] > (1 - q) * _sprayEdge[i] * fade) continue;
    final d = k * (8 + 26 * _sprayReach[i]) * (1 - exp(-3 * q));
    f.local(8, k * _sprayFront[i] + 3 * k + d, s * hh + s * d * 0.5);
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
