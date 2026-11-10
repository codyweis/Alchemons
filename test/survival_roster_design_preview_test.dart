@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// DESIGN FRAMES ONLY: twelve horde enemies and five bosses for survival,
// drawn in the hatch ceremony's and the wild harvest's language (grains,
// stream tubes, shells of turning bands). Nothing here is in the game; the
// painters live in this file so the frames can be judged first.
//
//   ROSTER_OUT=docs/survival_roster flutter test \
//     test/survival_roster_design_preview_test.dart --tags preview

const _ink = Color(0xFF07060B);
const _tileBg = Color(0xFF0B0912);
const _white = Color(0xFFFFF6E4);
const _brass = Color(0xFFD9B36A);
const _bone = Color(0xFFE8DCC0);
const _cyan = Color(0xFF7FE3F0);
const _ember = Color(0xFFFF8A4C);
const _green = Color(0xFF6FD08C);
const _violet = Color(0xFFB08CFF);
const _ochre = Color(0xFFD9A85B);
const _blue = Color(0xFF4FB3FF);
const _stone = Color(0xFF8E8778);
const _tau = math.pi * 2;

/// The clock every design reads, in seconds.
double _t = 0;

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _tone(Color c, double l) {
  final q = (l.clamp(0.0, 1.0) * 4).round();
  return switch (q) {
    0 => Color.lerp(c, _ink, 0.72)!,
    1 => Color.lerp(c, _ink, 0.42)!,
    2 => c,
    3 => Color.lerp(c, _white, 0.35)!,
    _ => Color.lerp(c, _white, 0.75)!,
  };
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

/// A sphere of grains in latitude bands turning against each other, each
/// band cut into segments; lit from the upper left. [pass] 0 = far side only,
/// 1 = near side only, null = both (far first).
void _shell(
  _G g,
  Offset o,
  double r,
  Color col, {
  int n = 1400,
  int bands = 5,
  int segs = 3,
  int segsPer = 1,
  double fill = 0.62,
  double twist = 0,
  double t = 0,
  double tip = 0.42,
  double grain = 1.7,
  double ry = 1,
  int salt = 0,
  int? pass,
  double farAlpha = 0.5,
  double gap = 0,
  bool Function(double u, double lon, int band, int i)? keep,
}) {
  final ct = math.cos(tip), st = math.sin(tip);
  for (var p = 0; p < 2; p++) {
    if (pass != null && pass != p) continue;
    for (var i = 0; i < n; i++) {
      final u = _h(i, 1 + salt), y = 2 * u - 1;
      final lon0 = _h(i, 2 + salt) * _tau;
      final band = math.min(bands - 1, (u * bands).floor());
      if ((u * bands) % 1.0 < gap) continue;
      final k = segs + band * segsPer;
      final ph = ((lon0 + twist * y) * k / _tau) % 1.0;
      if (ph > fill) continue;
      if (keep != null && !keep(u, lon0, band, i)) continue;
      final lon = lon0 + (band.isEven ? 1 : -1) * t;
      final cl = math.sqrt(1 - y * y);
      final x = cl * math.cos(lon), z = cl * math.sin(lon);
      final yy = y * ct - z * st, zz = y * st + z * ct;
      final near = zz > 0;
      if (near != (p == 1)) continue;
      final light = -0.5 * x + 0.62 * yy + 0.6 * zz;
      final c = near
          ? _tone(col, 0.5 + 0.5 * light)
          : _tone(col, 0.1).withValues(alpha: farAlpha);
      g.add(o.dx + r * x, o.dy - r * ry * yy, near ? grain : grain * 0.8, c);
    }
  }
}

/// A solid lit ball of grains.
void _ball(_G g, Offset o, double r, int n, Color col, {int salt = 0}) {
  for (var i = 0; i < n; i++) {
    final rho = math.sqrt(_h(i, 11 + salt)), a = _h(i, 12 + salt) * _tau;
    final x = rho * math.cos(a), y = rho * math.sin(a);
    final z = math.sqrt(math.max(0, 1 - rho * rho));
    final light = -0.5 * x - 0.62 * y + 0.6 * z;
    g.add(o.dx + r * x, o.dy + r * y, 1.8, _tone(col, 0.45 + 0.55 * light));
  }
}

/// A loose pinch of grains with a thinning tail.
void _clump(
  _G g,
  Offset o,
  double r,
  int n,
  Color col, {
  int salt = 0,
  Offset tail = Offset.zero,
  double spin = 0,
}) {
  for (var i = 0; i < n; i++) {
    final rho = math.pow(_h(i, 21 + salt), 0.8) * r;
    final a = _h(i, 22 + salt) * _tau + spin;
    final x = rho * math.cos(a), y = rho * math.sin(a);
    g.add(o.dx + x, o.dy + y, 1.7, _tone(col, 0.55 - 0.4 * (x + y) / r / 1.4));
  }
  if (tail == Offset.zero) return;
  for (var i = 0; i < n * 0.7; i++) {
    final s = (math.pow(_h(i, 23 + salt), 0.7) + _t * 0.6) % 1.0;
    final w = r * (0.5 + 1.1 * s);
    g.add(
      o.dx + tail.dx * s + (_h(i, 24 + salt) - 0.5) * w,
      o.dy + tail.dy * s + (_h(i, 25 + salt) - 0.5) * w,
      1.3,
      _tone(col, 0.3).withValues(alpha: 0.75 * (1 - s)),
    );
  }
}

List<Offset> _curve(int n, Offset Function(double s) f) => [
  for (var i = 0; i < n; i++) f(i / (n - 1)),
];

final _line = Paint()
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

void _seg(Canvas c, Offset a, Offset b, double w, Color col, double alpha) {
  final b2 = b + (b - a) * 0.2;
  for (final (k, l) in _rails) {
    _line
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = w * k
      ..color = _tone(col, l).withValues(alpha: alpha);
    c.drawLine(a, b2, _line);
  }
}

const _rails = [(1.0, 0.12), (0.62, 0.5), (0.24, 0.95)];

/// A glossy stream tube: dark edge, body, bright core. Head is the first
/// point.
void _tube(
  Canvas c,
  List<Offset> p,
  double w,
  Color col, {
  bool taper = true,
  double alpha = 1,
  Color? to,
}) {
  // Rail by rail down the whole tube, so the core is one unbroken line.
  for (final (k, l) in _rails) {
    for (var i = 0; i < p.length - 1; i++) {
      final f = i / (p.length - 1);
      final cc = to == null ? col : Color.lerp(col, to, f)!;
      _line
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (taper ? w * (1 - 0.82 * f) : w) * k
        ..color = _tone(cc, l).withValues(alpha: alpha);
      c.drawLine(p[i], p[i + 1], _line);
    }
  }
}

void _node(Canvas c, Offset o, double d, Color col) {
  _pool(c, o, d * 2.6, col, 0.5);
  c.drawCircle(o, d / 2, Paint()..color = Color.lerp(col, _white, 0.8)!);
}

void _dust(
  _G g,
  Rect r,
  int n, {
  int salt = 0,
  double a = 0.5,
  bool Function(Offset p)? skip,
}) {
  for (var i = 0; i < n; i++) {
    final p = Offset(
      r.left + _h(i, 41 + salt) * r.width,
      r.top + _h(i, 42 + salt) * r.height,
    );
    if (skip != null && skip(p)) continue;
    final k = _h(i, 43 + salt);
    g.add(
      p.dx,
      p.dy,
      k > 0.92 ? 1.6 : 1.1,
      Color.lerp(const Color(0xFF8A7F9E), _bone, k)!.withValues(
        alpha: a * (0.35 + 0.65 * k),
      ),
    );
  }
}

/// A creature read as grains: normalised positions, brightness, edge flag.
class _Sil {
  _Sil(this.x, this.y, this.lum, this.edge, this.image);
  final List<double> x, y, lum;
  final List<bool> edge;
  final ui.Image image;

  void paint(_G g, Offset o, double size, Color body, Color rim) {
    for (var i = 0; i < x.length; i++) {
      if (!edge[i] && _h(i, 181) < 0.35) continue;
      g.add(
        o.dx + x[i] * size + (_h(i, 182) - 0.5) * 1.2,
        o.dy + y[i] * size + (_h(i, 183) - 0.5) * 1.2,
        1.4,
        edge[i] ? rim : _tone(body, 0.3 + 0.6 * lum[i]),
      );
    }
  }
}

// ───────────────────────────── horde ─────────────────────────────

void _mote(Canvas c, Offset o) {
  final g = _G();
  final heads = <Offset>[];
  for (var k = 0; k < 9; k++) {
    final p =
        o +
        Offset(
          (_h(k, 31) - 0.5) * 230 - 16 * _t,
          (_h(k, 32) - 0.5) * 200 + 7 * _t + 5 * math.sin(_t * 2.2 + k * 1.7),
        );
    final sway = Offset(
      36 + 4 * math.sin(_t * 3 + k),
      -15 + 5 * math.cos(_t * 2.6 + k * 2),
    );
    _clump(g, p, 8.5, 46, _bone, salt: k * 7, tail: sway, spin: _t * 1.4 + k);
    heads.add(p);
  }
  g.flush(c);
  // Each is led by one bright grain: the root a strand would grow from.
  for (final p in heads) {
    _node(c, p + const Offset(-3, 1.5), 3.4, _bone);
  }
}

void _strand(Canvas c, Offset o, {Color col = _cyan, int count = 2}) {
  final g = _G();
  for (var k = 0; k < count; k++) {
    final off = Offset(k * 26.0 - 10, k * 78.0 - 40);
    final ph = k * 1.9 - _t * 5;
    final p = _curve(
      44,
      (s) =>
          o +
          off +
          Offset(-95 + 190 * s, -18 * s + 30 * math.sin(s * _tau * 1.15 + ph)),
    );
    _tube(c, p, 7, col);
    _node(c, p.first, 6, col);
    for (var i = 0; i < 46; i++) {
      final q = p[30 + (i % 13)];
      g.add(
        q.dx + (_h(i, 51 + k) - 0.3) * 30,
        q.dy + (_h(i, 52 + k) - 0.5) * 16,
        1.2,
        _tone(col, 0.35).withValues(alpha: 0.6),
      );
    }
  }
  g.flush(c);
}

void _braid(Canvas c, Offset o) {
  const cols = [_ember, _cyan, _green];
  final segs = <(double, Offset, Offset, double, Color)>[];
  Offset at(int j, double s) {
    final a = s * _tau * 2.6 + j * _tau / 3 - _t * 4;
    final amp = 20 * (1 - 0.45 * s);
    return o + Offset(-105 + 215 * s, -10 * s + amp * math.sin(a));
  }

  for (var j = 0; j < 3; j++) {
    for (var i = 0; i < 60; i++) {
      final s = i / 60, s2 = (i + 1) / 60;
      final z = math.cos(s * _tau * 2.6 + j * _tau / 3 - _t * 4);
      segs.add((z, at(j, s), at(j, s2), 7.5 * (1 - 0.7 * s), cols[j]));
    }
  }
  segs.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (z, a, b, w, col) in segs) {
    _seg(c, a, b, w * (0.85 + 0.15 * z), col, 1);
  }
  final g = _G();
  _ball(g, o + const Offset(-108, 0), 11, 220, _bone);
  g.flush(c);
  _node(c, o + const Offset(-112, -3), 5, _white);
}

void _husk(Canvas c, Offset o) {
  final g = _G();
  const col = Color(0xFF9A7B4A);
  _shell(g, o, 84, col, n: 11000, bands: 5, segs: 3, fill: 0.74, t: 0.3 + _t * 0.7, gap: 0.14, pass: 0);
  g.flush(c);
  c.drawCircle(o, 80, Paint()..color = _ink.withValues(alpha: 0.5));
  _shell(g, o, 84, col, n: 11000, bands: 5, segs: 3, fill: 0.74, t: 0.3 + _t * 0.7, gap: 0.14, pass: 1);
  g.flush(c);
}

void _snare(Canvas c, Offset o) {
  final g = _G();
  bool keep(double u, double lon, int band, int i) =>
      !(math.cos(lon) < -0.3 && (2 * u - 1).abs() < 0.8);
  void sh(int pass) => _shell(
    g,
    o + const Offset(34, 0),
    74,
    _green,
    n: 9000,
    bands: 6,
    segs: 2,
    segsPer: 0,
    fill: 0.5,
    twist: 2.6,
    farAlpha: 0.85,
    pass: pass,
    keep: keep,
  );
  sh(0);
  g.flush(c);
  c.drawCircle(
    o + const Offset(34, 0),
    66,
    Paint()..color = _ink.withValues(alpha: 0.25),
  );
  for (var j = 0; j < 6; j++) {
    final y0 = (j - 2.5) * 22.0;
    final p = _curve(
      30,
      (s) =>
          o +
          Offset(
            -12 - 118 * s,
            y0 * (1 - 0.55 * s) + 16 * math.sin(s * 5 + j * 1.3 - _t * 3) * s,
          ),
    );
    _tube(c, p.reversed.toList(), 4.5, _green);
    _node(c, p.last, 3.5, _green);
  }
  sh(1);
  // The lip of the mouth.
  final ctr = o + const Offset(34, 0);
  final ct = math.cos(0.42), st = math.sin(0.42);
  void lip(double x, double y, double z) {
    final yy = y * ct - z * st, zz = y * st + z * ct;
    g.add(
      ctr.dx + 74 * x,
      ctr.dy - 74 * yy,
      zz > 0 ? 2.1 : 1.6,
      _tone(_green, zz > 0 ? 0.95 : 0.5),
    );
  }

  for (var i = 0; i < 520; i++) {
    final y = (_h(i, 171) * 2 - 1) * 0.8, cl = math.sqrt(1 - y * y);
    lip(-0.3 * cl, y, (i.isEven ? 1 : -1) * cl * 0.954);
  }
  for (var i = 0; i < 360; i++) {
    final lon = 1.875 + _h(i, 172) * (_tau - 3.75);
    lip(0.6 * math.cos(lon), i.isEven ? 0.8 : -0.8, 0.6 * math.sin(lon));
  }
  g.flush(c);
}

void _siphon(Canvas c, Offset o) {
  final g = _G();
  final orb = o + const Offset(-150, 150), body = o + const Offset(84, -78);
  _pool(c, orb, 190, _brass, 0.22);
  _ball(g, orb, 92, 5200, _brass);
  g.flush(c);
  final latch = orb + const Offset(66, -62);
  final p = _curve(
    50,
    (s) =>
        Offset.lerp(body, latch, s)! +
        Offset(34 * math.sin(s * math.pi), 30 * math.sin(s * math.pi)),
  );
  _tube(c, p, 5.5, _violet, taper: false);
  for (var i = 0; i < 60; i++) {
    final q = p[(((_h(i, 61) + _t * 0.35) % 1.0) * 49).floor()];
    g.add(
      q.dx + (_h(i, 62) - 0.5) * 3,
      q.dy + (_h(i, 63) - 0.5) * 3,
      2.2,
      Color.lerp(_brass, _white, 0.4)!,
    );
  }
  g.flush(c);
  _pool(c, latch, 22, _white, 0.6);
  _pool(c, body, 44, _violet, 0.3);
  _ball(g, body, 19, 520, _violet, salt: 3);
  _shell(g, body, 27, _violet, n: 520, bands: 3, fill: 0.55, t: 0.4);
  g.flush(c);
}

void _lobber(Canvas c, Offset o) {
  final g = _G();
  final body = o + const Offset(66, 52);
  Offset arc(double s) =>
      body + Offset(-14 - 170 * s, -30 - 190 * s + 175 * s * s);
  final lob = (_t / 1.8) % 1.0;
  final cs = 0.2 + 0.8 * lob * lob * (3 - 2 * lob);
  for (var i = 0; i < 520; i++) {
    final s = math.pow(_h(i, 71), 0.6) * cs * 0.97;
    final w = 3 + 9 * (1 - s / cs);
    final q = arc(s.toDouble());
    g.add(
      q.dx + (_h(i, 72) - 0.5) * w,
      q.dy + (_h(i, 73) - 0.5) * w,
      1.5,
      _tone(_ember, 0.25 + 0.5 * s).withValues(alpha: 1 - 0.6 * lob),
    );
  }
  g.flush(c);
  _pool(c, arc(cs), 30, _ember, 0.45);
  _ball(g, arc(cs), 12, 260, _ember, salt: 5);
  _pool(c, body, 70, _ember, 0.25);
  _ball(g, body, 33, 1500, _ember, salt: 2);
  _shell(
    g,
    body,
    35,
    const Color(0xFF4A342A),
    n: 1300,
    bands: 3,
    segs: 3,
    fill: 0.58,
    pass: 1,
  );
  g.flush(c);
}

void _sower(Canvas c, Offset o) {
  final g = _G();
  // The bank it has laid, behind it.
  for (var i = 0; i < 3600; i++) {
    final f = _h(i, 81), x = 6 + 180 * f;
    final half = 72 - 24 * f + 6 * math.sin(x * 0.06 + i % 3);
    final y = (_h(i, 82) * 2 - 1) * half * math.sqrt(_h(i, 83));
    g.add(
      o.dx + x,
      o.dy + y,
      1.5,
      _tone(_ochre, 0.18 + 0.3 * _h(i, 84)).withValues(alpha: 0.9 - 0.6 * f),
    );
  }
  // The dune: a crescent, horns trailing, brightest along its crest.
  const outer = Offset(-40, 0), inner = Offset(8, 0);
  for (var i = 0; i < 5200; i++) {
    final rho = math.sqrt(_h(i, 85)), a = _h(i, 86) * _tau;
    final p = outer + Offset(76 * rho * math.cos(a), 76 * rho * math.sin(a));
    final d = (p - inner).distance - 66;
    if (d < 0) continue;
    g.add(
      o.dx + p.dx,
      o.dy + p.dy,
      1.7,
      _tone(_ochre, 0.3 + 0.65 * math.exp(-d / 8) - 0.12 * p.dy / 76),
    );
  }
  // The slip face under the crest, in shadow.
  for (var i = 0; i < 900; i++) {
    final a = math.pi + (_h(i, 87) * 2 - 1) * 1.05;
    final r = 66 - math.pow(_h(i, 88), 1.6) * 20;
    final p = inner + Offset(r * math.cos(a), r * math.sin(a));
    if ((p - outer).distance > 76) continue;
    g.add(o.dx + p.dx, o.dy + p.dy, 1.6, _tone(_ochre, 0.05));
  }
  // Sand blown off the crest, falling to the bank.
  for (var i = 0; i < 320; i++) {
    final a = math.pi + (_h(i, 89) * 2 - 1) * 1.0;
    final s = (_h(i, 90) + _t * 0.45) % 1.0;
    final p = inner + Offset(66 * math.cos(a) + 70 * s, 66 * math.sin(a));
    g.add(
      o.dx + p.dx,
      o.dy + p.dy,
      1.3,
      _tone(_ochre, 0.7).withValues(alpha: 0.8 * (1 - s)),
    );
  }
  g.flush(c);
}

void _crest(Canvas c, Offset o) {
  final g = _G();
  final ctr = o + const Offset(190, 0);
  const col = Color(0xFFFFE2A0);
  for (var k = 0; k < 4; k++) {
    final p = o + Offset(70 + _h(k, 91) * 70, (_h(k, 92) - 0.5) * 150);
    _clump(g, p, 7, 34, _bone, salt: k * 5, tail: const Offset(26, 0));
  }
  for (var i = 0; i < 3600; i++) {
    final a = math.pi + (_h(i, 93) * 2 - 1) * 0.72;
    final back = i < 1300
        ? _h(i, 94) * 2.5
        : math.pow((_h(i, 94) + _t * 0.25) % 1.0, 2.2) * 60;
    final r = 235 - back;
    final edge = 1 - ((a - math.pi).abs() / 0.72);
    g.add(
      ctr.dx + r * math.cos(a),
      ctr.dy + r * math.sin(a),
      i < 1300 ? 2.0 : 1.4,
      i < 1300
          ? _tone(col, 0.6 + 0.4 * edge)
          : _tone(col, 0.35).withValues(alpha: 0.7 * (1 - back / 60) * edge),
    );
  }
  g.flush(c);
}

void _clutch(Canvas c, Offset o) {
  final g = _G();
  final base = o + const Offset(0, 62);
  _pool(c, base, 90, _ember, 0.12);
  for (var j = 0; j < 5; j++) {
    final dx = (j - 2) * 30.0;
    _tube(
      c,
      _curve(
        14,
        (s) => base + Offset(dx * (0.3 + s), -6 + 16 * s + 5 * math.sin(s * 4)),
      ),
      4,
      _stone,
    );
  }
  _shell(
    g,
    o,
    48,
    _stone,
    n: 2600,
    bands: 1,
    segs: 1,
    segsPer: 0,
    fill: 1,
    ry: 1.3,
    pass: 1,
  );
  g.flush(c);
  // The seam, lit from inside.
  for (var i = 0; i < 260; i++) {
    final s = _h(i, 95);
    final y = -44 + 86 * s;
    final x = -6 + 9 * (((s * 7) % 1.0) - 0.5).abs() * 2 - 8 * s;
    g.add(
      o.dx + x + (_h(i, 96) - 0.5) * 2.5,
      o.dy + y,
      1.8,
      _tone(_ember, (0.6 + 0.4 * _h(i, 97)) * (0.8 + 0.2 * math.sin(_t * 4))),
    );
  }
  for (var k = 0; k < 3; k++) {
    _clump(
      g,
      o +
          Offset(
            -60 - (k * 34 + _t * 18) % 100,
            34 - k * 16 + (k.isOdd ? 20 : 0),
          ),
      7,
      34,
      _bone,
      salt: k * 3,
      tail: const Offset(20, -4),
    );
  }
  g.flush(c);
  _pool(c, o + const Offset(-6, 0), 34, _ember, 0.24 + 0.1 * math.sin(_t * 4));
}

void _spill(Canvas c, Offset o) {
  final g = _G();
  _pool(c, o, 100, _violet, 0.3);
  for (var i = 0; i < 1500; i++) {
    final rad = 58 * (0.3 + 1.35 * math.pow(_h(i, 101), 1.5));
    final dir = i % 4 == 0 ? -0.6 : 1.0;
    final a0 = _h(i, 102) * _tau + dir * _t * 1.5 * 58 / rad;
    final col = i % 5 == 0
        ? HSVColor.fromAHSV(1, _h(i, 102) * 360, 0.55, 1).toColor()
        : _tone(_violet, 0.3 + 0.6 * _h(i, 103));
    for (var k = 0; k < 4; k++) {
      final a = a0 - dir * k * 4.5 / rad;
      g.add(
        o.dx + rad * math.cos(a),
        o.dy + rad * 0.92 * math.sin(a),
        1.6 - k * 0.15,
        col.withValues(alpha: (1 - k * 0.25) * (rad > 80 ? 0.6 : 1)),
      );
    }
  }
  g.flush(c);
  _pool(c, o, 30, _white, 0.75);
}

bool _inHollow(Offset p, Offset o, double s) {
  for (var k = 0; k < 9; k++) {
    final q = o + Offset(k * 15.0, -k * 10.0) * s;
    if ((p - q).distance < (54 - k * 5.6) * s) return true;
  }
  return false;
}

void _hollowBow(_G g, Offset o, double s) {
  for (var i = 0; i < 1100; i++) {
    final a =
        math.pi * 0.75 +
        (_h(i, 111) * 2 - 1) * (i.isEven ? 1.25 : math.pi);
    final r = (55 + math.pow(_h(i, 112), 1.6) * 30) * s;
    final edge = 1 - ((a - math.pi * 0.75).abs() / 3.2);
    g.add(
      o.dx + r * math.cos(a),
      o.dy + r * math.sin(a),
      1.3,
      _bone.withValues(alpha: 0.75 * edge * edge),
    );
  }
}

void _hollow(Canvas c, Offset at) {
  final g = _G();
  final o = at + Offset(-9 * _t, 6 * _t);
  _dust(
    g,
    Rect.fromCenter(center: at, width: 360, height: 360),
    5200,
    salt: 9,
    a: 0.8,
    skip: (p) => _inHollow(p, o, 1),
  );
  _hollowBow(g, o, 1);
  g.flush(c);
}

// ───────────────────────────── bosses ─────────────────────────────

void _unhatched(Canvas c, Offset o) {
  const strands = 72, samples = 34, r = 150.0, ry = 1.28, tip = 0.3;
  final ct = math.cos(tip), st = math.sin(tip);
  final far = <(double, Offset, Offset, double, Color)>[];
  final near = <(double, Offset, Offset, double, Color)>[];
  for (var j = 0; j < strands; j++) {
    final lon0 = j / strands * _tau;
    final col = Color.lerp(_bone, _brass, _h(j, 121))!;
    Offset? prev;
    for (var i = 0; i <= samples; i++) {
      final s = i / samples;
      final lat = -1.38 + 2.76 * s;
      final lon = lon0 + s * 2.9 + _t * 0.2;
      final cl = math.cos(lat), y = math.sin(lat);
      final x = cl * math.cos(lon), z = cl * math.sin(lon);
      final yy = y * ct - z * st, zz = y * st + z * ct;
      final p = Offset(o.dx + r * x, o.dy - r * ry * yy);
      final broken =
          zz > 0 &&
          s > 0.36 + 0.1 * _h(j, 122) &&
          s < 0.56 + 0.14 * _h(j, 123) &&
          x > 0.0 + 0.3 * _h(j, 124) &&
          x < 0.6 + 0.35 * _h(j, 125);
      if (prev != null && !broken) {
        final light = 0.5 + 0.5 * (-0.5 * x + 0.62 * yy + 0.6 * zz);
        (zz > 0 ? near : far).add((
          zz,
          prev,
          p,
          zz > 0 ? 4.2 : 2.6,
          Color.lerp(_tone(col, 0.15), col, light)!,
        ));
      }
      prev = broken ? null : p;
      if (i == 0) _node(c, p, 3, col);
    }
  }
  for (final (_, a, b, w, col) in far) {
    _seg(c, a, b, w, col, 0.4);
  }
  c.drawOval(
    Rect.fromCenter(center: o, width: r * 1.9, height: r * ry * 1.9),
    Paint()..color = _ink.withValues(alpha: 0.5),
  );
  near.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (_, a, b, w, col) in near) {
    _seg(c, a, b, w, col, 1);
  }
  // The strands the broken band let go.
  for (var k = 0; k < 4; k++) {
    final start = o + Offset(70 + k * 12.0, -20 + k * 22.0);
    final p = _curve(
      30,
      (s) =>
          start +
          Offset(150 - 120 * s, (k - 1.5) * 26 * (1 - s) + 14 * math.sin(s * 7 + k - _t * 5)),
    );
    _tube(c, p, 5.5, _cyan);
    _node(c, p.first, 5, _cyan);
  }
}

void _harvester(Canvas c, Offset o) {
  final g = _G();
  const col = Color(0xFF8C7BFF);
  const closed = {0, 1, 5};
  bool keep(double u, double lon, int band, int i) =>
      closed.contains(band) || _h(i, 131) < 0.05;
  void sh(int pass) => _shell(
    g,
    o,
    212,
    col,
    n: 30000,
    bands: 6,
    segs: 5,
    segsPer: 1,
    fill: 0.93,
    t: 0.25 + _t * 0.35,
    grain: 1.9,
    gap: 0.1,
    pass: pass,
    keep: keep,
  );
  sh(0);
  // The octagram, written behind the specimen.
  for (var k = 0; k < 8; k++) {
    final a = Offset.fromDirection(k * _tau / 8 - math.pi / 2, 128);
    final b = Offset.fromDirection((k + 3) * _tau / 8 - math.pi / 2, 128);
    for (var i = 0; i < 120; i++) {
      final q = Offset.lerp(a, b, i / 120)!;
      g.add(o.dx + q.dx, o.dy + q.dy * 0.9, 1.4, col.withValues(alpha: 0.5));
    }
  }
  g.flush(c);
  _pool(c, o, 150, _brass, 0.3);
  _ball(g, o, 56, 2600, _brass);
  // Grains still pouring in to the open bands.
  for (var i = 0; i < 900; i++) {
    final s = (_h(i, 132) + _t * 0.3) % 1.0;
    final a = _h(i, 133) * _tau + s * 1.1;
    final r = 212 * (1.02 + 0.3 * s);
    final y = math.sin(a) * 0.5;
    if (y.abs() > 0.34) continue;
    g.add(
      o.dx + r * math.cos(a),
      o.dy + r * y,
      1.4,
      _tone(col, 0.5).withValues(alpha: 0.8 * (1 - s)),
    );
  }
  sh(1);
  g.flush(c);
}

void _drift(Canvas c, Offset o) {
  final g = _G();
  const turns = 1.8;
  Offset at(double f, double across) {
    final a = f * turns * _tau - 0.5;
    final r = 262 - 196 * f + across * (36 - 20 * f);
    return o + Offset(r * math.cos(a), r * math.sin(a) * 0.96);
  }

  for (var i = 0; i < 12000; i++) {
    final f = (math.pow(_h(i, 141), 0.85) + _t * 0.03) % 1.0;
    final ac = (_h(i, 142) + _h(i, 143) - 1);
    final counter = i % 4 == 0;
    final col = _tone(
      _ochre,
      (counter ? 0.2 : 0.35) + 0.5 * (1 - ac.abs() * 1.6) * (0.5 + 0.5 * f),
    ).withValues(alpha: (counter ? 0.5 : 0.9) * math.min(1, f * 6));
    for (var k = 0; k < 2; k++) {
      final q = at(f - (counter ? -1 : 1) * k * 0.004, ac);
      g.add(q.dx, q.dy, 1.5 - k * 0.3, col);
    }
  }
  for (var k = 0; k < 12; k++) {
    _clump(
      g,
      at((0.12 + 0.07 * k + _t * 0.03) % 1.0, (_h(k, 144) - 0.5) * 0.8),
      6,
      30,
      _bone,
      salt: k * 3,
    );
  }
  g.flush(c);
  final head = at(1, 0);
  _pool(c, head, 60, _white, 0.5);
  _ball(g, head, 22, 900, const Color(0xFFFFE2A0), salt: 4);
  g.flush(c);
  _node(c, head + const Offset(-6, -6), 7, _white);
  _pool(c, o, 60, _brass, 0.35);
  _ball(g, o, 20, 700, _brass);
  g.flush(c);
}

void _pair(Canvas c, Offset o) {
  final g = _G();
  final a = o + const Offset(-158, -6), b = o + const Offset(158, 10);
  void sa(int pass) => _shell(
    g,
    a,
    96,
    _ember,
    n: 4200,
    bands: 4,
    segs: 3,
    fill: 0.72,
    twist: 0.5,
    t: 0.2 + _t * 0.5,
    pass: pass,
  );
  void sb(int pass) => _shell(
    g,
    b,
    96,
    _blue,
    n: 4600,
    bands: 8,
    segs: 9,
    segsPer: 1,
    fill: 0.55,
    twist: 0.9,
    t: 0.2 + _t * 0.5,
    salt: 4,
    pass: pass,
  );
  sa(0);
  sb(0);
  g.flush(c);
  _pool(c, a, 70, _ember, 0.45);
  _pool(c, b, 70, _blue, 0.45);
  for (var j = 0; j < 16; j++) {
    final y0 = (j - 7.5) * 8.0;
    final p0 = a + Offset(math.sqrt(96 * 96 - y0 * y0 * 2) - 6, y0 * 1.3);
    final p1 = b + Offset(-math.sqrt(96 * 96 - y0 * y0 * 2) + 6, -y0 * 1.3);
    final p = _curve(
      40,
      (s) =>
          Offset.lerp(p0, p1, s)! +
          Offset(
            0,
            math.sin(s * math.pi) * (10 + j * 1.6) +
                9 *
                    math.sin(s * _tau * 1.5 + j * 0.9 - _t * 1.6) *
                    math.sin(s * math.pi),
          ),
    );
    _tube(c, p, 3.4, _ember, taper: false, to: _blue);
    _node(c, p0, 3.5, _ember);
    _node(c, p1, 3.5, _blue);
  }
  sa(1);
  sb(1);
  g.flush(c);
}

void _otherOrb(Canvas c, Offset o, List<_Sil> party) {
  final g = _G();
  final orb = o + const Offset(-196, 52), dark = o + const Offset(92, -14);
  const r = 128.0;
  const deep = Color(0xFF2A1E48);
  _pool(c, orb, 130, _brass, 0.35);
  _pool(c, dark, r * 1.7, _violet, 0.2);
  c.drawCircle(dark, r, Paint()..color = _ink);
  // The dark body, and the rim the orb lights.
  final toOrb = (orb - dark).direction;
  for (var i = 0; i < 5200; i++) {
    final rho = math.sqrt(_h(i, 151)), a = _h(i, 152) * _tau;
    g.add(
      dark.dx + r * rho * math.cos(a),
      dark.dy + r * rho * math.sin(a),
      1.6,
      _tone(deep, 0.1 + 0.3 * _h(i, 153)),
    );
  }
  for (var i = 0; i < 2600; i++) {
    final d = (_h(i, 154) + _h(i, 155) - 1) * 1.5;
    final rho = 1 - math.pow(_h(i, 156), 2) * 0.09 * (1 - d.abs() / 1.5);
    g.add(
      dark.dx + r * rho * math.cos(toOrb + d),
      dark.dy + r * rho * math.sin(toOrb + d),
      1.7,
      _tone(_violet, 0.5 + 0.5 * (1 - d.abs() / 1.5)),
    );
  }
  // The orb's grains, drawn across.
  final from = orb + Offset.fromDirection(toOrb + math.pi, 40);
  final to = dark + Offset.fromDirection(toOrb, r);
  for (var i = 0; i < 900; i++) {
    final s = (_h(i, 157) + _t * 0.3) % 1.0;
    final w = 22 * math.sin(s * math.pi) + 4;
    final q =
        Offset.lerp(from, to, s)! +
        Offset(0, -26 * math.sin(s * math.pi)) +
        Offset((_h(i, 158) - 0.5) * w, (_h(i, 159) - 0.5) * w);
    g.add(q.dx, q.dy, 1.6, Color.lerp(_tone(_brass, 0.7), _violet, s * s)!);
  }
  _ball(g, orb, 46, 1900, _brass);
  // Its guard: your party, read as grains.
  const at = [Offset(-52, -168), Offset(-66, 176), Offset(206, 168)];
  for (var k = 0; k < party.length && k < 3; k++) {
    party[k].paint(g, o + at[k], 128, const Color(0xFF6A54A8), _tone(_violet, 0.6));
  }
  g.flush(c);
}

// ───────────────────────────── sheets ─────────────────────────────

Future<_Sil> _readSil(String asset) async {
  final data = (await rootBundle.load(asset)).buffer.asUint8List();
  final full = (await (await ui.instantiateImageCodec(data)).getNextFrame())
      .image;
  final small =
      (await (await ui.instantiateImageCodec(
        data,
        targetWidth: 110,
      )).getNextFrame()).image;
  final px = (await small.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!.buffer.asUint8List();
  final w = small.width, h = small.height;
  bool solid(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && px[(y * w + x) * 4 + 3] > 110;
  final xs = <double>[], ys = <double>[], lum = <double>[];
  final edge = <bool>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!solid(x, y)) continue;
      final i = (y * w + x) * 4;
      xs.add(x / w - 0.5);
      ys.add((y - h / 2) / w);
      lum.add((px[i] * 0.3 + px[i + 1] * 0.59 + px[i + 2] * 0.11) / 255);
      edge.add(
        !solid(x - 1, y) || !solid(x + 1, y) || !solid(x, y - 1) ||
            !solid(x, y + 1),
      );
    }
  }
  return _Sil(xs, ys, lum, edge, full);
}

void _label(Canvas c, Offset at, String text, {double size = 21}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontSize: size,
        color: _brass.withValues(alpha: 0.9),
        letterSpacing: 0.6,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at);
}

void _tile(
  Canvas c,
  Rect r,
  String name,
  void Function(Canvas c, Offset o) draw, {
  bool dust = true,
}) {
  c.save();
  c.clipRect(r);
  c.drawRect(r, Paint()..color = _tileBg);
  if (dust) {
    final g = _G();
    _dust(g, r, (r.width * r.height * 0.0016).round(), salt: name.length);
    g.flush(c);
  }
  draw(c, r.center);
  _label(c, r.topLeft + const Offset(16, 12), name);
  c.restore();
}

void _placed(
  Canvas c,
  Offset at,
  double scale,
  void Function(Canvas c, Offset o) draw,
) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale);
  draw(c, Offset.zero);
  c.restore();
}

void _arena(Canvas c, Size size, List<_Sil> party) {
  final o = size.center(Offset.zero);
  c.drawRect(Offset.zero & size, Paint()..color = _tileBg);
  final g = _G();
  final hollowAt = o + const Offset(-330, 60) + Offset(9 * _t, -2 * _t);
  _dust(
    g,
    Offset.zero & size,
    15000,
    a: 0.6,
    skip: (p) => _inHollow(p, hollowAt, 0.55),
  );
  _hollowBow(g, hollowAt, 0.55);
  g.flush(c);

  // The sower's bank, creeping in from the lower right.
  _placed(c, o + const Offset(300, 330), 0.75, _sower);
  // The orb and its party.
  _pool(c, o, 150, _brass, 0.3);
  _ball(g, o, 36, 1400, _brass);
  g.flush(c);
  const posts = [Offset(96, -40), Offset(-70, -86), Offset(-20, 112)];
  for (var k = 0; k < party.length && k < 3; k++) {
    final im = party[k].image;
    c.drawImageRect(
      im,
      Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
      Rect.fromCenter(center: o + posts[k], width: 84, height: 84),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  _placed(c, o + posts[1] + const Offset(-14, 0), 0.62, _snare);

  // The siphon, latched.
  final body = o + const Offset(210, -170);
  final latch = o + const Offset(26, -24);
  final tube = _curve(
    40,
    (s) =>
        Offset.lerp(body, latch, s)! + Offset(0, 30 * math.sin(s * math.pi)),
  );
  _tube(c, tube, 4, _violet, taper: false);
  for (var i = 0; i < 30; i++) {
    final q = tube[(_h(i, 161) * 39).floor()];
    g.add(q.dx, q.dy, 2, Color.lerp(_brass, _white, 0.4)!);
  }
  _ball(g, body, 13, 300, _violet);
  g.flush(c);

  for (var k = 0; k < 7; k++) {
    final a = -0.9 + k * 0.3, r = 300.0 + 70 * _h(k, 162);
    c.save();
    c.translate(o.dx + r * math.cos(a), o.dy + r * math.sin(a));
    c.rotate(a + math.pi);
    c.scale(0.55);
    // Motes travel down-left in their own frame; turn them to face the orb.
    c.rotate(-0.4);
    _mote(c, Offset.zero);
    c.restore();
  }
  for (var k = 0; k < 4; k++) {
    final a = -0.7 + k * 0.42, r = 190.0 + 60 * _h(k, 163);
    c.save();
    c.translate(o.dx + r * math.cos(a), o.dy + r * math.sin(a));
    c.rotate(a);
    c.scale(0.5);
    _strand(c, Offset.zero, count: 1);
    c.restore();
  }
  _placed(c, o + const Offset(330, -40), 0.6, _husk);
  c.save();
  c.translate(o.dx + 250, o.dy + 190);
  c.rotate(0.65);
  c.scale(0.62);
  _crest(c, Offset.zero);
  c.restore();
  c.save();
  c.translate(o.dx + 170, o.dy - 330);
  c.rotate(-1.05);
  c.scale(0.5);
  _braid(c, Offset.zero);
  c.restore();
  _placed(c, o + const Offset(420, -330), 0.6, _lobber);
  _placed(c, o + const Offset(40, -300), 0.55, _clutch);
  _placed(c, o + const Offset(150, 60), 0.4, _spill);
}

void main() {
  final out = Platform.environment['ROSTER_OUT'];

  testWidgets('survival roster design frames', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    late List<_Sil> party;
    await tester.runAsync(() async {
      final font = File('/System/Library/Fonts/Supplemental/Georgia.ttf');
      if (font.existsSync()) {
        await (FontLoader('Georgia')..addFont(
              Future.value(ByteData.view(font.readAsBytesSync().buffer)),
            ))
            .load();
      }
      party = [
        await _readSil('assets/images/creatures/legendary/WNG01_firewing.png'),
        await _readSil('assets/images/creatures/uncommon/MAN01_firemane.png'),
        await _readSil('assets/images/creatures/common/LET01_firelet.png'),
      ];
    });

    var dir = out, tag = '';
    Future<void> save(String name, Size size, void Function(Canvas) draw) =>
        tester.runAsync(() async {
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec);
          canvas.drawRect(Offset.zero & size, Paint()..color = _ink);
          draw(canvas);
          final img = rec.endRecording().toImageSync(
            size.width.round(),
            size.height.round(),
          );
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/$name$tag.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });

    final horde = <(String, void Function(Canvas, Offset))>[
      ('1  Mote', _mote),
      ('2  Strand', (c, o) => _strand(c, o)),
      ('3  Braid', _braid),
      ('4  Husk', _husk),
      ('5  Snare', _snare),
      ('6  Siphon', _siphon),
      ('7  Lobber', _lobber),
      ('8  Sower', _sower),
      ('9  Crest', _crest),
      ('10  Clutch', _clutch),
      ('11  Spill', _spill),
      ('12  Hollow', _hollow),
    ];
    const t = 360.0, gap = 4.0;
    Future<void> all() async {
    await save('horde', const Size(4 * t + 3 * gap, 3 * t + 2 * gap), (c) {
      for (var i = 0; i < horde.length; i++) {
        _tile(
          c,
          Rect.fromLTWH((i % 4) * (t + gap), (i ~/ 4) * (t + gap), t, t),
          horde[i].$1,
          horde[i].$2,
          dust: i != 11,
        );
      }
    });

    final bosses = <(String, void Function(Canvas, Offset))>[
      ('I  The Unhatched', _unhatched),
      ('II  The Harvester', _harvester),
      ('III  The Drift', _drift),
      ('IV  The Pair', _pair),
      ('V  The Other Orb', (c, o) => _otherOrb(c, o, party)),
    ];
    const b = 600.0;
    await save('bosses', const Size(3 * b + 2 * gap, 2 * b + gap), (c) {
      for (var i = 0; i < bosses.length; i++) {
        final row = i ~/ 3, col = i % 3;
        final inset = row == 1 ? (b + gap) / 2 : 0.0;
        _tile(
          c,
          Rect.fromLTWH(inset + col * (b + gap), row * (b + gap), b, b),
          bosses[i].$1,
          bosses[i].$2,
        );
      }
    });

    await save(
      'arena',
      const Size(1000, 1000),
      (c) => _arena(c, const Size(1000, 1000), party),
    );
    }

    await all();
    // ROSTER_FRAMES=120 ROSTER_FRAMES_OUT=<dir>: the same sheets at 30 fps.
    final frames = int.tryParse(Platform.environment['ROSTER_FRAMES'] ?? '');
    final framesOut = Platform.environment['ROSTER_FRAMES_OUT'];
    if (frames != null && framesOut != null) {
      Directory(framesOut).createSync(recursive: true);
      dir = framesOut;
      for (var f = 0; f < frames; f++) {
        _t = f / 30;
        tag = '_${f.toString().padLeft(4, '0')}';
        await all();
      }
      _t = 0;
    }
  }, timeout: const Timeout(Duration(minutes: 20)));

  // What the look costs drawn the way the game would draw it: every live
  // body of every kind into shared tone buckets (a handful of point draws
  // however many bodies), and the chaff as quads in one atlas draw.
  //
  //   ROSTER_COST=1 flutter test ... --plain-name cost
  test('roster cost at horde counts', () {
    if (Platform.environment['ROSTER_COST'] == null) return;
    // A late wave: live grains per body at play scale x how many are out.
    const live = <String, (int, int)>{
      'husk': (500, 20),
      'snare': (500, 6),
      'siphon': (150, 6),
      'lobber': (250, 8),
      'sower': (400, 4),
      'crest': (500, 6),
      'clutch': (350, 6),
      'spill': (400, 10),
      'hollow': (200, 6),
    };
    // Atlas quads: 800 motes, 150 strands x 6 links, 10 braids x 18,
    // 6 snares x 36 tendril links, 6 siphon tubes x 10.
    const quads = 800 + 150 * 6 + 10 * 18 + 6 * 36 + 6 * 10;
    const tpl = 500, bands = 5, tones = 6;
    final x0 = Float32List(tpl), y0 = Float32List(tpl), z0 = Float32List(tpl);
    final band = Uint8List(tpl);
    for (var i = 0; i < tpl; i++) {
      final u = _h(i, 1), y = 2 * u - 1, lon = _h(i, 2) * _tau;
      final cl = math.sqrt(1 - y * y);
      x0[i] = cl * math.cos(lon);
      y0[i] = y;
      z0[i] = cl * math.sin(lon);
      band[i] = math.min(bands - 1, (u * bands).floor());
    }
    final total = live.values.fold(0, (a, v) => a + v.$1 * v.$2);
    final buf = [for (var k = 0; k < tones; k++) Float32List(total * 2)];
    final n = List.filled(tones, 0);
    final cs = Float32List(bands), sn = Float32List(bands);
    final rst = Float32List(quads * 4), rects = Float32List(quads * 4);
    final atlasRec = ui.PictureRecorder();
    Canvas(atlasRec).drawCircle(const Offset(16, 16), 12, Paint());
    final atlas = atlasRec.endRecording().toImageSync(32, 32);
    final ct = math.cos(0.42), st = math.sin(0.42);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final times = <int>[];
    for (var frame = 0; frame < 90; frame++) {
      final t = frame / 60;
      final sw = Stopwatch()..start();
      n.fillRange(0, tones, 0);
      var body = 0;
      for (final (grains, count) in live.values) {
        for (var b = 0; b < count; b++, body++) {
          final ox = 100.0 + (body * 37) % 800, oy = 100.0 + (body * 91) % 600;
          for (var k = 0; k < bands; k++) {
            final a = (k.isEven ? 1 : -1) * (t * 0.7 + body);
            cs[k] = math.cos(a);
            sn[k] = math.sin(a);
          }
          for (var i = 0; i < grains; i++) {
            final k = band[i];
            final x = x0[i] * cs[k] - z0[i] * sn[k];
            final z = x0[i] * sn[k] + z0[i] * cs[k];
            final yy = y0[i] * ct - z * st, zz = y0[i] * st + z * ct;
            final tone = zz <= 0
                ? 0
                : 1 +
                      ((0.5 + 0.5 * (-0.5 * x + 0.62 * yy + 0.6 * zz)) * 4)
                          .round()
                          .clamp(0, 4);
            final j = n[tone] * 2;
            buf[tone][j] = ox + 40 * x;
            buf[tone][j + 1] = oy - 40 * yy;
            n[tone]++;
          }
        }
      }
      for (var q = 0; q < quads; q++) {
        final a = t * 2 + q;
        rst[q * 4] = math.cos(a);
        rst[q * 4 + 1] = math.sin(a);
        rst[q * 4 + 2] = (q * 53) % 900 + 10 * t;
        rst[q * 4 + 3] = (q * 97) % 700 + 0.0;
        rects[q * 4 + 2] = 32;
        rects[q * 4 + 3] = 32;
      }
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var k = 0; k < tones; k++) {
        c.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(buf[k], 0, n[k] * 2),
          paint,
        );
      }
      c.drawRawAtlas(atlas, rst, rects, null, null, null, paint);
      rec.endRecording();
      sw.stop();
      if (frame >= 30) times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    // ignore: avoid_print
    print(
      'ROSTER COST: $total live grains + $quads atlas quads, 7 draws: '
      'median ${times[times.length ~/ 2]} us, '
      'p95 ${times[(times.length * 0.95).floor()]} us',
    );
  });
}
