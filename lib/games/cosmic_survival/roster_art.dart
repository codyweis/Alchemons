// lib/games/cosmic_survival/roster_art.dart
//
// SURVIVAL'S BODIES, IN GRAINS.
//
// Every kind (survival_kind.dart) is made of the same two things the hatch
// ceremony and the wild harvest are made of: grains and stream tubes. A
// husk is a harvest shell with nothing in it, a clutch is an egg that has
// not opened, a strand is one tube off a hatching shell.
//
// Nothing here draws a body on its own. Each body appends its grains and its
// tube segments to buffers shared by every body of its colour, and the whole
// field goes out in a handful of point and line draws per colour, however
// many bodies there are. A body's motion is its grains' positions computed
// from the clock, so there are no baked poses to step between.
//
// Blur-free. Health reads off the body: a hurt shell has lost grains.
//
// Nothing stands still: shells turn and breathe, clots churn, the Sower's
// sand runs off its crest, the Crest's front shimmers, a Hollow's dust
// circles it and a Snare's mouth works. A body that has just entered the
// field gathers out of loose grains drawn in from behind it, round the
// bright point it is forming on ([RosterBatch.arrivalSeconds]).

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_kind.dart';

const _ink = Color(0xFF07060B);
const _white = Color(0xFFFFF6E4);
const _tau = pi * 2;

double _h(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// `x % 1.0`, bit for bit, for every finite [x] (both are the one rounding
/// of the same exact value, and +0 for a whole number), without the runtime
/// call Dart makes for a double's `%`.
double _fract(double x) => x - x.floorToDouble();

/// [_h] at [salt] for the places 0 to [n] - 1, worked out once, with [f]
/// applied: a grain's fixed hash read from a table instead of a sine a grain
/// a frame (the same doubles).
Float64List _hTab(int salt, int n, [double Function(double h)? f]) {
  final t = Float64List(n);
  for (var i = 0; i < n; i++) {
    final h = _h(i, salt);
    t[i] = f == null ? h : f(h);
  }
  return t;
}

/// [_h] at a body's own [seed] (0 to 1023, as survival's are) for its first
/// eight places, worked out once; any other seed is worked out as before.
final Float64List _seedH = () {
  final t = Float64List(8 * 1024);
  for (var seed = 0; seed < 1024; seed++) {
    for (var i = 0; i < 8; i++) {
      t[seed * 8 + i] = _h(i, seed);
    }
  }
  return t;
}();

double _hSeed(int i, int seed) => seed >= 0 && seed < 1024 && i >= 0 && i < 8
    ? _seedH[seed * 8 + i]
    : _h(i, seed);

class _Buf {
  Float32List d = Float32List(512);
  int n = 0;

  void add(double x, double y) {
    if (n + 2 > d.length) d = Float32List(d.length * 2)..setAll(0, d);
    d[n] = x;
    d[n + 1] = y;
    n += 2;
  }

  void line(double x0, double y0, double x1, double y1) {
    if (n + 4 > d.length) d = Float32List(d.length * 2)..setAll(0, d);
    d[n] = x0;
    d[n + 1] = y0;
    d[n + 2] = x1;
    d[n + 3] = y1;
    n += 4;
  }

  Float32List get view => Float32List.sublistView(d, 0, n);
}

/// One colour's grains and tubes. Tones: 0 the far side, 1 deep, 2 dark,
/// 3 the colour itself, 4 lit, 5 glint.
class _Palette {
  _Palette(Color c)
    : tone = [
        Color.lerp(c, _ink, 0.72)!.withValues(alpha: 0.55),
        Color.lerp(c, _ink, 0.72)!,
        Color.lerp(c, _ink, 0.42)!,
        c,
        Color.lerp(c, _white, 0.35)!,
        Color.lerp(c, _white, 0.75)!,
      ],
      massTone = Color.lerp(c, _ink, 0.78)!,
      capTone = Color.lerp(c, _ink, 0.58)!;

  final List<Color> tone;
  final Color massTone, capTone;
  final List<_Buf> pts = List.generate(6, (_) => _Buf());

  /// The same tones in a heavier grain (1.35x): the plates of a heavy body,
  /// which have to cover it for its shape and shading to read at play size.
  final List<_Buf> big = List.generate(6, (_) => _Buf());

  /// The bright grain that leads a mote or a strand.
  final _Buf heads = _Buf();

  /// Tube segments: the thick half, the thin half, and the lit core.
  final _Buf thick = _Buf(), thin = _Buf(), core = _Buf();

  /// The dark mass under a heavy body's grains, so it reads as a body at
  /// play scale and not as loose dust.
  final Path body = Path();
  bool hasBody = false;

  /// The mass's lit side: a second, lighter mass set toward the light, so a
  /// body is a ball before a single grain is drawn on it.
  final Path cap = Path();

  /// Every buffer: grains (fine, then heavy), then the heads and the tubes.
  late final List<_Buf> all = [...pts, ...big, heads, thick, thin, core];

  /// How much of its mass a body arriving has gathered, 0..1.
  double scale = 1;

  void mass(double cx, double cy, double rx, double ry) {
    rx *= scale;
    ry *= scale;
    if (rx < 0.5) return;
    body.addOval(Rect.fromLTRB(cx - rx, cy - ry, cx + rx, cy + ry));
    final ox = cx - rx * 0.17, oy = cy - ry * 0.19;
    cap.addOval(
      Rect.fromLTRB(
        ox - rx * 0.76,
        oy - ry * 0.76,
        ox + rx * 0.76,
        oy + ry * 0.76,
      ),
    );
    hasBody = true;
  }

  bool used = false;
}

/// Grains on a sphere, cut into bands that turn against each other.
class _Shell {
  _Shell(
    int n, {
    required this.bands,
    int segs = 3,
    double fill = 0.74,
    double gap = 0.14,
    int salt = 0,
  }) {
    final xs = <double>[], ys = <double>[], zs = <double>[];
    final bs = <int>[];
    for (var i = 0; xs.length < n && i < n * 4; i++) {
      final u = _h(i, 1 + salt), y = 2 * u - 1, lon = _h(i, 2 + salt) * _tau;
      final b = min(bands - 1, (u * bands).floor());
      if ((u * bands) % 1.0 < gap) continue;
      if ((lon * (segs + b) / _tau) % 1.0 > fill) continue;
      final cl = sqrt(1 - y * y);
      xs.add(cl * cos(lon));
      ys.add(y);
      zs.add(cl * sin(lon));
      bs.add(b);
    }
    x = Float32List.fromList(xs);
    y = Float32List.fromList(ys);
    z = Float32List.fromList(zs);
    band = Uint8List.fromList(bs);
  }

  final int bands;
  late final Float32List x, y, z;
  late final Uint8List band;
  int get length => x.length;
}

/// Grains filling a lit ball: unit position, depth, tone, and which of
/// three rings (by distance from the middle) it turns with.
class _Ball {
  _Ball(int n, {int salt = 0})
    : x = Float32List(n),
      y = Float32List(n),
      z = Float32List(n),
      tone = Uint8List(n),
      ring = Uint8List(n) {
    for (var i = 0; i < n; i++) {
      final rho = sqrt(_h(i, 11 + salt)), a = _h(i, 12 + salt) * _tau;
      x[i] = rho * cos(a);
      y[i] = rho * sin(a);
      z[i] = sqrt(max(0.0, 1 - rho * rho));
      tone[i] = _ballTone(x[i], y[i], z[i]);
      ring[i] = min(2, (rho * 3).floor());
    }
  }

  final Float32List x, y, z;
  final Uint8List tone, ring;
}

/// A ball grain's tone from where it sits.
int _ballTone(double x, double y, double z) =>
    _tone(0.45 + 0.55 * (-0.5 * x - 0.62 * y + 0.6 * z));

/// The tone of a near-side grain lit [light] (0..1): most of a body is the
/// colour itself, its lit side lighter, and only the hot spot glints. Never
/// darker than the dark tone, so a shaded grain stands off the mass.
int _tone(double light) =>
    light < 0.3 ? 2 : (light < 0.68 ? 3 : (light < 0.9 ? 4 : 5));

/// Collects every kind body in view and draws them together.
class RosterBatch {
  final Map<int, _Palette> _palettes = {};
  final _Palette _flash = _Palette(_white);
  final List<_Palette> _order = [];

  // Hollows: the gap itself, drawn under everything.
  final List<double> _voids = [];

  static final _husk = _Shell(620, bands: 3, segs: 2, fill: 0.8, gap: 0.17);
  static final _crust = _Shell(90, bands: 3, fill: 0.5, gap: 0.12, salt: 3);
  static final _band = _Shell(72, bands: 3, fill: 0.55, gap: 0.1, salt: 5);
  static final _egg = _Shell(480, bands: 1, segs: 1, fill: 1, gap: 0, salt: 7);
  static final _ball = _Ball(170);
  static final _cage = _Shell(
    320,
    bands: 4,
    segs: 2,
    fill: 0.55,
    gap: 0.08,
    salt: 9,
  );
  static final _cs = Float64List(8), _sn = Float64List(8);

  // What each kind's grains hash to, by their place: the same doubles the
  // frame used to work out ([_hTab]).
  static final _hollowDepth = () {
    final t = Float64List(72);
    for (var i = 0; i < 72; i++) {
      t[i] = i % 10 < 7 ? _h(i, 112) * 0.12 : 0.12 + pow(_h(i, 112), 1.6) * 0.5;
    }
    return t;
  }();
  static final _hollowStart = _hTab(111, 72, (h) => h * _tau);
  static final _h113 = _hTab(113, 34), _h114 = _hTab(114, 34);
  static final _h115 = _hTab(115, 10);
  static final _slipStart = _hTab(116, 10, (h) => h * _tau);
  static final _spillRad = _hTab(101, 84, (h) => 0.3 + 1.0 * pow(h, 1.5));
  static final _spillStart = _hTab(102, 84, (h) => h * _tau);
  static final _armOut = _hTab(71, 16, (h) => pow(h, 0.6).toDouble());
  static final _h72 = _hTab(72, 16);
  static final _h90 = _hTab(90, 14);
  static final _blownCos = _hTab(89, 14, (h) => cos((h * 2 - 1) * 1.0));
  static final _blownSin = _hTab(89, 14, (h) => sin((h * 2 - 1) * 1.0));
  static final _frontOff = _hTab(93, 140, (h) => (h * 2 - 1) * 0.8);
  static final _frontDip = () {
    final t = Float64List(140);
    for (var i = 0; i < 140; i++) {
      t[i] = _h(i, 94) * _h(i, 97);
    }
    return t;
  }();
  static final _shedOff = _hTab(95, 40, (h) => (h * 2 - 1) * 0.8);
  static final _h96 = _hTab(96, 40);
  static final _rootQ = _hTab(151, 480);
  static final _rootSide = _hTab(152, 480, (h) => h * 2 - 1);
  static final double _ct = cos(0.42), _st = sin(0.42);

  static final Paint _pt = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  static final Paint _void = Paint()
    ..shader = Gradient.radial(
      Offset.zero,
      1,
      const [
        Color(0xFF040306),
        Color(0xFF040306),
        Color(0xC0040306),
        Color(0x00040306),
      ],
      const [0.0, 0.66, 0.86, 1.0],
    );
  static final Paint _mass = Paint();

  // The last colour asked for and its palette: a field is mostly one
  // element, so most bodies skip the lookup.
  Color? _lastColor;
  _Palette? _lastPalette;

  _Palette _palette(Color c) {
    final _Palette p;
    if (identical(c, _lastColor)) {
      p = _lastPalette!;
    } else {
      p = _palettes.putIfAbsent(c.toARGB32(), () => _Palette(c));
      _lastColor = c;
      _lastPalette = p;
    }
    if (!p.used) {
      p.used = true;
      _order.add(p);
    }
    return p;
  }

  /// Seconds a body of [kind] takes to gather when it enters the field.
  static double arrivalSeconds(SurvivalKind kind) => switch (kind) {
    SurvivalKind.mote => 0.6,
    SurvivalKind.strand => 0.7,
    SurvivalKind.braid => 0.8,
    SurvivalKind.spill || SurvivalKind.hollow => 0.9,
    SurvivalKind.lobber || SurvivalKind.siphon || SurvivalKind.snare => 1.0,
    SurvivalKind.husk ||
    SurvivalKind.crest ||
    SurvivalKind.clutch ||
    SurvivalKind.core => 1.2,
    SurvivalKind.sower => 1.5,
  };

  /// Where each of a palette's buffers stood before the body arriving now
  /// was added, so its grains alone can be gathered.
  final Int32List _from = Int32List(16);

  /// Adds survival's (or a dungeon's) [e]. [dense] thins the crowd's bodies
  /// on a packed field; [arrive] overrides how far it has gathered (a mode
  /// that does not keep a body's age passes 1).
  void add(
    CosmicSurvivalEnemy e,
    SurvivalKind kind,
    double time,
    Offset orb, {
    bool dense = false,
    double? arrive,
  }) {
    addBody(
      kind: kind,
      time: time,
      position: e.position,
      radius: e.radius,
      heading: e.facing.follow(
        e.action.isBusy ? e.action.aimAngle : e.angle,
        time,
      ),
      hp: e.hpFraction,
      color: e.visualColor ?? elementColor(e.element),
      seed: identityHashCode(e) & 1023,
      hitFlash: e.hitFlash,
      arrive:
          arrive ??
          (e.age >= 2 ? 1.0 : (e.age / arrivalSeconds(kind)).clamp(0.0, 1.0)),
      summonCooldown: e.summonCooldown,
      snareClosed: e.snareClosed,
      orb: orb,
      dense: dense,
    );
  }

  /// Adds a body of [kind] from plain values, for a mode whose enemies are
  /// not survival's (open space). [heading] is where it faces, [hp] 0..1,
  /// [seed] any stable small number for the body, [arrive] 0..1 how far it
  /// has gathered on entering.
  /// [orb] is what a Siphon latches to, if anything.
  void addBody({
    required SurvivalKind kind,
    required double time,
    required Offset position,
    required double radius,
    required double heading,
    required double hp,
    required Color color,
    required int seed,
    double hitFlash = 0,
    double arrive = 1,
    double summonCooldown = 0,
    bool snareClosed = false,
    Offset? orb,
    bool dense = false,
  }) {
    final _Palette p;
    if (hitFlash > 0.3) {
      p = _flash;
      if (!p.used) {
        p.used = true;
        _order.add(p);
      }
    } else {
      p = _palette(color);
    }
    // How far it has gathered, for a body still arriving (the rest never
    // read it).
    final gathered = arrive < 1 ? 1 - pow(1 - arrive, 3).toDouble() : 1.0;
    if (arrive < 1) {
      for (var b = 0; b < 16; b++) {
        _from[b] = p.all[b].n;
      }
      p.scale = gathered * gathered;
    }
    final hc = cos(heading), hs = sin(heading);
    final cx = position.dx, cy = position.dy;
    // Heavy bodies breathe.
    final r = switch (kind) {
      SurvivalKind.husk ||
      SurvivalKind.lobber ||
      SurvivalKind.siphon ||
      SurvivalKind.snare => radius * (1 + 0.035 * sin(time * 2.3 + seed)),
      _ => radius,
    };
    switch (kind) {
      case SurvivalKind.mote:
        _mote(p, cx, cy, r, hc, hs, time, seed, dense);
      case SurvivalKind.strand:
        _strand(p, cx, cy, r, hc, hs, time, seed);
      case SurvivalKind.braid:
        _braid(p, cx, cy, r, hc, hs, time, seed);
      case SurvivalKind.husk:
        p.mass(cx, cy, r * 0.98, r * 0.98);
        _shell(p, _husk, cx, cy, r * 1.02, 1, time * 0.7 + seed, hp, big: true);
      case SurvivalKind.hollow:
        _hollow(p, cx, cy, r, hc, hs, time, seed);
      case SurvivalKind.spill:
        _spill(p, cx, cy, r, time, seed);
      case SurvivalKind.lobber:
        _lobber(p, cx, cy, r, hc, hs, time, seed, hp);
      case SurvivalKind.clutch:
        _clutch(p, cx, cy, r, time, seed, hp, summonCooldown);
      case SurvivalKind.siphon:
        _siphon(p, cx, cy, r, time, seed, orb ?? const Offset(1e9, 1e9));
      case SurvivalKind.sower:
        _sower(p, cx, cy, r, hc, hs, time, hp);
      case SurvivalKind.crest:
        _crest(p, cx, cy, r, heading, time, hp);
      case SurvivalKind.snare:
        _snare(p, cx, cy, r, hc, hs, time, seed, snareClosed);
      case SurvivalKind.core:
        _core(p, cx, cy, r, time, seed, hp);
    }
    if (arrive < 1) {
      _gather(p, cx, cy, radius, hc, hs, gathered, seed);
      p.scale = 1;
    }
  }

  /// The body just added, as it is [gathered] (0..1) out of loose grains:
  /// at first a few grains far out and swung round, most of them still
  /// behind it where it came from, closing on the bright point it forms
  /// on and thickening as they come. Its tubes uncoil out of that point.
  void _gather(
    _Palette p,
    double cx,
    double cy,
    double r,
    double hc,
    double hs,
    double gathered,
    int seed,
  ) {
    final u = 1 - gathered;
    final dir = seed.isEven ? 1.0 : -1.0;
    for (var bi = 0; bi < 12; bi++) {
      final b = p.all[bi];
      final d = b.d;
      var w = _from[bi];
      for (var j = w, i = seed; j < b.n; j += 2, i++) {
        final h1 = _h(i, 31), h2 = _h(i, 37);
        if (h1 > 0.12 + 1.5 * gathered) continue;
        final dx = d[j] - cx, dy = d[j + 1] - cy;
        final th = dir * u * (2.2 + 1.6 * h2);
        final sc = 1 + u * (1.5 + 3.5 * h2);
        final c = cos(th), sn = sin(th);
        final back = r * u * (1.0 + 2.5 * h1);
        d[w] = cx + sc * (dx * c - dy * sn) - hc * back;
        d[w + 1] = cy + sc * (dx * sn + dy * c) - hs * back;
        w += 2;
      }
      b.n = w;
    }
    if (gathered < 0.85) p.heads.add(cx, cy);
    final sc = 0.2 + 0.8 * gathered, th = dir * u * 1.6;
    final c = cos(th) * sc, sn = sin(th) * sc;
    for (var bi = 12; bi < 16; bi++) {
      final b = p.all[bi];
      final d = b.d;
      for (var j = _from[bi]; j < b.n; j += 2) {
        final dx = d[j] - cx, dy = d[j + 1] - cy;
        d[j] = cx + dx * c - dy * sn;
        d[j + 1] = cy + dx * sn + dy * c;
      }
    }
  }

  void _shell(
    _Palette p,
    _Shell t,
    double cx,
    double cy,
    double r,
    double ry,
    double spin,
    double hp, {
    bool nearOnly = false,
    bool big = false,
  }) {
    final pts = big ? p.big : p.pts;
    final cs = _cs, sn = _sn, ct = _ct, st = _st;
    for (var k = 0; k < t.bands; k++) {
      final a = k.isEven ? spin : -spin;
      cs[k] = cos(a);
      sn[k] = sin(a);
    }
    // A hurt shell has lost grains.
    final n = (t.length * (0.45 + 0.55 * hp)).floor();
    final x0 = t.x, y0 = t.y, z0 = t.z, band = t.band;
    final far = p.pts[0];
    for (var i = 0; i < n; i++) {
      final k = band[i];
      final x = x0[i] * cs[k] - z0[i] * sn[k];
      final z = x0[i] * sn[k] + z0[i] * cs[k];
      final yy = y0[i] * ct - z * st, zz = y0[i] * st + z * ct;
      if (zz <= 0) {
        if (!nearOnly) far.add(cx + r * x, cy - r * ry * yy);
        continue;
      }
      pts[_tone(0.5 + 0.5 * (-0.5 * x + 0.62 * yy + 0.6 * zz))].add(
        cx + r * x,
        cy - r * ry * yy,
      );
    }
  }

  /// [n] grains of a lit ball. With [churn] it turns over: its middle
  /// fastest, its rim slowest, each grain lit by where it is now.
  void _lit(
    _Palette p,
    double cx,
    double cy,
    double r,
    int n, {
    bool big = false,
    double churn = 0,
  }) {
    final pts = big ? p.big : p.pts;
    final b = _ball;
    if (churn == 0) {
      for (var i = 0; i < n; i++) {
        pts[b.tone[i]].add(cx + r * b.x[i], cy + r * b.y[i]);
      }
      return;
    }
    final cs = _cs, sn = _sn;
    for (var k = 0; k < 3; k++) {
      final a = churn * (1.5 - 0.45 * k);
      cs[k] = cos(a);
      sn[k] = sin(a);
    }
    final bx = b.x, by = b.y, bz = b.z, ring = b.ring;
    for (var i = 0; i < n; i++) {
      final k = ring[i];
      final x = bx[i] * cs[k] - by[i] * sn[k];
      final y = bx[i] * sn[k] + by[i] * cs[k];
      pts[_ballTone(x, y, bz[i])].add(cx + r * x, cy + r * y);
    }
  }

  void _mote(
    _Palette p,
    double cx,
    double cy,
    double r,
    double hc,
    double hs,
    double time,
    int seed,
    bool dense,
  ) {
    // A tight clump that churns, so it is one thing and not loose specks.
    final spin = time * 1.4 + seed;
    final sc = cos(spin), ss = sin(spin);
    final n = dense ? 11 : 18;
    final pulse = 0.72 + 0.08 * sin(time * 4.1 + seed);
    for (var i = 0; i < n; i++) {
      final x = _ball.x[i] * pulse, y = _ball.y[i] * pulse;
      p.big[_ball.tone[i]].add(
        cx + r * (x * sc - y * ss),
        cy + r * (x * ss + y * sc),
      );
    }
    // What it sheds, a short wake close behind it.
    for (var i = 0; i < (dense ? 2 : 4); i++) {
      final s = _fract(_hSeed(i, seed) + time * 0.9);
      final back = r * (0.7 + 1.5 * s);
      final side = r * 0.3 * sin(time * 3 + seed + i * 2.1) * s;
      p.pts[s < 0.45 ? 3 : (s < 0.75 ? 2 : 0)].add(
        cx - hc * back - hs * side,
        cy - hs * back + hc * side,
      );
    }
    p.heads.add(cx + hc * r * 0.15, cy + hs * r * 0.15);
  }

  void _strand(
    _Palette p,
    double cx,
    double cy,
    double r,
    double hc,
    double hs,
    double time,
    int seed,
  ) {
    const links = 14;
    final len = r * 3.2;
    var px = cx + hc * r * 0.6, py = cy + hs * r * 0.6;
    p.heads.add(px, py);
    for (var i = 1; i <= links; i++) {
      final s = i / links;
      final back = len * s - r * 0.6;
      final side = r * 0.42 * sin(s * 5.5 - time * 9 + seed) * (0.3 + 0.7 * s);
      final x = cx - hc * back - hs * side, y = cy - hs * back + hc * side;
      (i <= links ~/ 2 ? p.thick : p.thin).line(px, py, x, y);
      if (i < links) p.core.line(px, py, x, y);
      px = x;
      py = y;
    }
  }

  void _braid(
    _Palette p,
    double cx,
    double cy,
    double r,
    double hc,
    double hs,
    double time,
    int seed,
  ) {
    const links = 18;
    final len = r * 3.0;
    for (var j = 0; j < 3; j++) {
      var px = cx + hc * r * 0.5, py = cy + hs * r * 0.5;
      for (var i = 1; i <= links; i++) {
        final s = i / links;
        final back = len * s - r * 0.5;
        final a = s * _tau * 1.25 + j * _tau / 3 - time * 4 + seed;
        final side = r * 0.5 * (1 - 0.4 * s) * sin(a);
        final x = cx - hc * back - hs * side, y = cy - hs * back + hc * side;
        final ca = cos(a);
        (ca > 0 ? p.thick : p.thin).line(px, py, x, y);
        if (ca > 0.2) p.core.line(px, py, x, y);
        px = x;
        py = y;
      }
    }
    _lit(
      p,
      cx + hc * r * 0.55,
      cy + hs * r * 0.55,
      r * 0.42,
      18,
      churn: time * 2 + seed,
    );
    p.heads.add(cx + hc * r * 0.7, cy + hs * r * 0.7);
  }

  void _hollow(
    _Palette p,
    double cx,
    double cy,
    double r,
    double hc,
    double hs,
    double time,
    int seed,
  ) {
    _voids
      ..add(cx)
      ..add(cy)
      ..add(r * p.scale);
    final dir = seed.isEven ? 1.0 : -1.0;
    final ahead = atan2(hs, hc);
    // The lip: most of the dust it pushes aside packed tight at the edge,
    // lit where it faces the light; the rest strewn further out, heaviest
    // ahead. All of it circles, the inner grains quicker.
    final depths = _hollowDepth, starts = _hollowStart;
    for (var i = 0; i < 72; i++) {
      final packed = i % 10 < 7;
      final depth = depths[i];
      final rr = r * (1.0 + depth + 0.03 * sin(time * 2 + i));
      final a = starts[i] + dir * time * (0.9 - 0.8 * depth) + seed;
      final x = cos(a), y = sin(a);
      final int tone;
      if (packed) {
        // How squarely this bit of lip faces the light (upper left).
        final lit = -0.63 * x - 0.78 * y;
        tone = lit > 0.55 ? 4 : (lit > -0.2 ? 3 : 2);
      } else {
        var off = a - ahead;
        off -= (off / _tau).roundToDouble() * _tau;
        tone = off.abs() < 0.8 ? 3 : (off.abs() < 1.8 ? 2 : 0);
      }
      p.pts[tone].add(cx + rr * x, cy + rr * y);
    }
    // The far wall, just inside the lip opposite the light, catching it:
    // the light falls into the hole, so the hole has a depth.
    for (var i = 0; i < 34; i++) {
      final s = _fract(_h113[i] + time * 0.06 * dir);
      final mid = 1 - (2 * s - 1).abs();
      final a = 0.89 + (s - 0.5) * 2.4;
      final rr = r * (0.97 - 0.16 * _h114[i] * mid);
      p.pts[mid > 0.7 ? 5 : (mid > 0.4 ? 4 : 3)].add(
        cx + rr * cos(a),
        cy + rr * sin(a),
      );
    }
    // Grains slipping over the lip, darker as they fall and lost below.
    for (var i = 0; i < 10; i++) {
      final s = _fract(_h115[i] + time * 0.32);
      final rr = r * (0.98 - 0.8 * s);
      final a = _slipStart[i] + seed + dir * s * 2.2;
      p.pts[s < 0.35 ? 3 : (s < 0.7 ? 2 : 0)].add(
        cx + rr * cos(a),
        cy + rr * sin(a),
      );
    }
  }

  void _spill(
    _Palette p,
    double cx,
    double cy,
    double r,
    double time,
    int seed,
  ) {
    p.mass(cx, cy, r * 0.45, r * 0.45);
    final rads = _spillRad, starts = _spillStart;
    for (var i = 0; i < 84; i++) {
      final rad = rads[i];
      final dir = i % 4 == 0 ? -0.6 : 1.0;
      final a = starts[i] + seed + dir * time * 1.5 / rad;
      final b = rad > 1.05 ? 0 : 2 + (i % 4);
      p.pts[b].add(cx + r * rad * cos(a), cy + r * rad * 0.92 * sin(a));
      // Each grain drags a second behind it, so the turning shows.
      final a2 = a - dir * 0.22 / rad;
      p.pts[b > 2 ? b - 1 : 0].add(
        cx + r * rad * cos(a2),
        cy + r * rad * 0.92 * sin(a2),
      );
    }
    p.heads.add(cx, cy);
  }

  void _lobber(
    _Palette p,
    double cx,
    double cy,
    double r,
    double hc,
    double hs,
    double time,
    int seed,
    double hp,
  ) {
    p.mass(cx, cy, r * 0.95, r * 0.95);
    _lit(
      p,
      cx,
      cy,
      r * 0.9,
      (130 * (0.5 + 0.5 * hp)).floor(),
      big: true,
      churn: time * 0.9 + seed,
    );
    // The crust, dark over the lit clot, its plates turning on it.
    final spin = time * 0.5 + seed;
    final cs = _cs, sn = _sn, ct = _ct, st = _st;
    final crust = _crust;
    for (var k = 0; k < crust.bands; k++) {
      final a = k.isEven ? spin : -spin;
      cs[k] = cos(a);
      sn[k] = sin(a);
    }
    final x0 = crust.x, y0 = crust.y, z0 = crust.z, band = crust.band;
    final plates = p.big[1];
    for (var i = 0; i < crust.length; i++) {
      final k = band[i];
      final x = x0[i] * cs[k] - z0[i] * sn[k];
      final z = x0[i] * sn[k] + z0[i] * cs[k];
      final yy = y0[i] * ct - z * st;
      if (y0[i] * st + z * ct <= 0) continue;
      plates.add(cx + r * x, cy - r * yy);
    }
    // Its arm of sand, swinging out toward what it shells.
    final lob = _fract(time / 1.8 + seed * 0.37);
    final reach = 0.3 + 0.7 * lob * lob * (3 - 2 * lob);
    for (var i = 0; i < 16; i++) {
      final s = _armOut[i] * reach;
      final out = r * (1.0 + 2.2 * s);
      final lift = r * 1.5 * s * (1 - s) * 2;
      final w = r * 0.3 * (1 - s / reach) * (_h72[i] - 0.5);
      p.pts[s > reach * 0.6 ? 4 : 2].add(
        cx + hc * out - hs * w,
        cy + hs * out + hc * w - lift,
      );
    }
    final tip = r * (1.0 + 2.2 * reach);
    p.heads.add(
      cx + hc * tip,
      cy + hs * tip - r * 1.5 * reach * (1 - reach) * 2,
    );
  }

  void _clutch(
    _Palette p,
    double cx,
    double cy,
    double r,
    double time,
    int seed,
    double hp,
    double summonCooldown,
  ) {
    // The seam lights from the foot up as the next hatch nears, and the
    // egg throbs harder and faster, so how soon it sends more is read off
    // the body.
    final ready =
        1 -
        (summonCooldown / CosmicSurvivalBalance.broodInterval).clamp(0.0, 1.0);
    r *= 1 + (0.02 + 0.05 * ready) * sin(time * (2.2 + 5 * ready) + seed);
    p.mass(cx, cy, r * 0.95, r * 1.25);
    _shell(
      p,
      _egg,
      cx,
      cy,
      r * 0.97,
      1.3,
      0.35 * sin(time * 0.8 + seed) + time * 0.25,
      hp,
      big: true,
    );
    final lit = 4 + (16 * ready).round();
    for (var i = 0; i < 20; i++) {
      final s = i / 20;
      final y = r * (1.05 - 2.0 * s);
      final x = r * (0.3 * (_fract(s * 5) - 0.5).abs() * 2 - 0.22);
      (i < lit ? p.heads : p.pts[1]).add(cx + x, cy + y);
    }
  }

  void _siphon(
    _Palette p,
    double cx,
    double cy,
    double r,
    double time,
    int seed,
    Offset orb,
  ) {
    p.mass(cx, cy, r * 0.8, r * 0.8);
    _lit(p, cx, cy, r * 0.75, 80, big: true, churn: time * 1.3 + seed);
    _shell(p, _band, cx, cy, r, 1, time * 0.6 + seed, 1, nearOnly: true);
    final dx = orb.dx - cx, dy = orb.dy - cy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist > CosmicSurvivalBalance.siphonHoldRange * 1.12 || dist < 1) {
      return;
    }
    // Latched: the tube to the orb, sagging, and the orb's grains coming
    // down it.
    const links = 10;
    final nx = -dy / dist, ny = dx / dist;
    final sag = dist * 0.16 * (1 + 0.15 * sin(time * 1.5 + seed));
    var px = cx, py = cy;
    for (var i = 1; i <= links; i++) {
      final s = i / links, bow = sin(s * pi) * sag;
      final x = cx + dx * s * 0.9 + nx * bow, y = cy + dy * s * 0.9 + ny * bow;
      p.thin.line(px, py, x, y);
      p.core.line(px, py, x, y);
      px = x;
      py = y;
    }
    for (var i = 0; i < 5; i++) {
      final s = 1 - _fract(_hSeed(i, seed) + time * 0.5),
          bow = sin(s * pi) * sag;
      p.pts[5].add(cx + dx * s * 0.9 + nx * bow, cy + dy * s * 0.9 + ny * bow);
    }
  }

  static final Float32List _duneX = Float32List(_duneN);
  static final Float32List _duneY = Float32List(_duneN);
  static final Uint8List _duneTone = Uint8List(_duneN);

  /// The bank's grains: how far down the bank each starts (0..1), and its
  /// place across the bank's width (-1..1).
  static final Float32List _bankF = Float32List(_duneN - _bankFrom);
  static final Float32List _bankW = Float32List(_duneN - _bankFrom);
  static const _duneN = 560;
  static const _crescentN = 380, _slipN = 440, _bankFrom = _slipN;
  static bool _duneBuilt = false;
  static final Float64List _m = Float64List(16)
    ..[10] = 1
    ..[15] = 1;

  /// The dune's mass in its own frame, +x ahead: a disc with a bite out of
  /// its lee.
  static final Path _crescent = Path()
    ..moveTo(-0.006, -0.8625)
    ..arcToPoint(
      const Offset(-0.006, 0.8625),
      radius: const Radius.circular(1),
      largeArc: true,
    )
    ..arcToPoint(
      const Offset(-0.006, -0.8625),
      radius: const Radius.circular(0.87),
      clockwise: false,
    )
    ..close();

  /// The dune in its own frame: moving toward -x, the bank trailing to +x.
  static void _buildDune() {
    _duneBuilt = true;
    var n = 0;
    // The crescent: a disc with a bite out of its lee.
    for (var i = 0; n < _crescentN; i++) {
      final rho = sqrt(_h(i, 85)), a = _h(i, 86) * _tau;
      final x = -0.5 + rho * cos(a), y = rho * sin(a);
      final d = sqrt((x - 0.12) * (x - 0.12) + y * y) - 0.87;
      if (d < 0) continue;
      _duneX[n] = x;
      _duneY[n] = y;
      _duneTone[n] = 1 + ((0.3 + 0.65 * exp(-d / 0.1)) * 4).round().clamp(0, 4);
      n++;
    }
    // The slip face under the crest, in shadow.
    for (var i = 0; n < _slipN; i++) {
      final a = pi + (_h(i, 87) * 2 - 1) * 1.0;
      final rr = 0.87 - pow(_h(i, 88), 1.6) * 0.26;
      _duneX[n] = 0.12 + rr * cos(a);
      _duneY[n] = rr * sin(a);
      _duneTone[n] = 1;
      n++;
    }
    // The bank behind it: where each grain starts down it. The grains run
    // down it as it walks (_sower).
    for (var i = 0; n < _duneN; i++) {
      _bankF[n - _bankFrom] = _h(i, 81);
      _bankW[n - _bankFrom] = (_h(i, 82) * 2 - 1) * sqrt(_h(i, 83));
      n++;
    }
  }

  void _sower(
    _Palette p,
    double cx,
    double cy,
    double r,
    double hc,
    double hs,
    double time,
    double hp,
  ) {
    if (!_duneBuilt) _buildDune();
    _m[0] = r * hc;
    _m[1] = r * hs;
    _m[4] = -r * hs;
    _m[5] = r * hc;
    _m[12] = cx;
    _m[13] = cy;
    if (p.scale < 1) {
      for (final k in const [0, 1, 4, 5]) {
        _m[k] *= p.scale;
      }
    }
    if (p.scale > 0.05) {
      p.body.addPath(_crescent, Offset.zero, matrix4: _m);
      p.hasBody = true;
    }
    final n = (_duneN * (0.5 + 0.5 * hp)).floor();
    // Local -x is ahead. The crescent's sand ripples over it, front to
    // back; the bank's runs off down it and is lost at its tail.
    for (var i = 0; i < n; i++) {
      double lx, ly;
      final int tone;
      if (i < _bankFrom) {
        ly = _duneY[i];
        lx = _duneX[i] + 0.035 * sin(ly * 9 + _duneX[i] * 6 + time * 4.5);
        tone = _duneTone[i];
      } else {
        final f = _fract(_bankF[i - _bankFrom] + time * 0.16);
        lx = 0.1 + 2.3 * f;
        ly = _bankW[i - _bankFrom] * (0.95 - 0.32 * f);
        tone = f < 0.3 ? 3 : (f < 0.6 ? 2 : 0);
      }
      final x = -lx * r, y = ly * r;
      (i < _crescentN ? p.big : p.pts)[tone].add(
        cx + hc * x - hs * y,
        cy + hs * x + hc * y,
      );
    }
    // Sand blown off the crest, falling to the bank.
    for (var i = 0; i < 14; i++) {
      final s = _fract(_h90[i] + time * 0.45);
      final x = r * (0.87 * _blownCos[i] - 0.12 - 0.9 * s),
          y = r * 0.87 * _blownSin[i];
      p.pts[s < 0.5 ? 4 : 2].add(cx + hc * x - hs * y, cy + hs * x + hc * y);
    }
  }

  /// A wide bright front, bowed toward where it is going, with what it
  /// sheds falling away behind it.
  void _crest(
    _Palette p,
    double cx,
    double cy,
    double r,
    double heading,
    double time,
    double hp,
  ) {
    final bow = r * 2.4;
    final ox = cx - cos(heading) * bow, oy = cy - sin(heading) * bow;
    final front = (140 * (0.45 + 0.55 * hp)).floor();
    final offs = _frontOff, dips = _frontDip;
    for (var i = 0; i < front; i++) {
      final off = i < 140 ? offs[i] : (_h(i, 93) * 2 - 1) * 0.8;
      final dip = i < 140 ? dips[i] : _h(i, 94) * _h(i, 97);
      // A shimmer runs along the front, out from its middle.
      final rr =
          bow - dip * r * 0.22 + r * 0.07 * sin(off.abs() * 11 - time * 3.2);
      p.big[off.abs() < 0.45 ? 5 : 4].add(
        ox + rr * cos(heading + off),
        oy + rr * sin(heading + off),
      );
    }
    for (var i = 0; i < 40; i++) {
      final off = _shedOff[i];
      final s = _fract(_h96[i] + time * 0.25);
      final rr = bow - r * (0.2 + 1.5 * s * s);
      p.pts[s < 0.45 ? 3 : (s < 0.75 ? 2 : 0)].add(
        ox + rr * cos(heading + off),
        oy + rr * sin(heading + off),
      );
    }
  }

  /// A shell with its mouth open toward what it is after, tendrils out
  /// ahead of it; closed, a cage turning round the Alchemon it holds.
  void _snare(
    _Palette p,
    double cx,
    double cy,
    double r,
    double hc,
    double hs,
    double time,
    int seed,
    bool closed,
  ) {
    final t = _cage;
    final spin = (closed ? time * 1.3 : time * 0.4) + seed;
    final cs = _cs, sn = _sn, ct = _ct, st = _st;
    for (var k = 0; k < t.bands; k++) {
      final a = k.isEven ? spin : -spin;
      cs[k] = cos(a);
      sn[k] = sin(a);
    }
    final rr = closed ? max(r * 1.7, 24.0) : r * 1.05;
    if (!closed) p.mass(cx, cy, r * 0.92, r * 0.92);
    // Open, its mouth works.
    final mouth = 0.42 + 0.14 * sin(time * 2.4 + seed);
    final x0 = t.x, y0 = t.y, z0 = t.z, band = t.band;
    for (var i = 0; i < t.length; i++) {
      final k = band[i];
      final x = x0[i] * cs[k] - z0[i] * sn[k];
      final z = x0[i] * sn[k] + z0[i] * cs[k];
      final yy = y0[i] * ct - z * st, zz = y0[i] * st + z * ct;
      // The open mouth, toward its heading.
      if (!closed && x * hc - yy * hs > mouth) continue;
      if (zz <= 0) {
        p.pts[closed ? 2 : 0].add(cx + rr * x, cy - rr * yy);
        continue;
      }
      p.big[_tone(0.5 + 0.5 * (-0.5 * x + 0.62 * yy + 0.6 * zz))].add(
        cx + rr * x,
        cy - rr * yy,
      );
    }
    if (closed) return;
    for (var j = 0; j < 4; j++) {
      final side = (j - 1.5) * r * 0.42;
      var px = cx + hc * r * 0.5 - hs * side,
          py = cy + hs * r * 0.5 + hc * side;
      for (var i = 1; i <= 6; i++) {
        final s = i / 6;
        final out = r * (0.5 + 1.5 * s);
        final w =
            side * (1 - 0.5 * s) +
            r * 0.28 * s * sin(s * 5 + j * 1.3 - time * 3 + seed);
        final x = cx + hc * out - hs * w, y = cy + hs * out + hc * w;
        p.thin.line(px, py, x, y);
        px = x;
        py = y;
      }
      p.heads.add(px, py);
    }
  }

  /// Grains and tube segments handed to the canvas by the last [flush].
  int lastGrains = 0;

  /// An outbreak's source: a churning lit knot on a dark mass, stream tubes
  /// writhing out of it all round. Worn down, it has fewer and shorter.
  void _core(
    _Palette p,
    double cx,
    double cy,
    double r,
    double time,
    int seed,
    double hp,
  ) {
    p.mass(cx, cy, r * 0.72, r * 0.72);
    _lit(
      p,
      cx,
      cy,
      r * 0.62,
      (150 * (0.45 + 0.55 * hp)).floor(),
      big: true,
      churn: time * 1.1 + seed,
    );
    final arms = 4 + (4 * hp).round();
    for (var k = 0; k < arms; k++) {
      final base = k * _tau / arms + time * 0.3 + seed;
      final len = r * (1.2 + 0.5 * hp + 0.3 * sin(time * 1.3 + k * 1.9));
      final bc = cos(base), bs = sin(base);
      var px = cx + bc * r * 0.55, py = cy + bs * r * 0.55;
      const links = 12;
      for (var i = 1; i <= links; i++) {
        final s = i / links;
        final out = r * 0.55 + len * s;
        final w = r * 0.32 * s * sin(s * 5 - time * 3 + k * 1.7);
        final x = cx + bc * out - bs * w, y = cy + bs * out + bc * w;
        (i <= links ~/ 2 ? p.thick : p.thin).line(px, py, x, y);
        if (i < links) p.core.line(px, py, x, y);
        // Its root is a band of grains, thinning out along it.
        if (i <= 7) {
          final girth = r * 0.2 * (1 - i / 8);
          for (var j = 0; j < 7; j++) {
            final at = j + i * 7 + k * 60;
            final q = at < 480 ? _rootQ[at] : _h(at, 151);
            final side = at < 480 ? _rootSide[at] : (_h(at, 152) * 2 - 1);
            final gx = px + (x - px) * q, gy = py + (y - py) * q;
            p.big[side.abs() > 0.7 ? 2 : (side.abs() > 0.3 ? 3 : 4)].add(
              gx - bs * girth * side,
              gy + bc * girth * side,
            );
          }
        }
        px = x;
        py = y;
      }
      p.heads.add(px, py);
    }
  }

  /// Draws everything added since the last flush. [grain] is a grain's
  /// diameter in world units.
  void flush(Canvas canvas, {double grain = 2.0}) {
    lastGrains = 0;
    // A Hollow's dark goes down: solid in the middle, its edge soft out
    // past the lip.
    for (var i = 0; i < _voids.length; i += 3) {
      final r = _voids[i + 2];
      if (r < 0.5) continue;
      canvas
        ..save()
        ..translate(_voids[i], _voids[i + 1])
        ..scale(r * 1.1)
        ..drawCircle(Offset.zero, 1, _void)
        ..restore();
    }
    _voids.clear();
    for (final p in _order) {
      _draw(canvas, p, grain);
    }
    _order.clear();
  }

  void _draw(Canvas canvas, _Palette p, double grain) {
    p.used = false;
    for (var b = 0; b < 12; b++) {
      lastGrains += p.all[b].n ~/ 2;
    }
    if (p.hasBody) {
      canvas.drawPath(p.body, _mass..color = p.massTone);
      canvas.drawPath(p.cap, _mass..color = p.capTone);
      p.body.reset();
      p.cap.reset();
      p.hasBody = false;
    }
    void lines(_Buf b, double w, Color c) {
      if (b.n == 0) return;
      canvas.drawRawPoints(
        PointMode.lines,
        b.view,
        _pt
          ..strokeWidth = w
          ..color = c,
      );
      b.n = 0;
    }

    lines(p.thick, grain * 1.8, p.tone[3]);
    lines(p.thin, grain * 1.1, p.tone[3]);
    lines(p.core, grain * 0.5, p.tone[5]);
    for (var t = 1; t < 6; t++) {
      final b = p.big[t];
      if (b.n == 0) continue;
      canvas.drawRawPoints(
        PointMode.points,
        b.view,
        _pt
          ..strokeWidth = grain * 1.35
          ..color = p.tone[t],
      );
      b.n = 0;
    }
    for (var t = 0; t < 6; t++) {
      final b = p.pts[t];
      if (b.n == 0) continue;
      canvas.drawRawPoints(
        PointMode.points,
        b.view,
        _pt
          ..strokeWidth = t == 0 ? grain * 0.8 : grain
          ..color = p.tone[t],
      );
      b.n = 0;
    }
    if (p.heads.n > 0) {
      canvas.drawRawPoints(
        PointMode.points,
        p.heads.view,
        _pt
          ..strokeWidth = grain * 2.2
          ..color = p.tone[5],
      );
      p.heads.n = 0;
    }
  }
}
