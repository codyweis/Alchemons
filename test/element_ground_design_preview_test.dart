@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// DESIGN FRAMES ONLY: what an element leaves on the ground, redrawn with no
// outline. Today every ground effect is a rounded patch with things drawn on
// it, and the patch is what the eye reads: a blob. Here nothing has an edge.
// Each is grains whose density, direction and light make the shape, thinning
// to nothing at the rim, and each element has a form of its own: fire is
// tongues, lava is cells, water is rings, ice is needles, a plant is leaves,
// lightning is branches.
//
// Nothing here is in the game.
//
//   GROUND_OUT=docs/ability_vfx_audit/ground_designs_1110.png flutter test \
//     test/element_ground_design_preview_test.dart --tags preview

const _floor = Color(0xFF18242A);
const _ink = Color(0xFF07060B);
const _white = Color(0xFFFFF6E4);
const _tau = math.pi * 2;

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// Grains bucketed by colour and size, drawn in the order first added.
class _G {
  final _m = <(int, int), List<double>>{};
  static final _p = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void add(double x, double y, double d, Color c) =>
      (_m[(c.toARGB32(), (d * 10).round())] ??= [])
        ..add(x)
        ..add(y);

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

void _pool(Canvas c, Offset o, double r, Color col, double a) {
  c.drawCircle(
    o,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        o,
        r,
        [col.withValues(alpha: a), col.withValues(alpha: 0)],
      ),
  );
}

/// A scatter of grains densest at the middle and gone by [r]: the ground
/// under an effect, with no edge to it.
void _bed(
  _G g,
  Offset o,
  double r,
  int n,
  Color col, {
  int salt = 0,
  double fall = 0.75,
  double squash = 0.8,
  double size = 2.2,
}) {
  for (var i = 0; i < n; i++) {
    final rho = math.pow(_h(i, 1 + salt), fall) * r;
    final a = _h(i, 2 + salt) * _tau;
    final k = 1 - rho / r;
    g.add(
      o.dx + rho * math.cos(a),
      o.dy + rho * math.sin(a) * squash,
      size,
      col.withValues(alpha: (0.35 + 0.65 * k) * col.a),
    );
  }
}

// ── Fire: tongues ──────────────────────────────────────────────────────────

void _fire(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 120.0;
  _bed(g, o, r, 1500, const Color(0xFF0B0809), salt: 3, fall: 0.62, size: 2.6);
  g.flush(c);
  _pool(c, o, r * 0.55, const Color(0xFFFF6A1E), 0.4);
  // Embers through the char, each on its own clock.
  for (var i = 0; i < 420; i++) {
    final glow = math.sin(t * (4 + 3 * _h(i, 11)) + i * 1.9);
    if (glow < -0.2) continue;
    final rho = math.pow(_h(i, 12), 0.8) * r * 0.86;
    final a = _h(i, 13) * _tau;
    g.add(
      o.dx + rho * math.cos(a),
      o.dy + rho * math.sin(a) * 0.8,
      glow > 0.6 ? 2.6 : 2.0,
      glow > 0.6
          ? const Color(0xFFFFD27A)
          : (glow > 0.1 ? const Color(0xFFFF8A2E) : const Color(0xFFC2371A)),
    );
  }
  g.flush(c);
  // Tongues: each a stream of grains climbing off the bed, wide and white-
  // hot at the foot, drawn to a point that leans and sways.
  for (var j = 0; j < 9; j++) {
    final a = j * 2.399 + 0.4;
    final rho = r * 0.6 * math.sqrt((j + 0.5) / 9);
    final bx = o.dx + rho * math.cos(a), by = o.dy + rho * math.sin(a) * 0.8;
    final tall = 62 + 46 * _h(j, 21);
    final wide = 13 + 7 * _h(j, 22);
    for (var i = 0; i < 150; i++) {
      final s = (_h(i + j * 331, 23) + t * (0.55 + 0.3 * _h(j, 24))) % 1.0;
      // A flame's outline: full a little above the foot, then to a point.
      final half = wide * math.sin(math.pi * math.pow(s, 0.55)) * (1 - 0.55 * s);
      final across = (_h(i + j * 331, 25) * 2 - 1);
      final lean = 16 * s * s * math.sin(t * 2.3 + j * 1.7) + 7 * s * math.sin(t * 5 + j);
      final core = across.abs() < 0.45;
      final col = s < 0.22 && core
          ? const Color(0xFFFFF1C2)
          : (s < 0.5
                ? (core ? const Color(0xFFFFC24A) : const Color(0xFFFF8A2E))
                : (s < 0.8 ? const Color(0xFFF2551E) : const Color(0xFF9E2414)));
      g.add(
        bx + across * half + lean,
        by - s * tall,
        s < 0.5 ? 2.5 : 2.0,
        col.withValues(alpha: s < 0.8 ? 1 : 1 - (s - 0.8) / 0.2),
      );
    }
  }
  // Sparks let go above the flames.
  for (var i = 0; i < 46; i++) {
    final s = (_h(i, 31) + t * 0.3) % 1.0;
    g.add(
      o.dx + (_h(i, 32) - 0.5) * r * 1.5 + 10 * math.sin(t * 2 + i),
      o.dy - 60 - s * 110,
      1.7,
      const Color(0xFFFFB45A).withValues(alpha: 1 - s),
    );
  }
  g.flush(c);
}

// ── Lava: cells ────────────────────────────────────────────────────────────

void _lava(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 124.0;
  _pool(c, o, r * 0.95, const Color(0xFFFF5A14), 0.45);
  // Plates of crust: each a point the pool is divided round. A grain is
  // crust, the hot edge of a plate, or the molten seam between two.
  final seeds = <Offset>[
    for (var k = 0; k < 13; k++)
      Offset(
        math.cos(k * 2.399 + t * 0.05 * (k.isEven ? 1 : -1)) *
            r *
            0.8 *
            math.sqrt((k + 0.5) / 13),
        math.sin(k * 2.399 + t * 0.05 * (k.isEven ? 1 : -1)) *
            r *
            0.66 *
            math.sqrt((k + 0.5) / 13),
      ),
  ];
  for (var i = 0; i < 5200; i++) {
    final rho = math.pow(_h(i, 41), 0.58) * r;
    final a = _h(i, 42) * _tau;
    final x = rho * math.cos(a), y = rho * math.sin(a) * 0.82;
    var d1 = 1e9, d2 = 1e9;
    for (final s in seeds) {
      final d = (s - Offset(x, y)).distance;
      if (d < d1) {
        d2 = d1;
        d1 = d;
      } else if (d < d2) {
        d2 = d;
      }
    }
    final seam = d2 - d1;
    final rim = rho / r;
    // Cooled and scattering at the rim; nothing has an edge.
    if (rim > 0.78 && _h(i, 43) < (rim - 0.78) / 0.22) continue;
    final pulse = 0.5 + 0.5 * math.sin(t * 1.4 + d1 * 0.08);
    final Color col;
    double size = 2.3;
    if (seam < 5 + 3 * pulse) {
      col = const Color(0xFFFFE9A8);
      size = 2.6;
    } else if (seam < 12 + 4 * pulse) {
      col = const Color(0xFFFF9A2A);
    } else if (seam < 22) {
      col = const Color(0xFFD2401A);
    } else {
      // Crust, lit a little on the side toward the light.
      col = Color.lerp(
        const Color(0xFF120807),
        const Color(0xFF3A1A12),
        (0.5 - 0.5 * (x + y) / r).clamp(0.0, 1.0) * _h(i, 44),
      )!;
    }
    g.add(o.dx + x, o.dy + y, size, rim > 0.8 ? col.withValues(alpha: 0.75) : col);
  }
  g.flush(c);
  // Gas welling up through a seam, and heat lifting off.
  for (var i = 0; i < 7; i++) {
    final clock = t * 0.5 + _h(i, 51) * 3;
    final s = clock % 1.0;
    final at = seeds[(i * 2 + clock.floor()) % seeds.length] * 0.55;
    for (var k = 0; k < 16; k++) {
      final b = k * 2.399;
      final d = 14 * s * math.sqrt((k + 0.5) / 16);
      g.add(
        o.dx + at.dx + d * math.cos(b),
        o.dy + at.dy + d * math.sin(b) * 0.8 - 8 * s,
        2.6,
        const Color(0xFFFFF1C2).withValues(alpha: 1 - s),
      );
    }
  }
  for (var i = 0; i < 70; i++) {
    final s = (_h(i, 52) + t * 0.2) % 1.0;
    g.add(
      o.dx + (_h(i, 53) - 0.5) * r * 1.5 + 6 * math.sin(t + i),
      o.dy - s * 120,
      1.7,
      const Color(0xFFFF8A3A).withValues(alpha: 0.7 * (1 - s)),
    );
  }
  g.flush(c);
}

// ── Water: rings ───────────────────────────────────────────────────────────

void _water(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 124.0;
  _pool(c, o, r, const Color(0xFF1668A0), 0.6);
  _bed(g, o, r, 2600, const Color(0xFF0F3F66), salt: 5, fall: 0.6, size: 2.8);
  _bed(g, o, r * 0.55, 700, const Color(0xFF071A2C), salt: 6, fall: 0.7, size: 2.8);
  g.flush(c);
  // Rings going out from where something fell, broken and thinning, each
  // with a lit face toward the light and a dark one behind it.
  for (var k = 0; k < 5; k++) {
    final s = (k / 5 + t * 0.16) % 1.0;
    final rr = r * (0.08 + 0.9 * s);
    final n = (rr * 3.4).round();
    for (var i = 0; i < n; i++) {
      final a = i / n * _tau;
      // Broken in runs, not grain by grain, so a ring is water and not dots.
      if (_h((i ~/ 9) + k * 97, 61) < 0.12 + 0.35 * s) continue;
      final light = math.cos(a - math.pi * 1.25);
      final wob = 2.5 * math.sin(a * 5 + k + t);
      g.add(
        o.dx + (rr + wob) * math.cos(a),
        o.dy + (rr + wob) * math.sin(a) * 0.8,
        light > 0.3 ? 3.4 : 2.7,
        (light > 0.3
                ? const Color(0xFFCFF2FF)
                : (light > -0.3
                      ? const Color(0xFF5FB6E8)
                      : const Color(0xFF1F5F8E)))
            .withValues(alpha: 1 - 0.8 * s),
      );
      // The trough behind the crest.
      g.add(
        o.dx + (rr - 6 + wob) * math.cos(a),
        o.dy + (rr - 6 + wob) * math.sin(a) * 0.8,
        3.0,
        const Color(0xFF06182A).withValues(alpha: 0.9 * (1 - s)),
      );
    }
  }
  // Light on the surface, coming and going.
  for (var i = 0; i < 260; i++) {
    if (math.sin(t * (2 + 2 * _h(i, 62)) + i * 2.3) < 0.45) continue;
    final rho = math.pow(_h(i, 63), 0.7) * r * 0.85;
    final a = _h(i, 64) * _tau;
    g.add(
      o.dx + rho * math.cos(a),
      o.dy + rho * math.sin(a) * 0.8,
      2.2,
      const Color(0xFFE8FAFF),
    );
  }
  // Drops thrown up from the middle, falling back.
  for (var i = 0; i < 26; i++) {
    final s = (_h(i, 65) + t * 0.5) % 1.0;
    final a = _h(i, 66) * _tau;
    final out = 44 * s * (0.5 + _h(i, 67));
    g.add(
      o.dx + out * math.cos(a),
      o.dy + out * math.sin(a) * 0.8 - 70 * s * (1 - s) * 2,
      2.4,
      const Color(0xFFBFE9FF).withValues(alpha: 1 - s * 0.6),
    );
  }
  g.flush(c);
}

// ── Ice: needles ───────────────────────────────────────────────────────────

void _ice(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 126.0;
  _pool(c, o, r * 0.9, const Color(0xFF7FD4F2), 0.16);
  _bed(g, o, r, 700, const Color(0xFF9AD6EA).withValues(alpha: 0.5), salt: 7);
  g.flush(c);
  // Frost grows in straight needles, six ways, each needle throwing smaller
  // ones at the same angles: a fern of ice across the floor.
  void needle(Offset from, double a, double len, int depth, int id) {
    final n = (len / 2.6).round();
    for (var i = 0; i < n; i++) {
      final s = i / n;
      final p = from + Offset(math.cos(a), math.sin(a) * 0.86) * (len * s);
      final lit = math.cos(a - math.pi * 1.25) > 0;
      g.add(
        p.dx,
        p.dy,
        depth == 0 ? 3.0 - 1.2 * s : 2.2 - 0.8 * s,
        s > 0.9
            ? _white
            : (lit ? const Color(0xFFD8F6FF) : const Color(0xFF6DB7D8)),
      );
      // A shadow line beside it, so a needle is a ridge and not a mark.
      if (depth == 0) {
        g.add(p.dx + 2.4, p.dy + 2.4, 2.0, const Color(0xFF0B1F2C));
      }
    }
    if (depth >= 2) return;
    final twigs = depth == 0 ? 6 : 3;
    for (var k = 1; k <= twigs; k++) {
      final s = k / (twigs + 1);
      final at = from + Offset(math.cos(a), math.sin(a) * 0.86) * (len * s);
      final l = len * (0.42 - 0.26 * s) * (0.8 + 0.4 * _h(id * 31 + k, 71));
      needle(at, a + math.pi / 3, l, depth + 1, id * 7 + k);
      needle(at, a - math.pi / 3, l, depth + 1, id * 11 + k);
    }
  }

  final grow = 0.82 + 0.18 * math.sin(t * 0.8);
  for (var k = 0; k < 6; k++) {
    needle(o, k * math.pi / 3 + 0.26, r * 0.92 * grow, 0, k + 1);
  }
  // Glints that stand and come and go, and cold falling off it.
  for (var i = 0; i < 120; i++) {
    if (math.sin(t * (1.5 + 2 * _h(i, 72)) + i * 1.7) < 0.7) continue;
    final rho = math.pow(_h(i, 73), 0.7) * r * 0.9;
    final a = (_h(i, 74) * 6).floor() * math.pi / 3 + 0.26 + (_h(i, 75) - 0.5) * 0.5;
    g.add(o.dx + rho * math.cos(a), o.dy + rho * math.sin(a) * 0.86, 3.2, _white);
  }
  g.flush(c);
}

// ── Plant: leaves ──────────────────────────────────────────────────────────

void _plant(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 122.0;
  _bed(g, o, r * 0.9, 900, const Color(0xFF0C1A10), salt: 9, fall: 0.6, size: 2.6);
  g.flush(c);
  // A rosette: leaves laid out from the heart, each filled with grains,
  // lit on one side of its midrib and dark on the other, curling a little.
  for (var ring = 0; ring < 2; ring++) {
    final count = ring == 0 ? 7 : 6;
    for (var j = 0; j < count; j++) {
      final a = j * _tau / count + ring * 0.45 + 0.05 * math.sin(t * 0.9 + j);
      final len = ring == 0 ? r * 0.92 : r * 0.56;
      final wide = ring == 0 ? 20.0 : 15.0;
      final ca = math.cos(a), sa = math.sin(a);
      for (var i = 0; i < (ring == 0 ? 330 : 200); i++) {
        final s = _h(i + j * 211 + ring * 5000, 81);
        final across = _h(i + j * 211 + ring * 5000, 82) * 2 - 1;
        // A leaf's outline: a point at both ends, widest before the middle.
        final half = wide * math.sin(math.pi * math.pow(s, 0.7));
        final curl = 10 * s * s * math.sin(t * 0.7 + j);
        final along = len * (0.08 + 0.92 * s);
        final x = ca * along - sa * (across * half + curl);
        final y = sa * along + ca * (across * half + curl);
        final rib = across.abs() < 0.1;
        final lit = across * (ca - sa) < 0;
        g.add(
          o.dx + x,
          o.dy + y * 0.86,
          2.3,
          rib
              ? const Color(0xFF0E2A14)
              : (lit
                    ? Color.lerp(
                        const Color(0xFF7FD46A),
                        const Color(0xFFD9F7A8),
                        _h(i, 83) * (1 - s),
                      )!
                    : const Color(0xFF2E7A3A)),
        );
      }
    }
  }
  g.flush(c);
  // Tendrils feeling outward, and spores lifting.
  final line = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  for (var j = 0; j < 5; j++) {
    final a0 = j * _tau / 5 + 0.6;
    Offset? prev;
    for (var i = 0; i <= 26; i++) {
      final s = i / 26;
      final a = a0 + 0.95 * s * s + 0.25 * math.sin(t * 1.3 + j + s * 4);
      final p =
          o + Offset(math.cos(a), math.sin(a) * 0.86) * (r * (0.3 + 0.75 * s));
      if (prev != null) {
        c.drawLine(
          prev,
          p,
          line
            ..strokeWidth = 7 * (1 - 0.7 * s)
            ..color = const Color(0xFF2F8A3C),
        );
        c.drawLine(
          prev,
          p,
          line
            ..strokeWidth = 2.8 * (1 - 0.6 * s)
            ..color = const Color(0xFFB8F09A),
        );
      }
      prev = p;
    }
    g.add(prev!.dx, prev.dy, 5, const Color(0xFFE6FFC2));
  }
  for (var i = 0; i < 40; i++) {
    final s = (_h(i, 84) + t * 0.15) % 1.0;
    g.add(
      o.dx + (_h(i, 85) - 0.5) * r * 1.7 + 12 * math.sin(t * 0.8 + i),
      o.dy + (_h(i, 86) - 0.5) * r - s * 60,
      2.0,
      const Color(0xFFD9F7A8).withValues(alpha: math.sin(s * math.pi)),
    );
  }
  g.flush(c);
}

// ── Lightning: branches ────────────────────────────────────────────────────

void _lightning(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 126.0;
  _bed(g, o, r * 0.8, 800, const Color(0xFF0A0A14), salt: 11, fall: 0.6, size: 2.6);
  g.flush(c);
  _pool(c, o, r * 0.7, const Color(0xFF8E7BFF), 0.28);
  // Bolts walking out across the floor from the strike, forking as they go.
  // Which ones are lit changes several times a second.
  void bolt(Offset from, double a, double len, int depth, int id) {
    var p = from;
    var dir = a;
    final steps = (len / 7).round();
    final live = math.sin(t * 9 + id * 2.1) > -0.35;
    for (var i = 0; i < steps; i++) {
      dir += (_h(id * 53 + i, 91) - 0.5) * 1.3;
      // Pulled back toward its heading, so it wanders but arrives.
      dir += (a - dir) * 0.35;
      final q = p + Offset(math.cos(dir), math.sin(dir) * 0.86) * 7;
      for (var k = 0; k < 4; k++) {
        final m = Offset.lerp(p, q, k / 4)!;
        if (live) {
          g.add(m.dx, m.dy, depth == 0 ? 3.0 : 2.2, const Color(0xFFF4F0FF));
        }
        // The air round it, charged.
        g.add(
          m.dx + (_h(id * 53 + i * 4 + k, 92) - 0.5) * 9,
          m.dy + (_h(id * 53 + i * 4 + k, 93) - 0.5) * 9,
          2.0,
          const Color(0xFF8E7BFF).withValues(alpha: live ? 0.85 : 0.3),
        );
      }
      if (depth < 2 && _h(id * 53 + i, 94) < (depth == 0 ? 0.3 : 0.18)) {
        bolt(
          q,
          dir + (i.isEven ? 0.8 : -0.8),
          len * 0.42,
          depth + 1,
          id * 13 + i,
        );
      }
      p = q;
    }
    if (live) g.add(p.dx, p.dy, depth == 0 ? 5 : 3.4, _white);
  }

  for (var k = 0; k < 6; k++) {
    bolt(o, k * _tau / 6 + 0.3, r * 0.9, 0, k + 1);
  }
  // Specks lifted off the floor round it, shivering.
  for (var i = 0; i < 90; i++) {
    final rho = math.pow(_h(i, 95), 0.6) * r;
    final a = _h(i, 96) * _tau;
    g.add(
      o.dx + rho * math.cos(a) + 2 * math.sin(t * 20 + i),
      o.dy + rho * math.sin(a) * 0.86 - 4 * (0.5 + 0.5 * math.sin(t * 6 + i)),
      1.9,
      const Color(0xFFC9BEFF).withValues(alpha: 0.75),
    );
  }
  g.flush(c);
  _pool(c, o, 22, _white, 0.7);
}

// ── Steam: vents ───────────────────────────────────────────────────────────

void _steam(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 120.0;
  _bed(g, o, r, 900, const Color(0xFF0C1114), salt: 21, fall: 0.6, size: 2.6);
  // Vents in the floor, each breathing out a plume that billows as it climbs.
  for (var j = 0; j < 5; j++) {
    final a = j * 2.399 + 1.1;
    final rho = r * 0.62 * math.sqrt((j + 0.5) / 5);
    final vx = o.dx + rho * math.cos(a), vy = o.dy + rho * math.sin(a) * 0.8;
    // The mouth: a dark throat with a lit lip toward the light.
    for (var i = 0; i < 60; i++) {
      final b = i / 60 * _tau;
      final lit = math.cos(b - math.pi * 1.25) > 0.2;
      g.add(
        vx + 11 * math.cos(b),
        vy + 7 * math.sin(b),
        2.4,
        lit ? const Color(0xFFB9C7C9) : const Color(0xFF3A4648),
      );
    }
    for (var i = 0; i < 40; i++) {
      final rr = 8 * math.sqrt(_h(i + j * 50, 201));
      final b = _h(i + j * 50, 202) * _tau;
      g.add(vx + rr * math.cos(b), vy + rr * 0.64 * math.sin(b), 2.6, _ink);
    }
    final puff = 0.5 + 0.5 * math.sin(t * 1.6 + j * 1.3);
    for (var i = 0; i < 260; i++) {
      final s = (_h(i + j * 400, 203) + t * (0.3 + 0.12 * _h(j, 204))) % 1.0;
      // Narrow and fast at the mouth, rolling wide and slow above.
      final wide = 5 + 34 * math.pow(s, 0.8);
      final roll = math.sin(s * 9 + _h(i + j * 400, 205) * _tau + t);
      final x = vx + (_h(i + j * 400, 206) * 2 - 1) * wide + 9 * roll * s;
      final y = vy - (16 + 96 * s) * (0.8 + 0.3 * puff);
      g.add(
        x,
        y,
        s < 0.3 ? 2.2 : 2.8,
        (s < 0.25
                ? const Color(0xFFF2FBFB)
                : (roll > 0.2
                      ? const Color(0xFFCBD8DA)
                      : const Color(0xFF7F9094)))
            .withValues(alpha: (1 - s) * 0.95),
      );
    }
  }
  g.flush(c);
}

// ── Earth: a spring among standing stones ──────────────────────────────────

void _earth(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 120.0;
  _bed(g, o, r, 1000, const Color(0xFF0E120C), salt: 23, fall: 0.6, size: 2.6);
  g.flush(c);
  _pool(c, o, r * 0.6, const Color(0xFF9FE08A), 0.3);
  // The spring: light welling up from the middle and spreading in soft
  // rings, green going to gold: this ground mends.
  for (var i = 0; i < 700; i++) {
    final s = (_h(i, 211) + t * 0.16) % 1.0;
    final a = _h(i, 212) * _tau + 0.4 * s;
    final rr = r * 0.62 * math.pow(s, 0.8);
    final crest = math.sin(s * 12 - t * 2) > 0.3;
    g.add(
      o.dx + rr * math.cos(a),
      o.dy + rr * math.sin(a) * 0.8 - 6 * (1 - s),
      crest ? 2.6 : 2.1,
      (s < 0.2
              ? const Color(0xFFFFF4C2)
              : (crest ? const Color(0xFFC8F0A0) : const Color(0xFF5FA860)))
          .withValues(alpha: 1 - 0.75 * s),
    );
  }
  // Standing stones round it: each a block of grains with a lit face, a
  // dark face and a shadow, no two alike.
  for (var j = 0; j < 7; j++) {
    final a = j * _tau / 7 + 0.3;
    final sx = o.dx + r * 0.78 * math.cos(a), sy = o.dy + r * 0.62 * math.sin(a);
    final w = 13 + 7 * _h(j, 213), h = 20 + 16 * _h(j, 214);
    final tilt = (_h(j, 215) - 0.5) * 0.5;
    for (var i = 0; i < 40; i++) {
      g.add(
        sx + 6 + (_h(i + j * 90, 216) - 0.3) * w * 1.6,
        sy + 4 + (_h(i + j * 90, 217) - 0.5) * 8,
        2.6,
        _ink.withValues(alpha: 0.8),
      );
    }
    for (var i = 0; i < 170; i++) {
      final u = _h(i + j * 300, 218) * 2 - 1, v = _h(i + j * 300, 219);
      // Narrower toward the top, like a tooth.
      final x = u * w * (1 - 0.45 * v) + tilt * v * h;
      final lit = u < -0.1;
      g.add(
        sx + x,
        sy - v * h,
        2.4,
        v > 0.93
            ? const Color(0xFFE6DCC0)
            : (lit
                  ? Color.lerp(
                      const Color(0xFFA89878),
                      const Color(0xFFD4C7A4),
                      _h(i, 220),
                    )!
                  : const Color(0xFF4A4234)),
      );
    }
  }
  // Motes of the spring's light lifting.
  for (var i = 0; i < 50; i++) {
    final s = (_h(i, 221) + t * 0.2) % 1.0;
    g.add(
      o.dx + (_h(i, 222) - 0.5) * r * 0.9 + 5 * math.sin(t + i),
      o.dy - s * 90,
      2.2,
      const Color(0xFFE8FFC2).withValues(alpha: math.sin(s * math.pi)),
    );
  }
  g.flush(c);
}

// ── Mud: a slow turning mire ───────────────────────────────────────────────

void _mud(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 122.0;
  // Wet earth in thick folds, dark in the creases and shining where the
  // light lies along a crest.
  for (var i = 0; i < 5200; i++) {
    final rho = math.pow(_h(i, 231), 0.6) * r;
    final a = _h(i, 232) * _tau;
    final rim = rho / r;
    if (rim > 0.8 && _h(i, 233) < (rim - 0.8) / 0.2) continue;
    // Thick folds lying round the middle, lumpy, creeping outward: not a
    // spiral, which is what air and the dark do.
    final fold = math.sin(
      rho * 0.17 + 1.7 * math.sin(a * 2 + 0.6) + 0.8 * math.sin(a * 5) - t * 0.4,
    );
    final light = math.cos(a - math.pi * 1.25);
    final Color col;
    if (fold > 0.82 && light > 0) {
      col = const Color(0xFFD9C29A);
    } else if (fold > 0.35) {
      col = const Color(0xFF8A6A44);
    } else if (fold > -0.35) {
      col = const Color(0xFF5C432A);
    } else {
      col = const Color(0xFF2A1D12);
    }
    g.add(o.dx + rho * math.cos(a), o.dy + rho * math.sin(a) * 0.8, 2.5, col);
  }
  // Bubbles doming up through it and breaking.
  for (var j = 0; j < 8; j++) {
    final clock = t * 0.35 + _h(j, 234) * 5;
    final s = clock % 1.0;
    final a = _h(j * 7 + clock.floor(), 235) * _tau;
    final rho = r * 0.7 * math.sqrt(_h(j * 7 + clock.floor(), 236));
    final bx = o.dx + rho * math.cos(a), by = o.dy + rho * math.sin(a) * 0.8;
    final dome = 4 + 9 * math.sin(s * math.pi * 0.9);
    for (var i = 0; i < 60; i++) {
      final rr = dome * math.sqrt(_h(i + j * 80, 237));
      final b = _h(i + j * 80, 238) * _tau;
      final lit = math.cos(b - math.pi * 1.25) > 0.3 && rr > dome * 0.4;
      g.add(
        bx + rr * math.cos(b),
        by + rr * math.sin(b) * 0.8 - dome * 0.3,
        2.4,
        (lit ? const Color(0xFFE8D6B0) : const Color(0xFF6E5236)).withValues(
          alpha: s > 0.85 ? 1 - (s - 0.85) / 0.15 : 1,
        ),
      );
    }
  }
  g.flush(c);
}

// ── Dust: ripples and blown sand ───────────────────────────────────────────

void _dust(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 126.0;
  // Sand laid in wind ripples: curved crests one behind another, lit on the
  // windward face, dark in the lee, thinning to scattered grains.
  for (var i = 0; i < 4200; i++) {
    final rho = math.pow(_h(i, 241), 0.6) * r;
    final a = _h(i, 242) * _tau;
    final x = rho * math.cos(a), y = rho * math.sin(a) * 0.8;
    final rim = rho / r;
    if (rim > 0.7 && _h(i, 243) < (rim - 0.7) / 0.3) continue;
    final wave = math.sin((x * 0.82 + y * 0.57) * 0.16 + 0.9 * math.sin(y * 0.04) - t * 0.5);
    g.add(
      o.dx + x,
      o.dy + y,
      2.3,
      wave > 0.7
          ? const Color(0xFFF2DDB0)
          : (wave > 0
                ? const Color(0xFFC9A873)
                : (wave > -0.6
                      ? const Color(0xFF8E7148)
                      : const Color(0xFF4A3922))),
    );
  }
  // Sand lifted off the crests and carried across, in long low runs.
  for (var i = 0; i < 90; i++) {
    final s = (_h(i, 244) + t * 0.5) % 1.0;
    final y = (_h(i, 245) - 0.5) * r * 1.5;
    final x = -r * 1.3 + s * r * 2.6;
    for (var k = 0; k < 6; k++) {
      g.add(
        o.dx + x - k * 6,
        o.dy + y - 10 - 8 * math.sin(s * math.pi) + k * 0.6,
        2.0,
        const Color(0xFFE8D2A2).withValues(
          alpha: math.sin(s * math.pi) * (1 - k / 6) * 0.9,
        ),
      );
    }
  }
  g.flush(c);
}

// ── Crystal: a cluster of shards ───────────────────────────────────────────

void _crystal(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 120.0;
  _bed(g, o, r, 800, const Color(0xFF0D0B16), salt: 25, fall: 0.6, size: 2.6);
  g.flush(c);
  _pool(c, o, r * 0.7, const Color(0xFFB79CFF), 0.22);
  // Shards standing out of the floor, leaning away from the middle. Each is
  // two facets meeting on a ridge: one lit, one in shade, a bright edge
  // between them and a glint at the tip.
  final order = [for (var j = 0; j < 11; j++) j]
    ..sort((a, b) => math.sin(a * 2.399).compareTo(math.sin(b * 2.399)));
  for (final j in order) {
    final a = j * 2.399;
    final rho = r * 0.6 * math.sqrt((j + 0.5) / 11);
    final bx = o.dx + rho * math.cos(a), by = o.dy + rho * math.sin(a) * 0.8;
    final tall = 46 + 50 * _h(j, 251);
    final wide = 9 + 8 * _h(j, 252);
    final lean = math.cos(a) * 0.45;
    for (var i = 0; i < 230; i++) {
      final v = _h(i + j * 300, 253), u = _h(i + j * 300, 254) * 2 - 1;
      // A kite: widest a third of the way up, to a point at the top.
      final half = wide * (v < 0.3 ? 0.55 + 1.5 * v : (1 - v) / 0.7);
      final x = u * half + lean * v * tall;
      final ridge = u.abs() < 0.09;
      final pulse = 0.5 + 0.5 * math.sin(t * 1.5 + j);
      g.add(
        bx + x,
        by - v * tall,
        2.3,
        ridge
            ? Color.lerp(const Color(0xFFE8DCFF), _white, pulse)!
            : (u < 0
                  ? Color.lerp(
                      const Color(0xFF9E86E8),
                      const Color(0xFFD8CCFF),
                      v,
                    )!
                  : Color.lerp(
                      const Color(0xFF3A2C70),
                      const Color(0xFF6A56B0),
                      v,
                    )!),
      );
    }
    if (math.sin(t * 2.2 + j * 1.9) > 0.3) {
      g.add(bx + lean * tall, by - tall, 5, _white);
    }
  }
  g.flush(c);
}

// ── Air: a turning gust ────────────────────────────────────────────────────

void _air(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 126.0;
  // Air has no body: only what it carries shows it. Grains swept round an
  // empty eye in long arms, quick near the middle, slow and loose outside.
  for (var arm = 0; arm < 4; arm++) {
    for (var i = 0; i < 520; i++) {
      final s = _h(i + arm * 600, 261);
      final a = arm * _tau / 4 + s * 4.2 - t * (1.6 - 0.9 * s);
      final rr = r * (0.14 + 0.86 * s) + (_h(i + arm * 600, 262) - 0.5) * 16 * s;
      final lit = math.cos(a - math.pi * 1.25) > 0.2;
      g.add(
        o.dx + rr * math.cos(a),
        o.dy + rr * math.sin(a) * 0.8,
        s < 0.4 ? 2.6 : 2.1,
        (lit ? const Color(0xFFE9F6F4) : const Color(0xFF8FB3B0)).withValues(
          alpha: 1 - 0.75 * s,
        ),
      );
    }
  }
  // Leaves and grit caught in it.
  for (var i = 0; i < 26; i++) {
    final s = 0.3 + 0.7 * _h(i, 263);
    final a = _h(i, 264) * _tau - t * (1.4 - 0.8 * s);
    final rr = r * s;
    for (var k = 0; k < 4; k++) {
      g.add(
        o.dx + rr * math.cos(a + k * 0.05),
        o.dy + rr * math.sin(a + k * 0.05) * 0.8 - 6,
        2.6 - k * 0.3,
        const Color(0xFFCFE8D0).withValues(alpha: 1 - k / 4),
      );
    }
  }
  g.flush(c);
}

// ── Poison: a low miasma ───────────────────────────────────────────────────

void _poison(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 122.0;
  _bed(g, o, r, 1100, const Color(0xFF0E120A), salt: 27, fall: 0.6, size: 2.6);
  g.flush(c);
  _pool(c, o, r * 0.8, const Color(0xFF9FB52A), 0.22);
  // Banks of it lying low and rolling over one another: each a heap of
  // grains, sickly bright on top, dark underneath, creeping and swelling.
  for (var j = 0; j < 12; j++) {
    final a = j * 2.399 + 0.5;
    final rho = r * 0.72 * math.sqrt((j + 0.5) / 12);
    final bx = o.dx + rho * math.cos(a) + 6 * math.sin(t * 0.5 + j);
    final by = o.dy + rho * math.sin(a) * 0.8;
    final big = (20 + 14 * _h(j, 271)) * (0.9 + 0.12 * math.sin(t * 0.9 + j * 2));
    for (var i = 0; i < 190; i++) {
      final rr = big * math.sqrt(_h(i + j * 300, 272));
      final b = _h(i + j * 300, 273) * _tau;
      final x = rr * math.cos(b), y = rr * math.sin(b) * 0.62;
      final top = -y / (big * 0.62);
      g.add(
        bx + x,
        by + y - 6,
        2.5,
        (top > 0.45
                ? const Color(0xFFE2F07A)
                : (top > -0.1
                      ? const Color(0xFF9DB53A)
                      : const Color(0xFF4A5A1E)))
            .withValues(alpha: 0.95),
      );
    }
  }
  // Bubbles let go of it and drift up, and drops fall back.
  for (var i = 0; i < 46; i++) {
    final s = (_h(i, 274) + t * 0.22) % 1.0;
    final x = o.dx + (_h(i, 275) - 0.5) * r * 1.4 + 7 * math.sin(t * 1.2 + i);
    final y = o.dy - 8 - s * 80;
    for (var k = 0; k < 7; k++) {
      final b = k / 7 * _tau;
      g.add(
        x + 4 * math.cos(b),
        y + 4 * math.sin(b),
        1.8,
        const Color(0xFFD6E86A).withValues(alpha: 0.9 * (1 - s)),
      );
    }
  }
  g.flush(c);
}

// ── Spirit: wisps ──────────────────────────────────────────────────────────

void _spirit(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 120.0;
  _bed(g, o, r, 700, const Color(0xFF0B0E16), salt: 29, fall: 0.6, size: 2.6);
  g.flush(c);
  _pool(c, o, r * 0.75, const Color(0xFF9FC6FF), 0.2);
  // Wisps risen from the floor, each a bright head with a long tail that
  // winds back down to where it came from.
  for (var j = 0; j < 7; j++) {
    final a = j * 2.399 + 0.2;
    final rho = r * 0.62 * math.sqrt((j + 0.5) / 7);
    final bx = o.dx + rho * math.cos(a), by = o.dy + rho * math.sin(a) * 0.8;
    final tall = 54 + 34 * _h(j, 281) + 8 * math.sin(t * 1.3 + j);
    for (var i = 0; i < 230; i++) {
      final s = _h(i + j * 300, 282);
      final sway = 14 * math.sin(s * 5 - t * 2 + j) * (1 - s * 0.4);
      // The head: a ball at the top; the tail: thinning below it.
      final head = s > 0.78;
      final half = head ? 9 * math.sqrt(1 - math.pow((s - 0.89) / 0.11, 2).clamp(0.0, 1.0)) : 1.5 + 5 * s;
      final u = _h(i + j * 300, 283) * 2 - 1;
      g.add(
        bx + sway + u * half,
        by - s * tall,
        head ? 2.6 : 2.0,
        (head
                ? (u.abs() < 0.4 ? _white : const Color(0xFFCFE4FF))
                : const Color(0xFF8FB4E8))
            .withValues(alpha: head ? 1 : 0.25 + 0.75 * s),
      );
    }
  }
  // Motes going up from the floor to join them.
  for (var i = 0; i < 60; i++) {
    final s = (_h(i, 284) + t * 0.18) % 1.0;
    g.add(
      o.dx + (_h(i, 285) - 0.5) * r * 1.5 + 6 * math.sin(t + i),
      o.dy + (_h(i, 286) - 0.5) * 40 - s * 70,
      2.0,
      const Color(0xFFE6F1FF).withValues(alpha: math.sin(s * math.pi) * 0.9),
    );
  }
  g.flush(c);
}

// ── Dark: a hole things fall into ──────────────────────────────────────────

void _dark(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 126.0;
  _pool(c, o, r, const Color(0xFF6A3FCF), 0.22);
  // Everything round it is going in: grains on a tightening spiral, quicker
  // and brighter the nearer they are, and gone at the lip.
  for (var i = 0; i < 3800; i++) {
    final s = (_h(i, 291) + t * (0.07 + 0.05 * _h(i, 292))) % 1.0;
    final rr = r * (1 - 0.72 * math.pow(s, 0.7));
    final a = _h(i, 293) * _tau + 5.5 * s * s + (i % 3) * _tau / 3;
    final arm = math.sin(a * 3 - s * 8) > 0;
    final lit = math.cos(a - math.pi * 1.25) > 0.1;
    g.add(
      o.dx + rr * math.cos(a),
      o.dy + rr * math.sin(a) * 0.82,
      s > 0.6 ? 2.6 : 2.1,
      (s > 0.82
              ? (lit ? const Color(0xFFF0E6FF) : const Color(0xFFB79CFF))
              : (arm ? const Color(0xFF8E6AE0) : const Color(0xFF3E2A72)))
          .withValues(alpha: 0.25 + 0.75 * s),
    );
  }
  g.flush(c);
  // The hole itself: nothing, with its far wall catching a little light.
  c.drawOval(
    Rect.fromCenter(center: o, width: r * 0.6, height: r * 0.5),
    Paint()
      ..shader = ui.Gradient.radial(
        o,
        r * 0.3,
        [_ink, _ink, _ink.withValues(alpha: 0)],
        const [0.0, 0.78, 1.0],
      ),
  );
  for (var i = 0; i < 120; i++) {
    final a = math.pi * 0.25 + (_h(i, 294) * 2 - 1) * 1.1;
    final rr = r * 0.27 * (0.84 + 0.14 * _h(i, 295));
    g.add(
      o.dx + rr * math.cos(a),
      o.dy + rr * math.sin(a) * 0.82,
      2.2,
      const Color(0xFF7A5AD0).withValues(alpha: 0.9),
    );
  }
  g.flush(c);
}

// ── Light: rays ────────────────────────────────────────────────────────────

void _light(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 126.0;
  _pool(c, o, r * 0.9, const Color(0xFFFFE08A), 0.3);
  // Light going out from one point in rays of unequal length that slowly
  // turn, each a stream of grains thinning as it goes; between them, motes.
  for (var j = 0; j < 14; j++) {
    final a = j * _tau / 14 + t * 0.12 + 0.2 * math.sin(j * 3.1);
    final long = r * (0.55 + 0.45 * _h(j, 301)) * (0.9 + 0.1 * math.sin(t * 1.7 + j));
    final wide = 0.07 + 0.05 * _h(j, 302);
    for (var i = 0; i < 190; i++) {
      final s = math.pow(_h(i + j * 300, 303), 0.8).toDouble();
      final off = (_h(i + j * 300, 304) * 2 - 1) * wide * (1 - 0.6 * s);
      final rr = 14 + long * s;
      g.add(
        o.dx + rr * math.cos(a + off),
        o.dy + rr * math.sin(a + off) * 0.86,
        s < 0.4 ? 2.6 : 2.0,
        (off.abs() < wide * 0.3 && s < 0.6
                ? _white
                : (s < 0.5 ? const Color(0xFFFFE9A8) : const Color(0xFFE8B95A)))
            .withValues(alpha: 1 - 0.85 * s),
      );
    }
  }
  for (var i = 0; i < 120; i++) {
    final s = (_h(i, 305) + t * 0.2) % 1.0;
    final a = _h(i, 306) * _tau;
    g.add(
      o.dx + r * s * math.cos(a),
      o.dy + r * s * math.sin(a) * 0.86,
      2.2,
      _white.withValues(alpha: math.sin(s * math.pi)),
    );
  }
  g.flush(c);
  _pool(c, o, 30, _white, 0.95);
}

// ── Blood: a pool that reaches ─────────────────────────────────────────────

void _blood(Canvas c, Offset o, double t) {
  final g = _G();
  const r = 122.0;
  _bed(g, o, r, 700, const Color(0xFF12080A), salt: 31, fall: 0.6, size: 2.6);
  // The pool: deep red, with one long shine lying across it.
  final beat = 0.5 + 0.5 * math.sin(t * 2.4);
  for (var i = 0; i < 2200; i++) {
    final rho = math.pow(_h(i, 311), 0.6) * r * (0.4 + 0.03 * beat);
    final a = _h(i, 312) * _tau;
    final x = rho * math.cos(a), y = rho * math.sin(a) * 0.78;
    final shine =
        (Offset(x, y) - Offset(-r * 0.12, -r * 0.1)).distance < r * 0.07;
    g.add(
      o.dx + x,
      o.dy + y,
      2.5,
      shine
          ? const Color(0xFFFFC2C2)
          : Color.lerp(
              const Color(0xFF5A0A12),
              const Color(0xFFC21E2E),
              (0.5 - 0.5 * (x + y) / (r * 0.4)).clamp(0.0, 1.0),
            )!,
    );
  }
  // Veins running out from it over the floor, forking, a pulse going down
  // each one.
  void vein(Offset from, double a, double len, int depth, int id) {
    var p = from;
    var dir = a;
    final steps = (len / 5).round();
    for (var i = 0; i < steps; i++) {
      dir += (_h(id * 61 + i, 313) - 0.5) * 0.5;
      dir += (a - dir) * 0.2;
      final q = p + Offset(math.cos(dir), math.sin(dir) * 0.8) * 5;
      final s = i / steps;
      final pulse = ((s - t * 0.5 + id * 0.13) % 1.0) < 0.12;
      final w = (depth == 0 ? 3.4 : 2.4) * (1 - 0.6 * s);
      for (var k = 0; k < 3; k++) {
        final m = Offset.lerp(p, q, k / 3)!;
        g.add(
          m.dx,
          m.dy,
          pulse ? w + 1 : w,
          pulse ? const Color(0xFFFF8A8A) : const Color(0xFFA81624),
        );
      }
      if (depth < 2 && _h(id * 61 + i, 314) < 0.14) {
        vein(q, dir + (i.isEven ? 0.7 : -0.7), len * 0.5, depth + 1, id * 17 + i);
      }
      p = q;
    }
  }

  for (var k = 0; k < 7; k++) {
    final a = k * _tau / 7 + 0.4;
    vein(
      o + Offset(math.cos(a), math.sin(a) * 0.78) * (r * 0.36),
      a,
      r * 0.62,
      0,
      k + 1,
    );
  }
  // Drops drawn up out of the pool.
  for (var i = 0; i < 30; i++) {
    final s = (_h(i, 315) + t * 0.3) % 1.0;
    g.add(
      o.dx + (_h(i, 316) - 0.5) * r * 0.6,
      o.dy - s * 80,
      3.0 - 1.4 * s,
      const Color(0xFFE23A48).withValues(alpha: 1 - s),
    );
  }
  g.flush(c);
}

// ── sheet ──────────────────────────────────────────────────────────────────

void _label(Canvas c, Offset at, String text) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 20,
        color: Color(0xFFD9B36A),
        letterSpacing: 0.6,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at);
}

void main() {
  final out = Platform.environment['GROUND_OUT'];

  testWidgets('element ground design frames', (tester) async {
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
    final time =
        double.tryParse(Platform.environment['GROUND_T'] ?? '') ?? 1.3;
    final tiles = <(String, void Function(Canvas, Offset, double))>[
      ('Fire', _fire),
      ('Lava', _lava),
      ('Water', _water),
      ('Ice', _ice),
      ('Plant', _plant),
      ('Lightning', _lightning),
      ('Steam', _steam),
      ('Earth', _earth),
      ('Mud', _mud),
      ('Dust', _dust),
      ('Crystal', _crystal),
      ('Air', _air),
      ('Poison', _poison),
      ('Spirit', _spirit),
      ('Dark', _dark),
      ('Light', _light),
      ('Blood', _blood),
    ];
    const tw = 420.0, th = 400.0, gap = 4.0;
    const cols = 6;
    const size = Size(cols * tw + (cols - 1) * gap, 3 * th + 2 * gap);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(Offset.zero & size, Paint()..color = _ink);
    for (var i = 0; i < tiles.length; i++) {
      final r = Rect.fromLTWH(
        (i % cols) * (tw + gap),
        (i ~/ cols) * (th + gap),
        tw,
        th,
      );
      canvas.save();
      canvas.clipRect(r);
      canvas.drawRect(r, Paint()..color = _floor);
      tiles[i].$2(canvas, r.center + const Offset(0, 26), time);
      _label(canvas, r.topLeft + const Offset(16, 12), tiles[i].$1);
      canvas.restore();
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
