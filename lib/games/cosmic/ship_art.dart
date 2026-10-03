// lib/games/cosmic/ship_art.dart
//
// The player's ship: a hull cut from obsidian with its light trapped inside.
// It is the enemies' material (enemy_body_art.dart) turned to the player's
// side — dark plates whose colour comes only from light: a core burning in
// the canopy, the leading edges catching it, seams where it leaks out
// between plates, the engines' glow on the hull. Nothing strokes an outline,
// a panel line or a hoop.
//
// The five hulls keep the silhouettes they always flew with. What changes
// between them is what they are made of:
//
//   standard        dark glass, teal light
//   Phantom Viper   smoked glass, violet light that comes and goes
//   Solar Dragoon   gilt obsidian round a small sun, a ring of grains
//   Inferno Raptor  obsidian cracked open by the heat inside, shedding embers
//   Crystal Bastion clear faceted glass with ice-light at its heart
//
// The exhaust is a wake of grains left behind in the world, so it curves
// through a turn and stretches with speed; the orbital sentinels are beads
// of the same light held in glass.
//
// Every hull is drawn nose up (−y) in its own units, about 45 tall. The
// plates and their gradients are built once per hull; a frame costs the
// hull's draw calls (about twenty) and the wake's handful of point passes.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

// ── light ───────────────────────────────────────────────────────────────────

/// What a hull is cut from and the light inside it.
class ShipLight {
  ShipLight._(this.ink, this.face, this.rim, this.essence, this.hot);

  /// The obsidian: its dark body, the face nearest the light, the edge that
  /// catches it.
  final Color ink, face, rim;

  /// The trapped light and its white-hot centre.
  final Color essence, hot;

  Color _a(Color c, double a) => c.withValues(alpha: a);

  /// Light pooled round the hull. Unit radius.
  late final ui.Shader pool = ui.Gradient.radial(
    Offset.zero,
    1,
    [_a(essence, 0.2), _a(essence, 0.07), _a(essence, 0)],
    const [0.0, 0.45, 1.0],
  );

  /// A point of light: nozzles, eyes, running lights. Unit radius.
  late final ui.Shader spark = ui.Gradient.radial(
    Offset.zero,
    1,
    [const Color(0xFFFFFFFF), hot, _a(essence, 0.75), _a(essence, 0)],
    const [0.0, 0.22, 0.5, 1.0],
  );

  /// An engine's flame, nozzle at the origin, tip at (0, 1).
  late final ui.Shader plume = ui.Gradient.linear(
    Offset.zero,
    const Offset(0, 1),
    [_a(hot, 0.8), _a(essence, 0.5), _a(essence, 0)],
    const [0.0, 0.35, 1.0],
  );

  /// A glass bead with light inside: dim through the middle, bright where
  /// the glass turns away at its rim. Unit radius.
  late final ui.Shader bead = ui.Gradient.radial(
    Offset.zero,
    1,
    [
      _a(essence, 0.42),
      _a(Color.lerp(ink, essence, 0.32)!, 0.62),
      _a(Color.lerp(ink, rim, 0.3)!, 0.7),
      _a(rim, 0.55),
      _a(rim, 0),
    ],
    const [0.0, 0.45, 0.76, 0.9, 1.0],
  );

  late final Color grainHot = Color.lerp(essence, hot, 0.55)!;
  late final Color grainDim = _a(Color.lerp(rim, essence, 0.5)!, 0.8);
}

final Map<String?, ShipLight> _lights = {
  null: ShipLight._(
    const Color(0xFF05090E),
    const Color(0xFF101B24),
    const Color(0xFF7BE3F5),
    const Color(0xFF4FD3F2),
    const Color(0xFFE2FBFF),
  ),
  'skin_phantom': ShipLight._(
    const Color(0xFF06040C),
    const Color(0xFF161029),
    const Color(0xFFA27BEA),
    const Color(0xFFB277FF),
    const Color(0xFFF0E2FF),
  ),
  'skin_solar': ShipLight._(
    const Color(0xFF0A0704),
    const Color(0xFF1E160B),
    const Color(0xFFEAC46A),
    const Color(0xFFFFC24A),
    const Color(0xFFFFF5D8),
  ),
  'skin_inferno': ShipLight._(
    const Color(0xFF0B0504),
    const Color(0xFF1F100C),
    const Color(0xFFFF8E4A),
    const Color(0xFFFF6B2C),
    const Color(0xFFFFE2B8),
  ),
  'skin_crystal': ShipLight._(
    const Color(0xFF050D16),
    const Color(0xFF13263A),
    const Color(0xFFC4F1FF),
    const Color(0xFF8DE8FF),
    const Color(0xFFF4FEFF),
  ),
};

/// The light of the hull [skin] ('skin_phantom', …; null for the standard
/// hull). Anything that flies with the ship takes its colour from here.
ShipLight shipLight(String? skin) => _lights[skin] ?? _lights[null]!;

// ── shared drawing state ────────────────────────────────────────────────────

final Paint _fill = Paint();
final Paint _flat = Paint();
final Paint _dots = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

void _shade(ui.Shader s, double alpha) {
  _fill
    ..shader = s
    ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
}

void _path(Canvas c, Path p, ui.Shader s, [double alpha = 1]) {
  if (alpha <= 0.004) return;
  _shade(s, alpha);
  c.drawPath(p, _fill);
}

/// A unit-radius shader drawn as a disc of [radius] at [at].
void _disc(
  Canvas c,
  ui.Shader s,
  Offset at,
  double radius, [
  double alpha = 1,
]) {
  if (alpha <= 0.004 || radius <= 0) return;
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(radius);
  _shade(s, alpha);
  c.drawCircle(Offset.zero, 1, _fill);
  c.restore();
}

final ui.Shader _glint = ui.Gradient.radial(
  Offset.zero,
  1,
  const [Color(0xE6FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
  const [0.0, 0.4, 1.0],
);

final ui.Shader _flash = ui.Gradient.radial(
  Offset.zero,
  1,
  const [Color(0xFFFFFFFF), Color(0xCCFFFFFF), Color(0x00FFFFFF)],
  const [0.0, 0.6, 1.0],
);

/// The engine flame's outline, nozzle at the origin, tip at (0, 1).
final Path _plumePath = Path()
  ..moveTo(-1, 0)
  ..quadraticBezierTo(-0.55, 0.45, 0, 1)
  ..quadraticBezierTo(0.55, 0.45, 1, 0)
  ..quadraticBezierTo(0, -0.3, -1, 0)
  ..close();

// ── building plates ─────────────────────────────────────────────────────────

Offset _o(List<double> xy, int i) => Offset(xy[i * 2], xy[i * 2 + 1]);

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

/// A whole shape from its left half, traced from the centre line at the
/// top down to the centre line at the bottom.
Path _symmetric(List<double> left) {
  final p = Path()..moveTo(left[0], left[1]);
  for (var i = 2; i < left.length; i += 2) {
    p.lineTo(left[i], left[i + 1]);
  }
  for (var i = left.length - 4; i >= 2; i -= 2) {
    p.lineTo(-left[i], left[i + 1]);
  }
  return p..close();
}

/// A seam of light along [spine]: widest in the middle, closing to a point
/// at both ends.
Path _seam(List<Offset> spine, double width) {
  final left = <Offset>[];
  final right = <Offset>[];
  for (var i = 0; i < spine.length; i++) {
    final prev = spine[max(0, i - 1)];
    final next = spine[min(spine.length - 1, i + 1)];
    var t = next - prev;
    t = t / max(t.distance, 1e-4);
    final n = Offset(-t.dy, t.dx);
    final h = width / 2 * sin(pi * i / (spine.length - 1));
    left.add(spine[i] + n * h);
    right.add(spine[i] - n * h);
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

/// One plate of a hull: the obsidian, lit from [lightAt] inside the ship,
/// and the edges along [litEdges] (pairs of point indices) catching it.
class _Plate {
  _Plate(
    List<double> xy,
    ShipLight l, {
    required Offset lightAt,
    required double reach,
    List<(int, int)> litEdges = const [],
    double edgeDepth = 3.2,
    double edgeAlpha = 0.9,
    double warmth = 0.16,
    bool symmetric = false,
  }) : path = symmetric ? _symmetric(xy) : _poly(xy),
       base = ui.Gradient.radial(
         lightAt,
         reach,
         [Color.lerp(l.face, l.essence, warmth)!, l.face, l.ink],
         const [0.0, 0.4, 1.0],
       ),
       edges = [
         for (final (i, j) in litEdges)
           _edgeLight(
             _o(xy, i),
             _o(xy, j),
             _centroid(xy),
             edgeDepth,
             l.rim,
             edgeAlpha,
           ),
       ];

  final Path path;
  final ui.Shader base;
  final List<ui.Shader> edges;

  void paint(Canvas c, {double alpha = 1, double edge = 1}) {
    _path(c, path, base, alpha);
    for (final e in edges) {
      _path(c, path, e, edge * alpha);
    }
  }

  static Offset _centroid(List<double> xy) {
    var x = 0.0, y = 0.0;
    final n = xy.length ~/ 2;
    for (var i = 0; i < n; i++) {
      x += xy[i * 2];
      y += xy[i * 2 + 1];
    }
    return Offset(x / n, y / n);
  }

  /// Light along the edge a→b: nothing a little way in, the rim colour at
  /// the edge itself.
  static ui.Shader _edgeLight(
    Offset a,
    Offset b,
    Offset inside,
    double depth,
    Color rim,
    double alpha,
  ) {
    final mid = (a + b) / 2;
    final d = b - a;
    var n = Offset(d.dy, -d.dx) / d.distance;
    final out = mid - inside;
    if (n.dx * out.dx + n.dy * out.dy < 0) n = -n;
    return ui.Gradient.linear(
      mid - n * depth,
      mid,
      [
        rim.withValues(alpha: 0),
        rim.withValues(alpha: 0.12 * alpha),
        rim.withValues(alpha: alpha),
      ],
      const [0.0, 0.55, 1.0],
    );
  }
}

/// A canopy of dark glass with the ship's core burning deep inside it.
ui.Shader _coreGlass(ShipLight l, Offset at, double radius) =>
    ui.Gradient.radial(
      at,
      radius,
      [
        l.hot,
        l.essence,
        Color.lerp(l.essence, l.ink, 0.62)!,
        Color.lerp(l.ink, l.face, 0.6)!,
      ],
      const [0.0, 0.16, 0.5, 1.0],
    );

// ── hulls ───────────────────────────────────────────────────────────────────

/// One hull design: how it is drawn and where its engines are.
abstract class _Hull {
  _Hull(this.light);

  final ShipLight light;

  /// Engine nozzles, hull units.
  List<Offset> get nozzles;

  /// How the wake behaves behind it.
  _WakeStyle get wake;

  /// Where embers leave the hull, if it sheds any.
  List<Offset> get emberPoints => const [];

  void paint(Canvas c, double t, bool glow, double boost);

  // Shared pieces.

  void pool(Canvas c, double radius, [Offset at = Offset.zero]) =>
      _disc(c, light.pool, at, radius);

  /// The glow round each nozzle and the flame out of it.
  void engines(
    Canvas c,
    double t,
    double boost, {
    double width = 2.3,
    double length = 8,
  }) {
    final pulse = 0.85 + 0.15 * sin(t * 9);
    for (final n in nozzles) {
      _disc(c, light.pool, n, 10 + 4 * boost, 1.6 + 0.6 * boost);
      c.save();
      c.translate(n.dx, n.dy);
      c.scale(width * (1 + 0.25 * boost), length * pulse * (1 + 1.4 * boost));
      _path(c, _plumePath, light.plume, 0.85);
      c.restore();
    }
  }

  void nozzleSparks(Canvas c, double t, double boost, [double radius = 2.8]) {
    for (var i = 0; i < nozzles.length; i++) {
      final flick = 0.88 + 0.12 * sin(t * 13 + i * 2.1);
      _disc(c, light.spark, nozzles[i], radius * flick * (1 + 0.3 * boost));
    }
  }

  /// [draw] on the left (−x) half, then again mirrored onto the right.
  static void mirrored(Canvas c, void Function() draw) {
    draw();
    c.save();
    c.scale(-1, 1);
    draw();
    c.restore();
  }
}

/// The wake's look: how many grains, how fast, how far they spread.
class _WakeStyle {
  const _WakeStyle({
    this.rate = 230,
    this.speed = 70,
    this.life = 0.5,
    this.spread = 12,
    this.drag = 1.6,
    this.size = 1.0,
    this.alpha = 1.0,
    this.twinkle = false,
  });

  /// Grains a second at cruise.
  final double rate;

  /// How fast a grain leaves the nozzle, and sideways scatter.
  final double speed, spread;

  final double life;

  /// How much of the ship's own velocity a grain keeps. Less than one, so
  /// the wake is left behind and draws the path the ship flew.
  static const double inherit = 0.5;

  final double drag;

  /// Grain size and brightness multipliers.
  final double size, alpha;

  /// Some grains glint as they go.
  final bool twinkle;
}

class _StandardHull extends _Hull {
  _StandardHull(super.light);

  @override
  final nozzles = const [Offset(-5.5, 16), Offset(5.5, 16)];

  @override
  final wake = const _WakeStyle();

  late final _wing = _Plate(
    const [0, -21, -7, -13, -14, -5, -19, 10, -9, 8, -4, 18, 0, 15],
    light,
    lightAt: const Offset(0, -4),
    reach: 22,
    litEdges: const [(1, 3)],
  );
  late final _body = _Plate(
    const [0, -24, -4.5, -11, -5.5, -1, -3.5, 13, 0, 18],
    light,
    lightAt: const Offset(0, -5),
    reach: 16,
    litEdges: const [(0, 1)],
    edgeDepth: 2.4,
    edgeAlpha: 0.7,
    warmth: 0.24,
  );
  late final _canopy = Path()
    ..moveTo(0, -14)
    ..quadraticBezierTo(5.2, -11, 4.2, -2.5)
    ..quadraticBezierTo(0, 2, -4.2, -2.5)
    ..quadraticBezierTo(-5.2, -11, 0, -14)
    ..close();
  late final _canopyGlass = _coreGlass(light, const Offset(0, -5.5), 9);
  late final _spine = _seam(const [
    Offset(0, 1),
    Offset(0, 7),
    Offset(0, 14),
  ], 1.4);
  late final _slit = _seam(const [
    Offset(-8.5, -1.5),
    Offset(-10.2, 3),
    Offset(-12, 7.5),
  ], 1.5);
  late final ui.Shader _seamLight = ui.Gradient.linear(
    const Offset(0, -2),
    const Offset(0, 14),
    [light.hot, light.essence, light.essence.withValues(alpha: 0.3)],
    const [0.0, 0.5, 1.0],
  );

  @override
  void paint(Canvas c, double t, bool glow, double boost) {
    final pulse = 0.85 + 0.15 * sin(t * 9);
    if (glow) pool(c, 32);
    engines(c, t, boost);
    _Hull.mirrored(c, () => _wing.paint(c));
    _Hull.mirrored(c, () {
      _body.paint(c);
      _path(c, _slit, _seamLight, 0.55 + 0.35 * pulse);
    });
    _path(c, _spine, _seamLight, 0.7 + 0.3 * pulse);
    _path(c, _canopy, _canopyGlass, 0.92 + 0.08 * sin(t * 3.1));
    _disc(c, _glint, const Offset(-1.7, -10), 1.6, 0.55);
    _disc(c, _glint, const Offset(-9, -6.5), 1.2, 0.35);
    nozzleSparks(c, t, boost);
    for (final x in const [-15.5, 15.5]) {
      _disc(
        c,
        light.spark,
        Offset(x, 6.5),
        1.5,
        0.75 + 0.25 * sin(t * 2.4 + x),
      );
    }
  }
}

class _PhantomHull extends _Hull {
  _PhantomHull(super.light);

  @override
  final nozzles = const [Offset(-5, 15.5), Offset(5, 15.5)];

  // Smoke: slower, wider, fainter, longer-lived.
  @override
  final wake = const _WakeStyle(
    rate: 200,
    speed: 46,
    life: 0.75,
    spread: 26,
    drag: 2.2,
    size: 1.15,
    alpha: 0.7,
  );

  late final _wing = _Plate(
    const [0, -26, -7, -18, -13, -7, -20, 6, -11, 5, -6, 15, 0, 11],
    light,
    lightAt: const Offset(0, -10),
    reach: 24,
    litEdges: const [(1, 3)],
    edgeDepth: 4.2,
    edgeAlpha: 1,
    warmth: 0.14,
  );
  late final _body = _Plate(
    const [0, -29, -3.5, -18, -5, -2, -2.8, 12, 0, 17],
    light,
    lightAt: const Offset(0, -10),
    reach: 18,
    litEdges: const [(0, 1)],
    edgeDepth: 2,
    edgeAlpha: 0.6,
    warmth: 0.2,
  );
  late final _canopy = Path()
    ..moveTo(0, -18)
    ..quadraticBezierTo(4, -15.5, 3.6, -7)
    ..quadraticBezierTo(0, -3, -3.6, -7)
    ..quadraticBezierTo(-4, -15.5, 0, -18)
    ..close();
  late final _canopyGlass = _coreGlass(light, const Offset(0, -10), 9);
  late final _veil = _seam(const [
    Offset(0, -24),
    Offset(0, -12),
    Offset(0, -1),
    Offset(0, 10),
  ], 3.2);
  late final _spine = _seam(const [
    Offset(0, -22),
    Offset(0, -8),
    Offset(0, 9),
  ], 1.1);
  late final _blade = _seam(const [
    Offset(-12, -4),
    Offset(-14, 1.5),
    Offset(-16, 7),
  ], 1.3);
  late final ui.Shader _veilLight = ui.Gradient.linear(
    const Offset(0, -24),
    const Offset(0, 10),
    [
      light.essence.withValues(alpha: 0),
      light.essence.withValues(alpha: 0.7),
      light.essence.withValues(alpha: 0),
    ],
    const [0.0, 0.5, 1.0],
  );
  late final ui.Shader _seamLight = ui.Gradient.linear(
    const Offset(0, -22),
    const Offset(0, 9),
    [light.essence.withValues(alpha: 0.4), light.hot, light.essence],
    const [0.0, 0.5, 1.0],
  );

  @override
  void paint(Canvas c, double t, bool glow, double boost) {
    // The light inside comes and goes, slowly, as if the hull were half in
    // another place.
    final phase = 0.5 + 0.5 * sin(t * 1.4);
    if (glow) pool(c, 30, const Offset(0, -2));
    engines(c, t, boost, width: 2.0, length: 9);
    _Hull.mirrored(c, () {
      _wing.paint(c, alpha: 0.94, edge: 0.65 + 0.35 * phase);
      _path(c, _blade, _seamLight, 0.5 + 0.45 * phase);
    });
    _Hull.mirrored(c, () => _body.paint(c, alpha: 0.96));
    _path(c, _veil, _veilLight, 0.35 + 0.45 * phase);
    _path(c, _spine, _seamLight, 0.6 + 0.3 * phase);
    _path(c, _canopy, _canopyGlass, 0.75 + 0.2 * phase);
    _disc(c, _glint, const Offset(-1.3, -14), 1.3, 0.45);
    final eye = 0.7 + 0.3 * sin(t * 4);
    for (final x in const [-3.0, 3.0]) {
      _disc(c, light.spark, Offset(x, -10.5), 2.1, eye);
    }
    nozzleSparks(c, t, boost, 2.5);
    for (final x in const [-15.0, 15.0]) {
      _disc(c, light.spark, Offset(x, 6), 1.3, 0.5 + 0.4 * phase);
    }
  }
}

class _SolarHull extends _Hull {
  _SolarHull(super.light);

  @override
  final nozzles = const [Offset(-8, 16.5), Offset(0, 22), Offset(8, 16.5)];

  @override
  final wake = const _WakeStyle(rate: 290, speed: 80, spread: 16, size: 1.1);

  late final _pod = _Plate(
    const [
      -6,
      -15,
      -12,
      -13,
      -17,
      -6,
      -21,
      8,
      -16,
      12,
      -11,
      10,
      -8,
      17,
      -4,
      14,
      -5,
      -2,
    ],
    light,
    lightAt: const Offset(-4, -6),
    reach: 20,
    litEdges: const [(1, 2), (2, 3)],
    edgeDepth: 3.6,
    edgeAlpha: 1,
    warmth: 0.18,
  );
  late final _core = _Plate(
    const [0, -30, -4.5, -19, -8, -9, -7.2, 9, -4.2, 20, 0, 24],
    light,
    lightAt: const Offset(0, -8),
    reach: 22,
    litEdges: const [(1, 2), (2, 3)],
    edgeDepth: 2.8,
    edgeAlpha: 0.95,
    warmth: 0.28,
  );

  /// The nose crest is the one piece of solid gold on the hull.
  late final _crest = Path()
    ..moveTo(0, -34)
    ..lineTo(-3.5, -25)
    ..lineTo(0, -20)
    ..lineTo(3.5, -25)
    ..close();
  late final ui.Shader _gold = ui.Gradient.linear(
    const Offset(-3.5, -34),
    const Offset(3.5, -20),
    [light.hot, light.rim, Color.lerp(light.rim, light.ink, 0.55)!],
    const [0.0, 0.45, 1.0],
  );
  late final _canopy = Path()
    ..moveTo(0, -18)
    ..quadraticBezierTo(5, -15, 4.4, -4.5)
    ..quadraticBezierTo(0, 0.5, -4.4, -4.5)
    ..quadraticBezierTo(-5, -15, 0, -18)
    ..close();
  late final _canopyGlass = _coreGlass(light, const Offset(0, -8), 8.5);
  late final _keel = _seam(const [
    Offset(0, 0),
    Offset(0, 9),
    Offset(0, 18),
  ], 1.6);
  late final ui.Shader _seamLight = ui.Gradient.linear(
    const Offset(0, 0),
    const Offset(0, 18),
    [light.hot, light.essence],
  );

  /// The sun's ring: grains on real orbits round the hull, in a tilted
  /// plane — the Dust planet's ring, small. (radius, start, phase, rate)
  static final List<(double, double, double, double)> _ring = () {
    final r = Random(17);
    return [
      for (var i = 0; i < 56; i++)
        () {
          final rad = 29 + r.nextDouble() * 7;
          return (
            rad,
            r.nextDouble() * 2 * pi,
            r.nextDouble() * 2 * pi,
            0.6 * pow(29 / rad, 1.5).toDouble(),
          );
        }(),
    ];
  }();
  static const double _ringFlat = 0.62;
  final Float32List _far = Float32List(_ring.length * 2);
  final Float32List _near = Float32List(_ring.length * 2);
  final Float32List _lit = Float32List(_ring.length * 2);
  int _nFar = 0, _nNear = 0, _nLit = 0;

  void _gatherRing(double t) {
    _nFar = _nNear = _nLit = 0;
    for (final (rad, a0, ph, rate) in _ring) {
      final a = a0 + t * rate;
      final x = cos(a) * rad;
      final y = sin(a) * rad * _ringFlat - 3;
      if (sin(t * 3 + ph) > 0.82) {
        _lit[_nLit++ * 2] = x;
        _lit[_nLit * 2 - 1] = y;
      } else if (sin(a) < 0) {
        _far[_nFar++ * 2] = x;
        _far[_nFar * 2 - 1] = y;
      } else {
        _near[_nNear++ * 2] = x;
        _near[_nNear * 2 - 1] = y;
      }
    }
  }

  void _grains(Canvas c, Float32List buf, int n, double d, Color col) {
    if (n == 0) return;
    _dots
      ..strokeWidth = d
      ..color = col;
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(buf, 0, n * 2),
      _dots,
    );
  }

  @override
  void paint(Canvas c, double t, bool glow, double boost) {
    final breathe = 0.85 + 0.15 * sin(t * 3.2);
    _gatherRing(t);
    if (glow) pool(c, 36, const Offset(0, -2));
    _grains(c, _far, _nFar, 1.1, light.grainDim.withValues(alpha: 0.5));
    engines(c, t, boost, width: 2.6, length: 9);
    _Hull.mirrored(c, () => _pod.paint(c));
    _Hull.mirrored(c, () => _core.paint(c));
    _path(c, _keel, _seamLight, 0.7 * breathe);
    _path(c, _crest, _gold);
    _path(c, _canopy, _canopyGlass);
    // The sun in the canopy.
    _disc(c, light.spark, const Offset(0, -8), 4.6 * breathe);
    _disc(c, _glint, const Offset(-2.2, -32), 1.3, 0.8);
    _disc(c, _glint, const Offset(-13, -11), 1.3, 0.45);
    nozzleSparks(c, t, boost, 3);
    _grains(c, _near, _nNear, 1.3, light.grainDim.withValues(alpha: 0.7));
    _grains(c, _lit, _nLit, 1.8, light.grainHot);
  }
}

class _InfernoHull extends _Hull {
  _InfernoHull(super.light);

  @override
  final nozzles = const [Offset(-6.5, 15.5), Offset(6.5, 15.5)];

  @override
  final wake = const _WakeStyle(rate: 240, speed: 82, life: 0.45, size: 1.05);

  @override
  final emberPoints = const [Offset(-19, 3.5), Offset(19, 3.5)];

  late final _wing = _Plate(
    const [0, -28, -5, -18, -13, -10, -21, 3, -12, 5, -8, 18, 0, 11],
    light,
    lightAt: const Offset(-6, -2),
    reach: 22,
    litEdges: const [(1, 2), (2, 3)],
    edgeAlpha: 0.85,
  );
  late final _body = _Plate(
    const [0, -31, -3.2, -20, -4.8, -2, -2.8, 12, 0, 21],
    light,
    lightAt: const Offset(0, -6),
    reach: 18,
    litEdges: const [(0, 1)],
    edgeDepth: 2,
    edgeAlpha: 0.7,
    warmth: 0.24,
  );

  /// Where the heat has split the wing open.
  late final _cracks = [
    _seam(const [
      Offset(-5.5, -9),
      Offset(-8.5, -6.5),
      Offset(-11, -4.5),
      Offset(-14.5, -1.5),
      Offset(-18, 1.5),
    ], 2.3),
    _seam(const [
      Offset(-6, 0),
      Offset(-7.4, 3.5),
      Offset(-8.8, 7),
      Offset(-9.6, 10.5),
    ], 1.9),
  ];
  late final _blade = Path()
    ..moveTo(0, 23)
    ..lineTo(-3.5, 13)
    ..lineTo(0, 16)
    ..lineTo(3.5, 13)
    ..close();
  late final _canopy = Path()
    ..moveTo(0, -19)
    ..quadraticBezierTo(4, -16, 3.5, -5)
    ..quadraticBezierTo(0, -0.5, -3.5, -5)
    ..quadraticBezierTo(-4, -16, 0, -19)
    ..close();
  late final _canopyGlass = _coreGlass(light, const Offset(0, -8), 9);
  late final ui.Shader _heat = ui.Gradient.radial(
    const Offset(-6, -2),
    14,
    [light.hot, light.essence, Color.lerp(light.essence, light.ink, 0.35)!],
    const [0.0, 0.45, 1.0],
  );
  late final ui.Shader _bladeLight = ui.Gradient.linear(
    const Offset(0, 13),
    const Offset(0, 23),
    [light.hot, light.essence, Color.lerp(light.essence, light.ink, 0.5)!],
    const [0.0, 0.5, 1.0],
  );

  @override
  void paint(Canvas c, double t, bool glow, double boost) {
    // The heat breathes unevenly, as a fire does.
    final heat = 0.72 + 0.18 * sin(t * 5.8) + 0.1 * sin(t * 13.1 + 1.3);
    if (glow) pool(c, 32);
    engines(c, t, boost, width: 2.4, length: 9);
    _Hull.mirrored(c, () {
      _wing.paint(c);
      for (final crack in _cracks) {
        _path(c, crack, _heat, heat);
      }
    });
    _Hull.mirrored(c, () => _body.paint(c));
    _path(c, _blade, _bladeLight, 0.75 + 0.25 * heat);
    _path(c, _canopy, _canopyGlass, 0.9 + 0.1 * heat);
    _disc(c, _glint, const Offset(-1.4, -15), 1.3, 0.5);
    nozzleSparks(c, t, boost);
    for (final x in const [-19.0, 19.0]) {
      _disc(c, light.spark, Offset(x, 3.2), 1.4, 0.6 + 0.4 * heat);
    }
  }
}

class _CrystalHull extends _Hull {
  _CrystalHull(super.light);

  @override
  final nozzles = const [Offset(-5, 16), Offset(5, 16)];

  @override
  final wake = const _WakeStyle(rate: 210, speed: 64, twinkle: true);

  // Three facets to a side, each turned a different way to the light, so
  // the hull reads as cut glass rather than one flat plate.
  late final _fore = _Plate(
    const [0, -27, -8, -18, -16, -8, -9, -4, 0, -10],
    light,
    lightAt: const Offset(-6, -16),
    reach: 16,
    litEdges: const [(1, 2)],
    edgeAlpha: 0.95,
    warmth: 0.32,
  );
  late final _mid = _Plate(
    const [0, -10, -9, -4, -16, -8, -19, 5, -10, 9, 0, 4],
    light,
    lightAt: const Offset(-2, -4),
    reach: 20,
    litEdges: const [(2, 3)],
    edgeAlpha: 0.75,
    warmth: 0.12,
  );
  late final _aft = _Plate(
    const [0, 4, -10, 9, -6, 20, 0, 15],
    light,
    lightAt: const Offset(-2, 8),
    reach: 14,
    litEdges: const [(1, 2)],
    edgeAlpha: 0.55,
    warmth: 0.22,
  );
  late final _coreShard = _symmetric(const [
    0, -31, -4.5, -18, -6.5, -2, -3, 14, 0, 22, //
  ]);
  late final ui.Shader _coreLight = ui.Gradient.radial(
    const Offset(0, -8),
    18,
    [
      light.hot,
      light.essence,
      Color.lerp(light.essence, light.ink, 0.55)!,
      Color.lerp(light.ink, light.face, 0.5)!,
    ],
    const [0.0, 0.14, 0.45, 1.0],
  );
  late final ui.Shader _noseLit = ui.Gradient.linear(
    const Offset(0, -35),
    const Offset(0, -22),
    [light.hot, light.rim],
  );
  late final ui.Shader _noseDark = ui.Gradient.linear(
    const Offset(0, -35),
    const Offset(0, -22),
    [light.rim, Color.lerp(light.face, light.essence, 0.3)!],
  );


  /// Shards of the hull's glass held in orbit round it: a dark face and a
  /// lit one each, all the shards on one side of the hull in two paths.
  void _shards(Canvas c, double t, bool front) {
    final dark = Path();
    final lit = Path();
    var any = false;
    for (var i = 0; i < 5; i++) {
      final a = t * 0.9 + i * 2 * pi / 5;
      if ((sin(a) > 0) != front) continue;
      any = true;
      final at = Offset(cos(a) * 24, sin(a) * 24 * 0.48 - 2);
      final r = 0.35 * sin(a + i);
      final up = Offset(sin(r), -cos(r)) * 2.9;
      final across = Offset(cos(r), sin(r)) * 1.9;
      final top = at + up, bottom = at - up;
      dark
        ..moveTo(top.dx, top.dy)
        ..lineTo(at.dx + across.dx, at.dy + across.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..close();
      lit
        ..moveTo(top.dx, top.dy)
        ..lineTo(at.dx - across.dx, at.dy - across.dy)
        ..lineTo(bottom.dx, bottom.dy)
        ..close();
    }
    if (!any) return;
    c.drawPath(dark, _flat..color = _shardDark);
    c.drawPath(lit, _flat..color = _shardLit);
  }

  late final Color _shardDark = Color.lerp(
    light.face,
    light.essence,
    0.4,
  )!.withValues(alpha: 0.9);
  late final Color _shardLit = light.rim.withValues(alpha: 0.9);

  @override
  void paint(Canvas c, double t, bool glow, double boost) {
    final pulse = 0.82 + 0.18 * sin(t * 3.2);
    if (glow) pool(c, 30);
    _shards(c, t, false);
    engines(c, t, boost, width: 2.0, length: 8);
    _Hull.mirrored(c, () {
      _mid.paint(c);
      _aft.paint(c);
      _fore.paint(c);
    });
    _path(c, _coreShard, _coreLight, 0.88 + 0.12 * pulse);
    _path(c, _nose, _noseDark);
    _path(c, _noseLeft, _noseLit);
    _disc(c, light.spark, const Offset(0, -8), 3.6 * pulse);
    _disc(c, _glint, const Offset(-7, -17), 1.5, 0.7);
    _disc(c, _glint, const Offset(-1.2, -29), 1.1, 0.8);
    nozzleSparks(c, t, boost, 2.5);
    _shards(c, t, true);
  }

  late final _nose = _poly(const [0, -35, -3, -27, 0, -22, 3, -27]);
  late final _noseLeft = _poly(const [0, -35, -3, -27, 0, -22]);
}

final Map<String?, _Hull> _hulls = {};

_Hull _hull(String? skin) => _hulls[skin] ??= switch (skin) {
  'skin_phantom' => _PhantomHull(shipLight(skin)),
  'skin_solar' => _SolarHull(shipLight(skin)),
  'skin_inferno' => _InfernoHull(shipLight(skin)),
  'skin_crystal' => _CrystalHull(shipLight(skin)),
  _ => _StandardHull(shipLight(null)),
};

/// Draws the hull [skin] (null for the standard hull) at the origin, nose
/// up, in hull units. [glow] adds the light pooled round it — survival
/// leaves it off. [boost] (0..1) opens the engines up; [flash] (0..1)
/// blanches the hull from the inside out, the way an enemy shows a hit.
void paintShipHull(
  Canvas c,
  String? skin,
  double time, {
  bool glow = true,
  double boost = 0,
  double flash = 0,
}) {
  _hull(skin).paint(c, time, glow, boost.clamp(0.0, 1.0));
  if (flash > 0.02) {
    _disc(c, _flash, const Offset(0, -2), 24, 0.75 * flash.clamp(0.0, 1.0));
  }
}

// ── wake ────────────────────────────────────────────────────────────────────

/// The grains a ship leaves behind it, in world space. Each ship keeps its
/// own; [update] once a frame (repeat calls at the same time are free),
/// then [paint] before the hull.
class ShipWake {
  static const int _cap = 640;

  final Float32List _x = Float32List(_cap);
  final Float32List _y = Float32List(_cap);
  final Float32List _vx = Float32List(_cap);
  final Float32List _vy = Float32List(_cap);
  final Float32List _age = Float32List(_cap);
  final Float32List _life = Float32List(_cap);
  final Uint8List _ember = Uint8List(_cap);
  int _n = 0;

  double? _t;
  Offset _lastPos = Offset.zero;
  double _carry = 0, _emberCarry = 0;
  String? _skin;
  double _boost = 0;
  int _seed = 0x2545F491;

  double _rand() {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed / 0x7FFFFFFF;
  }

  /// The box the wake's grains lie in (world space), or null with none —
  /// so a layer round the ship can be bounded to it.
  Rect? get bounds {
    if (_n == 0) return null;
    var l = _x[0], r = l, t = _y[0], b = t;
    for (var i = 1; i < _n; i++) {
      final x = _x[i], y = _y[i];
      if (x < l) l = x;
      if (x > r) r = x;
      if (y < t) t = y;
      if (y > b) b = y;
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  /// Forget the wake, as after a teleport.
  void clear() {
    _n = 0;
    _t = null;
  }

  /// Advances the wake to [time] behind a ship at [pos] heading [angle]
  /// (radians, 0 = +x). The first call lays down the wake a ship cruising
  /// in a straight line would have, so a still picture of the hull shows
  /// one too.
  void update(
    double time,
    Offset pos,
    double angle,
    String? skin, {
    double boost = 0,
  }) {
    _skin = skin;
    _boost = boost.clamp(0.0, 1.0);
    final hull = _hull(skin);
    final last = _t;
    if (last == null || time < last || time - last > 1.0) {
      _n = 0;
      _t = time;
      const cruise = 220.0;
      final fwd = Offset(cos(angle), sin(angle));
      const step = 1 / 30;
      for (var k = 24; k > 0; k--) {
        _step(hull, step, pos - fwd * (cruise * step * k), angle, fwd * cruise);
      }
      _lastPos = pos;
      return;
    }
    final dt = time - last;
    if (dt <= 0) return;
    _t = time;
    final vel = (pos - _lastPos) / dt;
    _lastPos = pos;
    if (vel.distance > 5000) {
      _n = 0;
      return;
    }
    _step(hull, min(dt, 0.05), pos, angle, vel);
  }

  void _step(_Hull hull, double dt, Offset pos, double angle, Offset vel) {
    final w = hull.wake;
    final drag = max(0.0, 1 - dt * w.drag);
    var i = 0;
    while (i < _n) {
      _age[i] += dt;
      if (_age[i] >= _life[i]) {
        _n--;
        _x[i] = _x[_n];
        _y[i] = _y[_n];
        _vx[i] = _vx[_n];
        _vy[i] = _vy[_n];
        _age[i] = _age[_n];
        _life[i] = _life[_n];
        _ember[i] = _ember[_n];
        continue;
      }
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      _vx[i] *= drag;
      _vy[i] *= drag;
      i++;
    }

    // Hull units to world: the hull is drawn rotated by angle + π/2.
    final th = angle + pi / 2;
    final ct = cos(th), st = sin(th);
    Offset toWorld(Offset l) =>
        pos + Offset(l.dx * ct - l.dy * st, l.dx * st + l.dy * ct);
    final back = Offset(-cos(angle), -sin(angle));
    final side = Offset(-back.dy, back.dx);
    final boost = _boost;

    _carry += dt * w.rate * (1 + 1.6 * boost);
    while (_carry >= 1) {
      _carry -= 1;
      if (_n >= _cap) continue;
      final nz =
          hull.nozzles[(_rand() * hull.nozzles.length).floor() %
              hull.nozzles.length];
      final at = toWorld(nz + Offset((_rand() - 0.5) * 1.6, 2.5));
      final v =
          back * (w.speed * (0.75 + 0.5 * _rand()) * (1 + 0.9 * boost)) +
          side * ((_rand() - 0.5) * w.spread) +
          vel * _WakeStyle.inherit;
      _spawn(
        at,
        v,
        w.life * (0.7 + 0.6 * _rand()) * (1 + 0.35 * boost),
        dt,
        false,
      );
    }

    final embers = hull.emberPoints;
    if (embers.isNotEmpty) {
      _emberCarry += dt * 16 * (1 + boost);
      while (_emberCarry >= 1) {
        _emberCarry -= 1;
        if (_n >= _cap) continue;
        final p = embers[(_rand() * embers.length).floor() % embers.length];
        final v =
            back * (26 + 30 * _rand()) +
            side * ((_rand() - 0.5) * 50) +
            vel * 0.62;
        _spawn(toWorld(p), v, 0.45 + 0.4 * _rand(), dt, true);
      }
    }
  }

  void _spawn(Offset at, Offset v, double life, double dt, bool ember) {
    // Spread across the frame, so a long frame lays a line, not a clump.
    final f = _rand() * dt;
    final i = _n++;
    _x[i] = at.dx + v.dx * f;
    _y[i] = at.dy + v.dy * f;
    _vx[i] = v.dx;
    _vy[i] = v.dy;
    _age[i] = f;
    _life[i] = life;
    _ember[i] = ember ? 1 : 0;
  }

  // Grains go out in five passes: three by age, the glints, the embers.
  static final List<Float32List> _buckets = List.generate(
    5,
    (_) => Float32List(_cap * 2),
  );
  static final List<int> _bucketN = List.filled(5, 0);

  /// Draws the wake. World space: call before the canvas moves to the hull.
  void paint(Canvas c, {double opacity = 1}) {
    if (_n == 0 || opacity <= 0.01) return;
    final hull = _hull(_skin);
    final w = hull.wake;
    final l = hull.light;
    final t = _t ?? 0;
    _bucketN.fillRange(0, 5, 0);
    for (var i = 0; i < _n; i++) {
      final f = _age[i] / _life[i];
      final int b;
      if (_ember[i] == 1) {
        b = 4;
      } else if (w.twinkle && sin(t * 11 + i * 2.7) > 0.86) {
        b = 3;
      } else {
        b = f < 0.28 ? 0 : (f < 0.62 ? 1 : 2);
      }
      final k = _bucketN[b]++ * 2;
      _buckets[b][k] = _x[i];
      _buckets[b][k + 1] = _y[i];
    }
    final s = w.size * (1 + 0.3 * _boost);
    final a = w.alpha * opacity;
    void pass(int b, double d, Color col, double alpha) {
      final n = _bucketN[b];
      if (n == 0) return;
      _dots
        ..strokeWidth = d * s
        ..color = col.withValues(alpha: (col.a * alpha).clamp(0.0, 1.0));
      c.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_buckets[b], 0, n * 2),
        _dots,
      );
    }

    pass(2, 0.8, l.grainDim, 0.5 * a);
    pass(1, 1.15, l.essence, 0.75 * a);
    pass(0, 1.55, l.grainHot, 0.95 * a);
    pass(3, 1.9, l.hot, a);
    pass(4, 1.5, l.grainHot, 0.9 * a);
  }
}

// ── orbital sentinels ───────────────────────────────────────────────────────

/// One orbital sentinel at [at]: a bead of the ship's light held in glass,
/// grains of it turning inside. [radius] is the bead's; its light pools a
/// little past that. [opacity] fades it in as it forms.
void paintOrbitalSentinel(
  Canvas c,
  Offset at,
  ShipLight l, {
  required double time,
  required double seed,
  double radius = 9,
  double opacity = 1,
}) {
  if (opacity <= 0.01) return;
  _disc(c, l.pool, at, radius * 2.4, opacity);
  _disc(c, l.bead, at, radius, opacity);

  // The grains inside, on small tilted orbits, the near ones brighter.
  final buf = _beadGrains;
  var nNear = 0, nFar = 0;
  for (var i = 0; i < 7; i++) {
    final a = time * (1.6 + 0.35 * i) + seed * 3 + i * 0.9;
    final r = radius * (0.22 + 0.07 * i);
    final x = at.dx + cos(a) * r;
    final y = at.dy + sin(a) * r * 0.55 + cos(seed + i) * radius * 0.12;
    if (sin(a) > 0) {
      buf[14 + nNear * 2] = x;
      buf[15 + nNear * 2] = y;
      nNear++;
    } else {
      buf[nFar * 2] = x;
      buf[nFar * 2 + 1] = y;
      nFar++;
    }
  }
  _dots
    ..strokeWidth = radius * 0.2
    ..color = l.grainDim.withValues(alpha: 0.6 * opacity);
  if (nFar > 0) {
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(buf, 0, nFar * 2),
      _dots,
    );
  }
  _disc(c, l.spark, at, radius * 0.34, opacity);
  if (nNear > 0) {
    _dots
      ..strokeWidth = radius * 0.24
      ..color = l.grainHot.withValues(alpha: opacity);
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(buf, 14, 14 + nNear * 2),
      _dots,
    );
  }
  // Where the glass catches the light.
  _disc(
    c,
    _glint,
    at + Offset(-radius * 0.38, -radius * 0.42),
    radius * 0.3,
    0.75 * opacity,
  );
}

final Float32List _beadGrains = Float32List(28);
