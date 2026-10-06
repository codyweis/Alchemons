// lib/games/planet_dungeon/blood_heart_fx.dart
//
// THE HEART's moments, in the Blood Rites' own house rules (eased, trailed
// grains that drift and dissolve; no bursts, flashes or hoops; nothing left
// at the end; no blur), plain Dart driven by time so a test can scrub it.
//
//   · RiteMorphFx — bodies come apart into grains of themselves, run along
//     bowed ways, and gather into other bodies: Blood taken up into its binding,
//     the four pouring in, two fusing into one, one splitting into two, an
//     element stepping out of what held it, the four re-forming.
//   · HeartRiseFx — EVERY ELEMENT SHOWS ITSELF (the author, 2026-10-06: "if
//     we form a crystal fusion, crystals form on the other side or something
//     visually cool, and if it happens to solve it then something else
//     happens"), IN GRAINS (the author, same day: "all our alchemy should
//     come from the particle looking style and animation"). The creature a
//     fusion made comes apart into its element the way the Elemental Essence
//     does (lib/widgets/fx/elemental_essence.dart: its own grains, heated
//     into the element's shades by their own brightness), pours up the
//     altar's column in that element's own motion to the first thing
//     hanging there, washes over it, and comes back down and gathers into
//     the creature again.
//   · HeartMatter — what hangs in the open space (ice, crystal, thorn, a
//     tear in the air), in grains too, and how each comes apart when it
//     gives way.

import 'dart:math' as math;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/painting.dart';

double _ease(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

double _hash(int n) {
  final s = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

Offset _curl(double x, double y, double t, double seed) => Offset(
  math.sin(y * 0.031 + t * 1.3 + seed) + 0.5 * math.sin(x * 0.017 - t * 0.7),
  math.cos(x * 0.029 - t * 1.1 + seed) + 0.5 * math.cos(y * 0.021 + t * 0.9),
);

// ═══════════════════════════ THE MORPH ═════════════════════════════════════

/// Bodies come apart and gather into others. The beats, in seconds (with
/// the default [flight]):
///  * 0.00 – 0.55  each source comes apart, top to bottom (the host draws its
///                 sprite below [crestLocal]);
///  * 0.25 – 2.10  its grains leave in turn and run along bowed, wandering
///                 ways, turning the colour of what they will become;
///  * 1.70 – 2.10  they settle into the new body's shape, and the host fades
///                 the new body in by [reveal] as the grains go out.
/// With no sources the grains pour in from [from] (the four arriving, an
/// element stepping out of what held it).
class RiteMorphFx {
  RiteMorphFx({
    this.sources = const [],
    required this.targets,
    this.from,
    this.flight = 1.1,
    this.bow = .3,
    this.spread = .45,
  });

  final List<(RiteBody, Offset)> sources;
  final List<(RiteBody, Offset)> targets;
  final Offset? from;
  final double flight, bow, spread;

  double t = 0;

  static const double crestDur = .55, leaveAt = .25, revealDur = .4;

  double get _arriveAt => leaveAt + spread + flight;
  double get duration => _arriveAt + revealDur + .05;
  bool get done => t >= duration;

  /// How much of each source is grains (top first).
  double get cut => _ease(t / crestDur);

  /// Where source [i]'s crest is, from its centre: its sprite is drawn below.
  double crestLocal(int i) {
    final (top, bottom) = sources[i].$1.span;
    return top + (bottom - top + 2) * cut;
  }

  /// How far the new bodies have come in (the host fades their sprites).
  double get reveal => _ease((t - _arriveAt + .1) / revealDur);

  void update(double dt) {
    t += dt;
    if (t > .3) {
      for (final (b, _) in sources) {
        b.force();
      }
      for (final (b, _) in targets) {
        b.force();
      }
    }
  }

  void paint(Canvas canvas, RiteGrainBatch batch, double time) {
    if (targets.isEmpty) return;
    var j = 0;
    void grain(
      Offset start,
      double leave,
      Color? c0,
      int k,
    ) {
      final ti = k % targets.length;
      final (tb, tAt) = targets[ti];
      final tg = tb.grains;
      Offset end;
      Color c1;
      if (tg == null || tg.length == 0) {
        end = tAt + Offset((_hash(k) - .5) * 30, (_hash(k + 5) - .5) * 30);
        c1 = tb.color;
      } else {
        final m = (k * 7919) % tg.length;
        end = tAt + Offset(tg.hx[m], tg.hy[m]);
        c1 = tg.tones[tg.tone[m]];
      }
      // Poured from a point (no body coming apart): already the colours of
      // what they will become.
      final from0 = c0 ?? c1;
      final h = _hash(k + 11);
      final u = (t - leave) / flight;
      Offset p, q;
      var a = 1.0;
      Color col;
      if (u <= 0) {
        final c = _curl(start.dx, start.dy, time, h * 6);
        p = start + Offset(c.dx * 2, c.dy * 2 - 3 * cut);
        q = p;
        col = from0;
      } else {
        final d = end - start;
        final len = math.max(1.0, d.distance);
        final n = Offset(-d.dy, d.dx) / len;
        final across = (h - .5) * 26;
        Offset at(double v) {
          final e = _ease(v);
          final base = Offset.lerp(start, end, e)!;
          final arc = n * (len * bow * math.sin(math.pi * e) + across * math.sin(math.pi * e));
          final w = _curl(base.dx, base.dy, time, h * 9) * (10 * math.sin(math.pi * e));
          return base + arc + w;
        }

        p = at(math.min(1.0, u));
        q = at(math.max(0.0, math.min(1.0, u) - .025));
        col = Color.lerp(from0, c1, _ease(u * 1.3))!;
        a = 1 - reveal;
      }
      if (a <= .02) return;
      batch.add(q.dx, q.dy, p.dx, p.dy, col, alpha: a, width: k % 3 == 0 ? 2.6 : 2.0);
    }

    if (sources.isEmpty) {
      final f = from ?? targets.first.$2;
      final n = targets.fold<int>(0, (s, x) => s + math.max(60, x.$1.length));
      for (var k = 0; k < n; k++) {
        final h = _hash(k + 3);
        // A soft round knot of them, never a square.
        final th = _hash(k) * math.pi * 2, rr = 15 * math.sqrt(_hash(k + 9));
        final start = f + Offset(math.cos(th) * rr, math.sin(th) * rr);
        grain(start, leaveAt * h + spread * _hash(k + 21), null, k);
      }
    } else {
      for (final (b, at) in sources) {
        final g = b.grains;
        if (g == null) continue;
        final (top, bottom) = b.span;
        final span = math.max(1.0, bottom - top);
        for (var i = 0; i < g.length; i++) {
          final hy = g.hy[i];
          final frac = (hy - top) / span;
          final cutAt = crestDur * frac;
          if (t < cutAt) {
            j++;
            continue; // still the sprite
          }
          final leave = leaveAt + spread * (frac * .6 + _hash(i + 31) * .4);
          grain(at + Offset(g.hx[i], hy), leave, g.tones[g.tone[i]], j);
          j++;
        }
      }
    }
    // Where the grains are thickest on the way, a little of their light.
    batch.paint(canvas);
  }
}

// ═══════════════════════════ EVERY ELEMENT, IN GRAINS ════════════════════

/// How fast each element pours up its column (world units a second).
const Map<String, double> kHeartManifestSpeed = {
  'Lightning': 1100,
  'Light': 900,
  'Air': 650,
  'Steam': 300,
  'Dust': 340,
  'Fire': 420,
  'Water': 380,
  'Spirit': 260,
  'Dark': 260,
  'Poison': 240,
  'Ice': 330,
  'Crystal': 260,
  'Lava': 200,
  'Mud': 180,
  'Earth': 300,
  'Plant': 220,
};

/// Seconds an element takes to pour [reach] world units up its column.
double heartManifestTravel(String el, double reach) =>
    math.max(.35, reach / (kHeartManifestSpeed[el] ?? 380));

double _sm(double e0, double e1, double x) => _ease((x - e0) / (e1 - e0));
double _fr(double x) => x - x.floorToDouble();
double _h2(int a, int k) => _hash(a * 31 + k * 977);

const List<Offset> _kUp = [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)];

/// A fused creature's element, poured up its altar's column in grains and
/// gathered back. The beats, in seconds from when it comes apart:
///  * 0 – [release]       the creature gives way to its grains, which heat
///                        into the element's shades (each by its own
///                        brightness) and leave it, crown first;
///  * to [hitAt]          they pour up the column in the element's own
///                        motion — flames lick, water spirals, clods heave,
///                        crystal stands in spires, bubbles lift and burst —
///                        the head reaching the first thing hanging there;
///  * to [returnAt]       they hold, and wash over what they reached;
///  * to [duration]       they come back down the column and gather into the
///                        creature, cooling to its own colours; the host
///                        fades its sprite back in by [spriteAlpha].
class HeartRiseFx {
  HeartRiseFx({
    required this.body,
    required this.el,
    required this.at,
    required this.reach,
    this.dir = 0,
    this.hits = false,
    this.into,
  }) : element = EssenceElement.of(el),
       ramp = essenceRamp(EssenceElement.of(el)),
       pool = essencePool(EssenceElement.of(el)),
       intoRamp = into == null ? null : essenceRamp(EssenceElement.of(into));

  final RiteBody body;
  final String el;
  final EssenceElement element;
  final List<Color> ramp;
  final Color pool;

  /// Where the creature stands (the altar's front stone), and how far up the
  /// column the element goes.
  final Offset at;
  final double reach;
  final int dir;

  /// Something hangs at the head: the grains there wash over it.
  final bool hits;

  /// What it makes with what hangs there, if anything. Then it does not come
  /// back: at the head its grains turn into that element's shades, and at
  /// [returnAt] they draw into the meeting and go, as what they made pours
  /// down from there (the host's morph).
  final String? into;
  final List<Color>? intoRamp;

  static const double release = .35, hold = .8, back = 1.15;

  /// The column is fuller than the creature is: each of its grains goes up
  /// as several, so there are at least this many.
  static const int minGrains = 2400;

  double get travel => heartManifestTravel(el, reach);
  double get hitAt => release + travel;
  double get returnAt => hitAt + hold;
  double get duration => into != null ? returnAt + .45 : returnAt + back + .1;

  /// The creature's sprite: gone while its grains are out, back as they land
  /// (never, when it fused up there).
  double spriteAlpha(double t) => into != null
      ? 1 - _sm(0, .1, t)
      : (1 - _sm(0, .1, t) + _sm(returnAt + back - .3, returnAt + back - .05, t)).clamp(0.0, 1.0);

  /// Up the column, as a unit offset.
  Offset get up => _up;

  Offset get _up => _kUp[dir & 3];
  Offset get _side => Offset(-_up.dy, _up.dx);

  // Per grain: its station up the column (0..1 of reach) and across it, its
  // element shade, when it leaves and when it starts home, and dice.
  SpecimenGrains? _g;
  late Float32List _f, _w, _rel, _ret, _dur, _d3, _d4, _hs, _hw;
  late Uint8List _shade;

  // Each column grain's creature grain, and its home (a little apart from
  // the others that share that grain).
  late Int32List _src;
  late Float32List _hx, _hy;
  int _n = 0;

  void _seed(SpecimenGrains g) {
    _g = g;
    final m = g.length;
    final n = _n = math.max(m, minGrains);
    _src = Int32List(n);
    _hx = Float32List(n);
    _hy = Float32List(n);
    _f = Float32List(n);
    _w = Float32List(n);
    _rel = Float32List(n);
    _ret = Float32List(n);
    _dur = Float32List(n);
    _d3 = Float32List(n);
    _d4 = Float32List(n);
    _hs = Float32List(n);
    _hw = Float32List(n);
    _shade = Uint8List(n);
    var top = double.infinity, bot = -double.infinity;
    for (var i = 0; i < m; i++) {
      top = math.min(top, g.hy[i]);
      bot = math.max(bot, g.hy[i]);
    }
    final span = math.max(1.0, bot - top);
    final last = math.max(1, g.tones.length - 1);
    final up = _up, side = _side;
    for (var i = 0; i < n; i++) {
      final src = _src[i] = i % m;
      final jit = i < m ? 0.0 : 1.2;
      _hx[i] = g.hx[src] + (_hash(i * 17 + 5) - .5) * 2 * jit;
      _hy[i] = g.hy[src] + (_hash(i * 19 + 6) - .5) * 2 * jit;
      final h1 = _hash(i * 3 + 1), h2 = _hash(i * 7 + 2);
      _d3[i] = _hash(i * 11 + 3);
      _d4[i] = _hash(i * 13 + 4);
      // Its home, in the column's own terms (s up it, w across).
      _hs[i] = _hx[i] * up.dx + _hy[i] * up.dy;
      _hw[i] = _hx[i] * side.dx + _hy[i] * side.dy;
      final b = g.tone[src] / last;
      _shade[i] = math.min(3, (b * 4).floor());
      _f[i] = math.pow(h1, .8).toDouble();
      _w[i] = (h2 - .5) * 2;
      final frac = (g.hy[src] - top) / span;
      _rel[i] = .18 * frac + .1 * _d3[i];
      _ret[i] = .3 * (1 - _f[i]) + .06 * h2;
      _dur[i] = .55 + .3 * _f[i];
    }
  }

  // The grain being worked out: its place in the column, shade and alpha.
  double _s = 0, _ww = 0, _a = 1;
  int _sh = 2;
  bool _big = false;

  /// Grain [i], [age] seconds after it reached its station, in the
  /// element's motion ([s] and [w] its station).
  void _local(int i, double s, double w, double age, double time) {
    final d3 = _d3[i], d4 = _d4[i], f = _f[i];
    final r = reach;
    _a = 1;
    _big = false;
    _sh = _shade[i];
    switch (element) {
      case EssenceElement.fire:
        // A pillar of flame: each grain licks up and goes, hottest low.
        final half = 16 * (1 - .55 * f) + 4;
        final ph = _fr(time * 1.4 + d4);
        _s = s + ph * 26;
        _ww = w * half * (1 - ph * .45) + math.sin(time * 7 + i) * 1.5;
        _sh = ph < .25 ? 3 : (ph < .5 ? 2 : (ph < .8 ? 1 : 0));
        _a = 1 - _sm(.7, 1, ph);
        if (d3 > .94) {
          _s = s + ph * 70;
          _ww += math.sin(time * 3 + i) * 6;
          _sh = 3;
          _big = true;
        }
      case EssenceElement.water:
        // A spout turning on itself, spray off its head.
        // Three streams twisting round each other.
        final th = math.pi * 2 * (i % 3) / 3 + (d4 - .5) * .7 + time * 3.2 + s * .06;
        _ww = 13 * (.6 + .4 * f) * math.sin(th) + w * 2;
        _s = s + math.sin(time * 2 + d4 * 6) * 2;
        final c = math.cos(th);
        _sh = c > .3 ? 3 : (c > -.3 ? 2 : 1);
        if (f > .9 && d3 > .5) {
          final ph = _fr(time * 1.1 + d4);
          _s += ph * 24 - ph * ph * 40;
          _ww += w * ph * 40;
          _sh = 3;
        }
      case EssenceElement.earth:
        // Clods heaving up, one above another.
        final c = i % 6;
        final sc = r * (c + .5) / 6;
        final th = d4 * math.pi * 2;
        // A rough clod: its edge in and out by sector.
        final rr = (9 + 5 * _hash(c * 7 + (th * 1.3).floor())) * math.sqrt(d3);
        _s = sc + math.sin(th) * rr * .85 + 5 * math.sin(time * 2.5 + c).abs();
        _ww = (_hash(c + 40) - .5) * 30 + math.cos(th) * rr * 1.15;
        _sh = math.sin(th) > .35 ? 3 : (math.sin(th) > -.3 ? 2 : 1);
      case EssenceElement.air:
        // A whirlwind, wider as it goes.
        // Four gusts spiralling up, wider as they go, the far side dimmer.
        final rr = 6 + 14 * f;
        final th = math.pi * 2 * (i % 4) / 4 + (d4 - .5) * .6 + time * 7 + s * .09;
        _ww = rr * math.cos(th);
        _s = s + math.sin(time * 3 + d4 * 5) * 3;
        final near = math.sin(th) > 0;
        _sh = near ? 3 : 1;
        _a = near ? 1 : .5;
      case EssenceElement.steam:
        // Billows, each loosening as it rises.
        final c = i % 8;
        final sc = r * (c + .5) / 8 + age * 14;
        final rr = (6 + 12 * math.min(1.0, age * .8)) * math.sqrt(_hash(i * 5 + 9));
        final th = d4 * math.pi * 2;
        _s = sc + rr * math.sin(th);
        _ww = (_hash(c + 50) - .5) * 18 + rr * math.cos(th) * 1.2;
        _a = 1 - .5 * _sm(0, 3, age);
        _sh = d3 > .6 ? 3 : 2;
      case EssenceElement.lava:
        // A column welling up, glowing through, its crust at the edges, and
        // drips running back down.
        final half = 14 + 2 * math.sin(time * 1.3 + s * .05);
        _ww = w * half;
        _s = s + _fr(time * .35 + d4) * 12;
        _sh = w.abs() < .4 ? (d3 > .5 ? 3 : 2) : (d3 > .85 ? 1 : 0);
        if (d3 > .92) {
          _s -= _fr(time * .8 + d4) * 50;
          _ww = (w < 0 ? -1 : 1) * half;
          _sh = 2;
        }
      case EssenceElement.lightning:
        // A bolt that jumps every 75 ms, with a branch.
        final k = (time / .075).floor();
        double jag(double at) {
          final u = (at / math.max(1.0, r)).clamp(0.0, 1.0) * 9;
          final j = u.floor();
          final a0 = j == 0 ? 0.0 : (_h2(j, k) - .5) * 26;
          final a1 = (_h2(j + 1, k) - .5) * 26;
          return a0 + (a1 - a0) * (u - j);
        }
        // A bright core of grains on the bolt, the rest crackling round it.
        final core = d3 < .4;
        final spread = core ? 1.2 : 2 + 9 * w.abs() * w.abs();
        _s = s;
        _ww = jag(s) + (w < 0 ? -1 : 1) * spread * (core ? w.abs() : 1);
        if (d3 > .86) {
          final sb = r * (.3 + .4 * _h2(7, k));
          final along = d4 * 26;
          _s = sb + along * .7;
          _ww = jag(sb) + (_h2(8, k) > .5 ? 1 : -1) * along + w * 2;
        }
        _sh = core ? 3 : 2;
        _a = (core ? 1 : .55) * (.6 + .4 * _h2(i % 5, k));
      case EssenceElement.mud:
        // A heavy column that slumps as it stands, and drips.
        _ww = w * 16 * (1 + .25 * _sm(0, 1.2, age));
        _s = s - 5 * _sm(0, 1.2, age) + math.sin(time * 1.5 + d4 * 6) * 1.5;
        // Lumps catching the light as it churns.
        final lump = _hash((s / 7).floor() * 13 + ((w + 1) * 2.5).floor() * 7);
        _sh = lump > .62 ? 2 : (d3 > .5 ? 1 : 0);
        if (d3 > .9) _s -= _fr(time * .5 + d4) * 40;
      case EssenceElement.ice:
        // Frost snapping to a lattice, needles standing up out of it.
        const sp = 6.0;
        final row = (s / sp).round();
        _s = row * sp;
        _ww = ((w * 12) / sp + (row.isOdd ? .5 : 0)).round() * sp - (row.isOdd ? sp / 2 : 0);
        _sh = 2;
        if (d3 > .55) {
          final nIdx = i % 12;
          final sb = r * (nIdx + .5) / 12;
          final ang = (nIdx.isEven ? 1 : -1) * (.5 + .5 * _hash(nIdx + 70));
          final len = 10 + 12 * _hash(nIdx + 80);
          _s = sb + d4 * len * math.cos(ang);
          _ww = (_hash(nIdx + 90) - .5) * 14 + d4 * len * math.sin(ang);
          _sh = 3;
        }
      case EssenceElement.dust:
        // Sand climbing in a loose cloud, blown downwind.
        _ww = w * (14 + 10 * f) + age * 18 + math.sin(time * 1.3 + d4 * 6) * 4 + math.sin(s * .045 + time * 1.5) * 8;
        _s = s + age * 8 + math.sin(time * 1.1 + d4 * 9) * 3;
        _a = 1 - .45 * _sm(0, 2.5, age);
      case EssenceElement.crystal:
        // Spires standing up the column, each grain on its facet: a lit
        // face, a shaded one, a glint at the tip.
        final c = i % 9;
        final sb = r * (c + .3) / 9 * .9;
        final wb = (c.isEven ? -1 : 1) * (3 + _hash(c + 20) * 8);
        final len = 30 + _hash(c + 30) * 26;
        final lean = (c.isEven ? -1 : 1) * (5 + _hash(c + 40) * 12);
        final grow = _sm(0, .35, age);
        final u = d4 * grow;
        final across = (1 - d4) * w * 6;
        _s = sb + len * u;
        _ww = wb + lean * u + across;
        _sh = d4 > .82 ? 3 : (w > 0 ? 2 : 1);
      case EssenceElement.plant:
        // Three stems climbing, curling, leafing.
        final c = i % 3;
        _ww = math.sin(s * .07 + c * 2.1 + time * .6) * 10 + (c - 1) * 5 + w * 1.2;
        _s = s;
        _sh = 1;
        if (d3 > .68) {
          final k = i % 7;
          final sk = r * (k + .6) / 7;
          final sideK = k.isEven ? 1.0 : -1.0;
          final cw = math.sin(sk * .07 + c * 2.1 + time * .6) * 10 + (c - 1) * 5;
          final th = d4 * math.pi * 2;
          final rr = math.sqrt(_hash(i * 3 + 7));
          final lx = math.cos(th) * 7 * rr, ly = math.sin(th) * 3 * rr;
          _s = sk + 4 + lx * .64 + ly * .77;
          _ww = cw + sideK * 9 + lx * .77 * sideK - ly * .64;
          _sh = d3 > .85 ? 3 : 2;
        }
      case EssenceElement.poison:
        // Bubbles lifting up the column, swelling, bursting.
        final c = i % 12;
        final ph = _fr(time * .45 + _hash(c + 60));
        final sc = r * math.min(1.0, _hash(c + 61) * .6 + ph * .45);
        final rr = (4 + 9 * ph) * math.sqrt(_hash(i * 23 + 8));
        final th = d4 * math.pi * 2;
        final burst = ph > .85 ? 1 + (ph - .85) * 8 : 1.0;
        _s = sc + math.sin(th) * rr * burst;
        _ww = (_hash(c + 62) - .5) * 16 + math.cos(th) * rr * burst;
        _a = ph > .85 ? 1 - (ph - .85) / .15 : 1;
        // Each blister lit on its upper side.
        _sh = math.sin(th) > .4 && rr > 3 ? 3 : (d3 > .6 ? 2 : 1);
        if (d3 < .25) {
          _s = s;
          _ww = w * 14;
          _sh = 1;
          _a = .6;
        }
      case EssenceElement.spirit:
        // A pale ribbon waving up, its tail behind.
        _ww = 10 * math.sin(s * .05 - time * 2.6) * (.6 + .4 * (1 - f)) + w * 6;
        _s = s + math.sin(time * 1.4 + d4 * 6) * 3;
        _sh = d3 > .5 ? 3 : 2;
        _a = .85;
      case EssenceElement.dark:
        // Two arms twisting up the column round a dark core, drawing in.
        final arm = i.isEven ? 0.0 : math.pi;
        final th = arm + s * .07 - time * 2.4 + (d4 - .5) * .5;
        final rr = (15 - 6 * _sm(0, 1.4, age)) * (.75 + .25 * d3);
        _ww = rr * math.cos(th);
        _s = s + rr * math.sin(th) * .25;
        _sh = math.sin(th) > .2 ? 2 : 1;
        if (d3 > .8) {
          _ww = w * 3;
          _sh = 0;
        }
      case EssenceElement.light:
        // Rays, uneven, streaming up.
        final c = i % 6;
        final ang = (c / 5 - .5) * .5 + (_hash(c + 100) - .5) * .12;
        final sl = s * (.55 + .45 * _hash(c + 109));
        _s = sl + _fr(time * 2.2 + d4) * 10;
        _ww = sl * math.tan(ang) * .5 + w;
        _sh = d3 > .3 ? 3 : 2;
      case EssenceElement.blood:
        _ww = w * 10;
        _s = s;
    }
    // At the head, against what hangs there: the grains billow round it,
    // a churning cloud of the element over its lower half (never a ring).
    if (hits && f > .88) {
      final k = _sm(0, .5, age);
      final rr = 36 * math.sqrt(d3) * (.85 + .3 * _hash(i * 29 + 3));
      final reachAround = math.pi * (.7 + .3 * d4);
      final phi = _w[i] * reachAround * k + math.sin(time * 2 + d4 * 6) * .18;
      final es = r + 20 - rr * math.cos(phi), ew = rr * math.sin(phi) * 1.1;
      _s += (es - _s) * k;
      _ww += (ew - _ww) * k;
      _a *= 1 - .55 * k * d3 * d3;
    }
  }

  /// Where grain [i] is at [t], into [_pt]; false when it is not drawn.
  bool _place(int i, double t, double time, SpecimenGrains g) {
    final s0 = _hs[i], w0 = _hw[i];
    final rel = _rel[i];
    final f = _f[i];
    final station = reach * f;
    // When it gets to its station: the higher, the later (the head reaches
    // the top at [hitAt]).
    final arrive = release + travel * f;
    final ret0 = into != null ? double.infinity : returnAt + _ret[i];
    final ret1 = ret0 + _dur[i];
    if (t < rel || t >= ret1) {
      // Still the creature, or home again: waiting for the sprite.
      _s = s0;
      _ww = w0;
      _a = 1;
      _sh = _shade[i];
      return true;
    }
    // Its place at its station (in motion), as of [tt].
    void atStation(double tt) => _local(i, station, _w[i], math.max(0, tt - arrive), time);
    if (t < arrive) {
      final u = ((t - rel) / math.max(.05, arrive - rel)).clamp(0.0, 1.0);
      final e = 1 - (1 - u) * (1 - u);
      atStation(arrive);
      final ts = _s, tw = _ww;
      _s = s0 + (ts - s0) * e;
      _ww = w0 + (tw - w0) * _sm(0, .6, u);
    } else {
      atStation(t);
    }
    if (t > ret0) {
      // Home: down the column and in along a swirl.
      final v = ((t - ret0) / _dur[i]).clamp(0.0, 1.0);
      final e = _ease(v);
      final fs = _s, fw = _ww;
      _s = fs + (s0 - fs) * e;
      _ww = fw + (w0 - fw) * e + math.sin(math.pi * e) * (_d3[i] - .5) * 24;
      _a = _a + (1 - _a) * e;
    }
    return true;
  }

  void paint(Canvas canvas, RiteGrainBatch batch, double t, double time) {
    if (t < 0 || t >= duration) return;
    var g = body.grains;
    if (g == null) {
      body.force();
      g = body.grains;
      if (g == null) return;
    }
    if (!identical(g, _g)) _seed(g);
    final up = _up, side = _side;
    // The light the element gives off: at the creature as it lets go, at
    // the head while it is up.
    final headK = ((t - release) / travel).clamp(0.0, 1.0);
    final head = at + up * (reach * (1 - (1 - headK) * (1 - headK)));
    final out = _sm(0, release, t) * (1 - _sm(returnAt, returnAt + back, t));
    vfxSpill(canvas, head, 44 + 10 * math.sin(time * 2), pool, .2 * out);
    vfxSpill(canvas, at, 40, pool, .14 * out);
    // A short streak behind each moving grain (none for Lightning, whose
    // grains jump), so they read as grains.
    final dt = element == EssenceElement.lightning ? 0.0 : .012;
    for (var i = 0; i < _n; i++) {
      if (!_place(i, t, time, g)) continue;
      final s = _s, w = _ww, a = _a, sh = _sh, big = _big;
      if (a <= .03) continue;
      final pull = into == null ? 0.0 : _sm(returnAt - .15, returnAt + .35, t);
      final ms = reach + 20.0;
      final s1 = s + (ms - s) * pull, w1 = w * (1 - pull);
      final px = at.dx + up.dx * s1 + side.dx * w1, py = at.dy + up.dy * s1 + side.dy * w1;
      _place(i, math.max(0, t - dt), time - dt, g);
      final s2 = _s + (ms - _s) * pull, w2 = _ww * (1 - pull);
      final qx = at.dx + up.dx * s2 + side.dx * w2, qy = at.dy + up.dy * s2 + side.dy * w2;
      // Heated into the element as it leaves, cooled to its own as it lands.
      final own = g.tones[g.tone[_src[i]]];
      final heat = _sm(_rel[i], _rel[i] + .25, t) * (1 - _sm(returnAt + _ret[i] + _dur[i] * .55, returnAt + _ret[i] + _dur[i], t));
      final q = (heat * 3).round() / 3;
      var col = q >= 1 ? ramp[sh] : (q <= 0 ? own : Color.lerp(own, ramp[sh], q)!);
      // The last of them go out as the sprite comes back.
      var fade = 1 - _sm(returnAt + back - .3, returnAt + back - .05, t);
      final ir = intoRamp;
      if (ir != null) {
        // Fused up there: they turn into what they made, draw into the
        // meeting, and go as it pours down.
        final k = ((_sm(hitAt + .15, hitAt + .65, t)) * 3).round() / 3;
        if (k > 0) col = k >= 1 ? ir[sh] : Color.lerp(col, ir[sh], k)!;
        fade = 1 - _sm(returnAt, returnAt + .4, t);
      }
      final d = (px - qx).abs() + (py - qy).abs();
      if (d > 7) {
        batch.add(px, py, px, py, col, alpha: a * fade, width: big ? 2.6 : 2);
      } else {
        batch.add(qx, qy, px, py, col, alpha: a * fade, width: big || i % 7 == 0 ? 2.6 : 2);
      }
    }
    batch.paint(canvas);
  }
}

// ═══════════════════════════ WHAT HANGS THERE ══════════════════════════════

/// The radius of an element's orb hanging in the Heart (world units).
const double kHeartOrbRadius = 22;

/// An element hanging in the Heart is its Codex orb (ElementOrb: a ball of
/// its grains in dark glass — the author, 2026-10-06: the loose grains
/// "look too particly"; the orb is how the player knows each element from
/// the Fusion Codex). Reached by what rises and fused with it, the orb comes
/// apart: its glass goes, and its grains, as they stood ([g], from
/// `ElementOrb.grainsAt`), swirl in to the meeting just below it and go.
void paintHeartMeet(RiteGrainBatch batch, SpecimenGrains g, Offset c, double since) {
  final k = _sm(0, .7, since);
  if (k >= 1) return;
  for (var i = 0; i < g.length; i++) {
    final x0 = g.hx[i], y0 = g.hy[i];
    final d = math.max(1.0, math.sqrt(x0 * x0 + y0 * y0));
    final ang = math.atan2(y0, x0) + k * 2.2 * (_hash(i * 7 + 1) > .5 ? 1 : -1);
    final rr = d * (1 - k);
    final x = c.dx + math.cos(ang) * rr, y = c.dy + math.sin(ang) * rr + 14 * k;
    batch.add(x, y, x, y, g.tones[g.tone[i]], alpha: 1 - k * k, width: 2);
  }
}

// ═══════════════════════════ BLOOD'S BANDS ═════════════════════════════════

/// The bands that hold Blood at the top of the Heart, in grains of blood
/// running round them: [grow] as they close on it (0..1), [letGo] as they
/// open and fall away (0..1), [alpha] for the empty binding's ghost, [beat]
/// the planet's heartbeat (they swell with it).
void paintHeartBands(
  RiteGrainBatch batch,
  Offset at,
  double grow,
  double letGo,
  double time, {
  double alpha = 1,
  double beat = 0,
}) {
  const ramp = [Color(0xFF2A060C), Color(0xFF6A0E20), Color(0xFFC8283C), Color(0xFFFF8A94)];
  final a0 = alpha * grow * (1 - _sm(.3, 1, letGo));
  if (a0 <= .02) return;
  for (final k in const [-1.0, 1.0]) {
    final cx = at.dx + k * (9 + letGo * 16);
    final sw = .8 + .2 * grow + .07 * beat;
    for (var i = 0; i < 90; i++) {
      final th = math.pi * 2 * i / 90 + time * 1.3 * k;
      final rr = 1 + (_hash(i * 7 + (k > 0 ? 3 : 0)) - .5) * .35;
      final x = cx + math.cos(th) * 6 * sw * rr;
      final y = at.dy + 2 + math.sin(th) * 24 * sw * rr + letGo * letGo * 60;
      final front = math.cos(th) * k < 0;
      final sh = front ? (_hash(i) > .7 ? 3 : 2) : 1;
      batch.add(x, y, x, y, ramp[sh], alpha: a0, width: sh == 3 ? 2.4 : 2);
    }
  }
  // Drops of it, falling from the binding into the dark.
  for (var i = 0; i < 9; i++) {
    final ph = _fr(time * .45 + i / 9);
    final x = at.dx + (_hash(i + 40) - .5) * 22;
    final y = at.dy + 30 + ph * ph * 80;
    batch.add(x, y - 3, x, y, ramp[2], alpha: a0 * (1 - ph), width: 2);
  }
}

/// A pair that would not fuse: a breath of both their colours, and nothing.
void paintHeartFizzle(RiteGrainBatch batch, Offset at, double since, Color a, Color b) {
  if (since >= .9) return;
  for (var i = 0; i < 46; i++) {
    final th = _hash(i * 3) * math.pi * 2;
    final v = 10 + 18 * _hash(i * 5 + 1);
    final x = at.dx + math.cos(th) * v * since;
    final y = at.dy + math.sin(th) * v * since * .6 - 22 * since;
    batch.add(x, y, x, y, i.isEven ? a : b, alpha: .8 * (1 - _sm(.3, .9, since)), width: 2);
  }
}

// ═══════════════════════════ AN ELEMENT'S NAME ═════════════════════════════

/// An element's name laid out as grains (sampled from the text), centred on
/// the origin, with which letter each grain belongs to.
class HeartWord {
  HeartWord(this.text, this.x, this.y, this.letter, this.letters, this.width);
  final String text;
  final Float32List x, y;
  final Uint8List letter;
  final int letters;
  final double width;
  int get length => x.length;
}

/// Sample [text] (upper case, heavy, spaced) into grains [size] world units
/// tall: drawn at [scale]× and read every [step] pixels.
Future<HeartWord> heartWordOf(String text, {double size = 24, double scale = 3, double step = 4}) async {
  final word = text.toUpperCase();
  final tp = TextPainter(
    text: TextSpan(
      text: word,
      style: TextStyle(
        // The device's own bold sans (Roboto on Android): read as grains,
        // a clean heavy face is what stays legible.
        fontFamily: 'Roboto',
        fontSize: size * scale,
        fontWeight: FontWeight.w800,
        letterSpacing: size * .2 * scale,
        color: const Color(0xFFFFFFFF),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final pad = 4 * scale;
  final w = (tp.width + pad * 2).ceil(), h = (tp.height + pad * 2).ceil();
  final rec = ui.PictureRecorder();
  tp.paint(Canvas(rec), Offset(pad, pad));
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  // Where each letter starts, so grains know their letter.
  final edges = <double>[];
  for (var i = 0; i < word.length; i++) {
    edges.add(pad + tp.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dx);
  }
  final xs = <double>[], ys = <double>[], ls = <int>[];
  if (data != null) {
    for (var py = 0; py < h; py += step.round()) {
      for (var px = 0; px < w; px += step.round()) {
        final a = data.getUint8((py * w + px) * 4 + 3);
        if (a < 128) continue;
        var l = 0;
        while (l < edges.length - 1 && px >= edges[l + 1]) {
          l++;
        }
        xs.add((px - w / 2) / scale);
        ys.add((py - h / 2) / scale);
        ls.add(l);
      }
    }
  }
  return HeartWord(
    word,
    Float32List.fromList(xs),
    Float32List.fromList(ys),
    Uint8List.fromList(ls),
    math.max(1, word.length),
    tp.width / scale,
  );
}

/// An element's name shown where it hangs, in grains: they stream out of
/// [from] into the letters (left to right), shimmer a moment, then come
/// loose letter by letter and drift up and away as they fade (the author,
/// 2026-10-06: "tapping the orb should show the element in a cool particle
/// fade away"). Plain Dart, scrubbed by [t].
class HeartWordFx {
  HeartWordFx(this.word, this.from, this.at, this.ramp);
  final HeartWord word;
  final Offset from, at;
  final List<Color> ramp;
  double t = 0;

  static const double gather = .7, hold = 1.3, dissolve = 1.1;
  static const double duration = gather + .35 + hold + dissolve + .3;
  bool get done => t >= duration;

  Offset _pos(int i, double t, double time) {
    final n = word.letters;
    final l = word.letter[i];
    final h = _hash(i * 7 + 3);
    final home = at + Offset(word.x[i], word.y[i]);
    // In: out of the orb, along a slight bow, letter by letter.
    final leave = .35 * l / n + .12 * h;
    final u = ((t - leave) / gather).clamp(0.0, 1.0);
    if (u < 1) {
      final e = 1 - (1 - u) * (1 - u) * (1 - u);
      final start = from + Offset((_hash(i) - .5) * 18, (_hash(i + 5) - .5) * 18);
      final base = Offset.lerp(start, home, e)!;
      final bow = Offset(0, -18 * math.sin(math.pi * e)) + _curl(base.dx, base.dy, time, h * 6) * (5 * math.sin(math.pi * e));
      return base + bow;
    }
    // Out: loose, letter by letter, drifting up and away.
    final go = gather + .35 + hold + .4 * l / n + .15 * h;
    final tau = t - go;
    if (tau <= 0) {
      return home + Offset(0, math.sin(time * 2 + i * .7) * .6);
    }
    final c = _curl(home.dx, home.dy, time, h * 9);
    return home + Offset(c.dx * 16 * tau, -26 * tau - 10 * tau * tau + c.dy * 8 * tau);
  }

  double _alpha(int i) {
    final n = word.letters;
    final l = word.letter[i];
    final h = _hash(i * 7 + 3);
    final leave = .35 * l / n + .12 * h;
    final inK = _sm(leave, leave + .2, t);
    final go = gather + .35 + hold + .4 * l / n + .15 * h;
    return inK * (1 - _sm(go, go + dissolve * .8, t));
  }

  void paint(Canvas canvas, RiteGrainBatch batch, double time) {
    if (done) return;
    final glow = _sm(0, .5, t) * (1 - _sm(gather + .35 + hold, duration - .3, t));
    vfxSpill(canvas, at, word.width * .7 + 20, ramp[2], .16 * glow);
    final k = (time * 4).floor();
    for (var i = 0; i < word.length; i++) {
      final a = _alpha(i);
      if (a <= .03) continue;
      final p = _pos(i, t, time);
      final q = _pos(i, math.max(0, t - .02), time - .02);
      // Lit grains, the odd one catching the light.
      final sh = _hash(i * 13 + k) > .96 ? 3 : (i % 3 == 0 ? 3 : 2);
      batch.add(q.dx, q.dy, p.dx, p.dy, ramp[sh], alpha: a, width: sh == 3 ? 2.4 : 2);
    }
    batch.paint(canvas);
  }
}
