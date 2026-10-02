// lib/widgets/wilderness/wild_map.dart
//
// THE WILD AS GRAINS. The wilderness map: each realm one simple shape made
// of grains on a faint circle of sand — snow-capped mountains for the
// Valley, a cloud for the Sky, a volcano for the Volcano, a swamp tree on
// brown ground for the Swamp — and a purple circle in the middle for
// Arcane. A finger drawn through them stirs them like sand in water, and
// they settle back. A realm with something waiting in it has its circle
// pulse green.
//
// Weather is shown, not announced: lightning out of the Sky's cloud, rain
// or snow on the Valley's mountains, the Swamp's tree gone dry.
//
// Cheap at rest: grains that hold still are drawn once into a picture and
// that picture drawn again each frame; the cloud's bob, the tree's sway and
// Arcane's turn are one move of their picture rather than a move of every
// grain. A finger through the field turns it back into live grains until
// they settle. No blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:flutter/painting.dart';

const double _tau = math.pi * 2;

/// The four realms, where their circles sit on the map (as shares of its
/// width and height) and the scene each one opens.
enum WildRealm {
  valley('valley', 0.25, 0.25),
  sky('sky', 0.75, 0.25),
  volcano('volcano', 0.25, 0.75),
  swamp('swamp', 0.75, 0.75);

  const WildRealm(this.sceneId, this.x, this.y);

  final String sceneId;
  final double x, y;
}

// The parts the map is made of. A grain remembers its part: it decides its
// colour, how it moves and what the weather does to it.
const int _rock = 0, _snowcap = 1, _meadow = 2; // Valley
const int _cloud = 3; // Sky
const int _cone = 4, _lava = 5, _crater = 6; // Volcano
const int _ground = 7, _pool = 8, _trunk = 9, _canopy = 10, _moss = 11;
const int _sand = 12, _rim = 13; // each realm's circle
const int _arcRing = 14, _arcFill = 15, _arcHaze = 16; // Arcane

// Groups, in the order they draw. Each is one picture at rest, and only
// the ones a finger reaches go back to live grains.
const int _gStill = 0; // 0..3: each realm's grains that never move
const int _gRim = 4; // 4..7: each realm's rim, live while it pulses
const int _gCloud = 8, _gTree = 9, _gLive = 10, _gArcane = 11;
const int _groups = 12;

int _groupOf(int part, int realm) => switch (part) {
  _rim => _gRim + realm,
  _cloud => _gCloud,
  _canopy || _moss => _gTree,
  _meadow || _lava || _crater => _gLive,
  _arcRing || _arcFill || _arcHaze => _gArcane,
  _ => _gStill + realm,
};

/// A circle in a shape's unit square: centre and radius.
typedef _Lobe = (double, double, double);

// The Valley's two peaks, as the top edge of the range (unit square).
const _ridge = <(double, double)>[
  (0.02, 0.88),
  (0.2, 0.6),
  (0.28, 0.5),
  (0.36, 0.36),
  (0.44, 0.2),
  (0.5, 0.11),
  (0.56, 0.21),
  (0.62, 0.32),
  (0.66, 0.38),
  (0.74, 0.3),
  (0.8, 0.25),
  (0.86, 0.35),
  (0.92, 0.52),
  (0.98, 0.88),
];

const _cloudLobes = <_Lobe>[
  (0.15, 0.62, 0.11),
  (0.29, 0.53, 0.17),
  (0.47, 0.42, 0.22),
  (0.67, 0.49, 0.19),
  (0.83, 0.6, 0.12),
];

const _canopyLobes = <_Lobe>[
  (0.22, 0.42, 0.09),
  (0.34, 0.32, 0.14),
  (0.5, 0.25, 0.17),
  (0.66, 0.32, 0.14),
  (0.78, 0.42, 0.09),
  (0.42, 0.4, 0.12),
  (0.58, 0.4, 0.12),
];

/// A grain as it is built.
class _Seed {
  _Seed(
    this.x,
    this.y,
    this.size,
    this.col,
    this.alt,
    this.part,
    this.realm,
    this.v,
  );
  final double x, y, size, v;
  final int col, alt, part, realm;
}

/// The field: its grains, the flow a finger leaves in them, and what the
/// weather is doing. Plain Dart — [layout] sizes it, [step] advances it,
/// [paint] draws it.
class WildMapField {
  WildMapField({int seed = 7}) : _seed = seed;

  final int _seed;
  Size _size = Size.zero;
  double time = 0;

  /// The weather over each realm, by scene id.
  Map<String, WeatherKind> weather = const {};

  /// The realms with something waiting in them, by scene id.
  Set<String> ready = const {};

  /// Whether Arcane has opened: its purple circle shows in the middle.
  bool arcane = false;

  /// Drawn in ink on a light page instead of light on the dark: light
  /// adding up shows nothing on parchment.
  bool ink = false;

  // ── Layout ────────────────────────────────────────────────────────────

  /// Each realm's circle (centre, and [_ringR] its radius) and the square
  /// its shape is drawn in.
  final List<Offset> _centre = List.filled(4, Offset.zero);
  final List<Rect> _box = List.filled(4, Rect.zero);
  double _ringR = 1, _side = 1, _circleR = 1;

  Offset get _mid => Offset(_size.width / 2, _size.height / 2);

  /// Where a realm's circle sits.
  Rect circleOf(WildRealm r) =>
      Rect.fromCircle(center: _centre[r.index], radius: _ringR);

  /// Under a realm's circle.
  Offset labelAnchor(WildRealm r) => _centre[r.index] + Offset(0, _ringR + 2);

  /// Where Arcane's circle sits.
  Rect get riftRect => Rect.fromCircle(center: _mid, radius: _circleR);

  /// A point in realm [i]'s square from unit coordinates.
  Offset _at(int i, double u, double v) {
    final b = _box[i];
    return Offset(b.left + u * _side, b.top + v * _side);
  }

  /// Lays the field out for [size]. Grains are rebuilt only when it changes.
  void layout(Size size) {
    if (size == _size || size.isEmpty) return;
    _size = size;
    _ringR = math.min(size.width * 0.24, size.height * 0.215);
    _side = _ringR * 1.42;
    for (final r in WildRealm.values) {
      final c = Offset(size.width * r.x, size.height * r.y);
      _centre[r.index] = c;
      _box[r.index] = Rect.fromCenter(
        center: c - Offset(0, _side * 0.02),
        width: _side,
        height: _side,
      );
    }
    // Arcane: a little bigger than a realm's gap would need, and never so
    // big it crowds them.
    final reach =
        (_centre[0] - Offset(size.width / 2, size.height / 2)).distance;
    _circleR = math.min(
      size.width * 0.135,
      math.max(size.width * 0.06, (reach - _ringR) * 0.88),
    );
    final rng = math.Random(_seed);
    _buildShapes();
    _buildCloudMask();
    _buildGrains(rng);
    _buildMovers(rng);
    _buildWashes(rng);
    _fieldW = (size.width / _cell).ceil() + 1;
    _fieldH = (size.height / _cell).ceil() + 1;
    _fu = Float32List(_fieldW * _fieldH);
    _fv = Float32List(_fieldW * _fieldH);
    _ft = Float32List(_fieldW * _fieldH);
    _fieldOn = false;
    _dropPictures();
  }

  /// How far inside realm [i]'s circle (x, y) is: 1 at its middle, 0 out.
  double _zone(int i, double x, double y) {
    final c = _centre[i];
    final dx = (x - c.dx) / _ringR, dy = (y - c.dy) / _ringR;
    final d = dx * dx + dy * dy;
    return d >= 1 ? 0 : _smooth(1 - d);
  }

  /// The realm under [p], or 'arcane' for its circle: by scene id.
  String? sceneAt(Offset p) {
    for (var i = 0; i < 4; i++) {
      if ((p - _centre[i]).distance < _ringR * 1.04) {
        return WildRealm.values[i].sceneId;
      }
    }
    if (arcane && (p - _mid).distance < _circleR * 1.08) return 'arcane';
    return null;
  }

  // ── Shapes ────────────────────────────────────────────────────────────

  // Each realm's parts, front-most last, as paths in its square.
  final List<List<(Path, int)>> _parts = List.generate(4, (_) => []);

  void _buildShapes() {
    Path poly(int i, List<(double, double)> pts) {
      final p = Path();
      for (var k = 0; k < pts.length; k++) {
        final o = _at(i, pts[k].$1, pts[k].$2);
        k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }
      return p..close();
    }

    Path lobes(int i, List<_Lobe> ls) {
      final p = Path();
      for (final (u, v, r) in ls) {
        p.addOval(Rect.fromCircle(center: _at(i, u, v), radius: r * _side));
      }
      return p;
    }

    Path oval(int i, double u, double v, double ru, double rv) => Path()
      ..addOval(
        Rect.fromCenter(
          center: _at(i, u, v),
          width: ru * 2 * _side,
          height: rv * 2 * _side,
        ),
      );

    // The Valley: a range of two peaks over a meadow.
    final v = WildRealm.valley.index;
    final meadow = Path()..moveTo(_at(v, 0, 0.94).dx, _at(v, 0, 0.94).dy);
    for (var k = 0; k <= 20; k++) {
      final u = k / 20;
      final o = _at(v, u, 0.84 + 0.035 * math.sin(u * 7 + 0.6));
      meadow.lineTo(o.dx, o.dy);
    }
    meadow
      ..lineTo(_at(v, 1, 0.98).dx, _at(v, 1, 0.98).dy)
      ..lineTo(_at(v, 0, 0.98).dx, _at(v, 0, 0.98).dy)
      ..close();
    _parts[v]
      ..clear()
      ..add((poly(v, _ridge), _rock))
      ..add((meadow, _meadow));

    // The Sky: one cloud, puffed on top, flat underneath.
    final s = WildRealm.sky.index;
    final cloud = lobes(s, _cloudLobes)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            _at(s, 0.1, 0.55).dx,
            _at(s, 0.1, 0.55).dy,
            _at(s, 0.9, 0.74).dx,
            _at(s, 0.9, 0.74).dy,
          ),
          Radius.circular(_side * 0.09),
        ),
      );
    _parts[s]
      ..clear()
      ..add((cloud, _cloud));

    // The Volcano: a cone with a notched crater and a run of lava.
    final o = WildRealm.volcano.index;
    _parts[o]
      ..clear()
      ..add((
        poly(o, const [
          (0.03, 0.94),
          (0.2, 0.68),
          (0.32, 0.44),
          (0.4, 0.27),
          (0.44, 0.22),
          (0.48, 0.26),
          (0.52, 0.27),
          (0.56, 0.22),
          (0.6, 0.27),
          (0.68, 0.44),
          (0.8, 0.68),
          (0.97, 0.94),
        ]),
        _cone,
      ))
      ..add((oval(o, 0.5, 0.245, 0.075, 0.035), _crater));

    // The Swamp: a tree on a mound of mud, a dark pool at its foot.
    final w = WildRealm.swamp.index;
    final trunk = poly(w, const [
      (0.36, 0.93),
      (0.43, 0.86),
      (0.45, 0.72),
      (0.46, 0.56),
      (0.42, 0.45),
      (0.47, 0.44),
      (0.5, 0.5),
      (0.53, 0.44),
      (0.58, 0.45),
      (0.55, 0.56),
      (0.56, 0.72),
      (0.58, 0.86),
      (0.66, 0.93),
    ]);
    final moss = Path();
    for (final (u, top, len) in const [
      (0.29, 0.42, 0.14),
      (0.37, 0.45, 0.17),
      (0.63, 0.45, 0.16),
      (0.71, 0.42, 0.13),
    ]) {
      final a = _at(w, u - 0.008, top), b = _at(w, u + 0.008, top + len);
      moss.addRect(Rect.fromPoints(a, b));
    }
    _parts[w]
      ..clear()
      ..add((oval(w, 0.5, 0.92, 0.47, 0.085), _ground))
      ..add((oval(w, 0.26, 0.915, 0.12, 0.03), _pool))
      ..add((trunk, _trunk))
      ..add((moss, _moss))
      ..add((lobes(w, _canopyLobes), _canopy));
  }

  // The cloud, as a coarse grid of in/out, for the wind blowing through it.
  static const double _maskCell = 4;
  Uint8List _cloudMask = Uint8List(0);
  int _cmw = 0;

  void _buildCloudMask() {
    final b = _box[WildRealm.sky.index];
    _cmw = (_side / _maskCell).ceil() + 1;
    _cloudMask = Uint8List(_cmw * _cmw);
    for (var gy = 0; gy < _cmw; gy++) {
      for (var gx = 0; gx < _cmw; gx++) {
        final p = Offset(b.left + gx * _maskCell, b.top + gy * _maskCell);
        _cloudMask[gy * _cmw + gx] = _partAt(WildRealm.sky.index, p) >= 0
            ? 1
            : 0;
      }
    }
  }

  bool _inCloud(double x, double y) {
    final b = _box[WildRealm.sky.index];
    final gx = ((x - b.left) / _maskCell).round();
    final gy = ((y - b.top) / _maskCell).round();
    if (gx < 0 || gy < 0 || gx >= _cmw || gy >= _cmw) return false;
    return _cloudMask[gy * _cmw + gx] == 1;
  }

  /// The front-most part of realm [i] at (x, y), or -1.
  int _partAt(int i, Offset p) {
    final parts = _parts[i];
    for (var k = parts.length - 1; k >= 0; k--) {
      if (parts[k].$1.contains(p)) return parts[k].$2;
    }
    return -1;
  }

  // ── Grains ────────────────────────────────────────────────────────────

  // Every grain, in group order: where each rests, its push from the flow,
  // its colour clear and under its realm's weather, its part, its realm
  // (4 = Arcane) and its height in the shape's square.
  int _n = 0;
  late Float32List _hx, _hy, _ox, _oy, _vx, _vy, _size2, _ph, _v;
  late Float32List _r, _g, _b, _ar, _ag, _ab, _alpha;
  late Uint8List _realm, _part;
  final List<int> _from = List.filled(_groups, 0);
  final List<int> _to = List.filled(_groups, 0);
  final List<Rect> _reach = List.filled(_groups, Rect.zero);

  void _buildGrains(math.Random rng) {
    final groups = List.generate(_groups, (_) => <_Seed>[]);
    void add(_Seed s) => groups[_groupOf(s.part, s.realm)].add(s);
    final grain = _size.width;

    // Each realm's circle of sand: a faint disc, a little thicker at its
    // rim.
    for (var i = 0; i < 4; i++) {
      final c = _centre[i];
      final fill = (math.pi * _ringR * _ringR / 18).round();
      for (var k = 0; k < fill; k++) {
        final r = _ringR * 0.96 * math.sqrt(rng.nextDouble());
        final a = rng.nextDouble() * _tau;
        final col = _mix(0xFF6E5E44, 0xFFA8946C, rng.nextDouble());
        final al = ((0.18 + 0.14 * rng.nextDouble()) * 255).round();
        final argb = (al << 24) | (col & 0xFFFFFF);
        add(
          _Seed(
            c.dx + math.cos(a) * r,
            c.dy + math.sin(a) * r,
            grain * (0.0019 + 0.0012 * rng.nextDouble()),
            argb,
            argb,
            _sand,
            i,
            0,
          ),
        );
      }
      // The rim, shown only while the realm is ready: a fine line of green
      // grains at the circle's edge.
      final rim = (_tau * _ringR / 0.8).round();
      for (var k = 0; k < rim; k++) {
        final r = _ringR * (1 - 0.018 * rng.nextDouble());
        final a = rng.nextDouble() * _tau;
        final col = _mix(0xFF5ED07A, 0xFFA6F0B0, rng.nextDouble());
        final al = ((0.7 + 0.3 * rng.nextDouble()) * 255).round();
        final argb = (al << 24) | (col & 0xFFFFFF);
        add(
          _Seed(
            c.dx + math.cos(a) * r,
            c.dy + math.sin(a) * r,
            grain * (0.002 + 0.001 * rng.nextDouble()),
            argb,
            argb,
            _rim,
            i,
            0,
          ),
        );
      }
    }

    // The shapes: about one grain to every 1.8 square px. A grain is
    // tested a little way off its own place, so the edges come out grained,
    // never cut.
    final spacing = math.sqrt(1.8);
    for (var i = 0; i < 4; i++) {
      final b = _box[i];
      for (var y = b.top; y < b.bottom; y += spacing) {
        for (var x = b.left; x < b.right; x += spacing) {
          final px = x + (rng.nextDouble() - 0.5) * spacing * 1.1;
          final py = y + (rng.nextDouble() - 0.5) * spacing * 1.1;
          final test = Offset(
            px + (rng.nextDouble() - 0.5) * 3.2,
            py + (rng.nextDouble() - 0.5) * 3.2,
          );
          final part = _partAt(i, test);
          if (part < 0) continue;
          final u = (px - b.left) / _side, v = (py - b.top) / _side;
          final (col, alt, sub) = _look(part, u, v, px, py, rng);
          add(
            _Seed(
              px,
              py,
              grain * (0.0019 + 0.0016 * rng.nextDouble()),
              col,
              alt,
              sub,
              i,
              v,
            ),
          );
        }
      }
    }

    // Arcane: a bright ring, faint dust filling its disc, a little more
    // drifting just outside it.
    void arc(
      int part,
      int count,
      double Function() radius,
      int Function(double r) argbOf,
    ) {
      for (var k = 0; k < count; k++) {
        final r = radius();
        final a = rng.nextDouble() * _tau;
        final argb = argbOf(r);
        add(
          _Seed(
            _mid.dx + math.cos(a) * _circleR * r,
            _mid.dy + math.sin(a) * _circleR * r,
            grain * (part == _arcRing ? 0.0032 : 0.0026),
            argb,
            argb,
            part,
            4,
            r,
          ),
        );
      }
    }

    arc(
      _arcRing,
      1400,
      () => 0.88 + 0.12 * rng.nextDouble(),
      (r) => _argb(0.95, 0.72, 0.56, 1),
    );
    arc(
      _arcFill,
      2300,
      () => math.sqrt(rng.nextDouble()) * 0.98,
      (r) => _argb(0.34 + 0.2 * r, 0.54, 0.36, 0.9),
    );
    arc(_arcHaze, 500, () {
      final u = rng.nextDouble();
      return 1.0 + 0.25 * u * u;
    }, (r) => _argb(0.4 * (1 - (r - 1) / 0.25), 0.56, 0.4, 0.9));

    final all = <_Seed>[];
    for (var g = 0; g < _groups; g++) {
      _from[g] = all.length;
      all.addAll(groups[g]);
      _to[g] = all.length;
      var l = double.infinity, t = double.infinity;
      var r = -double.infinity, b = -double.infinity;
      for (final s in groups[g]) {
        if (s.x < l) l = s.x;
        if (s.x > r) r = s.x;
        if (s.y < t) t = s.y;
        if (s.y > b) b = s.y;
      }
      // Wide enough for its own motion; the movers and lava are always
      // live anyway.
      _reach[g] = groups[g].isEmpty
          ? Rect.zero
          : Rect.fromLTRB(l, t, r, b).inflate(8);
    }
    _n = all.length;
    _hx = Float32List(_n);
    _hy = Float32List(_n);
    _size2 = Float32List(_n);
    _v = Float32List(_n);
    _ox = Float32List(_n);
    _oy = Float32List(_n);
    _vx = Float32List(_n);
    _vy = Float32List(_n);
    _ph = Float32List(_n);
    _r = Float32List(_n);
    _g = Float32List(_n);
    _b = Float32List(_n);
    _ar = Float32List(_n);
    _ag = Float32List(_n);
    _ab = Float32List(_n);
    _alpha = Float32List(_n);
    _realm = Uint8List(_n);
    _part = Uint8List(_n);
    for (var k = 0; k < _n; k++) {
      final s = all[k];
      _hx[k] = s.x;
      _hy[k] = s.y;
      _size2[k] = s.size;
      _v[k] = s.v;
      _realm[k] = s.realm;
      _part[k] = s.part;
      _ph[k] = rng.nextDouble() * _tau;
      final c = s.col, a = s.alt;
      _alpha[k] = ((c >> 24) & 0xFF) / 255;
      _r[k] = ((c >> 16) & 0xFF) / 255;
      _g[k] = ((c >> 8) & 0xFF) / 255;
      _b[k] = (c & 0xFF) / 255;
      _ar[k] = ((a >> 16) & 0xFF) / 255;
      _ag[k] = ((a >> 8) & 0xFF) / 255;
      _ab[k] = (a & 0xFF) / 255;
    }
    // Where each is drawn: at rest until the field first steps, so a frame
    // painted straight after layout has every grain in place.
    _px = Float32List.fromList(_hx);
    _py = Float32List.fromList(_hy);
    _watched = null;
    _moved.fillRange(0, _groups, false);
  }

  /// A grain's colour in [part] at (u, v) of its square, the colour its
  /// realm's weather turns it (Valley: snow; Sky: storm; Swamp: dry), and
  /// the part it turns out to be (a snowcap on the rock, lava on the cone).
  (int, int, int) _look(
    int part,
    double u,
    double v,
    double x,
    double y,
    math.Random rng,
  ) {
    final n = _fbm(x * 0.05, y * 0.05, 40 + part);
    switch (part) {
      case _rock:
        // Lit on the faces left of each peak, in shade right of them.
        final peak = u < 0.66 ? 0.5 : 0.8;
        final lit = _smooth(_clamp01((peak - u) / 0.06 + 0.5));
        final below = v - _ridgeAt(u);
        final white = _mix(0xFFB8C2D6, 0xFFF4F6FA, lit);
        if (below < 0.11 + 0.05 * n && v < 0.62) {
          return (white, white, _snowcap);
        }
        var col = _mix(0xFF464A5C, 0xFF8C8FA0, lit);
        col = _mix(col, 0xFF2E3242, 0.25 * n);
        // Deep snow comes much further down the faces.
        final deep = below < 0.3 + 0.06 * n;
        return (col, deep ? white : _mix(col, 0xFFDCE4EE, 0.55), _rock);
      case _meadow:
        var col = _mix(0xFF2E5022, 0xFF6E9A3A, _clamp01(n * 1.4 - 0.2));
        if (rng.nextDouble() < 0.07) col = _mix(0xFFC8B45C, 0xFFE8D890, n);
        if (rng.nextDouble() < 0.05) col = 0xFF1C3418;
        return (col, _mix(col, 0xFFE6EDF4, 0.82), _meadow);
      case _cloud:
        // Each puff lit on its upper left, shaded beneath; the whole cloud
        // darker toward its flat base.
        final shade = _lobeShade(_cloudLobes, u, v);
        final base = _smooth(_clamp01((v - 0.52) / 0.22));
        final lit = _clamp01(shade * (1 - 0.6 * base));
        final col = _mix(0xFF8A98BE, 0xFFF6F7FA, lit);
        return (col, _mix(0xFF2E3248, 0xFF6E7290, lit), _cloud);
      case _cone:
        // Lava down the face from the crater.
        if (v > 0.27 && v < 0.84) {
          final lx = 0.53 + 0.035 * math.sin(v * 11) + (v - 0.27) * 0.2;
          final lw = 0.012 + 0.022 * (v - 0.27);
          if ((u - lx).abs() < lw) {
            final hot = 1 - (u - lx).abs() / lw;
            final col = _mix(0xFFB8401A, 0xFFFF9A3A, hot);
            return (col, col, _lava);
          }
        }
        final lit = _smooth(_clamp01((0.5 - u) / 0.12 + 0.5));
        var col = _mix(0xFF2A1C1C, 0xFF84645A, lit);
        col = _mix(col, 0xFF120C0C, 0.3 * _clamp01((v - 0.6) / 0.3));
        col = _mix(col, 0xFF2A2224, 0.3 * n);
        return (col, col, _cone);
      case _crater:
        final col = _mix(0xFFFF7A2A, 0xFFFFD27A, 1 - (v - 0.21) / 0.07);
        return (col, col, _crater);
      case _ground:
        final col = _mix(0xFF3E2A1A, 0xFF7A5634, _clamp01((0.95 - v) / 0.08));
        return (
          _mix(col, 0xFF2E2014, 0.3 * n),
          _mix(col, 0xFFA88C62, 0.7),
          _ground,
        );
      case _pool:
        final col = _mix(0xFF16302C, 0xFF2E5E54, n);
        return (col, _mix(0xFF5E4A34, 0xFF8C7450, n), _pool);
      case _trunk:
        final lit = _smooth(_clamp01((0.5 - u) / 0.05 + 0.5));
        final col = _mix(0xFF2E2018, 0xFF6A4E36, lit);
        return (col, _mix(col, 0xFF7A6448, 0.4), _trunk);
      case _moss:
        return (0xFF7C8868, 0xFF8C8060, _moss);
      default: // canopy
        final shade = _lobeShade(_canopyLobes, u, v);
        final col = _mix(0xFF1A2C1E, 0xFF5E8440, shade);
        return (
          _mix(col, 0xFF14241A, 0.25 * n),
          _mix(_mix(0xFF4A3E24, 0xFF8E7A44, shade), 0xFF3A3020, 0.2 * n),
          _canopy,
        );
    }
  }

  /// The top edge of the Valley's range at [u].
  static double _ridgeAt(double u) {
    for (var k = 1; k < _ridge.length; k++) {
      final (u0, v0) = _ridge[k - 1];
      final (u1, v1) = _ridge[k];
      if (u <= u1) return v0 + (v1 - v0) * _clamp01((u - u0) / (u1 - u0));
    }
    return _ridge.last.$2;
  }

  /// How lit (0–1) a point in a cluster of puffs is: by the puff it is
  /// most inside, lit from the upper left.
  static double _lobeShade(List<_Lobe> lobes, double u, double v) {
    var best = -1.0, shade = 0.5;
    for (final (cu, cv, r) in lobes) {
      final dx = (u - cu) / r, dy = (v - cv) / r;
      final inside = 1 - math.sqrt(dx * dx + dy * dy);
      if (inside > best) {
        best = inside;
        shade = _clamp01(0.55 - 0.42 * (dx * 0.6 + dy * 0.8));
      }
    }
    return shade;
  }

  // ── The light under each realm ────────────────────────────────────────

  // Soft lights strewn inside each shape: x, y, radius, realm.
  final List<(double, double, double, int)> _washes = [];

  void _buildWashes(math.Random rng) {
    _washes.clear();
    for (var i = 0; i < 4; i++) {
      var placed = 0, tries = 0;
      while (placed < 9 && tries++ < 400) {
        final b = _box[i];
        final p = Offset(
          b.left + rng.nextDouble() * _side,
          b.top + rng.nextDouble() * _side,
        );
        if (_partAt(i, p) < 0) continue;
        _washes.add((p.dx, p.dy, _side * (0.16 + 0.12 * rng.nextDouble()), i));
        placed++;
      }
    }
  }

  // Each realm's light: clear, and under its weather.
  static const _washClear = [0xFF6E7A9C, 0xFFB8C8E0, 0xFF6A2A16, 0xFF2E5034];
  static const _washAlt = [0xFFD0DAE6, 0xFF3A3E58, 0xFF6A2A16, 0xFF6A5A38];

  void _paintWashes() {
    final t = time;
    for (final (x, y, r, i) in _washes) {
      final c = _mix(_washClear[i], _washAlt[i], _wx[i]);
      final breathe = 0.85 + 0.15 * _fsin(t * 0.5 + x * 0.05);
      var a = 0.06 * breathe;
      if (i == WildRealm.sky.index) a += 0.14 * _flash * _wx[i];
      _wash.add(x, y, r * 2, (_byte(a) << 24) | (c & 0xFFFFFF));
    }
    // The Volcano's crater, glowing.
    final crater = _at(WildRealm.volcano.index, 0.5, 0.25);
    _wash.add(
      crater.dx,
      crater.dy,
      _side * 0.5,
      _argb(0.28 + 0.06 * _fsin(t * 1.7), 1, 0.48, 0.16),
    );
    if (arcane) {
      _wash.add(
        _mid.dx,
        _mid.dy,
        _circleR * 3,
        _argb(0.16 + 0.04 * _fsin(t * 0.9), 0.5, 0.24, 0.95),
      );
    }
  }

  // ── Movers: grains that travel ────────────────────────────────────────

  // Kinds: 0 wind through the cloud, 1 ember off the crater, 2 smoke off
  // the crater, 3 dust off the dry Swamp.
  int _m = 0;
  late Float32List _mx, _my, _mph, _mspd, _mox, _moy, _mvx, _mvy;
  late Uint8List _mkind;

  void _buildMovers(math.Random rng) {
    final kinds = <int>[], xs = <double>[], ys = <double>[];
    final speeds = <double>[];
    void add(int kind, double x, double y, double speed) {
      kinds.add(kind);
      xs.add(x);
      ys.add(y);
      speeds.add(speed);
    }

    final s = _box[WildRealm.sky.index];
    for (var k = 0; k < 320; k++) {
      add(
        0,
        s.left + rng.nextDouble() * _side,
        s.top + _side * (0.3 + 0.45 * rng.nextDouble()),
        _side * (0.12 + 0.12 * rng.nextDouble()),
      );
    }
    final crater = _at(WildRealm.volcano.index, 0.5, 0.24);
    for (var k = 0; k < 220; k++) {
      add(
        1,
        crater.dx + (rng.nextDouble() - 0.5) * _side * 0.12,
        crater.dy,
        _side * (0.16 + 0.14 * rng.nextDouble()),
      );
    }
    for (var k = 0; k < 200; k++) {
      add(
        2,
        crater.dx + (rng.nextDouble() - 0.5) * _side * 0.08,
        crater.dy,
        _side * (0.08 + 0.06 * rng.nextDouble()),
      );
    }
    final w = WildRealm.swamp.index;
    for (var k = 0; k < 90; k++) {
      final g = _at(w, 0.1 + 0.8 * rng.nextDouble(), 0.9);
      add(3, g.dx, g.dy, _side * (0.04 + 0.05 * rng.nextDouble()));
    }
    _m = kinds.length;
    _mkind = Uint8List.fromList(kinds);
    _mx = Float32List.fromList(xs);
    _my = Float32List.fromList(ys);
    _mspd = Float32List.fromList(speeds);
    _mph = Float32List(_m);
    for (var k = 0; k < _m; k++) {
      _mph[k] = rng.nextDouble();
    }
    _mox = Float32List(_m);
    _moy = Float32List(_m);
    _mvx = Float32List(_m);
    _mvy = Float32List(_m);
  }

  // ── The flow a finger leaves ──────────────────────────────────────────

  static const double _cell = 14;
  int _fieldW = 0, _fieldH = 0;
  Float32List _fu = Float32List(0), _fv = Float32List(0), _ft = Float32List(0);
  bool _fieldOn = false;

  // Round the part of the flow still moving anything.
  Rect _flowBox = Rect.zero;

  /// A finger drawn [delta] (px, over [dt] s) through [at].
  void stir(Offset at, Offset delta, double dt) {
    if (_fieldW == 0) return;
    final s = 1 / math.max(dt, 1 / 120);
    final ux = (delta.dx * s).clamp(-1600.0, 1600.0);
    final uy = (delta.dy * s).clamp(-1600.0, 1600.0);
    _inject(at, 50, (dx, dy, w) => (ux * w, uy * w), blend: true);
  }

  /// A push out from [at], as a tap or a strike of lightning gives.
  void ripple(Offset at, {double strength = 320, double reach = 70}) {
    if (_fieldW == 0) return;
    _inject(at, reach, (dx, dy, w) {
      final l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      return (dx / l * strength * w, dy / l * strength * w);
    });
  }

  void _inject(
    Offset at,
    double reach,
    (double, double) Function(double dx, double dy, double w) push, {
    bool blend = false,
  }) {
    final g0x = ((at.dx - reach) / _cell).floor().clamp(0, _fieldW - 1);
    final g1x = ((at.dx + reach) / _cell).ceil().clamp(0, _fieldW - 1);
    final g0y = ((at.dy - reach) / _cell).floor().clamp(0, _fieldH - 1);
    final g1y = ((at.dy + reach) / _cell).ceil().clamp(0, _fieldH - 1);
    for (var gy = g0y; gy <= g1y; gy++) {
      for (var gx = g0x; gx <= g1x; gx++) {
        final dx = gx * _cell - at.dx, dy = gy * _cell - at.dy;
        final q = (dx * dx + dy * dy) / (reach * reach);
        if (q >= 1) continue;
        final w = (1 - q) * (1 - q);
        final (pu, pv) = push(dx, dy, w);
        final i = gy * _fieldW + gx;
        if (blend) {
          // Toward the finger's own speed, never past it.
          _fu[i] += (pu / math.max(w, 1e-3) - _fu[i]) * w * 0.7;
          _fv[i] += (pv / math.max(w, 1e-3) - _fv[i]) * w * 0.7;
        } else {
          _fu[i] += pu;
          _fv[i] += pv;
        }
      }
    }
    final box = Rect.fromCircle(center: at, radius: reach + _cell);
    _flowBox = _fieldOn ? _flowBox.expandToInclude(box) : box;
    _fieldOn = true;
  }

  void _stepField(double dt) {
    if (!_fieldOn) return;
    final decay = math.exp(-dt / 0.3);
    var most = 0.0;
    var x0 = _fieldW, x1 = -1, y0 = _fieldH, y1 = -1;
    // Spread a little to the neighbours, so a stroke leaves a soft wake.
    for (final f in [_fu, _fv]) {
      final t = _ft;
      for (var gy = 0; gy < _fieldH; gy++) {
        for (var gx = 0; gx < _fieldW; gx++) {
          final i = gy * _fieldW + gx;
          var s = f[i] * 4;
          var w = 4.0;
          if (gx > 0) {
            s += f[i - 1];
            w++;
          }
          if (gx < _fieldW - 1) {
            s += f[i + 1];
            w++;
          }
          if (gy > 0) {
            s += f[i - _fieldW];
            w++;
          }
          if (gy < _fieldH - 1) {
            s += f[i + _fieldW];
            w++;
          }
          t[i] = s / w * decay;
        }
      }
      for (var i = 0; i < f.length; i++) {
        f[i] = t[i];
        final a = f[i].abs();
        if (a > most) most = a;
        // Slower than this barely moves a grain: not worth waking for.
        if (a > 12) {
          final gx = i % _fieldW, gy = i ~/ _fieldW;
          if (gx < x0) x0 = gx;
          if (gx > x1) x1 = gx;
          if (gy < y0) y0 = gy;
          if (gy > y1) y1 = gy;
        }
      }
    }
    if (x1 >= 0) {
      _flowBox = Rect.fromLTRB(
        (x0 - 1) * _cell,
        (y0 - 1) * _cell,
        (x1 + 1) * _cell,
        (y1 + 1) * _cell,
      );
    }
    if (most < 3) {
      _fu.fillRange(0, _fu.length, 0);
      _fv.fillRange(0, _fv.length, 0);
      _fieldOn = false;
    }
  }

  // Sets [_su], [_sv] to the flow at (x, y).
  double _su = 0, _sv = 0;
  void _sample(double x, double y) {
    final fx = x / _cell, fy = y / _cell;
    final gx = fx.floor(), gy = fy.floor();
    if (gx < 0 || gy < 0 || gx >= _fieldW - 1 || gy >= _fieldH - 1) {
      _su = _sv = 0;
      return;
    }
    final tx = fx - gx, ty = fy - gy;
    final i = gy * _fieldW + gx;
    final a = _fu[i], b = _fu[i + 1], c = _fu[i + _fieldW];
    final d = _fu[i + _fieldW + 1];
    _su = a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty;
    final e = _fv[i], f = _fv[i + 1], g = _fv[i + _fieldW];
    final h = _fv[i + _fieldW + 1];
    _sv = e + (f - e) * tx + (g - e) * ty + (e - f - g + h) * tx * ty;
  }

  // ── Weather and the realms' moods ─────────────────────────────────────

  // Eased toward what [weather] and [ready] ask for, per realm; each lands
  // on its mark, so a field at rest can keep its pictures.
  final Float64List _wx = Float64List(4);
  final Float64List _rain = Float64List(1);
  final Float64List _ready = Float64List(4);
  double _flash = 0;
  double _nextStrike = 2;
  final List<Offset> _bolt = [], _fork = [];
  double _boltAge = 9;
  final math.Random _rng = math.Random(11);

  double _target(WildRealm r) {
    final w = weather[r.sceneId];
    return switch (r) {
      WildRealm.valley => w == WeatherKind.snow ? 1 : 0,
      WildRealm.sky => w == WeatherKind.storm ? 1 : 0,
      WildRealm.swamp => w == WeatherKind.dry ? 1 : 0,
      WildRealm.volcano => 0,
    };
  }

  bool get _raining => weather['valley'] == WeatherKind.rain;

  /// Snaps the weather and the realms' moods to what is asked, no easing.
  void settle() {
    for (final r in WildRealm.values) {
      _wx[r.index] = _target(r);
      _ready[r.index] = ready.contains(r.sceneId) ? 1 : 0;
    }
    _rain[0] = _raining ? 1 : 0;
  }

  static double _ease(double v, double to, double k) {
    final next = v + (to - v) * k;
    return (next - to).abs() < 2e-3 ? to : next;
  }

  void step(double dt) {
    time += dt;
    final k = 1 - math.exp(-dt / 1.2);
    for (final r in WildRealm.values) {
      _wx[r.index] = _ease(_wx[r.index], _target(r), k);
      final to = ready.contains(r.sceneId) ? 1.0 : 0.0;
      _ready[r.index] = _ease(_ready[r.index], to, k);
    }
    _rain[0] = _ease(_rain[0], _raining ? 1 : 0, k);
    _stepField(dt);
    _stepStorm(dt);
    _stepGrains(dt);
  }

  /// Brings the next strike of lightning now (previews).
  void debugStrike() => _nextStrike = 0;

  void _stepStorm(double dt) {
    _flash *= math.exp(-dt / 0.22);
    if (_flash < 0.01) _flash = 0;
    _boltAge += dt;
    final storm = _wx[WildRealm.sky.index];
    if (storm < 0.3 || _size.isEmpty) return;
    _nextStrike -= dt;
    if (_nextStrike > 0) return;
    _nextStrike = 1.6 + _rng.nextDouble() * 2.8;
    // A bolt out of the cloud's underside, jagged, sometimes forked.
    final i = WildRealm.sky.index;
    final from = _at(i, 0.25 + 0.5 * _rng.nextDouble(), 0.6);
    var x = from.dx, y = from.dy;
    final end = _box[i].top + _side * (0.9 + 0.08 * _rng.nextDouble());
    _bolt
      ..clear()
      ..add(Offset(x, y));
    while (y < end) {
      y += 5 + _rng.nextDouble() * 6;
      x += (_rng.nextDouble() - 0.5) * 12;
      _bolt.add(Offset(x, y));
    }
    // A fork off it, leaning away.
    _fork.clear();
    if (_bolt.length > 4 && _rng.nextDouble() < 0.75) {
      final start = _bolt[1 + _rng.nextInt(_bolt.length ~/ 2)];
      final lean = _rng.nextBool() ? 1.0 : -1.0;
      var fx = start.dx, fy = start.dy;
      _fork.add(start);
      for (var k = 0; k < 3 + _rng.nextInt(3); k++) {
        fy += 4 + _rng.nextDouble() * 5;
        fx += lean * (4 + _rng.nextDouble() * 6);
        _fork.add(Offset(fx, fy));
      }
    }
    _boltAge = 0;
    _flash = 1;
    ripple(from, strength: 240 * storm, reach: 70);
  }

  // ── Motion ────────────────────────────────────────────────────────────

  /// Every grain's place this frame, after its own motion and the flow.
  /// Kept only for groups being drawn grain by grain.
  Float32List _px = Float32List(0), _py = Float32List(0);

  // Whether each group has a grain still pushed off its place.
  final List<bool> _moved = List.filled(_groups, false);

  // Each moving group's one move this frame.
  double _cloudDx = 0, _cloudDy = 0, _treeShear = 0, _treeBase = 0;
  double _arcTurn = 0;

  /// Whether group [g] is drawn grain by grain this frame, rather than
  /// from its picture.
  bool _live(int g) {
    if (_moved[g]) return true;
    if (_fieldOn && _reach[g].overlaps(_flowBox)) return true;
    if (g == _gLive) return true;
    if (g == _gCloud && _flash > 0) return true;
    if (g >= _gRim && g < _gRim + 4) return _ready[g - _gRim] > 0;
    return false;
  }

  void _stepGrains(double dt) {
    final t = time;
    const drag = 5.0, spring = 14.0;
    _cloudDx = 2.2 * _fsin(0.23 * t);
    _cloudDy = 2.4 * _fsin(0.41 * t);
    final dry = _wx[WildRealm.swamp.index];
    // The crown leans over its trunk and back: a shear about where they
    // meet, so its top moves most.
    _treeBase = _box[WildRealm.swamp.index].top + _side * 0.6;
    _treeShear = -(1 - 0.3 * dry) * 0.032 * _fsin(0.9 * t);
    _arcTurn = t * 0.32;
    final ac = _fcos(_arcTurn), as = _fsin(_arcTurn);
    final mid = _mid;

    for (var grp = 0; grp < _groups; grp++) {
      if (!_live(grp)) continue;
      final on = _fieldOn && _reach[grp].overlaps(_flowBox);
      var moved = false;
      for (var k = _from[grp]; k < _to[grp]; k++) {
        final hx = _hx[k], hy = _hy[k];
        var bx = hx, by = hy;
        switch (grp) {
          case _gCloud:
            bx += _cloudDx;
            by += _cloudDy;
          case _gTree:
            bx += _treeShear * (hy - _treeBase);
          case _gArcane:
            final dx = hx - mid.dx, dy = hy - mid.dy;
            bx = mid.dx + dx * ac - dy * as;
            by = mid.dy + dx * as + dy * ac;
          case _gLive:
            final ph = _ph[k];
            if (_part[k] == _meadow) {
              // Grass in the wind, in waves crossing it.
              bx += 1.2 * _fsin(1.3 * t - hx * 0.05 + ph * 0.3);
            } else {
              // Heat shimmer over the lava.
              bx += 0.4 * _fsin(2.6 * t + ph);
              by += 0.5 * _fsin(3.1 * t + ph * 1.7);
            }
          default:
            break;
        }
        var ox = _ox[k], oy = _oy[k], vx = _vx[k], vy = _vy[k];
        if (on || ox != 0 || oy != 0 || vx != 0 || vy != 0) {
          var fu = 0.0, fv = 0.0;
          if (on) {
            _sample(bx + ox, by + oy);
            fu = _su;
            fv = _sv;
          }
          vx += (drag * (fu - vx) - spring * ox) * dt;
          vy += (drag * (fv - vy) - spring * oy) * dt;
          ox += vx * dt;
          oy += vy * dt;
          if (!on &&
              ox.abs() < 0.05 &&
              oy.abs() < 0.05 &&
              vx.abs() < 0.5 &&
              vy.abs() < 0.5) {
            ox = oy = vx = vy = 0;
          } else {
            moved = true;
          }
          _ox[k] = ox;
          _oy[k] = oy;
          _vx[k] = vx;
          _vy[k] = vy;
        }
        _px[k] = bx + ox;
        _py[k] = by + oy;
      }
      _moved[grp] = moved;
    }

    final on = _fieldOn;
    for (var k = 0; k < _m; k++) {
      var ox = _mox[k], oy = _moy[k], vx = _mvx[k], vy = _mvy[k];
      if (on || ox != 0 || oy != 0 || vx != 0 || vy != 0) {
        var fu = 0.0, fv = 0.0;
        if (on) {
          final (x, y) = _moverAt(k);
          _sample(x + ox, y + oy);
          fu = _su;
          fv = _sv;
        }
        vx += (drag * (fu - vx) - spring * ox) * dt;
        vy += (drag * (fv - vy) - spring * oy) * dt;
        ox += vx * dt;
        oy += vy * dt;
        if (!on && ox.abs() < 0.05 && oy.abs() < 0.05 && vx.abs() < 0.5) {
          ox = oy = vx = vy = 0;
        }
        _mox[k] = ox;
        _moy[k] = oy;
        _mvx[k] = vx;
        _mvy[k] = vy;
      }
    }
  }

  /// Where mover [k] is on its own path, before any push.
  (double, double) _moverAt(int k) {
    final t = time;
    final x0 = _mx[k], y0 = _my[k], sp = _mspd[k], ph = _mph[k];
    switch (_mkind[k]) {
      case 0: // Wind through the cloud, round and round its width.
        final b = _box[WildRealm.sky.index];
        final x = b.left + ((x0 - b.left + sp * t) % _side);
        return (x + _cloudDx, y0 + _cloudDy + 2 * _fsin(t * 0.7 + ph * _tau));
      case 1: // Embers up off the crater.
        const life = 3.6;
        final a = (t / life + ph) % 1.0;
        return (x0 + _side * 0.08 * a * _fsin(ph * 40 + t), y0 - a * sp * life);
      case 2: // Smoke off the crater, leaning away on the wind.
        const life = 6.0;
        final a = (t / life + ph) % 1.0;
        return (
          x0 + _side * (0.22 * a * a + 0.05 * a * _fsin(ph * 30)),
          y0 - a * sp * life,
        );
      default: // Dust lifting off the dried Swamp.
        const life = 5.0;
        final a = (t / life + ph) % 1.0;
        return (x0 + 6 * _fsin(t * 0.8 + ph * 20), y0 - a * sp * life);
    }
  }

  // ── Drawing ───────────────────────────────────────────────────────────

  static ui.Image? _atlas;
  static final Paint _over = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _add = Paint()
    ..filterQuality = FilterQuality.medium
    ..blendMode = BlendMode.plus;
  // Ink: each colour deepened, so grains read as stipple on the page and
  // the lights as darker, warmer marks.
  static final Paint _inkOver = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.matrix([
      0.62, 0, 0, 0, 0, //
      0, 0.6, 0, 0, 0, //
      0, 0, 0.64, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  static final Paint _inkGlow = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.matrix([
      0.52, 0, 0, 0, 0, //
      0, 0.4, 0, 0, 0, //
      0, 0, 0.58, 0, 0, //
      0, 0, 0, 0.8, 0, //
    ]);
  final _Batch _dots = _Batch(_solid);
  final _Batch _wash = _Batch(_soft);
  final _Batch _glow = _Batch(_soft);

  // Each group's picture at rest, and what it was drawn for.
  final List<ui.Picture?> _pics = List.filled(_groups, null);
  List<double>? _picKey;

  void _dropPictures() {
    for (var g = 0; g < _groups; g++) {
      _pics[g]?.dispose();
      _pics[g] = null;
    }
    _picKey = null;
  }

  /// Lets go of the pictures kept for the field at rest.
  void dispose() => _dropPictures();

  List<double> get _key => [
    _wx[0],
    _wx[1],
    _wx[2],
    _wx[3],
    _rain[0],
    ink ? 1 : 0,
  ];

  /// Grains drawn grain by grain in the last frame.
  int debugGrains = 0;

  /// Groups drawn from their picture in the last frame.
  int debugPictures = 0;

  /// The farthest any grain has been pushed from its place, px.
  double get debugDisplacement {
    var most = 0.0;
    for (var k = 0; k < _n; k++) {
      final d = _ox[k].abs() + _oy[k].abs();
      if (d > most) most = d;
    }
    return most;
  }

  int? _watched;

  /// Where the grain that rests nearest [p] is now (the same grain on
  /// every call; one that never moves, of the mountains or the cone).
  Offset debugGrainNear(Offset p) {
    var k = _watched;
    if (k == null) {
      var bd = double.infinity;
      for (var i = _from[_gStill]; i < _to[_gStill + 3]; i++) {
        if (_part[i] == _sand) continue;
        final dx = _hx[i] - p.dx, dy = _hy[i] - p.dy;
        if (dx * dx + dy * dy < bd) {
          bd = dx * dx + dy * dy;
          k = i;
        }
      }
      _watched = k;
    }
    return Offset(_px[k!], _py[k]);
  }

  /// Whether a bolt of lightning is showing.
  bool get debugStriking => _boltAge < 0.4 && _bolt.isNotEmpty;

  void paint(Canvas canvas) {
    if (_size.isEmpty) return;
    _atlas ??= _buildAtlas();
    debugGrains = 0;
    debugPictures = 0;
    final key = _key;
    if (!_sameKey(key, _picKey)) {
      _dropPictures();
      _picKey = key;
    }
    final dots = ink ? _inkOver : _over;

    _wash.clear();
    _paintWashes();
    if (!ink) _wash.draw(canvas, _atlas!, _add);
    _glow.clear();

    for (var g = 0; g < _groups; g++) {
      if (g == _gArcane && !arcane) continue;
      if (g >= _gRim && g < _gRim + 4 && _ready[g - _gRim] <= 0) continue;
      if (_live(g)) {
        _dots.clear();
        _emit(g);
        if (g == _gLive) {
          // Movers and weather draw with the live grains.
          _paintMovers();
          _paintWeather();
        }
        debugGrains += _dots.n;
        _dots.draw(canvas, _atlas!, dots);
        continue;
      }
      var pic = _pics[g];
      if (pic == null) {
        final rec = ui.PictureRecorder();
        _dots.clear();
        _emitAtRest(g);
        _dots.draw(Canvas(rec), _atlas!, dots);
        pic = _pics[g] = rec.endRecording();
      }
      debugPictures++;
      _drawMoved(canvas, g, pic);
    }
    _paintRimGlow();
    _glow.draw(canvas, _atlas!, ink ? _inkGlow : _add);
  }

  /// [pic] drawn with its group's one move this frame.
  void _drawMoved(Canvas canvas, int g, ui.Picture pic) {
    switch (g) {
      case _gCloud:
        canvas
          ..save()
          ..translate(_cloudDx, _cloudDy)
          ..drawPicture(pic)
          ..restore();
      case _gTree:
        canvas
          ..save()
          ..translate(0, _treeBase)
          ..skew(_treeShear, 0)
          ..translate(0, -_treeBase)
          ..drawPicture(pic)
          ..restore();
      case _gArcane:
        canvas
          ..save()
          ..translate(_mid.dx, _mid.dy)
          ..rotate(_arcTurn)
          ..translate(-_mid.dx, -_mid.dy)
          ..drawPicture(pic)
          ..restore();
      default:
        canvas.drawPicture(pic);
    }
  }

  static bool _sameKey(List<double> a, List<double>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // A grain's colour under its realm's weather, set by [_colour].
  double _cr = 0, _cg = 0, _cb = 0;
  void _colour(int k) {
    final ri = _realm[k];
    final w = ri < 4 ? _wx[ri] : 0.0;
    _cr = _r[k] + (_ar[k] - _r[k]) * w;
    _cg = _g[k] + (_ag[k] - _g[k]) * w;
    _cb = _b[k] + (_ab[k] - _b[k]) * w;
    if (ri == 0 && _rain[0] > 0 && _part[k] != _sand && _part[k] != _rim) {
      // Wet: darker, a little blue.
      final l = 1 - 0.22 * _rain[0];
      _cr *= l;
      _cg *= l;
      _cb = _cb * l + 0.05 * _rain[0];
    }
  }

  /// Group [g]'s grains at their places, for its picture.
  void _emitAtRest(int g) {
    for (var k = _from[g]; k < _to[g]; k++) {
      _colour(k);
      _dots.add(_hx[k], _hy[k], _size2[k], _argb(_alpha[k], _cr, _cg, _cb));
    }
  }

  /// Group [g]'s grains where they are this frame, catching the light when
  /// pushed, and the Sky's when lightning flashes.
  void _emit(int g) {
    final flash = g == _gCloud ? _flash * _wx[WildRealm.sky.index] : 0.0;
    final bolt = _bolt.isNotEmpty ? _bolt.first : null;
    final t = time;
    for (var k = _from[g]; k < _to[g]; k++) {
      _colour(k);
      var r = _cr, gg = _cg, b = _cb, a = _alpha[k];
      final x = _px[k], y = _py[k];
      if (_part[k] == _rim) {
        // A realm with something waiting: its rim pulses.
        final pulse = 0.5 + 0.5 * _fsin(t * 2.4 + _realm[k] * 1.3);
        a *= _ready[_realm[k]] * (0.6 + 0.4 * pulse);
      }
      var l = 1.0;
      if (flash > 0) {
        var near = 0.5;
        if (bolt != null) {
          final dx = x - bolt.dx, dy = y - bolt.dy;
          near = math.max(0.4, 1 - (dx * dx + dy * dy) / (90 * 90));
        }
        l += flash * 1.5 * near;
      }
      final sp = _vx[k].abs() + _vy[k].abs();
      final lit = sp > 30 ? math.min(1.0, (sp - 30) / 400) : 0.0;
      r = r * l + (1 - r) * lit * 0.6;
      gg = gg * l + (1 - gg) * lit * 0.6;
      b = b * l + (1 - b) * lit * 0.55;
      _dots.add(x, y, _size2[k], _argb(a, r, gg, b));
      if (lit > 0.5) {
        _glow.add(x, y, _size2[k] * 3, _argb(0.25 * lit, r, gg, b));
      }
      if (_part[k] == _lava || _part[k] == _crater) {
        // Lava and the crater glow, breathing.
        final pulse = 0.75 + 0.25 * _fsin(t * 1.6);
        _glow.add(x, y, _size2[k] * 3.2, _argb(0.2 * pulse, r, gg, b));
      }
    }
  }

  /// Soft green light along each waiting realm's rim, pulsing with it.
  void _paintRimGlow() {
    final grain = _size.width;
    final t = time;
    for (var i = 0; i < 4; i++) {
      final ready = _ready[i];
      if (ready <= 0) continue;
      final pulse = 0.5 + 0.5 * _fsin(t * 2.4 + i * 1.3);
      final c = _centre[i];
      const n = 96;
      for (var k = 0; k < n; k++) {
        final a = _tau * k / n;
        _glow.add(
          c.dx + math.cos(a) * _ringR * 0.97,
          c.dy + math.sin(a) * _ringR * 0.97,
          grain * 0.024,
          _argb(0.2 * ready * (0.45 + 0.55 * pulse), 0.42, 0.9, 0.5),
        );
      }
    }
  }

  void _paintMovers() {
    final grain = _size.width;
    final storm = _wx[WildRealm.sky.index];
    final dry = _wx[WildRealm.swamp.index];
    for (var k = 0; k < _m; k++) {
      final kind = _mkind[k];
      if (kind == 3 && dry < 0.05) continue;
      final (x0, y0) = _moverAt(k);
      final x = x0 + _mox[k], y = y0 + _moy[k];
      switch (kind) {
        case 0:
          if (!_inCloud(x0 - _cloudDx, y0 - _cloudDy)) continue;
          _dots.add(
            x,
            y,
            grain * 0.0028,
            storm > 0.5 ? _argb(0.5, 0.56, 0.58, 0.72) : _argb(0.6, 1, 1, 1),
          );
        case 1:
          final a = (time / 3.6 + _mph[k]) % 1.0;
          final fade = a < 0.1 ? a / 0.1 : 1 - a;
          // Gold off the crater, cooling to red as it rises.
          _glow.add(
            x,
            y,
            grain * (0.011 - 0.005 * a),
            _argb(0.75 * fade, 1, 0.82 - 0.5 * a, 0.36 - 0.3 * a),
          );
        case 2:
          final a = (time / 6 + _mph[k]) % 1.0;
          final fade = (a < 0.12 ? a / 0.12 : 1 - a) * 0.5;
          _dots.add(
            x,
            y,
            grain * (0.0028 + 0.0045 * a),
            _argb(fade, 0.42, 0.38, 0.38),
          );
        default:
          final a = (time / 5 + _mph[k]) % 1.0;
          final fade = (a < 0.15 ? a / 0.15 : 1 - a) * dry;
          _dots.add(x, y, grain * 0.003, _argb(0.5 * fade, 0.72, 0.62, 0.44));
      }
    }
  }

  void _paintWeather() {
    final grain = _size.width;
    final v = WildRealm.valley.index;
    final box = _box[v];
    final top = box.top - _side * 0.12, height = _side * 1.1;

    // Rain over the mountains: short falling streaks of grains.
    final rain = _rain[0];
    if (rain > 0) {
      for (var k = 0; k < 260; k++) {
        final ph = _hash(k * 3 + 1), ph2 = _hash(k * 3 + 2);
        final fall = (time * (1.1 + 0.4 * ph2) + ph) % 1.0;
        final y = top + fall * height;
        final x =
            box.left + ((_hash(k * 3) * _side + fall * height * 0.18) % _side);
        final m = _zone(v, x, y);
        if (m < 0.05) continue;
        for (var j = 0; j < 6; j++) {
          _dots.add(
            x - j * 0.55,
            y - j * 2.6,
            grain * 0.003,
            _argb(rain * m * (0.85 - j * 0.13), 0.8, 0.88, 0.98),
          );
        }
      }
    }
    // Snow: soft flakes drifting down.
    final snow = _wx[v];
    if (snow > 0) {
      for (var k = 0; k < 150; k++) {
        final ph = _hash(k * 5 + 7);
        final fall = (time * (0.08 + 0.05 * _hash(k * 5 + 8)) + ph) % 1.0;
        final y = top + fall * height;
        final x =
            box.left +
            _hash(k * 5 + 9) * _side +
            7 * _fsin(time * 0.9 + ph * 30);
        final m = _zone(v, x, y);
        if (m < 0.05) continue;
        _glow.add(x, y, grain * 0.014, _argb(0.7 * snow * m, 0.95, 0.97, 1));
      }
    }
    // Lightning: the bolt, as grains, flickering out.
    if (_boltAge < 0.4 && _bolt.length > 1) {
      final storm = _wx[WildRealm.sky.index];
      final flick =
          (_boltAge < 0.05 ? 1.0 : math.exp(-(_boltAge - 0.05) * 9)) *
          (0.8 + 0.2 * math.sin(_boltAge * 90)) *
          storm;
      for (final (path, k) in [(_bolt, 1.0), (_fork, 0.6)]) {
        for (var j = 1; j < path.length; j++) {
          final a = path[j - 1], b = path[j];
          final steps = ((b - a).distance / 0.9).ceil();
          for (var s = 0; s < steps; s++) {
            final p = Offset.lerp(a, b, s / steps)!;
            _dots.add(
              p.dx,
              p.dy,
              grain * 0.0062 * k,
              _argb(flick * k, 1, 1, 1),
            );
            if (s % 3 == 0) {
              _glow.add(
                p.dx,
                p.dy,
                grain * 0.045,
                _argb(0.32 * flick * k, 0.74, 0.72, 1),
              );
            }
          }
        }
      }
    }
  }
}

// ── Drawing helpers ──────────────────────────────────────────────────────

const double _solidCell = 16, _softCell = 32;
const Rect _solid = Rect.fromLTWH(0, 0, _solidCell, _solidCell);
const Rect _soft = Rect.fromLTWH(_solidCell, 0, _softCell, _softCell);

/// A grain (solid heart, soft rim so it minifies cleanly) and a soft light.
ui.Image _buildAtlas() {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const white = Color(0xFFFFFFFF);
  const sc = Offset(_solidCell / 2, _solidCell / 2);
  c.drawCircle(
    sc,
    _solidCell / 2,
    Paint()
      ..shader = ui.Gradient.radial(
        sc,
        _solidCell / 2,
        [
          white,
          white,
          white.withValues(alpha: 0.6),
          white.withValues(alpha: 0),
        ],
        const [0, 0.55, 0.8, 1],
      ),
  );
  const gc = Offset(_solidCell + _softCell / 2, _softCell / 2);
  c.drawCircle(
    gc,
    _softCell / 2,
    Paint()
      ..shader = ui.Gradient.radial(
        gc,
        _softCell / 2,
        [
          white,
          white.withValues(alpha: 0.55),
          white.withValues(alpha: 0.18),
          white.withValues(alpha: 0.05),
          white.withValues(alpha: 0),
        ],
        const [0, 0.18, 0.42, 0.7, 1],
      ),
  );
  return rec.endRecording().toImageSync(
    (_solidCell + _softCell).toInt(),
    _softCell.toInt(),
  );
}

/// Grains of one sprite, each its own colour and size, in one atlas call.
/// Grows as it needs to and keeps its size.
class _Batch {
  _Batch(this._src);

  final Rect _src;
  Float32List _xf = Float32List(0), _rects = Float32List(0);
  Int32List _colors = Int32List(0);
  int n = 0;

  void clear() => n = 0;

  void add(double x, double y, double size, int argb) {
    if ((argb >>> 24) < 3 || size <= 0) return;
    if (n >= _colors.length) _grow();
    final cell = _src.width;
    final s = size / cell;
    final i = n * 4;
    _xf[i] = s;
    _xf[i + 1] = 0;
    _xf[i + 2] = x - s * cell / 2;
    _xf[i + 3] = y - s * cell / 2;
    _colors[n] = argb;
    n++;
  }

  void _grow() {
    final cap = math.max(1024, _colors.length * 2);
    _xf = Float32List(cap * 4)..setAll(0, _xf);
    final rects = Float32List(cap * 4)..setAll(0, _rects);
    for (var i = _colors.length; i < cap; i++) {
      rects[i * 4] = _src.left;
      rects[i * 4 + 1] = _src.top;
      rects[i * 4 + 2] = _src.right;
      rects[i * 4 + 3] = _src.bottom;
    }
    _rects = rects;
    _colors = Int32List(cap)..setAll(0, _colors);
  }

  void draw(Canvas c, ui.Image atlas, Paint paint) {
    if (n == 0) return;
    c.drawRawAtlas(
      atlas,
      Float32List.sublistView(_xf, 0, n * 4),
      Float32List.sublistView(_rects, 0, n * 4),
      Int32List.sublistView(_colors, 0, n),
      BlendMode.modulate,
      null,
      paint,
    );
  }
}

int _byte(double v) => v <= 0 ? 0 : (v >= 1 ? 255 : (v * 255).toInt());

int _argb(double a, double r, double g, double b) =>
    (_byte(a) << 24) | (_byte(r) << 16) | (_byte(g) << 8) | _byte(b);

int _mix(int a, int b, double t) {
  int ch(int s) =>
      (((a >> s) & 0xFF) + ((((b >> s) & 0xFF) - ((a >> s) & 0xFF)) * t))
          .round()
          .clamp(0, 255);
  return (0xFF << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

// A sine by table, for the per-grain sway and twinkle: tens of thousands a
// frame, where the table's 1024 steps look the same as the real thing.
final Float32List _sinTable = Float32List.fromList([
  for (var i = 0; i < 1024; i++) math.sin(i / 1024 * _tau),
]);

double _fsin(double x) => _sinTable[(x * (1024 / _tau)).floor() & 1023];

double _fcos(double x) => _fsin(x + math.pi / 2);

/// A fixed pseudo-random number in [0, 1) for [k].
double _hash(int k) {
  final v = math.sin(k * 127.1 + 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

double _smooth(double t) => t * t * (3 - 2 * t);

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _lattice(int x, int y, int seed) {
  var h = (x * 0x27d4eb2d) ^ (y * 0x165667b1) ^ (seed * 0x5bd1e995);
  h = (h ^ (h >> 15)) * 0x2c1b3c6d;
  h = (h ^ (h >> 12)) * 0x297a2d39;
  h ^= h >> 15;
  return (h & 0xFFFFFF) / 0xFFFFFF;
}

double _noise(double x, double y, int seed) {
  final xi = x.floor(), yi = y.floor();
  final fx = _smooth(x - xi), fy = _smooth(y - yi);
  final a = _lattice(xi, yi, seed), b = _lattice(xi + 1, yi, seed);
  final c = _lattice(xi, yi + 1, seed), d = _lattice(xi + 1, yi + 1, seed);
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

double _fbm(double x, double y, int seed) {
  var sum = 0.0, amp = 0.5, norm = 0.0, f = 1.0;
  for (var o = 0; o < 3; o++) {
    sum += amp * _noise(x * f, y * f, seed + o * 31);
    norm += amp;
    amp *= 0.5;
    f *= 2.03;
  }
  return sum / norm;
}
