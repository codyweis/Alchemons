// lib/games/planet_dungeon/blood_rite_fx.dart
//
// The Blood Rites' moments, in grains — the release of a captive and the
// sacrifice of an ally — plus a small field of loose grains the rooms use for
// steam, dust, drips and wakes.
//
// The house rules for a reveal (the author): eased, trailed grains that drift
// and dissolve; no snaps, bursts, flashes, confetti or shock rings; nothing
// left on screen at the end. And the body is the creature's OWN matter: its
// sprite, read into grains the way a guardian's death is (SpecimenGrains).
//
// Plain Dart, driven by time alone: the dungeon ticks it and paints it, and a
// test can scrub it. Drawn as batched points (no blur, no per-grain paint).

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/painting.dart';

const Color kRiteFxBlood = Color(0xFFC8283C);
const Color kRiteFxBloodHot = Color(0xFFFF8A94);

double _ease(double t) {
  final c = t.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}

double _hash(int n) {
  final s = math.sin(n * 127.1 + 311.7) * 43758.5453;
  return s - s.floorToDouble();
}

/// A smooth, cheap curl: two sines crossed, enough to make a grain wander.
Offset _curl(double x, double y, double t, double seed) => Offset(
  math.sin(y * 0.031 + t * 1.3 + seed) + 0.5 * math.sin(x * 0.017 - t * 0.7),
  math.cos(x * 0.029 - t * 1.1 + seed) + 0.5 * math.cos(y * 0.021 + t * 0.9),
);

// ═══════════════════════════ DRAWING GRAINS ════════════════════════════════

/// Collects grains by colour and width, then draws each group in one call:
/// a trail (the segment from where it was) for moving grains, a point for
/// still ones.
class RiteGrainBatch {
  final Map<int, List<double>> _lines = {};
  final Map<int, List<double>> _points = {};

  static int _key(Color c, double alpha, double width) {
    final a = (alpha.clamp(0.0, 1.0) * 7).round();
    final w = width < 2.4 ? 0 : 1;
    final col = c.toARGB32() & 0x00FFFFFF;
    return (col << 4) | (a << 1) | w;
  }

  void add(
    double px,
    double py,
    double x,
    double y,
    Color c, {
    double alpha = 1,
    double width = 2,
  }) {
    if (alpha <= 0.02) return;
    final k = _key(c, alpha, width);
    if ((x - px).abs() + (y - py).abs() < 0.6) {
      (_points[k] ??= []).addAll([x, y]);
    } else {
      (_lines[k] ??= []).addAll([px, py, x, y]);
    }
  }

  void paint(Canvas canvas) {
    void draw(Map<int, List<double>> m, ui.PointMode mode) {
      for (final e in m.entries) {
        final k = e.key;
        final col = Color(0xFF000000 | (k >> 4));
        final a = ((k >> 1) & 7) / 7;
        final w = (k & 1) == 1 ? 3.0 : 2.0;
        canvas.drawRawPoints(
          mode,
          Float32List.fromList(e.value),
          Paint()
            ..strokeWidth = w
            ..strokeCap = StrokeCap.round
            ..color = col.withValues(alpha: a),
        );
      }
    }

    draw(_lines, ui.PointMode.lines);
    draw(_points, ui.PointMode.points);
    _lines.clear();
    _points.clear();
  }
}

// ═══════════════════════════ LOOSE GRAINS ══════════════════════════════════

class RiteGrain {
  RiteGrain({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    required this.life,
    required this.color,
    this.width = 2,
    this.drag = 1.6,
    this.lift = 0,
    this.wander = 10,
    this.to,
    this.pull = 0,
    this.seed = 0,
  }) : px = x,
       py = y;

  double x, y, px, py, vx, vy;
  double age = 0;
  final double life;
  final Color color;
  final double width;

  /// How fast velocity eases away (per second).
  final double drag;

  /// Upward drift (world units / s²); negative falls.
  final double lift;

  /// How hard the curl pushes it about.
  final double wander;

  /// A place it is drawn towards, and how hard.
  final Offset? to;
  final double pull;
  final double seed;

  bool get dead => age >= life;

  /// Fades in quickly and out slowly: it never pops.
  double get alpha {
    final t = age / life;
    return math.min(1.0, t * 6) * (1 - _ease((t - 0.45) / 0.55));
  }
}

/// Loose grains: steam off a drowned brazier, dust off a turning plate,
/// drips, a drift's wake, vapour into a bell.
class RiteGrainField {
  final List<RiteGrain> grains = [];

  /// Never more than this many at once (this is drawn in the game loop).
  static const int cap = 900;

  void add(RiteGrain g) {
    if (grains.length >= cap) grains.removeAt(0);
    grains.add(g);
  }

  void update(double dt, double time) {
    for (final g in grains) {
      g.px = g.x;
      g.py = g.y;
      g.age += dt;
      final c = _curl(g.x, g.y, time, g.seed);
      g.vx += c.dx * g.wander * dt;
      g.vy += (c.dy * g.wander - g.lift) * dt;
      if (g.to != null) {
        g.vx += (g.to!.dx - g.x) * g.pull * dt;
        g.vy += (g.to!.dy - g.y) * g.pull * dt;
      }
      final k = math.exp(-g.drag * dt);
      g.vx *= k;
      g.vy *= k;
      g.x += g.vx * dt;
      g.y += g.vy * dt;
    }
    grains.removeWhere((g) => g.dead);
  }

  void paint(Canvas canvas, RiteGrainBatch batch) {
    for (final g in grains) {
      batch.add(g.px, g.py, g.x, g.y, g.color, alpha: g.alpha, width: g.width);
    }
    batch.paint(canvas);
  }

  void clear() => grains.clear();
}

// ═══════════════════════════ A BODY, READ ══════════════════════════════════

/// A creature as it stood, read into grains of itself. Until the read lands
/// the host draws the sprite; a body that cannot be read is a disc of its
/// colour.
class RiteBody {
  RiteBody(this.color);

  final Color color;
  SpecimenGrains? grains;
  bool _reading = false;

  /// [image] is the creature, [box] world units square at [ratio] px each.
  Future<void> read(ui.Image image, double ratio) async {
    _reading = true;
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return;
      final rgba = data.buffer.asUint8List();
      final w = image.width, h = image.height;
      SpecimenGrains g;
      try {
        g = await Isolate.run(
          () => SpecimenGrains.fromRgba(
            rgba,
            w,
            h,
            pixelRatio: ratio,
            maxGrains: 1400,
          ),
        );
      } catch (_) {
        g = SpecimenGrains.fromRgba(rgba, w, h, pixelRatio: ratio, maxGrains: 1400);
      }
      if (g.length >= 40) grains ??= g;
    } catch (_) {
      // the disc, below
    } finally {
      _reading = false;
      image.dispose();
    }
  }

  /// Make sure there is something to animate (called once the moment needs
  /// grains and the read has not landed).
  void ensure({double radius = 16}) {
    if (grains != null || _reading) return;
    grains = SpecimenGrains.disc(color, radius: radius);
  }

  /// Give up waiting on a slow read.
  void force({double radius = 16}) {
    grains ??= SpecimenGrains.disc(color, radius: radius);
  }

  int get length => grains?.length ?? 0;

  double? _top, _bottom;

  /// The body's top and bottom, in world units from its centre.
  (double, double) get span {
    final g = grains;
    if (g == null) return (-22, 22);
    if (_top == null) {
      var t = double.infinity, b = -double.infinity;
      for (var i = 0; i < g.length; i++) {
        t = math.min(t, g.hy[i]);
        b = math.max(b, g.hy[i]);
      }
      _top = t;
      _bottom = b;
    }
    return (_top!, _bottom!);
  }
}

// ═══════════════════════════ THE RELEASE ═══════════════════════════════════

/// A captive freed. The beats, in seconds:
///  * 0.00 – 1.40  THE INGREDIENTS. The room's two ingredients run in grains
///                 along their ways to the captive, trailed, and sink into it.
///  * 0.90 – 2.10  THE BANDS loosen: the blood that held it swells, thins and
///                 lets go.
///  * 1.40 – 2.40  THE BODY comes apart, top to bottom, into grains of itself
///                 that lift and loosen, warming to blood as they go.
///  * 2.30 – 4.80  HOME. The grains gather into a ribbon of blood that runs
///                 out of the room by its door, towards the Circle, and thins
///                 to nothing on the way.
class RiteReleaseFx {
  RiteReleaseFx({
    required this.at,
    required this.exit,
    required this.sources,
    required this.body,
  });

  /// Where the captive lies, and the door its blood leaves by.
  final Offset at, exit;

  /// The ingredients: each a path (ending at the captive) and its colour.
  final List<(List<Offset>, Color)> sources;

  final RiteBody body;

  double t = 0;

  static const double ingredientsEnd = 1.4;
  static const double bandsAt = 0.9, bandsDur = 1.2;
  static const double crestAt = 1.4, crestDur = 0.9;
  static const double homeAt = 2.3, homeSpread = 1.5, flight = 1.6;
  static const double duration = homeAt + homeSpread + flight + 0.1;

  bool get done => t >= duration;

  /// How loose the bands are (0 holding, 1 gone).
  double get bandsK => _ease((t - bandsAt) / bandsDur);

  /// How far down the body the crest has run (0 none of it, 1 all of it):
  /// the host draws the sprite only below it.
  double get cut => _ease((t - crestAt) / crestDur);

  /// The sprite is drawn whole until the crest starts.
  bool get spriteWhole => t < crestAt;

  /// Where the crest is, in world units from the body's centre: the sprite
  /// is drawn below it, the grains are above it.
  double get crestLocal {
    final (top, bottom) = body.span;
    return top + (bottom - top + 2) * cut;
  }

  void update(double dt) {
    t += dt;
    if (t > crestAt + 0.4) body.force();
  }

  void paint(Canvas canvas, RiteGrainBatch batch, double time) {
    _glow.clear();
    _paintIngredients(batch);
    _paintBody(batch, time);
    // A soft body of blood under the ribbon, so it reads as matter and not
    // as threads: a few faint pools of light where the grains are thickest.
    for (final g in _glow) {
      canvas.drawCircle(
        g,
        20,
        Paint()
          ..shader = ui.Gradient.radial(g, 20, [
            kRiteFxBlood.withValues(alpha: .22),
            kRiteFxBlood.withValues(alpha: 0),
          ]),
      );
    }
    batch.paint(canvas);
  }

  final List<Offset> _glow = [];

  void _paintIngredients(RiteGrainBatch batch) {
    if (t > ingredientsEnd + 0.4) return;
    for (var s = 0; s < sources.length; s++) {
      final (path, col) = sources[s];
      if (path.length < 2) continue;
      // Cumulative lengths, so grains travel at an even pace.
      final lens = <double>[0];
      for (var i = 1; i < path.length; i++) {
        lens.add(lens.last + (path[i] - path[i - 1]).distance);
      }
      final total = math.max(1.0, lens.last);
      Offset along(double f) {
        final d = f.clamp(0.0, 1.0) * total;
        var i = 1;
        while (i < lens.length - 1 && lens[i] < d) {
          i++;
        }
        final k = (d - lens[i - 1]) / math.max(1e-6, lens[i] - lens[i - 1]);
        return Offset.lerp(path[i - 1], path[i], k)!;
      }

      const n = 110;
      for (var i = 0; i < n; i++) {
        final born = (i / n) * 0.85;
        final life = 0.8;
        final u = (t - born) / life;
        if (u <= 0 || u >= 1) continue;
        final e = _ease(u);
        final p = along(e);
        final q = along(math.max(0, e - 0.02));
        final j = (_hash(i * 31 + s * 7) - 0.5) * 16 * math.sin(math.pi * u);
        final n2 = (p - q).distance < 0.01
            ? Offset.zero
            : Offset(-(p - q).dy, (p - q).dx) / (p - q).distance;
        final a = math.sin(math.pi * u);
        batch.add(
          q.dx + n2.dx * j,
          q.dy + n2.dy * j,
          p.dx + n2.dx * j,
          p.dy + n2.dy * j,
          // Lighter than the way it runs along, so it reads on it.
          Color.lerp(col, const Color(0xFFFFFFFF), 0.45)!,
          alpha: a,
          width: i % 3 == 0 ? 3.0 : 2.2,
        );
      }
    }
  }

  void _paintBody(RiteGrainBatch batch, double time) {
    final g = body.grains;
    if (g == null || t < crestAt) return;
    final (top, bottom) = body.span;
    final crestY = crestLocal;
    final home = exit - at;
    for (var i = 0; i < g.length; i++) {
      final hx = g.hx[i], hy = g.hy[i];
      if (hy > crestY) continue; // still the sprite
      final h = _hash(i);
      // When this grain was cut loose.
      final cutAt = crestAt + crestDur * ((hy - top) / math.max(1, bottom - top));
      final loose = t - cutAt;
      final tone = g.tones[g.tone[i]];
      // Warming to blood after it is loose.
      final warm = _ease(loose / 1.0);
      final col = Color.lerp(tone, i % 5 == 0 ? kRiteFxBloodHot : kRiteFxBlood, warm)!;
      // Loose: lift and wander a little.
      final c = _curl(hx * 3, hy * 3, time, h * 6);
      final drift = Offset(c.dx * 3 * warm, c.dy * 3 * warm - 6 * warm);
      var p = at + Offset(hx, hy) + drift;
      var q = p;
      var a = 1.0;
      // Home: each grain in its turn joins the ribbon to the door.
      final leave = homeAt + homeSpread * ((hy - top) / math.max(1, bottom - top) * 0.6 + h * 0.4);
      final f = (t - leave) / flight;
      if (f > 0) {
        final e = _ease(f);
        // A ribbon, not a line: every grain has its own place across the
        // stream, the stream bows out to one side as it goes, and each
        // grain wanders a little off its line in the middle of the run.
        final len = math.max(1.0, home.distance);
        final n = Offset(-home.dy, home.dx) / len;
        final across = (h - 0.5) * 34 + (_hash(i + 3) - 0.5) * 10;
        final bow = len * 0.32;
        final start = p;
        Offset path(double u) {
          final base = Offset.lerp(start, exit, u)!;
          final arc = n * (bow * math.sin(math.pi * u));
          final w = _curl(base.dx, base.dy, time, h * 9) * (12 * math.sin(math.pi * u));
          return base + arc + n * (across * math.sin(math.pi * math.min(1.0, u * 1.4))) + w;
        }

        q = path(math.max(0, e - 0.014));
        p = path(e);
        a = 1 - _ease((f - 0.6) / 0.4);
        if (i % 40 == 0 && a > .3) _glow.add(p);
      }
      if (a <= 0.02) continue;
      batch.add(q.dx, q.dy, p.dx, p.dy, col, alpha: a, width: i % 3 == 0 ? 2.6 : 2.0);
    }
  }
}

// ═══════════════════════════ THE SACRIFICE ═════════════════════════════════

/// An ally gives itself to Sanguorath's shell. The beats, in seconds:
///  * 0.00 – 0.50  It stands; blood rises round it.
///  * 0.30 – 1.10  It comes apart, feet first, into grains of itself.
///  * 0.70 – 2.80  The grains are drawn round the shell in a tightening
///                 spiral, warming to blood, and are taken into it.
///  * 2.20 – 3.40  The shell sheds: its element thins and lets go.
class RiteSacrificeFx {
  RiteSacrificeFx({required this.from, required this.body, required this.allyColor});

  final Offset from;
  final RiteBody body;
  final Color allyColor;

  /// Where the shell is now (Sanguorath moves).
  Offset target = Offset.zero;

  double t = 0;

  static const double crestAt = 0.3, crestDur = 0.8;
  static const double spiralAt = 0.7, spiralSpread = 0.8, spiralDur = 2.0;
  static const double shedAt = 2.6, shedDur = 1.3;
  static const double duration = shedAt + shedDur;

  bool get done => t >= duration;

  /// How much of the body (from the feet) is grains.
  double get cut => _ease((t - crestAt) / crestDur);

  /// How far the shell has shed (0 whole, 1 gone).
  double get shedK => _ease((t - shedAt) / shedDur);

  /// Where the crest is (feet first), from the body's centre: the sprite is
  /// drawn above it, the grains are below it.
  double get crestLocal {
    final (top, bottom) = body.span;
    return bottom - (bottom - top + 2) * cut;
  }

  /// How much of the body the shell has taken in (it warms to blood).
  double get takenK => _ease((t - spiralAt - spiralDur * .5) / (spiralDur * .8));

  /// The blood rising round the ally before it goes.
  double get riseK => _ease(t / 0.5) * (1 - _ease((t - 1.0) / 0.6));

  void update(double dt) {
    t += dt;
    if (t > crestAt + 0.3) body.force();
  }

  void paint(Canvas canvas, RiteGrainBatch batch, double time) {
    final g = body.grains;
    if (g != null && t >= crestAt) {
      final (top, bottom) = body.span;
      final span = math.max(1.0, bottom - top);
      // Feet first: the crest climbs.
      final crestY = crestLocal;
      final start = from - target;
      final r0 = start.distance;
      final a0 = math.atan2(start.dy, start.dx);
      for (var i = 0; i < g.length; i++) {
        final hx = g.hx[i], hy = g.hy[i];
        if (hy < crestY) continue; // still the sprite
        final h = _hash(i + 7);
        final tone = g.tones[g.tone[i]];
        final leave = spiralAt + spiralSpread * ((bottom - hy) / span * 0.7 + h * 0.3);
        final f = (t - leave) / spiralDur;
        Offset at(double u) {
          final e = _ease(u);
          // Out into a wide orbit first, then drawn in, round and round.
          final wide = math.max(r0, 70.0) + 70 * math.sin(math.pi * math.min(1.0, e * 1.6)) + 30 * h;
          final r = wide * (1 - e) + 26 * (1 - e) * h;
          final ang = a0 + (hy * 0.004) + e * (9.5 + h * 2.0);
          return target + Offset(math.cos(ang), math.sin(ang)) * r +
              Offset(hx, hy) * math.max(0.0, 1 - e * 3) * 0.9;
        }

        Offset p, q;
        double a = 1;
        Color col;
        if (f <= 0) {
          // Loose, waiting: a little lift.
          final c = _curl(hx * 3, hy * 3, time, h * 5);
          p = from + Offset(hx, hy) + Offset(c.dx * 2, c.dy * 2 - 4);
          q = p;
          col = tone;
        } else {
          p = at(f);
          q = at(math.max(0, f - 0.006));
          col = Color.lerp(tone, i % 4 == 0 ? kRiteFxBloodHot : kRiteFxBlood, _ease(f * 1.6))!;
          a = 1 - _ease((f - 0.7) / 0.3);
        }
        if (a <= 0.02) continue;
        batch.add(q.dx, q.dy, p.dx, p.dy, col, alpha: a, width: i % 3 == 0 ? 2.6 : 2.0);
      }
    }
    batch.paint(canvas);
  }
}
