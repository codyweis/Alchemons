// lib/widgets/wilderness/wild_globe.dart
//
// THE WILD AS A GLOBE. The wilderness map: a small world of grains turning
// in the dark, each biome a continent in its own field's colours — the
// Valley's green basin ringed by ridges, the Sky's isles floating over a
// cloud sea, the Swamp's jade mosaic of pools and cypress, the Volcano's
// cone with its lava fanning down to the sea. Arcane is a rift that orbits
// it like a moon.
//
// The light is the phone's hour, as every field's is, and it is fixed to the
// viewer rather than to the world: every field runs on the same hour, so
// whatever biome is turned to face you is lit the way its field will be when
// you land. Weather shows on the world itself — a storm over the Sky, rain
// or snow on the Valley, the Swamp dried out — and wild Alchemons waiting in
// a biome show as motes over it.
//
// Everything is built once: grains are points fixed to the unit sphere with
// their colour, normal and lift. A frame turns them (one 3×3 multiply each),
// lights them and draws them in a few atlas calls. No blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/planets/planet_sphere.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:flutter/painting.dart';

const double _tau = math.pi * 2;

/// The wild biomes, as continents on the globe.
enum GlobeBiome {
  valley('valley'),
  sky('sky'),
  swamp('swamp'),
  volcano('volcano');

  const GlobeBiome(this.sceneId);

  /// The scene id the map and the spawn service know it by.
  final String sceneId;

  static GlobeBiome? ofScene(String id) {
    for (final b in values) {
      if (b.sceneId == id) return b;
    }
    return null;
  }
}

/// What the globe shows besides its land: the hour, the weather on each
/// biome, the wild Alchemons waiting, and whether Arcane has opened.
class GlobeConditions {
  const GlobeConditions({
    required this.hour,
    this.weather = const {},
    this.spawns = const {},
    this.arcane = false,
    this.moon,
  });

  /// The phone's hour, 0–24, as every field reads it.
  final double hour;
  final Map<GlobeBiome, WeatherKind> weather;

  /// Wild Alchemons waiting, per biome.
  final Map<GlobeBiome, int> spawns;
  final bool arcane;

  /// The moon's lit fraction, 0–1. Null reads tonight's real phase.
  final double? moon;
}

/// Tonight's moon, as the lit fraction 0–1 of the real phase.
double globeMoonLight(DateTime now) {
  const synodic = 29.530588853;
  final days =
      now.toUtc().difference(DateTime.utc(2000, 1, 6, 18, 14)).inMinutes / 1440;
  final phase = (days / synodic) % 1;
  return (1 - math.cos(phase * _tau)) / 2;
}

/// The globe: its world, the way it is turned, and the conditions it shows.
/// Plain Dart — [step] advances it and [paint] draws it.
class WildGlobe {
  WildGlobe() : _w = _World();

  final _World _w;

  /// How far the globe is turned about its pole, and how far its north is
  /// tipped toward the viewer (radians).
  double yaw = 0;
  double lean = 0.3;

  double time = 0;
  GlobeConditions conditions = const GlobeConditions(hour: 12);

  // Weather per biome, eased toward what [conditions] asks for:
  // index = biome × 4 + WeatherKind.index.
  final Float64List _wx = Float64List(16);

  late final RiftVortexField _rift = RiftVortexField(
    grains: 560,
    ringGrains: 120,
    motes: 26,
  )..open = 1;
  static final RiftPalette _riftPalette = RiftPalette(const Color(0xFF7C3AED));

  /// The turn that brings [b] to face the viewer: (yaw, lean).
  (double, double) facing(GlobeBiome b) {
    final c = _w.continents[b.index];
    return (c.lon - math.pi / 2, c.lat.clamp(-0.1, 0.5));
  }

  void face(GlobeBiome b) {
    final f = facing(b);
    yaw = f.$1;
    lean = f.$2;
  }

  void step(double dt) {
    time += dt;
    final k = 1 - math.exp(-dt / 1.4);
    for (var i = 0; i < 16; i++) {
      _wx[i] += (_wxTarget(i) - _wx[i]) * k;
    }
    if (conditions.arcane) _rift.step(dt);
  }

  /// Snaps the weather to what [conditions] asks for, with no easing in.
  void settle() {
    for (var i = 0; i < 16; i++) {
      _wx[i] = _wxTarget(i);
    }
  }

  double _wxTarget(int i) {
    final kind = conditions.weather[GlobeBiome.values[i ~/ 4]];
    return kind != null && kind.index == i % 4 ? 1 : 0;
  }

  double _weather(GlobeBiome b, WeatherKind k) => _wx[b.index * 4 + k.index];

  /// The biome whose centre faces the viewer most squarely.
  GlobeBiome get front {
    final m = _matrix();
    var best = GlobeBiome.valley;
    var bz = -2.0;
    for (final c in _w.continents) {
      final z = m[6] * c.cx + m[7] * c.cy + m[8] * c.cz;
      if (z > bz) {
        bz = z;
        best = c.biome;
      }
    }
    return best;
  }

  Offset _lastCentre = Offset.zero;
  double _lastRadius = 0;

  /// The biome under [p] (in the coordinates the last [paint] drew in).
  GlobeBiome? biomeAt(Offset p) {
    final r = _lastRadius;
    if (r <= 0) return null;
    final x = (p.dx - _lastCentre.dx) / r, y = -(p.dy - _lastCentre.dy) / r;
    final q = x * x + y * y;
    if (q > 1) return null;
    final z = math.sqrt(1 - q);
    final m = _matrix();
    final wx = m[0] * x + m[3] * y + m[6] * z;
    final wy = m[1] * x + m[4] * y + m[7] * z;
    final wz = m[2] * x + m[5] * y + m[8] * z;
    for (final c in _w.continents) {
      if (c.inside(wx, wy, wz, 1.06)) return c.biome;
    }
    return null;
  }

  /// Where [b]'s centre shows on screen, or null round the back.
  Offset? anchorOf(GlobeBiome b) {
    final m = _matrix();
    final c = _w.continents[b.index];
    final z = m[6] * c.cx + m[7] * c.cy + m[8] * c.cz;
    if (z < 0.15) return null;
    return Offset(
      _lastCentre.dx + (m[0] * c.cx + m[1] * c.cy + m[2] * c.cz) * _lastRadius,
      _lastCentre.dy - (m[3] * c.cx + m[4] * c.cy + m[5] * c.cz) * _lastRadius,
    );
  }

  Float64List _matrix() =>
      SphereSpin(period: _tau, roll: 0, lean: lean).matrixAt(yaw);

  // ── The frame ─────────────────────────────────────────────────────────

  final _Light _l = _Light();
  late Float64List _m;
  double _cx = 0, _cy = 0, _r = 1;

  // The lights turned into the globe's own frame, so a grain is lit with
  // three multiplies rather than a turn.
  double _swx = 0, _swy = 0, _swz = 0;
  double _mwx = 0, _mwy = 0, _mwz = 0;
  double _hwx = 0, _hwy = 0, _hwz = 0;

  // Per biome (index 4 = none): how far its weather has changed its
  // colours, a tint over it, and the alpha of its weather deck.
  final Float64List _alt = Float64List(5);
  final Float64List _tintR = Float64List(5);
  final Float64List _tintG = Float64List(5);
  final Float64List _tintB = Float64List(5);
  final Float64List _deck = Float64List(5);
  final Float64List _deckAlt = Float64List(5);
  final Float64List _one = Float64List.fromList([1, 1, 1, 1, 1]);
  final Float64List _none = Float64List(5);

  static ui.Image? _atlas;
  static final Paint _over = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _add = Paint()
    ..filterQuality = FilterQuality.medium
    ..blendMode = BlendMode.plus;

  final _Batch _seaB = _Batch(24000, _solid);
  final _Batch _landB = _Batch(70000, _solid);
  final _Batch _isleB = _Batch(9000, _solid);
  final _Batch _wxB = _Batch(9000, _puff);
  final _Batch _cloudB = _Batch(9000, _puff);
  final _Batch _softB = _Batch(2000, _soft);
  final _Batch _glowB = _Batch(6000, _soft);

  /// Grains the last frame drew.
  /// Lit grains in the last frame's glow pass: lava, glints, motes and
  /// lightning.
  int get debugGlow => _glowB.n;

  /// How bright the last frame's lightning was, summed over its strikes.
  double debugFlash = 0;

  int get debugGrains =>
      _seaB.n + _landB.n + _isleB.n + _wxB.n + _softB.n + _glowB.n;

  void paint(Canvas canvas, Offset centre, double radius) {
    _lastCentre = centre;
    _lastRadius = radius;
    _cx = centre.dx;
    _cy = centre.dy;
    _r = radius;
    final m = _m = _matrix();
    final l = _l
      ..set(conditions.hour, conditions.moon ?? globeMoonLight(DateTime.now()));
    _swx = m[0] * l.sx + m[3] * l.sy + m[6] * l.sz;
    _swy = m[1] * l.sx + m[4] * l.sy + m[7] * l.sz;
    _swz = m[2] * l.sx + m[5] * l.sy + m[8] * l.sz;
    _mwx = m[0] * l.mx + m[3] * l.my + m[6] * l.mz;
    _mwy = m[1] * l.mx + m[4] * l.my + m[7] * l.mz;
    _mwz = m[2] * l.mx + m[5] * l.my + m[8] * l.mz;
    var hx = l.sx, hy = l.sy, hz = l.sz + 1;
    final hl = math.sqrt(hx * hx + hy * hy + hz * hz);
    hx /= hl;
    hy /= hl;
    hz /= hl;
    _hwx = m[0] * hx + m[3] * hy + m[6] * hz;
    _hwy = m[1] * hx + m[4] * hy + m[7] * hz;
    _hwz = m[2] * hx + m[5] * hy + m[8] * hz;
    _weatherNow();

    _atlas ??= _buildAtlas();
    final view = SphereView(centre, radius, m);

    _paintHalo(canvas);
    final rift = conditions.arcane ? _riftAt() : null;
    if (rift != null && rift.$3 < 0) _paintRift(canvas, rift);

    // The sea, and the land beneath its grains.
    canvas.drawCircle(centre, radius, Paint()..color = _ocean);
    _paintSpecular(canvas, hx, hy, hz);
    final visible = <_Continent>[
      for (final c in _w.continents)
        if (m[6] * c.cx + m[7] * c.cy + m[8] * c.cz > -math.sin(c.reach + 0.2))
          c,
    ];
    for (final c in visible) {
      if (c.shelf == null) continue;
      final p = visibleRegion(
        view,
        c.shelfLoop,
        (x, y, z) => c.inside(x, y, z, 1.075),
      );
      if (p != null) canvas.drawPath(p, Paint()..color = c.shelf!);
    }
    for (final c in visible) {
      if (c.base.a == 0) continue;
      final p = visibleRegion(
        view,
        c.baseLoop,
        (x, y, z) => c.inside(x, y, z, _Continent.baseScale),
      );
      if (p != null) canvas.drawPath(p, Paint()..color = c.base);
    }
    _paintShade(canvas);

    // Grains.
    _seaB.clear();
    _emit(_w.sea, 0, _w.sea.n, _seaB, _one, _none, twinkle: true);
    _seaB.draw(canvas, _atlas!, _over);

    _landB.clear();
    for (final c in visible) {
      final i = c.biome.index;
      _emit(_w.land, _w.landFrom[i], _w.landTo[i], _landB, _one, _alt);
    }
    _landB.draw(canvas, _atlas!, _over);
    if (visible.any((c) => c.biome == GlobeBiome.sky)) {
      _cloudB.clear();
      _emit(_w.cloud, 0, _w.cloud.n, _cloudB, _one, _none);
      _cloudB.draw(canvas, _atlas!, _over);
    }

    if (visible.any((c) => c.biome == GlobeBiome.sky)) {
      _paintIsleShadows(canvas, view);
      _isleB.clear();
      _emit(_w.under, 0, _w.under.n, _isleB, _one, _none);
      _isleB.draw(canvas, _atlas!, _over);
      _paintIsleTops(canvas);
      _isleB.clear();
      _emit(_w.isles, 0, _w.isles.n, _isleB, _one, _none);
      _isleB.draw(canvas, _atlas!, _over);
    }

    _wxB.clear();

    _emit(_w.deck, 0, _w.deck.n, _wxB, _deck, _deckAlt);
    _emitRain();
    _wxB.draw(canvas, _atlas!, _over);

    _softB.clear();
    _glowB.clear();
    _emitPlume();
    _emitSteam();
    _emitMist();
    _emitMotes();
    _softB.draw(canvas, _atlas!, _over);

    _emitLava();
    _emitFlies();
    _emitStorm();
    _glowB.draw(canvas, _atlas!, _add);

    _paintLimb(canvas);
    if (rift != null && rift.$3 >= 0) _paintRift(canvas, rift);
  }

  void _weatherNow() {
    final rain = _weather(GlobeBiome.valley, WeatherKind.rain);
    final snow = _weather(GlobeBiome.valley, WeatherKind.snow);
    final storm = _weather(GlobeBiome.sky, WeatherKind.storm);
    final dry = _weather(GlobeBiome.swamp, WeatherKind.dry);
    for (var i = 0; i < 5; i++) {
      _alt[i] = 0;
      _tintR[i] = _tintG[i] = _tintB[i] = 1;
      _deck[i] = 0;
      _deckAlt[i] = 0;
    }
    final v = GlobeBiome.valley.index, s = GlobeBiome.sky.index;
    _alt[v] = snow;
    _alt[GlobeBiome.swamp.index] = dry;
    _tintR[v] = 1 - 0.2 * rain;
    _tintG[v] = 1 - 0.16 * rain;
    _tintB[v] = 1 - 0.08 * rain;
    _tintR[s] = 1 - 0.5 * storm;
    _tintG[s] = 1 - 0.5 * storm;
    _tintB[s] = 1 - 0.38 * storm;
    _deck[v] = math.max(rain, snow);
    _deckAlt[v] = rain + snow < 1e-6 ? 0 : snow / (rain + snow);
    _deck[s] = storm;
  }

  // ── Passes ────────────────────────────────────────────────────────────

  /// Lights and places grains [from]..[to] of [g] into [out]. [alpha] and
  /// [alt] are per biome: how opaque its grains are, and how far its
  /// weather has turned their colours.
  void _emit(
    _Grains g,
    int from,
    int to,
    _Batch out,
    Float64List alpha,
    Float64List alt, {
    bool twinkle = false,
  }) {
    final m = _m;
    final m0 = m[0], m1 = m[1], m2 = m[2];
    final m3 = m[3], m4 = m[4], m5 = m[5];
    final m6 = m[6], m7 = m[7], m8 = m[8];
    final cx = _cx, cy = _cy, rad = _r;
    final l = _l;
    final swx = _swx, swy = _swy, swz = _swz;
    final mwx = _mwx, mwy = _mwy, mwz = _mwz;
    final hwx = _hwx, hwy = _hwy, hwz = _hwz;
    final t = time;
    final glint = l.sun * 1.4;
    for (var i = from; i < to; i++) {
      final bi = g.biome[i];
      final ba = alpha[bi];
      if (ba <= 0.004) continue;
      final x = g.px[i], y = g.py[i], z = g.pz[i];
      final vz = m6 * x + m7 * y + m8 * z;
      final vx = m0 * x + m1 * y + m2 * z;
      final vy = m3 * x + m4 * y + m5 * z;
      final lift = 1 + g.lift[i];
      if (vz < 0 && lift * lift * (vx * vx + vy * vy) < 1) continue;

      final nx = g.nx[i], ny = g.ny[i], nz = g.nz[i];
      var d = (nx * swx + ny * swy + nz * swz + 0.12) * (1 / 1.12);
      if (d < 0) d = 0;
      var mo = nx * mwx + ny * mwy + nz * mwz;
      if (mo < 0) mo = 0;
      final w = alt[bi] * g.aw[i];
      var r = g.r[i] + (g.ar[i] - g.r[i]) * w;
      var gg = g.g[i] + (g.ag[i] - g.g[i]) * w;
      var b = g.b[i] + (g.ab[i] - g.b[i]) * w;
      r *= _tintR[bi] * (l.ambR + l.sunR * d + l.moonR * mo);
      gg *= _tintG[bi] * (l.ambG + l.sunG * d + l.moonG * mo);
      b *= _tintB[bi] * (l.ambB + l.sunB * d + l.moonB * mo);
      final limb = 0.68 + 0.32 * (vz < 0 ? 0 : vz);
      r *= limb;
      gg *= limb;
      b *= limb;

      // Water catches the sun.
      final sp = g.spec[i] * (1 - w);
      if (sp > 0 && glint > 0) {
        var hd = nx * hwx + ny * hwy + nz * hwz;
        if (hd > 0.95) {
          hd *= hd;
          hd *= hd;
          hd *= hd;
          hd *= hd;
          hd *= hd;
          hd *= hd;
          final tw = 0.5 + 0.5 * math.sin(t * 2.3 + g.phase[i]);
          final k = sp * hd * glint * tw * tw;
          r += l.sr * k;
          gg += l.sg * k;
          b += l.sb * k;
        }
      }
      // The air thickens toward the limb.
      if (vz < 0.55) {
        final q = 1 - (vz < 0 ? 0 : vz) / 0.55;
        final k = 0.55 * q * q * q;
        final lit = 0.3 + 0.7 * d * l.sun + 0.2 * l.night;
        r += (l.airR * lit - r) * k;
        gg += (l.airG * lit - gg) * k;
        b += (l.airB * lit - b) * k;
      }
      var a = g.alpha[i] * ba;
      if (twinkle) a *= 0.6 + 0.4 * math.sin(t * 1.3 + g.phase[i]);
      out.add(
        cx + vx * lift * rad,
        cy - vy * lift * rad,
        g.size[i] * rad,
        _argb(a, r, gg, b),
      );
    }
  }

  // Projection of one point for the live passes: sets [_px], [_py], [_pz]
  // and says whether it shows.
  double _px = 0, _py = 0, _pz = 0;
  bool _project(double x, double y, double z) {
    final m = _m;
    final vz = m[6] * x + m[7] * y + m[8] * z;
    final vx = m[0] * x + m[1] * y + m[2] * z;
    final vy = m[3] * x + m[4] * y + m[5] * z;
    if (vz < 0 && vx * vx + vy * vy < 1) return false;
    _px = _cx + vx * _r;
    _py = _cy - vy * _r;
    _pz = vz;
    return true;
  }

  /// Sun on a point with unit direction (x, y, z), softened, 0–1.
  double _sunOn(double x, double y, double z, double wrap) {
    final d = (x * _swx + y * _swy + z * _swz + wrap) / (1 + wrap);
    return d < 0 ? 0 : d;
  }

  void _emitLava() {
    final g = _w.glow;
    final m = _m;
    final t = time;
    final boost = (0.5 + 0.5 * _l.night) * 1.0;
    for (var i = 0; i < g.n; i++) {
      final x = g.px[i], y = g.py[i], z = g.pz[i];
      final vz = m[6] * x + m[7] * y + m[8] * z;
      final vx = m[0] * x + m[1] * y + m[2] * z;
      final vy = m[3] * x + m[4] * y + m[5] * z;
      final lift = 1 + g.lift[i];
      if (vz < 0 && lift * lift * (vx * vx + vy * vy) < 1) continue;
      var a = g.alpha[i] * boost * (0.8 + 0.2 * math.sin(t * 1.4 + g.phase[i]));
      if (vz < 0.25) a *= (vz < 0 ? 0.0 : vz) / 0.25 * 0.7 + 0.3;
      _glowB.add(
        _cx + vx * lift * _r,
        _cy - vy * lift * _r,
        g.size[i] * _r,
        _argb(a, g.r[i], g.g[i], g.b[i]),
      );
    }
  }

  void _emitPlume() {
    final p = _w.plume;
    final v = _w.vent;
    final t = time;
    final l = _l;
    for (var i = 0; i < p.n; i++) {
      final a = (t / 7.5 + p.phase[i]) % 1.0;
      final lift = 0.084 + 0.34 * a;
      final spread = 0.008 + 0.08 * a;
      final du = 0.26 * a * math.sqrt(a) + spread * p.a[i];
      final dv = 0.03 * a + spread * p.b[i];
      var x = v.x + du * v.ex + dv * v.nx;
      var y = v.y + du * v.ey + dv * v.ny;
      var z = v.z + du * v.ez + dv * v.nz;
      final k = (1 + lift) / math.sqrt(x * x + y * y + z * z);
      x *= k;
      y *= k;
      z *= k;
      if (!_project(x, y, z)) continue;
      final d = _sunOn(x / (1 + lift), y / (1 + lift), z / (1 + lift), 0.45);
      final s = _smooth((a / 0.7).clamp(0.0, 1.0));
      final lr = l.ambR + l.sunR * d, lg = l.ambG + l.sunG * d;
      final lb = l.ambB + l.sunB * d;
      var al = a < 0.05 ? a / 0.05 : (a > 0.6 ? (1 - a) / 0.4 : 1.0);
      al *= 0.4 * _clamp01(a / 0.14);
      _softB.add(
        _px,
        _py,
        (0.016 + 0.036 * a) * _r,
        _argb(
          al,
          (0.16 + 0.3 * s) * lr,
          (0.14 + 0.27 * s) * lg,
          (0.14 + 0.26 * s) * lb,
        ),
      );
      if (a < 0.18) {
        _glowB.add(
          _px,
          _py,
          (0.02 + 0.03 * a) * _r,
          _argb((1 - a / 0.18) * 0.32 * (0.6 + 0.4 * l.night), 1, 0.48, 0.16),
        );
      }
    }
  }

  void _emitSteam() {
    final s = _w.steam;
    final t = time;
    final l = _l;
    for (var i = 0; i < s.n; i++) {
      final a = (t / 3.4 + s.phase[i]) % 1.0;
      final lift = 0.004 + 0.05 * a;
      final du = 0.02 * a + 0.014 * a * s.a[i];
      final dv = 0.014 * a * s.b[i];
      var x = s.x[i] + du * s.ex[i] + dv * s.nx[i];
      var y = s.y[i] + du * s.ey[i] + dv * s.ny[i];
      var z = s.z[i] + du * s.ez[i] + dv * s.nz[i];
      final k = (1 + lift) / math.sqrt(x * x + y * y + z * z);
      x *= k;
      y *= k;
      z *= k;
      if (!_project(x, y, z)) continue;
      final d = _sunOn(x, y, z, 0.4);
      final al = 0.36 * (a < 0.1 ? a / 0.1 : 1 - a);
      _softB.add(
        _px,
        _py,
        (0.012 + 0.024 * a) * _r,
        _argb(
          al,
          0.9 * (l.ambR + l.sunR * d),
          0.92 * (l.ambG + l.sunG * d),
          0.94 * (l.ambB + l.sunB * d),
        ),
      );
    }
  }

  void _emitMist() {
    final dry = _weather(GlobeBiome.swamp, WeatherKind.dry);
    if (dry > 0.98) return;
    final s = _w.mist;
    final t = time;
    final l = _l;
    for (var i = 0; i < s.n; i++) {
      final ph = s.phase[i];
      final du = 0.022 * math.sin(0.05 * t + ph * _tau);
      final dv = 0.012 * math.cos(0.04 * t + ph * 7);
      final lift = 0.006 + 0.004 * math.sin(0.3 * t + ph * 5);
      var x = s.x[i] + du * s.ex[i] + dv * s.nx[i];
      var y = s.y[i] + du * s.ey[i] + dv * s.ny[i];
      var z = s.z[i] + du * s.ez[i] + dv * s.nz[i];
      final k = (1 + lift) / math.sqrt(x * x + y * y + z * z);
      if (!_project(x * k, y * k, z * k)) continue;
      final d = _sunOn(x, y, z, 0.4);
      final al = 0.06 * (1 - dry) * (0.7 + 0.3 * math.sin(t * 0.4 + ph * 9));
      _softB.add(
        _px,
        _py,
        0.04 * _r,
        _argb(
          al,
          0.82 * (l.ambR + l.sunR * d),
          0.9 * (l.ambG + l.sunG * d),
          0.84 * (l.ambB + l.sunB * d),
        ),
      );
    }
  }

  void _emitFlies() {
    final night = _l.night;
    if (night < 0.05) return;
    final s = _w.flies;
    final t = time;
    for (var i = 0; i < s.n; i++) {
      final ph = s.phase[i];
      final du = 0.012 * math.sin(0.5 * t + ph * 11);
      final dv = 0.012 * math.cos(0.37 * t + ph * 17);
      final lift = 0.007 + 0.004 * math.sin(0.9 * t + ph * 5);
      var x = s.x[i] + du * s.ex[i] + dv * s.nx[i];
      var y = s.y[i] + du * s.ey[i] + dv * s.ny[i];
      var z = s.z[i] + du * s.ez[i] + dv * s.nz[i];
      final k = (1 + lift) / math.sqrt(x * x + y * y + z * z);
      if (!_project(x * k, y * k, z * k)) continue;
      final tw = 0.5 + 0.5 * math.sin(t * 2.6 + ph * 40);
      final a = night * night * tw * tw * tw * 0.95;
      if (a < 0.02) continue;
      final swamp = s.a[i] > 0.5;
      _glowB.add(
        _px,
        _py,
        0.014 * _r,
        swamp ? _argb(a, 0.7, 0.95, 0.62) : _argb(a, 0.92, 0.94, 0.55),
      );
    }
  }

  void _emitMotes() {
    final t = time;
    for (final b in GlobeBiome.values) {
      final n = math.min(conditions.spawns[b] ?? 0, 8);
      if (n <= 0) continue;
      final s = _w.motes[b.index];
      for (var i = 0; i < n && i < s.n; i++) {
        final ph = s.phase[i];
        final lift = s.a[i] + 0.006 * math.sin(1.3 * t + ph * 9);
        final k = 1 + lift;
        if (!_project(s.x[i] * k, s.y[i] * k, s.z[i] * k)) continue;
        final fade = _pz < 0.2 ? (_pz < 0 ? 0.0 : _pz / 0.2) : 1.0;
        final cx = _px, cy = _py;
        final pulse = 0.42 + 0.16 * math.sin(1.7 * t + ph * 13);
        _softB.add(cx, cy, 0.075 * _r, _argb(pulse * 0.6 * fade, 1, 0.9, 0.66));
        _glowB.add(cx, cy, 0.04 * _r, _argb(pulse * fade, 1, 0.92, 0.7));
        _glowB.add(cx, cy, 0.016 * _r, _argb(0.9 * fade, 1, 0.98, 0.9));
        // Sparks wheeling round it.
        for (var j = 0; j < 3; j++) {
          final a = t * 1.2 + j * _tau / 3 + ph * 5;
          final du = 0.016 * math.cos(a), dv = 0.016 * math.sin(a) * 0.6;
          final x = (s.x[i] + du * s.ex[i] + dv * s.nx[i]) * k;
          final y = (s.y[i] + du * s.ey[i] + dv * s.ny[i]) * k;
          final z = (s.z[i] + du * s.ez[i] + dv * s.nz[i]) * k;
          if (!_project(x, y, z)) continue;
          _glowB.add(_px, _py, 0.012 * _r, _argb(0.7 * fade, 1, 0.94, 0.78));
        }
      }
    }
  }

  void _emitStorm() {
    debugFlash = 0;
    final storm = _weather(GlobeBiome.sky, WeatherKind.storm);
    if (storm < 0.05) return;
    final s = _w.towers;
    final t = time;
    for (var i = 0; i < s.n; i++) {
      final period = 1.7 + 0.45 * i;
      final clock = t + i * 0.77;
      final k = (clock / period).floor();
      final tau = clock - k * period;
      if (_lattice(k, i, 77) < 0.42 || tau > 0.45) continue;
      final flick =
          (tau < 0.04 ? tau / 0.04 : math.exp(-(tau - 0.04) * 9)) *
          (0.62 + 0.38 * math.sin(tau * 95)) *
          storm;
      final top = 1 + s.a[i];
      if (!_project(s.x[i] * top, s.y[i] * top, s.z[i] * top)) continue;
      debugFlash += flick;
      // The flash lights the deck round it, brightest at the strike.
      _glowB.add(_px, _py, 0.6 * _r, _argb(0.42 * flick, 0.7, 0.66, 1));
      _glowB.add(_px, _py, 0.24 * _r, _argb(0.62 * flick, 0.86, 0.84, 1));
      _glowB.add(_px, _py, 0.07 * _r, _argb(0.95 * flick, 1, 1, 1));
      // The bolt: a jagged run of light from the tower down to the deck.
      var du = 0.0, dv = 0.0;
      for (var j = 0; j < 12; j++) {
        final f = j / 11;
        du += (_lattice(k, j, 91 + i) - 0.5) * 0.008;
        dv += (_lattice(k, j, 93 + i) - 0.5) * 0.008;
        final lift = 1 + s.a[i] - (s.a[i] - 0.018) * f;
        final x = (s.x[i] + du * s.ex[i] + dv * s.nx[i]) * lift;
        final y = (s.y[i] + du * s.ey[i] + dv * s.ny[i]) * lift;
        final z = (s.z[i] + du * s.ez[i] + dv * s.nz[i]) * lift;
        if (!_project(x, y, z)) continue;
        _glowB.add(_px, _py, 0.013 * _r, _argb(0.95 * flick, 0.9, 0.88, 1));
      }
    }
  }

  void _emitRain() {
    final rain = _weather(GlobeBiome.valley, WeatherKind.rain);
    if (rain < 0.02) return;
    final s = _w.rain;
    final t = time;
    final l = _l;
    for (var i = 0; i < s.n; i++) {
      final a = (t * 1.4 + s.phase[i]) % 1.0;
      final k = 1 + 0.04 * (1 - a);
      if (!_project(s.x[i] * k, s.y[i] * k, s.z[i] * k)) continue;
      final lit = l.ambG + l.sunG * 0.6;
      _wxB.add(
        _px,
        _py,
        0.006 * _r,
        _argb(0.42 * rain, 0.74 * lit, 0.8 * lit, 0.88 * lit),
      );
    }
  }

  // ── Painted layers ────────────────────────────────────────────────────

  /// The disc darkened toward night: one mesh over the sea and the land
  /// beneath the grains, so they are lit as the grains are.
  void _paintShade(Canvas canvas) {
    const rings = [
      0.0,
      0.3,
      0.5,
      0.64,
      0.75,
      0.84,
      0.9,
      0.945,
      0.975,
      0.992,
      1.0,
    ];
    const segs = 72;
    final n = rings.length * segs;
    final pos = Float32List(n * 2);
    final col = Int32List(n);
    final l = _l;
    for (var ri = 0; ri < rings.length; ri++) {
      final rr = rings[ri];
      final z = math.sqrt(math.max(0.0, 1 - rr * rr));
      for (var k = 0; k < segs; k++) {
        final a = _tau * k / segs;
        final ux = math.cos(a) * rr, uy = math.sin(a) * rr;
        final i = ri * segs + k;
        pos[i * 2] = _cx + ux * _r;
        pos[i * 2 + 1] = _cy + uy * _r;
        // View normal: screen y is down.
        final nx = ux, ny = -uy, nz = z;
        var d = (nx * l.sx + ny * l.sy + nz * l.sz + 0.12) / 1.12;
        if (d < 0) d = 0;
        var mo = nx * l.mx + ny * l.my + nz * l.mz;
        if (mo < 0) mo = 0;
        final lum =
            0.3 * (l.ambR + l.sunR * d + l.moonR * mo) +
            0.55 * (l.ambG + l.sunG * d + l.moonG * mo) +
            0.15 * (l.ambB + l.sunB * d + l.moonB * mo);
        final a2 = (1 - lum * (0.68 + 0.32 * z)).clamp(0.0, 0.94);
        col[i] = _argb(a2, 0.016, 0.024, 0.05);
      }
    }
    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        pos,
        colors: col,
        indices: _ringIndices(rings.length, segs),
      ),
      BlendMode.srcOver,
      Paint(),
    );
  }

  /// How strongly the air glows at screen angle [a] round the limb.
  double _airAt(double a) {
    final l = _l;
    final dx = math.cos(a), dy = -math.sin(a);
    final along = dx * l.sx + dy * l.sy;
    final lit = ((along + 0.3) / 1.3).clamp(0.0, 1.0);
    final behind = math.max(0.0, -l.sz);
    return 0.12 + 0.6 * lit * l.sun + 0.32 * behind * (0.6 + 0.4 * lit);
  }

  /// A soft ring of [stops] (radius, alpha share) round the disc in the
  /// air's colour, as one mesh.
  void _airRing(Canvas canvas, List<(double, double)> stops, double power) {
    const segs = 96;
    final n = stops.length * segs;
    final pos = Float32List(n * 2);
    final col = Int32List(n);
    final l = _l;
    for (var k = 0; k < segs; k++) {
      final a = _tau * k / segs;
      final glow = _airAt(a) * power;
      for (var s = 0; s < stops.length; s++) {
        final (rr, share) = stops[s];
        final i = s * segs + k;
        pos[i * 2] = _cx + math.cos(a) * rr * _r;
        pos[i * 2 + 1] = _cy + math.sin(a) * rr * _r;
        col[i] = _argb((glow * share).clamp(0.0, 0.9), l.airR, l.airG, l.airB);
      }
    }
    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        pos,
        colors: col,
        indices: _ringIndices(stops.length, segs),
      ),
      BlendMode.srcOver,
      Paint(),
    );
  }

  void _paintHalo(Canvas canvas) => _airRing(canvas, const [
    (0.97, 1.0),
    (1.03, 0.62),
    (1.1, 0.26),
    (1.2, 0.07),
    (1.32, 0.0),
  ], 0.9);

  void _paintLimb(Canvas canvas) => _airRing(canvas, const [
    (0.8, 0.0),
    (0.9, 0.12),
    (0.965, 0.42),
    (1.0, 0.6),
  ], 0.75);

  void _paintSpecular(Canvas canvas, double hx, double hy, double hz) {
    final l = _l;
    if (l.sun < 0.05 || hz <= 0) return;
    final c = Offset(_cx + hx * _r, _cy - hy * _r);
    final rr = _r * 0.42;
    final col = Color.fromARGB(
      255,
      (l.sr * 255).round().clamp(0, 255),
      (l.sg * 255).round().clamp(0, 255),
      (l.sb * 255).round().clamp(0, 255),
    );
    canvas.drawCircle(
      c,
      rr,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          rr,
          [
            col.withValues(alpha: 0.22 * l.sun),
            col.withValues(alpha: 0.08 * l.sun),
            col.withValues(alpha: 0),
          ],
          const [0, 0.4, 1],
        ),
    );
  }

  void _paintIsleShadows(Canvas canvas, SphereView view) {
    final l = _l;
    if (l.sun < 0.05) return;
    for (final isle in _w.isleList) {
      final ax = isle.x, ay = isle.y, az = isle.z;
      final ns = ax * _swx + ay * _swy + az * _swz;
      if (ns < 0.08) continue;
      final tx = _swx - ns * ax, ty = _swy - ns * ay, tz = _swz - ns * az;
      var k = isle.lift / ns * 1.7;
      if (k > 0.2) k = 0.2;
      var sx = ax - tx * k, sy = ay - ty * k, sz = az - tz * k;
      final sl = math.sqrt(sx * sx + sy * sy + sz * sz);
      sx /= sl;
      sy /= sl;
      sz /= sl;
      // The isle's own outline, laid on the cloud where its shadow falls.
      final pr = view.project(sx, sy, sz);
      if (pr.depth < 0.05) continue;
      final p = _w.continents[GlobeBiome.sky.index];
      var ex = -sz, ez = sx;
      final el = math.sqrt(ex * ex + ez * ez);
      ex /= el;
      ez /= el;
      final nx = -ez * sy, ny = ez * sx - ex * sz, nz = ex * sy;
      final path = Path();
      const sides = 28;
      for (var j = 0; j < sides; j++) {
        final th = _tau * j / sides;
        final rr =
            isle.radius *
            1.05 *
            (1 +
                0.08 * math.sin(2 * th + isle.p1) +
                0.05 * math.sin(5 * th + isle.p2) +
                0.03 * math.sin(8 * th + isle.p3));
        final cu = math.cos(th) * rr, cv = math.sin(th) * rr;
        final o = view.projectClamped(
          sx + cu * ex + cv * nx,
          sy + cv * ny,
          sz + cu * ez + cv * nz,
        );
        j == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      path.close();
      if (!p.inside(sx, sy, sz, 1.05)) continue;
      final a = (0.75 * l.sun * ns.clamp(0.0, 1.0)).clamp(0.0, 0.6);
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            pr.offset,
            isle.radius * 1.2 * _r,
            [
              const Color(0xFF16203A).withValues(alpha: a),
              const Color(0xFF16203A).withValues(alpha: a * 0.85),
              const Color(0xFF16203A).withValues(alpha: 0),
            ],
            const [0, 0.62, 1],
          ),
      );
    }
  }

  /// Each isle's top as one lit shape, so its grains lie on grass rather
  /// than on the rock beneath.
  void _paintIsleTops(Canvas canvas) {
    final l = _l;
    final m = _m;
    for (final isle in _w.isleList) {
      final cz = m[6] * isle.x + m[7] * isle.y + m[8] * isle.z;
      if (cz < 0.02) continue;
      final k = 1 + isle.lift - 0.001;
      final o = isle.top;
      final path = Path();
      for (var j = 0; j < o.length ~/ 3; j++) {
        final x = o[j * 3] * k, y = o[j * 3 + 1] * k, z = o[j * 3 + 2] * k;
        final px = _cx + (m[0] * x + m[1] * y + m[2] * z) * _r;
        final py = _cy - (m[3] * x + m[4] * y + m[5] * z) * _r;
        j == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      path.close();
      final d = _sunOn(isle.x, isle.y, isle.z, 0.12);
      final limb = 0.68 + 0.32 * cz;
      final r = 0.3 * (l.ambR + l.sunR * d) * limb;
      final g = 0.42 * (l.ambG + l.sunG * d) * limb;
      final b = 0.2 * (l.ambB + l.sunB * d) * limb;
      canvas.drawPath(path, Paint()..color = Color(_argb(1, r, g, b)));
    }
  }

  /// Arcane's rift: a small moon of its own, held up and to the right of
  /// the globe where it can always be reached, wheeling slowly on the spot.
  /// (screen x, y, view depth, radius).
  (double, double, double, double) _riftAt() {
    final a = time * _tau / 40;
    return (
      _cx + _r * (1.0 + 0.03 * math.cos(a)),
      _cy - _r * (0.98 + 0.03 * math.sin(a)),
      1,
      _r * 0.17,
    );
  }

  void _paintRift(Canvas canvas, (double, double, double, double) at) {
    _rift.paint(
      canvas,
      Size.zero,
      Offset(at.$1, at.$2),
      at.$4,
      _riftPalette,
      backdrop: false,
    );
  }
}

// ── Light ─────────────────────────────────────────────────────────────────

// (hour, sun colour, sun power, ambient colour, ambient power, air colour)
const _lightKeys = <(double, int, double, int, double, int)>[
  (0.0, 0xFF000000, 0.0, 0xFF8A9CC8, 0.2, 0xFF3A4884),
  (4.9, 0xFF000000, 0.0, 0xFF8A9CC8, 0.2, 0xFF404C8A),
  (5.6, 0xFFF0A0A0, 0.28, 0xFFB4A8CC, 0.2, 0xFF8A68A8),
  (6.3, 0xFFFFB27A, 0.72, 0xFFE2CAC0, 0.26, 0xFFFF9C6E),
  (7.6, 0xFFFFE4C4, 0.94, 0xFFEEEAE6, 0.22, 0xFFA2C6EA),
  (11.0, 0xFFFFFAF2, 1.0, 0xFFE6EEFF, 0.24, 0xFF84BCEC),
  (15.5, 0xFFFFF0DA, 1.0, 0xFFF0ECE6, 0.23, 0xFF92BEE4),
  (18.0, 0xFFFFC27C, 0.95, 0xFFE2C8AE, 0.19, 0xFFFFAE6C),
  (19.1, 0xFFFF925C, 0.72, 0xFFCAA8B6, 0.21, 0xFFFF8A5E),
  (19.8, 0xFFC4728C, 0.32, 0xFFA898C2, 0.18, 0xFF8E62A6),
  (20.6, 0xFF000000, 0.0, 0xFF8A9CC8, 0.2, 0xFF404C8A),
  (24.0, 0xFF000000, 0.0, 0xFF8A9CC8, 0.2, 0xFF3A4884),
];

/// The hour's light, in view space: the sun's direction and colour, the
/// ambient fill, the moon's direction and the air's colour.
class _Light {
  double sx = 0, sy = 0, sz = 1, mx = 0, my = 0, mz = 1;
  double sr = 1, sg = 1, sb = 1;
  double sunR = 0, sunG = 0, sunB = 0;
  double ambR = 0, ambG = 0, ambB = 0;
  double moonR = 0, moonG = 0, moonB = 0;
  double airR = 0, airG = 0, airB = 0;
  double sun = 0, night = 0;

  double _hour = double.nan, _moonLit = double.nan;

  void set(double hour, double moonLit) {
    if (hour == _hour && moonLit == _moonLit) return;
    _hour = hour;
    _moonLit = moonLit;
    final h = hour % 24;
    var i = 0;
    while (i < _lightKeys.length - 2 && _lightKeys[i + 1].$1 <= h) {
      i++;
    }
    final a = _lightKeys[i], b = _lightKeys[i + 1];
    final f = _smooth(((h - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0));
    double ch(int ca, int cb, int shift) =>
        (((ca >> shift) & 0xFF) * (1 - f) + ((cb >> shift) & 0xFF) * f) / 255;
    sr = ch(a.$2, b.$2, 16);
    sg = ch(a.$2, b.$2, 8);
    sb = ch(a.$2, b.$2, 0);
    sun = a.$3 + (b.$3 - a.$3) * f;
    final amb = a.$5 + (b.$5 - a.$5) * f;
    ambR = ch(a.$4, b.$4, 16) * amb;
    ambG = ch(a.$4, b.$4, 8) * amb;
    ambB = ch(a.$4, b.$4, 0) * amb;
    airR = ch(a.$6, b.$6, 16);
    airG = ch(a.$6, b.$6, 8);
    airB = ch(a.$6, b.$6, 0);
    // A white sun looks brighter than a red one of the same power.
    final peak = math.max(sr, math.max(sg, sb));
    final k = peak > 0 ? sun / peak : 0.0;
    sunR = sr * k;
    sunG = sg * k;
    sunB = sb * k;
    night = (1 - sun / 0.6).clamp(0.0, 1.0);

    // The sun crosses in front from left (rising) to right (setting), and
    // round the back by night.
    double theta, elev;
    if (h >= 6 && h <= 19.5) {
      final p = (h - 6) / 13.5;
      theta = -1.25 + 2.5 * p - 0.42 * math.sin(math.pi * p);
      elev = 0.18 + 0.5 * math.sin(math.pi * p);
    } else {
      final hh = h < 6 ? h + 24 : h;
      final p = (hh - 19.5) / 10.5;
      theta = 1.25 + (_tau - 2.5) * p;
      elev = 0.18 - 0.3 * math.sin(math.pi * p);
    }
    var x = math.sin(theta), y = elev, z = math.cos(theta);
    var len = math.sqrt(x * x + y * y + z * z);
    sx = x / len;
    sy = y / len;
    sz = z / len;

    // The moon, 20:00 to 05:30, crossing the same way.
    final hm = h < 12 ? h + 24 : h;
    final p = (hm - 20) / 9.5;
    var moon = 0.0;
    if (p > 0 && p < 1) {
      final th = -1.1 + 2.2 * p;
      x = math.sin(th);
      y = 0.25 + 0.4 * math.sin(math.pi * p);
      z = math.cos(th);
      len = math.sqrt(x * x + y * y + z * z);
      mx = x / len;
      my = y / len;
      mz = z / len;
      moon = 0.5 * (0.3 + 0.7 * moonLit) * math.sqrt(math.sin(math.pi * p));
    }
    moonR = 0.66 * moon;
    moonG = 0.74 * moon;
    moonB = 0.88 * moon;
  }
}

// ── Drawing grains ───────────────────────────────────────────────────────

const double _solidCell = 16, _softCell = 32;
const Rect _solid = Rect.fromLTWH(0, 0, _solidCell, _solidCell);
const Rect _soft = Rect.fromLTWH(_solidCell, 0, _softCell, _softCell);
const Rect _puff = Rect.fromLTWH(
  _solidCell + _softCell,
  0,
  _softCell,
  _softCell,
);

/// Three sprites: a grain (a solid heart, a soft rim so it minifies
/// cleanly), a soft light, and a cloud's puff (full in the middle, soft all
/// the way out, no rim).
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
          white.withValues(alpha: 0.7),
          white.withValues(alpha: 0),
        ],
        const [0, 0.62, 0.82, 1],
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
  const pc = Offset(_solidCell + _softCell * 1.5, _softCell / 2);
  c.drawCircle(
    pc,
    _softCell / 2,
    Paint()
      ..shader = ui.Gradient.radial(
        pc,
        _softCell / 2,
        [
          white,
          white.withValues(alpha: 0.88),
          white.withValues(alpha: 0.5),
          white.withValues(alpha: 0.16),
          white.withValues(alpha: 0),
        ],
        const [0, 0.3, 0.56, 0.8, 1],
      ),
  );
  return rec.endRecording().toImageSync(
    (_solidCell + _softCell * 2).toInt(),
    _softCell.toInt(),
  );
}

/// One sprite's worth of grains, each its own colour and size, drawn in one
/// atlas call. Preallocated.
class _Batch {
  _Batch(this.cap, Rect src)
    : _cell = src.width,
      _xf = Float32List(cap * 4),
      _rects = Float32List(cap * 4),
      _colors = Int32List(cap) {
    for (var i = 0; i < cap; i++) {
      _rects[i * 4] = src.left;
      _rects[i * 4 + 1] = src.top;
      _rects[i * 4 + 2] = src.right;
      _rects[i * 4 + 3] = src.bottom;
    }
  }

  final int cap;
  final double _cell;
  final Float32List _xf, _rects;
  final Int32List _colors;
  int n = 0;

  void clear() => n = 0;

  void add(double x, double y, double size, int argb) {
    if (n >= cap || (argb >>> 24) < 3) return;
    final s = size / _cell;
    final i = n * 4;
    _xf[i] = s;
    _xf[i + 1] = 0;
    _xf[i + 2] = x - s * _cell / 2;
    _xf[i + 3] = y - s * _cell / 2;
    _colors[n] = argb;
    n++;
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

final Map<int, Uint16List> _ringIndexCache = {};

/// Triangles joining [rings] rings of [segs] vertices each, ring by ring.
Uint16List _ringIndices(int rings, int segs) =>
    _ringIndexCache.putIfAbsent(rings * 1000 + segs, () {
      final idx = <int>[];
      for (var s = 0; s < rings - 1; s++) {
        for (var k = 0; k < segs; k++) {
          final a = s * segs + k, b = s * segs + (k + 1) % segs;
          idx.addAll([a, a + segs, b, b, a + segs, b + segs]);
        }
      }
      return Uint16List.fromList(idx);
    });

int _byte(double v) => v <= 0 ? 0 : (v >= 1 ? 255 : (v * 255).toInt());

int _argb(double a, double r, double g, double b) =>
    (_byte(a) << 24) | (_byte(r) << 16) | (_byte(g) << 8) | _byte(b);

// ── Noise ─────────────────────────────────────────────────────────────────

double _smooth(double t) => t * t * (3 - 2 * t);

/// A fixed pseudo-random phase for a point.
double _hashPhase(double x, double y, double z) {
  final v = math.sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453;
  return (v - v.floorToDouble()) * _tau;
}

double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

/// A lattice value on [0, 1].
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

double _fbm(double x, double y, int seed, [int octaves = 4]) {
  var sum = 0.0, amp = 0.5, norm = 0.0, f = 1.0;
  for (var o = 0; o < octaves; o++) {
    sum += amp * _noise(x * f, y * f, seed + o * 31);
    norm += amp;
    amp *= 0.5;
    f *= 2.03;
  }
  return sum / norm;
}

/// 1 at [centre] (radians), falling smoothly to 0 at [half] either side.
double _arc(double th, double centre, double half) {
  var d = (th - centre) % _tau;
  if (d > math.pi) d -= _tau;
  if (d < -math.pi) d += _tau;
  final k = 1 - d.abs() / half;
  return k <= 0 ? 0 : _smooth(k);
}

// ── The world ────────────────────────────────────────────────────────────

class _Rgb {
  const _Rgb(this.r, this.g, this.b);
  _Rgb.hex(int v)
    : r = ((v >> 16) & 0xFF) / 255,
      g = ((v >> 8) & 0xFF) / 255,
      b = (v & 0xFF) / 255;

  final double r, g, b;

  _Rgb mix(_Rgb o, double t) =>
      _Rgb(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t);
}

_Rgb _hex(int v) => _Rgb.hex(v);

const int _noBiome = 4;
const _ocean = Color(0xFF0D2834);

/// One continent: a lobed coast round a centre, with local coordinates
/// east (u) and north (v) of it in arc radians.
class _Continent {
  _Continent(
    this.biome,
    this.lat,
    this.lon,
    this.radius,
    int seed, {
    required this.base,
    this.shelf,
  }) {
    final (x, y, z) = sphereAt(lat, lon);
    cx = x;
    cy = y;
    cz = z;
    ex = -math.sin(lon);
    ey = 0;
    ez = math.cos(lon);
    nx = -math.sin(lat) * math.cos(lon);
    ny = math.cos(lat);
    nz = -math.sin(lat) * math.sin(lon);
    final rng = math.Random(seed);
    for (var k = 0; k < _ks.length; k++) {
      _amp.add(_base[k] * (0.6 + 0.8 * rng.nextDouble()));
      _ph.add(rng.nextDouble() * _tau);
    }
    reach = radius * (1 + _amp.fold(0.0, (a, b) => a + b.abs()) + 0.08);
    baseLoop = loop(baseScale);
    shelfLoop = loop(1.075);
  }

  final GlobeBiome biome;
  final double lat, lon, radius;
  final Color base;
  final Color? shelf;

  /// How far in from the coast the land beneath the grains stops.
  static const double baseScale = 0.94;
  late final double cx, cy, cz, ex, ey, ez, nx, ny, nz;
  late final double reach;
  late final Float64List baseLoop, shelfLoop;
  final List<double> _amp = [], _ph = [];
  static const _ks = [2, 3, 4, 6, 9];
  static const _base = [0.11, 0.08, 0.05, 0.035, 0.02];

  int get seed => biome.index * 1000 + 17;

  double coast(double th) {
    var s = 1.0;
    for (var k = 0; k < _ks.length; k++) {
      s += _amp[k] * math.sin(_ks[k] * th + _ph[k]);
    }
    return radius * s;
  }

  /// The ragged coast: 0 at the centre, 1 on the shore.
  double rho(double u, double v) {
    final d = math.sqrt(u * u + v * v);
    final rag = 1 + 0.14 * (_fbm(u * 15 + 50, v * 15 + 50, seed) - 0.5);
    return d / (coast(math.atan2(v, u)) * rag);
  }

  (double, double) local(double x, double y, double z) {
    final d = math.acos((x * cx + y * cy + z * cz).clamp(-1.0, 1.0));
    final pe = x * ex + y * ey + z * ez, pn = x * nx + y * ny + z * nz;
    final l = math.sqrt(pe * pe + pn * pn);
    if (l < 1e-9) return (0, 0);
    return (d * pe / l, d * pn / l);
  }

  (double, double, double) at(double u, double v) {
    final d = math.sqrt(u * u + v * v);
    if (d < 1e-9) return (cx, cy, cz);
    final cd = math.cos(d), sd = math.sin(d) / d;
    return (
      cd * cx + sd * (u * ex + v * nx),
      cd * cy + sd * (u * ey + v * ny),
      cd * cz + sd * (u * ez + v * nz),
    );
  }

  bool inside(double x, double y, double z, [double scale = 1]) {
    if (x * cx + y * cy + z * cz < math.cos(reach * scale)) return false;
    final (u, v) = local(x, y, z);
    return math.sqrt(u * u + v * v) < coast(math.atan2(v, u)) * scale;
  }

  Float64List loop(double scale, [int n = 128]) {
    final out = Float64List(n * 3);
    for (var k = 0; k < n; k++) {
      final th = _tau * k / n;
      final r = coast(th) * scale;
      final (x, y, z) = at(r * math.cos(th), r * math.sin(th));
      out[k * 3] = x;
      out[k * 3 + 1] = y;
      out[k * 3 + 2] = z;
    }
    return out;
  }
}

/// A grain as it is built.
class _G {
  _G(
    this.x,
    this.y,
    this.z,
    this.size,
    this.c, {
    required this.nx,
    required this.ny,
    required this.nz,
    this.lift = 0,
    _Rgb? alt,
    this.aw = 0,
    this.spec = 0,
    this.alpha = 1,
    this.layer = 0,
    this.biome = _noBiome,
    this.phase = 0,
  }) : alt = alt ?? c;

  final double x, y, z, nx, ny, nz, size, lift, aw, spec, alpha, phase;
  final _Rgb c, alt;
  final int layer, biome;
}

/// Grains fixed to the globe, as arrays, in the order they draw.
class _Grains {
  _Grains(List<_G> gs)
    : n = gs.length,
      px = Float32List(gs.length),
      py = Float32List(gs.length),
      pz = Float32List(gs.length),
      nx = Float32List(gs.length),
      ny = Float32List(gs.length),
      nz = Float32List(gs.length),
      lift = Float32List(gs.length),
      size = Float32List(gs.length),
      r = Float32List(gs.length),
      g = Float32List(gs.length),
      b = Float32List(gs.length),
      ar = Float32List(gs.length),
      ag = Float32List(gs.length),
      ab = Float32List(gs.length),
      aw = Float32List(gs.length),
      spec = Float32List(gs.length),
      alpha = Float32List(gs.length),
      phase = Float32List(gs.length),
      biome = Uint8List(gs.length) {
    for (var i = 0; i < n; i++) {
      final q = gs[i];
      px[i] = q.x;
      py[i] = q.y;
      pz[i] = q.z;
      nx[i] = q.nx;
      ny[i] = q.ny;
      nz[i] = q.nz;
      lift[i] = q.lift;
      size[i] = q.size;
      r[i] = q.c.r;
      g[i] = q.c.g;
      b[i] = q.c.b;
      ar[i] = q.alt.r;
      ag[i] = q.alt.g;
      ab[i] = q.alt.b;
      aw[i] = q.aw;
      spec[i] = q.spec;
      alpha[i] = q.alpha;
      phase[i] = q.phase;
      biome[i] = q.biome;
    }
  }

  final int n;
  final Float32List px, py, pz, nx, ny, nz, lift, size;
  final Float32List r, g, b, ar, ag, ab, aw, spec, alpha, phase;
  final Uint8List biome;
}

/// Points on the surface the live grains move about: each with its own
/// east/north tangents, a phase and two spare numbers.
class _Anchors {
  final List<double> _v = [];

  void add(
    double x,
    double y,
    double z, {
    double phase = 0,
    double a = 0,
    double b = 0,
  }) => _v.addAll([x, y, z, phase, a, b]);

  late final int n;
  late final Float32List x, y, z, ex, ey, ez, nx, ny, nz, phase, a, b;

  void freeze() {
    n = _v.length ~/ 6;
    x = Float32List(n);
    y = Float32List(n);
    z = Float32List(n);
    ex = Float32List(n);
    ey = Float32List(n);
    ez = Float32List(n);
    nx = Float32List(n);
    ny = Float32List(n);
    nz = Float32List(n);
    phase = Float32List(n);
    a = Float32List(n);
    b = Float32List(n);
    for (var i = 0; i < n; i++) {
      final px = _v[i * 6], py = _v[i * 6 + 1], pz = _v[i * 6 + 2];
      x[i] = px;
      y[i] = py;
      z[i] = pz;
      // East = p × up; north = east × p.
      var qx = -pz, qz = px;
      final ql = math.sqrt(qx * qx + qz * qz);
      qx /= ql;
      qz /= ql;
      ex[i] = qx;
      ey[i] = 0;
      ez[i] = qz;
      nx[i] = -qz * py;
      ny[i] = qz * px - qx * pz;
      nz[i] = qx * py;
      phase[i] = _v[i * 6 + 3];
      a[i] = _v[i * 6 + 4];
      b[i] = _v[i * 6 + 5];
    }
  }
}

/// One fixed point with its tangents.
class _Point {
  _Point(this.x, this.y, this.z) {
    var qx = -z, qz = x;
    final ql = math.sqrt(qx * qx + qz * qz);
    qx /= ql;
    qz /= ql;
    ex = qx;
    ey = 0;
    ez = qz;
    nx = -qz * y;
    ny = qz * x - qx * z;
    nz = qx * y;
  }
  final double x, y, z;
  late final double ex, ey, ez, nx, ny, nz;
}

class _Isle {
  _Isle(
    this.x,
    this.y,
    this.z,
    this.radius,
    this.lift,
    this.seed,
    this.p1,
    this.p2,
    this.p3,
  );
  final double x, y, z, radius, lift, p1, p2, p3;
  final int seed;

  /// The top's outline on the unit sphere, xyz.
  Float64List top = Float64List(0);
}

/// A polyline in a continent's local coordinates, widening from [w0] at
/// its start to [w1] at its end.
class _Path2 {
  _Path2(this.pts, this.w0, this.w1) {
    var total = 0.0;
    _at.add(0);
    for (var i = 1; i < pts.length; i++) {
      final dx = pts[i].$1 - pts[i - 1].$1, dy = pts[i].$2 - pts[i - 1].$2;
      total += math.sqrt(dx * dx + dy * dy);
      _at.add(total);
    }
    length = total;
  }

  final List<(double, double)> pts;
  final double w0, w1;
  final List<double> _at = [];
  late final double length;

  /// (distance, fraction along, width there) from the nearest point.
  (double, double, double) nearest(double u, double v) {
    var best = double.infinity, along = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final ax = pts[i - 1].$1, ay = pts[i - 1].$2;
      final dx = pts[i].$1 - ax, dy = pts[i].$2 - ay;
      final l2 = dx * dx + dy * dy;
      var s = l2 == 0 ? 0.0 : ((u - ax) * dx + (v - ay) * dy) / l2;
      s = _clamp01(s);
      final qx = ax + dx * s - u, qy = ay + dy * s - v;
      final d = qx * qx + qy * qy;
      if (d < best) {
        best = d;
        along = (_at[i - 1] + (_at[i] - _at[i - 1]) * s) / length;
      }
    }
    return (math.sqrt(best), along, w0 + (w1 - w0) * along);
  }
}

/// Builds every grain once.
class _World {
  _World() {
    continents = [
      _Continent(
        GlobeBiome.valley,
        0.30,
        0.0,
        0.58,
        3,
        base: const Color(0xFF1C2814),
        shelf: const Color(0xFF113440),
      ),
      _Continent(
        GlobeBiome.sky,
        0.48,
        math.pi / 2,
        0.54,
        7,
        base: const Color(0x00000000),
      ),
      _Continent(
        GlobeBiome.swamp,
        -0.06,
        math.pi,
        0.6,
        13,
        base: const Color(0xFF16241C),
        shelf: const Color(0xFF11363A),
      ),
      _Continent(
        GlobeBiome.volcano,
        0.1,
        math.pi * 1.5,
        0.56,
        19,
        base: const Color(0xFF140E0E),
        shelf: const Color(0xFF11323C),
      ),
    ];
    for (var i = 0; i < 4; i++) {
      motes.add(_Anchors());
    }
    final land = <List<_G>>[for (var i = 0; i < 4; i++) <_G>[]];
    final isleGrains = <_G>[], deckGrains = <_G>[], glowGrains = <_G>[];
    final underGrains = <_G>[];
    final cloudGrains = <_G>[];
    _valley(continents[0], land[0], deckGrains);
    _sky(continents[1], cloudGrains, underGrains, isleGrains, deckGrains);
    _swamp(continents[2], land[2]);
    _volcano(continents[3], land[3], glowGrains);

    final all = <_G>[];
    for (var i = 0; i < 4; i++) {
      final l = land[i]
        ..sort((a, b) {
          final c = a.layer.compareTo(b.layer);
          return c != 0 ? c : a.lift.compareTo(b.lift);
        });
      landFrom.add(all.length);
      all.addAll(l);
      landTo.add(all.length);
    }
    this.land = _Grains(all);
    isles = _Grains(isleGrains);
    under = _Grains(underGrains);
    cloud = _Grains(cloudGrains);
    deck = _Grains(deckGrains);
    glow = _Grains(glowGrains);
    sea = _Grains(_sea());

    for (final s in [plume, steam, mist, flies, rain, towers, ...motes]) {
      s.freeze();
    }
  }

  late final List<_Continent> continents;
  final List<int> landFrom = [], landTo = [];
  late final _Grains land, cloud, under, isles, deck, glow, sea;

  final List<_Isle> isleList = [];
  late final _Point vent;
  final _Anchors plume = _Anchors(),
      steam = _Anchors(),
      mist = _Anchors(),
      flies = _Anchors(),
      rain = _Anchors(),
      towers = _Anchors();
  final List<_Anchors> motes = [];

  static const double _density = 10500;
  static const double _grain = 0.0094;

  /// Points spread evenly over the cap of [reach] round [c]'s centre,
  /// [density] per steradian, shaken a little: local (u, v).
  static List<(double, double)> _spread(
    double reach,
    double density,
    math.Random rng,
  ) {
    final area = _tau * (1 - math.cos(reach));
    final n = (area * density).round();
    final spacing = 1 / math.sqrt(density);
    const golden = 2.399963229728653;
    final c0 = math.cos(reach);
    return [
      for (var i = 0; i < n; i++)
        () {
          final d = math.acos(1 - (1 - c0) * (i + 0.5) / n);
          final th = i * golden;
          return (
            d * math.cos(th) + (rng.nextDouble() - 0.5) * spacing * 0.9,
            d * math.sin(th) + (rng.nextDouble() - 0.5) * spacing * 0.9,
          );
        }(),
    ];
  }

  /// A grain on [c] at (u, v) over the height field [h], its normal tipped
  /// by the field's slope ([relief] exaggerates it).
  static _G _ground(
    _Continent c,
    double u,
    double v,
    double Function(double, double) h,
    _Rgb col, {
    double size = _grain,
    double extraLift = 0,
    _Rgb? alt,
    double aw = 0,
    double spec = 0,
    int layer = 0,
    double relief = 2.4,
    double alpha = 1,
    double? hAt,
  }) {
    final (x, y, z) = c.at(u, v);
    final h0 = hAt ?? h(u, v);
    const e = 0.004;
    final hu = (h(u + e, v) - h0) / e, hv = (h(u, v + e) - h0) / e;
    final (x1, y1, z1) = c.at(u + e, v);
    final (x2, y2, z2) = c.at(u, v + e);
    var tux = x1 - x, tuy = y1 - y, tuz = z1 - z;
    var tl = math.sqrt(tux * tux + tuy * tuy + tuz * tuz);
    tux /= tl;
    tuy /= tl;
    tuz /= tl;
    var tvx = x2 - x, tvy = y2 - y, tvz = z2 - z;
    tl = math.sqrt(tvx * tvx + tvy * tvy + tvz * tvz);
    tvx /= tl;
    tvy /= tl;
    tvz /= tl;
    var nx = x - relief * (hu * tux + hv * tvx);
    var ny = y - relief * (hu * tuy + hv * tvy);
    var nz = z - relief * (hu * tuz + hv * tvz);
    final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
    return _G(
      x,
      y,
      z,
      size,
      col,
      nx: nx / nl,
      ny: ny / nl,
      nz: nz / nl,
      lift: h0 + extraLift,
      alt: alt,
      aw: aw,
      spec: spec,
      layer: layer,
      biome: c.biome.index,
      alpha: alpha,
      phase: _hashPhase(x, y, z),
    );
  }

  /// A crown of grains round (u, v): a small dome, lit on its sun side.
  static void _crown(
    _Continent c,
    List<_G> out,
    double u,
    double v,
    double base,
    double radius,
    double height,
    int count,
    _Rgb dark,
    _Rgb lit,
    math.Random rng, {
    _Rgb? alt,
    double aw = 0.4,
    int layer = 2,
    double size = 0.0112,
  }) {
    const golden = 2.399963229728653;
    final (x0, y0, z0) = c.at(u, v);
    final turn = rng.nextDouble() * _tau;
    for (var i = 0; i < count; i++) {
      final f = math.sqrt((i + 0.5) / count);
      final th = turn + i * golden;
      final du = math.cos(th) * f * radius, dv = math.sin(th) * f * radius;
      final (x, y, z) = c.at(u + du, v + dv);
      // Tipped outward from the crown's middle.
      var nx = x + (x - x0) / radius * 1.4;
      var ny = y + (y - y0) / radius * 1.4;
      var nz = z + (z - z0) / radius * 1.4;
      final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
      final col = dark.mix(lit, (1 - f) * 0.8 + rng.nextDouble() * 0.2);
      out.add(
        _G(
          x,
          y,
          z,
          size,
          col,
          nx: nx / nl,
          ny: ny / nl,
          nz: nz / nl,
          lift: base + height * (1 - f * f) + 0.002,
          alt: alt,
          aw: aw,
          layer: layer,
          biome: c.biome.index,
        ),
      );
    }
  }

  // ── The Valley: a green basin ringed by ridges, a lake, a river to the sea.

  void _valley(_Continent c, List<_G> out, List<_G> deck) {
    final rng = math.Random(31);
    const s = 101;
    const lakeU = -0.1, lakeV = 0.05, lakeR = 0.1;
    final river = _Path2(
      const [
        (-0.03, 0.0),
        (0.07, -0.07),
        (0.16, -0.16),
        (0.22, -0.28),
        (0.27, -0.42),
        (0.31, -0.58),
        (0.34, -0.76),
      ],
      0.012,
      0.024,
    );

    double ridge(double u, double v) {
      final rho = c.rho(u, v);
      final th = math.atan2(v, u);
      final ring = math.exp(-math.pow((rho - 0.76) / 0.16, 2).toDouble());
      final arcs = math.max(
        _arc(th, 0.6 * math.pi, 0.44 * math.pi),
        0.8 * _arc(th, -0.08 * math.pi, 0.2 * math.pi),
      );
      final f = _fbm(u * 9 + 5, v * 9 + 5, s);
      final ridged = 1 - (2 * f - 1).abs();
      return 0.04 * ring * arcs * (0.3 + 0.95 * ridged);
    }

    double lakeK(double u, double v) {
      final dx = u - lakeU, dy = v - lakeV;
      final th = math.atan2(dy, dx);
      final wob =
          1 +
          0.16 * math.sin(2 * th + 1.1) +
          0.1 * math.sin(3 * th + 0.4) +
          0.6 * (_fbm(u * 9, v * 9, s + 9) - 0.5);
      return math.sqrt(dx * dx + dy * dy) / (lakeR * wob);
    }

    double height(double u, double v) {
      var h = 0.003 * _fbm(u * 7, v * 7, s + 3) + ridge(u, v);
      final lk = lakeK(u, v);
      if (lk < 1.4) h *= _smooth(_clamp01((lk - 1) / 0.4));
      final (rd, _, rw) = river.nearest(u, v);
      if (rd < rw * 2.5) h *= _smooth(_clamp01((rd - rw) / (rw * 1.5)));
      return h;
    }

    final snowGround = _hex(0xFFE6EDF4);
    final meadowDark = _hex(0xFF44702A), meadowLit = _hex(0xFF7AA23E);
    final golden = _hex(0xFFB4B052);
    final forestFloor = _hex(0xFF20361A);
    final rock = _hex(0xFF6A645A), rockHigh = _hex(0xFF8C8A90);
    final snowCap = _hex(0xFFEEF1F4);
    final sand = _hex(0xFFCDB98C);
    final flowers = [_hex(0xFFE8DC9A), _hex(0xFFE0A8B8), _hex(0xFFB8A8E0)];
    final ice = _hex(0xFFC2D4E0);

    bool forested(double u, double v) =>
        _fbm(u * 5.5 + 20, v * 5.5 + 20, s + 7) > 0.56;

    for (final (u, v) in _spread(c.reach, _density, rng)) {
      final rho = c.rho(u, v);
      if (rho >= 1 || _taken(u, v, c)) continue;
      final h = height(u, v);
      final m = ridge(u, v);
      final lk = lakeK(u, v);
      final (rd, _, rw) = river.nearest(u, v);
      if (lk < 1 || rd < rw) {
        final deep = lk < 1 ? _smooth(1 - lk) : 0.2;
        out.add(
          _ground(
            c,
            u,
            v,
            height,
            _hex(0xFF3A7890).mix(_hex(0xFF16405C), deep),
            hAt: 0,
            alt: ice,
            aw: 0.75,
            spec: 1,
            size: _grain * 0.95,
          ),
        );
        continue;
      }
      final t = _fbm(u * 8 + 3, v * 8 + 1, s + 5);
      var col = meadowDark.mix(meadowLit, _smooth(t));
      final gold = _fbm(u * 4.5 + 9, v * 4.5, s + 6);
      if (gold > 0.56) col = col.mix(golden, _clamp01((gold - 0.56) * 6));
      var aw = 1.0;
      if (rng.nextDouble() < 0.03) {
        col = flowers[rng.nextInt(flowers.length)];
      }
      if (forested(u, v) && m < 0.012) {
        col = forestFloor;
        aw = 0.75;
      }
      final rk = _clamp01(m / 0.011);
      col = col.mix(rock, rk);
      if (m > 0.017) col = col.mix(rockHigh, _clamp01((m - 0.017) / 0.006));
      if (m > 0.031) col = col.mix(snowCap, _clamp01((m - 0.031) / 0.004));
      if (rho > 0.9 && m < 0.004) {
        col = col.mix(sand, _clamp01((rho - 0.9) / 0.08));
        aw = 0.7;
      }
      out.add(_ground(c, u, v, height, col, hAt: h, alt: snowGround, aw: aw));
    }

    // Trees: woods on the lower slopes, a few alone in the meadow, firs at
    // the feet of the ridges, and three great trees round the lake.
    final treeDark = _hex(0xFF1A3218), treeLit = _hex(0xFF3A6A2C);
    final firDark = _hex(0xFF14261C), firLit = _hex(0xFF2A4A34);
    final frost = _hex(0xFFD6E0E6);
    const step = 0.02;
    for (var gu = -c.reach; gu < c.reach; gu += step) {
      for (var gv = -c.reach; gv < c.reach; gv += step) {
        final u = gu + (rng.nextDouble() - 0.5) * step * 0.9;
        final v = gv + (rng.nextDouble() - 0.5) * step * 0.9;
        final rho = c.rho(u, v);
        if (rho > 0.9 || lakeK(u, v) < 1.15) continue;
        final (rd, _, rw) = river.nearest(u, v);
        if (rd < rw * 1.6) continue;
        final m = ridge(u, v);
        final h = height(u, v);
        final wood = forested(u, v);
        if (wood && m < 0.012 && rng.nextDouble() < 0.85) {
          _crown(
            c,
            out,
            u,
            v,
            h,
            0.0085,
            0.008,
            7,
            treeDark,
            treeLit,
            rng,
            alt: frost,
          );
        } else if (m > 0.005 && m < 0.017 && rng.nextDouble() < 0.5) {
          _crown(
            c,
            out,
            u,
            v,
            h,
            0.0062,
            0.009,
            5,
            firDark,
            firLit,
            rng,
            alt: frost,
          );
        } else if (!wood && m < 0.004 && rng.nextDouble() < 0.035) {
          _crown(
            c,
            out,
            u,
            v,
            h,
            0.008,
            0.007,
            7,
            treeDark,
            treeLit,
            rng,
            alt: frost,
          );
        }
      }
    }
    for (final (u, v) in const [(-0.25, 0.13), (0.05, 0.17), (-0.04, -0.15)]) {
      _crown(
        c,
        out,
        u,
        v,
        height(u, v),
        0.017,
        0.016,
        18,
        treeDark,
        treeLit,
        rng,
        alt: frost,
        size: 0.0125,
      );
    }

    // Weather: a patchy deck for rain or snow.
    final cloudTop = _hex(0xFF9AA2AE), cloudLow = _hex(0xFF424A56);
    final snowTop = _hex(0xFFF4F6FA), snowLow = _hex(0xFFAAB6C4);
    double deckH(double u, double v) => 0.014 * _cells(u, v, 6, s + 21);
    for (final (u, v) in _spread(c.reach * 0.98, 4200, rng)) {
      final rho = c.rho(u, v);
      if (rho > 1.02) continue;
      final patch =
          _fbm(u * 4 + 70, v * 4 + 70, s + 20) -
          0.12 * _clamp01((rho - 0.75) / 0.25);
      if (patch < 0.45) continue;
      final b = _cells(u, v, 6, s + 21);
      deck.add(
        _ground(
          c,
          u,
          v,
          deckH,
          cloudLow.mix(cloudTop, _smooth(b)),
          extraLift: 0.04,
          alt: snowLow.mix(snowTop, _smooth(b)),
          aw: 1,
          relief: 3.6,
          size: _grain * 2.8,
          alpha: 0.62 * _clamp01((patch - 0.45) / 0.05),
        ),
      );
      if (rng.nextDouble() < 0.05) {
        final (x, y, z) = c.at(u, v);
        rain.add(x, y, z, phase: rng.nextDouble());
      }
    }

    for (var i = 0; i < 70; i++) {
      final u = (rng.nextDouble() - 0.5) * 1.0,
          v = (rng.nextDouble() - 0.5) * 1.0;
      if (c.rho(u, v) > 0.85 || lakeK(u, v) < 1.1) continue;
      final (x, y, z) = c.at(u, v);
      flies.add(x, y, z, phase: rng.nextDouble(), a: 0);
    }
    _spawnSpots(
      c,
      motes[c.biome.index],
      rng,
      (u, v) => lakeK(u, v) > 1.2,
      0.03,
    );
  }

  // ── The Sky: a cloud sea with pale stone isles floating over it.

  /// Cumulus cells: 0 in the creases between puffs, rising to 1 on their
  /// rounded tops.
  static double _cells(double u, double v, double freq, int seed) {
    final f = _fbm(u * freq + 3, v * freq + 3, seed);
    return math.sqrt(_clamp01((2 * f - 1).abs() * 2.4));
  }

  void _sky(
    _Continent c,
    List<_G> out,
    List<_G> under,
    List<_G> isles,
    List<_G> deck,
  ) {
    final rng = math.Random(71);
    const s = 707;
    final towerAt = <(double, double, double, double)>[];
    for (var i = 0; i < 5; i++) {
      final th = i * _tau / 5 + 0.4 + (rng.nextDouble() - 0.5) * 0.6;
      final r = c.coast(th) * (0.58 + 0.2 * rng.nextDouble());
      towerAt.add((
        math.cos(th) * r,
        math.sin(th) * r,
        0.05 + 0.02 * rng.nextDouble(),
        0.024 + 0.012 * rng.nextDouble(),
      ));
    }
    double towerH(double u, double v) {
      var h = 0.0;
      for (final (tu, tv, tr, th) in towerAt) {
        final dx = u - tu, dy = v - tv;
        final k = 1 - (dx * dx + dy * dy) / (tr * tr);
        if (k > 0) h = math.max(h, th * math.pow(k, 0.6).toDouble());
      }
      return h;
    }

    double fray(double rho) => 1 - 0.55 * _clamp01((rho - 0.78) / 0.22);
    double height(double u, double v) =>
        (0.012 + 0.018 * _cells(u, v, 6.5, s)) * fray(c.rho(u, v)) +
        towerH(u, v);

    final crease = _hex(0xFF7A94AE), mid = _hex(0xFFD6DFE8);
    final top = _hex(0xFFF8F5EE);
    for (final (u, v) in _spread(c.reach, 10000, rng)) {
      final rho = c.rho(u, v);
      if (rho >= 1 || _taken(u, v, c)) continue;
      if (rho > 0.8 && rng.nextDouble() < math.pow((rho - 0.8) / 0.2, 1.4)) {
        continue;
      }
      final b = _cells(u, v, 6.5, s);
      final tw = towerH(u, v);
      var col = crease.mix(mid, _smooth(_clamp01(b * 1.6)));
      if (b > 0.6) col = col.mix(top, _clamp01((b - 0.6) * 2.5));
      if (tw > 0.004) col = col.mix(top, _clamp01(tw / 0.016));
      out.add(
        _ground(
          c,
          u,
          v,
          height,
          col,
          relief: 3.6,
          size: _grain * 3.0,
          alpha: 0.42 * (1 - 0.5 * _clamp01((rho - 0.75) / 0.25)),
        ),
      );
    }

    // Isles: grass plateaus rimmed in pale stone, each over a rough
    // inverted cone of rock.
    final grass = [_hex(0xFF587E30), _hex(0xFF6E9440), _hex(0xFF8AAA56)];
    final rimStone = _hex(0xFFD8CEB8);
    final stoneTop = _hex(0xFF9C8E76), stoneLow = _hex(0xFF3C342C);
    final fall = _hex(0xFFE6F0F6);
    final spots = <(double, double, double)>[];
    var tries = 0;
    while (spots.length < 6 && tries++ < 400) {
      final th = rng.nextDouble() * _tau;
      final r = c.coast(th) * (0.1 + 0.52 * rng.nextDouble());
      final u = math.cos(th) * r, v = math.sin(th) * r;
      final ri = 0.036 + 0.04 * rng.nextDouble();
      if (spots.any((p) {
        final dx = p.$1 - u, dy = p.$2 - v;
        return math.sqrt(dx * dx + dy * dy) < p.$3 + ri + 0.1;
      })) {
        continue;
      }
      spots.add((u, v, ri));
    }
    for (var k = 0; k < spots.length; k++) {
      final (iu, iv, ri) = spots[k];
      final ht = 0.085 + 0.02 * rng.nextDouble();
      final (ax, ay, az) = c.at(iu, iv);
      final p1 = rng.nextDouble() * _tau, p2 = rng.nextDouble() * _tau;
      final p3 = rng.nextDouble() * _tau;
      double edge(double th) =>
          ri *
          (1 +
              0.08 * math.sin(2 * th + p1) +
              0.05 * math.sin(5 * th + p2) +
              0.03 * math.sin(8 * th + p3));
      isleList.add(_Isle(ax, ay, az, ri, ht, 400 + k, p1, p2, p3));

      // The underside, deepest first: ragged rings narrowing to a point.
      const rings = 8;
      for (var ring = rings; ring >= 1; ring--) {
        final f = ring / (rings + 1);
        final count = math.max(5, (_tau * ri * (1 - f) / 0.0068).round());
        for (var j = 0; j < count; j++) {
          final th = _tau * j / count + ring * 0.37;
          final rag = 0.72 + 0.26 * _noise(th * 3, ring * 1.7, s + k);
          final rr = edge(th) * 0.95 * math.pow(1 - f, 1.25).toDouble() * rag;
          final du = math.cos(th) * rr, dv = math.sin(th) * rr;
          final (x, y, z) = c.at(iu + du, iv + dv);
          final ox = x - ax, oy = y - ay, oz = z - az;
          final ol = math.max(1e-6, math.sqrt(ox * ox + oy * oy + oz * oz));
          var nx = ox / ol * 0.9 - x * 0.45;
          var ny = oy / ol * 0.9 - y * 0.45;
          var nz = oz / ol * 0.9 - z * 0.45;
          final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
          under.add(
            _G(
              x,
              y,
              z,
              0.0112,
              stoneTop.mix(stoneLow, f * (0.8 + 0.4 * rng.nextDouble())),
              nx: nx / nl,
              ny: ny / nl,
              nz: nz / nl,
              lift: ht - 0.0062 * ring,
              layer: rings + 1 - ring,
              biome: c.biome.index,
            ),
          );
        }
      }
      // The top: grass, rimmed in pale stone, strewn at random over a fill
      // (a golden-angle spiral showed as a sunflower).
      final count = (math.pi * ri * ri * 1.1 * 11000).round();
      for (var j = 0; j < count; j++) {
        final f = math.sqrt(rng.nextDouble());
        final th = rng.nextDouble() * _tau;
        final rr = edge(th) * f;
        final du = math.cos(th) * rr, dv = math.sin(th) * rr;
        final (x, y, z) = c.at(iu + du, iv + dv);
        final rim = f > 0.76 || rng.nextDouble() < 0.06;
        final ox = x - ax, oy = y - ay, oz = z - az;
        var nx = x + ox / ri * 0.22,
            ny = y + oy / ri * 0.22,
            nz = z + oz / ri * 0.22;
        final nl = math.sqrt(nx * nx + ny * ny + nz * nz);
        final col = rim
            ? rimStone.mix(stoneTop, 0.25 * rng.nextDouble())
            : grass[rng.nextInt(3)];
        isles.add(
          _G(
            x,
            y,
            z,
            0.0095,
            col,
            nx: nx / nl,
            ny: ny / nl,
            nz: nz / nl,
            lift: ht - (f > 0.82 ? 0.0012 : 0),
            layer: rings + 2,
            biome: c.biome.index,
          ),
        );
      }
      final outline = Float64List(28 * 3);
      for (var j = 0; j < 28; j++) {
        final th = _tau * j / 28;
        final rr = edge(th) * 0.97;
        final (x, y, z) = c.at(iu + math.cos(th) * rr, iv + math.sin(th) * rr);
        outline[j * 3] = x;
        outline[j * 3 + 1] = y;
        outline[j * 3 + 2] = z;
      }
      isleList.last.top = outline;
      // A tree or two.
      for (var j = 0; j < 1 + rng.nextInt(2); j++) {
        final th = rng.nextDouble() * _tau, rr = ri * 0.5 * rng.nextDouble();
        _crown(
          c,
          isles,
          iu + math.cos(th) * rr,
          iv + math.sin(th) * rr,
          ht,
          0.0068,
          0.007,
          8,
          _hex(0xFF1A3218),
          _hex(0xFF3A6A2C),
          rng,
          layer: rings + 3,
          size: 0.0096,
        );
      }
      // Falls off two of them, down to the cloud sea.
      if (k == 0 || k == 3) {
        final th = rng.nextDouble() * _tau;
        final rr = edge(th) * 0.92;
        for (var j = 0; j < 16; j++) {
          final f = j / 15;
          final out2 = rr + 0.003 + 0.007 * f;
          final (x, y, z) = c.at(
            iu + math.cos(th) * out2,
            iv + math.sin(th) * out2,
          );
          under.add(
            _G(
              x,
              y,
              z,
              f > 0.85 ? 0.016 : 0.0092,
              fall,
              nx: x,
              ny: y,
              nz: z,
              lift: ht - 0.002 - (ht - 0.026) * f,
              alpha: f > 0.85 ? 0.5 : 0.85,
              layer: rings,
              biome: c.biome.index,
            ),
          );
        }
      }
      final (mx, my, mz) = c.at(iu, iv);
      motes[c.biome.index].add(
        mx,
        my,
        mz,
        phase: rng.nextDouble(),
        a: ht + 0.022,
      );
    }
    // Two more spawn spots over the cloud sea.
    for (var i = 0; i < 2; i++) {
      final th = rng.nextDouble() * _tau, r = c.coast(th) * 0.4;
      final (x, y, z) = c.at(math.cos(th) * r, math.sin(th) * r);
      motes[c.biome.index].add(x, y, z, phase: rng.nextDouble(), a: 0.05);
    }

    // The storm: a slate deck over the whole sea of cloud.
    final slateLow = _hex(0xFF22243A), slateTop = _hex(0xFF6C7090);
    double stormH(double u, double v) =>
        0.02 * _cells(u, v, 5.5, s + 9) + 0.6 * towerH(u, v);
    for (final (u, v) in _spread(c.reach * 0.98, 4200, rng)) {
      final rho = c.rho(u, v);
      if (rho > 0.97) continue;
      final b = _cells(u, v, 5.5, s + 9);
      deck.add(
        _ground(
          c,
          u,
          v,
          stormH,
          slateLow.mix(slateTop, _smooth(b)),
          extraLift: 0.046,
          relief: 3.6,
          size: _grain * 2.8,
          alpha: 0.7 * (rho > 0.85 ? 1 - (rho - 0.85) / 0.12 * 0.7 : 1),
        ),
      );
    }
    for (var i = 0; i < 4; i++) {
      final (tu, tv, _, th) = towerAt[i];
      final (x, y, z) = c.at(tu, tv);
      towers.add(x, y, z, a: 0.05 + th * 0.6);
    }
  }

  // ── The Swamp: a jade mosaic of pools, peat and cypress.

  void _swamp(_Continent c, List<_G> out) {
    final rng = math.Random(51);
    const s = 505;
    double wet(double u, double v, double rho) =>
        _fbm(u * 6.5 + 40, v * 6.5 + 40, s) + 0.14 * (1 - rho) - 0.07;
    double height(double u, double v) =>
        wet(u, v, c.rho(u, v)) > 0.53 ? 0 : 0.0016 * _fbm(u * 9, v * 9, s + 2);

    final jade = _hex(0xFF2E6C5E), deep = _hex(0xFF184640);
    final weed = _hex(0xFF62903C);
    final peat = _hex(0xFF362E20),
        moss = _hex(0xFF3A5432),
        sedge = _hex(0xFF5E6E3E);
    final mud = _hex(0xFFA48C64),
        mudDark = _hex(0xFF866F4E),
        crack = _hex(0xFF54452F);
    final dryLand = _hex(0xFF6E6648);
    final stone = _hex(0xFF66645A);
    final stones = <(double, double, double)>[
      for (var i = 0; i < 4; i++)
        () {
          final th = rng.nextDouble() * _tau,
              r = c.coast(th) * 0.6 * rng.nextDouble();
          return (
            math.cos(th) * r,
            math.sin(th) * r,
            0.014 + 0.01 * rng.nextDouble(),
          );
        }(),
    ];

    // Cracks for the dry floor: the edges of a jittered cell pattern.
    bool cracked(double u, double v) {
      const cell = 0.034;
      final gu = (u / cell).floor(), gv = (v / cell).floor();
      var d1 = 9.0, d2 = 9.0;
      for (var i = -1; i <= 1; i++) {
        for (var j = -1; j <= 1; j++) {
          final px = (gu + i + _lattice(gu + i, gv + j, s + 40)) * cell;
          final py = (gv + j + _lattice(gu + i, gv + j, s + 41)) * cell;
          final dx = (u - px) * 1.6, dy = v - py;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d < d1) {
            d2 = d1;
            d1 = d;
          } else if (d < d2) {
            d2 = d;
          }
        }
      }
      return d2 - d1 < 0.0034;
    }

    for (final (u, v) in _spread(c.reach, _density, rng)) {
      final rho = c.rho(u, v);
      if (rho >= 1 || _taken(u, v, c)) continue;
      final onStone = stones.any((p) {
        final dx = u - p.$1, dy = v - p.$2;
        return dx * dx + dy * dy < p.$3 * p.$3;
      });
      if (onStone) {
        out.add(_ground(c, u, v, height, stone, hAt: 0.0035, layer: 1));
        continue;
      }
      final w = wet(u, v, rho);
      if (w > 0.53) {
        final q = _clamp01((w - 0.53) / 0.14);
        var col = jade.mix(deep, q);
        var sp = 1.0;
        if (q < 0.6 && _fbm(u * 14, v * 14, s + 3) > 0.6) {
          col = col.mix(weed, 0.85);
          sp = 0.3;
        }
        // Dry, the water draws down to its deepest pools.
        final keep = q > 0.72;
        final dry = cracked(u, v)
            ? crack
            : mud.mix(mudDark, _fbm(u * 12, v * 12, s + 5));
        out.add(
          _ground(
            c,
            u,
            v,
            height,
            col,
            hAt: 0,
            alt: dry,
            aw: keep ? 0 : 1,
            spec: sp,
          ),
        );
        continue;
      }
      final a = _fbm(u * 9 + 7, v * 9 + 7, s + 8),
          b = _fbm(u * 5 + 1, v * 5 + 1, s + 9);
      var col = peat.mix(moss, _smooth(a));
      if (b > 0.58) col = col.mix(sedge, _clamp01((b - 0.58) * 5));
      out.add(
        _ground(c, u, v, height, col, alt: col.mix(dryLand, 0.7), aw: 0.8),
      );
    }

    // Cypress groves, with moss hanging grey-green at their edges.
    final crownDark = _hex(0xFF16261C), crownLit = _hex(0xFF2E4A34);
    final hang = _hex(0xFF7C8868), grey = _hex(0xFF4C4C38);
    const step = 0.023;
    for (var gu = -c.reach; gu < c.reach; gu += step) {
      for (var gv = -c.reach; gv < c.reach; gv += step) {
        final u = gu + (rng.nextDouble() - 0.5) * step * 0.9;
        final v = gv + (rng.nextDouble() - 0.5) * step * 0.9;
        final rho = c.rho(u, v);
        if (rho > 0.92) continue;
        final grove = _fbm(u * 5 + 80, v * 5 + 80, s + 11);
        final w = wet(u, v, rho);
        final p = w > 0.53 ? (w < 0.6 ? 0.22 : 0.0) : 0.8;
        if (grove < 0.5 || rng.nextDouble() > p) continue;
        final r = 0.0085 + 0.003 * rng.nextDouble();
        _crown(
          c,
          out,
          u,
          v,
          0.002,
          r,
          0.011,
          9,
          crownDark,
          crownLit,
          rng,
          alt: grey,
          aw: 0.35,
        );
        for (var j = 0; j < 3; j++) {
          final th = rng.nextDouble() * _tau;
          final (x, y, z) = c.at(
            u + math.cos(th) * r * 1.05,
            v + math.sin(th) * r * 1.05,
          );
          out.add(
            _G(
              x,
              y,
              z,
              0.0095,
              hang,
              nx: x,
              ny: y,
              nz: z,
              lift: 0.006,
              alt: grey,
              aw: 0.5,
              layer: 2,
              biome: c.biome.index,
            ),
          );
        }
      }
    }

    for (var i = 0; i < 130; i++) {
      final th = rng.nextDouble() * _tau,
          r = c.coast(th) * 0.85 * math.sqrt(rng.nextDouble());
      final (x, y, z) = c.at(math.cos(th) * r, math.sin(th) * r);
      mist.add(x, y, z, phase: rng.nextDouble());
    }
    for (var i = 0; i < 50; i++) {
      final th = rng.nextDouble() * _tau,
          r = c.coast(th) * 0.8 * math.sqrt(rng.nextDouble());
      final (x, y, z) = c.at(math.cos(th) * r, math.sin(th) * r);
      flies.add(x, y, z, phase: rng.nextDouble(), a: 1);
    }
    _spawnSpots(c, motes[c.biome.index], rng, (u, v) => true, 0.026);
  }

  // ── The Volcano: a cone with lava fanning down to the sea.

  void _volcano(_Continent c, List<_G> out, List<_G> glow) {
    final rng = math.Random(91);
    const s = 303;
    const coneU = 0.03, coneV = 0.05, rc = 0.28, rim = 0.042, peak = 0.088;
    const oldU = -0.33, oldV = -0.15, ro = 0.15;
    double coneD(double u, double v) {
      final dx = u - coneU, dy = v - coneV;
      return math.sqrt(dx * dx + dy * dy);
    }

    double coneH(double u, double v) {
      final d = coneD(u, v);
      if (d >= rc) return 0;
      if (d < rim) {
        final top = peak * math.pow(1 - rim / rc, 1.35).toDouble();
        return top - 0.014 * (1 - (d / rim) * (d / rim));
      }
      final a = math.atan2(v - coneV, u - coneU);
      final k = (d - rim) / (rc - rim);
      final gully =
          0.0035 * math.sin(a * 13 + 3 * _fbm(u * 6, v * 6, s)) * k * (1 - k);
      return peak * math.pow(1 - d / rc, 1.35).toDouble() + gully;
    }

    double oldH(double u, double v) {
      final dx = u - oldU, dy = v - oldV;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d >= ro) return 0;
      final k = 1 - d / ro;
      return 0.03 * math.pow(k, 1.5).toDouble() -
          (d < 0.04 ? 0.007 * (1 - (d / 0.04) * (d / 0.04)) : 0);
    }

    double hills(double u, double v) {
      final rho = c.rho(u, v);
      final th = math.atan2(v, u);
      return 0.013 *
          _arc(th, 0.3 * math.pi, 0.5 * math.pi) *
          _smooth(_clamp01((rho - 0.5) / 0.3)) *
          _fbm(u * 8 + 4, v * 8, s + 2);
    }

    double height(double u, double v) =>
        0.004 * _fbm(u * 7, v * 7, s + 1) +
        coneH(u, v) +
        oldH(u, v) +
        hills(u, v);

    // Lava: channels from the crater rim, wandering outward; four reach the
    // sea, two die on the plain.
    final rivers = <_Path2>[];
    final mouths = <(double, double)>[];
    for (var i = 0; i < 6; i++) {
      final a0 = i * _tau / 6 + 0.3 + (rng.nextDouble() - 0.5) * 0.5;
      var a = a0;
      var d = rim * 1.02;
      final pts = <(double, double)>[];
      final toSea = i != 2 && i != 5;
      final len = toSea ? 2.0 : rc * 1.2 + rng.nextDouble() * 0.1;
      var reached = false;
      while (d < len) {
        final u = coneU + math.cos(a) * d, v = coneV + math.sin(a) * d;
        pts.add((u, v));
        if (c.rho(u, v) > 1.02) {
          reached = true;
          break;
        }
        a =
            a0 +
            0.16 * math.sin(d * 13 + i * 1.7) +
            0.07 * math.sin(d * 31 + i);
        d += 0.008;
      }
      rivers.add(_Path2(pts, 0.0046, toSea ? 0.012 : 0.009));
      if (reached) mouths.add(pts.last);
    }
    final pools = <(double, double, double)>[
      (0.3, -0.24, 0.028),
      (-0.12, 0.34, 0.024),
    ];

    final basalt = _hex(0xFF1C1719), basaltLit = _hex(0xFF30262A);
    final sheen = _hex(0xFF46404A);
    final redHill = _hex(0xFF6A2C20), redHillLit = _hex(0xFF8E4632);
    final ash = _hex(0xFF4C4442);
    final flank = _hex(0xFF3A2422), flankTop = _hex(0xFF4E3C38);
    final streak = _hex(0xFF62524C), rimAsh = _hex(0xFF5A4A44);
    final worn = _hex(0xFF3A2C28), blackSand = _hex(0xFF141012);
    final crust = _hex(0xFF3A120A), crustHot = _hex(0xFFB8441A);
    final lavaRed = _hex(0xFFFF5418), lavaGold = _hex(0xFFFFC454);

    void lava(double u, double v, double hot, double power) {
      final (x, y, z) = c.at(u, v);
      final col = lavaRed.mix(lavaGold, hot * hot);
      glow.add(
        _G(
          x,
          y,
          z,
          0.022,
          col,
          nx: x,
          ny: y,
          nz: z,
          lift: height(u, v) + 0.001,
          alpha: power,
          phase: rng.nextDouble() * _tau,
          biome: c.biome.index,
        ),
      );
    }

    for (final (u, v) in _spread(c.reach, _density, rng)) {
      final rho = c.rho(u, v);
      if (rho >= 1 || _taken(u, v, c)) continue;
      final h = height(u, v);
      final dc = coneD(u, v);
      // The crater's lava lake.
      if (dc < rim * 0.72) {
        out.add(_ground(c, u, v, height, crustHot, hAt: h));
        lava(u, v, 1 - dc / (rim * 0.72) * 0.5, 0.95);
        continue;
      }
      var molten = false;
      for (final r in rivers) {
        final (rd, along, rw) = r.nearest(u, v);
        if (rd < rw) {
          final hot = 1 - rd / rw;
          out.add(
            _ground(c, u, v, height, crust.mix(crustHot, hot * 0.6), hAt: h),
          );
          lava(u, v, hot, (0.5 + 0.5 * hot) * (1 - 0.55 * along * along));
          molten = true;
          break;
        }
      }
      if (molten) continue;
      for (final (pu, pv, pr) in pools) {
        final dx = u - pu, dy = v - pv;
        final wob = 1 + 0.3 * (_fbm(u * 20, v * 20, s + 6) - 0.5);
        final k = math.sqrt(dx * dx + dy * dy) / (pr * wob);
        if (k < 1) {
          out.add(_ground(c, u, v, height, crust, hAt: h));
          lava(u, v, 1 - k, 0.8);
          molten = true;
          break;
        }
      }
      if (molten) continue;

      final t = _fbm(u * 9 + 2, v * 9 + 2, s + 3);
      var col = basalt.mix(basaltLit, t);
      if (rng.nextDouble() < 0.06) col = sheen;
      final hk = _clamp01(hills(u, v) / 0.007);
      col = col.mix(redHill.mix(redHillLit, _fbm(u * 6, v * 6, s + 4)), hk);
      if (dc > rc * 0.9) {
        col = col.mix(ash, 0.6 * _clamp01(1 - (dc - rc) / 0.2));
      }
      if (dc < rc) {
        final k = 1 - dc / rc;
        var f = flank.mix(flankTop, k);
        final a = math.atan2(v - coneV, u - coneU);
        if (math.sin(a * 9 + _fbm(u * 5, v * 5, s + 7) * 4) > 0.55) {
          f = f.mix(streak, 0.5);
        }
        col = col.mix(f, _smooth(_clamp01(k * 3)));
      }
      if (dc < rim * 1.45) col = rimAsh;
      if (oldH(u, v) > 0.002) col = col.mix(worn, 0.6);
      if (rho > 0.92) col = col.mix(blackSand, _clamp01((rho - 0.92) / 0.06));
      out.add(_ground(c, u, v, height, col, hAt: h, relief: 3.4));
    }

    final (vx, vy, vz) = c.at(coneU, coneV);
    vent = _Point(vx, vy, vz);
    // The plume: billows of ash, each a clump of grains rising together.
    const billows = 16, perBillow = 34;
    for (var k = 0; k < billows; k++) {
      final bu = (rng.nextDouble() - 0.5) * 1.1,
          bv = (rng.nextDouble() - 0.5) * 1.1;
      for (var j = 0; j < perBillow; j++) {
        final th = rng.nextDouble() * _tau,
            r = math.sqrt(rng.nextDouble()) * 0.55;
        plume.add(
          vx,
          vy,
          vz,
          phase: k / billows + (rng.nextDouble() - 0.5) * 0.02,
          a: bu + math.cos(th) * r,
          b: bv + math.sin(th) * r,
        );
      }
    }
    // Steam where the lava meets the sea.
    for (final (u, v) in mouths) {
      final (x, y, z) = c.at(u, v);
      for (var j = 0; j < 30; j++) {
        steam.add(
          x,
          y,
          z,
          phase: rng.nextDouble(),
          a: rng.nextDouble() * 2 - 1,
          b: rng.nextDouble() * 2 - 1,
        );
      }
    }
    _spawnSpots(
      c,
      motes[c.biome.index],
      rng,
      (u, v) => coneD(u, v) > rc * 0.7,
      0.03,
    );
  }

  /// Up to eight places over [c] for wild Alchemons' motes.
  void _spawnSpots(
    _Continent c,
    _Anchors into,
    math.Random rng,
    bool Function(double, double) ok,
    double lift,
  ) {
    var tries = 0;
    final placed = <(double, double)>[];
    while (into.lengthHint < 8 && tries++ < 300) {
      final th = rng.nextDouble() * _tau;
      final r = c.coast(th) * (0.12 + 0.5 * rng.nextDouble());
      final u = math.cos(th) * r, v = math.sin(th) * r;
      if (!ok(u, v)) continue;
      if (placed.any(
        (p) => (p.$1 - u) * (p.$1 - u) + (p.$2 - v) * (p.$2 - v) < 0.012,
      )) {
        continue;
      }
      placed.add((u, v));
      final (x, y, z) = c.at(u, v);
      into.add(x, y, z, phase: rng.nextDouble(), a: lift);
    }
  }

  /// Whether (u, v) on [c] already belongs to an earlier continent.
  bool _taken(double u, double v, _Continent c) {
    final (x, y, z) = c.at(u, v);
    for (final o in continents) {
      if (identical(o, c)) return false;
      if (o.inside(x, y, z, 1.08)) return true;
    }
    return false;
  }

  // ── The sea ──────────────────────────────────────────────────────────

  List<_G> _sea() {
    final rng = math.Random(909);
    final out = <_G>[];
    const n = 7600;
    const golden = 2.399963229728653;
    final deepTone = _hex(0xFF1A4858), lightTone = _hex(0xFF2E6A78);
    for (var i = 0; i < n; i++) {
      final y = 1 - 2 * (i + 0.5) / n;
      final rr = math.sqrt(math.max(0.0, 1 - y * y));
      final th = i * golden;
      var x = math.cos(th) * rr + (rng.nextDouble() - 0.5) * 0.02;
      var yy = y + (rng.nextDouble() - 0.5) * 0.02;
      var z = math.sin(th) * rr + (rng.nextDouble() - 0.5) * 0.02;
      final l = math.sqrt(x * x + yy * yy + z * z);
      x /= l;
      yy /= l;
      z /= l;
      if (continents.any((c) => c.inside(x, yy, z, 1.04))) continue;
      out.add(
        _G(
          x,
          yy,
          z,
          0.0085,
          deepTone.mix(lightTone, rng.nextDouble()),
          nx: x,
          ny: yy,
          nz: z,
          alpha: 0.5,
          spec: 1,
          phase: rng.nextDouble() * _tau,
        ),
      );
    }
    // Surf along each coast, broken by the noise so it never reads as a line.
    final foam = _hex(0xFFCFE6E4);
    for (final c in continents) {
      if (c.shelf == null) continue;
      const m = 460;
      for (var k = 0; k < m; k++) {
        final th = _tau * (k + rng.nextDouble()) / m;
        if (_noise(th * 7, 3, c.seed) < 0.36) continue;
        final d0 = c.coast(th);
        final rag =
            1 +
            0.14 *
                (_fbm(
                      d0 * math.cos(th) * 15 + 50,
                      d0 * math.sin(th) * 15 + 50,
                      c.seed,
                    ) -
                    0.5);
        final d =
            d0 * rag * (1.008 + 0.03 * rng.nextDouble() * rng.nextDouble());
        final (x, y, z) = c.at(d * math.cos(th), d * math.sin(th));
        out.add(
          _G(
            x,
            y,
            z,
            0.0078,
            foam,
            nx: x,
            ny: y,
            nz: z,
            alpha: 0.3 + 0.35 * rng.nextDouble(),
            spec: 0.5,
            phase: rng.nextDouble() * _tau,
          ),
        );
      }
      // Shallows: grains thickest at the shore, thinning out to sea, so the
      // shelf fades rather than ending in an edge.
      final near = _hex(0xFF2E7480), far = _hex(0xFF17465A);
      for (final (u, v) in _spread(c.reach * 1.2, 7000, rng)) {
        final rho = c.rho(u, v);
        if (rho < 1.0 || rho > 1.16) continue;
        final k = (rho - 1) / 0.16;
        if (rng.nextDouble() < k * 0.8) continue;
        final (x, y, z) = c.at(u, v);
        if (continents.any((o) => !identical(o, c) && o.inside(x, y, z, 1))) {
          continue;
        }
        out.add(
          _G(
            x,
            y,
            z,
            0.0088,
            near.mix(far, k),
            nx: x,
            ny: y,
            nz: z,
            alpha: 0.75 * (1 - k) + 0.1,
            spec: 1,
            phase: rng.nextDouble() * _tau,
          ),
        );
      }
    }
    return out;
  }
}

extension on _Anchors {
  int get lengthHint => _v.length ~/ 6;
}
