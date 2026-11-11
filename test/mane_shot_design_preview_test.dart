@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/element_ground_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// DESIGN FRAMES ONLY: Mane's catapult shots in grains.
//
// Today most Mane shots are one smooth filled shape under a gradient (the
// Earth slabs, the Water crescent, the Lava boulder, the Ice glass, the
// Mud / Poison / Blood teardrop that only changes colour), with a ruled
// crack or crest drawn on top. Here a shot is grains: density makes the
// mass, light makes it round, it thins to nothing at the rim, and each
// element has its own form. What it does on the board is shown too: the
// stones Earth throws, the bodies Water carries, the pools Lava drops, the
// bodies Ice freezes, what Dark drags in and eats, the blood that runs home.
//
// Each row: in flight | the pierce | what it leaves. One world unit is
// 1.25 sheet pixels; sizes are the decent band's.
//
// Nothing here is in the game.
//
//   MANE_OUT=docs/ability_vfx_audit/mane_designs_1111.png flutter test \
//     test/mane_shot_design_preview_test.dart --tags preview

const _floor = Color(0xFF18242A);
const _ink = Color(0xFF07060B);
const _tau = math.pi * 2;

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _sm(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _nz(double x, double y) =>
    0.5 * math.sin(x * 1.7 + y * 0.9) +
    0.3 * math.sin(x * 0.63 - y * 1.31 + 1.7) +
    0.2 * math.sin(x * 2.9 + y * 2.3 + 0.4);

Color _al(Color c, double a) => c.withValues(alpha: (c.a * a).clamp(0.0, 1.0));

/// Grains bucketed by colour and size, drawn in the order first added.
class _G {
  final _m = <(int, int), List<double>>{};
  static final _p = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void add(double x, double y, double d, Color c) {
    if (c.a < 0.02) return;
    // Alpha in steps of 1/16 so the buckets stay few.
    final q = c.withValues(alpha: ((c.a * 16).round() / 16).clamp(0.0, 1.0));
    (_m[(q.toARGB32(), (d * 10).round())] ??= [])
      ..add(x)
      ..add(y);
  }

  void flush(Canvas c) {
    _m.forEach((k, v) {
      _p
        ..color = Color(k.$1)
        ..strokeWidth = k.$2 / 10;
      c.drawRawPoints(ui.PointMode.points, Float32List.fromList(v), _p);
    });
    _m.clear();
  }
}

// ── The scene ──────────────────────────────────────────────────────────────

const double _w = 600, _hgt = 300, _py = 150;

/// Five bodies across the line, the way a wave meets the catapult.
const _foes = [
  Offset(285, 120),
  Offset(305, 178),
  Offset(335, 148),
  Offset(362, 196),
  Offset(380, 108),
];

class _Path {
  final double x0, v;
  const _Path(this.x0, this.v);
  double x(double t) => x0 + v * t;

  /// When the shot's centre comes level with [ex], less [lead].
  double reach(double ex, [double lead = 0]) => (ex - lead - x0) / v;
}

/// A body in grains: a dark heart, a lit rim. [tint] recolours it (frozen,
/// burning); [stretch] smears it toward something pulling it.
void _foe(
  _G g,
  Offset o, {
  int salt = 0,
  Color? tint,
  double tintK = 0,
  Offset stretch = Offset.zero,
  double a = 1,
}) {
  for (var i = 0; i < 70; i++) {
    final rho = math.sqrt(_h(i, 300 + salt)) * 9.5;
    final ang = _h(i, 301 + salt) * _tau;
    final x = rho * math.cos(ang), y = rho * math.sin(ang) * 0.92;
    final lit = (-x * 0.55 - y * 0.8) / 9.5;
    final heart = rho < 4.8;
    var c = heart
        ? const Color(0xFF0C0A12)
        : (lit > 0.3
              ? const Color(0xFFDCD5F2)
              : (lit > -0.2
                    ? const Color(0xFF9087AE)
                    : const Color(0xFF4E4766)));
    if (tint != null && tintK > 0) c = Color.lerp(c, tint, tintK)!;
    final s = _h(i, 302 + salt);
    g.add(
      o.dx + x + stretch.dx * s,
      o.dy + y + stretch.dy * s,
      heart ? 2.8 : 2.1,
      _al(c, a),
    );
  }
}

/// A heavy thing's shadow on the floor, in grains, no edge.
void _shadow(_G g, Offset o, double r, {double a = 0.55, int n = 380}) {
  for (var i = 0; i < n; i++) {
    final rho = math.pow(_h(i, 41), 0.6) * r;
    final ang = _h(i, 42) * _tau;
    g.add(
      o.dx + 5 + rho * math.cos(ang),
      o.dy + 8 + rho * math.sin(ang) * 0.75,
      2.6,
      _al(_ink, a * (1 - rho / r)),
    );
  }
}

/// A ground effect from the game's own painter, faded by [a].
void _ground(
  Canvas c,
  String element,
  Offset at,
  double r,
  double time,
  double seed,
  double a,
) {
  if (a <= 0.01 || r < 6) return;
  c.saveLayer(
    Rect.fromCircle(center: at, radius: r * 1.6),
    Paint()..color = Color.fromRGBO(0, 0, 0, a.clamp(0.0, 1.0)),
  );
  c.translate(at.dx, at.dy);
  paintElementGround(c, element, r, time, seed);
  c.restore();
}

/// A lump of grains lit from the upper left: [edge] gives its outline
/// radius by angle, it thins to nothing past 86% of it, and [tone] picks a
/// colour from the light (-1 dark .. 1 lit) and the point.
void _lump(
  _G g,
  Offset o,
  int n,
  int salt,
  double Function(double ang) edge,
  Color? Function(double shade, double lx, double ly, double u) tone, {
  double size = 2.3,
  double rimFrom = 0.86,
}) {
  for (var i = 0; i < n; i++) {
    final ang = _h(i, 1 + salt) * _tau;
    final e = edge(ang);
    final u = math.sqrt(_h(i, 2 + salt));
    if (u > rimFrom && _h(i, 3 + salt) < (u - rimFrom) / (1 - rimFrom)) {
      continue;
    }
    final lx = e * u * math.cos(ang), ly = e * u * math.sin(ang);
    final nx = lx / e, ny = ly / e;
    final nz = math.sqrt(math.max(0.0, 1 - u * u));
    final shade = -0.42 * nx - 0.58 * ny + 0.7 * nz - 0.25;
    final c = tone(shade, lx, ly, u);
    if (c == null) continue;
    g.add(o.dx + lx, o.dy + ly, size, c);
  }
}

// ── Earth: a slab of stone that breaks and throws ──────────────────────────

void _earth(Canvas c, int m) {
  const path = _Path(30, 200);
  final t = const [0.55, 1.45, 2.6][m];
  final cx = path.x(t);
  final big = math.max(34.0, 60 - 9.5 * t);
  final rot = t * 0.3;
  final g = _G();

  // The quakes it leaves as it breaks (the game's Earth ground).
  for (var k = 0; k < 6; k++) {
    final tau = 0.45 + k * 0.42;
    final age = t - tau;
    if (age < 0 || age > 1.05) continue;
    final at = Offset(path.x(tau) - 18, _py + (_h(k, 77) - 0.5) * 56);
    final a = _sm(0, 0.15, age) * (1 - _sm(0.75, 1.05, age));
    _ground(c, 'Earth', at, 46, t, k * 3.1, a * 0.9);
  }

  // Grit ground off its trailing side.
  for (var i = 0; i < 520; i++) {
    final age = _h(i, 60) * 1.0;
    final tau = t - age;
    if (tau < 0.05) continue;
    final r = math.max(34.0, 60 - 9.5 * tau);
    final side = _h(i, 61) * 2 - 1;
    final x = path.x(tau) - r * 0.55 - 10 * _h(i, 62) - 6 * age;
    final y = _py + side * r * 0.85 + side * 14 * age;
    final f = 1 - age;
    g.add(
      x,
      y,
      _h(i, 63) < 0.3 ? 2.1 : 1.6,
      _al(
        _h(i, 64) < 0.25 ? const Color(0xFFB8AE9A) : const Color(0xFF5C5862),
        f * f * 0.85,
      ),
    );
  }

  // The bodies it meets are shoved aside, in a burst of grit.
  for (var e = 0; e < _foes.length; e++) {
    final f = _foes[e];
    final dy = f.dy - _py;
    final hit = dy.abs() < big + 4;
    final tHit = path.reach(f.dx, big * 0.8);
    var at = f;
    if (hit && t > tHit) {
      final k = _sm(0, 0.45, t - tHit);
      at = f + Offset(18 * k, (dy.sign == 0 ? 1 : dy.sign) * 30 * k);
      for (var i = 0; i < 40; i++) {
        final age = t - tHit;
        if (age > 0.7) break;
        final ang = (dy.sign >= 0 ? 0.3 : -0.3) + (_h(i, 80 + e) - 0.5) * 2.4;
        final d = 6 + 34 * _sm(0, 0.5, age) * (0.4 + 0.6 * _h(i, 81 + e));
        g.add(
          f.dx + d * math.cos(ang),
          f.dy + d * math.sin(ang),
          1.7,
          _al(const Color(0xFFB8AE9A), (1 - age / 0.7) * 0.9),
        );
      }
    }
    _foe(g, at, salt: e * 7);
  }
  g.flush(c);

  // The stones it throws as it breaks, each with its own trail of grit.
  for (var k = 0; k < 9; k++) {
    final tau = 0.25 + k * 0.28;
    final age = t - tau;
    if (age < 0 || age > 1.3) continue;
    final rTau = math.max(34.0, 60 - 9.5 * tau);
    final sideSign = k.isEven ? 1.0 : -1.0;
    final phi = sideSign * (1.15 + 0.9 * _h(k, 90));
    final start =
        Offset(path.x(tau), _py) +
        Offset(math.cos(phi), math.sin(phi)) * rTau * 0.85;
    double travel(double a) => 230 * (1 - math.exp(-2.4 * a)) / 2.4;
    final dir = Offset(math.cos(phi), math.sin(phi));
    final pos = start + dir * travel(age);
    final fade = 1 - _sm(0.9, 1.3, age);
    for (var j = 1; j <= 9; j++) {
      final pa = math.max(0.0, age - j * 0.035);
      final q = start + dir * travel(pa);
      g.add(
        q.dx + (_h(j + k * 9, 91) - 0.5) * 4,
        q.dy + (_h(j + k * 9, 92) - 0.5) * 4,
        1.6,
        _al(const Color(0xFF8E877C), fade * (1 - j / 10) * 0.8),
      );
    }
    final rr = 7.5 + 3.5 * _h(k, 93);
    _shadow(g, pos, rr, a: 0.4 * fade, n: 40);
    _lump(
      g,
      pos,
      90,
      400 + k * 13,
      (a) => rr * (1 + 0.22 * math.sin(3 * a + k)),
      (s, lx, ly, u) => _al(
        s > 0.45
            ? const Color(0xFFE9DFC6)
            : (s > 0.1
                  ? const Color(0xFF8F8A90)
                  : (s > -0.25
                        ? const Color(0xFF45424B)
                        : const Color(0xFF1A191E))),
        fade,
      ),
      size: 2.1,
    );
  }

  // The slab: packed stone, lit on its upper face, its faults opening as
  // it breaks, a seam of light deep in each one.
  _shadow(g, Offset(cx, _py), big * 1.05);
  final seamW = 1.4 + 1.5 * t;
  // Plates: each a flat face tilted its own way, so the light steps from
  // plate to plate the way it does on broken stone. The seams between
  // them are the faults.
  final plates = <Offset>[];
  final normals = <(double, double, double)>[];
  for (var k = 0; k < 8; k++) {
    final pr = big * 0.62 * math.sqrt((k + 0.5) / 8);
    final pa = k * 2.399 + 0.3;
    plates.add(Offset(pr * math.cos(pa), pr * math.sin(pa)));
    // Spread round the light so the faces step through every tone.
    final tilt = 0.35 + 0.45 * _h(k, 95);
    final az = 4.1 + k * 2.399 + 0.6 * _h(k, 96);
    normals.add((
      math.sin(tilt) * math.cos(az),
      math.sin(tilt) * math.sin(az),
      math.cos(tilt),
    ));
  }
  final seams = <Offset>[];
  _lump(
    g,
    Offset(cx, _py),
    2300,
    500,
    (a) =>
        big *
        (1 +
            0.15 * math.sin(3 * a + 1.3) +
            0.09 * math.sin(5 * a + 0.4) +
            0.05 * math.sin(9 * a)),
    (s, lx, ly, u) {
      final cr = math.cos(rot), sr = math.sin(rot);
      final px = lx * cr + ly * sr, py = -lx * sr + ly * cr;
      var d1 = 1e9, d2 = 1e9;
      var k1 = 0;
      for (var k = 0; k < plates.length; k++) {
        final d = (Offset(px, py) - plates[k]).distance;
        if (d < d1) {
          d2 = d1;
          d1 = d;
          k1 = k;
        } else if (d < d2) {
          d2 = d;
        }
      }
      final gap = d2 - d1;
      // Only some boundaries are faults; the others are edges between faces.
      final fault = (k1 * 3) % 4 != 1;
      if (fault && gap < seamW) {
        if (gap < seamW * 0.7 && u < 0.84) seams.add(Offset(lx, ly));
        return null;
      }
      final n = normals[k1];
      final f = -0.42 * n.$1 - 0.58 * n.$2 + 0.7 * n.$3 - 0.3 + 0.3 * s;
      final edge = gap < seamW + 2.5 ? -0.18 : 0.0;
      final v = f + edge;
      return v > 0.62
          ? const Color(0xFFE6DCC4)
          : (v > 0.38
                ? const Color(0xFF9C9599)
                : (v > 0.14
                      ? const Color(0xFF5A5662)
                      : (v > -0.12
                            ? const Color(0xFF2E2C35)
                            : const Color(0xFF15141A))));
    },
    size: 2.4,
    rimFrom: 0.78,
  );
  for (var i = 0; i < seams.length; i++) {
    final s = seams[i];
    final flick = 0.55 + 0.45 * math.sin(t * 5 + i * 1.7);
    g.add(
      cx + s.dx,
      _py + s.dy,
      i.isEven ? 2.0 : 1.5,
      _al(
        i % 3 == 0 ? const Color(0xFFFFE7A6) : const Color(0xFFFFB347),
        flick * _sm(0.3, 1.0, t + 0.3),
      ),
    );
  }
  g.flush(c);
}

// ── Water: a wall that takes them with it ──────────────────────────────────

void _water(Canvas c, int m) {
  const path = _Path(20, 240);
  final t = const [0.5, 1.3, 2.2][m];
  final fx = path.x(t);
  const hh = 96.0;
  double front(double s) => 14 * (1 - s * s) - 26 * math.pow(s.abs(), 4);
  double depth(double s) => 8 + 40 * math.sqrt(math.max(0.0, 1 - s * s));
  final g = _G();

  // What it leaves: wet streaks and lace on the floor, drying out.
  // Foam lace: grains only along the threads where a slow noise crosses
  // zero, so it nets instead of dotting the floor.
  for (var i = 0; i < 9000; i++) {
    final age = _h(i, 10) * 1.0;
    final tau = t - age;
    if (tau < 0.08) continue;
    final s = _h(i, 11) * 2 - 1;
    final x =
        path.x(tau) +
        front(s) -
        depth(s) * (0.5 + 0.7 * _h(i, 12)) +
        14 * (1 - math.exp(-3 * age));
    final y = _py + s * hh * 0.97;
    final lace = _nz(x * 0.06 + 3, y * 0.075 + age * 0.4).abs();
    if (lace > 0.07 + 0.05 * (1 - age)) continue;
    final a = math.pow(1 - age, 1.4) * (1 - _sm(0.75, 1, s.abs()));
    final col = age < 0.25
        ? const Color(0xFFCFF4FC)
        : (age < 0.55 ? const Color(0xFF5FC2E6) : const Color(0xFF2A78AA));
    g.add(x, y, 1.7, _al(col, a * 0.85));
  }

  // The bodies: carried at the front once it reaches them.
  final carried = <Offset>[];
  for (var e = 0; e < _foes.length; e++) {
    final f = _foes[e];
    final s = (f.dy - _py) / hh;
    final tHit = path.reach(f.dx, front(s));
    var at = f;
    if (t > tHit) {
      final tumble = (t - tHit) * 3 + e;
      at = Offset(
        fx + front(s) - 2 - 3 * math.sin(tumble),
        f.dy + (_py - f.dy) * 0.12 * _sm(0, 0.6, t - tHit),
      );
      carried.add(at);
      continue;
    }
    _foe(g, at, salt: e * 7);
  }
  g.flush(c);

  // The wall: a crest of froth at the front, lit water behind it going
  // deep blue and then to nothing; its tips curl back. The water rushes.
  for (var i = 0; i < 3600; i++) {
    final raw = _h(i, 20) * 2 - 1;
    final s = raw.sign * math.pow(raw.abs(), 0.85);
    final u = math.pow(_h(i, 21), 1.5).toDouble();
    final x =
        fx + front(s) - u * depth(s) + 2.5 * math.sin(t * 7 + s * 11 + u * 5);
    final y = _py + s * hh + 2.5 * math.sin(t * 3 + u * 7 + s * 3);
    final tip = 1 - _sm(0.78, 1.0, s.abs());
    final back = 1 - _sm(0.62, 1.0, u) * 0.92;
    final a = tip * back;
    Color col;
    double size = 2.0;
    if (u < 0.07) {
      if (_nz(s * 16 + t * 2.2, u * 30 + t) > 0.42) continue;
      col = const Color(0xFFF4FCFF);
      size = 1.8;
    } else if (u < 0.2) {
      col = const Color(0xFFA6EDFA);
    } else if (u < 0.42) {
      col = const Color(0xFF3FB2DE);
    } else if (u < 0.7) {
      col = const Color(0xFF16679C);
    } else {
      col = const Color(0xFF0B3A60);
    }
    g.add(x, y, size, _al(col, a));
    if (u > 0.07 && u < 0.6) g.add(x - 3.5, y, 1.6, _al(col, a * 0.45));
  }
  // Breaking clumps along the crest, rolling over forward.
  for (var k = 0; k < 11; k++) {
    final s = -0.85 + k * 0.17 + 0.05 * math.sin(k * 3.1);
    final phase = (t * 1.6 + _h(k, 30)) % 1.0;
    final bx = fx + front(s) + 2 + 7 * phase;
    final by = _py + s * hh;
    for (var i = 0; i < 26; i++) {
      final ang = _h(i + k * 31, 31) * _tau;
      final r = 1.5 + 4.5 * _h(i + k * 31, 32) * math.sin(phase * math.pi);
      g.add(
        bx + r * math.cos(ang),
        by + r * math.sin(ang) * 1.3,
        1.7,
        _al(
          const Color(0xFFFFFFFF),
          (1 - _sm(0.75, 1.0, s.abs())) * (1 - phase * 0.6),
        ),
      );
    }
  }
  g.flush(c);
  // What it carries rides the crest, froth breaking over it.
  for (var k = 0; k < carried.length; k++) {
    _foe(g, carried[k], salt: k * 11 + 3);
  }
  g.flush(c);
  for (var k = 0; k < carried.length; k++) {
    for (var i = 0; i < 26; i++) {
      // Over its back half only: it is in the water, not ringed by it.
      final ang = math.pi * (0.5 + _h(i + k * 26, 40)) + t * 2;
      final r = 7 + 7 * _h(i + k * 26, 41);
      g.add(
        carried[k].dx + r * math.cos(ang),
        carried[k].dy + r * math.sin(ang) * 0.9,
        1.6,
        _al(const Color(0xFFE6FAFF), 0.5 + 0.4 * _h(i, 42)),
      );
    }
  }
  // Spray thrown ahead of the crest.
  for (var i = 0; i < 420; i++) {
    final age = _h(i, 50) * 0.45;
    final tau = t - age;
    if (tau < 0) continue;
    final s = _h(i, 51) * 1.7 - 0.85;
    final v = 50 + 70 * _h(i, 52);
    final d = v * (1 - math.exp(-4 * age)) / 4;
    final x = path.x(tau) + front(s) + 3 + d;
    final y = _py + s * hh + s * d * 0.5;
    g.add(
      x,
      y,
      1.5,
      _al(
        _h(i, 53) < 0.5 ? const Color(0xFFFFFFFF) : const Color(0xFFA6EDFA),
        (1 - age / 0.45) * 0.85 * (1 - _sm(0.7, 0.85, s.abs())),
      ),
    );
  }
  g.flush(c);
}

// ── Lava: molten cells rolling, a pool where it bites ──────────────────────

Color _lavaTone(double seam, double heat) {
  if (seam < 1.8) {
    return heat > 0.45 ? const Color(0xFFFFF2B8) : const Color(0xFFFFC53A);
  }
  if (seam < 4.2) return const Color(0xFFFF7A1E);
  if (seam < 6.6) return const Color(0xFFC92F0E);
  return const Color(0xFF1C0B0B);
}

/// A pool of lava on the ground: cells of crust with the melt glowing in
/// the seams, dense enough at a small size that the cells read.
void _lavaPool(_G g, Offset o, double r, double t, int salt, double a) {
  final seeds = <Offset>[];
  for (var k = 0; k < 7; k++) {
    final pr = r * 0.66 * math.sqrt((k + 0.5) / 7);
    final pa = k * 2.399 + salt * 1.7;
    seeds.add(
      Offset(pr * math.cos(pa), pr * math.sin(pa)) +
          Offset(math.sin(t * 0.4 + k), math.cos(t * 0.33 + k)) * 1.5,
    );
  }
  final n = (r * r * 0.62).round();
  for (var i = 0; i < n; i++) {
    final u = math.sqrt(_h(i, 200 + salt));
    if (u > 0.72 && _h(i, 201 + salt) < (u - 0.72) / 0.28) continue;
    final ang = _h(i, 202 + salt) * _tau;
    final lx = r * u * math.cos(ang), ly = r * u * math.sin(ang);
    var d1 = 1e9, d2 = 1e9;
    for (final p in seeds) {
      final d = (Offset(lx, ly) - p).distance;
      if (d < d1) {
        d2 = d1;
        d1 = d;
      } else if (d < d2) {
        d2 = d;
      }
    }
    final seam = (d2 - d1) / (r / 46);
    final pulse = 0.5 + 0.5 * math.sin(t * 1.6 + i * 0.37);
    final col = seam < 1.6 + 0.8 * pulse
        ? const Color(0xFFFFE9A8)
        : (seam < 4.2
              ? const Color(0xFFFF9A2A)
              : (seam < 7.0
                    ? const Color(0xFFD2401A)
                    : const Color(0xFF1A0C0A)));
    g.add(o.dx + lx, o.dy + ly * 0.82, 2.1, _al(col, a));
  }
}

void _lava(Canvas c, int m) {
  const path = _Path(40, 210);
  final t = const [0.5, 1.35, 2.4][m];
  final cx = path.x(t);
  const r = 31.0;
  final g = _G();

  // A pool where each body was pierced (the game's Lava ground).
  final bit = <int>[];
  for (var e = 0; e < _foes.length; e++) {
    final f = _foes[e];
    if ((f.dy - _py).abs() > 32) continue;
    final tHit = path.reach(f.dx, r * 0.4);
    if (t < tHit) continue;
    bit.add(e);
  }
  for (final e in bit) {
    final f = _foes[e];
    final grow = _sm(0, 0.4, t - path.reach(f.dx, r * 0.4));
    _lavaPool(g, f, 46 * (0.4 + 0.6 * grow), t, e, grow);
  }
  g.flush(c);

  // Drips shed off its trailing side, cooling where they fall.
  // A dribble off its back: a short run of melt just behind it that
  // breaks into drops as it falls back, each cooling where it lies.
  for (var i = 0; i < 900; i++) {
    final drop = i ~/ 9;
    final fresh = _h(i, 67) < 0.3;
    final age = (fresh ? _h(i, 60) * 0.18 : _h(drop, 60) * 1.0);
    final tau = t - age;
    if (tau < 0.06) continue;
    final across = fresh
        ? (_h(i, 61) * 2 - 1) * r * 0.22
        : (_h(drop, 61) * 2 - 1) * r * 0.36;
    final ang = _h(i, 63) * _tau;
    final d = fresh ? 0.0 : (1 + 2.5 * _h(drop, 65)) * math.sqrt(_h(i, 64));
    final x = path.x(tau) - r * 0.72 + d * math.cos(ang) * 1.3;
    final y = _py + across + d * math.sin(ang);
    final col = age < 0.1
        ? const Color(0xFFFFE9A0)
        : (age < 0.28
              ? const Color(0xFFFFA22E)
              : (age < 0.55
                    ? const Color(0xFFE0451A)
                    : (age < 0.8
                          ? const Color(0xFF7A1A0C)
                          : const Color(0xFF2A0A08))));
    g.add(x, y, 2.0, _al(col, 1 - _sm(0.75, 1.0, age)));
  }

  // A splash where it bites, then the bodies burn.
  for (var e = 0; e < _foes.length; e++) {
    final f = _foes[e];
    final burning = bit.contains(e);
    if (burning) {
      final age = t - path.reach(f.dx, r * 0.4);
      if (age < 0.35) {
        for (var i = 0; i < 46; i++) {
          final ang = _h(i, 70 + e) * _tau;
          final d = 8 + 30 * _sm(0, 0.3, age) * (0.4 + 0.6 * _h(i, 71 + e));
          g.add(
            f.dx + d * math.cos(ang),
            f.dy + d * math.sin(ang) * 0.85,
            2.0,
            _al(const Color(0xFFFFB13A), 1 - age / 0.35),
          );
        }
      }
    }
    _foe(g, f, salt: e * 7);
    if (burning) {
      for (var i = 0; i < 8; i++) {
        final fl = math.sin(t * 9 + i * 2.1 + e);
        if (fl < 0) continue;
        g.add(
          f.dx + (_h(i, 75 + e) - 0.5) * 16,
          f.dy - 4 - 10 * ((t * 1.3 + _h(i, 76 + e)) % 1.0),
          1.8,
          _al(const Color(0xFFFFC53A), fl),
        );
      }
    }
  }
  g.flush(c);

  // The mass: cells of molten rock rolling over, the seams white-hot on
  // its leading face, dark crust plates riding the cells round to its back.
  _shadow(g, Offset(cx, _py), r * 1.05);
  final roll = t * 0.42;
  final seeds = <Offset>[];
  for (var k = 0; k < 11; k++) {
    final u = (_h(k, 80) - roll) % 1.0;
    final th = (u - 0.5) * math.pi;
    seeds.add(Offset(r * math.sin(th), (_h(k, 81) * 2 - 1) * r * 0.95));
  }
  _lump(
    g,
    Offset(cx, _py),
    1900,
    600,
    (a) => r * (1 + 0.05 * math.sin(4 * a)),
    (s, lx, ly, u) {
      var d1 = 1e9, d2 = 1e9;
      for (final p in seeds) {
        final d = (Offset(lx, ly) - p).distance;
        if (d < d1) {
          d2 = d1;
          d1 = d;
        } else if (d < d2) {
          d2 = d;
        }
      }
      // Seams look narrower toward the limb, where the surface turns away.
      final seam = (d2 - d1) / (0.45 + 0.55 * math.sqrt(1 - u * u));
      final heat = 0.5 + 0.5 * lx / r;
      var col = _lavaTone(seam, heat);
      if (u > 0.8 && seam >= 1.8) col = Color.lerp(col, _ink, 0.45)!;
      return col;
    },
    size: 2.3,
  );
  // Heat lifting off it: a few motes, flickering.
  for (var i = 0; i < 46; i++) {
    final q = (t * 0.9 + _h(i, 90)) % 1.0;
    final ang = _h(i, 91) * _tau;
    final d = r * 0.9 + 22 * q;
    final fl = 0.5 + 0.5 * math.sin(t * 11 + i * 1.3);
    g.add(
      cx + d * math.cos(ang) - 14 * q,
      _py + d * math.sin(ang) * 0.85,
      1.7,
      _al(
        q < 0.4 ? const Color(0xFFFFC53A) : const Color(0xFFE0451A),
        (1 - q) * fl * 0.9,
      ),
    );
  }
  g.flush(c);
}

// ── Ice: a ball of rime that freezes what it touches ───────────────────────

void _iceNeedle(
  _G g,
  Offset base,
  double ang,
  double len,
  double a, {
  double width = 2.0,
  bool branches = true,
  int salt = 0,
}) {
  final dx = math.cos(ang), dy = math.sin(ang);
  final steps = (len / 1.3).round();
  for (var s = 0; s <= steps; s++) {
    final f = s / math.max(1, steps);
    final p = base + Offset(dx, dy) * (len * f);
    final wv = width * (1 - f);
    final col = Color.lerp(
      const Color(0xFF7CC6EA),
      const Color(0xFFF2FCFF),
      f,
    )!;
    g.add(p.dx, p.dy, 1.9, _al(col, a * (0.6 + 0.4 * f)));
    if (wv > 0.8) {
      g.add(p.dx - dy * wv, p.dy + dx * wv, 1.6, _al(col, a * 0.5));
      g.add(p.dx + dy * wv, p.dy - dx * wv, 1.6, _al(col, a * 0.5));
    }
    // Side feathers, swept toward the tip: a frond, not a spike.
    if (branches && s > 2 && s % 3 == 0 && f < 0.85) {
      final bl = len * 0.28 * (1 - f);
      for (final side in const [-1.0, 1.0]) {
        final ba = ang + side * 0.75;
        for (var j = 1; j <= (bl / 1.3).round(); j++) {
          final q = p + Offset(math.cos(ba), math.sin(ba)) * (j * 1.3);
          g.add(q.dx, q.dy, 1.5, _al(const Color(0xFFBDEBFF), a * 0.7));
        }
      }
    }
  }
  g.add(
    base.dx + dx * len,
    base.dy + dy * len,
    2.4,
    _al(const Color(0xFFFFFFFF), a),
  );
}

void _ice(Canvas c, int m) {
  const path = _Path(40, 200);
  final t = const [0.55, 1.4, 2.5][m];
  final cx = path.x(t);
  const r = 21.0;
  final g = _G();

  // Rime left on the floor: a fine frost thinning to the sides, with a
  // few needles lying in it along the track, going grey as they melt.
  for (var i = 0; i < 1400; i++) {
    final age = _h(i, 16) * 1.7;
    final tau = t - age;
    if (tau < 0.08) continue;
    final side = _h(i, 17) * 2 - 1;
    final w = side.sign * math.pow(side.abs(), 1.6) * r * 1.2;
    final a = (1 - age / 1.7) * (1 - side.abs() * 0.7) * 0.7;
    g.add(
      path.x(tau) - 4 + (_h(i, 18) - 0.5) * 10,
      _py + w,
      1.4,
      _al(age < 0.7 ? const Color(0xFFBDE6F7) : const Color(0xFF4F8DB4), a),
    );
  }
  for (var k = 0; k < 46; k++) {
    final age = _h(k, 10) * 1.7;
    final tau = t - age;
    if (tau < 0.08) continue;
    final at = Offset(
      path.x(tau) - 6 + (_h(k, 11) - 0.5) * 14,
      _py + (_h(k, 12) * 2 - 1) * r * 0.9,
    );
    final a = (1 - age / 1.7) * 0.85;
    final ang = math.pi + (_h(k, 13) - 0.5) * 0.7;
    final len = 4 + 8 * _h(k, 15);
    for (var s = 0; s <= (len / 1.4).round(); s++) {
      final p = at + Offset(math.cos(ang), math.sin(ang)) * (s * 1.4);
      g.add(
        p.dx,
        p.dy,
        1.6,
        _al(age < 0.6 ? const Color(0xFFD6F3FF) : const Color(0xFF6FA7CC), a),
      );
    }
  }
  // Cold breath trailing off it.
  for (var i = 0; i < 380; i++) {
    final age = _h(i, 20) * 0.9;
    final tau = t - age;
    if (tau < 0.05) continue;
    final side = _h(i, 21) * 2 - 1;
    g.add(
      path.x(tau) - r * 0.8 - 10 * age,
      _py + side * (r * 0.7 + 18 * age),
      1.4,
      _al(const Color(0xFFD7F4FF), (1 - age / 0.9) * 0.35),
    );
  }

  // Bodies it touched are frozen where they stand: pale, a crust of needles.
  final frozen = <(Offset, double, int)>[];
  for (var e = 0; e < _foes.length; e++) {
    final f = _foes[e];
    final touched = (f.dy - _py).abs() < 32;
    final age = t - path.reach(f.dx, r * 0.6);
    final isFrozen = touched && age > 0;
    if (isFrozen) {
      for (var i = 0; i < 80; i++) {
        final rho = math.pow(_h(i, 30 + e), 0.7) * 17;
        final ang = _h(i, 31 + e) * _tau;
        g.add(
          f.dx + rho * math.cos(ang),
          f.dy + rho * math.sin(ang) * 0.85,
          1.7,
          _al(const Color(0xFF6FB8DD), 0.55 * _sm(0, 0.3, age)),
        );
      }
      frozen.add((f, age, e));
    }
    _foe(
      g,
      f,
      salt: e * 7,
      tint: const Color(0xFFCDEFFF),
      tintK: isFrozen ? 0.75 * _sm(0, 0.25, age) : 0,
    );
  }
  for (final (f, age, e) in frozen) {
    // Frost grows out of the side the ball came from, uneven: a crust,
    // not a star round it.
    final grow = _sm(0, 0.35, age);
    final side = f.dy < _py ? -1.0 : 1.0;
    for (var j = 0; j < 4; j++) {
      final ang =
          math.pi + side * (0.2 + j * 0.42) + (_h(j, 40 + e) - 0.5) * 0.3;
      _iceNeedle(
        g,
        f + Offset(math.cos(ang), math.sin(ang)) * 5,
        ang,
        (5 + 9 * _h(j, 41 + e)) * grow,
        0.95,
        width: 1.3,
        branches: false,
      );
    }
  }
  g.flush(c);

  // The ball: packed rime, lit pale on its upper face, blue in shadow, and
  // fronds of frost swept back off it by its flight.
  _shadow(g, Offset(cx, _py), r * 1.1);
  for (var k = 0; k < 15; k++) {
    final back = k < 11;
    final ang = back
        ? math.pi + (_h(k, 50) * 2 - 1) * 1.05
        : (_h(k, 50) * 2 - 1) * 1.3;
    final len =
        (back ? 14 + 26 * _h(k, 51) : 5 + 6 * _h(k, 51)) *
        (0.92 + 0.08 * math.sin(t * 1.7 + k));
    _iceNeedle(
      g,
      Offset(cx, _py) + Offset(math.cos(ang), math.sin(ang)) * r * 0.7,
      ang + (back ? (_h(k, 52) - 0.5) * 0.3 : 0),
      len,
      0.95,
      width: back ? 2.2 : 1.4,
      branches: back,
      salt: k,
    );
  }
  _lump(
    g,
    Offset(cx, _py),
    1300,
    700,
    (a) => r * (1 + 0.08 * math.sin(5 * a + 1)),
    (s, lx, ly, u) {
      final sparkle = math.sin(t * 6 + lx * 1.3 + ly * 0.7);
      if (s > 0.5 && sparkle > 0.92) return const Color(0xFFFFFFFF);
      return s > 0.42
          ? const Color(0xFFE6F8FF)
          : (s > 0.12
                ? const Color(0xFF9AD8F0)
                : (s > -0.2
                      ? const Color(0xFF3F84AE)
                      : const Color(0xFF173650)));
    },
    size: 2.2,
  );
  g.flush(c);
}

// ── Dark: a hole that drags them in and eats the weak ──────────────────────

void _dark(Canvas c, int m) {
  const path = _Path(40, 160);
  final t = const [0.5, 1.25, 2.65][m];
  final cx = path.x(t);
  const hole = 11.0, reach = 81.0;
  final g = _G();
  final b = Offset(cx, _py);

  // Dust it drags along in its wake, settling.
  for (var i = 0; i < 700; i++) {
    final age = _h(i, 20) * 1.3;
    final tau = t - age;
    if (tau < 0.05) continue;
    final side = _h(i, 21) * 2 - 1;
    final birth = Offset(
      path.x(tau) - 20 * _h(i, 22),
      _py + side * (20 + 40 * _h(i, 23)),
    );
    final toward = b - birth;
    final p = birth + toward * (0.18 * (1 - math.exp(-1.5 * age)));
    final dir = toward / toward.distance;
    final a = (1 - age / 1.3) * 0.55;
    g.add(p.dx, p.dy, 1.6, _al(const Color(0xFF5A35A8), a));
    g.add(
      p.dx - dir.dx * 3,
      p.dy - dir.dy * 3,
      1.4,
      _al(const Color(0xFF3A2470), a * 0.6),
    );
  }
  g.flush(c);

  // The disc of what it is drawing in: two loose arms winding into the
  // lip, faint far out and lit close in, every grain a short run along its
  // orbit, the outer turns lagging as it moves. The lip is lit on the side
  // it is moving toward and broken on the other.
  for (var i = 0; i < 3400; i++) {
    final r0 = hole + 66 * math.pow(_h(i, 30), 1.5);
    final q = (_h(i, 31) + t * 0.45 * math.sqrt(30 / (r0 + 4))) % 1.0;
    final rr = hole + (r0 - hole) * (1 - q);
    final om = 3.2 * math.pow(18 / rr, 1.5);
    final ang = _h(i, 32) * _tau + t * om;
    final arm = math.cos(2 * (ang - 2.3 * math.log(rr / hole)));
    if (arm < -0.1 && _h(i, 33) < 0.75) continue;
    final out = rr - hole;
    final lag = -0.004 * out * out;
    double px(double a) => cx + rr * math.cos(a) * 1.08 + lag;
    double py(double a) =>
        _py + rr * math.sin(a) * 0.82 + 0.06 * out * out / 10;
    final side = 0.55 + 0.45 * math.cos(ang + 0.5);
    if (out < 4 && _h(i, 34) > side) continue;
    final a = _sm(0, 0.15, q) * (0.55 + 0.45 * side);
    final col = out < 3
        ? const Color(0xFFF4EDFF)
        : (out < 8
              ? const Color(0xFFC9B0FF)
              : (out < 20
                    ? const Color(0xFF8A5CE6)
                    : (out < 36
                          ? const Color(0xFF5A33A8)
                          : const Color(0xFF2E1A66))));
    final fade = out > 36 ? 0.7 : 1.0;
    g.add(px(ang), py(ang), out < 8 ? 2.1 : 1.8, _al(col, a * fade));
    g.add(px(ang - 0.1), py(ang - 0.1), 1.5, _al(col, a * fade * 0.5));
  }
  for (var i = 0; i < 520; i++) {
    final rho = math.sqrt(_h(i, 40)) * hole;
    final ang = _h(i, 41) * _tau;
    g.add(
      cx + rho * math.cos(ang) * 1.08,
      _py + rho * math.sin(ang) * 0.82,
      2.6,
      const Color(0xFF020104),
    );
  }
  g.flush(c);

  // The bodies, pulled by the game's own rule, stepped from the cast. The
  // two weakest are eaten when they reach the lip; the rest are held in
  // its pull, smeared toward it.
  const weak = {2, 0};
  for (var e = 0; e < _foes.length; e++) {
    var p = _foes[e];
    double? eatenAt;
    for (var s = 0.0; s < t; s += 1 / 60) {
      final bs = Offset(path.x(s), _py);
      final d = (bs - p).distance;
      if (weak.contains(e) && d < hole + 6) {
        eatenAt = s;
        break;
      }
      if (d < 4 || d > reach) continue;
      final k = 1 - d / reach;
      if (!weak.contains(e) && d < hole + 18) continue;
      p += (bs - p) / d * ((60 + 220 * k) / 60);
    }
    if (eatenAt != null) {
      // Its grains spiral in and are gone.
      final q = ((t - eatenAt) / 0.7).clamp(0.0, 1.0);
      if (q >= 1) continue;
      for (var i = 0; i < 70; i++) {
        final r0 = hole + 8 + 8 * _h(i, 300 + e * 7);
        final f = math.min(1.0, q * (0.7 + 0.6 * _h(i, 310 + e)));
        final rr = hole + (r0 - hole) * math.pow(1 - f, 1.4);
        final ang = _h(i, 301 + e * 7) * _tau + 7 * f;
        g.add(
          b.dx + rr * math.cos(ang),
          b.dy + rr * math.sin(ang),
          1.9,
          _al(
            Color.lerp(const Color(0xFFB9B0D6), const Color(0xFFE8DCFF), f)!,
            1 - f,
          ),
        );
      }
      continue;
    }
    final d = (b - p).distance;
    final pull = d < reach ? (1 - d / reach) : 0.0;
    _foe(g, p, salt: e * 7, stretch: (b - p) / d * (18 * pull));
    // What it is losing: its grains drawn off it in a current curling into
    // the lip.
    if (pull > 0.1) {
      final dir = (b - p) / d;
      final nrm = Offset(-dir.dy, dir.dx);
      for (var i = 0; i < 60; i++) {
        final q = (_h(i, 320 + e) + t * 1.3) % 1.0;
        final along = (d - hole - 2) * math.pow(q, 1.3);
        final curl = 7 * math.sin(q * math.pi) * (1 + _h(i, 321 + e));
        final at = p + dir * along + nrm * curl;
        g.add(
          at.dx,
          at.dy,
          q < 0.5 ? 1.9 : 1.6,
          _al(
            Color.lerp(const Color(0xFFB9B0D6), const Color(0xFFC9B0FF), q)!,
            (1 - q) * math.min(1.0, pull * 2.2),
          ),
        );
      }
    }
  }
  g.flush(c);
}

// ── Blood: a clot that sends what it takes home ────────────────────────────

const _orb = Offset(-40, 150);

void _blood(Canvas c, int m) {
  const path = _Path(40, 210);
  final t = const [0.5, 1.35, 2.4][m];
  final cx = path.x(t);
  const r = 24.0;
  final g = _G();

  final hits = <(int, double)>[];
  for (var e = 0; e < _foes.length; e++) {
    final f = _foes[e];
    if ((f.dy - _py).abs() > 32) continue;
    final tHit = path.reach(f.dx, r * 0.5);
    if (t > tHit) hits.add((e, tHit));
  }

  // The orb at home (scenery: where the blood is going).
  c.drawCircle(
    _orb,
    120,
    Paint()
      ..shader = ui.Gradient.radial(
        _orb,
        120,
        [
          const Color(0xFF39D6EC).withValues(alpha: 0.55),
          const Color(0xFF1B6E86).withValues(alpha: 0.18),
          const Color(0x0018242A),
        ],
        const [0, 0.5, 1],
      ),
  );

  // Spatter on the floor behind it, going dark.
  for (var k = 0; k < 90; k++) {
    final age = _h(k, 10) * 1.6;
    final tau = t - age;
    if (tau < 0.06) continue;
    final at = Offset(
      path.x(tau) - r * 0.5 - 14 * _h(k, 11),
      _py + (_h(k, 12) * 2 - 1) * r * 1.35,
    );
    final ang = math.pi + (_h(k, 13) - 0.5) * 1.6;
    final col = age < 0.25
        ? const Color(0xFFE8253A)
        : (age < 0.8 ? const Color(0xFF8A0C1A) : const Color(0xFF45060C));
    final a = 1 - _sm(1.2, 1.6, age);
    for (var j = 0; j < 4; j++) {
      g.add(
        at.dx + math.cos(ang) * j * 1.5,
        at.dy + math.sin(ang) * j * 1.5,
        j == 0 ? 2.2 : 1.6,
        _al(col, a * (1 - j * 0.18)),
      );
    }
  }

  // The bodies it went through, and a burst out of each.
  for (var e = 0; e < _foes.length; e++) {
    final f = _foes[e];
    double? tHit;
    for (final (he, th) in hits) {
      if (he == e) tHit = th;
    }
    _foe(
      g,
      f,
      salt: e * 7,
      tint: const Color(0xFF8A2A36),
      tintK: tHit == null ? 0 : 0.3 * (1 - _sm(0.4, 1.2, t - tHit)),
    );
    if (tHit != null && t - tHit < 0.4) {
      final age = t - tHit;
      for (var i = 0; i < 36; i++) {
        final ang = _h(i, 20 + e) * _tau;
        final d = 6 + 22 * _sm(0, 0.35, age) * (0.4 + 0.6 * _h(i, 21 + e));
        g.add(
          f.dx + d * math.cos(ang),
          f.dy + d * math.sin(ang),
          1.8,
          _al(const Color(0xFFFF4A5A), 1 - age / 0.4),
        );
      }
    }
  }
  g.flush(c);

  // What each pierced body gives runs home to the orb: a loose current of
  // separate drops, each at its own pace, spreading wide in the middle of
  // the run and gathering again as they arrive.
  for (var hi = 0; hi < hits.length; hi++) {
    final (e, tHit) = hits[hi];
    final p0 = _foes[e];
    final p2 = _orb + Offset(80, (p0.dy - _py) * 0.4);
    final ctrl = Offset(
      (p0.dx + p2.dx) / 2,
      _py - 60 - 22 * hi + (p0.dy - _py) * 0.5,
    );
    Offset at(double p) {
      final u = 1 - p;
      return p0 * (u * u) + ctrl * (2 * u * p) + p2 * (p * p);
    }

    // Four strands braiding: each drop keeps to its strand, so the run
    // reads as one current, and each trails a short tail so it moves.
    for (var i = 0; i < 72; i++) {
      final strand = i % 4;
      // Each drop at its own pace, so they bunch and string out.
      final dur = 0.7 + 0.6 * _h(i, 34 + e);
      final age = t - (tHit + _h(i, 35 + e) * 0.7);
      if (age < 0 || age > dur) continue;
      final lin = age / dur;
      final p = lin * lin * (3 - 2 * lin);
      Offset point(double pp) {
        final q0 = at(pp), q1 = at(math.min(1.0, pp + 0.01));
        final tan = q1 - q0;
        final tl = math.max(tan.distance, 1e-6);
        final lateral =
            math.sin(pp * math.pi) *
            (9 * math.sin(strand * 1.7 + pp * 5 + t * 1.5) +
                4 * (_h(i, 36 + e) - 0.5));
        return q0 + Offset(-tan.dy / tl, tan.dx / tl) * lateral;
      }

      final a = 1 - _sm(0.88, 1.0, p);
      for (var j = 0; j < 3; j++) {
        final q = point(math.max(0.0, p - j * 0.008));
        g.add(
          q.dx,
          q.dy,
          j == 0 ? 2.3 : 1.6,
          _al(
            j == 0 && strand == 1
                ? const Color(0xFFFFB8C0)
                : const Color(0xFFFF3A4A),
            a * (1 - j * 0.19),
          ),
        );
      }
    }
  }

  // The clot: packed dark blood, a wet light on its upper face, veins
  // through it with the beat running out along them past its edge.
  final beat = math.pow(0.5 + 0.5 * math.sin(t * 7), 3).toDouble();
  final rr = r * (1 + 0.05 * beat);
  _shadow(g, Offset(cx, _py), rr * 1.05);
  _lump(
    g,
    Offset(cx, _py),
    1500,
    800,
    (a) => rr * (1 + 0.1 * math.sin(3 * a + 0.5) + 0.06 * math.sin(5 * a)),
    (s, lx, ly, u) {
      // A wet glint or two, not a pale cap.
      if (s > 0.68 && math.sin(lx * 1.9 + ly * 2.7) > 0.9) {
        return const Color(0xFFFFB3B3);
      }
      return s > 0.52
          ? const Color(0xFFE02436)
          : (s > 0.08
                ? const Color(0xFF9A0E1E)
                : (s > -0.25
                      ? const Color(0xFF5A0610)
                      : const Color(0xFF2A0306)));
    },
    size: 2.3,
  );
  for (var v = 0; v < 3; v++) {
    final a0 = v * 2.1 + 0.4 + t * 0.15;
    final len = rr * (1.05 + 0.3 * _h(v, 50));
    for (var s = 0.0; s < len; s += 1.3) {
      final f = s / len;
      final ang = a0 + 0.5 * math.sin(f * 3 + v);
      final x = cx + s * math.cos(ang);
      final y = _py + s * math.sin(ang);
      final pulse = 0.5 + 0.5 * math.sin(s * 0.3 - t * 7);
      final out = s > rr * 0.9 ? 1 - _sm(rr * 0.9, len, s) : 1.0;
      g.add(
        x,
        y,
        s > rr ? 1.6 : 2.0,
        _al(const Color(0xFFFF4A5A), (0.45 + 0.55 * pulse) * out),
      );
      if (s > rr * 0.6 && s < len * 0.85 && (s ~/ 1.3) % 7 == 3) {
        final ba = ang + (v.isEven ? 0.8 : -0.8);
        for (var j = 1; j < 5; j++) {
          g.add(
            x + math.cos(ba) * j * 1.3,
            y + math.sin(ba) * j * 1.3,
            1.5,
            _al(const Color(0xFFFF4A5A), (1 - j / 5) * out * 0.8),
          );
        }
      }
    }
  }
  g.flush(c);
}

// ── Sheet ──────────────────────────────────────────────────────────────────

void _label(Canvas c, Offset at, String text, {double size = 15, Color? col}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontSize: size,
        color: col ?? const Color(0xFFE8D7A8),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at);
}

void main() {
  final out = Platform.environment['MANE_OUT'];

  testWidgets('mane shot design frames', (tester) async {
    if (out == null) return;
    await tester.runAsync(() async {
      final font = File('/System/Library/Fonts/Supplemental/Georgia.ttf');
      if (font.existsSync()) {
        await (FontLoader('Georgia')..addFont(
              Future.value(ByteData.view(font.readAsBytesSync().buffer)),
            ))
            .load();
      }
    });
    final rows = <(String, String, void Function(Canvas, int))>[
      ('Earth', 'starts huge, breaks apart, throws stones as it goes', _earth),
      ('Water', 'a wall of water that takes them with it', _water),
      ('Lava', 'a pool of lava where each body is pierced', _lava),
      ('Ice', 'freezes everything it touches', _ice),
      ('Dark', 'drags them in, eats the weak', _dark),
      ('Blood', 'each body pierced sends blood home to the orb', _blood),
    ];
    const moments = ['in flight', 'the pierce', 'what it leaves'];
    final only = Platform.environment['MANE_ONLY']?.split(',');
    final shown = only == null
        ? rows
        : rows.where((r) => only.contains(r.$1)).toList();
    const s = 1.25;
    const tw = _w * s, th = _hgt * s, gap = 4.0;
    final size = Size(3 * tw + 2 * gap, shown.length * (th + gap) - gap);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(Offset.zero & size, Paint()..color = _ink);
    for (var ri = 0; ri < shown.length; ri++) {
      for (var mi = 0; mi < 3; mi++) {
        final r = Rect.fromLTWH(mi * (tw + gap), ri * (th + gap), tw, th);
        canvas.save();
        canvas.clipRect(r);
        canvas.drawRect(r, Paint()..color = _floor);
        canvas.save();
        canvas.translate(r.left, r.top);
        canvas.scale(s);
        shown[ri].$3(canvas, mi);
        canvas.restore();
        _label(
          canvas,
          r.topLeft + const Offset(14, 10),
          mi == 0 ? '${shown[ri].$1}  ·  ${moments[mi]}' : moments[mi],
        );
        if (mi == 0) {
          _label(
            canvas,
            r.topLeft + const Offset(14, 32),
            shown[ri].$2,
            size: 12,
            col: const Color(0xFF9FB3B8),
          );
        }
        canvas.restore();
      }
    }
    final img = rec.endRecording().toImageSync(
      size.width.round(),
      size.height.round(),
    );
    await tester.runAsync(() async {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
