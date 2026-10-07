// lib/games/cosmic_survival/orb_art.dart
//
// The survival orb — the alchemy core the party defends — in the material
// the ships and enemies are made of now: dark glass with light trapped
// inside it, and particles on real motion round it. Each of the eight cores
// is its own thing, and wears what it does:
//
//   Standard Orb      teal light in dark glass, a slow ring of grains
//   Voidforge Core    obsidian, violet light leaking through its cracks,
//                     grains spiralling in
//   Celestial Beacon  a small sun: rays, a drifting corona, a flare as it
//                     heals
//   Infernal Engine   a cracked shell with molten veins, embers rising as
//                     far as its burn reaches
//   Frozen Nexus      faceted ice with shards in orbit, frost haze out to
//                     the edge of its slow
//   Phantom Wisp      smoked glass with wisps of light drifting inside it —
//                     dim at its faintest, never gone
//   Prism Heart       a cut gem whose facets catch shifting spectral light
//   Verdant Bloom     a seed of light with tendrils, beating like a heart
//
// Its readings sit round it as rings of cells, like the ship console's
// gauges: health in the core's own light (amber, then red, as it falls) and
// the alchemy meter outside it. The gravity field the ship orbits in is a
// few lanes of drifting dust. No hoops, no outline strokes, no blur.
//
// Every core is built on the unit disc (radius 1 = the core's radius) and
// drawn under canvas.scale, so its gradients are built once per skin.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flutter/painting.dart';

// ── look ────────────────────────────────────────────────────────────────────

/// One core's colours, and the unit shaders built from them.
class OrbLook {
  OrbLook._(this.ink, this.rim, this.essence, this.hot);

  /// The glass, the edge that catches the light, the light, its centre.
  final Color ink, rim, essence, hot;

  Color _a(Color c, double a) => c.withValues(alpha: a);

  late final ui.Shader pool = ui.Gradient.radial(
    Offset.zero,
    1,
    [_a(essence, 0.22), _a(essence, 0.08), _a(essence, 0)],
    const [0.0, 0.42, 1.0],
  );

  /// Dark glass lit from inside: light deep in the middle, a black body,
  /// the rim catching it.
  late final ui.Shader body = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      Color.lerp(ink, essence, 0.34)!,
      ink,
      Color.lerp(ink, rim, 0.12)!,
      Color.lerp(ink, rim, 0.32)!,
      _a(Color.lerp(ink, rim, 0.3)!, 0),
    ],
    const [0.0, 0.5, 0.8, 0.95, 1.0],
  );

  /// The glass catching the light on one shoulder: a soft crescent, not a
  /// bead.
  late final ui.Shader sheen = ui.Gradient.radial(
    const Offset(-0.32, -0.38),
    0.62,
    [_a(rim, 0.34), _a(rim, 0.1), _a(rim, 0)],
    const [0.0, 0.5, 1.0],
  );

  late final ui.Shader iris = ui.Gradient.radial(
    Offset.zero,
    1,
    [hot, essence, _a(Color.lerp(essence, ink, 0.3)!, 0.6), _a(essence, 0)],
    const [0.0, 0.35, 0.72, 1.0],
  );

  late final ui.Shader spark = ui.Gradient.radial(
    Offset.zero,
    1,
    [const Color(0xFFFFFFFF), hot, _a(essence, 0.7), _a(essence, 0)],
    const [0.0, 0.22, 0.5, 1.0],
  );

  late final ui.Shader seam = ui.Gradient.radial(
    Offset.zero,
    1,
    [hot, essence, Color.lerp(essence, ink, 0.4)!],
    const [0.0, 0.5, 1.0],
  );

  late final Color grainDim = _a(Color.lerp(rim, essence, 0.5)!, 0.7);
  late final Color grainLit = Color.lerp(essence, hot, 0.6)!;

  /// Health cells in this light, warming as the core is hurt.
  Color hpColor(double frac) => frac > 0.5
      ? Color.lerp(essence, hot, 0.25)!
      : frac > 0.25
      ? const Color(0xFFF2C96F)
      : const Color(0xFFFF5A57);
}

final Map<OrbBaseSkin, OrbLook> _looks = {
  OrbBaseSkin.defaultOrb: OrbLook._(
    const Color(0xFF04090D),
    const Color(0xFF7FE8F5),
    const Color(0xFF1FD3EA),
    const Color(0xFFE6FDFF),
  ),
  OrbBaseSkin.voidforgeOrb: OrbLook._(
    const Color(0xFF06030C),
    const Color(0xFF9A6AE0),
    const Color(0xFFB44DFF),
    const Color(0xFFF2DDFF),
  ),
  OrbBaseSkin.celestialOrb: OrbLook._(
    const Color(0xFF120B03),
    const Color(0xFFFFE08A),
    const Color(0xFFFFC23A),
    const Color(0xFFFFF8DC),
  ),
  OrbBaseSkin.infernalOrb: OrbLook._(
    const Color(0xFF0C0504),
    const Color(0xFFFF8A4A),
    const Color(0xFFFF5A1F),
    const Color(0xFFFFE0B0),
  ),
  OrbBaseSkin.frozenNexusOrb: OrbLook._(
    const Color(0xFF06101A),
    const Color(0xFFCFF4FF),
    const Color(0xFF8FE3FF),
    const Color(0xFFF2FCFF),
  ),
  OrbBaseSkin.phantomWispOrb: OrbLook._(
    const Color(0xFF031410),
    const Color(0xFF7BFFCE),
    const Color(0xFF4DFFBE),
    const Color(0xFFE6FFF6),
  ),
  OrbBaseSkin.prismHeartOrb: OrbLook._(
    const Color(0xFF0A0614),
    const Color(0xFFD8C8FF),
    const Color(0xFFF07AD0),
    const Color(0xFFFFFFFF),
  ),
  OrbBaseSkin.verdantBloomOrb: OrbLook._(
    const Color(0xFF050D04),
    const Color(0xFFB6F07A),
    const Color(0xFF6EE04A),
    const Color(0xFFF4FFD8),
  ),
};

/// The colours of [skin]'s core.
OrbLook orbLook(OrbBaseSkin skin) =>
    _looks[skin] ?? _looks[OrbBaseSkin.defaultOrb]!;

// ── drawing state ───────────────────────────────────────────────────────────

final Paint _fill = Paint();
final Paint _dots = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

void _shade(ui.Shader s, double alpha) {
  _fill
    ..shader = s
    ..colorFilter = null
    ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
}

void _disc(
  Canvas c,
  ui.Shader s,
  double r, [
  double a = 1,
  Offset at = Offset.zero,
]) {
  if (a <= 0.004 || r <= 0) return;
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(r);
  _shade(s, a);
  c.drawCircle(Offset.zero, 1, _fill);
  c.restore();
}

void _path(Canvas c, Path p, ui.Shader s, [double a = 1]) {
  if (a <= 0.004) return;
  _shade(s, a);
  c.drawPath(p, _fill);
}

/// Point buffers, reused every frame: far grains, near grains, lit grains.
final List<Float32List> _buf = List.generate(4, (_) => Float32List(1024));
final List<int> _n = List.filled(4, 0);

void _reset() => _n.fillRange(0, 4, 0);

void _add(int b, double x, double y) {
  final i = _n[b] * 2;
  if (i + 2 > _buf[b].length) return;
  _buf[b][i] = x;
  _buf[b][i + 1] = y;
  _n[b]++;
}

void _flush(Canvas c, int b, double d, Color col) {
  if (_n[b] == 0 || col.a <= 0) return;
  _dots
    ..strokeWidth = d
    ..color = col;
  c.drawRawPoints(
    ui.PointMode.points,
    Float32List.sublistView(_buf[b], 0, _n[b] * 2),
    _dots,
  );
}

double _frac(double x) => x - x.floorToDouble();

/// The glass's shoulder catching light, and one small glint on it.
void _glass(Canvas c, OrbLook l, [double a = 1]) {
  _disc(c, l.sheen, 1, a);
  _disc(c, l.spark, 0.07, 0.55 * a, const Offset(-0.42, -0.46));
}

/// A seam of light along [pts]: widest in the middle, closing at both ends.
Path _seam(List<Offset> pts, double w) {
  final left = <Offset>[], right = <Offset>[];
  for (var i = 0; i < pts.length; i++) {
    final a = pts[max(0, i - 1)], b = pts[min(pts.length - 1, i + 1)];
    var d = b - a;
    d = d / max(d.distance, 1e-5);
    final n = Offset(-d.dy, d.dx) * (w / 2 * sin(pi * i / (pts.length - 1)));
    left.add(pts[i] + n);
    right.add(pts[i] - n);
  }
  final p = Path()..moveTo(left.first.dx, left.first.dy);
  for (final q in left.skip(1)) {
    p.lineTo(q.dx, q.dy);
  }
  for (final q in right.reversed) {
    p.lineTo(q.dx, q.dy);
  }
  return p..close();
}

/// A jagged line across the face of the sphere, kept inside it.
List<Offset> _crack(Random r, {double reach = 0.9}) {
  final a = r.nextDouble() * 2 * pi;
  var p = Offset(cos(a), sin(a)) * (0.1 + r.nextDouble() * 0.25);
  final dir = a + (r.nextDouble() - 0.5) * 1.2;
  final pts = [p];
  final steps = 4 + r.nextInt(3);
  for (var i = 0; i < steps; i++) {
    final turn = dir + (r.nextDouble() - 0.5) * 1.3;
    p += Offset(cos(turn), sin(turn)) * (0.12 + r.nextDouble() * 0.1);
    if (p.distance > reach) p = p / p.distance * reach;
    pts.add(p);
  }
  return pts;
}

// ── a ring of grains ────────────────────────────────────────────────────────

/// Grains on real orbits in a tilted plane: (radius, start, rate, phase).
class _Ring {
  _Ring(
    int seed,
    int count,
    double inner,
    double outer, {
    this.flat = 0.34,
    this.tilt = -0.32,
    this.speed = 0.5,
  }) : grains = _build(seed, count, inner, outer);

  static List<(double, double, double, double)> _build(
    int seed,
    int count,
    double inner,
    double outer,
  ) {
    final r = Random(seed);
    final out = <(double, double, double, double)>[];
    for (var i = 0; i < count; i++) {
      final rad = inner + (outer - inner) * pow(r.nextDouble(), 0.8);
      out.add((
        rad,
        r.nextDouble() * 2 * pi,
        1 / (rad * sqrt(rad)),
        r.nextDouble() * 2 * pi,
      ));
    }
    return out;
  }

  final List<(double, double, double, double)> grains;
  final double flat, tilt, speed;

  /// Splits the ring into buffers 0 (far), 1 (near), 2 (glinting).
  void gather(double t) {
    final ct = cos(tilt), st = sin(tilt);
    for (final (rad, a0, rate, ph) in grains) {
      final a = a0 + t * rate * speed;
      final x = cos(a) * rad, y = sin(a) * rad * flat;
      final px = x * ct - y * st, py = x * st + y * ct;
      if (sin(t * 2.3 + ph) > 0.9) {
        _add(2, px, py);
      } else {
        _add(sin(a) < 0 ? 0 : 1, px, py);
      }
    }
  }
}

// ── the cores ───────────────────────────────────────────────────────────────

final _standardRing = _Ring(11, 96, 1.32, 1.78);
final _voidCracks = () {
  final r = Random(23);
  return [for (var i = 0; i < 5; i++) _seam(_crack(r), 0.07)];
}();
final _infernalVeins = () {
  final r = Random(5);
  return [
    for (var i = 0; i < 8; i++)
      _seam(_crack(r, reach: 0.95), 0.05 + 0.04 * (i % 3)),
  ];
}();

/// (start angle, phase, speed) for drifting motes.
final List<(double, double, double)> _motes = () {
  final r = Random(31);
  return [
    for (var i = 0; i < 64; i++)
      (r.nextDouble() * 2 * pi, r.nextDouble(), 0.7 + r.nextDouble() * 0.6),
  ];
}();

void _standard(Canvas c, OrbLook l, double t) {
  final breathe = 1 + 0.06 * sin(t * 1.7);
  _disc(c, l.pool, 2.0);
  _reset();
  _standardRing.gather(t);
  _flush(c, 0, 0.032, l.grainDim.withValues(alpha: 0.45));
  _disc(c, l.body, 1);
  _disc(c, l.iris, 0.56 * breathe, 0.95, const Offset(0, -0.05));
  _glass(c, l);
  _flush(c, 1, 0.038, l.grainDim);
  _flush(c, 2, 0.05, l.grainLit);
}

void _voidforge(Canvas c, OrbLook l, double t) {
  _disc(c, l.pool, 2.1);
  // Grains spiralling into the core along a flattened disk.
  _reset();
  for (var i = 0; i < _motes.length; i++) {
    final (a0, ph, sp) = _motes[i];
    final p = _frac(t * 0.11 * sp + ph);
    final r = 2.15 - 1.1 * p;
    final a = a0 + t * 0.9 * sp / (r * sqrt(r)) + p * 3;
    final x = cos(a) * r, y = sin(a) * r * 0.36;
    final px = x * 0.94 - y * 0.34, py = x * 0.34 + y * 0.94;
    _add(sin(a) < 0 ? 0 : (p > 0.75 ? 2 : 1), px, py);
  }
  _flush(c, 0, 0.03, l.grainDim.withValues(alpha: 0.5));
  _disc(c, l.body, 1);
  // Its light only gets out through the cracks.
  final flick = 0.62 + 0.24 * sin(t * 2.3) + 0.14 * sin(t * 6.1 + 1);
  for (var i = 0; i < _voidCracks.length; i++) {
    _path(c, _voidCracks[i], l.seam, flick * (0.75 + 0.25 * sin(t * 1.3 + i)));
  }
  _disc(c, l.iris, 0.3, 0.55 + 0.25 * flick);
  _glass(c, l);
  _flush(c, 1, 0.036, l.grainDim);
  _flush(c, 2, 0.05, l.grainLit);
}

final List<(double, double, double)> _rays = () {
  final r = Random(7);
  return [
    for (var i = 0; i < 30; i++)
      (
        r.nextDouble() * 2 * pi,
        1.12 + r.nextDouble() * 0.38,
        r.nextDouble() * 2 * pi,
      ),
  ];
}();

void _celestial(Canvas c, OrbLook l, double t, double beat) {
  // [beat] runs 0→1 between heals; just after one, the sun flares.
  final flare = beat < 0.08 ? 1 - beat / 0.08 : 0.0;
  _disc(c, l.pool, 2.5 + 0.4 * flare, 1);
  // The corona: many short, faint streamers off the limb, each breathing
  // on its own, so the edge of the sun shimmers rather than spikes.
  final rays = Path();
  final spin = t * 0.03;
  for (final (a0, len, ph) in _rays) {
    final a = a0 + spin;
    final reach = len * (0.9 + 0.14 * sin(t * 0.9 + ph)) + 0.25 * flare;
    final tip = Offset(cos(a), sin(a)) * reach;
    final side = Offset(-sin(a), cos(a)) * 0.075;
    final base = Offset(cos(a), sin(a)) * 0.9;
    rays
      ..moveTo(base.dx + side.dx, base.dy + side.dy)
      ..quadraticBezierTo(
        (base.dx + tip.dx) / 2 + side.dx * 0.3,
        (base.dy + tip.dy) / 2 + side.dy * 0.3,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        (base.dx + tip.dx) / 2 - side.dx * 0.3,
        (base.dy + tip.dy) / 2 - side.dy * 0.3,
        base.dx - side.dx,
        base.dy - side.dy,
      )
      ..close();
  }
  _path(c, rays, _celestialRays(l), 0.2 + 0.3 * flare);
  _disc(c, _corona(l), 1.45, 0.9 + 0.3 * flare);
  // Motes lifting off the surface and fading.
  _reset();
  for (var i = 0; i < 48; i++) {
    final (a0, ph, sp) = _motes[i];
    final p = _frac(t * 0.12 * sp + ph);
    final r = 1.04 + 0.95 * p;
    _add(p < 0.4 ? 2 : 1, cos(a0 + t * 0.05) * r, sin(a0 + t * 0.05) * r);
  }
  _disc(c, _celestialBody(l), 1);
  _disc(c, l.iris, 0.62, 0.7);
  _flush(c, 1, 0.03, l.grainDim);
  _flush(c, 2, 0.042, l.grainLit);
}

final Map<OrbLook, ui.Shader> _coronas = {};

/// A soft band of light hugging the limb.
ui.Shader _corona(OrbLook l) => _coronas[l] ??= ui.Gradient.radial(
  Offset.zero,
  1,
  [
    l.essence.withValues(alpha: 0),
    l.essence.withValues(alpha: 0),
    l.hot.withValues(alpha: 0.32),
    l.essence.withValues(alpha: 0.1),
    l.essence.withValues(alpha: 0),
  ],
  const [0.0, 0.62, 0.69, 0.8, 1.0],
);

final Map<OrbLook, ui.Shader> _rayShaders = {};
ui.Shader _celestialRays(OrbLook l) => _rayShaders[l] ??= ui.Gradient.radial(
  Offset.zero,
  1.6,
  [l.hot, l.essence.withValues(alpha: 0.45), l.essence.withValues(alpha: 0)],
  const [0.55, 0.72, 1.0],
);

final Map<OrbLook, ui.Shader> _sunShaders = {};

/// The sun is all light: bright to the limb, darkening only at its edge.
ui.Shader _celestialBody(OrbLook l) => _sunShaders[l] ??= ui.Gradient.radial(
  Offset.zero,
  1,
  [
    l.hot,
    l.essence,
    Color.lerp(l.essence, const Color(0xFFB0560C), 0.6)!,
    Color.lerp(l.essence, l.ink, 0.72)!,
  ],
  const [0.0, 0.4, 0.82, 1.0],
);

void _infernal(Canvas c, OrbLook l, double t) {
  final heat = 0.7 + 0.18 * sin(t * 5.3) + 0.12 * sin(t * 12.7 + 0.7);
  _disc(c, l.pool, 2.3);
  if (_showReach) _disc(c, _burnReach(l), _infernalReach);
  // Embers rising off the shell as far as the burn reaches.
  _reset();
  for (final (a0, ph, sp) in _motes) {
    final p = _frac(t * 0.28 * sp + ph);
    final r = 1.0 + (_infernalReach - 1.0) * p;
    final a = a0 + sin(t * 0.7 + ph * 9) * 0.25;
    _add(p < 0.35 ? 2 : 1, cos(a) * r, sin(a) * r - p * 0.35);
  }
  _disc(c, l.body, 1);
  for (var i = 0; i < _infernalVeins.length; i++) {
    _path(
      c,
      _infernalVeins[i],
      l.seam,
      heat * (0.8 + 0.2 * sin(t * 2.1 + i * 1.7)),
    );
  }
  _disc(c, l.iris, 0.4, 0.5 * heat);
  _glass(c, l);
  _flush(c, 1, 0.034, l.grainDim);
  _flush(c, 2, 0.046, l.grainLit);
}

/// Whether this core's aura reach is drawn (see [paintOrbCore]).
bool _showReach = true;

/// The burn aura's 160 against the core's 72.
const double _infernalReach = 160 / 72;

/// The slow aura's 200 against the core's 72.
const double _frozenReach = 200 / 72;

final Map<OrbLook, ui.Shader> _reachShaders = {};

/// A faint pool of the core's light out to the edge of what it does.
ui.Shader _burnReach(OrbLook l) => _reachShaders[l] ??= ui.Gradient.radial(
  Offset.zero,
  1,
  [
    l.essence.withValues(alpha: 0),
    l.essence.withValues(alpha: 0.05),
    l.essence.withValues(alpha: 0.09),
    l.essence.withValues(alpha: 0),
  ],
  const [0.0, 0.55, 0.9, 1.0],
);

/// Rime on the ice: specks near the limb, where frost would gather.
final List<(double, double)> _rime = () {
  final r = Random(61);
  return [
    for (var i = 0; i < 46; i++)
      (r.nextDouble() * 2 * pi, 0.72 + 0.26 * sqrt(r.nextDouble())),
  ];
}();

final _frostShards = _Ring(
  41,
  7,
  1.42,
  1.62,
  flat: 0.48,
  tilt: 0.2,
  speed: 0.8,
);

/// The ice: six outer facets turned to the light at different angles, and
/// a brighter table in the middle where the light comes through.
final List<(Path, double)> _iceFacets = () {
  final out = <(Path, double)>[];
  for (var i = 0; i < 6; i++) {
    final a0 = i * pi / 3 - pi / 2, a1 = a0 + pi / 3;
    final p = Path()
      ..moveTo(cos(a0) * 0.46, sin(a0) * 0.46)
      ..lineTo(cos(a0) * 1.02, sin(a0) * 1.02)
      ..lineTo(cos(a1) * 1.02, sin(a1) * 1.02)
      ..lineTo(cos(a1) * 0.46, sin(a1) * 0.46)
      ..close();
    // The upper-left facets catch the most light.
    out.add((p, 0.5 + 0.5 * cos(a0 + pi / 6 + 2.3)));
  }
  return out;
}();
final Path _iceTable = () {
  final p = Path();
  for (var i = 0; i < 6; i++) {
    final a = i * pi / 3 - pi / 2;
    i == 0
        ? p.moveTo(cos(a) * 0.46, sin(a) * 0.46)
        : p.lineTo(cos(a) * 0.46, sin(a) * 0.46);
  }
  return p..close();
}();

final Map<OrbLook, List<ui.Shader>> _facetShaders = {};

List<ui.Shader> _facetsFor(OrbLook l) => _facetShaders[l] ??= [
  for (final (_, lit) in _iceFacets)
    ui.Gradient.radial(Offset.zero, 1.05, [
      Color.lerp(l.ink, l.essence, 0.25 + 0.3 * lit)!,
      Color.lerp(l.ink, l.rim, 0.12 + 0.5 * lit)!,
    ]),
];

void _frozen(Canvas c, OrbLook l, double t) {
  _disc(c, l.pool, 1.9);
  if (_showReach) _disc(c, _burnReach(l), _frozenReach);
  // Frost motes turning lazily through the slow.
  _reset();
  for (var i = 0; i < 40; i++) {
    final (a0, ph, sp) = _motes[i];
    final a = a0 + t * 0.06 * sp;
    final r = 1.25 + (_frozenReach - 1.35) * ph + 0.06 * sin(t * 0.8 + i);
    _add(sin(t * 1.9 + i * 2.1) > 0.8 ? 2 : 3, cos(a) * r, sin(a) * r);
  }
  _flush(c, 3, 0.028, l.grainDim.withValues(alpha: 0.45));
  _flush(c, 2, 0.04, l.grainLit);
  _reset();
  _frostShards.gather(t);
  for (final (a, r) in _rime) {
    _add(3, cos(a) * r, sin(a) * r);
  }
  _shards(c, l, 0);
  // A sphere of dark ice with the crystal it grew from lit inside it.
  _disc(c, l.body, 1);
  c.save();
  c.scale(0.6);
  c.rotate(t * 0.05);
  final facets = _facetsFor(l);
  for (var i = 0; i < _iceFacets.length; i++) {
    _path(c, _iceFacets[i].$1, facets[i], 0.9);
  }
  _path(c, _iceTable, l.iris, 0.85 + 0.1 * sin(t * 1.4));
  c.restore();
  _disc(c, l.spark, 0.12, 0.85);
  // Rime on the glass.
  _flush(c, 3, 0.02, l.hot.withValues(alpha: 0.35));
  _glass(c, l);
  _shards(c, l, 1);
}

/// The frost shards in buffer [b] as small two-tone diamonds.
void _shards(Canvas c, OrbLook l, int b) {
  final n = _n[b];
  if (n == 0) return;
  final dark = Path(), lit = Path();
  final buf = _buf[b];
  for (var i = 0; i < n; i++) {
    final x = buf[i * 2], y = buf[i * 2 + 1];
    const h = 0.13, w = 0.065;
    dark
      ..moveTo(x, y - h)
      ..lineTo(x + w, y)
      ..lineTo(x, y + h)
      ..close();
    lit
      ..moveTo(x, y - h)
      ..lineTo(x - w, y)
      ..lineTo(x, y + h)
      ..close();
  }
  _fill
    ..shader = null
    ..colorFilter = null
    ..color = Color.lerp(l.ink, l.essence, 0.45)!.withValues(alpha: 0.95);
  c.drawPath(dark, _fill);
  _fill.color = l.rim.withValues(alpha: 0.95);
  c.drawPath(lit, _fill);
}

void _phantom(Canvas c, OrbLook l, double t) {
  // Comes and goes — but the faintest it gets is still plainly there.
  final phase = 0.78 + 0.12 * sin(t * 1.6) + 0.1 * sin(t * 3.7 + 1.2);
  _disc(c, l.pool, 2.0, 0.6 + 0.4 * phase);
  // A veil of its light drifting round the glass.
  _disc(
    c,
    _veil(l),
    1.55,
    0.8 * phase,
    Offset(sin(t * 0.6) * 0.06, cos(t * 0.5) * 0.05),
  );
  _disc(c, l.body, 1, 0.88);
  // Wisps drifting inside, each with a short trail of where it has been.
  _reset();
  for (var w = 0; w < 3; w++) {
    Offset at(double s) => Offset(
      sin(s * (0.9 + w * 0.23) + w * 2.1) * 0.5,
      sin(s * (0.7 + w * 0.31) + w) * 0.42,
    );
    for (var k = 1; k <= 8; k++) {
      final p = at(t - k * 0.09);
      _add(k < 4 ? 1 : 0, p.dx, p.dy);
    }
    _disc(c, l.spark, 0.13, phase, at(t));
  }
  _flush(c, 0, 0.03, l.grainDim.withValues(alpha: 0.45 * phase));
  _flush(c, 1, 0.04, l.grainLit.withValues(alpha: 0.75 * phase));
  _glass(c, l, 0.8);
}

final Map<OrbLook, ui.Shader> _veils = {};
ui.Shader _veil(OrbLook l) => _veils[l] ??= ui.Gradient.radial(
  Offset.zero,
  1,
  [
    l.essence.withValues(alpha: 0),
    l.essence.withValues(alpha: 0),
    l.essence.withValues(alpha: 0.18),
    l.essence.withValues(alpha: 0),
  ],
  const [0.0, 0.6, 0.72, 1.0],
);

/// The gem: an octagon cut into eight facets, and its table.
final List<Path> _gemFacets = [
  for (var i = 0; i < 8; i++)
    () {
      final a0 = i * pi / 4 - pi / 8, a1 = a0 + pi / 4;
      return Path()
        ..moveTo(cos(a0) * 0.52, sin(a0) * 0.52)
        ..lineTo(cos(a0) * 1.0, sin(a0) * 1.0)
        ..lineTo(cos(a1) * 1.0, sin(a1) * 1.0)
        ..lineTo(cos(a1) * 0.52, sin(a1) * 0.52)
        ..close();
    }(),
];
final Path _gemTable = () {
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final a = i * pi / 4 - pi / 8;
    i == 0
        ? p.moveTo(cos(a) * 0.52, sin(a) * 0.52)
        : p.lineTo(cos(a) * 0.52, sin(a) * 0.52);
  }
  return p..close();
}();

final Map<OrbLook, ui.Shader> _gemFaces = {};

/// A facet of dark glass whose outer edge catches light — in white, so the
/// light's colour can be laid over it as it shifts.
ui.Shader _gemFace(OrbLook l) => _gemFaces[l] ??= ui.Gradient.radial(
  Offset.zero,
  1.0,
  [
    Color.lerp(l.ink, const Color(0xFFFFFFFF), 0.12)!,
    l.ink,
    Color.lerp(l.ink, const Color(0xFFFFFFFF), 0.7)!,
  ],
  const [0.5, 0.78, 1.0],
);

void _prism(Canvas c, OrbLook l, double t) {
  _disc(c, l.pool, 2.0);
  final face = _gemFace(l);
  final spin = t * 0.12;
  c.save();
  c.rotate(spin);
  for (var i = 0; i < _gemFacets.length; i++) {
    // Each facet throws its own colour, and the colours walk round.
    final hue = (t * 22 + i * 45) % 360;
    final col = HSVColor.fromAHSV(1, hue, 0.5, 1).toColor();
    _fill
      ..shader = face
      ..color = const Color(0xFFFFFFFF)
      ..colorFilter = ColorFilter.mode(col, BlendMode.modulate);
    c.drawPath(_gemFacets[i], _fill);
  }
  _fill.colorFilter = null;
  _path(c, _gemTable, l.iris, 0.9);
  c.restore();
  // Spectral glints round the stone.
  _reset();
  for (var i = 0; i < 28; i++) {
    final (a0, ph, sp) = _motes[i];
    final a = a0 + t * 0.15 * sp;
    final r = 1.12 + 0.5 * ph;
    if (sin(t * 3 * sp + i) > 0.55) _add(i % 3, cos(a) * r, sin(a) * r);
  }
  for (var b = 0; b < 3; b++) {
    _flush(
      c,
      b,
      0.045,
      HSVColor.fromAHSV(0.9, (t * 22 + b * 120) % 360, 0.45, 1).toColor(),
    );
  }
  _disc(
    c,
    l.spark,
    0.2,
    0.9,
    Offset(cos(spin + 2.4) * 0.12, sin(spin + 2.4) * 0.12),
  );
}

/// The tendrils: each a curve out from behind the seed, with a leaf.
final List<(List<Offset>, bool)> _tendrils = () {
  final r = Random(13);
  return [
    for (var i = 0; i < 6; i++)
      () {
        final a = i * pi / 3 + r.nextDouble() * 0.5;
        final bend = (r.nextBool() ? 1 : -1) * (0.5 + r.nextDouble() * 0.4);
        final len = 1.45 + r.nextDouble() * 0.35;
        return (
          [
            for (var k = 0; k <= 8; k++)
              () {
                final f = k / 8;
                final rad = 0.82 + (len - 0.82) * f;
                final ang = a + bend * f * f;
                return Offset(cos(ang) * rad, sin(ang) * rad);
              }(),
          ],
          i.isEven,
        );
      }(),
  ];
}();

void _verdant(Canvas c, OrbLook l, double t) {
  // A heartbeat: lub, dub, rest — the regen it is known for.
  final b = _frac(t / 1.6);
  final beat =
      exp(-pow((b - 0.04) / 0.05, 2).toDouble()) +
      0.6 * exp(-pow((b - 0.22) / 0.05, 2).toDouble());
  _disc(c, l.pool, 2.0 + 0.15 * beat);
  final vine = _vine(l);
  for (final (pts, behind) in _tendrils) {
    if (behind) _tendril(c, vine, l, pts, t);
  }
  // Pollen drifting up and out.
  _reset();
  for (var i = 0; i < 36; i++) {
    final (a0, ph, sp) = _motes[i];
    final p = _frac(t * 0.08 * sp + ph);
    final r = 1.1 + 0.9 * p;
    _add(p < 0.3 ? 2 : 1, cos(a0) * r, sin(a0) * r - p * 0.4);
  }
  _disc(c, l.body, 1);
  _disc(c, l.iris, 0.5 * (1 + 0.16 * beat), 0.9);
  _glass(c, l);
  for (final (pts, behind) in _tendrils) {
    if (!behind) _tendril(c, vine, l, pts, t);
  }
  _flush(c, 1, 0.03, l.grainDim);
  _flush(c, 2, 0.042, l.grainLit);
}

final Map<OrbLook, ui.Shader> _vines = {};
ui.Shader _vine(OrbLook l) => _vines[l] ??= ui.Gradient.radial(
  Offset.zero,
  1.9,
  [
    Color.lerp(l.essence, l.ink, 0.35)!,
    Color.lerp(l.essence, l.ink, 0.7)!,
    Color.lerp(l.rim, l.ink, 0.35)!,
  ],
  const [0.42, 0.75, 1.0],
);

void _tendril(Canvas c, ui.Shader vine, OrbLook l, List<Offset> pts, double t) {
  final sway = sin(t * 0.9 + pts.last.dx * 3) * 0.04;
  final moved = [
    for (var i = 0; i < pts.length; i++)
      pts[i] + Offset(-pts[i].dy, pts[i].dx) * (sway * i / pts.length),
  ];
  _path(c, _seam(moved, 0.11), vine, 0.95);
  // A leaf two-thirds of the way out.
  final at = moved[5], next = moved[6];
  final d = next - at;
  final ang = atan2(d.dy, d.dx) + 0.9;
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(ang);
  final leaf = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(0.13, -0.1, 0.32, 0)
    ..quadraticBezierTo(0.13, 0.1, 0, 0)
    ..close();
  _path(c, leaf, vine, 0.95);
  c.restore();
}

/// Draws [skin]'s core at the origin, [radius] across in world units, at
/// [time]. [beat] (0..1) is how far a Celestial core is through the wait for
/// its next heal; it flares just after one. [reach] draws how far an aura
/// core's aura reaches; small pictures leave it out.
void paintOrbCore(
  Canvas c,
  OrbBaseSkin skin,
  double time, {
  double radius = 72,
  double beat = 1,
  bool reach = true,
}) {
  final l = orbLook(skin);
  _showReach = reach;
  c.save();
  c.scale(radius);
  switch (skin) {
    case OrbBaseSkin.defaultOrb:
      _standard(c, l, time);
    case OrbBaseSkin.voidforgeOrb:
      _voidforge(c, l, time);
    case OrbBaseSkin.celestialOrb:
      _celestial(c, l, time, beat);
    case OrbBaseSkin.infernalOrb:
      _infernal(c, l, time);
    case OrbBaseSkin.frozenNexusOrb:
      _frozen(c, l, time);
    case OrbBaseSkin.phantomWispOrb:
      _phantom(c, l, time);
    case OrbBaseSkin.prismHeartOrb:
      _prism(c, l, time);
    case OrbBaseSkin.verdantBloomOrb:
      _verdant(c, l, time);
  }
  c.restore();
}

// ── readings ────────────────────────────────────────────────────────────────

/// A ring of [cells] cells between [inner] and [outer], built once: the
/// dim track, and the lit run for every count of lit cells.
class _CellRing {
  _CellRing(this.cells, double inner, double outer, {double gap = 0.035}) {
    final sectors = <Path>[];
    for (var i = 0; i < cells; i++) {
      final a0 = -pi / 2 + i * 2 * pi / cells + gap / 2;
      final a1 = a0 + 2 * pi / cells - gap;
      sectors.add(
        Path()
          ..arcTo(
            Rect.fromCircle(center: Offset.zero, radius: outer),
            a0,
            a1 - a0,
            true,
          )
          ..arcTo(
            Rect.fromCircle(center: Offset.zero, radius: inner),
            a1,
            a0 - a1,
            false,
          )
          ..close(),
      );
    }
    _sectors = sectors;
    track = Path();
    for (final s in sectors) {
      track.addPath(s, Offset.zero);
    }
    _lit = List.generate(cells + 1, (k) {
      final p = Path();
      for (var i = 0; i < k; i++) {
        p.addPath(sectors[i], Offset.zero);
      }
      return p;
    });
  }

  final int cells;
  late final List<Path> _sectors;
  late final Path track;
  late final List<Path> _lit;

  Path lit(int k) => _lit[k.clamp(0, cells)];
  Path cell(int i) => _sectors[i.clamp(0, cells - 1)];
}

final _hpRing = _CellRing(60, 108, 114, gap: 0.03);
final _meterRing = _CellRing(84, 157, 161, gap: 0.025);
final Paint _cellPaint = Paint();

final ui.Shader _meterShader = ui.Gradient.sweep(
  Offset.zero,
  const [
    Color(0xFF6C5CE7),
    Color(0xFF9B59B6),
    Color(0xFFE056FD),
    Color(0xFF00D2FF),
    Color(0xFF6C5CE7),
  ],
  const [0.0, 0.28, 0.56, 0.82, 1.0],
  TileMode.clamp,
  -pi / 2,
  3 * pi / 2,
);

final ui.Shader _shieldShader = ui.Gradient.radial(
  Offset.zero,
  1,
  const [
    Color(0x007FDBFF),
    Color(0x007FDBFF),
    Color(0x557FDBFF),
    Color(0xCCB8ECFF),
    Color(0x00B8ECFF),
  ],
  const [0.0, 0.8, 0.93, 0.975, 1.0],
);

/// The core's readings round it, at the origin in world units: health in
/// a ring of cells just outside the core, the alchemy meter outside that,
/// and — while it holds — the shield as a glass bubble. [time] makes a
/// failing core's last cells pulse.
void paintOrbReadings(
  Canvas c,
  OrbBaseSkin skin, {
  required double hpFrac,
  required double meterFrac,
  double shield = 0,
  double shieldRadius = 136,
  double time = 0,
}) {
  final l = orbLook(skin);
  if (shield > 0) {
    c.save();
    c.scale(shieldRadius);
    _shade(_shieldShader, (0.45 + shield).clamp(0.4, 1.0));
    c.drawCircle(Offset.zero, 1, _fill);
    c.restore();
  }

  _cellPaint
    ..shader = null
    ..color = const Color(0xFF2A2F3A).withValues(alpha: 0.4);
  c.drawPath(_hpRing.track, _cellPaint);
  final hp = hpFrac.clamp(0.0, 1.0);
  final whole = (hp * _hpRing.cells).floor();
  final part = hp * _hpRing.cells - whole;
  final pulse = hp < 0.25 ? 0.75 + 0.25 * sin(time * 6) : 1.0;
  _cellPaint.color = l.hpColor(hp).withValues(alpha: 0.78 * pulse);
  c.drawPath(_hpRing.lit(whole), _cellPaint);
  if (part > 0.02 && whole < _hpRing.cells) {
    _cellPaint.color = l.hpColor(hp).withValues(alpha: 0.78 * part * pulse);
    c.drawPath(_hpRing.cell(whole), _cellPaint);
  }

  _cellPaint
    ..shader = null
    ..color = const Color(0xFF3A2E5A).withValues(alpha: 0.28);
  c.drawPath(_meterRing.track, _cellPaint);
  final m = meterFrac.clamp(0.0, 1.0);
  final lit = (m * _meterRing.cells).round();
  if (lit > 0) {
    _cellPaint
      ..shader = _meterShader
      ..color = const Color(0xCCFFFFFF);
    c.drawPath(_meterRing.lit(lit), _cellPaint);
    _cellPaint.shader = null;
  }
}

// ── the gravity field ───────────────────────────────────────────────────────

/// Dust in lanes round the orb: (lane, angle, radius jitter, size).
final List<(int, double, double, double)> _lanes = () {
  final r = Random(57);
  return [
    for (var lane = 0; lane < 4; lane++)
      for (var i = 0; i < 70 + lane * 14; i++)
        (
          lane,
          r.nextDouble() * 2 * pi,
          (r.nextDouble() - 0.5) * 14,
          0.6 + r.nextDouble() * 0.8,
        ),
  ];
}();

/// The run's spacing between the field's lanes, in world units.
const double kOrbFieldLaneGap = 92;

/// The field the ship orbits in, centred on the origin: four lanes of dust
/// turning slowly, the innermost on the ship's own orbit and brightest.
void paintOrbField(
  Canvas c,
  OrbBaseSkin skin,
  double time, {
  double orbit = 270,
  double laneGap = kOrbFieldLaneGap,
}) {
  final l = orbLook(skin);
  _reset();
  for (final (lane, a0, jitter, _) in _lanes) {
    final a = a0 + time * (0.05 - lane * 0.008) * (lane.isEven ? 1 : -1);
    final r = orbit + lane * laneGap + jitter;
    _add(min(lane, 3), cos(a) * r, sin(a) * r);
  }
  _flush(c, 0, 3.0, l.grainDim.withValues(alpha: 0.32));
  _flush(c, 1, 2.6, l.grainDim.withValues(alpha: 0.2));
  _flush(c, 2, 2.4, l.grainDim.withValues(alpha: 0.13));
  _flush(c, 3, 2.2, l.grainDim.withValues(alpha: 0.08));
}

// ── the core giving out ─────────────────────────────────────────────────────

/// How long the core takes to come apart once its health is gone.
const double kCoreFallSeconds = 2.6;

/// The core's grains for its fall: (angle, depth 0 centre..1 rim, reach,
/// turn, colour bucket). Laid out once.
final List<(double, double, double, double, int)> _fallGrains = () {
  final r = Random(83);
  return [
    for (var i = 0; i < 300; i++)
      (
        r.nextDouble() * 2 * pi,
        sqrt(r.nextDouble()),
        1.1 + pow(r.nextDouble(), 1.6) * 3.4,
        (r.nextBool() ? 1 : -1) * (0.25 + r.nextDouble() * 0.6),
        i % 7 == 0 ? 0 : (i % 3 == 0 ? 2 : 1),
      ),
  ];
}();

final List<Float32List> _fallBuf = List.generate(9, (_) => Float32List(1024));
final List<int> _fallN = List.filled(9, 0);

double _ease(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The core giving out, centred on the origin, [t] seconds after its health
/// ran out. Its light gutters and the glass draws in, and it comes apart
/// into grains of its own light — the rim first, the heart last — which
/// loosen, drift off on a slow turn and dim as they go. Nothing bursts: the
/// grains leave at rest and ease out, and nothing flashes.
void paintCoreFall(
  Canvas c,
  OrbBaseSkin skin,
  double t,
  double time, {
  double radius = 72,
}) {
  final l = orbLook(skin);

  // The pool of light it stood in, going out.
  final pool = 1 - _ease(0, 1.8, t);
  if (pool > 0.01) _disc(c, l.pool, radius * 2.6, pool);

  // The core itself, dimming and drawing in as its grains leave it.
  final body = 1 - _ease(0.05, 1.1, t);
  if (body > 0.01) {
    final r = radius * (1 - 0.35 * (1 - body));
    c.saveLayer(
      Rect.fromCircle(center: Offset.zero, radius: r * 3.4),
      Paint()..color = Color.fromRGBO(0, 0, 0, body),
    );
    // Its turn slows to a stop rather than freezing with the field.
    paintOrbCore(
      c,
      skin,
      time + 0.6 * (1 - pow(1 - min(t, 1.0), 2)),
      radius: r,
      reach: false,
    );
    c.restore();
  }

  // The grains: buckets are colour (lit, light, dim) × trail (head, mid,
  // tail).
  _fallN.fillRange(0, 9, 0);
  void add(int b, double x, double y) {
    final i = _fallN[b] * 2;
    if (i + 2 > _fallBuf[b].length) return;
    _fallBuf[b][i] = x;
    _fallBuf[b][i + 1] = y;
    _fallN[b]++;
  }

  for (final (a0, depth, reach, turn, col) in _fallGrains) {
    // The rim loosens first; the heart holds longest.
    final leave = 0.08 + 0.75 * (1 - depth);
    final span = 1.5 + 0.5 * reach / 4.5;
    for (var k = 0; k < 3; k++) {
      final q = ((t - k * 0.07 - leave) / span).clamp(0.0, 1.0);
      if (q <= 0) continue;
      // Eased both ends: leaves at rest, drifts, settles to a stop.
      final e = q * q * (3 - 2 * q);
      final d = radius * (depth * 0.9 + (reach - depth * 0.9) * e);
      final a = a0 + turn * e;
      add(col * 3 + k, cos(a) * d, sin(a) * d);
    }
  }

  // The grains appear as the glass gives them up and dim as they drift.
  final glow = _ease(0.05, 0.4, t) * (1 - _ease(1.3, kCoreFallSeconds, t));
  if (glow <= 0.01) return;
  final colours = [l.grainLit, Color.lerp(l.essence, l.rim, 0.3)!, l.grainDim];
  const sizes = [2.6, 2.2, 1.9];
  const trail = [1.0, 0.45, 0.2];
  for (var col = 0; col < 3; col++) {
    for (var k = 0; k < 3; k++) {
      final b = col * 3 + k;
      if (_fallN[b] == 0) continue;
      _dots
        ..strokeWidth = sizes[col] * (1 - 0.18 * k)
        ..color = colours[col].withValues(
          alpha: (colours[col].a * glow * trail[k]).clamp(0.0, 1.0),
        );
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_fallBuf[b], 0, _fallN[b] * 2),
        _dots,
      );
    }
  }
}
