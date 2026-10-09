// lib/widgets/wilderness/wild_map.dart
//
// THE WILD AS GRAINS. The wilderness map: each realm one simple shape made
// of grains on a faint circle of sand — snow-capped mountains for the
// Valley, a cloud for the Sky, a volcano for the Volcano, a swamp tree on
// brown ground for the Swamp — and a purple circle in the middle for
// Arcane, ringed by a fine violet line. A finger drawn through them stirs
// them like sand in water, and they settle back. A realm (or Arcane) with
// something waiting in it has a fine green rim that pulses.
//
// A realm takes its shape only while something waits in it. Until then its
// grains are loose dust scattered over its circle, drifting round in a few
// layers that turn against each other; when something arrives they gather
// into the shape, and when it is gone they come apart again.
//
// The state of each realm is shown, not announced: the Sky's cloud dark and
// flickering with lightning in a storm; rain on the Valley's mountains, a
// snowcap on them in snow and a rainbow behind them when rain has left one;
// the Volcano quiet, smoking or erupting, as the next visit will find it;
// the Swamp's tree gone dry; meteors streaking across Arcane's disc in a
// shower, curtains of northern lights hung in it.
//
// There are always four circles, and which realms fill them is the day's
// pick ([WildMapField.slots]): the first four until a realm is bought in the
// shop, then any four of those owned. A realm out today takes the circle it
// is given and is drawn there as it would be anywhere; one not out is not on
// the map at all. The Glass Dunes (bought): two crescent dunes, sand
// streaming off their crests, glass glinting in them; in a sandstorm dust
// drives across its circle and the dunes go hazy; after one, the sand
// glitters with glass. Geode Hollow (bought): a cluster of amethyst and
// quartz points on a rock, their tips glowing faintly, a shaft of light
// falling on them; in a frostfall ice drifts down across it, and after one
// the crystals are rimed white and glittering; while they sing, waves of
// light roll up through the points one after another. The Tidal Shelf
// (bought): a low sun on the ocean, a path of light glittering on the water
// toward you, the sea a little higher with the real tide; fog turns the sun
// to a pale disc, a swell breaks the path up into whitecaps, and after a
// swell shells and a glass float lie on the sand.
//
// Cheap at rest: grains that hold still are drawn once into a picture and
// that picture drawn again each frame; the cloud's bob, the tree's sway,
// Arcane's turn and each layer of a realm's dust drifting round are one move
// of their picture rather than a move of every grain. A finger through the
// field, or a realm gathering, turns it back into live grains until they
// settle. No blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:flutter/painting.dart';

const double _tau = math.pi * 2;

/// The realms: the scene each one opens, and for the first four the
/// circle each fills by default, which is also where that circle sits (as
/// shares of the map's width and height): the map's four circles in order,
/// top left, top right, bottom left, bottom right. A realm [bought] in the
/// shop is on the map only on the days it is one of the four
/// ([WildMapField.slots]); its x and y are not used.
enum WildRealm {
  valley('valley', 0.25, 0.25),
  sky('sky', 0.75, 0.25),
  volcano('volcano', 0.25, 0.75),
  swamp('swamp', 0.75, 0.75),
  dunes('dunes', 0.5, 1, bought: true),
  geode('geode', 0.5, 1, bought: true),
  tidal('tidal', 0.5, 1, bought: true);

  const WildRealm(this.sceneId, this.x, this.y, {this.bought = false});

  final String sceneId;
  final double x, y;

  /// Sold in the shop.
  final bool bought;
}

/// How many realms there are ([WildRealm.values]); the first four come
/// first.
const int _nRealms = 7;
const int _core = 4;

/// Arcane's index wherever it stands beside the realms (its grains' realm,
/// its readiness).
const int _arcI = _nRealms;

/// The four circles' realms until one is bought: the first four, each in
/// its own.
const kWildCoreSlots = ['valley', 'sky', 'volcano', 'swamp'];

/// The Volcano's mood, as the next visit will find it.
enum WildVolcano { still, smoking, erupting }

// The parts the map is made of. A grain remembers its part: it decides its
// color, how it moves and what the weather does to it.
const int _rock = 0, _farRock = 1, _meadow = 2; // Valley
const int _cloud = 3; // Sky
// Volcano: the cone, the lava down its right face (glowing whenever it is
// warm) and down its left (only in eruption), and the crater.
const int _cone = 4, _lava = 5, _crater = 6, _lava2 = 17;
const int _ground = 7, _pool = 8, _trunk = 9, _canopy = 10, _moss = 11;
const int _sand = 12, _rim = 13; // each realm's circle
const int _arcRing = 14, _arcFill = 15; // Arcane
// The Dunes: the near dune, the far one behind it, the sand floor under
// them.
const int _dune = 18, _duneFar = 19, _duneFloor = 20;
// Geode Hollow: its amethyst points, its pale quartz ones, the rock under
// them.
const int _amethyst = 21, _quartz = 22, _geoRock = 23;
// The Tidal Shelf: its sun, the sea, the sand at its foot.
const int _sun = 24, _sea = 26;
const int _tideSand = 28;
// Past each circle (and Arcane's): a few of its grains drifting in the
// dark, its light spilling out.
const int _spill = 30;

/// Where the Tidal Shelf's horizon stands at a [tide] (0 low water, 1
/// high), in its unit square: a little higher at high water.
double _seaAt(double tide) => 0.5 - 0.05 * tide;

/// The sun: how far its middle sits above the horizon, and its radius.
const double _sunUp = 0.045, _sunR = 0.165;

/// Half the width of the sun's path on the water at [v], below horizon
/// [h]: narrow under the sun, widening toward the viewer.
double _pathHalf(double h, double v) => 0.06 + (v - h) * 0.55;

// Groups, in the order they draw. Each is one picture at rest, and only
// the ones a finger reaches go back to live grains.
// One per realm, then Arcane's: its grains past its circle, turning slowly
// round it, under everything.
const int _gSpill = 0;
const int _gSand = _gSpill + _nRealms + 1; // every realm's circle of sand
const int _gStill = _gSand + 1; // one per realm: its grains that never move
const int _gRim = _gStill + _nRealms; // one per realm: live while it pulses
const int _gCloud = _gRim + _nRealms, _gTree = _gCloud + 1;
const int _gLive = _gCloud + 2, _gArcane = _gCloud + 3;
const int _gArcRim = _gCloud + 4; // Arcane's rim, outside its own ring
const int _groups = _gCloud + 5;

/// How many layers a realm's dust drifts round in, each turning its own
/// way at its own pace.
const int _layers = 3;

/// Each layer's turn, radians a second (alternate realms turn the other
/// way).
const _layerTurn = [0.1, -0.075, 0.05];

/// Whether [part] is one of a realm's shape: scattered as dust until
/// something waits in it.
bool _isShape(int part) => (part < _sand || part >= _lava2) && part != _spill;

int _groupOf(int part, int realm) => switch (part) {
  _spill => _gSpill + realm,
  _sand => _gSand,
  _rim => realm < _nRealms ? _gRim + realm : _gArcRim,
  _cloud => _gCloud,
  _canopy || _moss => _gTree,
  _meadow || _lava || _lava2 || _crater => _gLive,
  _arcRing || _arcFill => _gArcane,
  _ => _gStill + realm,
};

/// A circle in a shape's unit square: centre and radius.
typedef _Lobe = (double, double, double);

// The Valley's two peaks, each from its foot on the left over its summit to
// its foot on the right (unit square): the near one, and the far one behind
// it to the right.
const _nearPeak = <(double, double)>[
  (0.06, 0.885),
  (0.13, 0.74),
  (0.19, 0.63),
  (0.24, 0.55),
  (0.28, 0.49),
  (0.32, 0.4),
  (0.36, 0.31),
  (0.4, 0.21),
  (0.44, 0.12),
  (0.47, 0.155),
  (0.5, 0.2),
  (0.54, 0.25),
  (0.57, 0.27),
  (0.61, 0.35),
  (0.66, 0.45),
  (0.72, 0.57),
  (0.79, 0.69),
  (0.86, 0.8),
  (0.9, 0.885),
];
const _farPeak = <(double, double)>[
  (0.42, 0.885),
  (0.5, 0.58),
  (0.57, 0.44),
  (0.62, 0.36),
  (0.66, 0.31),
  (0.71, 0.24),
  (0.74, 0.265),
  (0.78, 0.31),
  (0.82, 0.37),
  (0.86, 0.46),
  (0.9, 0.58),
  (0.93, 0.7),
  (0.955, 0.885),
];

/// A peak: its summit, the spine its lit and shaded faces meet along
/// (leaning [lean] in u for each unit down), a lesser spine down off a
/// shoulder on each side (where it starts, and its lean), how far down its
/// snowcap comes in snow, and where its forest starts.
typedef _Peak = ({
  double u,
  double v,
  double lean,
  (double, double, double) left,
  (double, double, double) right,
  double cap,
  double trees,
});

const _Peak _near = (
  u: 0.44,
  v: 0.12,
  lean: 0.11,
  left: (0.3, 0.43, 0.06),
  right: (0.57, 0.27, 0.2),
  cap: 0.27,
  trees: 0.68,
);
const _Peak _far = (
  u: 0.71,
  v: 0.24,
  lean: 0.07,
  left: (0.6, 0.38, 0.05),
  right: (0.82, 0.37, 0.14),
  cap: 0.19,
  trees: 0.7,
);

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

/// A crescent dune, seen side on with the wind from the left (unit
/// square): where its windward back leaves the ground, its crest, where its
/// slipface comes down, the tip of the horn running out low along the
/// ground beyond, and the ground.
typedef _Dune = ({
  double u0,
  double uc,
  double vc,
  double us,
  double ut,
  double g,
});

// The far dune is the big one, on the left; the near one smaller, in
// front of its slipface, so a lit back stands against shade.
const _Dune _nearDune = (
  u0: 0.3,
  uc: 0.76,
  vc: 0.57,
  us: 0.9,
  ut: 0.99,
  g: 0.875,
);
const _Dune _farDune = (u0: 0.03, uc: 0.5, vc: 0.35, us: 0.72, ut: 0.9, g: 0.8);

/// How high the horn stands where the slipface comes down to it.
const double _hornH = 0.035;

/// The top of dune [d] at [u]: its back rising to the crest, nearly
/// straight, a little full near the top; its slipface falling steeply from
/// the sharp crest and easing out at its foot; the horn running out.
double _duneTop(_Dune d, double u) {
  if (u <= d.uc) {
    final t = _clamp01((u - d.u0) / (d.uc - d.u0));
    final h = 0.5 * t + 0.5 * (1 - (1 - t) * (1 - t));
    return d.g - (d.g - d.vc) * h;
  }
  final foot = d.g - _hornH;
  if (u <= d.us) {
    final s = (u - d.uc) / (d.us - d.uc);
    return d.vc + (foot - d.vc) * (1 - math.pow(1 - s, 1.7).toDouble());
  }
  final s = _clamp01((u - d.us) / (d.ut - d.us));
  return d.g - _hornH * math.pow(1 - s, 1.4).toDouble();
}

/// Whether (u, v) on dune [d] is on its slipface, in shade: a crescent from
/// the crest round to the horn's tip, the lit back wrapping in below it.
bool _duneSlip(_Dune d, double u, double v) {
  final foot = d.g - _hornH;
  if (v <= d.vc || v >= foot) return false;
  final s = (v - d.vc) / (foot - d.vc);
  return u > _duneBrink(d, s);
}

/// Where the slipface's crescent begins at [s] of the way from the crest
/// down to its foot: bowing back under the crest, sweeping out to meet the
/// foot.
double _duneBrink(_Dune d, double s) =>
    d.uc +
    (d.us - d.uc) * math.pow(s, 2.6).toDouble() -
    0.045 * math.sin(math.pi * s);

/// A crystal point of the Geode (unit square): where its foot is, how far
/// it leans from upright (radians, + to the right), how wide and how long
/// it is, and whether it is pale quartz rather than amethyst. Back to
/// front.
typedef _Xtal = (double, double, double, double, double, bool);

// Lopsided on purpose: a fan of even points reads as a crown.
const _xtals = <_Xtal>[
  (0.28, 0.85, -0.78, 0.07, 0.2, true),
  (0.71, 0.84, 0.6, 0.085, 0.31, true),
  (0.38, 0.83, -0.3, 0.135, 0.5, false),
  (0.64, 0.84, 0.44, 0.11, 0.33, false),
  (0.52, 0.85, 0.06, 0.17, 0.66, false),
  (0.43, 0.87, -0.98, 0.06, 0.15, false),
];

/// How far up crystal [x] (0 foot, 1 tip) and how far across (-1 its left
/// edge, 1 its right) (u, v) is, or null if outside it.
(double, double)? _inXtal(_Xtal x, double u, double v) {
  final (bu, bv, t, w, len, _) = x;
  final du = u - bu, dv = v - bv;
  final st = math.sin(t), ct = math.cos(t);
  final a = du * st - dv * ct, p = du * ct + dv * st;
  if (a < -0.08 * len || a > len) return null;
  final half = a < 0.72 * len ? w / 2 : w / 2 * (len - a) / (0.28 * len);
  if (p.abs() > half || half <= 0) return null;
  return (a / len, p / (w / 2));
}

/// A grain as it is built: where it rests in its realm's shape, and (a
/// shape's grain) where in the dust it rests until the shape is called, and
/// the layer of dust it drifts in.
class _Seed {
  _Seed(
    this.x,
    this.y,
    this.size,
    this.col,
    this.alt,
    this.part,
    this.realm,
    this.v, {
    double? sx,
    double? sy,
    this.layer = 0,
  }) : sx = sx ?? x,
       sy = sy ?? y;
  final double x, y, size, v, sx, sy;
  final int col, alt, part, realm, layer;
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

  /// How the Volcano's next visit will find it.
  WildVolcano volcano = WildVolcano.still;

  /// Whether the Valley's next clear visit finds the rainbow its rain left.
  bool rainbow = false;

  /// The realm in each of the map's four circles, by scene id: top left,
  /// top right, bottom left, bottom right. A realm in none of them is not
  /// on the map; an id that is no realm here leaves its circle empty. Read
  /// at [layout].
  List<String> slots = kWildCoreSlots;

  /// Whether the Dunes' next clear visit finds the glass a sandstorm left:
  /// the sand glitters with it.
  bool glass = false;

  /// Whether Geode Hollow's next clear visit finds the rime a frostfall
  /// left: the cave frosted white.
  bool rime = false;

  /// The tide on the Tidal Shelf (0 low water, 1 high), as the real clock
  /// has it: its sea a little higher at high water. Read at [layout].
  double tide = 0.5;

  /// Whether the Tidal Shelf's next clear visit finds the shells and glass
  /// floats a swell left on its sand.
  bool shells = false;

  /// Drawn in ink on a light page instead of light on the dark: light
  /// adding up shows nothing on parchment.
  bool ink = false;

  // ── Layout ────────────────────────────────────────────────────────────

  /// Each realm's circle (centre, and [_ringR] its radius) and the square
  /// its shape is drawn in.
  final List<Offset> _centre = List.filled(_nRealms, Offset.zero);
  final List<Rect> _box = List.filled(_nRealms, Rect.zero);
  double _ringR = 1, _side = 1, _circleR = 1;

  /// Which realms are on the map: those in [slots].
  final List<bool> _shown = List.generate(
    _nRealms,
    (i) => !WildRealm.values[i].bought,
  );

  /// The slots the field was laid out for.
  String? _laidSlots;

  /// Where each of the four circles sits.
  final List<Offset> _slotAt = List.filled(4, Offset.zero);

  /// Whether realm [r] is on the map.
  bool shows(WildRealm r) => _shown[r.index];

  /// The width the map is drawn to: the screen's on a phone; on a wider one
  /// what its circles would have on a phone. Grains, lights and weather are
  /// all sized from it.
  double _unit = 1;

  /// The biggest a realm's circle grows, on a tablet.
  static const double _maxRing = 130;

  /// Where Arcane's circle sits: the middle of the map, between the four.
  Offset _mid = Offset.zero;

  /// Where a realm's circle sits (nowhere useful for one not on the map).
  Rect circleOf(WildRealm r) =>
      Rect.fromCircle(center: _centre[r.index], radius: _ringR);

  /// Under a realm's circle.
  Offset labelAnchor(WildRealm r) => _centre[r.index] + Offset(0, _ringR + 2);

  /// How far out Arcane's green rim sits, in its circle's radius: clear of
  /// its own violet line.
  static const double _arcRimAt = 1.1;

  /// Where Arcane's circle sits.
  Rect get riftRect => Rect.fromCircle(center: _mid, radius: _circleR);

  /// A point in realm [i]'s square from unit coordinates.
  Offset _at(int i, double u, double v) {
    final b = _box[i];
    return Offset(b.left + u * _side, b.top + v * _side);
  }

  /// Lays the field out for [size] and the realms in [slots]. Grains are
  /// rebuilt only when either changes.
  void layout(Size size) {
    assert(WildRealm.values.length == _nRealms);
    // (The tide is in the key only while the Tidal Shelf is out, in steps,
    // so the map is laid out again only when it has moved.)
    final key = slots.contains('tidal')
        ? '${slots.join(',')}|${(tide.clamp(0.0, 1.0) * 20).round()}'
        : slots.join(',');
    if (size.isEmpty || (size == _size && key == _laidSlots)) return;
    _size = size;
    _laidSlots = key;
    _ringR = math.min(
      _maxRing,
      math.min(size.width * 0.24, size.height * 0.215),
    );
    _side = _ringR * 1.42;
    // Everything is sized from the circles, as on the phone it was made
    // for: on a wider screen the four keep together in the middle, and a
    // grain stays as fine against its realm, never blown up with the
    // screen.
    _unit = _ringR / 0.24;
    _mid = Offset(size.width / 2, size.height / 2);
    final spanX = _unit, spanY = math.min(size.height, _unit * 1.7);
    // The four circles, where the first four realms sit by default; each
    // realm out today in the one it is given.
    _shown.fillRange(0, _nRealms, false);
    for (var k = 0; k < 4; k++) {
      final home = WildRealm.values[k];
      _slotAt[k] = Offset(
        size.width / 2 + (home.x - 0.5) * spanX,
        size.height / 2 + (home.y - 0.5) * spanY,
      );
      if (k >= slots.length) continue;
      final r = WildRealm.values
          .where((r) => r.sceneId == slots[k])
          .firstOrNull;
      if (r == null || _shown[r.index]) continue;
      _shown[r.index] = true;
      _centre[r.index] = _slotAt[k];
    }
    for (final r in WildRealm.values) {
      if (!_shown[r.index]) continue;
      // (The dunes are low and wide: lifted a little to sit mid-circle.)
      final lift = r == WildRealm.dunes ? 0.07 : 0.02;
      _box[r.index] = Rect.fromCenter(
        center: _centre[r.index] - Offset(0, _side * lift),
        width: _side,
        height: _side,
      );
    }
    // Arcane: a little bigger than a realm's gap would need, and never so
    // big it crowds them.
    final reach = (_slotAt[0] - _mid).distance;
    _circleR = math.min(
      _unit * 0.135,
      math.max(_unit * 0.06, (reach - _ringR) * 0.88),
    );
    final rng = math.Random(_seed);
    _buildShapes();
    _buildCloudMask();
    _buildGrains(rng);
    _buildMovers(rng);
    _buildWashes(rng);
    _buildRainbow(rng);
    _buildGlints();
    _buildGeode();
    _buildTidal();
    _fieldW = (size.width / _cell).ceil() + 1;
    _fieldH = (size.height / _cell).ceil() + 1;
    _fu = Float32List(_fieldW * _fieldH);
    _fv = Float32List(_fieldW * _fieldH);
    _ft = Float32List(_fieldW * _fieldH);
    _fieldOn = false;
    _dropPictures();
    _turnLayers();
    final cull = Rect.fromLTRB(
      -size.width,
      -size.height,
      size.width * 2,
      size.height * 2,
    );
    for (final b in [
      _dots,
      _wash,
      _glow,
      _litGlow,
      _swayGlow,
      ..._rest,
      ..._liveB,
    ]) {
      b.cull = cull;
    }
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
    for (var i = 0; i < _nRealms; i++) {
      if (!_shown[i]) continue;
      if ((p - _centre[i]).distance < _ringR * 1.04) {
        return WildRealm.values[i].sceneId;
      }
    }
    if (arcane && (p - _mid).distance < _circleR * 1.08) return 'arcane';
    return null;
  }

  // ── Shapes ────────────────────────────────────────────────────────────

  // Each realm's parts, front-most last, as paths in its square.
  final List<List<(Path, int)>> _parts = List.generate(_nRealms, (_) => []);

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

    // The Valley: two peaks, the far one behind, their feet in a mound of
    // meadow that rolls a little along its top and thins to nothing at its
    // ends.
    final v = WildRealm.valley.index;
    final meadow = Path();
    for (var k = 0; k <= 32; k++) {
      final u = 0.03 + 0.94 * k / 32;
      final e = math.sqrt(math.max(0, 1 - math.pow((u - 0.5) / 0.47, 2)));
      final o = _at(v, u, 0.89 - e * (0.07 + 0.012 * math.sin(u * 15 + 0.6)));
      k == 0 ? meadow.moveTo(o.dx, o.dy) : meadow.lineTo(o.dx, o.dy);
    }
    for (var k = 32; k >= 0; k--) {
      final u = 0.03 + 0.94 * k / 32;
      final e = math.sqrt(math.max(0, 1 - math.pow((u - 0.5) / 0.47, 2)));
      final o = _at(v, u, 0.89 + e * 0.035);
      meadow.lineTo(o.dx, o.dy);
    }
    meadow.close();
    _parts[v]
      ..clear()
      ..add((poly(v, _farPeak), _farRock))
      ..add((poly(v, _nearPeak), _rock))
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

    // The Dunes (when out): two crescent dunes, the far one behind to the
    // right, on a low floor of sand.
    final d = WildRealm.dunes.index;
    _parts[d].clear();
    if (_shown[d]) {
      Path dune(_Dune dn) {
        final p = Path();
        const steps = 48;
        for (var k = 0; k <= steps; k++) {
          final u = dn.u0 + (dn.ut - dn.u0) * k / steps;
          final o = _at(d, u, _duneTop(dn, u));
          k == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        // Underneath, down into the floor so the two meet.
        final a = _at(d, dn.ut, dn.g + 0.02), b = _at(d, dn.u0, 0.9);
        return p
          ..lineTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..close();
      }

      final floor = Path();
      for (var k = 0; k <= 32; k++) {
        final u = 0.02 + 0.96 * k / 32;
        final e = math.sqrt(math.max(0, 1 - math.pow((u - 0.5) / 0.48, 2)));
        final o = _at(d, u, 0.885 - e * (0.04 + 0.01 * math.sin(u * 13 + 1)));
        k == 0 ? floor.moveTo(o.dx, o.dy) : floor.lineTo(o.dx, o.dy);
      }
      for (var k = 32; k >= 0; k--) {
        final u = 0.02 + 0.96 * k / 32;
        final e = math.sqrt(math.max(0, 1 - math.pow((u - 0.5) / 0.48, 2)));
        final o = _at(d, u, 0.885 + e * 0.04);
        floor.lineTo(o.dx, o.dy);
      }
      floor.close();
      _parts[d]
        ..add((floor, _duneFloor))
        ..add((dune(_farDune), _duneFar))
        ..add((dune(_nearDune), _dune));
    }
    // Geode Hollow (when out): its crystal points rising out of a rock.
    final g = WildRealm.geode.index;
    _parts[g].clear();
    if (_shown[g]) {
      for (final x in _xtals) {
        final (bu, bv, t, w, len, pale) = x;
        final st = math.sin(t), ct = math.cos(t);
        Offset at(double p, double a) =>
            _at(g, bu + p * ct + a * st, bv + p * st - a * ct);
        final pts = [
          at(-w / 2, -0.08 * len),
          at(-w / 2, 0.72 * len),
          at(0, len),
          at(w / 2, 0.72 * len),
          at(w / 2, -0.08 * len),
        ];
        final path = Path()..moveTo(pts[0].dx, pts[0].dy);
        for (final o in pts.skip(1)) {
          path.lineTo(o.dx, o.dy);
        }
        _parts[g].add((path..close(), pale ? _quartz : _amethyst));
      }
      // The rock: a lumpy mound over their feet.
      final rock = Path();
      for (var k = 0; k <= 28; k++) {
        final u = 0.16 + 0.68 * k / 28;
        final e = math.sqrt(math.max(0, 1 - math.pow((u - 0.5) / 0.34, 2)));
        final o = _at(
          g,
          u,
          0.875 - e * (0.07 + 0.018 * math.sin(u * 23 + 0.4)),
        );
        k == 0 ? rock.moveTo(o.dx, o.dy) : rock.lineTo(o.dx, o.dy);
      }
      for (var k = 28; k >= 0; k--) {
        final u = 0.16 + 0.68 * k / 28;
        final e = math.sqrt(math.max(0, 1 - math.pow((u - 0.5) / 0.34, 2)));
        final o = _at(g, u, 0.875 + e * 0.045);
        rock.lineTo(o.dx, o.dy);
      }
      _parts[g].add((rock..close(), _geoRock));
    }
    // The Tidal Shelf (when out): a low sun sinking into a patch of sea, a
    // spit of sand in front.
    final td = WildRealm.tidal.index;
    _parts[td].clear();
    if (_shown[td]) {
      final level = _seaAt(tide);
      _parts[td].add((
        Path()..addOval(
          Rect.fromCircle(
            center: _at(td, 0.5, level - _sunUp),
            radius: _sunR * _side,
          ),
        ),
        _sun,
      ));
      final sea = Path();
      for (var k = 0; k <= 32; k++) {
        final u = k / 32;
        final o = _at(td, u, level);
        k == 0 ? sea.moveTo(o.dx, o.dy) : sea.lineTo(o.dx, o.dy);
      }
      // Down to the foot of the square: it fades out at its sides and
      // below rather than ending in an edge.
      for (final (u, v) in const [(1.0, 0.97), (0.0, 0.97)]) {
        final o = _at(td, u, v);
        sea.lineTo(o.dx, o.dy);
      }
      _parts[td].add((sea..close(), _sea));
      final sand = Path()
        ..addOval(
          Rect.fromCenter(
            center: _at(td, 0.2, 0.925),
            width: _side * 0.3,
            height: _side * 0.05,
          ),
        );
      _parts[td].add((sand, _tideSand));
    }
    // A realm not out today has no shape on the map.
    for (var i = 0; i < _nRealms; i++) {
      if (!_shown[i]) _parts[i].clear();
    }
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

  // Every grain, in group order: where each rests now, its push from the
  // flow, its color clear and under its realm's weather, its part, its
  // realm (4 = Arcane) and its height in the shape's square. And for a
  // shape's grain: its place in the shape and in the dust (where it rests
  // now is one of the two), its layer of dust, and when it sets off and how
  // far round it swings as its realm gathers.
  int _n = 0;
  late Float32List _hx, _hy, _ox, _oy, _vx, _vy, _size2, _ph, _v;
  late Float32List _fx, _fy, _sx, _sy, _delay, _curl;
  late Float32List _r, _g, _b, _ar, _ag, _ab, _alpha;
  late Uint8List _realm, _part, _layer;
  final List<int> _from = List.filled(_groups, 0);
  final List<int> _to = List.filled(_groups, 0);
  final List<Rect> _reach = List.filled(_groups, Rect.zero);

  void _buildGrains(math.Random rng) {
    final groups = List.generate(_groups, (_) => <_Seed>[]);
    void add(_Seed s) => groups[_groupOf(s.part, s.realm)].add(s);
    final grain = _unit;

    // Each realm's circle of sand: a faint disc, a little thicker at its
    // rim.
    void circle(int i, math.Random rng) {
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

    for (var i = 0; i < _core; i++) {
      if (_shown[i]) circle(i, rng);
    }

    // Where a shape's grain waits while its realm is empty: anywhere in
    // the circle, in loose clumps (each layer its own), thinning toward the
    // rim. Its own dice, so the shapes come out as they always have.
    final dust = math.Random(_seed + 101);
    Offset scatter(int i, int layer, math.Random dust) {
      final c = _centre[i];
      while (true) {
        final r = _ringR * 0.9 * math.sqrt(dust.nextDouble());
        final a = dust.nextDouble() * _tau;
        final x = c.dx + math.cos(a) * r, y = c.dy + math.sin(a) * r;
        final q = 3.2 / _ringR;
        final clump = _fbm(x * q, y * q, 90 + i * 7 + layer);
        final edge = 1 - _smooth(_clamp01((r / _ringR - 0.68) / 0.22));
        final keep =
            (0.12 + 0.88 * _smooth(_clamp01(clump * 2.4 - 0.75))) *
            (0.35 + 0.65 * edge);
        if (dust.nextDouble() < keep) return Offset(x, y);
      }
    }

    // The shapes: about one grain to every 1.8 square px. A grain is
    // tested a little way off its own place, so the edges come out grained,
    // never cut.
    final spacing = math.sqrt(1.8);
    void shape(int i, math.Random rng, math.Random dust) {
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
          final layer = dust.nextInt(_layers);
          final at = scatter(i, layer, dust);
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
              sx: at.dx,
              sy: at.dy,
              layer: layer,
            ),
          );
        }
      }
    }

    for (var i = 0; i < _core; i++) {
      if (_shown[i]) shape(i, rng, dust);
    }
    // A bought realm throws its own dice: the others come out as they
    // always have whether it is out or not.
    for (var i = _core; i < _nRealms; i++) {
      if (!_shown[i]) continue;
      final own = math.Random(_seed + 300 + i);
      circle(i, own);
      shape(i, own, math.Random(_seed + 400 + i));
    }

    // Arcane: a fine violet line round it, as fine as a realm's green
    // rim, and faint dust filling its disc; outside the line, the green rim
    // it takes while something waits in it.
    void arc(
      int part,
      int count,
      double Function() radius,
      double Function() size,
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
            size(),
            argb,
            argb,
            part,
            _arcI,
            r,
          ),
        );
      }
    }

    arc(
      _arcRing,
      (_tau * _circleR / 0.7).round(),
      () => 1 - 0.022 * rng.nextDouble(),
      () => grain * (0.0022 + 0.001 * rng.nextDouble()),
      (r) => _argb(0.46 + 0.14 * rng.nextDouble(), 0.74, 0.58, 1),
    );
    arc(
      _arcFill,
      2300,
      () => math.sqrt(rng.nextDouble()) * 0.97,
      () => grain * 0.0026,
      (r) => _argb(0.34 + 0.2 * r, 0.54, 0.36, 0.9),
    );
    arc(
      _rim,
      (_tau * _circleR * _arcRimAt / 0.8).round(),
      () => _arcRimAt * (1 - 0.018 * rng.nextDouble()),
      () => grain * (0.002 + 0.001 * rng.nextDouble()),
      (r) =>
          ((((0.7 + 0.3 * rng.nextDouble()) * 255).round()) << 24) |
          (_mix(0xFF5ED07A, 0xFFA6F0B0, rng.nextDouble()) & 0xFFFFFF),
    );

    // Past each circle, a few of its realm's grains in the dark, thinning
    // as they go: its light spilling out. Arcane's too. Their own dice, so
    // everything else comes out as it always has.
    void spill(
      int i,
      Offset c,
      double from,
      double reach,
      int count,
      List<int> colors,
      double bright,
      math.Random dice,
    ) {
      for (var k = 0; k < count; k++) {
        final q = math.pow(dice.nextDouble(), 1.8).toDouble();
        final r = from + reach * q;
        final a = dice.nextDouble() * _tau;
        final col = colors[dice.nextInt(colors.length)];
        final al = (0.22 + bright * dice.nextDouble()) * (1 - _smooth(q));
        final argb = (_byte(al) << 24) | (col & 0xFFFFFF);
        add(
          _Seed(
            c.dx + math.cos(a) * r,
            c.dy + math.sin(a) * r,
            grain * (0.0021 + 0.0013 * dice.nextDouble()),
            argb,
            argb,
            _spill,
            i,
            q,
          ),
        );
      }
    }

    for (var i = 0; i < _nRealms; i++) {
      if (!_shown[i]) continue;
      spill(
        i,
        _centre[i],
        _ringR * 1.14,
        _ringR * 1.15,
        850,
        _spillGrains[i],
        0.5,
        math.Random(_seed + 600 + i),
      );
    }
    spill(
      _arcI,
      _mid,
      _circleR * 1.15,
      _circleR * 1.4,
      420,
      const [0xFFA080F0, 0xFF8C70E0],
      0.45,
      math.Random(_seed + 700),
    );

    final all = <_Seed>[];
    final chunkFrom = <int>[], chunkLayer = <int>[];
    for (var g = 0; g < _groups; g++) {
      _from[g] = all.length;
      _chunk0[g] = chunkFrom.length;
      if (_chunked(g)) {
        // Into chunks, each a square of the map, so a stir redraws only
        // the ones it pushed. Arcane's ring stays under what was drawn over
        // it, and each layer of dust keeps together so it can turn as one;
        // within a chunk grains keep their order.
        final seeds = groups[g];
        final side = _isSpill(g) ? _spillChunkSide : _chunkSide;
        int keyOf(_Seed s) {
          final under = s.part == _arcRing ? 0 : 1;
          final cx = (s.x / side).floor().clamp(0, 255);
          final cy = (s.y / side).floor().clamp(0, 255);
          return (under << 20) | (s.layer << 16) | (cy << 8) | cx;
        }

        final keys = [for (final s in seeds) keyOf(s)];
        final order = List.generate(seeds.length, (i) => i)
          ..sort((a, b) {
            final d = keys[a] - keys[b];
            return d != 0 ? d : a - b;
          });
        var last = -1;
        for (final i in order) {
          if (keys[i] != last) {
            chunkFrom.add(all.length);
            chunkLayer.add(seeds[i].layer);
            last = keys[i];
          }
          all.add(seeds[i]);
        }
      } else {
        // A rim pulses whole, so it is one chunk, never a picture.
        if (_isRim(g) && groups[g].isNotEmpty) {
          chunkFrom.add(all.length);
          chunkLayer.add(0);
        }
        all.addAll(groups[g]);
      }
      _chunk1[g] = chunkFrom.length;
      _to[g] = all.length;
      var l = double.infinity, t = double.infinity;
      var r = -double.infinity, b = -double.infinity;
      for (final s in groups[g]) {
        // A shape's grain drifts anywhere in its circle as dust.
        final box = _isShape(s.part) && s.realm < _nRealms
            ? circleOf(WildRealm.values[s.realm])
            : Rect.fromLTRB(s.x, s.y, s.x, s.y);
        if (box.left < l) l = box.left;
        if (box.right > r) r = box.right;
        if (box.top < t) t = box.top;
        if (box.bottom > b) b = box.bottom;
      }
      // Wide enough for its own motion; the movers and lava are always
      // live anyway.
      _reach[g] = groups[g].isEmpty
          ? Rect.zero
          : Rect.fromLTRB(l, t, r, b).inflate(8);
    }
    _n = all.length;
    final nc = chunkFrom.length;
    _chunkFrom = Int32List(nc)..setAll(0, chunkFrom);
    // Each ends where the next of its group begins, or where its group
    // does: groups not cut into chunks lie between.
    _chunkTo = Int32List(nc);
    for (var g = 0; g < _groups; g++) {
      for (var c = _chunk0[g]; c < _chunk1[g]; c++) {
        _chunkTo[c] = c + 1 < _chunk1[g] ? chunkFrom[c + 1] : _to[g];
      }
    }
    _chunkS0 = Int32List(nc);
    _chunkS1 = Int32List(nc);
    _chunkBusy = Uint8List(nc);
    _chunkLayer = Uint8List.fromList(chunkLayer);
    for (final p in _chunkPics) {
      p?.dispose();
    }
    _chunkPics = List.filled(nc, null);
    _hx = Float32List(_n);
    _hy = Float32List(_n);
    _fx = Float32List(_n);
    _fy = Float32List(_n);
    _sx = Float32List(_n);
    _sy = Float32List(_n);
    _layer = Uint8List(_n);
    _delay = Float32List(_n);
    _curl = Float32List(_n);
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
    final spillDice = math.Random(_seed + 800);
    for (var k = 0; k < _n; k++) {
      final s = all[k];
      _fx[k] = s.x;
      _fy[k] = s.y;
      _sx[k] = s.sx;
      _sy[k] = s.sy;
      _layer[k] = s.layer;
      // Rests as its realm last rested: in its shape or in the dust.
      final shaped = s.realm >= _nRealms || _formed[s.realm] == 1;
      _hx[k] = shaped ? s.x : s.sx;
      _hy[k] = shaped ? s.y : s.sy;
      _size2[k] = s.size;
      _v[k] = s.v;
      _realm[k] = s.realm;
      _part[k] = s.part;
      final c = s.col, a = s.alt;
      _alpha[k] = ((c >> 24) & 0xFF) / 255;
      _r[k] = ((c >> 16) & 0xFF) / 255;
      _g[k] = ((c >> 8) & 0xFF) / 255;
      _b[k] = (c & 0xFF) / 255;
      _ar[k] = ((a >> 16) & 0xFF) / 255;
      _ag[k] = ((a >> 8) & 0xFF) / 255;
      _ab[k] = (a & 0xFF) / 255;
      if (s.part == _spill) {
        // Spilled grains never gather, and throw their own dice: the rest
        // come out as they always have.
        _ph[k] = spillDice.nextDouble() * _tau;
        continue;
      }
      // When it sets off as the realm gathers, and how far round it swings
      // on the way: the way its layer was turning.
      _delay[k] = dust.nextDouble() * _stagger;
      final way = s.realm < _nRealms ? _turnWay(s.realm, s.layer) : 1.0;
      _curl[k] = way * (0.12 + 0.26 * dust.nextDouble());
      _ph[k] = rng.nextDouble() * _tau;
    }
    // Where each is drawn: at rest until the field first steps, so a frame
    // painted straight after layout has every grain in place.
    _px = Float32List.fromList(_hx);
    _py = Float32List.fromList(_hy);
    _watched = null;
    _moved.fillRange(0, _groups, false);
    // The tile each rests in, for asking whether the flow reaches it.
    _tw = (_size.width / _tileSide).ceil() + 1;
    _th = (_size.height / _tileSide).ceil() + 1;
    _tileFlow = Uint8List(_tw * _th);
    _tile = Int32List(_n);
    for (var k = 0; k < _n; k++) {
      _tile[k] = _tileAt(_hx[k], _hy[k]);
    }
    _busy = Uint8List(_n);
    _slot = Int32List(_n)..fillRange(0, _n, -1);
  }

  // ── Which grains the flow reaches ─────────────────────────────────────

  // Tiles two flow cells wide. A grain does any work only while its tile
  // has flow in it or it is still pushed off its place; the rest of a
  // stirred group stays as it was drawn at rest.
  static const double _tileSide = _cell * 2;
  int _tw = 0, _th = 0;
  Uint8List _tileFlow = Uint8List(0);
  Int32List _tile = Int32List(0);
  // Each grain: still pushed off its place (or moving).
  Uint8List _busy = Uint8List(0);
  // Each grain's place in its group's batch at rest, or -1 if not in it.
  Int32List _slot = Int32List(0);

  // The groups that only ever move whole are cut into chunks: squares of
  // the map, each one picture at rest. While a finger stirs the group,
  // only the chunks with a grain off its place are drawn grain by grain.
  static const double _chunkSide = 40;
  // (Spilled grains lie thin over a wide ring: bigger squares, so a stir
  // anywhere near draws few pictures of them.)
  static const double _spillChunkSide = 100;
  static bool _chunked(int g) =>
      g < _gStill + _nRealms || g == _gCloud || g == _gTree || g == _gArcane;
  final Int32List _chunk0 = Int32List(_groups), _chunk1 = Int32List(_groups);
  // Each chunk's grains (_chunkFrom[c].._chunkTo[c]), its sprites in
  // its group's batch (_chunkS0[c].._chunkS1[c]), whether any grain of it
  // is pushed off its place, its layer of dust, and its picture.
  Int32List _chunkFrom = Int32List(0), _chunkTo = Int32List(0);
  Int32List _chunkS0 = Int32List(0), _chunkS1 = Int32List(0);
  Uint8List _chunkBusy = Uint8List(0), _chunkLayer = Uint8List(0);
  List<ui.Picture?> _chunkPics = const [];

  int _tileAt(double x, double y) {
    final tx = (x / _tileSide).floor().clamp(0, _tw - 1);
    final ty = (y / _tileSide).floor().clamp(0, _th - 1);
    return ty * _tw + tx;
  }

  /// Marks every tile with a grain that could feel the flow: one whose
  /// samples touch a cell moving faster than barely, with a tile to spare
  /// for the cloud's bob and the crown's lean.
  void _markTiles() {
    _tileFlow.fillRange(0, _tileFlow.length, 0);
    _markCells(0, _fieldW - 1, 0, _fieldH - 1);
  }

  void _markCells(int cx0, int cx1, int cy0, int cy1) {
    for (var gy = cy0; gy <= cy1; gy++) {
      for (var gx = cx0; gx <= cx1; gx++) {
        final i = gy * _fieldW + gx;
        if (_fu[i].abs() + _fv[i].abs() <= 3) continue;
        final x0 = math.max(0, ((gx - 1) >> 1) - 1);
        final x1 = math.min(_tw - 1, (gx >> 1) + 1);
        final y0 = math.max(0, ((gy - 1) >> 1) - 1);
        final y1 = math.min(_th - 1, (gy >> 1) + 1);
        for (var ty = y0; ty <= y1; ty++) {
          for (var tx = x0; tx <= x1; tx++) {
            _tileFlow[ty * _tw + tx] = 1;
          }
        }
      }
    }
  }

  /// Whether group [g] is drawn whole, grain by grain: every grain of it
  /// moves or changes color this frame.
  bool _whole(int g) =>
      g == _gLive || (g == _gCloud && _flash > 0) || _travelling(g);

  static bool _isRim(int g) =>
      (g >= _gRim && g < _gRim + _nRealms) || g == _gArcRim;

  static bool _isSpill(int g) => g >= _gSpill && g <= _gSpill + _nRealms;

  /// What spill group [g] turns round: its realm's circle, or Arcane's.
  Offset _spillCentre(int g) =>
      g - _gSpill == _arcI ? _mid : _centre[g - _gSpill];

  /// How far spill group [g] has turned: slowly, alternate realms the
  /// other way, Arcane's the way its disc turns.
  double _spillAngle(int g) {
    final i = g - _gSpill;
    if (i == _arcI) return time * 0.06;
    return time * 0.035 * (i.isEven ? 1 : -1) + i * 0.9;
  }

  /// Where in its pulse realm [i]'s rim (or Arcane's, [_arcI]) is: each
  /// its own.
  static double _pulseAt(int i) =>
      i == _arcI ? 4 * 1.3 : (i < _core ? i * 1.3 : i * 1.3 + 2.1);

  /// How bright rim group [g] is now: as ready as its realm, pulsing.
  double _rimAlpha(int g) {
    final i = g == _gArcRim ? _arcI : g - _gRim;
    final pulse = 0.5 + 0.5 * _fsin(time * 2.4 + _pulseAt(i));
    return _ready[i] * (0.6 + 0.4 * pulse);
  }

  /// A grain's color in [part] at (u, v) of its square, the color its
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
      case _rock || _farRock:
        final far = part == _farRock;
        final pk = far ? _far : _near;
        // Two faces, meeting along a line down from the summit: the one
        // to its left in the light, the one to its right in shade. The far
        // peak is dimmer and bluer, a little lost in the air.
        final drop = v - pk.v;
        final crest = pk.u + drop * pk.lean + 0.012 * math.sin(v * 31);
        final lit = _smooth(_clamp01((crest - u) / 0.025 + 0.5));
        // Each face broken by its lesser spine: the lit face's outer part a
        // step darker, the shaded face's outer part catching a little light
        // back.
        final (lu, lv, ll) = pk.left;
        final (ru, rv, rl) = pk.right;
        final jag = 0.01 * math.sin(v * 27 + u * 9);
        final outerLit = v > lv && u < lu + (v - lv) * ll + jag;
        final outerShade = v > rv && u > ru + (v - rv) * rl + jag;
        final tone = lit * (outerLit ? 0.68 : 1) + (outerShade ? 0.2 : 0);
        final high = _clamp01(1 - drop / 0.7);
        // Gullies running down off the summit.
        final gully = _fbm(
          (u - pk.u) / (drop + 0.06) * 2.2,
          v * 2.5,
          far ? 61 : 60,
        );
        final shade = far
            ? _mix(0xFF1C2030, 0xFF2C3044, high)
            : _mix(0xFF242836, 0xFF3E4256, high);
        final light = far
            ? _mix(0xFF50566C, 0xFF8A90A6, high)
            : _mix(0xFF6A6E80, 0xFFC0C4D0, high);
        var col = _mix(shade, light, tone);
        col = _mix(col, 0xFF1A1E2A, 0.35 * _clamp01(gully * 1.6 - 0.6));
        col = _mix(col, 0xFF22262F, 0.15 * n);
        // Snow lies from the summit down, deeper in the gullies, its edge
        // ragged; below it the rock takes the lightest dusting.
        final cap = pk.cap + 0.08 * gully + (rng.nextDouble() - 0.5) * 0.03;
        final snow = drop < cap
            ? _mix(
                far ? 0xFF7E8AA6 : 0xFF98A6C2,
                far ? 0xFFD0D6E2 : 0xFFF6F8FB,
                lit,
              )
            : _mix(col, 0xFFD6DEEA, 0.06);
        // Forest on the lower slopes, its top edge ragged like treetops.
        // Higher up the gullies, and in crowns.
        final treeline =
            pk.trees +
            0.12 * (_fbm(x * 0.1, 3, 70) - 0.5) -
            0.06 * gully +
            0.012 * math.sin(x * 0.9).abs() +
            (rng.nextDouble() - 0.5) * 0.03;
        if (v > treeline) {
          var tree = _mix(0xFF18301E, 0xFF3A6834, lit * 0.85);
          tree = _mix(tree, 0xFF0E1C12, 0.3 * n);
          if (far) tree = _mix(tree, 0xFF1A2632, 0.35);
          return (tree, _mix(tree, 0xFFD6DEEA, 0.3), part);
        }
        return (col, snow, part);
      case _meadow:
        var col = _mix(0xFF2E5022, 0xFF6E9A3A, _clamp01(n * 1.4 - 0.2));
        if (rng.nextDouble() < 0.07) col = _mix(0xFFC8B45C, 0xFFE8D890, n);
        if (rng.nextDouble() < 0.05) col = 0xFF1C3418;
        return (col, _mix(col, 0xFFDCE6EE, 0.5), _meadow);
      case _cloud:
        // Each puff lit on its upper left, shaded beneath; the whole cloud
        // darker toward its flat base.
        final shade = _lobeShade(_cloudLobes, u, v);
        final base = _smooth(_clamp01((v - 0.52) / 0.22));
        final lit = _clamp01(shade * (1 - 0.6 * base));
        final col = _mix(0xFF8A98BE, 0xFFF6F7FA, lit);
        return (col, _mix(0xFF24283A, 0xFF5E6280, lit), _cloud);
      case _cone:
        final lit = _smooth(_clamp01((0.5 - u) / 0.12 + 0.5));
        var col = _mix(0xFF2A1C1C, 0xFF84645A, lit);
        col = _mix(col, 0xFF120C0C, 0.3 * _clamp01((v - 0.6) / 0.3));
        col = _mix(col, 0xFF2A2224, 0.3 * n);
        // Lava down the right face from the crater: a dark crust while the
        // mountain is quiet, glowing as it wakes.
        if (v > 0.27 && v < 0.84) {
          final lx = 0.53 + 0.035 * math.sin(v * 11) + (v - 0.27) * 0.2;
          final lw = 0.012 + 0.022 * (v - 0.27);
          if ((u - lx).abs() < lw) {
            final hot = 1 - (u - lx).abs() / lw;
            final crust = _mix(0xFF3E1C14, 0xFF6A2C1A, hot);
            return (crust, _mix(0xFFB8401A, 0xFFFF9A3A, hot), _lava);
          }
        }
        // And down the left, only when it erupts: rock until then.
        if (v > 0.28 && v < 0.74) {
          final lx = 0.46 - 0.03 * math.sin(v * 9 + 1) - (v - 0.28) * 0.24;
          final lw = 0.01 + 0.018 * (v - 0.28);
          if ((u - lx).abs() < lw) {
            final hot = 1 - (u - lx).abs() / lw;
            return (col, _mix(0xFFB8401A, 0xFFFF9A3A, hot), _lava2);
          }
        }
        // Lit red from the crater as it wakes.
        final near = _clamp01(1 - ((u - 0.5).abs() + (v - 0.24)) / 0.45);
        return (col, _mix(col, 0xFF7A2E1C, 0.5 * near), _cone);
      case _crater:
        final hot = 1 - (v - 0.21) / 0.07;
        return (
          // Even asleep the crater keeps an ember in it.
          _mix(0xFF6E2814, 0xFFA8461C, hot),
          _mix(0xFFFF7A2A, 0xFFFFD27A, hot),
          _crater,
        );
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
      case _dune || _duneFar:
        final far = part == _duneFar;
        final d = far ? _farDune : _nearDune;
        // How high on the dune, and how far under its surface.
        final high = _clamp01((d.g - v) / (d.g - d.vc));
        final depth = v - _duneTop(d, u);
        int col;
        if (_duneSlip(d, u, v)) {
          // The slipface, in shade: deepest along its brink under the sharp
          // crest, warmer out toward its edge and low down, where light is
          // thrown back into it off the sand.
          final s = (v - d.vc) / (d.g - _hornH - d.vc);
          final into = _clamp01((u - _duneBrink(d, s)) / 0.07);
          col = _mix(0xFF432A18, 0xFF835632, 0.2 + 0.4 * into + 0.35 * s);
        } else {
          // The windward back, lit from the upper left, brightest high up;
          // faint wind ripples across it, the crest's edge catching the
          // light.
          col = _mix(0xFF8A6036, 0xFFE2BA7C, 0.3 + 0.7 * high);
          final ripple = math.sin(
            depth * 70 + u * 6 + 5 * _fbm(x * 0.04, y * 0.04, 81),
          );
          if (ripple > 0.45) col = _mix(col, 0xFF6A4628, 0.3);
          if (depth < 0.018 && u > d.uc - 0.12) {
            col = _mix(col, 0xFFF6E2B4, 0.65 * (1 - depth / 0.018));
          }
        }
        // The far one paler and cooler, a little lost in the air.
        if (far) col = _mix(col, 0xFF8C7470, 0.22);
        col = _mix(col, 0xFF2A1A10, 0.14 * n);
        // In a sandstorm: hazed, the light and shade run together.
        return (col, _mix(col, far ? 0xFF6E5C48 : 0xFF84705A, 0.66), part);
      case _amethyst || _quartz:
        // The crystal it is in (front-most), and where on it.
        var at = (0.5, 0.0);
        for (var k = _xtals.length - 1; k >= 0; k--) {
          final hit = _inXtal(_xtals[k], u, v);
          if (hit != null) {
            at = hit;
            break;
          }
        }
        final (up, across) = at;
        final pale = part == _quartz;
        // Three faces seen: the left one lit, the middle half lit, the
        // right in shade; each darker toward the foot, the point lit.
        final int faceCol;
        if (across < -0.38) {
          faceCol = pale ? 0xFFF4F7FC : 0xFFDABEFA;
        } else if (across < 0.36) {
          faceCol = pale ? 0xFFAEBACE : 0xFF9668D4;
        } else {
          faceCol = pale ? 0xFF5E6A80 : 0xFF46287C;
        }
        final rise = 0.55 + 0.45 * _clamp01(up);
        var col = _mix(pale ? 0xFF3A4252 : 0xFF221238, faceCol, rise);
        // The edge between the lit faces catches the light.
        if ((across + 0.38).abs() < 0.1 && up > 0.15) {
          col = _mix(col, pale ? 0xFFFFFFFF : 0xFFEADCFF, 0.55);
        }
        col = _mix(col, pale ? 0xFF2A3040 : 0xFF1E1030, 0.12 * n);
        // Rimed: frosted white.
        return (col, _mix(col, 0xFFE6EEF8, 0.58), part);
      case _sun:
        // Gold-white in its middle, deeper and redder toward its rim and
        // toward the sea, its rim soft.
        final level = _seaAt(tide);
        final d = _clamp01(
          math.sqrt(math.pow(u - 0.5, 2) + math.pow(v - (level - _sunUp), 2)) /
              _sunR,
        );
        var col = d < 0.55
            ? _mix(0xFFFFF6DC, 0xFFFFD484, d / 0.55)
            : _mix(0xFFFFD484, 0xFFE8783A, (d - 0.55) / 0.45);
        col = _mix(col, 0xFFD24E2A, 0.45 * _clamp01((v - level + 0.12) / 0.12));
        final soft = 1 - 0.65 * _smooth(_clamp01((d - 0.7) / 0.3));
        return (
          (_byte(soft) << 24) | (col & 0xFFFFFF),
          // In a fog: a pale hazy disc.
          _mix(col, 0xFFCDD0D2, 0.78),
          _sun,
        );
      case _sea:
        // Bands of swell across it, lighter toward the horizon, and the
        // sun's path warm on it.
        final level = _seaAt(tide);
        final deep = _clamp01((v - level) / 0.3);
        final band = math.sin(
          (v - level) * 90 + u * 3 + 3 * _fbm(x * 0.05, y * 0.05, 91),
        );
        var col = _mix(0xFF2A6E7E, 0xFF0A2630, deep);
        if (band > 0.5) col = _mix(col, 0xFF4E9CAC, 0.5 * (1 - deep * 0.5));
        if (band < -0.6) col = _mix(col, 0xFF061C24, 0.35);
        final half = _pathHalf(level, v);
        final inPath = 1 - _clamp01((u - 0.5).abs() / half);
        if (inPath > 0) {
          col = _mix(
            col,
            0xFFF0BC74,
            0.62 * _smooth(inPath) * (1 - 0.55 * _clamp01((v - level) / 0.45)),
          );
        }
        col = _mix(col, 0xFF061820, 0.12 * n);
        // Thinning out to its sides and below.
        final side = _clamp01(math.min(u, 1 - u) / 0.2);
        final below = _clamp01((0.97 - v) / 0.14);
        final fade = _smooth(side) * _smooth(below);
        return (
          (_byte(fade) << 24) | (col & 0xFFFFFF),
          _mix(col, 0xFF7A868E, 0.62),
          _sea,
        );
      case _tideSand:
        final col = _mix(0xFF5E5040, 0xFFA48C6A, _clamp01(n * 1.3 - 0.1));
        return (col, _mix(col, 0xFF8A8C88, 0.55), _tideSand);
      case _geoRock:
        final lit = _clamp01((0.88 - v) / 0.1) * 0.7 + (1 - u) * 0.3;
        var col = _mix(0xFF2A2630, 0xFF7E7688, _clamp01(lit));
        col = _mix(col, 0xFF141016, 0.3 * n);
        // A few violet chips in it.
        if (rng.nextDouble() < 0.05) col = _mix(col, 0xFF8A62C0, 0.6);
        return (col, _mix(col, 0xFFC2CAD6, 0.62), _geoRock);
      case _duneFloor:
        // Lit toward its top, where it meets the dunes; ribbed by the wind.
        final top = _clamp01((0.9 - v) / 0.05);
        var col = _mix(0xFF4A3420, 0xFF9C7A4C, 0.25 + 0.45 * top + 0.3 * n);
        if (math.sin(y * 0.9 + 4 * _fbm(x * 0.05, y * 0.05, 83)) > 0.6) {
          col = _mix(col, 0xFF3A2818, 0.25);
        }
        return (col, _mix(col, 0xFF7A6650, 0.6), _duneFloor);
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
    for (var i = 0; i < _nRealms; i++) {
      if (!_shown[i]) continue;
      // A bought realm's own dice, as for its grains.
      final dice = i < _core ? rng : math.Random(_seed + 500 + i);
      var placed = 0, tries = 0;
      while (placed < 9 && tries++ < 400) {
        final b = _box[i];
        final p = Offset(
          b.left + dice.nextDouble() * _side,
          b.top + dice.nextDouble() * _side,
        );
        if (_partAt(i, p) < 0) continue;
        _washes.add((p.dx, p.dy, _side * (0.16 + 0.12 * dice.nextDouble()), i));
        placed++;
      }
    }
  }

  // Each realm's light: clear, and under its weather.
  static const _washClear = [
    0xFF6E7A9C,
    0xFFB8C8E0,
    0xFF6A2A16,
    0xFF2E5034,
    0xFF9A6A34,
    0xFF6A3E9A,
    0xFF9A6A30,
  ];
  static const _washAlt = [
    0xFFD0DAE6,
    0xFF3A3E58,
    0xFF6A2A16,
    0xFF6A5A38,
    0xFF7A6448,
    0xFFAEB8D0,
    0xFF8A949C,
  ];

  // The light each realm spills into the dark round its circle, clear (its
  // weather's light, [_washAlt], tints it).
  static const _spillLight = [
    0xFF78BE78, // Valley
    0xFF96AFEB, // Sky
    0xFFE6602E, // Volcano
    0xFF46AA82, // Swamp
    0xFFC8964E, // Dunes
    0xFF9A6AE0, // Geode
    0xFF4A9AB0, // Tidal
  ];

  // The grains each realm spills, by realm.
  static const _spillGrains = [
    [0xFF96B482, 0xFFB0B4CE, 0xFFCDC060], // meadow, rock, a gold fleck
    [0xFFD6DCF0, 0xFFB4C0E4], // cloud
    [0xFFEC6E2E, 0xFFAA6A4A], // embers, the cone
    [0xFF6E9650, 0xFF3C8C82, 0xFFA07046], // moss, the pool, mud
    [0xFFD8B47A, 0xFFB08850], // sand
    [0xFFA77BE0, 0xFFD8D0F0], // amethyst, quartz
    [0xFF3E8A9A, 0xFFF0A860, 0xFFD0B080], // sea, sun, sand
  ];

  // Each realm's ring of light (and Arcane's, last), and the color it was
  // made for.
  final List<Shader?> _spillShader = List.filled(_nRealms + 1, null);
  final List<int> _spillShaderFor = List.filled(_nRealms + 1, 0);
  final Paint _spillPaint = Paint()..blendMode = BlendMode.plus;

  /// Each realm lights the dark round its circle in its own color, a
  /// little more once it has gathered, and Arcane the middle violet; where
  /// two meet, their lights mix. The light is brightest at the rim and
  /// none in the middle, so what is in a circle looks as it did.
  void _paintSpillLight(Canvas canvas) {
    for (var i = 0; i <= _nRealms; i++) {
      final arc = i == _arcI;
      if (arc ? !arcane : !_shown[i]) continue;
      final c = arc ? _mid : _centre[i];
      final r = arc ? _circleR : _ringR;
      final reach = r * (arc ? 3.2 : 2.4);
      final int argb;
      if (arc) {
        argb = _argb(0.07, 0.5, 0.35, 0.9);
      } else {
        final col = _mix(_spillLight[i], _washAlt[i], _wx[i] * 0.6);
        argb = (_byte(0.075 + 0.025 * _form[i]) << 24) | (col & 0xFFFFFF);
      }
      if (_spillShader[i] == null || _spillShaderFor[i] != argb) {
        final peak = Color(argb), none = peak.withAlpha(0);
        final from = r * (arc ? 0.7 : 0.55) / reach;
        final top = r / reach;
        _spillShaderFor[i] = argb;
        _spillShader[i] = ui.Gradient.radial(
          c,
          reach,
          [
            none,
            none,
            peak,
            peak.withValues(alpha: peak.a * 0.6),
            peak.withValues(alpha: peak.a * 0.22),
            none,
          ],
          [0, from, top, top + (1 - top) * 0.3, top + (1 - top) * 0.62, 1],
        );
      }
      canvas.drawCircle(c, reach, _spillPaint..shader = _spillShader[i]);
    }
  }

  void _paintWashes() {
    final t = time;
    for (final (x, y, r, i) in _washes) {
      final c = _mix(_washClear[i], _washAlt[i], _wx[i]);
      final breathe = 0.85 + 0.15 * _fsin(t * 0.5 + x * 0.05);
      // Lit within its shape: dimmer while it is only dust.
      var a = 0.06 * breathe * (0.35 + 0.65 * _form[i]);
      if (i == WildRealm.sky.index) a += 0.14 * _flash * _wx[i];
      _wash.add(x, y, r * 2, (_byte(a) << 24) | (c & 0xFFFFFF));
    }
    // The Volcano's crater: a faint warmth while it sleeps, a glow as it
    // smokes, and in eruption a red light over the whole cone.
    final o = WildRealm.volcano.index;
    final heat = _wx[o];
    final crater = _at(o, 0.5, 0.25);
    // (None of it when the Volcano is not out today.)
    final cone = _shown[o] ? 0.3 + 0.7 * _form[o] : 0.0;
    _wash.add(
      crater.dx,
      crater.dy,
      _side * (0.3 + 0.25 * heat),
      _argb(
        (0.08 + 0.24 * heat) * (0.9 + 0.1 * _fsin(t * 1.7)) * cone,
        1,
        0.48,
        0.16,
      ),
    );
    if (_erupt > 0) {
      final up = _at(o, 0.5, 0.42);
      _wash.add(
        up.dx,
        up.dy,
        _side * 1.1,
        _argb(0.14 * _erupt * (0.85 + 0.15 * _fsin(t * 2.3)), 0.9, 0.3, 0.12),
      );
      final plume = _at(o, 0.5, 0.0);
      _wash.add(
        plume.dx,
        plume.dy,
        _side * 0.6,
        _argb(0.08 * _erupt, 1, 0.42, 0.18),
      );
    }
    // Fog over the Tidal Shelf: grey hanging in the circle in slow banks.
    final ti = WildRealm.tidal.index;
    final fogged = _shown[ti] ? _wx[ti] : 0.0;
    if (fogged > 0) {
      final c = _centre[ti];
      for (var k = 0; k < 6; k++) {
        final drift = (t * 0.04 + _hash(k * 3 + 951)) % 1.0;
        final x = c.dx + _ringR * (drift * 1.6 - 0.8);
        final y = c.dy + _ringR * (_hash(k * 3 + 952) * 1.1 - 0.55);
        final m = _zone(ti, x, y);
        if (m <= 0) continue;
        _wash.add(
          x,
          y,
          _ringR * (0.9 + 0.4 * _hash(k * 3 + 953)),
          _argb(0.09 * fogged * m, 0.66, 0.7, 0.74),
        );
      }
    }
    // A sandstorm over the Dunes: dust hanging in the whole circle, in
    // slow drifting banks.
    final d = WildRealm.dunes.index;
    final storm = _shown[d] ? _wx[d] : 0.0;
    if (storm > 0) {
      final c = _centre[d];
      for (var k = 0; k < 7; k++) {
        final drift = (t * 0.06 + _hash(k * 3 + 901)) % 1.0;
        final x = c.dx + _ringR * (drift * 1.6 - 0.8);
        final y = c.dy + _ringR * (_hash(k * 3 + 902) * 1.1 - 0.55);
        final m = _zone(d, x, y);
        if (m <= 0) continue;
        _wash.add(
          x,
          y,
          _ringR * (0.9 + 0.4 * _hash(k * 3 + 903)),
          _argb(0.09 * storm * m, 0.72, 0.56, 0.36),
        );
      }
    }
    if (arcane) {
      _wash.add(
        _mid.dx,
        _mid.dy,
        _circleR * 1.9,
        _argb(0.12 + 0.03 * _fsin(t * 0.9), 0.5, 0.24, 0.95),
      );
    }
  }

  // ── The rainbow rain leaves ───────────────────────────────────────────

  // Its grains, arching over the Valley's range in the air before it:
  // place, size and color (alpha already faded toward the circle's edge);
  // and a few soft lights along each band.
  Float32List _bowX = Float32List(0), _bowY = Float32List(0);
  Float32List _bowS = Float32List(0);
  Int32List _bowC = Int32List(0);
  final List<(double, double, double, int)> _bowLanes = [];

  static const _bowBands = [
    0xFFE8604E,
    0xFFF0A048,
    0xFFF2DE74,
    0xFF72D486,
    0xFF5E9CEA,
    0xFF9A78E2,
  ];

  void _buildRainbow(math.Random rng) {
    final v = WildRealm.valley.index;
    if (!_shown[v]) {
      _bowX = _bowY = _bowS = Float32List(0);
      _bowC = Int32List(0);
      _bowLanes.clear();
      return;
    }
    final c = _at(v, 0.5, 0.97);
    final width = _side * 0.016;
    final xs = <double>[], ys = <double>[], ss = <double>[];
    final cs = <int>[];
    _bowLanes.clear();
    for (var b = 0; b < _bowBands.length; b++) {
      final r = _side * 0.6 - b * width;
      final col = _bowBands[b];
      final count = (math.pi * r / 1.4).round();
      for (var k = 0; k < count; k++) {
        final a = math.pi + math.pi * rng.nextDouble();
        final rr = r + (rng.nextDouble() - 0.5) * width * 1.1;
        final x = c.dx + math.cos(a) * rr, y = c.dy + math.sin(a) * rr;
        final m = math.min(1.0, _zone(v, x, y) * 2.2);
        if (m < 0.05) continue;
        xs.add(x);
        ys.add(y);
        ss.add(_unit * (0.0018 + 0.0012 * rng.nextDouble()));
        final al = ((0.3 + 0.24 * rng.nextDouble()) * m * 255).round();
        cs.add((al << 24) | (col & 0xFFFFFF));
      }
      for (var k = 0; k <= 20; k++) {
        final a = math.pi + math.pi * k / 20;
        final x = c.dx + math.cos(a) * r, y = c.dy + math.sin(a) * r;
        final m = _zone(v, x, y);
        if (m < 0.05) continue;
        _bowLanes.add((
          x,
          y,
          width * 6,
          (((0.06 * m) * 255).round() << 24) | (col & 0xFFFFFF),
        ));
      }
    }
    _bowX = Float32List.fromList(xs);
    _bowY = Float32List.fromList(ys);
    _bowS = Float32List.fromList(ss);
    _bowC = Int32List.fromList(cs);
  }

  void _paintRainbow(Canvas canvas) {
    // It stands before the mountains: none while they are only dust.
    final bow = _bow * _form[WildRealm.valley.index];
    if (bow <= 0) return;
    if (!ink) {
      _wash.clear();
      for (final (x, y, r, c) in _bowLanes) {
        _wash.add(x, y, r, _scaleAlpha(c, bow));
      }
      _wash.draw(canvas, _atlas!, _add);
    }
    // Ink on the page has no light behind it: it needs more of itself.
    final a = ink ? bow * 1.8 : bow;
    _dots.clear();
    for (var k = 0; k < _bowX.length; k++) {
      _dots.add(_bowX[k], _bowY[k], _bowS[k], _scaleAlpha(_bowC[k], a));
    }
    debugRainbow = _dots.n;
    _dots.draw(canvas, _atlas!, ink ? _inkOver : _add);
  }

  // ── The Dunes: sand off the crests, glass, a sandstorm ────────────────

  // Spots on the dunes' lit backs where glass lies: place, and when each
  // glints. The first few always; the rest only in the glass a sandstorm
  // leaves.
  Float32List _glintX = Float32List(0), _glintY = Float32List(0);
  Float32List _glintPh = Float32List(0);
  static const int _glintsAlways = 26, _glintsMost = 190;

  void _buildGlints() {
    final d = WildRealm.dunes.index;
    final xs = <double>[], ys = <double>[], ph = <double>[];
    if (_shown[d]) {
      final rng = math.Random(_seed + 600);
      final b = _box[d];
      for (var tries = 0; xs.length < _glintsMost && tries < 6000; tries++) {
        final u = rng.nextDouble(), v = 0.2 + 0.75 * rng.nextDouble();
        final p = Offset(b.left + u * _side, b.top + v * _side);
        final part = _partAt(d, p);
        if (part != _dune && part != _duneFar && part != _duneFloor) continue;
        if (part != _duneFloor &&
            _duneSlip(part == _dune ? _nearDune : _farDune, u, v)) {
          continue;
        }
        xs.add(p.dx);
        ys.add(p.dy);
        ph.add(rng.nextDouble());
      }
    }
    _glintX = Float32List.fromList(xs);
    _glintY = Float32List.fromList(ys);
    _glintPh = Float32List.fromList(ph);
  }

  /// Drawn with the live grains: sand streaming off each crest downwind,
  /// glass glinting in the sand (far more of it after a sandstorm), and in
  /// a sandstorm dust driving across the whole circle.
  void _paintDunes() {
    final i = WildRealm.dunes.index;
    if (!_shown[i]) return;
    final grain = _unit;
    final t = time;
    final storm = _wx[i];
    final form = _form[i];
    if (form > 0.02) {
      for (final (dn, count, reach, seed) in [
        (_nearDune, 90, 0.24, 0),
        (_farDune, 50, 0.16, 1),
      ]) {
        final far = seed == 1 ? 0.62 : 1.0;
        for (var k = 0; k < count; k++) {
          final h = k * 7 + 211 + seed * 997;
          final ph = _hash(h), ph2 = _hash(h + 1), ph3 = _hash(h + 2);
          final a = (t / (1.5 - 0.6 * storm) + ph) % 1.0;
          // Off the last stretch of the back below the crest, lifted a
          // little, carried out over the slipface and settling.
          final from = dn.uc - ph2 * 0.045;
          final u = from + a * reach * (0.7 + 0.5 * ph3) * (1 + 0.6 * storm);
          final v =
              _duneTop(dn, from) -
              0.006 -
              0.03 * a * (1 - a) * (1 + ph3) +
              0.07 * a * a * (1 - 0.5 * storm);
          final p = _at(i, u, v);
          final x = p.dx + 1.4 * _fsin(t * 2.3 + ph * 30) * a;
          final fade =
              (a < 0.12 ? a / 0.12 : 1 - a) * form * far * (0.6 + 0.3 * storm);
          if (fade < 0.02) continue;
          _dots.add(
            x,
            p.dy,
            grain * (0.0024 + 0.0012 * ph3),
            _argb(fade, 0.95, 0.85, 0.66),
          );
        }
      }
      // Glass: a few glints always, many after a sandstorm; lost in one.
      final lit =
          ((_glintsAlways + (_glintX.length - _glintsAlways) * _glass) *
                  (1 - 0.85 * storm))
              .round()
              .clamp(0, _glintX.length);
      for (var k = 0; k < lit; k++) {
        final ph = _glintPh[k];
        final w = _fsin(t * (1.1 + 1.3 * ph) + ph * 40);
        if (w < 0.86) continue;
        final f = (w - 0.86) / 0.14;
        final a = f * f * form;
        if (a < 0.03) continue;
        debugGlints++;
        final x = _glintX[k], y = _glintY[k];
        // Pale and cool, some faintly gold.
        final gold = ph > 0.7 ? 0.14 : 0.0;
        _dots.add(x, y, grain * 0.0042, _argb(a, 1, 0.98 - gold, 0.94 - gold));
        _glow.add(x, y, grain * 0.026, _argb(0.42 * a, 0.78, 0.9, 1));
      }
    }
    // The sandstorm: dust in streaks driving across on the wind, thickest
    // low down, gusting.
    if (storm > 0) {
      final c = _centre[i];
      final span = _ringR * 2.3;
      for (var k = 0; k < 300; k++) {
        final h = k * 5 + 501;
        final ph = _hash(h), ph2 = _hash(h + 1), ph3 = _hash(h + 2);
        final speed = _ringR * (0.9 + 0.8 * ph2);
        final x = c.dx - span / 2 + (ph * span + t * speed) % span;
        final lane = 1 - math.pow(ph3, 1.6).toDouble() * 2;
        final y =
            c.dy +
            _ringR * 0.92 * -lane +
            3 * _fsin(t * 1.4 + ph * 30) +
            2 * _fsin(x * 0.05 + t * 2);
        final m = math.min(1.0, _zone(i, x, y) * 2.2);
        if (m < 0.05) continue;
        final gust = 0.7 + 0.3 * _fsin(t * 0.8 + y * 0.03);
        final a = storm * m * gust;
        final tone = 0.85 + 0.15 * ph;
        for (var j = 0; j < 3; j++) {
          _dots.add(
            x - j * 2.4,
            y - j * 0.4,
            grain * (0.0034 - j * 0.0006),
            _argb(a * (0.55 - j * 0.15), 0.84 * tone, 0.68 * tone, 0.46 * tone),
          );
        }
        debugSandstorm++;
      }
    }
  }

  // ── Geode Hollow: glowing points, a shaft of light, frost ─────────────

  // Spots on the crystals that glint: a few always, many more when rimed.
  Float32List _geoGlX = Float32List(0), _geoGlY = Float32List(0);
  Float32List _geoGlPh = Float32List(0);
  static const int _geoGlintsAlways = 9, _geoGlintsMost = 150;
  // The crystals, as a coarse grid of in/out, for the ice crossing them.
  Uint8List _geoMask = Uint8List(0);
  int _gmw = 0;
  // Where the singing's light shows: spots in the crystals (place, which
  // point, how far up it), and spots loose in the circle for while it is
  // dust (place, how far out).
  Float32List _songX = Float32List(0), _songY = Float32List(0);
  Float32List _songUp = Float32List(0);
  Uint8List _songOf = Uint8List(0);
  Float32List _songDX = Float32List(0), _songDY = Float32List(0);
  Float32List _songDR = Float32List(0);

  /// The order the points sing in, and how far apart, s: a slow rolling
  /// rhythm across the cluster.
  static const _songOrder = [0, 2, 5, 4, 3, 1];
  static const double _songGap = 0.9, _songRise = 1.3;

  void _buildGeode() {
    final g = WildRealm.geode.index;
    final xs = <double>[], ys = <double>[], ph = <double>[];
    _gmw = 0;
    _geoMask = Uint8List(0);
    if (_shown[g]) {
      final rng = math.Random(_seed + 700);
      final b = _box[g];
      for (var tries = 0; xs.length < _geoGlintsMost && tries < 6000; tries++) {
        final p = Offset(
          b.left + rng.nextDouble() * _side,
          b.top + rng.nextDouble() * _side,
        );
        final part = _partAt(g, p);
        if (part != _amethyst && part != _quartz) continue;
        xs.add(p.dx);
        ys.add(p.dy);
        ph.add(rng.nextDouble());
      }
      _gmw = (_side / _maskCell).ceil() + 1;
      _geoMask = Uint8List(_gmw * _gmw);
      for (var gy = 0; gy < _gmw; gy++) {
        for (var gx = 0; gx < _gmw; gx++) {
          final part = _partAt(
            g,
            Offset(b.left + gx * _maskCell, b.top + gy * _maskCell),
          );
          if (part == _amethyst || part == _quartz) {
            _geoMask[gy * _gmw + gx] = 1;
          }
        }
      }
    }
    _geoGlX = Float32List.fromList(xs);
    _geoGlY = Float32List.fromList(ys);
    _geoGlPh = Float32List.fromList(ph);
    _buildSong();
  }

  void _buildSong() {
    final g = WildRealm.geode.index;
    final xs = <double>[], ys = <double>[], ups = <double>[];
    final ofs = <int>[];
    final dx = <double>[], dy = <double>[], dr = <double>[];
    if (_shown[g]) {
      final rng = math.Random(_seed + 800);
      final b = _box[g];
      for (var tries = 0; xs.length < 700 && tries < 9000; tries++) {
        final u = rng.nextDouble(), v = rng.nextDouble();
        for (var k = _xtals.length - 1; k >= 0; k--) {
          final hit = _inXtal(_xtals[k], u, v);
          if (hit == null) continue;
          xs.add(b.left + u * _side);
          ys.add(b.top + v * _side);
          ups.add(hit.$1.clamp(0.0, 1.0));
          ofs.add(k);
          break;
        }
      }
      final c = _centre[g];
      for (var k = 0; k < 600; k++) {
        final r = _ringR * 0.88 * math.sqrt(rng.nextDouble());
        final a = rng.nextDouble() * _tau;
        dx.add(c.dx + math.cos(a) * r);
        dy.add(c.dy + math.sin(a) * r);
        dr.add(r / _ringR);
      }
    }
    _songX = Float32List.fromList(xs);
    _songY = Float32List.fromList(ys);
    _songUp = Float32List.fromList(ups);
    _songOf = Uint8List.fromList(ofs);
    _songDX = Float32List.fromList(dx);
    _songDY = Float32List.fromList(dy);
    _songDR = Float32List.fromList(dr);
  }

  /// The singing: in its shape, a wave of light rolling up each point in
  /// turn, foot to tip, and a few grains lifting off the tip it reaches;
  /// as dust, waves of light rolling out through the dust.
  void _paintSong(int i, double form) {
    final sing = _sing;
    if (sing <= 0) return;
    final grain = _unit;
    final t = time;
    const period = _songGap * 6;
    // How far up each point its wave is now (-1: none on it).
    final wave = List<double>.filled(_xtals.length, -1);
    for (var n = 0; n < _songOrder.length; n++) {
      final age = (t - n * _songGap) % period;
      if (age < _songRise) wave[_songOrder[n]] = age / _songRise;
    }
    if (form > 0.02) {
      for (var k = 0; k < _songX.length; k++) {
        final w = wave[_songOf[k]];
        if (w < 0) continue;
        final d = (_songUp[k] - (w * 1.3 - 0.15)) / 0.16;
        if (d.abs() > 2) continue;
        final band = math.exp(-d * d);
        final a = band * sing * form * math.sin(math.pi * w);
        if (a < 0.04) continue;
        debugSinging++;
        final x = _songX[k], y = _songY[k];
        _dots.add(x, y, grain * 0.0042, _argb(a, 1, 0.96, 1));
        // A little light round it, as small as a grain's glow.
        if (k % 3 == 0) {
          _glow.add(x, y, grain * 0.02, _argb(0.3 * a, 0.86, 0.72, 1));
        }
      }
      // Grains lifting off the tip a wave has reached, drifting up.
      for (var n = 0; n < _songOrder.length; n++) {
        final x = _xtals[_songOrder[n]];
        final (bu, bv, tilt, _, len, _) = x;
        final age = (t - n * _songGap - _songRise * 0.85) % period;
        if (age > 1.8) continue;
        final tip = _at(
          i,
          bu + math.sin(tilt) * len,
          bv - math.cos(tilt) * len,
        );
        for (var j = 0; j < 7; j++) {
          final h = n * 31 + j * 7 + 2101;
          final s = age / 1.8;
          final px =
              tip.dx +
              (_hash(h) - 0.5) * _side * 0.06 +
              _side * 0.03 * _fsin(age * 2 + j);
          final py =
              tip.dy - _side * (0.03 + 0.16 * s * (0.6 + 0.4 * _hash(h + 1)));
          final a = sing * form * 0.8 * (s < 0.15 ? s / 0.15 : 1 - s);
          if (a < 0.03) continue;
          debugSinging++;
          _dots.add(px, py, grain * 0.003, _argb(a, 0.92, 0.88, 1));
        }
      }
    }
    if (form < 0.98) {
      // As dust: rings of light rolling out from the middle, one each
      // beat.
      final out = (t % _songGap) / _songGap;
      for (var k = 0; k < _songDX.length; k++) {
        final d = (_songDR[k] - out) / 0.08;
        if (d.abs() > 2) continue;
        final a = math.exp(-d * d) * sing * (1 - form) * (1 - out * 0.4);
        if (a < 0.04) continue;
        debugSinging++;
        final x = _songDX[k], y = _songDY[k];
        _dots.add(x, y, grain * 0.0042, _argb(a, 0.98, 0.92, 1));
        if (k % 4 == 0) {
          _glow.add(x, y, grain * 0.02, _argb(0.28 * a, 0.8, 0.66, 1));
        }
      }
    }
  }

  bool _inCrystal(double x, double y) {
    final b = _box[WildRealm.geode.index];
    final gx = ((x - b.left) / _maskCell).round();
    final gy = ((y - b.top) / _maskCell).round();
    if (gx < 0 || gy < 0 || gx >= _gmw || gy >= _gmw) return false;
    return _geoMask[gy * _gmw + gx] == 1;
  }

  /// Drawn with the live grains: the points' tips glowing, breathing
  /// slowly; a shaft of light falling on them, motes drifting down it; the
  /// crystals glinting (far more when rimed); and in a frostfall ice
  /// drifting down across the circle, brighter where it crosses them.
  void _paintGeode() {
    final i = WildRealm.geode.index;
    if (!_shown[i]) return;
    final grain = _unit;
    final t = time;
    final form = _form[i];
    final frost = _frost;
    final rimed = _wx[i];
    _paintSong(i, form);
    if (form > 0.02) {
      // The shaft: from above on the left, down onto the cluster.
      final from = _at(i, 0.16, -0.28), to = _at(i, 0.52, 0.62);
      final along = to - from;
      final len = along.distance;
      final ux = along.dx / len, uy = along.dy / len;
      final half = _side * 0.075;
      for (var k = 0; k < 150; k++) {
        final h = k * 5 + 1301;
        final s = (_hash(h) + t * (0.02 + 0.02 * _hash(h + 1))) % 1.0;
        final q = (_hash(h + 2) * 2 - 1) * (0.4 + 0.6 * s);
        final x = from.dx + ux * len * s - uy * half * q;
        final y = from.dy + uy * len * s + ux * half * q;
        final m = math.min(1.0, _zone(i, x, y) * 2);
        if (m < 0.05) continue;
        final a =
            0.32 *
            form *
            m *
            math.sin(math.pi * s) *
            (1 - q.abs() * 0.6) *
            (1 - 0.6 * frost);
        _dots.add(
          x,
          y,
          grain * (0.0022 + 0.001 * _hash(h + 3)),
          _argb(a, 0.88, 0.82, 1),
        );
      }
      // The tips, glowing faintly, breathing.
      for (var k = 0; k < _xtals.length; k++) {
        final (bu, bv, tilt, _, len, pale) = _xtals[k];
        final tip = _at(
          i,
          bu + math.sin(tilt) * len * 0.92,
          bv - math.cos(tilt) * len * 0.92,
        );
        final breathe = 0.65 + 0.35 * _fsin(t * 0.55 + k * 1.9);
        _glow.add(
          tip.dx,
          tip.dy,
          grain * (pale ? 0.045 : 0.07),
          pale
              ? _argb(0.22 * breathe * form, 0.8, 0.9, 1)
              : _argb(0.3 * breathe * form, 0.72, 0.5, 1),
        );
      }
      // Glints: a few always, many when rimed; lost in a frostfall.
      final lit =
          ((_geoGlintsAlways + (_geoGlX.length - _geoGlintsAlways) * rimed) *
                  (1 - 0.85 * frost))
              .round()
              .clamp(0, _geoGlX.length);
      for (var k = 0; k < lit; k++) {
        final ph = _geoGlPh[k];
        final w = _fsin(t * (0.9 + 1.2 * ph) + ph * 40);
        if (w < 0.86) continue;
        final f = (w - 0.86) / 0.14;
        final a = f * f * form;
        if (a < 0.03) continue;
        debugRimeGlints++;
        final x = _geoGlX[k], y = _geoGlY[k];
        _dots.add(x, y, grain * 0.004, _argb(a, 0.96, 0.97, 1));
        _glow.add(x, y, grain * 0.022, _argb(0.4 * a, 0.82, 0.86, 1));
      }
    }
    // The frostfall: ice drifting down across the whole circle, swaying,
    // catching the light where it crosses the crystals.
    if (frost > 0) {
      final c = _centre[i];
      final span = _ringR * 2.2;
      for (var k = 0; k < 240; k++) {
        final h = k * 5 + 1701;
        final ph = _hash(h), ph2 = _hash(h + 1), ph3 = _hash(h + 2);
        final y =
            c.dy -
            span / 2 +
            (ph * span + t * _ringR * (0.12 + 0.12 * ph2)) % span;
        final x =
            c.dx -
            _ringR +
            ph3 * 2 * _ringR +
            5 * _fsin(t * (0.6 + 0.5 * ph2) + ph * 30);
        final m = math.min(1.0, _zone(i, x, y) * 2.2);
        if (m < 0.05) continue;
        debugFrost++;
        final over = form > 0.5 && _inCrystal(x, y);
        final a = frost * m * (over ? 0.95 : 0.6);
        _dots.add(
          x,
          y,
          grain * (0.003 + 0.0016 * ph2),
          _argb(a, 0.86, 0.93, 1),
        );
        if (over && k % 3 == 0) {
          _glow.add(x, y, grain * 0.02, _argb(0.35 * a, 0.8, 0.9, 1));
        }
      }
    }
  }

  // ── The Tidal Shelf: the sun's path, fog, a swell, shells ────────────

  // Spots on the sea for whitecaps, and on the sand for shells.
  Float32List _seaX = Float32List(0), _seaY = Float32List(0);
  Float32List _sandX = Float32List(0), _sandY = Float32List(0);

  void _buildTidal() {
    final td = WildRealm.tidal.index;
    final sx = <double>[], sy = <double>[], hx = <double>[], hy = <double>[];
    if (_shown[td]) {
      final rng = math.Random(_seed + 900);
      final b = _box[td];
      for (var tries = 0; sx.length < 120 && tries < 5000; tries++) {
        final p = Offset(
          b.left + rng.nextDouble() * _side,
          b.top + (_seaAt(tide) + 0.03 + rng.nextDouble() * 0.2) * _side,
        );
        if (_partAt(td, p) == _sea) {
          sx.add(p.dx);
          sy.add(p.dy);
        }
      }
      for (var tries = 0; hx.length < 16 && tries < 3000; tries++) {
        final p = Offset(
          b.left + (0.05 + 0.3 * rng.nextDouble()) * _side,
          b.top + (0.9 + 0.05 * rng.nextDouble()) * _side,
        );
        if (_partAt(td, p) == _tideSand) {
          hx.add(p.dx);
          hy.add(p.dy);
        }
      }
    }
    _seaX = Float32List.fromList(sx);
    _seaY = Float32List.fromList(sy);
    _sandX = Float32List.fromList(hx);
    _sandY = Float32List.fromList(hy);
  }

  /// Drawn with the live grains: the sun's soft light and its path
  /// glittering on the water; in a fog, grey drifting across the circle; in
  /// a swell, whitecaps on the sea and the path broken up; and after one,
  /// shells and a glass float on the sand.
  void _paintTidal() {
    final i = WildRealm.tidal.index;
    if (!_shown[i]) return;
    final grain = _unit;
    final t = time;
    final form = _form[i];
    final fog = _wx[i];
    final swell = _swell;
    final level = _seaAt(tide);
    if (form > 0.02) {
      // The sun's light, soft, and along the horizon under it.
      final sun = _at(i, 0.5, level - _sunUp);
      final lit = form * (1 - 0.6 * fog);
      _glow.add(sun.dx, sun.dy, _side * 0.75, _argb(0.12 * lit, 1, 0.72, 0.42));
      for (var k = -2; k <= 2; k++) {
        final p = _at(i, 0.5 + k * 0.07, level + 0.005);
        _glow.add(
          p.dx,
          p.dy,
          _side * 0.12,
          _argb(0.14 * lit * (1 - k.abs() * 0.25), 1, 0.8, 0.5),
        );
      }
      // The path: grains of light twinkling on the water, narrow under the
      // sun and widening toward the viewer; in a swell, broken in bands.
      for (var k = 0; k < 400; k++) {
        final h = k * 5 + 3101;
        final ph = _hash(h), ph2 = _hash(h + 1);
        final s = math.pow(_hash(h + 2), 1.3).toDouble();
        final v = level + 0.008 + s * (0.9 - level);
        final q = ph2 * 2 - 1;
        final u = 0.5 + q * _pathHalf(level, v) * (0.85 + 0.1 * ph);
        final w = _fsin(t * (1.4 + 2.2 * ph) + ph * 50);
        if (w < 0.35) continue;
        var a =
            math.pow((w - 0.35) / 0.65, 1.3).toDouble() *
            lit *
            (1 - 0.55 * s) *
            (1 - 0.5 * q.abs());
        if (swell > 0) {
          final crest = _fsin(v * 70 - t * 2.4 + q * 3);
          a *= 1 - swell * (crest > 0.1 ? 0.15 : 0.85);
        }
        if (a < 0.05) continue;
        debugGlitter++;
        final p = _at(i, u, v);
        final warm = _clamp01(1 - s * 1.4);
        _dots.add(
          p.dx,
          p.dy,
          grain * (0.0032 + 0.0018 * ph * (1 - s)),
          _argb(a, 1, 0.9 + 0.08 * (1 - warm), 0.62 + 0.3 * (1 - warm)),
        );
        if (k % 7 == 0) {
          _glow.add(p.dx, p.dy, grain * 0.02, _argb(0.3 * a, 1, 0.82, 0.5));
        }
      }
      if (swell > 0) {
        // Whitecaps, each breaking now and then.
        for (var k = 0; k < _seaX.length; k++) {
          final w = _fsin(t * (0.8 + 0.6 * _hash(k + 2601)) + k * 2.3);
          if (w < 0.6) continue;
          final a = (w - 0.6) / 0.4 * swell * form;
          debugSpray++;
          _dots.add(
            _seaX[k],
            _seaY[k],
            grain * 0.0036,
            _argb(0.9 * a, 0.94, 0.98, 1),
          );
          _dots.add(
            _seaX[k] - 1.6,
            _seaY[k] + 0.4,
            grain * 0.003,
            _argb(0.6 * a, 0.9, 0.96, 1),
          );
        }
      }
      // Shells and a glass float on the sand, after a swell.
      if (_shells > 0) {
        for (var k = 0; k < _sandX.length; k++) {
          final glass = k < 2;
          final x = _sandX[k], y = _sandY[k];
          if (glass) {
            final w = 0.6 + 0.4 * _fsin(t * 1.3 + k * 2.1);
            debugShells++;
            _dots.add(
              x,
              y,
              grain * 0.0052,
              _argb(_shells * form, 0.5, 0.86, 0.62),
            );
            _glow.add(
              x,
              y,
              grain * 0.024,
              _argb(0.35 * w * _shells * form, 0.5, 0.95, 0.7),
            );
            continue;
          }
          final pink = k.isEven;
          debugShells++;
          _dots.add(
            x,
            y,
            grain * 0.0036,
            pink
                ? _argb(0.9 * _shells * form, 0.98, 0.8, 0.8)
                : _argb(0.9 * _shells * form, 1, 0.95, 0.86),
          );
        }
      }
    }
    // Fog: grey drifting across in slow banks.
    if (fog > 0) {
      final c = _centre[i];
      final span = _ringR * 2.3;
      for (var k = 0; k < 300; k++) {
        final h = k * 5 + 2901;
        final ph = _hash(h), ph2 = _hash(h + 1), ph3 = _hash(h + 2);
        final x =
            c.dx -
            span / 2 +
            (ph * span + t * _ringR * (0.05 + 0.06 * ph2)) % span;
        final y =
            c.dy + _ringR * (ph3 * 1.8 - 0.9) + 3 * _fsin(t * 0.3 + ph * 20);
        final m = math.min(1.0, _zone(i, x, y) * 2);
        if (m < 0.05) continue;
        final bank = 0.55 + 0.45 * _fsin(x * 0.03 + y * 0.02 + t * 0.2);
        final a = 0.4 * fog * m * bank;
        if (a < 0.04) continue;
        debugFog++;
        _dots.add(
          x,
          y,
          grain * (0.004 + 0.002 * ph2),
          _argb(a, 0.78, 0.82, 0.85),
        );
      }
    }
  }

  // ── Arcane's sky: a meteor shower, the northern lights ────────────────

  double _shower = 0, _aurora = 0;

  // Meteors in flight across Arcane's disc, out of one point beyond its
  // upper left: where each started, its way (unit), when it began, how
  // long it flies, its trail and its tint (0 white, 1 mint, 2 gold).
  static const int _meteorCap = 10;
  final Float64List _mtX = Float64List(_meteorCap),
      _mtY = Float64List(_meteorCap);
  final Float64List _mtUx = Float64List(_meteorCap),
      _mtUy = Float64List(_meteorCap);
  final Float64List _mtBorn = Float64List(_meteorCap)
    ..fillRange(0, _meteorCap, -99);
  final Float64List _mtLife = Float64List(_meteorCap),
      _mtLen = Float64List(_meteorCap);
  final Uint8List _mtTint = Uint8List(_meteorCap);
  double _nextMeteor = 0;

  void _stepMeteors(double dt) {
    if (_shower < 0.3 || _size.isEmpty) return;
    _nextMeteor -= dt;
    if (_nextMeteor > 0) return;
    _nextMeteor = (0.08 + _rng.nextDouble() * 0.22) / _shower;
    var slot = -1;
    for (var k = 0; k < _meteorCap; k++) {
      if (time - _mtBorn[k] > _mtLife[k] + 0.8) {
        slot = k;
        break;
      }
    }
    if (slot < 0) return;
    final r = _circleR;
    // Out of the radiant, first seen a little way into the disc.
    final rad = _mid + Offset(-r * 0.95, -r * 1.05);
    final a = math.pi * (0.12 + 0.26 * _rng.nextDouble());
    final ux = math.cos(a), uy = math.sin(a);
    final start = rad + Offset(ux, uy) * r * (0.4 + 0.7 * _rng.nextDouble());
    _mtX[slot] = start.dx;
    _mtY[slot] = start.dy;
    _mtUx[slot] = ux;
    _mtUy[slot] = uy;
    _mtBorn[slot] = time;
    _mtLife[slot] = 0.35 + 0.35 * _rng.nextDouble();
    _mtLen[slot] = r * (0.5 + 0.45 * _rng.nextDouble());
    _mtTint[slot] = _rng.nextDouble() < 0.7 ? 0 : 1 + _rng.nextInt(2);
  }

  /// How far inside Arcane's line (x, y) is: 1 well in, 0 at the line.
  double _inArc(double x, double y) {
    final dx = x - _mid.dx, dy = y - _mid.dy;
    final d = math.sqrt(dx * dx + dy * dy) / _circleR;
    return _clamp01((0.95 - d) / 0.15);
  }

  static const _meteorTints = [
    (0.9, 0.93, 1.0),
    (0.66, 0.96, 0.82),
    (1.0, 0.9, 0.65),
  ];

  /// Lights drawn over Arcane's disc for its weather: each meteor a bright
  /// head, a trail of grains tapering behind it and grains that glow on a
  /// moment after it passes; the northern lights as two curtains of rays
  /// standing on folded hems, green below and violet above.
  // The northern lights' columns, each [_auroraRise] grains tall: what
  // never changes along one, worked out once. Each grain's sideways
  // scatter; and by height, its color (green at the hem, through blue, to
  // violet at the top) and how bright (brightest just above the hem,
  // thinning upward).
  static const int _auroraRise = 22;
  static final Float64List _auroraJitter = Float64List.fromList([
    for (var i = 0; i < 72; i++)
      for (var j = 0; j < _auroraRise; j++) (_hash(i * 31 + j) - 0.5) * 1.1,
  ]);
  static double _auroraAt(int j) => j / (_auroraRise - 1);
  static final Float64List _auroraR = Float64List.fromList([
    for (var j = 0; j < _auroraRise; j++)
      _auroraAt(j) < 0.5
          ? 0.32 + 0.3 * _auroraAt(j)
          : 0.47 + 0.2 * (_auroraAt(j) - 0.5),
  ]);
  static final Float64List _auroraG = Float64List.fromList([
    for (var j = 0; j < _auroraRise; j++)
      _auroraAt(j) < 0.5
          ? 0.94 - 0.7 * _auroraAt(j)
          : 0.59 - 0.4 * (_auroraAt(j) - 0.5),
  ]);
  static final Float64List _auroraB = Float64List.fromList([
    for (var j = 0; j < _auroraRise; j++)
      _auroraAt(j) < 0.5
          ? 0.7 + 0.3 * _auroraAt(j)
          : 0.85 + 0.1 * (_auroraAt(j) - 0.5),
  ]);
  static final Float64List _auroraFade = Float64List.fromList([
    for (var j = 0; j < _auroraRise; j++)
      _auroraAt(j) < 0.08
          ? 0.5 + _auroraAt(j) * 6
          : math.pow(1 - _auroraAt(j), 0.55).toDouble(),
  ]);

  void _paintArcaneSky(Canvas canvas) {
    if (!arcane || (_shower <= 0 && _aurora <= 0)) return;
    final grain = _unit;
    final t = time;
    _dots.clear();

    if (_aurora > 0) {
      final r = _circleR;
      const columns = 72;
      for (final (base, tall, strength, seed) in const [
        (0.34, 0.9, 1.0, 5.0),
        (-0.06, 0.62, 0.6, 9.0),
      ]) {
        for (var i = 0; i < columns; i++) {
          final u = i / (columns - 1);
          final x0 = _mid.dx - r + 2 * r * u;
          final hem =
              _mid.dy +
              r * base +
              r * 0.1 * _fsin(u * 4.2 + t * 0.3 + seed) +
              r * 0.035 * _fsin(u * 11 + t * 0.5 + seed * 2);
          final rise = r * tall * (0.8 + 0.2 * _fsin(u * 9.3 + seed + t * 0.2));
          final lean = r * 0.12 * _fsin(u * 6.5 + t * 0.25 + seed);
          // Fine rays standing along it, drifting.
          final ray =
              0.25 +
              0.75 *
                  math.pow(
                    0.5 +
                        0.5 *
                            _fsin(u * 73 + t * 0.9 + seed) *
                            _fsin(u * 29 - t * 0.6),
                    1.6,
                  );
          final pulse = 0.55 + 0.45 * _fsin(u * 8 - t * 1.3 + seed);
          final a = _aurora * strength * ray * pulse;
          if (a < 0.05) continue;
          const n = _auroraRise;
          for (var j = 0; j < n; j++) {
            final s = j / (n - 1);
            final x = x0 + lean * s + _auroraJitter[i * n + j];
            final y = hem - rise * s;
            final m = _inArc(x, y);
            if (m <= 0) continue;
            _dots.add(
              x,
              y,
              grain * 0.0034,
              _argb(
                math.min(1.0, 1.3 * a * _auroraFade[j]) * m,
                _auroraR[j],
                _auroraG[j],
                _auroraB[j],
              ),
            );
          }
          if (i % 3 == 0) {
            final m = _inArc(x0, hem - rise * 0.25);
            if (m > 0) {
              _glow.add(
                x0 + lean * 0.25,
                hem - rise * 0.25,
                r * 0.55,
                _argb(0.3 * a * m, 0.32, 0.94, 0.7),
              );
            }
          }
        }
      }
    }

    if (_shower > 0) {
      for (var k = 0; k < _meteorCap; k++) {
        final age = t - _mtBorn[k], life = _mtLife[k];
        if (age < 0 || age > life + 0.8) continue;
        // White light shows nothing on the page: there, a deep violet ink.
        final (cr, cg, cb) = ink ? (0.42, 0.3, 0.78) : _meteorTints[_mtTint[k]];
        final head = ink ? 0.5 : 1.0;
        final speed = _circleR * 2.4;
        final went = speed * math.min(age, life);
        final ux = _mtUx[k], uy = _mtUy[k];
        final hx = _mtX[k] + ux * went, hy = _mtY[k] + uy * went;
        if (age < life) {
          final env = math.sqrt(math.sin(math.pi * age / life)) * _shower;
          final len = math.min(went, _mtLen[k]);
          final n = (len / 0.9).ceil();
          for (var j = 1; j <= n; j++) {
            final s = j / n;
            final x = hx - ux * len * s, y = hy - uy * len * s;
            final m = _inArc(x, y);
            if (m <= 0) continue;
            final f = env * m * math.pow(1 - s, 1.1).toDouble();
            _dots.add(
              x,
              y,
              grain * (0.0042 - 0.0018 * s),
              _argb(f, cr, cg, cb),
            );
            if (j % 4 == 0) {
              _glow.add(x, y, grain * 0.016, _argb(0.22 * f, cr, cg, cb));
            }
          }
          final m = _inArc(hx, hy);
          if (m > 0) {
            _dots.add(hx, hy, grain * 0.006, _argb(env * m, head, head, 1));
            _glow.add(hx, hy, grain * 0.04, _argb(0.45 * env * m, cr, cg, cb));
          }
        }
        // What it leaves: grains that glow on a moment, scattering.
        for (var j = 0; j < 14; j++) {
          final at = went - _hash(j * 13 + k * 7) * _mtLen[k] * 1.4;
          if (at <= 0) continue;
          final since = age - at / speed;
          if (since < 0.04) continue;
          final glow = math.exp(-since * 3.4) * _shower * 0.8;
          if (glow < 0.04) continue;
          final side = (_hash(j * 5 + 3) - 0.5) * 3 * (1 + since * 5);
          final x = _mtX[k] + ux * at - uy * side;
          final y = _mtY[k] + uy * at + ux * side;
          final m = _inArc(x, y);
          if (m <= 0) continue;
          _dots.add(x, y, grain * 0.003, _argb(glow * m, cr, cg, cb));
        }
      }
    }
    debugArcaneSky = _dots.n;
    _dots.draw(canvas, _atlas!, ink ? _inkOver : _add);
  }

  // ── Movers: grains that travel ────────────────────────────────────────

  // Kinds: 0 wind through the cloud, 1 lava thrown out of the crater in
  // eruption, 2 smoke off the crater, 3 dust off the dry Swamp.
  int _m = 0;
  Offset _craterAt = Offset.zero;
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

    // Each only for a realm out today.
    final s = _box[WildRealm.sky.index];
    for (var k = 0; k < (_shown[WildRealm.sky.index] ? 320 : 0); k++) {
      add(
        0,
        s.left + rng.nextDouble() * _side,
        s.top + _side * (0.3 + 0.45 * rng.nextDouble()),
        _side * (0.12 + 0.12 * rng.nextDouble()),
      );
    }
    final crater = _craterAt = _at(WildRealm.volcano.index, 0.5, 0.24);
    final volcanoOut = _shown[WildRealm.volcano.index];
    for (var k = 0; k < (volcanoOut ? 220 : 0); k++) {
      add(
        1,
        crater.dx + (rng.nextDouble() - 0.5) * _side * 0.1,
        crater.dy,
        _side * (0.5 + 0.45 * rng.nextDouble()),
      );
    }
    for (var k = 0; k < (volcanoOut ? 260 : 0); k++) {
      add(
        2,
        crater.dx + (rng.nextDouble() - 0.5) * _side * 0.1,
        crater.dy,
        _side * (0.05 + 0.035 * rng.nextDouble()),
      );
    }
    final w = WildRealm.swamp.index;
    for (var k = 0; k < (_shown[w] ? 90 : 0); k++) {
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
    // Felt from the next grain step, even one later in this same step (a
    // strike of lightning).
    _markCells(g0x, g1x, g0y, g1y);
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
    _markTiles();
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
  final Float64List _wx = Float64List(_nRealms);
  final Float64List _rain = Float64List(1);
  // Each realm's, and Arcane's ([_arcI]).
  final Float64List _ready = Float64List(_nRealms + 1);

  // How far each realm has gathered: 0 dust, 1 its shape; it travels at an
  // even pace and each grain eases along its own share of the way.
  final Float64List _form = Float64List(_nRealms);
  // How each realm last rested (1 in its shape, 0 as dust): where its
  // grains' places at rest (_hx, _hy) are.
  final Uint8List _formed = Uint8List(_nRealms);
  // No realm gathers before this time: the map has a moment to open.
  double _formWait = 0;

  /// How long a realm takes to gather or come apart, s.
  static const double _formTime = 1.8;

  /// The share of that time a grain may wait before it sets off.
  static const double _stagger = 0.4;

  /// How long an opened map waits before the realms gather, s.
  static const double _gatherDelay = 0.35;

  /// How bright a realm's dust is against its shape: a realm with
  /// something waiting stands out.
  static const double _dustAlpha = 0.72;

  // Each realm's layers of dust, turned this frame: angle, cos, sin.
  final Float64List _spinA = Float64List(_nRealms * _layers);
  final Float64List _spinC = Float64List(_nRealms * _layers)
    ..fillRange(0, _nRealms * _layers, 1);
  final Float64List _spinS = Float64List(_nRealms * _layers);

  /// Which way layer [l] of realm [i]'s dust turns: 1 or -1.
  static double _turnWay(int i, int l) =>
      (_layerTurn[l] < 0 ? -1.0 : 1.0) * (i.isEven ? 1 : -1);

  void _turnLayers() {
    for (var i = 0; i < _nRealms; i++) {
      for (var l = 0; l < _layers; l++) {
        final j = i * _layers + l;
        final a = time * _layerTurn[l] * (i.isEven ? 1 : -1) + i * 1.7 + l;
        _spinA[j] = a;
        _spinC[j] = math.cos(a);
        _spinS[j] = math.sin(a);
      }
    }
  }

  /// Whether realm [i] is on its way between dust and its shape.
  bool _gathering(int i) => _form[i] > 0 && _form[i] < 1;

  /// The realm whose shape group [g] holds, or -1.
  static int _realmOf(int g) {
    if (g >= _gStill && g < _gStill + _nRealms) return g - _gStill;
    if (g == _gCloud) return WildRealm.sky.index;
    if (g == _gTree) return WildRealm.swamp.index;
    return -1;
  }

  /// Whether group [g] is a realm's dust at rest, its layers turning.
  bool _turning(int g) {
    final i = _realmOf(g);
    return i >= 0 && _formed[i] == 0 && !_gathering(i);
  }

  /// Whether group [g] is a realm's grains on their way.
  bool _travelling(int g) {
    final i = _realmOf(g);
    return i >= 0 && _gathering(i);
  }

  /// Realm [i] at rest in its shape ([formed] 1) or as dust: its grains'
  /// places moved there, and what was drawn of them at the old ones let go.
  void _restAs(int i, int formed) {
    _formed[i] = formed;
    if (_n == 0) return;
    final shaped = formed == 1;
    for (var k = 0; k < _n; k++) {
      if (_realm[k] != i || !_isShape(_part[k])) continue;
      _px[k] = _hx[k] = shaped ? _fx[k] : _sx[k];
      _py[k] = _hy[k] = shaped ? _fy[k] : _sy[k];
      _tile[k] = _tileAt(_hx[k], _hy[k]);
    }
    for (var g = 0; g < _groups; g++) {
      if (_realmOf(g) == i || g == _gLive) _dropGroup(g);
    }
  }

  // Set by [_travel]: where grain k is on its way, and how far along (0–1).
  double _qx = 0, _qy = 0, _qe = 0;

  /// Where grain [k] is on its way between the dust and its shape: from its
  /// spot in its turning layer to its place in the shape (as its part moves
  /// there), easing, swinging round on the way.
  @pragma('vm:prefer-inline')
  void _travel(int k) {
    final i = _realm[k];
    var s = (_form[i] - _delay[k]) / (1 - _stagger);
    s = s < 0 ? 0 : (s > 1 ? 1 : s);
    final e = s * s * s * (s * (s * 6 - 15) + 10);
    final c = _centre[i];
    final j = i * _layers + _layer[k];
    final cs = _spinC[j], sn = _spinS[j];
    final dx = _sx[k] - c.dx, dy = _sy[k] - c.dy;
    final x0 = c.dx + dx * cs - dy * sn, y0 = c.dy + dx * sn + dy * cs;
    var x1 = _fx[k], y1 = _fy[k];
    switch (_part[k]) {
      case _cloud:
        x1 += _cloudDx;
        y1 += _cloudDy;
      case _canopy || _moss:
        x1 += _treeShear * (y1 - _treeBase);
      default:
        break;
    }
    final mx = x1 - x0, my = y1 - y0;
    final swing = _curl[k] * _fsin(math.pi * e);
    _qx = x0 + mx * e - my * swing;
    _qy = y0 + my * e + mx * swing;
    _qe = e;
  }

  /// How gathered realm [r] is: 0 dust, 1 its shape (tests, previews).
  double debugFormOf(WildRealm r) => _form[r.index];
  // The Volcano: smoke over it (smoking or erupting), and erupting.
  double _smoke = 0, _erupt = 0, _bow = 0;
  // The glass a sandstorm leaves in the Dunes.
  double _glass = 0;
  // A frostfall over Geode Hollow, and its crystals singing.
  double _frost = 0, _sing = 0;
  // A swell on the Tidal Shelf, and the shells one leaves.
  double _swell = 0, _shells = 0;
  double _flash = 0;
  double _nextStrike = 2;
  final List<Offset> _bolt = [], _fork = [];
  double _boltAge = 9;
  // Lightning inside the cloud: where it lit, the crack it ran along (both
  // at rest, before the cloud's bob), and how long ago.
  Offset _flickAt = Offset.zero;
  final List<Offset> _flickPath = [];
  double _flickAge = 9, _nextFlick = 0.3, _flickR = 0;
  final math.Random _rng = math.Random(11);

  double _target(WildRealm r) {
    // A realm not out today has no weather here.
    if (!_shown[r.index]) return 0;
    final w = weather[r.sceneId];
    return switch (r) {
      WildRealm.valley => w == WeatherKind.snow ? 1 : 0,
      WildRealm.sky => w == WeatherKind.storm ? 1 : 0,
      WildRealm.swamp => w == WeatherKind.dry ? 1 : 0,
      WildRealm.dunes => w == WeatherKind.sandstorm ? 1 : 0,
      // Its crystals frosted white: the rime a frostfall leaves, once it
      // has passed.
      WildRealm.geode => rime && w == null ? 1 : 0,
      // Hazed in a fog.
      WildRealm.tidal => w == WeatherKind.fog ? 1 : 0,
      // How warm the mountain is.
      WildRealm.volcano => switch (volcano) {
        WildVolcano.still => 0,
        WildVolcano.smoking => 0.45,
        WildVolcano.erupting => 1,
      },
    };
  }

  bool get _volcanoOut => _shown[WildRealm.volcano.index];
  bool get _valleyOut => _shown[WildRealm.valley.index];
  double get _smokeTo => _volcanoOut && volcano != WildVolcano.still ? 1 : 0;
  double get _eruptTo => _volcanoOut && volcano == WildVolcano.erupting ? 1 : 0;
  double get _bowTo =>
      _valleyOut && rainbow && weather['valley'] == null ? 1 : 0;

  double get _glassTo =>
      glass && _shown[WildRealm.dunes.index] && weather['dunes'] == null
      ? 1
      : 0;

  double get _frostTo =>
      _shown[WildRealm.geode.index] && weather['geode'] == WeatherKind.frostfall
      ? 1
      : 0;

  bool get _tidalOut => _shown[WildRealm.tidal.index];
  double get _swellTo =>
      _tidalOut && weather['tidal'] == WeatherKind.swell ? 1 : 0;
  double get _shellsTo =>
      _tidalOut && shells && weather['tidal'] == null ? 1 : 0;

  double get _singTo =>
      _shown[WildRealm.geode.index] && weather['geode'] == WeatherKind.singing
      ? 1
      : 0;

  bool get _raining => _valleyOut && weather['valley'] == WeatherKind.rain;

  /// Whether realm [i] is on the map with something waiting in it.
  bool _isReady(int i) =>
      _shown[i] && ready.contains(WildRealm.values[i].sceneId);

  double get _arcReadyTo => arcane && ready.contains('arcane') ? 1 : 0;
  double get _showerTo =>
      arcane && weather['arcane'] == WeatherKind.meteors ? 1 : 0;
  double get _auroraTo =>
      arcane && weather['arcane'] == WeatherKind.aurora ? 1 : 0;

  /// Snaps the weather and the realms' moods to what is asked, no easing.
  /// With [gather], every realm starts as dust and those with something
  /// waiting gather once the map has had a moment to open; otherwise each
  /// is snapped to its shape or its dust.
  void settle({bool gather = false}) {
    for (final r in WildRealm.values) {
      _wx[r.index] = _target(r);
      _ready[r.index] = _isReady(r.index) ? 1 : 0;
      final to = gather ? 0 : (_isReady(r.index) ? 1 : 0);
      _form[r.index] = to.toDouble();
      if (_shown[r.index]) _restAs(r.index, to);
    }
    _formWait = gather ? time + _gatherDelay : 0;
    _ready[_arcI] = _arcReadyTo;
    _shower = _showerTo;
    _aurora = _auroraTo;
    _rain[0] = _raining ? 1 : 0;
    _smoke = _smokeTo;
    _erupt = _eruptTo;
    _bow = _bowTo;
    _glass = _glassTo;
    _frost = _frostTo;
    _sing = _singTo;
    _swell = _swellTo;
    _shells = _shellsTo;
  }

  static double _ease(double v, double to, double k) {
    final next = v + (to - v) * k;
    return (next - to).abs() < 2e-3 ? to : next;
  }

  void step(double dt) {
    time += dt;
    final k = 1 - math.exp(-dt / 1.2);
    for (final r in WildRealm.values) {
      final i = r.index;
      _wx[i] = _ease(_wx[i], _target(r), k);
      final to = _isReady(i) ? 1.0 : 0.0;
      _ready[i] = _ease(_ready[i], to, k);
      // Gathering into its shape, or coming apart, at an even pace.
      final was = _form[i];
      if (was != to && time >= _formWait) {
        final d = dt / _formTime;
        _form[i] = to > was ? math.min(to, was + d) : math.max(to, was - d);
        if (_form[i] == to) _restAs(i, to.toInt());
      }
    }
    _ready[_arcI] = _ease(_ready[_arcI], _arcReadyTo, k);
    _shower = _ease(_shower, _showerTo, k);
    _aurora = _ease(_aurora, _auroraTo, k);
    _rain[0] = _ease(_rain[0], _raining ? 1 : 0, k);
    _smoke = _ease(_smoke, _smokeTo, k);
    _erupt = _ease(_erupt, _eruptTo, k);
    _bow = _ease(_bow, _bowTo, k);
    _glass = _ease(_glass, _glassTo, k);
    _frost = _ease(_frost, _frostTo, k);
    _sing = _ease(_sing, _singTo, k);
    _swell = _ease(_swell, _swellTo, k);
    _shells = _ease(_shells, _shellsTo, k);
    _stepField(dt);
    _stepStorm(dt);
    _stepMeteors(dt);
    _stepGrains(dt);
  }

  /// Brings the next strike of lightning now (previews).
  void debugStrike() => _nextStrike = 0;

  void _stepStorm(double dt) {
    _flash *= math.exp(-dt / 0.22);
    if (_flash < 0.01) _flash = 0;
    _boltAge += dt;
    _flickAge += dt;
    final storm = _wx[WildRealm.sky.index];
    if (storm < 0.3 || _size.isEmpty) return;
    _stepFlicker(dt);
    // Bolts drop out of the cloud's base: none while it is only dust.
    if (_form[WildRealm.sky.index] < 1) return;
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

  /// Lightning that stays in the cloud, often: one puff lit from inside
  /// and a short crack running across it.
  void _stepFlicker(double dt) {
    _nextFlick -= dt;
    if (_nextFlick > 0) return;
    _nextFlick = 0.35 + _rng.nextDouble() * 1.1;
    final i = WildRealm.sky.index;
    // The three big puffs in the middle, mostly: light in the small ones
    // at the ends spills out past them.
    final (u, v, r) = _cloudLobes[1 + _rng.nextInt(3)];
    final a = _rng.nextDouble() * _tau;
    var p = _at(i, u + math.cos(a) * r * 0.35, v + math.sin(a) * r * 0.3);
    _flickAt = p;
    _flickR = r * _side;
    _flickPath
      ..clear()
      ..add(p);
    final lean = _rng.nextBool() ? 1.0 : -1.0;
    for (var k = 0; k < 4 + _rng.nextInt(3); k++) {
      final next =
          p +
          Offset(
            lean * (3 + _rng.nextDouble() * 5),
            (_rng.nextDouble() - 0.4) * 5,
          );
      if (!_inCloud(next.dx, next.dy)) break;
      _flickPath.add(p = next);
    }
    _flickAge = 0;
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
    if (_travelling(g)) return true;
    if (_fieldOn && _reach[g].overlaps(_flowBox)) return true;
    if (g == _gLive) return true;
    if (g == _gCloud && _flash > 0) return true;
    if (g >= _gRim && g < _gRim + _nRealms) return _ready[g - _gRim] > 0;
    if (g == _gArcRim) return _ready[_arcI] > 0;
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
    _turnLayers();
    final ac = _fcos(_arcTurn), as = _fsin(_arcTurn);
    final warm = _wx[WildRealm.volcano.index];
    final mid = _mid;

    _syncKey();
    _litGlow.clear();
    for (var grp = 0; grp < _groups; grp++) {
      if (!_live(grp)) continue;
      final on = _fieldOn && _reach[grp].overlaps(_flowBox);
      if (grp == _gLive) {
        _stepSwaying(dt, on);
        continue;
      }
      if (!_whole(grp)) {
        _stepWorked(grp, dt, on, _isRim(grp) ? _rimAlpha(grp) : 1.0);
        continue;
      }
      // Drawn whole this frame: its batch no longer follows it.
      _liveOk[grp] = false;
      var moved = false;
      final travelling = _travelling(grp);
      for (var k = _from[grp]; k < _to[grp]; k++) {
        final hx = _hx[k], hy = _hy[k];
        final here = on;
        var bx = hx, by = hy;
        if (travelling) {
          _travel(k);
          bx = _qx;
          by = _qy;
        } else {
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
                // Heat shimmer over the lava, as warm as it is.
                final heat = _part[k] == _lava2 ? _erupt : warm;
                bx += 0.4 * heat * _fsin(2.6 * t + ph);
                by += 0.5 * heat * _fsin(3.1 * t + ph * 1.7);
              }
            default:
              break;
          }
        }
        var ox = _ox[k], oy = _oy[k], vx = _vx[k], vy = _vy[k];
        if (here || ox != 0 || oy != 0 || vx != 0 || vy != 0) {
          var fu = 0.0, fv = 0.0;
          if (here) {
            _sample(bx + ox, by + oy);
            fu = _su;
            fv = _sv;
          }
          vx += (drag * (fu - vx) - spring * ox) * dt;
          vy += (drag * (fv - vy) - spring * oy) * dt;
          ox += vx * dt;
          oy += vy * dt;
          if (!here &&
              ox.abs() < 0.05 &&
              oy.abs() < 0.05 &&
              vx.abs() < 0.5 &&
              vy.abs() < 0.5) {
            ox = oy = vx = vy = 0;
            _busy[k] = 0;
          } else {
            moved = true;
            _busy[k] = 1;
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

  /// Steps group [g], one that moves (if at all) only as a whole: only its
  /// grains in the flow or still pushed off their places do any work, and
  /// each writes itself straight into the group's batch.
  /// Steps the grains that sway every frame (the meadow, the lava and the
  /// crater), writing each into the group's batch, and their light into
  /// [_swayGlow].
  void _stepSwaying(double dt, bool on) {
    const drag = 5.0, spring = 14.0;
    const g = _gLive;
    final live = _liveOf(g), rest = _rest[g];
    final t = time;
    final warm = _wx[WildRealm.volcano.index];
    final erupt = _erupt;
    final pulse = 0.75 + 0.25 * _fsin(t * 1.6);
    final hxs = _hx, hys = _hy, oxs = _ox, oys = _oy, vxs = _vx, vys = _vy;
    final pxs = _px, pys = _py, sizes = _size2, phs = _ph, parts = _part;
    final busy = _busy, slots = _slot;
    final lxf = live._xf, rxf = rest._xf;
    final lcol = live._colors, rcol = rest._colors;
    final glow = _swayGlow..clear();
    // The realms (bits) whose grains here are on their way, and those
    // resting as dust, turning.
    var travelling = 0, dust = 0;
    for (var i = 0; i < _nRealms; i++) {
      if (_gathering(i)) {
        travelling |= 1 << i;
      } else if (_formed[i] == 0) {
        dust |= 1 << i;
      }
    }
    final realms = _realm, layers = _layer;
    var moved = false;
    for (var k = _from[g], end = _to[g]; k < end; k++) {
      final hx = hxs[k], hy = hys[k];
      final ph = phs[k];
      final part = parts[k];
      var bx = hx, by = hy;
      final bit = 1 << realms[k];
      // How far along its way it is, or -1 at rest.
      var fly = -1.0;
      if (travelling & bit != 0) {
        _travel(k);
        bx = _qx;
        by = _qy;
        fly = _qe;
      } else if (dust & bit != 0) {
        final i = realms[k];
        final c = _centre[i];
        final j = i * _layers + layers[k];
        final cs = _spinC[j], sn = _spinS[j];
        final dx = hx - c.dx, dy = hy - c.dy;
        bx = c.dx + dx * cs - dy * sn;
        by = c.dy + dx * sn + dy * cs;
      }
      if (part == _meadow) {
        // Grass in the wind, in waves crossing it.
        bx += 1.2 * _fsin(1.3 * t - hx * 0.05 + ph * 0.3);
      } else {
        // Heat shimmer over the lava, as warm as it is.
        final heat = part == _lava2 ? erupt : warm;
        bx += 0.4 * heat * _fsin(2.6 * t + ph);
        by += 0.5 * heat * _fsin(3.1 * t + ph * 1.7);
      }
      var ox = oxs[k], oy = oys[k], vx = vxs[k], vy = vys[k];
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
            ox < 0.05 &&
            ox > -0.05 &&
            oy < 0.05 &&
            oy > -0.05 &&
            vx < 0.5 &&
            vx > -0.5 &&
            vy < 0.5 &&
            vy > -0.5) {
          ox = oy = vx = vy = 0;
          busy[k] = 0;
        } else {
          moved = true;
          busy[k] = 1;
        }
        oxs[k] = ox;
        oys[k] = oy;
        vxs[k] = vx;
        vys[k] = vy;
      }
      final x = bx + ox, y = by + oy;
      pxs[k] = x;
      pys[k] = y;

      final s = slots[k];
      if (s < 0) continue;
      final j = s * 4;
      lxf[j + 2] = rxf[j + 2] + (x - hx);
      lxf[j + 3] = rxf[j + 3] + (y - hy);
      // Catching the light when pushed fast; lava and the crater glowing,
      // breathing, as warm as they are.
      final sp = (vx < 0 ? -vx : vx) + (vy < 0 ? -vy : vy);
      var rc = rcol[s];
      if (fly >= 0) {
        // Brightening from dust to its shape on the way.
        final a = _alpha[k] * (_dustAlpha + (1 - _dustAlpha) * fly);
        rc = (_byte(a) << 24) | (rc & 0xFFFFFF);
      }
      final hot = part == _lava || part == _lava2 || part == _crater;
      final heat = !hot ? 0.0 : (part == _lava2 ? erupt : warm);
      if (sp <= 30) {
        lcol[s] = rc;
        if (heat > 0.02) {
          glow.add(
            x,
            y,
            sizes[k] * 3.2,
            (_byte(0.2 * pulse * heat) << 24) | (rc & 0xFFFFFF),
          );
        }
        continue;
      }
      final lit = math.min(1.0, (sp - 30) / 400);
      final r0 = ((rc >> 16) & 0xFF) / 255, g0 = ((rc >> 8) & 0xFF) / 255;
      final b0 = (rc & 0xFF) / 255;
      final r = r0 + (1 - r0) * lit * 0.6;
      final gg = g0 + (1 - g0) * lit * 0.6;
      final bb = b0 + (1 - b0) * lit * 0.55;
      lcol[s] =
          (rc & 0xFF000000) | (_byte(r) << 16) | (_byte(gg) << 8) | _byte(bb);
      if (lit > 0.5) {
        glow.add(x, y, sizes[k] * 3, _argb(0.25 * lit, r, gg, bb));
      }
      if (heat > 0.02) {
        glow.add(x, y, sizes[k] * 3.2, _argb(0.2 * pulse * heat, r, gg, bb));
      }
    }
    _moved[g] = moved;
  }

  // The hottest loop on the map: every pushed grain, every frame.
  @pragma('vm:unsafe:no-bounds-checks')
  void _stepWorked(int g, double dt, bool on, double fade) {
    const drag = 5.0, spring = 14.0;
    final live = _liveOf(g), rest = _rest[g];
    // The group's one move: (x, y) at rest is drawn at
    // (a·x + b·y + c, d·x + e·y + f). The batch is drawn under that move,
    // so a push goes into it turned back by the inverse (ia ib / id ie).
    var a = 1.0, b = 0.0, c = 0.0, d = 0.0, e = 1.0, f = 0.0;
    // A realm's dust turns layer by layer: each its own move, set as its
    // chunks come up.
    final turning = _turning(g);
    final ri = _realmOf(g);
    var layerNow = -1;
    switch (g) {
      case _gCloud:
        c = _cloudDx;
        f = _cloudDy;
      case _gTree:
        b = _treeShear;
        c = -_treeShear * _treeBase;
      case _gArcane:
        final ac = _fcos(_arcTurn), as = _fsin(_arcTurn);
        final mx = _mid.dx, my = _mid.dy;
        a = ac;
        b = -as;
        d = as;
        e = ac;
        c = mx - mx * ac + my * as;
        f = my - mx * as - my * ac;
      default:
        if (_isSpill(g)) {
          final sa = _spillAngle(g), cs = math.cos(sa), sn = math.sin(sa);
          final o = _spillCentre(g);
          a = cs;
          b = -sn;
          d = sn;
          e = cs;
          c = o.dx - o.dx * cs + o.dy * sn;
          f = o.dy - o.dx * sn - o.dy * cs;
        }
    }
    final det = a * e - b * d;
    var ia = e / det, ib = -b / det, id = -d / det, ie = a / det;
    final spin = g == _gArcane || turning || _isSpill(g);
    final chunkLayer = _chunkLayer;

    final hxs = _hx, hys = _hy, oxs = _ox, oys = _oy, vxs = _vx, vys = _vy;
    final pxs = _px, pys = _py, sizes = _size2;
    final busy = _busy, tiles = _tile, flowAt = _tileFlow, slots = _slot;
    final lxf = live._xf, rxf = rest._xf;
    final lcol = live._colors, rcol = rest._colors;
    final fus = _fu, fvs = _fv, fw = _fieldW, fh = _fieldH;
    const inv = 1 / _cell, invTile = 1 / _tileSide;
    final tw = _tw, th = _th;
    final chunkFrom = _chunkFrom, chunkTo = _chunkTo, chunkBusy = _chunkBusy;
    final alphas = _alpha;
    // Each grain's color at rest, at this group's brightness now.
    final faded = fade != 1.0;
    if (faded) {
      for (var k = _from[g], end = _to[g]; k < end; k++) {
        final s = slots[k];
        if (s >= 0) {
          lcol[s] = (_byte(alphas[k] * fade) << 24) | (rcol[s] & 0xFFFFFF);
        }
      }
    }
    var moved = false;
    for (var ch = _chunk0[g], ce = _chunk1[g]; ch < ce; ch++) {
      if (turning && chunkLayer[ch] != layerNow) {
        layerNow = chunkLayer[ch];
        final j = ri * _layers + layerNow;
        final cs = _spinC[j], sn = _spinS[j];
        final mx = _centre[ri].dx, my = _centre[ri].dy;
        a = cs;
        b = -sn;
        d = sn;
        e = cs;
        c = mx - mx * cs + my * sn;
        f = my - mx * sn - my * cs;
        ia = cs;
        ib = sn;
        id = -sn;
        ie = cs;
      }
      var off = false;
      for (var k = chunkFrom[ch], end = chunkTo[ch]; k < end; k++) {
        var here = false;
        if (on) {
          final int ti;
          if (spin) {
            final hx = hxs[k], hy = hys[k];
            var tx = ((a * hx + b * hy + c) * invTile).toInt();
            var ty = ((d * hx + e * hy + f) * invTile).toInt();
            if (tx < 0) tx = 0;
            if (tx >= tw) tx = tw - 1;
            if (ty < 0) ty = 0;
            if (ty >= th) ty = th - 1;
            ti = ty * tw + tx;
          } else {
            ti = tiles[k];
          }
          here = flowAt[ti] != 0;
        }
        // Out of the flow and at rest: as at rest, no work.
        if (!here && busy[k] == 0) continue;
        final hx = hxs[k], hy = hys[k];
        final bx = a * hx + b * hy + c, by = d * hx + e * hy + f;
        var ox = oxs[k], oy = oys[k], vx = vxs[k], vy = vys[k];
        var fu = 0.0, fv = 0.0;
        if (here) {
          // The flow at the grain, as [_sample] has it.
          final fx = (bx + ox) * inv, fy = (by + oy) * inv;
          final gx = fx.floor(), gy = fy.floor();
          if (gx >= 0 && gy >= 0 && gx < fw - 1 && gy < fh - 1) {
            final tx = fx - gx, ty = fy - gy;
            final i = gy * fw + gx;
            final u0 = fus[i], u1 = fus[i + 1], u2 = fus[i + fw];
            final u3 = fus[i + fw + 1];
            fu =
                u0 +
                (u1 - u0) * tx +
                (u2 - u0) * ty +
                (u0 - u1 - u2 + u3) * tx * ty;
            final v0 = fvs[i], v1 = fvs[i + 1], v2 = fvs[i + fw];
            final v3 = fvs[i + fw + 1];
            fv =
                v0 +
                (v1 - v0) * tx +
                (v2 - v0) * ty +
                (v0 - v1 - v2 + v3) * tx * ty;
          }
        }
        vx += (drag * (fu - vx) - spring * ox) * dt;
        vy += (drag * (fv - vy) - spring * oy) * dt;
        ox += vx * dt;
        oy += vy * dt;
        if (!here &&
            ox < 0.05 &&
            ox > -0.05 &&
            oy < 0.05 &&
            oy > -0.05 &&
            vx < 0.5 &&
            vx > -0.5 &&
            vy < 0.5 &&
            vy > -0.5) {
          ox = oy = vx = vy = 0;
          busy[k] = 0;
        } else {
          moved = true;
          off = true;
          busy[k] = 1;
        }
        oxs[k] = ox;
        oys[k] = oy;
        vxs[k] = vx;
        vys[k] = vy;
        pxs[k] = bx + ox;
        pys[k] = by + oy;

        final s = slots[k];
        if (s < 0) continue;
        final j = s * 4;
        lxf[j + 2] = rxf[j + 2] + ia * ox + ib * oy;
        lxf[j + 3] = rxf[j + 3] + id * ox + ie * oy;
        // Catching the light when pushed fast.
        final sp = (vx < 0 ? -vx : vx) + (vy < 0 ? -vy : vy);
        final rc = faded
            ? (_byte(alphas[k] * fade) << 24) | (rcol[s] & 0xFFFFFF)
            : rcol[s];
        if (sp <= 30) {
          lcol[s] = rc;
          continue;
        }
        final lit = math.min(1.0, (sp - 30) / 400);
        final r0 = ((rc >> 16) & 0xFF) / 255, g0 = ((rc >> 8) & 0xFF) / 255;
        final b0 = (rc & 0xFF) / 255;
        final r = r0 + (1 - r0) * lit * 0.6;
        final gg = g0 + (1 - g0) * lit * 0.6;
        final bb = b0 + (1 - b0) * lit * 0.55;
        lcol[s] =
            (rc & 0xFF000000) | (_byte(r) << 16) | (_byte(gg) << 8) | _byte(bb);
        // (A rim not showing gives no light either.)
        if (lit > 0.5 && fade > 0) {
          _litGlow.add(
            bx + ox,
            by + oy,
            sizes[k] * 3,
            _argb(0.25 * lit, r, gg, bb),
          );
        }
      }
      chunkBusy[ch] = off ? 1 : 0;
    }
    _moved[g] = moved;
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
      case 1: // Lava thrown up out of the crater, falling back on the cone.
        final s = (t / _bombLife + ph) % 1.0 * _bombLife;
        return (
          x0 + (x0 - _craterAt.dx) * 2.6 * s,
          y0 - sp * s + 0.5 * _side * 1.1 * s * s,
        );
      case 2: // Smoke off the crater, leaning away on the wind; faster and
        // taller in eruption.
        const life = 6.0;
        final a = (t / life + ph) % 1.0;
        return (
          x0 + _side * (0.2 * a * a + 0.09 * a * _fsin(ph * 30 + t * 0.4)),
          y0 - a * sp * life * (1 + 0.5 * _erupt),
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
  // Ink: each color deepened, so grains read as stipple on the page and
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

  // Each group's picture at rest, the batch it was drawn from, and what
  // they were drawn for.
  final List<ui.Picture?> _pics = List.filled(_groups, null);
  // A realm's dust at rest: each layer's picture, by group.
  final List<List<ui.Picture?>> _layerPics = List.generate(
    _groups,
    (_) => List.filled(_layers, null),
  );
  final List<_Batch> _rest = List.generate(_groups, (_) => _Batch(_solid));
  final List<bool> _restOk = List.filled(_groups, false);
  final List<_Batch> _liveB = List.generate(_groups, (_) => _Batch(_solid));
  final List<bool> _liveOk = List.filled(_groups, false);
  // Light off grains pushed fast, in the groups [_stepWorked] keeps.
  final _Batch _litGlow = _Batch(_soft);
  // Light off the swaying grains: the lava's, and any pushed fast.
  final _Batch _swayGlow = _Batch(_soft);
  List<double>? _picKey;

  void _dropPictures() {
    for (var g = 0; g < _groups; g++) {
      _dropGroup(g);
    }
    for (var c = 0; c < _chunkPics.length; c++) {
      _chunkPics[c]?.dispose();
      _chunkPics[c] = null;
    }
    // (The rings of light are made where the circles were.)
    _spillShader.fillRange(0, _spillShader.length, null);
    _picKey = null;
  }

  /// Lets go of everything drawn of group [g] at rest.
  void _dropGroup(int g) {
    _pics[g]?.dispose();
    _pics[g] = null;
    for (var l = 0; l < _layers; l++) {
      _layerPics[g][l]?.dispose();
      _layerPics[g][l] = null;
    }
    if (g < _chunk1.length) {
      for (var c = _chunk0[g]; c < _chunk1[g] && c < _chunkPics.length; c++) {
        _chunkPics[c]?.dispose();
        _chunkPics[c] = null;
      }
    }
    _restOk[g] = false;
    _liveOk[g] = false;
  }

  /// Lets go of the pictures kept for the field at rest.
  void dispose() => _dropPictures();

  List<double> get _key => [
    for (var i = 0; i < _nRealms; i++) _wx[i],
    _rain[0],
    // The left run of lava's color.
    _erupt,
    ink ? 1 : 0,
  ];

  /// Grains drawn grain by grain in the last frame.
  int debugGrains = 0;

  /// Groups drawn from their picture in the last frame.
  int debugPictures = 0;

  /// Chunks of stirred groups drawn from their picture in the last frame.
  int debugChunkPictures = 0;

  /// Lava thrown and smoke risen off the Volcano in the last frame.
  int debugBombs = 0, debugSmoke = 0;

  /// Grains of the rainbow drawn in the last frame.
  int debugRainbow = 0;

  /// Grains of the Dunes' sandstorm, and glints of its glass lit, in the
  /// last frame.
  int debugSandstorm = 0, debugGlints = 0;

  /// Ice of Geode Hollow's frostfall drawn, and glints of its crystals lit,
  /// in the last frame.
  int debugFrost = 0, debugRimeGlints = 0;

  /// Light of Geode Hollow's singing drawn in the last frame.
  int debugSinging = 0;

  /// The Tidal Shelf's fog, the swell's spray and whitecaps, and its
  /// shells, drawn in the last frame.
  int debugFog = 0, debugSpray = 0, debugShells = 0;

  /// Grains of the sun's path on the Tidal Shelf lit in the last frame.
  int debugGlitter = 0;

  /// How many of the Tidal Shelf's grains are sea (tests: the higher the
  /// tide, the more sea).
  int get debugSeaGrains {
    var n = 0;
    for (var k = 0; k < _n; k++) {
      if (_part[k] == _sea) n++;
    }
    return n;
  }

  /// Grains of Arcane's weather (meteors, northern lights) drawn in the
  /// last frame.
  int debugArcaneSky = 0;

  /// Meteors flying across Arcane's disc now.
  int get debugMeteors {
    var n = 0;
    for (var k = 0; k < _meteorCap; k++) {
      final age = time - _mtBorn[k];
      if (age >= 0 && age < _mtLife[k]) n++;
    }
    return n;
  }

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

  /// Whether lightning is lighting the cloud from inside.
  bool get debugFlickering => _flickAge < 0.05 && _flickPath.isNotEmpty;

  void paint(Canvas canvas) {
    if (_size.isEmpty) return;
    _atlas ??= _buildAtlas();
    debugGrains = 0;
    debugPictures = 0;
    debugChunkPictures = 0;
    debugBombs = debugSmoke = debugRainbow = debugArcaneSky = 0;
    debugSandstorm = debugGlints = debugFrost = debugRimeGlints = 0;
    debugSinging = 0;
    debugFog = debugSpray = debugShells = debugGlitter = 0;
    if (_syncKey()) _restepBatches();
    final dots = ink ? _inkOver : _over;

    _wash.clear();
    _paintWashes();
    if (!ink) {
      _paintSpillLight(canvas);
      _wash.draw(canvas, _atlas!, _add);
    }
    _glow.clear();

    for (var g = 0; g < _groups; g++) {
      // (The live grains' pass draws the movers and weather too, so it
      // runs even with none of its own.)
      if (_to[g] == _from[g] && g != _gLive) continue;
      if ((g == _gArcane || g == _gSpill + _arcI) && !arcane) continue;
      if (g >= _gRim && g < _gRim + _nRealms && _ready[g - _gRim] <= 0) {
        continue;
      }
      if (g == _gArcRim && (!arcane || _ready[_arcI] <= 0)) continue;
      if (_live(g)) {
        if (g == _gLive) {
          // As stepped, then the movers and weather with them.
          _dots.copyFrom(_liveOf(g));
          _glow.appendFrom(_swayGlow);
          _paintMovers();
          _paintWeather();
          _paintDunes();
          _paintGeode();
          _paintTidal();
          debugGrains += _dots.n;
          _dots.draw(canvas, _atlas!, dots);
        } else if (_whole(g)) {
          _dots.clear();
          _emit(g);
          if (g == _gLive) {
            // Movers and weather draw with the live grains.
            _paintMovers();
            _paintWeather();
            _paintDunes();
            _paintGeode();
            _paintTidal();
          }
          debugGrains += _dots.n;
          _dots.draw(canvas, _atlas!, dots);
        } else {
          // Its batch: as at rest, with each grain the flow has pushed
          // where it is now.
          if (_isRim(g)) {
            final b = _liveOf(g);
            debugGrains += b.n;
            b.draw(canvas, _atlas!, dots);
          } else if (_turning(g)) {
            for (var l = 0; l < _layers; l++) {
              _drawTurned(
                canvas,
                g,
                l,
                () => _drawChunks(canvas, g, dots, layer: l),
              );
            }
          } else {
            _drawMoved(canvas, g, () => _drawChunks(canvas, g, dots));
          }
        }
        continue;
      }
      if (_turning(g)) {
        // Dust: each layer its own picture, turned its own way.
        for (var l = 0; l < _layers; l++) {
          final pic = _layerPic(g, l, dots);
          if (pic == null) continue;
          debugPictures++;
          _drawTurned(canvas, g, l, () => canvas.drawPicture(pic));
        }
        continue;
      }
      var pic = _pics[g];
      if (pic == null) {
        final rec = ui.PictureRecorder();
        _restOf(g).draw(Canvas(rec), _atlas!, dots);
        pic = _pics[g] = rec.endRecording();
      }
      debugPictures++;
      _drawMoved(canvas, g, () => canvas.drawPicture(pic!));
    }
    _paintRainbow(canvas);
    _paintArcaneSky(canvas);
    _paintRimGlow();
    _litGlow.draw(canvas, _atlas!, ink ? _inkGlow : _add);
    _glow.draw(canvas, _atlas!, ink ? _inkGlow : _add);
  }

  /// Drops what was drawn for other weather (or ink); whether it did.
  bool _syncKey() {
    final key = _key;
    if (_sameKey(key, _picKey)) return false;
    _dropPictures();
    _picKey = key;
    return true;
  }

  /// The batches rebuilt at rest in new colors, with every grain put back
  /// where the last step left it (no time passing).
  void _restepBatches() {
    _litGlow.clear();
    for (var g = 0; g < _groups; g++) {
      if (!_live(g)) continue;
      if (g == _gLive) {
        _stepSwaying(0, false);
      } else if (!_whole(g)) {
        _stepWorked(g, 0, false, _isRim(g) ? _rimAlpha(g) : 1.0);
      }
    }
  }

  /// [draw] done with group [g]'s one move this frame.
  void _drawMoved(Canvas canvas, int g, void Function() draw) {
    switch (g) {
      case _gCloud:
        canvas
          ..save()
          ..translate(_cloudDx, _cloudDy);
      case _gTree:
        canvas
          ..save()
          ..translate(0, _treeBase)
          ..skew(_treeShear, 0)
          ..translate(0, -_treeBase);
      case _gArcane:
        canvas
          ..save()
          ..translate(_mid.dx, _mid.dy)
          ..rotate(_arcTurn)
          ..translate(-_mid.dx, -_mid.dy);
      default:
        if (!_isSpill(g)) {
          draw();
          return;
        }
        final c = _spillCentre(g);
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..rotate(_spillAngle(g))
          ..translate(-c.dx, -c.dy);
    }
    draw();
    canvas.restore();
  }

  /// [draw] done with layer [l] of group [g]'s dust turned as it is now.
  void _drawTurned(Canvas canvas, int g, int l, void Function() draw) {
    final i = _realmOf(g);
    final c = _centre[i];
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(_spinA[i * _layers + l])
      ..translate(-c.dx, -c.dy);
    draw();
    canvas.restore();
  }

  /// Layer [l] of group [g]'s dust at rest, as one picture; null if the
  /// layer has no grains.
  ui.Picture? _layerPic(int g, int l, Paint dots) {
    final had = _layerPics[g][l];
    if (had != null) return had;
    final rest = _restOf(g);
    var s0 = -1, s1 = -1;
    for (var c = _chunk0[g]; c < _chunk1[g]; c++) {
      if (_chunkLayer[c] != l) continue;
      if (s0 < 0) s0 = _chunkS0[c];
      s1 = _chunkS1[c];
    }
    if (s0 < 0 || s1 <= s0) return null;
    final rec = ui.PictureRecorder();
    rest.draw(Canvas(rec), _atlas!, dots, from: s0, to: s1);
    return _layerPics[g][l] = rec.endRecording();
  }

  /// Stirred group [g], chunk by chunk: each one at rest from its picture,
  /// each run of pushed ones from the group's batch in one go. With
  /// [layer], only that layer's chunks.
  void _drawChunks(Canvas canvas, int g, Paint dots, {int? layer}) {
    final live = _liveOf(g), rest = _rest[g];
    final atlas = _atlas!;
    var run = -1, end = 0;
    void flush() {
      if (run < 0) return;
      live.draw(canvas, atlas, dots, from: run, to: end);
      debugGrains += end - run;
      run = -1;
    }

    for (var c = _chunk0[g]; c < _chunk1[g]; c++) {
      if (layer != null && _chunkLayer[c] != layer) {
        flush();
        continue;
      }
      final s0 = _chunkS0[c], s1 = _chunkS1[c];
      if (s1 == s0) continue;
      if (_chunkBusy[c] != 0) {
        if (run < 0) run = s0;
        end = s1;
        continue;
      }
      flush();
      var pic = _chunkPics[c];
      if (pic == null) {
        final rec = ui.PictureRecorder();
        rest.draw(Canvas(rec), atlas, dots, from: s0, to: s1);
        pic = _chunkPics[c] = rec.endRecording();
      }
      canvas.drawPicture(pic);
      debugChunkPictures++;
    }
    flush();
  }

  /// Group [g]'s grains at their places, in one batch: what its picture
  /// draws, and what a stirred frame starts from.
  _Batch _restOf(int g) {
    final b = _rest[g];
    if (!_restOk[g]) {
      b.clear();
      _emitAtRest(g, b);
      _restOk[g] = true;
    }
    return b;
  }

  /// Group [g]'s batch as it is now: at rest, but for the grains the flow
  /// has pushed, which [_stepWorked] keeps up to date in it.
  _Batch _liveOf(int g) {
    final rest = _restOf(g);
    final b = _liveB[g];
    if (!_liveOk[g]) {
      b.copyFrom(rest);
      _liveOk[g] = true;
    }
    return b;
  }

  static bool _sameKey(List<double> a, List<double>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // A grain's color under its realm's weather, set by [_color].
  double _cr = 0, _cg = 0, _cb = 0;
  void _color(int k) {
    final ri = _realm[k];
    // The left run of lava wakes only in eruption.
    final w = ri >= _nRealms ? 0.0 : (_part[k] == _lava2 ? _erupt : _wx[ri]);
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

  /// Group [g]'s grains at their places, into [into], each noting its
  /// place there.
  void _emitAtRest(int g, _Batch into) {
    for (var c = _chunk0[g]; c < _chunk1[g]; c++) {
      _chunkS0[c] = into.n;
      for (var k = _chunkFrom[c]; k < _chunkTo[c]; k++) {
        _color(k);
        _slot[k] = into.add(
          _hx[k],
          _hy[k],
          _size2[k],
          _argb(_alpha[k] * _restAlpha(k), _cr, _cg, _cb),
        );
      }
      _chunkS1[c] = into.n;
    }
    if (_chunk1[g] > _chunk0[g]) return;
    for (var k = _from[g]; k < _to[g]; k++) {
      _color(k);
      _slot[k] = into.add(
        _hx[k],
        _hy[k],
        _size2[k],
        _argb(_alpha[k] * _restAlpha(k), _cr, _cg, _cb),
      );
    }
  }

  /// How bright grain [k] is where it rests: dimmer as dust.
  double _restAlpha(int k) {
    final i = _realm[k];
    return i < _nRealms && _formed[i] == 0 && _isShape(_part[k])
        ? _dustAlpha
        : 1;
  }

  /// Group [g]'s grains where they are this frame, catching the light when
  /// pushed, and the Sky's when lightning flashes.
  void _emit(int g) {
    final flash = g == _gCloud ? _flash * _wx[WildRealm.sky.index] : 0.0;
    final bolt = _bolt.isNotEmpty ? _bolt.first : null;
    final t = time;
    final travelling = _travelling(g);
    for (var k = _from[g]; k < _to[g]; k++) {
      _color(k);
      var r = _cr, gg = _cg, b = _cb, a = _alpha[k];
      final x = _px[k], y = _py[k];
      if (travelling) {
        final i = _realm[k];
        final s = _clamp01((_form[i] - _delay[k]) / (1 - _stagger));
        a *= _dustAlpha + (1 - _dustAlpha) * s;
      }
      if (_part[k] == _rim) {
        // A realm with something waiting: its rim pulses.
        final pulse = 0.5 + 0.5 * _fsin(t * 2.4 + _pulseAt(_realm[k]));
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
      var lit = sp > 30 ? math.min(1.0, (sp - 30) / 400) : 0.0;
      if (travelling) {
        // Catching the light on its way, most at mid-flight.
        final i = _realm[k];
        final s = _clamp01((_form[i] - _delay[k]) / (1 - _stagger));
        lit = math.max(lit, 0.28 * _fsin(math.pi * s));
      }
      r = r * l + (1 - r) * lit * 0.6;
      gg = gg * l + (1 - gg) * lit * 0.6;
      b = b * l + (1 - b) * lit * 0.55;
      _dots.add(x, y, _size2[k], _argb(a, r, gg, b));
      if (lit > 0.5) {
        _glow.add(x, y, _size2[k] * 3, _argb(0.25 * lit, r, gg, b));
      }
      final p = _part[k];
      if (p == _lava || p == _lava2 || p == _crater) {
        // Lava and the crater glow, breathing, as warm as they are.
        final heat = p == _lava2 ? _erupt : _wx[WildRealm.volcano.index];
        if (heat > 0.02) {
          final pulse = 0.75 + 0.25 * _fsin(t * 1.6);
          _glow.add(x, y, _size2[k] * 3.2, _argb(0.2 * pulse * heat, r, gg, b));
        }
      }
    }
  }

  /// Soft green light along each waiting realm's rim, pulsing with it.
  void _paintRimGlow() {
    final grain = _unit;
    final t = time;
    for (var i = 0; i <= _nRealms; i++) {
      final ready = _ready[i];
      final arc = i == _arcI;
      if (ready <= 0 || (arc ? !arcane : !_shown[i])) continue;
      final pulse = 0.5 + 0.5 * _fsin(t * 2.4 + _pulseAt(i));
      final c = arc ? _mid : _centre[i];
      final r = arc ? _circleR * _arcRimAt * 0.99 : _ringR * 0.97;
      final n = arc ? 56 : 96;
      for (var k = 0; k < n; k++) {
        final a = _tau * k / n;
        _glow.add(
          c.dx + math.cos(a) * r,
          c.dy + math.sin(a) * r,
          grain * (arc ? 0.018 : 0.024),
          _argb(0.2 * ready * (0.45 + 0.55 * pulse), 0.42, 0.9, 0.5),
        );
      }
    }
  }

  static const double _bombLife = 2.0;

  void _paintMovers() {
    final grain = _unit;
    final storm = _wx[WildRealm.sky.index];
    final o = WildRealm.volcano.index;
    // Each comes off its realm's shape: none while it is only dust.
    final wind = _form[WildRealm.sky.index];
    final dry = _wx[WildRealm.swamp.index] * _form[WildRealm.swamp.index];
    final erupt = _erupt * _form[o], smoke = _smoke * _form[o];
    for (var k = 0; k < _m; k++) {
      final kind = _mkind[k];
      if (kind == 0 && wind < 0.02) continue;
      if (kind == 3 && dry < 0.05) continue;
      if (kind == 1 && erupt < 0.02) continue;
      if (kind == 2 && smoke < 0.02) continue;
      final (x0, y0) = _moverAt(k);
      final x = x0 + _mox[k], y = y0 + _moy[k];
      switch (kind) {
        case 0:
          if (!_inCloud(x0 - _cloudDx, y0 - _cloudDy)) continue;
          _dots.add(
            x,
            y,
            grain * 0.0028,
            storm > 0.5
                ? _argb(0.5 * wind, 0.56, 0.58, 0.72)
                : _argb(0.6 * wind, 1, 1, 1),
          );
        case 1:
          final a = (time / _bombLife + _mph[k]) % 1.0;
          // Gold out of the crater, cooling to red as it flies; gone once
          // it has come down a way onto the cone.
          final below = (y0 - _craterAt.dy) / _side;
          final fade =
              (a < 0.04 ? a / 0.04 : 1.0) * _clamp01(1 - below / 0.3) * erupt;
          if (fade <= 0) continue;
          debugBombs++;
          _dots.add(
            x,
            y,
            grain * 0.0036,
            _argb(fade, 1, 0.9 - 0.45 * a, 0.5 - 0.4 * a),
          );
          _glow.add(
            x,
            y,
            grain * 0.012,
            _argb(0.4 * fade, 1, 0.6 - 0.3 * a, 0.2),
          );
        case 2:
          final a = (time / 6 + _mph[k]) % 1.0;
          // Thinning out before the edge of the Volcano's circle.
          final fade =
              (a < 0.12 ? a / 0.12 : 1 - a) *
              math.min(1.0, _zone(o, x, y) * 2.5) *
              smoke;
          if (fade <= 0.01) continue;
          debugSmoke++;
          // Grey smoke; in eruption darker ash, lit red from beneath.
          final under = _erupt * _clamp01(1 - a * 3);
          _dots.add(
            x,
            y,
            grain * (0.003 + (0.005 + 0.003 * _erupt) * a),
            _argb(
              fade * (0.55 + 0.15 * _erupt),
              0.46 - 0.12 * _erupt + 0.4 * under,
              0.42 - 0.14 * _erupt + 0.08 * under,
              0.42 - 0.14 * _erupt,
            ),
          );
        default:
          final a = (time / 5 + _mph[k]) % 1.0;
          final fade = (a < 0.15 ? a / 0.15 : 1 - a) * dry;
          _dots.add(x, y, grain * 0.003, _argb(0.5 * fade, 0.72, 0.62, 0.44));
      }
    }
  }

  void _paintWeather() {
    final grain = _unit;
    final v = WildRealm.valley.index;
    final box = _box[v];
    final top = box.top - _side * 0.12, height = _side * 1.1;

    // Rain over the mountains: falling streaks of grains, and drops
    // splashing on the meadow.
    final rain = _rain[0];
    if (rain > 0) {
      for (var k = 0; k < 240; k++) {
        final ph = _hash(k * 3 + 1), ph2 = _hash(k * 3 + 2);
        final fall = (time * (1.1 + 0.4 * ph2) + ph) % 1.0;
        final y = top + fall * height;
        final x =
            box.left + ((_hash(k * 3) * _side + fall * height * 0.18) % _side);
        final m = math.min(1.0, _zone(v, x, y) * 1.8);
        if (m < 0.05) continue;
        for (var j = 0; j < 7; j++) {
          _dots.add(
            x - j * 0.5,
            y - j * 2.3,
            grain * 0.0032,
            _argb(rain * m * (0.8 - j * 0.1), 0.82, 0.9, 1),
          );
        }
      }
      // (Splashing on the meadow: none while it is only dust.)
      final meadow = _form[v];
      for (var k = 0; k < 40 && meadow > 0.02; k++) {
        final a = (time * 2.2 + _hash(k * 7 + 5)) % 1.0;
        if (a > 0.25) continue;
        final u = 0.08 + 0.84 * _hash(k * 7 + 6);
        final e = math.sqrt(math.max(0, 1 - math.pow((u - 0.5) / 0.47, 2)));
        final p = _at(v, u, 0.9 - e * 0.05 * _hash(k * 7 + 4));
        final f = rain * meadow * (1 - a / 0.25);
        final spread = 1 + a * 14;
        _dots.add(p.dx, p.dy, grain * 0.0034, _argb(0.8 * f, 0.86, 0.92, 1));
        _dots.add(
          p.dx - spread,
          p.dy - 1,
          grain * 0.0026,
          _argb(0.6 * f, 0.86, 0.92, 1),
        );
        _dots.add(
          p.dx + spread,
          p.dy - 1,
          grain * 0.0026,
          _argb(0.6 * f, 0.86, 0.92, 1),
        );
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
        _dots.add(x, y, grain * 0.004, _argb(0.9 * snow * m, 0.95, 0.97, 1));
        _glow.add(x, y, grain * 0.01, _argb(0.35 * snow * m, 0.95, 0.97, 1));
      }
    }
    final storm = _wx[WildRealm.sky.index];
    if (storm > 0) {
      final s = WildRealm.sky.index;
      final d = Offset(_cloudDx, _cloudDy);
      // Rain out of the storm cloud's base (none while it is only dust).
      final base = _form[s];
      for (var k = 0; k < 110 && base > 0.02; k++) {
        final ph = _hash(k * 3 + 41), ph2 = _hash(k * 3 + 42);
        final fall = (time * (1.3 + 0.4 * ph2) + ph) % 1.0;
        final u = 0.16 + 0.68 * _hash(k * 3 + 40) + fall * 0.04;
        final p = _at(s, u, 0.7 + fall * 0.3) + d;
        final m = math.min(1.0, _zone(s, p.dx, p.dy) * 2) * (1 - fall * 0.6);
        if (m < 0.05) continue;
        for (var j = 0; j < 5; j++) {
          _dots.add(
            p.dx - j * 0.4,
            p.dy - j * 2.3,
            grain * 0.003,
            _argb(storm * base * m * (0.7 - j * 0.12), 0.6, 0.66, 0.82),
          );
        }
      }
      // Lightning inside the cloud: a puff lit from within, twice in
      // quick succession, and the crack it ran along.
      if (_flickAge < 0.3) {
        final age = _flickAge;
        final f =
            (age < 0.05
                ? 1.0
                : age < 0.09
                ? 0.25
                : age < 0.14
                ? 0.85
                : math.exp(-(age - 0.14) * 22)) *
            storm;
        final c = _flickAt + d;
        _glow.add(c.dx, c.dy, _flickR * 2.6, _argb(0.5 * f, 0.62, 0.64, 1));
        _glow.add(c.dx, c.dy, _flickR * 1.3, _argb(0.6 * f, 0.86, 0.86, 1));
        for (var j = 1; j < _flickPath.length; j++) {
          final a = _flickPath[j - 1] + d, b = _flickPath[j] + d;
          final steps = ((b - a).distance / 0.9).ceil();
          for (var q = 0; q < steps; q++) {
            final p = Offset.lerp(a, b, q / steps)!;
            _dots.add(p.dx, p.dy, grain * 0.004, _argb(0.9 * f, 1, 1, 1));
            if (q % 3 == 0) {
              _glow.add(
                p.dx,
                p.dy,
                grain * 0.022,
                _argb(0.22 * f, 0.76, 0.74, 1),
              );
            }
          }
        }
      }
    }

    // Lightning: the bolt, as grains, flickering out.
    if (_boltAge < 0.4 && _bolt.length > 1) {
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

/// Grains of one sprite, each its own color and size, in one atlas call.
/// Grows as it needs to and keeps its size.
class _Batch {
  _Batch(this._src);

  final Rect _src;

  /// Somewhere every sprite lies within, so drawing need not measure each
  /// one; for a field, generously round it, to hold under its groups'
  /// moves and any push.
  Rect? cull;
  Float32List _xf = Float32List(0), _rects = Float32List(0);
  Int32List _colors = Int32List(0);
  int n = 0;

  void clear() => n = 0;

  /// Adds a sprite; its place in the batch, or -1 if too faint to draw.
  int add(double x, double y, double size, int argb) {
    if ((argb >>> 24) < 3 || size <= 0) return -1;
    if (n >= _colors.length) _grow();
    final cell = _src.width;
    final s = size / cell;
    final i = n * 4;
    _xf[i] = s;
    _xf[i + 1] = 0;
    _xf[i + 2] = x - s * cell / 2;
    _xf[i + 3] = y - s * cell / 2;
    _colors[n] = argb;
    return n++;
  }

  /// Adds every sprite of [other] (of the same sprite).
  void appendFrom(_Batch other) {
    while (_colors.length < n + other.n) {
      _grow();
    }
    _xf.setRange(n * 4, (n + other.n) * 4, other._xf);
    _colors.setRange(n, n + other.n, other._colors);
    n += other.n;
  }

  /// Becomes a copy of [other] (of the same sprite).
  void copyFrom(_Batch other) {
    while (_colors.length < other.n) {
      _grow();
    }
    _xf.setRange(0, other.n * 4, other._xf);
    _colors.setRange(0, other.n, other._colors);
    n = other.n;
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

  /// Draws sprites [from]..[to] (all of them by default).
  void draw(Canvas c, ui.Image atlas, Paint paint, {int from = 0, int? to}) {
    final end = to ?? n;
    if (end <= from) return;
    c.drawRawAtlas(
      atlas,
      Float32List.sublistView(_xf, from * 4, end * 4),
      Float32List.sublistView(_rects, from * 4, end * 4),
      Int32List.sublistView(_colors, from, end),
      BlendMode.modulate,
      cull,
      paint,
    );
  }
}

int _scaleAlpha(int argb, double t) =>
    (((argb >>> 24) * t).round().clamp(0, 255) << 24) | (argb & 0xFFFFFF);

@pragma('vm:prefer-inline')
int _byte(double v) => v <= 0 ? 0 : (v >= 1 ? 255 : (v * 255).toInt());

@pragma('vm:prefer-inline')
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
