// ─────────────────────────────────────────────────────────────────────────────
//  THE SEVENTEEN PLANETS, AS SEEN FROM SPACE
//
//  One look for all of them, so they read as one system: each is a sphere
//  lit from the upper left, turning slowly on a pole that leans toward the
//  viewer. A planet paints in the same order —
//
//    back   halo in space, far halves of rings and moons
//    body   (clipped to the disc) surface colour → the night-side shade →
//           anything that glows on its own, so it still glows at night
//           → atmosphere on the limb
//    front  near halves of rings and moons
//
//  and its territory gets its own motes: embers, spores, glints, drops.
//
//  House rules (the ones every first draft broke): material, not lines —
//  filled shapes and gradient light, no hoops, no outline strokes; no blur,
//  ever, in anything painted per frame; muted where it is rock, luminous only
//  where it is lit from within; one signature idea per planet, not five.
//
//  Each planet is its own part file. test/planet_look_preview_test.dart
//  renders them; test/planet_art_budget_test.dart holds the cost.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;

import '../vfx_shapes.dart';
import 'planet_sphere.dart';

part 'accretion_disk.dart';
part 'air_planet.dart';
part 'blood_planet.dart';
part 'crystal_planet.dart';
part 'dark_planet.dart';
part 'dust_planet.dart';
part 'earth_planet.dart';
part 'ember_corona.dart';
part 'fire_planet.dart';
part 'home_effects_art.dart';
part 'ice_planet.dart';
part 'lava_planet.dart';
part 'light_planet.dart';
part 'lightning_planet.dart';
part 'mud_planet.dart';
part 'plant_planet.dart';
part 'poison_planet.dart';
part 'spirit_planet.dart';
part 'steam_planet.dart';
part 'water_planet.dart';

abstract class PlanetArt {
  PlanetArt();

  static final Map<String, PlanetArt> _cache = {};

  /// One build per planet; the planet in space, its encounter backdrop and
  /// its card on the map all share it. [seed] keeps two planets of the same
  /// element (should there ever be two) from being twins.
  factory PlanetArt.of(String element, int seed) =>
      _cache.putIfAbsent('$element:$seed', () => _create(element, seed));

  static PlanetArt _create(String element, int seed) => switch (element) {
    'Fire' => FirePlanetArt(seed),
    'Lava' => LavaPlanetArt(seed),
    'Lightning' => LightningPlanetArt(seed),
    'Water' => WaterPlanetArt(seed),
    'Ice' => IcePlanetArt(seed),
    'Steam' => SteamPlanetArt(seed),
    'Earth' => EarthPlanetArt(seed),
    'Mud' => MudPlanetArt(seed),
    'Dust' => DustPlanetArt(seed),
    'Crystal' => CrystalPlanetArt(seed),
    'Air' => AirPlanetArt(seed),
    'Plant' => PlantPlanetArt(seed),
    'Poison' => PoisonPlanetArt(seed),
    'Spirit' => SpiritPlanetArt(seed),
    'Dark' => DarkPlanetArt(seed),
    'Light' => LightPlanetArt(seed),
    'Blood' => BloodPlanetArt(seed),
    _ => throw ArgumentError('No planet art for $element'),
  };

  /// Behind the body: its light thrown into space, the far half of anything
  /// that goes round it.
  void paintBack(Canvas c, Offset p, double r, double t);

  /// The planet itself.
  void paintBody(Canvas c, Offset p, double r, double t);

  /// In front of the body: the near half of anything that goes round it.
  void paintFront(Canvas c, Offset p, double r, double t) {}

  /// How its territory tints space. Low-alpha versions of bright element
  /// colours go muddy on near-black, so each planet picks its own.
  Color get territoryTint;

  /// How strongly [territoryTint] washes the territory at its heart.
  double get territoryStrength => 0.075;

  /// What drifts loose in its territory.
  TerritoryMotes get motes;

  /// Where the ship is (world space), set by the game each frame, so a
  /// planet's loose matter — a disk, a ring — can part round it as it flies
  /// through. Null when there is no ship to answer to (previews, cards).
  Offset? wake;

  /// How far out (in planet radii) its solid parts reach — rings, a moon,
  /// orbiting rock, a corona — not counting soft halos. A card that has to
  /// fit the whole planet sizes it by this.
  double get cardReach => 1.15;

  /// The territory, beyond the wash: motes, when the view is inside it.
  /// [depth] is 1 well inside, easing to 0 at the border.
  void paintTerritory(
    Canvas c,
    Offset planet,
    Rect view,
    double depth,
    double t,
  ) => motes.paint(c, planet, view, depth, t);
}

// ── shared light ────────────────────────────────────────────────────────────

/// Where the light pool sits for a planet at [p]: off the disc, upper left,
/// so the lit side is a broad shoulder rather than a hotspot.
Offset _lightAt(Offset p, double r) => Offset(p.dx - r * 0.55, p.dy - r * 0.62);

/// Light thrown into space: one gradient fill from the limb out to [reach]
/// radii.
void _halo(
  Canvas c,
  Offset p,
  double r,
  Color col, {
  double alpha = 0.16,
  double reach = 2.3,
}) {
  final outer = r * reach;
  final at = r / outer;
  c.drawCircle(
    p,
    outer,
    Paint()
      ..shader = ui.Gradient.radial(
        p,
        outer,
        [
          col.withValues(alpha: alpha),
          col.withValues(alpha: alpha * 0.3),
          col.withValues(alpha: 0),
        ],
        [at, at + (1 - at) * 0.35, 1.0],
      ),
  );
}

/// The night side: darkness gathering toward the lower right. Paint it over
/// the surface and under anything that glows by itself.
void _shade(
  Canvas c,
  Offset p,
  double r, {
  double strength = 1,
  Color night = const Color(0xFF03030A),
}) {
  c.drawCircle(
    p,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        _lightAt(p, r),
        r * 2.2,
        [
          night.withValues(alpha: 0),
          night.withValues(alpha: 0),
          night.withValues(alpha: 0.5 * strength),
          night.withValues(alpha: 0.9 * strength),
        ],
        const [0.0, 0.36, 0.62, 0.84],
      ),
  );
}

/// Soft light on the lit shoulder. Call inside the disc clip.
void _sheen(
  Canvas c,
  Offset p,
  double r,
  Color col, {
  double alpha = 0.22,
  double size = 0.85,
}) {
  final at = Offset(p.dx - r * 0.36, p.dy - r * 0.4);
  c.drawCircle(
    at,
    r * size,
    Paint()
      ..shader = ui.Gradient.radial(at, r * size, [
        col.withValues(alpha: alpha),
        col.withValues(alpha: 0),
      ]),
  );
}

/// Atmosphere on the limb: a band of [col] that fades in over the last of
/// the surface and out into space.
void _limb(
  Canvas c,
  Offset p,
  double r,
  Color col, {
  double alpha = 0.26,
  double inner = 0.8,
  double outer = 1.12,
}) {
  final o = r * outer;
  final at = r / o;
  c.drawCircle(
    p,
    o,
    Paint()
      ..shader = ui.Gradient.radial(
        p,
        o,
        [
          col.withValues(alpha: 0),
          col.withValues(alpha: alpha),
          col.withValues(alpha: alpha * 0.3),
          col.withValues(alpha: 0),
        ],
        [inner / outer, at, at + (1 - at) * 0.45, 1.0],
      ),
  );
}

/// A filled circle as a gaussian blur of [sigma] would leave it — solid in
/// the middle, falling off over about two sigma either side of the edge —
/// drawn as one radial gradient. For the planets whose look IS soft glow and
/// fog (the originals the player preferred), at the cost of a plain fill
/// instead of a blur pass.
void _softCircle(
  Canvas c,
  Offset at,
  double radius,
  Color col,
  double sigma,
) {
  if (radius <= 0 || col.a <= 0) return;
  final outer = radius + 2 * sigma;
  final inner = max(0.0, radius - 2 * sigma);
  // A disc much smaller than its blur never reaches full strength.
  final peak = radius >= 2 * sigma
      ? 1.0
      : 1 - exp(-(radius * radius) / (2 * sigma * sigma));
  c.drawCircle(
    at,
    outer,
    Paint()
      ..shader = ui.Gradient.radial(
        at,
        outer,
        [
          col.withValues(alpha: col.a * peak),
          col.withValues(alpha: col.a * peak),
          col.withValues(alpha: 0),
        ],
        [0.0, inner / outer, 1.0],
      ),
  );
}

/// A stroked path with a soft glow, as the originals drew it with a blurred
/// stroke under a crisp one: here two wider, fainter strokes instead of the
/// blur.
void _softStroke(Canvas c, Path path, Color col, double width, double sigma) {
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  c.drawPath(path, p
    ..strokeWidth = width + sigma * 3
    ..color = col.withValues(alpha: col.a * 0.35));
  c.drawPath(path, p
    ..strokeWidth = width + sigma * 1.2
    ..color = col.withValues(alpha: col.a * 0.6));
}

/// The glow every planet used to sit in: a disc of its colour at 15%, two
/// and a half radii wide, softened.
void _oldAura(Canvas c, Offset p, double r, Color col) =>
    _softCircle(c, p, r * 2.5, col.withValues(alpha: 0.15), 30);

/// The original sphere shading: a highlight toward the upper left, the
/// colour, and a shadow toward the edge.
void _oldSphere(
  Canvas c,
  Offset p,
  double r,
  Color color, {
  double highlight = 0.4,
  double shadow = 0.6,
}) {
  c.drawCircle(
    p,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(p.dx - r * 0.3, p.dy - r * 0.3),
        r * 1.5,
        [
          Color.lerp(color, const Color(0xFFFFFFFF), highlight)!,
          color,
          Color.lerp(color, const Color(0xFF000000), shadow)!,
        ],
        const [0.0, 0.5, 1.0],
      ),
  );
}

/// Many round dots in a few draws. Points are gathered into buckets (one
/// per colour and size) and each bucket goes out as a single drawRawPoints
/// call with round caps — the GPU draws hundreds of dots in one go, where a
/// path of hundreds of ovals had to be tessellated every frame. Buffers are
/// kept between frames, so steady state allocates nothing.
class _DotBatch {
  _DotBatch(int buckets)
    : _pts = List.generate(buckets, (_) => Float32List(64)),
      _n = List.filled(buckets, 0);

  final List<Float32List> _pts;
  final List<int> _n;

  void clear() => _n.fillRange(0, _n.length, 0);

  void add(int bucket, double x, double y) {
    var buf = _pts[bucket];
    final i = _n[bucket] * 2;
    if (i + 2 > buf.length) {
      final grown = Float32List(buf.length * 2)..setAll(0, buf);
      _pts[bucket] = buf = grown;
    }
    buf[i] = x;
    buf[i + 1] = y;
    _n[bucket]++;
  }

  bool isEmpty(int bucket) => _n[bucket] == 0;

  static final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  /// Draws [bucket] as dots [diameter] across in [color].
  void draw(Canvas c, int bucket, double diameter, Color color) {
    final n = _n[bucket];
    if (n == 0 || diameter <= 0 || color.a <= 0) return;
    _paint
      ..strokeWidth = diameter
      ..color = color;
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_pts[bucket], 0, n * 2),
      _paint,
    );
  }
}

/// Pushes a point at ([x], [y]) away from [wake] — the ship, flying by —
/// when it is within [reach]; nothing otherwise. Returns the push.
Offset _wakePush(double x, double y, Offset? wake, double reach, double push) {
  if (wake == null) return Offset.zero;
  final dx = x - wake.dx, dy = y - wake.dy;
  final d2 = dx * dx + dy * dy;
  if (d2 >= reach * reach || d2 < 1e-6) return Offset.zero;
  final d = sqrt(d2);
  final k = 1 - d / reach;
  final s = push * k * k / d;
  // Swept a little sideways as well as out, so the matter swirls round the
  // ship's passage instead of just shrinking from it.
  const ca = 0.88, sa = 0.47;
  return Offset((dx * ca - dy * sa) * s, (dx * sa + dy * ca) * s);
}

/// Clips to the disc for the body's surface layers.
void _clipDisc(Canvas c, Offset p, double r) =>
    c.clipPath(Path()..addOval(Rect.fromCircle(center: p, radius: r)));

/// Draws a path built on the unit disc (see [unitView]) at [p], radius [r].
void _drawUnit(Canvas c, Offset p, double r, Path unit, Paint paint) {
  c.save();
  c.translate(p.dx, p.dy);
  c.scale(r);
  c.drawPath(unit, paint);
  c.restore();
}

/// Gathers the rings that face the viewer into one path. Rings wholly
/// round the back (their centre deeper than [cull]) are skipped.
Path _gatherRings(
  SphereView view,
  List<Float64List> rings,
  Float64List centres, {
  double cull = -0.3,
  Path? into,
}) {
  final path = into ?? Path();
  for (var i = 0; i < rings.length; i++) {
    final d = view.depthOf(
      centres[i * 3],
      centres[i * 3 + 1],
      centres[i * 3 + 2],
    );
    if (d < cull) continue;
    addSphereRing(path, view, rings[i]);
  }
  return path;
}

/// Centre points of [rings], for culling.
Float64List _ringCentres(List<Float64List> rings) {
  final out = Float64List(rings.length * 3);
  for (var i = 0; i < rings.length; i++) {
    final ring = rings[i];
    var x = 0.0, y = 0.0, z = 0.0;
    final n = ring.length ~/ 3;
    for (var k = 0; k < n; k++) {
      x += ring[k * 3];
      y += ring[k * 3 + 1];
      z += ring[k * 3 + 2];
    }
    final l = sqrt(x * x + y * y + z * z);
    out[i * 3] = x / l;
    out[i * 3 + 1] = y / l;
    out[i * 3 + 2] = z / l;
  }
  return out;
}

// ── soft features ───────────────────────────────────────────────────────────

/// A scatter of surface features — clouds, mists, pools, clots — each drawn
/// as its shape plus a faint, slightly larger copy of the same shape under
/// it. The copy softens the edge the way blur would, at the cost of one more
/// ordinary fill: without it a flat blob reads as a sticker.
class _BlobField {
  _BlobField._(this.cores, this.halos, this.sizes)
    : centres = _ringCentres(cores);

  /// [n] features at random longitudes, latitudes within ±[spread]/2
  /// (radians; pass [uniform] for an even spread over the whole sphere).
  factory _BlobField.scatter(
    Random rng,
    int n, {
    required double size,
    double spread = 2.4,
    double stretch = 1,
    double rough = 0.3,
    double soft = 1.45,
    bool uniform = false,
  }) {
    final cores = <Float64List>[];
    final halos = <Float64List>[];
    final sizes = <double>[];
    for (var i = 0; i < n; i++) {
      final lat = uniform
          ? asin(rng.nextDouble() * 2 - 1)
          : (rng.nextDouble() - 0.5) * spread;
      final (x, y, z) = sphereAt(lat, rng.nextDouble() * 2 * pi);
      final sz = size * (0.6 + rng.nextDouble() * 0.8);
      sizes.add(sz);
      final shape = rng.nextInt(1 << 30);
      cores.add(sphereBlob(x, y, z, sz, Random(shape),
          stretch: stretch, rough: rough));
      if (soft > 1) {
        halos.add(sphereBlob(x, y, z, sz * soft, Random(shape),
            stretch: stretch, rough: rough));
      }
    }
    return _BlobField._(cores, halos, sizes);
  }

  final List<Float64List> cores;
  final List<Float64List> halos;
  final Float64List centres;

  /// Each feature's radius, arc radians.
  final List<double> sizes;

  /// The front-facing cores as one path — for callers that draw it more
  /// than once (a cast shadow, then the thing itself).
  Path gather(SphereView view) => _gatherRings(view, cores, centres);

  /// Features on the limb, standing up off it: for each one within [band]
  /// of the edge, a disc centred on the edge. Draw it before the body, so
  /// only the part proud of the edge shows — the lumpy silhouette of a
  /// world covered in something.
  Path limbBumps(SphereView view, {double band = 0.14, double scale = 0.55}) {
    final path = Path();
    final p = view.center, r = view.radius;
    for (var i = 0; i < sizes.length; i++) {
      final sp = view.project(
        centres[i * 3],
        centres[i * 3 + 1],
        centres[i * 3 + 2],
      );
      if (sp.depth.abs() > band) continue;
      final rel = sp.offset - p;
      final l = rel.distance;
      if (l < 1) continue;
      path.addOval(
        Rect.fromCircle(center: p + rel / l * r, radius: r * sizes[i] * scale),
      );
    }
    return path;
  }

  void paint(
    Canvas c,
    SphereView view,
    Color col,
    double alpha, {
    double halo = 0.35,
    Color? haloCol,
  }) {
    if (halos.isNotEmpty && halo > 0) {
      c.drawPath(
        _gatherRings(view, halos, centres),
        Paint()..color = (haloCol ?? col).withValues(alpha: alpha * halo),
      );
    }
    c.drawPath(
      _gatherRings(view, cores, centres),
      Paint()..color = col.withValues(alpha: alpha),
    );
  }
}

// ── facets ──────────────────────────────────────────────────────────────────

/// Light and half-vector in view space (x right, y up, z to the eye): the
/// upper left, as everything in space is lit.
const double _lx = -0.5, _ly = 0.55, _lz = 0.67;
final (double, double, double) _half = () {
  const hx = _lx, hy = _ly, hz = _lz + 1;
  final l = sqrt(hx * hx + hy * hy + hz * hz);
  return (hx / l, hy / l, hz / l);
}();

/// A shell of flat facets — a spherical Voronoi cut — each shaded by which
/// way it faces, bucketed into a few fills; a facet swinging into line
/// between the light and the eye flashes. The Crystal planet's look, reused
/// for ice floes and obsidian. Whatever is drawn under it shows through the
/// seams.
class _FacetShell {
  _FacetShell._(this.plates, this.rings);

  factory _FacetShell(
    Random rng, {
    required int count,
    double jitter = 0.95,
    double gap = 0.01,
    double gapVar = 0,
    int sides = 16,
  }) {
    final plates = SpherePlates.fromSeeds(
      SpherePlates.spreadSeeds(count: count, rng: rng, jitter: jitter),
      sides: sides,
    );
    final rings = [
      for (var i = 0; i < plates.plateCount; i++)
        () {
          final g = gap * (1 + gapVar * pow(rng.nextDouble(), 3) * 3);
          return plates.ring(i, (k, x, y, z) => g, minFrac: 0.5);
        }(),
    ];
    return _FacetShell._(plates, rings);
  }

  final SpherePlates plates;
  final List<Float64List> rings;

  /// [ramp] runs from facing away from the light to facing it.
  void paint(
    Canvas c,
    SphereView view,
    List<Color> ramp, {
    double alpha = 1,
    Color glint = const Color(0xFFFFFFFF),
    double glintAlpha = 0.7,
    double glintPower = 40,
  }) {
    final m = view.m;
    final levels = ramp.length;
    final buckets = List.generate(levels, (_) => Path());
    final glints = <(Float64List, double)>[];
    final (hx, hy, hz) = _half;
    final s = plates.seeds;
    for (var i = 0; i < plates.plateCount; i++) {
      final x = s[i * 3], y = s[i * 3 + 1], z = s[i * 3 + 2];
      final nx = m[0] * x + m[1] * y + m[2] * z;
      final ny = m[3] * x + m[4] * y + m[5] * z;
      final nz = m[6] * x + m[7] * y + m[8] * z;
      if (nz < -0.3) continue;
      final lambert = (nx * _lx + ny * _ly + nz * _lz).clamp(0.0, 1.0);
      addSphereRing(buckets[(lambert * (levels - 1)).round()], view, rings[i]);
      if (glintAlpha > 0 && nz > 0) {
        final spec = pow((nx * hx + ny * hy + nz * hz).clamp(0.0, 1.0),
            glintPower).toDouble();
        if (spec > 0.15) glints.add((rings[i], spec));
      }
    }
    for (var k = 0; k < levels; k++) {
      c.drawPath(buckets[k], Paint()..color = ramp[k].withValues(alpha: alpha));
    }
    for (final (ring, spec) in glints) {
      final g = Path();
      addSphereRing(g, view, ring);
      c.drawPath(g, Paint()..color = glint.withValues(alpha: glintAlpha * spec));
    }
  }
}

// ── rings ───────────────────────────────────────────────────────────────────

/// A ring that moves: soft lanes of material in the planet's equatorial
/// plane, and hundreds of grains on their orbits over them — inner grains
/// faster than outer, the way a real ring shears, so clumps of them draw out
/// into arcs as they go — each twinkling on its own beat. Drawn in two
/// halves either side of the body, so the planet sits inside it.
/// (Cindrath's ring first; the player's favourite of all this work.)
class _ParticleRing {
  _ParticleRing(
    Random rng, {
    required this.spin,
    required List<(double, double, double)> lanes,
    required this.laneColor,
    required this.laneReach,
    required this.laneStops,
    required this.laneAlphas,
    required this.dim,
    required this.bright,
    int count = 340,
    int clumps = 8,
    int perClump = 18,
    this.grainSize = 0.0055,
    this.brightCut = 0.55,
    this.speed = 0.14,
  }) : grains = _strew(rng, lanes, count, clumps, perClump);

  /// Soft lanes as gradient stops and alphas, from lanes as (centre,
  /// half-width, peak alpha) in planet radii, out to [reach].
  static (List<double>, List<double>) laneProfile(
    List<(double, double, double)> lanes,
    double reach,
  ) {
    const n = 28;
    final stops = <double>[], alphas = <double>[];
    for (var i = 0; i <= n; i++) {
      final rad = reach * i / n;
      var a = 0.0;
      for (final (c, w, peak) in lanes) {
        final u = (rad - c) / w;
        a = max(a, peak * exp(-u * u));
      }
      stops.add(i / n);
      alphas.add(i == n ? 0 : a);
    }
    return (stops, alphas);
  }

  /// Orbital speed at one radius.
  final double speed;

  final SphereSpin spin;
  final Color laneColor;

  /// How far the lanes' gradient reaches, planet radii.
  final double laneReach;
  final List<double> laneStops;
  final List<double> laneAlphas;
  final Color dim, bright;
  final double grainSize;

  /// Twinkle above which a grain is drawn bright.
  final double brightCut;

  /// (radius in planet radii, starting angle, size, twinkle phase).
  final List<(double, double, double, double)> grains;

  /// Grains strewn through the lanes — (centre, half-width, weight) — most
  /// spread by the lanes' density, some gathered into clumps.
  static List<(double, double, double, double)> _strew(
    Random rng,
    List<(double, double, double)> lanes,
    int count,
    int clumps,
    int perClump,
  ) {
    final total = lanes.fold(0.0, (s, l) => s + l.$3);
    double laneRadius() {
      var pick = rng.nextDouble() * total;
      for (final (c, w, weight) in lanes) {
        pick -= weight;
        if (pick <= 0) return c + (rng.nextDouble() + rng.nextDouble() - 1) * w;
      }
      return lanes.last.$1;
    }

    final grains = <(double, double, double, double)>[];
    for (var i = 0; i < count; i++) {
      grains.add((laneRadius(), rng.nextDouble() * 2 * pi,
          0.4 + rng.nextDouble() * 0.9, rng.nextDouble() * 2 * pi));
    }
    for (var k = 0; k < clumps; k++) {
      final a = rng.nextDouble() * 2 * pi;
      final rad = laneRadius();
      for (var i = 0; i < perClump; i++) {
        grains.add((
          rad + (rng.nextDouble() - 0.5) * 0.08,
          a + (rng.nextDouble() - 0.5) * 0.35,
          0.6 + rng.nextDouble() * 1.0,
          rng.nextDouble() * 2 * pi,
        ));
      }
    }
    return grains;
  }

  // Grains for both halves, gathered once a frame in the ring's own
  // rotated frame: bucket = bright × 2 + size class.
  final _DotBatch _near = _DotBatch(4);
  final _DotBatch _far = _DotBatch(4);
  double _preparedT = double.nan;
  double _preparedR = 0;
  Offset? _preparedWake;

  void _prepare(double r, double t, Offset? wakeLocal, double flat, bool nearIsDown) {
    if (t == _preparedT && r == _preparedR && wakeLocal == _preparedWake) return;
    _preparedT = t;
    _preparedR = r;
    _preparedWake = wakeLocal;
    _near.clear();
    _far.clear();
    final reach = max(150.0, r * 0.55);
    for (final (rad, a0, size, phase) in grains) {
      final a = a0 + t * speed / (rad * sqrt(rad));
      final sy = sin(a);
      var x = cos(a) * rad * r;
      var y = sy * rad * r * flat;
      // The ship flying through parts the ring round it.
      final push = _wakePush(x, y, wakeLocal, reach, reach * 0.4);
      x += push.dx;
      y += push.dy;
      final bucket = (sin(t * 2.2 + phase) > brightCut ? 2 : 0) +
          (size > 0.85 ? 1 : 0);
      ((sy > 0) == nearIsDown ? _near : _far).add(bucket, x, y);
    }
  }

  /// The near half ([front]) or the far half. [wake] is the ship's world
  /// position, when there is one.
  void paint(
    Canvas c,
    Offset p,
    double r,
    double t, {
    required bool front,
    Offset? wake,
    Color? laneTint,
    double alpha = 1,
  }) {
    final m = spin.matrixAt(0);
    final flat = m[7].abs().clamp(0.05, 1.0);
    final angle = atan2(-m[4], m[1]) + pi / 2;
    final nearSign = m[7] > 0 ? 1.0 : -1.0;
    final far = r * 4;
    // The ship, in the ring's rotated frame.
    Offset? wakeLocal;
    if (wake != null) {
      final d = wake - p;
      final ca = cos(-angle), sa = sin(-angle);
      wakeLocal = Offset(d.dx * ca - d.dy * sa, d.dx * sa + d.dy * ca);
    }
    _prepare(r, t, wakeLocal, flat, nearSign > 0);
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(angle);
    c.clipRect(front == (nearSign > 0)
        ? Rect.fromLTRB(-far, 0, far, far)
        : Rect.fromLTRB(-far, -far, far, 0));

    // The lanes: one soft gradient in the ring's own plane.
    c.save();
    c.scale(1, flat);
    final outer = r * laneReach;
    final breathe = 0.85 + 0.15 * sin(t * 0.4);
    c.drawCircle(
      Offset.zero,
      outer,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          outer,
          [
            for (final a in laneAlphas)
              (laneTint ?? laneColor).withValues(alpha: a * breathe * alpha),
          ],
          laneStops,
        ),
    );
    c.restore();

    // The grains: four batched point draws for the half.
    final batch = front ? _near : _far;
    for (var b = 0; b < 4; b++) {
      final d = r * grainSize * ((b & 1) == 1 ? 1.2 : 0.75) * 2;
      final col = b >= 2 ? bright : dim;
      batch.draw(c, b, d, alpha >= 1 ? col : col.withValues(alpha: col.a * alpha));
    }
    c.restore();
  }
}

// ── territory motes ─────────────────────────────────────────────────────────

enum MoteMotion {
  /// Carried away from the planet.
  outward,

  /// Drawn in toward it, turning as they go.
  inward,

  /// Going round it.
  orbit,

  /// Wandering where they are.
  drift,

  /// Staying put and catching the light.
  twinkle,
}

enum MoteShape {
  dot,
  streak,
  drop,
  leaf,
  shard,
  bubble,
  puff,
  pebble,
}

/// Loose matter in a planet's territory. Placed by hashing world tiles, so
/// nothing is stored and a mote is where it was when you come back; each
/// runs a life cycle — born, carried [travel] world units, gone — then
/// begins again where it started.
class TerritoryMotes {
  const TerritoryMotes({
    required this.born,
    required this.mid,
    required this.dying,
    this.motion = MoteMotion.drift,
    this.shape = MoteShape.dot,
    this.tile = 360,
    this.perTile = 3,
    this.speed = 0.05,
    this.travel = 160,
    this.size = 1.6,
    this.alpha = 0.8,
    this.glow = true,
    this.spin = 0.6,
  });

  /// Colour over a life: born → mid → dying.
  final Color born, mid, dying;
  final MoteMotion motion;
  final MoteShape shape;
  final double tile;
  final int perTile;

  /// Lives per second, roughly (each mote varies ±40%).
  final double speed;
  final double travel;
  final double size;
  final double alpha;
  final bool glow;

  /// How fast shaped motes tumble, radians a second.
  final double spin;

  static const _cap = 90;

  /// Life is drawn in [_stages] steps: each mote's colour and strength are
  /// its stage's, so motes can be gathered and drawn a stage at a time.
  static const _stages = 6;

  // Scratch batches, shared: only one territory is painted in a frame.
  static final _DotBatch _dots = _DotBatch(_stages * 2);
  static final _DotBatch _spots = _DotBatch(_stages);
  static final List<Path> _paths = List.generate(_stages * 3, (_) => Path());

  void paint(Canvas c, Offset planet, Rect view, double depth, double t) {
    _dots.clear();
    _spots.clear();
    for (final path in _paths) {
      path.reset();
    }
    final x0 = (view.left / tile).floor() - 1;
    final y0 = (view.top / tile).floor() - 1;
    final x1 = (view.right / tile).ceil() + 1;
    final y1 = (view.bottom / tile).ceil() + 1;
    final cull = view.inflate(40);
    var drawn = 0;
    for (var tx = x0; tx <= x1 && drawn < _cap; tx++) {
      for (var ty = y0; ty <= y1 && drawn < _cap; ty++) {
        for (var k = 0; k < perTile; k++) {
          var h = (tx * 73856093) ^ (ty * 19349663) ^ (k * 83492791);
          h = (h ^ (h >> 13)) * 1274126177;
          final fx = (h & 0xffff) / 65536.0;
          final fy = ((h >> 16) & 0xffff) / 65536.0;
          final ph = ((h >> 32) & 0xff) / 256.0;
          final rate = speed * (0.6 + 0.8 * ((h >> 40) & 0xf) / 15.0);
          final big = ((h >> 44) & 0x3) >= 2;
          final sz = size * (big ? 1.15 : 0.8);
          final base = Offset((tx + fx) * tile, (ty + fy) * tile);
          final life = (t * rate + ph) % 1.0;
          final stage = min(_stages - 1, (life * _stages).floor());
          if (_stageAlpha(stage, depth) < 0.01) continue;
          final (pos, heading) = _place(base, planet, life, ph, t);
          if (!cull.contains(pos)) continue;
          _gather(pos, heading, sz, big, stage, ph, t, c, depth);
          drawn++;
        }
      }
    }
    _flush(c, depth);
  }

  /// A stage's colour: born → mid → dying over the life.
  Color _stageColor(int stage) {
    final life = (stage + 0.5) / _stages;
    return life < 0.4
        ? Color.lerp(born, mid, life / 0.4)!
        : Color.lerp(mid, dying, (life - 0.4) / 0.6)!;
  }

  /// A stage's strength: fading in and out over the life.
  double _stageAlpha(int stage, double depth) {
    final life = (stage + 0.5) / _stages;
    final fade = motion == MoteMotion.twinkle
        ? pow(sin(life * pi), 3).toDouble()
        : (life < 0.12 ? life / 0.12 : 1.0) * (1 - life * life);
    return fade * depth * alpha;
  }

  /// One mote into the batches.
  void _gather(Offset pos, double heading, double sz, bool big, int stage,
      double ph, double t, Canvas c, double depth) {
    final tumble = ph * 2 * pi + t * spin * (ph > 0.5 ? 1 : -1);
    switch (shape) {
      case MoteShape.dot:
        _dots.add(stage * 2 + (big ? 1 : 0), pos.dx, pos.dy);
      case MoteShape.streak:
        _dots.add(stage * 2 + (big ? 1 : 0), pos.dx, pos.dy);
        _paths[stage].addPath(vfxDrop(pos, sz * 0.9, heading), Offset.zero);
      case MoteShape.drop:
        _paths[stage].addPath(vfxDrop(pos, sz * 1.2, heading), Offset.zero);
        _spots.add(stage, pos.dx - sz * 0.35, pos.dy - sz * 0.35);
      case MoteShape.leaf:
        _paths[stage].addPath(vfxLeaf(pos, sz * 4, tumble), Offset.zero);
      case MoteShape.shard:
        // Bright only while a face is toward the upper left.
        final glint = pow(max(0.0, cos(tumble - 2.4)), 6).toDouble();
        final lit = glint > 0.35;
        _paths[stage + (lit ? _stages : 0)]
            .addPath(vfxShard(pos, sz * 2.6, sz * 0.9, tumble), Offset.zero);
        if (lit) _dots.add(stage * 2 + (big ? 1 : 0), pos.dx, pos.dy);
      case MoteShape.bubble:
        _dots.add(stage * 2 + (big ? 1 : 0), pos.dx, pos.dy);
        _spots.add(stage, pos.dx - sz * 0.6, pos.dy - sz * 0.6);
      case MoteShape.puff:
        // Few of these, and each a gradient: drawn as it comes.
        final a = _stageAlpha(stage, depth);
        final col = _stageColor(stage);
        final life = (stage + 0.5) / _stages;
        final pr = sz * 9 * (0.6 + 0.8 * life);
        c.drawCircle(
          pos,
          pr,
          Paint()
            ..shader = ui.Gradient.radial(pos, pr, [
              col.withValues(alpha: 0.16 * a),
              col.withValues(alpha: 0.07 * a),
              col.withValues(alpha: 0),
            ], const [0.0, 0.5, 1.0]),
        );
      case MoteShape.pebble:
        final tone = (0.5 + 0.5 * cos(tumble - 2.4)) > 0.5 ? 1 : 0;
        _paths[stage + tone * _stages]
            .addPath(vfxBlob(pos, sz * 1.3, ph * 97, n: 6, wobble: 0.3), Offset.zero);
    }
  }

  /// Draws everything gathered: a handful of batched calls per stage.
  void _flush(Canvas c, double depth) {
    final fill = Paint();
    for (var s = 0; s < _stages; s++) {
      final a = _stageAlpha(s, depth);
      if (a < 0.01) continue;
      final col = _stageColor(s);
      for (var b = 0; b < 2; b++) {
        final bucket = s * 2 + b;
        if (_dots.isEmpty(bucket)) continue;
        final d = size * (b == 1 ? 1.15 : 0.8) * 2;
        switch (shape) {
          case MoteShape.bubble:
            _dots.draw(c, bucket, d * 1.8, col.withValues(alpha: 0.22 * a));
            _dots.draw(c, bucket, d * 1.2, col.withValues(alpha: 0.3 * a));
          case MoteShape.dot:
            if (glow) {
              _dots.draw(c, bucket, d * 2.4, col.withValues(alpha: 0.09 * a));
              _dots.draw(c, bucket, d * 1.5, col.withValues(alpha: 0.2 * a));
            }
            _dots.draw(c, bucket, d * 0.85, col.withValues(alpha: 0.9 * a));
          case MoteShape.streak:
          case MoteShape.shard:
            if (glow) {
              _dots.draw(c, bucket, d * 2.4, col.withValues(alpha: 0.07 * a));
              _dots.draw(c, bucket, d * 1.5, col.withValues(alpha: 0.16 * a));
            }
          default:
            break;
        }
      }
      switch (shape) {
        case MoteShape.streak:
        case MoteShape.drop:
        case MoteShape.leaf:
          fill.color = col.withValues(alpha: 0.88 * a);
          c.drawPath(_paths[s], fill);
        case MoteShape.shard:
          fill.color = col.withValues(alpha: 0.5 * a);
          c.drawPath(_paths[s], fill);
          fill.color = Color.lerp(col, const Color(0xFFFFFFFF), 0.6)!
              .withValues(alpha: 0.9 * a);
          c.drawPath(_paths[s + _stages], fill);
        case MoteShape.pebble:
          fill.color = dying.withValues(alpha: 0.9 * a);
          c.drawPath(_paths[s], fill);
          fill.color = Color.lerp(dying, born, 0.8)!.withValues(alpha: 0.9 * a);
          c.drawPath(_paths[s + _stages], fill);
        default:
          break;
      }
      if (!_spots.isEmpty(s)) {
        final hd = shape == MoteShape.bubble ? size * 0.8 : size * 0.6;
        _spots.draw(c, s, hd,
            const Color(0xFFFFFFFF).withValues(alpha: (shape == MoteShape.bubble ? 0.5 : 0.35) * a));
      }
    }
  }

  (Offset, double) _place(
    Offset base,
    Offset planet,
    double life,
    double ph,
    double t,
  ) {
    final away = base - planet;
    final dist = max(1.0, away.distance);
    final dir = away / dist;
    final side = Offset(-dir.dy, dir.dx);
    switch (motion) {
      case MoteMotion.outward:
        final curl = side * sin(life * pi + ph * 6) * travel * 0.12;
        final pos = base + dir * (life * travel) + curl;
        return (pos, atan2(dir.dy, dir.dx));
      case MoteMotion.inward:
        // Spiralling in: falls a little, turns a lot.
        final fall = life * travel;
        final turn = life * travel * 1.6 / dist;
        final ang = atan2(away.dy, away.dx) + turn;
        final rr = max(0.0, dist - fall);
        final pos = planet + Offset(cos(ang), sin(ang)) * rr;
        return (pos, ang + pi / 2 + 0.4);
      case MoteMotion.orbit:
        final ang = atan2(away.dy, away.dx) + life * travel / dist;
        final pos = planet + Offset(cos(ang), sin(ang)) * dist;
        return (pos, ang + pi / 2);
      case MoteMotion.drift:
        final wander = Offset(
          sin(life * 2 * pi + ph * 9) * travel * 0.35 + (life - 0.5) * travel,
          cos(life * 2 * pi * 0.7 + ph * 5) * travel * 0.35,
        );
        final heading = atan2(wander.dy, wander.dx);
        return (base + wander, heading);
      case MoteMotion.twinkle:
        return (
          base + Offset(sin(ph * 40) * 6, cos(ph * 30) * 6) * life,
          ph * 2 * pi,
        );
    }
  }
}
