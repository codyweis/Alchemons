// lib/widgets/fx/bloodborn_vial.dart
//
// The Bloodborn Vial: what the Blood Ring's rite leaves in the extraction
// chamber (see blood_rebirth_service.dart). The favorite dripped away into
// blood at the ring and the pool was sent below; this is that pool, at the
// foot of the round chamber, and the new one forming upward out of it in
// its own grains as the cultivation runs, blood drawn up into it and
// running back off its edges. Ready, it stands whole, dripping, and beats
// like a heart in a red light.
//
// One field paints it wherever it shows: a chamber (in its round vessel),
// the finale's last beat, and the extraction, where it rises out of the
// pool in seconds instead of hours. Grains and light only, as the finale
// is: no strokes, no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/creature.dart' show Genetics;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart'
    show CultivationGrains;
import 'package:alchemons/widgets/fx/fusion_particles.dart' show SpecimenGrains;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// The ring's light, the blood's grain, and the pool's depth.
const kBloodLight = Color(0xFFB3122E);
const kBloodGrain = Color(0xFFC21A35);
const kBloodDeep = Color(0xFF6E0A1C);

double bloodSmooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double bloodSmoother(double t) => t * t * t * (t * (t * 6 - 15) + 10);

/// The lub-dub, 0..1: a beat every [period] seconds, the second softer. A
/// short swell rather than a jump, then easing off.
double bloodHeartbeat(double time, {double period = 1.2}) {
  final ph = (time % period) / period;
  double pulse(double at) {
    final d = ph - at;
    if (d < 0) return 0;
    const attack = 0.035;
    return d < attack
        ? bloodSmooth(0, attack, d)
        : math.exp(-(d - attack) * 15);
  }

  return math.min(1.0, pulse(0) + 0.6 * pulse(0.2));
}

final Paint _lightPaint = Paint();
final Paint _fill = Paint();

/// A soft red light, no blur: a radial gradient squashed to an ellipse.
void paintBloodLight(
  Canvas canvas,
  Offset c,
  double rx,
  double ry,
  double a, {
  Color color = kBloodLight,
}) {
  if (a <= 0.005 || rx <= 0 || ry <= 0) return;
  _lightPaint.shader = RadialGradient(
    colors: [
      color.withValues(alpha: (0.42 * a).clamp(0.0, 1.0)),
      color.withValues(alpha: (0.16 * a).clamp(0.0, 1.0)),
      color.withValues(alpha: 0),
    ],
    stops: const [0, 0.45, 1],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
  canvas
    ..save()
    ..translate(c.dx, c.dy)
    ..scale(rx, ry)
    ..drawCircle(Offset.zero, 1, _lightPaint)
    ..restore();
}

/// A species read into grains for the vial, in its genetics coloring.
class BloodbornVialGrains {
  BloodbornVialGrains._();

  static final Map<String, Future<SpecimenGrains?>> _cache = {};

  static Future<SpecimenGrains?> read(
    String image, {
    Genetics? genetics,
    bool prismatic = false,
    int height = 140,
    int maxGrains = 700,
  }) {
    final key = '$image|${genetics?.variants}|$prismatic|$height|$maxGrains';
    return _cache.putIfAbsent(key, () async {
      try {
        final path = image.startsWith('assets/')
            ? image
            : 'assets/images/$image';
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetHeight: height,
        );
        final src = (await codec.getNextFrame()).image;
        codec.dispose();
        final paint = Paint()..filterQuality = FilterQuality.medium;
        final filter = CultivationGrains.coloring(genetics, prismatic);
        if (filter != null) paint.colorFilter = ColorFilter.matrix(filter);
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImage(src, Offset.zero, paint);
        final pic = rec.endRecording();
        final img = pic.toImageSync(src.width, src.height);
        pic.dispose();
        try {
          final bytes = await img.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          );
          if (bytes == null) return null;
          final g = SpecimenGrains.fromRgba(
            bytes.buffer.asUint8List(),
            img.width,
            img.height,
            pixelRatio: 1,
            maxGrains: maxGrains,
            tones: 14,
          );
          return g.length < 30 ? null : g;
        } finally {
          img.dispose();
          src.dispose();
        }
      } catch (_) {
        return null;
      }
    });
  }

  /// The vial's species out of its payload, read; a disc of blood if it
  /// cannot be read.
  static Future<SpecimenGrains> forPayload(
    Map<String, dynamic> payload,
    CreatureCatalog? catalog, {
    int height = 140,
    int maxGrains = 700,
  }) async {
    final id = payload['baseId'];
    final image = id is String ? catalog?.getCreatureById(id)?.image : null;
    final raw = payload['genetics'];
    final genetics = raw is Map && raw.isNotEmpty
        ? Genetics({for (final e in raw.entries) '${e.key}': '${e.value}'})
        : null;
    final read = image == null || image.isEmpty
        ? null
        : await BloodbornVialGrains.read(
            image,
            genetics: genetics,
            prismatic: payload['isPrismaticSkin'] == true,
            height: height,
            maxGrains: maxGrains,
          );
    return read ?? SpecimenGrains.disc(kBloodGrain, radius: 40);
  }
}

/// The pool, the one forming out of it, the blood drawn up and the blood
/// running off, its heartbeat and its embers.
class BloodbornVialField {
  BloodbornVialField(this.body, {int pool = 220, int seed = 11})
    : _pool = pool {
    final n = body.length;
    final rng = math.Random(seed);
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < n; i++) {
      minX = math.min(minX, body.hx[i]);
      maxX = math.max(maxX, body.hx[i]);
      minY = math.min(minY, body.hy[i]);
      maxY = math.max(maxY, body.hy[i]);
    }
    if (n == 0) minX = maxX = minY = maxY = 0;
    _bx = (minX + maxX) / 2;
    _bottom = maxY;
    _bw = math.max(1.0, maxX - minX);
    _bh = math.max(1.0, maxY - minY);
    _h = Float32List(n);
    _j = Float32List(n);
    _r = Float32List(n);
    _r2 = Float32List(n);
    for (var i = 0; i < n; i++) {
      _h[i] = ((_bottom - body.hy[i]) / _bh).clamp(0.0, 1.0);
      _j[i] = rng.nextDouble() * _jitter;
      _r[i] = rng.nextDouble();
      _r2[i] = rng.nextDouble();
    }
    // Its width at each height, for where the drawn-up blood arrives.
    _lo = Float32List(_bins)..fillRange(0, _bins, double.infinity);
    _hi = Float32List(_bins)..fillRange(0, _bins, -double.infinity);
    for (var i = 0; i < n; i++) {
      final b = (_h[i] * (_bins - 1)).round();
      _lo[b] = math.min(_lo[b], body.hx[i] - _bx);
      _hi[b] = math.max(_hi[b], body.hx[i] - _bx);
    }
    for (var b = 0; b < _bins; b++) {
      if (_lo[b].isFinite) continue;
      // An empty band (between legs, say): its neighbour's width.
      final from = b > 0 ? b - 1 : b + 1;
      if (from < _bins && _lo[from].isFinite) {
        _lo[b] = _lo[from];
        _hi[b] = _hi[from];
      } else {
        _lo[b] = -_bw / 4;
        _hi[b] = _bw / 4;
      }
    }
    // The blood runs off its edges: the grains at either side of their
    // band, below its head.
    final edges = <int>[];
    final near = body.step * 1.6;
    for (var i = 0; i < n; i++) {
      if (_h[i] > 0.85) continue;
      final b = (_h[i] * (_bins - 1)).round();
      final x = body.hx[i] - _bx;
      if (x - _lo[b] < near || _hi[b] - x < near) edges.add(i);
    }
    if (edges.isEmpty) {
      for (var i = 0; i < n; i += math.max(1, n ~/ 24)) {
        edges.add(i);
      }
    }
    _edges = Int32List.fromList(edges);
    _px = Float32List(pool);
    _pd = Float32List(pool);
    _pr = Float32List(pool);
    for (var k = 0; k < pool; k++) {
      _px[k] = rng.nextDouble() * 2 - 1;
      // More of it near the surface, where it is lit.
      _pd[k] = math.pow(rng.nextDouble(), 1.4).toDouble();
      _pr[k] = rng.nextDouble();
    }
    _batch = BloodGrainBatch(
      n + pool + _streams * 2 + _drips * 3 + _embers + 4,
    );
  }

  final SpecimenGrains body;
  final int _pool;

  static const int _bins = 24;
  static const double _band = 0.14, _jitter = 0.06;
  static const int _streams = 22, _drips = 12, _embers = 16;

  late final double _bx, _bottom, _bw, _bh;
  late final Float32List _h, _j, _r, _r2, _lo, _hi;
  late final Int32List _edges;
  late final Float32List _px, _pd, _pr;
  late final BloodGrainBatch _batch;

  /// Paints it in a round vessel: centre [c], radius [r]. The pool fills
  /// the vessel's foot and drops as the body takes the blood up.
  void paintVessel(
    Canvas canvas,
    Offset c,
    double r, {
    required double progress,
    required double ready,
    required double time,
    Offset? pointer,
    double stir = 0,
    double opacity = 1,
  }) {
    final f = progress.clamp(0.0, 1.0);
    final level = 0.58 + 0.13 * f;
    final surface = c.dy + r * level;
    double halfAt(double y) {
      final d = (y - c.dy).abs();
      return d >= r ? 0 : math.sqrt(r * r - d * d) * 0.95;
    }

    final half = halfAt(surface);
    _paint(
      canvas,
      feet: Offset(c.dx, surface + r * 0.03),
      height: r * 1.28,
      maxWidth: r * 1.5,
      progress: f,
      ready: ready,
      time: time,
      poolHalf: half,
      surfaceY: surface,
      poolPoint: (x, d) {
        final px = c.dx + x * half;
        final floor =
            c.dy +
            math.sqrt(math.max(0.0, r * r - (px - c.dx) * (px - c.dx))) * 0.95;
        return Offset(px, surface + d * math.max(0.0, floor - surface));
      },
      poolBody: (canvas, a) {
        // The blood itself under its grains: lit at the surface, deep
        // below, the vessel's round foot its shape.
        final rect = Rect.fromLTRB(
          c.dx - r,
          surface - r * 0.04,
          c.dx + r,
          c.dy + r,
        );
        _fill.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kBloodGrain.withValues(alpha: 0),
            kBloodGrain.withValues(alpha: 0.42 * a),
            kBloodDeep.withValues(alpha: 0.7 * a),
            const Color(0xFF2A0008).withValues(alpha: 0.85 * a),
          ],
          stops: const [0, 0.14, 0.42, 1],
        ).createShader(rect);
        canvas
          ..save()
          ..clipRect(rect)
          ..drawCircle(c, r * 0.95, _fill)
          ..restore();
      },
      scale: r,
      pointer: pointer,
      stir: stir,
      opacity: opacity,
    );
  }

  /// Paints it on an open floor: its feet at [feet], [height] tall at most,
  /// the pool a low ellipse round its feet.
  void paintOpen(
    Canvas canvas,
    Offset feet,
    double height, {
    required double progress,
    required double ready,
    required double time,
    double poolWidth = 0,
    double opacity = 1,
    double? beat,
  }) {
    final half = poolWidth > 0 ? poolWidth / 2 : height * 0.62;
    final depth = height * 0.13;
    _paint(
      canvas,
      feet: feet + Offset(0, depth * 0.3),
      height: height,
      maxWidth: height * 1.4,
      progress: progress.clamp(0.0, 1.0),
      ready: ready,
      time: time,
      poolHalf: half,
      surfaceY: feet.dy,
      poolPoint: (x, d) {
        // An ellipse's lower half, deepest under the feet.
        final w = math.sqrt(math.max(0.0, 1 - x * x));
        return Offset(feet.dx + x * half, feet.dy + d * depth * w);
      },
      poolBody: (canvas, a) => paintBloodLight(
        canvas,
        feet + Offset(0, depth * 0.4),
        half * 1.02,
        depth * 0.9,
        a * 1.6,
        color: kBloodDeep,
      ),
      scale: height * 0.86,
      opacity: opacity,
      beat: beat,
    );
  }

  void _paint(
    Canvas canvas, {
    required Offset feet,
    required double height,
    required double maxWidth,
    required double progress,
    required double ready,
    required double time,
    required double poolHalf,
    required double surfaceY,
    required Offset Function(double x, double depth) poolPoint,
    required void Function(Canvas canvas, double alpha) poolBody,
    required double scale,
    Offset? pointer,
    double stir = 0,
    double opacity = 1,
    double? beat,
  }) {
    final f = progress;
    final s = math.min(height / _bh, maxWidth / _bw);
    final tall = _bh * s;
    // A beat given from outside (the extraction's three) is a full one.
    final given = beat;
    final beatNow =
        given ?? bloodHeartbeat(time, period: 1.9 + (1.15 - 1.9) * ready);
    final amp = given != null ? 1.0 : 0.25 + 0.75 * ready;
    final pulse = 0.032 * beatNow * amp;
    final grain = math.max(1.2, body.step * s * 1.4);
    final front = f * (1 + _band + _jitter);
    final gravity = tall * 3.4;
    final push = stir > 0.01 && pointer != null;
    final reach = scale * 0.4;
    Offset stirred(Offset p) {
      if (!push) return p;
      final d = p - pointer;
      final dist = d.distance;
      if (dist >= reach || dist < 0.001) return p;
      final k = 1 - dist / reach;
      return p + d / dist * (reach * 0.4 * k * k * stir);
    }

    // The light: over the pool, and round the one forming, beating.
    paintBloodLight(
      canvas,
      Offset(feet.dx, surfaceY),
      poolHalf * 1.2,
      scale * 0.26,
      (0.6 + (given != null ? 1.3 : 0.4) * beatNow * amp) * opacity,
    );
    if (f > 0.02) {
      paintBloodLight(
        canvas,
        Offset(feet.dx, feet.dy - tall * math.min(f, 1.0) * 0.5),
        _bw * s * 0.9,
        tall * 0.7,
        (0.2 + 0.4 * ready + 0.7 * beatNow * amp) * f * opacity,
      );
    }
    poolBody(canvas, opacity);

    final b = _batch..begin(grain);

    // The pool, its surface stirred by every beat.
    for (var k = 0; k < _pool; k++) {
      final x = (_px[k] + 0.03 * math.sin(time * 0.35 + _pr[k] * 9)).clamp(
        -1.0,
        1.0,
      );
      final d = _pd[k];
      var p = poolPoint(x, d);
      final out = x.abs();
      final ripple =
          scale *
              (given != null ? 0.04 : 0.022) *
              (0.3 + beatNow * amp) *
              math.sin(out * 8 - time * 4.5) *
              (1 - d) -
          // A beat given from outside heaves the whole pool.
          (given != null ? scale * 0.035 * beatNow * (1 - out) : 0);
      p = stirred(p + Offset(0, ripple));
      var col = Color.lerp(
        kBloodDeep,
        kBloodGrain,
        (1 - d) * 0.65 + _pr[k] * 0.25,
      )!;
      if (_pr[k] > 0.94) {
        final glint = 0.5 + 0.5 * math.sin(time * 2 + _pr[k] * 40);
        col = Color.lerp(col, const Color(0xFFFF6B6B), glint * 0.55)!;
      }
      b.put(p, col, 0.92 * opacity);
    }

    // The one forming: drawn up out of the pool from its feet, its own
    // colours under the blood, the blood thinning off it as it stands.
    for (var i = 0; i < body.length; i++) {
      final si = (front - _h[i] - _j[i]) / _band;
      if (si <= 0) continue;
      final hx = (body.hx[i] - _bx) * s, hy = (body.hy[i] - _bottom) * s;
      final home = feet + Offset(hx, hy) * (1 + pulse);
      final blood = Color.lerp(kBloodDeep, kBloodGrain, 0.45 + 0.55 * _r2[i])!;
      Offset p;
      Color col;
      var alpha = opacity;
      if (si >= 1) {
        p = home + Offset(0, math.sin(time * 1.6 + hx * 0.08) * grain * 0.25);
        var coat = (0.85 - 2.4 * (f - _h[i])).clamp(0.18, 0.85);
        coat = coat + (0.14 - coat) * ready;
        final own = body.tones[body.tone[i]];
        final stronger = Color.lerp(
          own,
          const Color(0xFFFFFFFF),
          0.08 * ready,
        )!;
        col = Color.lerp(stronger, blood, coat)!;
      } else {
        final u0 = bloodSmoother(si);
        final u = (u0 + 0.05 * math.sin(time * 2.6 + _r[i] * 6.283) * (1 - u0))
            .clamp(0.0, 1.0);
        final from = Offset(
          feet.dx + hx * 0.8 + (_r2[i] - 0.5) * grain * 4,
          surfaceY + scale * 0.015 * _r2[i],
        );
        final d = home - from;
        final curl = 0.16 * math.sin(math.pi * u) * (_r2[i] - 0.5);
        p = from + d * u + Offset(-d.dy, d.dx) * curl;
        col = Color.lerp(blood, const Color(0xFFFF4D5E), 0.25 * (1 - u))!;
        alpha *= bloodSmooth(0, 0.2, u);
      }
      b.put(stirred(p), col, alpha);
    }

    // Blood drawn up out of the pool to where it is forming. With nothing
    // formed yet it only leaps and falls back.
    if (f < 0.995) {
      final fill = (1 - ready).clamp(0.0, 1.0);
      for (var j = 0; j < _streams; j++) {
        final ph = (j * 0.618) % 1;
        final t = (time * (0.42 + 0.2 * ((j * 0.37) % 1)) + ph) % 1;
        final side = ((j * 0.73) % 1) - 0.5;
        if (f < 0.1) {
          final x = feet.dx + side * poolHalf * 1.2;
          final y =
              surfaceY - scale * 0.14 * (0.5 + ph) * math.sin(math.pi * t);
          b.put(
            Offset(x, y),
            kBloodGrain,
            0.75 * math.sin(math.pi * t) * fill * opacity,
          );
          continue;
        }
        final at = (math.min(f, 1.0) * (_bins - 1)).round();
        final tx = feet.dx + (_lo[at] + (_hi[at] - _lo[at]) * (side + 0.5)) * s;
        final ty = feet.dy - math.min(f, 1.0) * tall;
        final sx = feet.dx + side * poolHalf * 0.9;
        final u = bloodSmoother(t);
        final p = Offset(sx + (tx - sx) * u, surfaceY + (ty - surfaceY) * u);
        final a = math.sin(math.pi * t) * 0.85 * fill * opacity;
        b.put(p, const Color(0xFFE0283F), a);
        b.put(p + Offset(0, grain * 2.2), kBloodGrain, a * 0.5);
      }
    }

    // Running off its edges, and falling back into the pool.
    final dripping = math.max(f * 0.6, ready);
    final drips = (_drips * dripping).round();
    for (var j = 0; j < drips; j++) {
      final period = 1.8 + 0.9 * ((j * 0.41) % 1);
      final clock = time + ((j * 0.618) % 1) * period;
      final t = (clock / period) % 1;
      final cycle = (clock / period).floor();
      final src =
          _edges[((cycle * 7919 + j * 104729) & 0x7fffffff) % _edges.length];
      final si = (front - _h[src] - _j[src]) / _band;
      if (si < 1) continue;
      final hx = (body.hx[src] - _bx) * s, hy = (body.hy[src] - _bottom) * s;
      final home = feet + Offset(hx, hy) * (1 + pulse);
      final run = tall * 0.05;
      final col = Color.lerp(kBloodGrain, const Color(0xFFFF4D5E), 0.3)!;
      if (t < 0.4) {
        final u = t / 0.4;
        b.put(
          home + Offset(0, run * u * u),
          col,
          bloodSmooth(0, 0.3, u) * opacity,
        );
        continue;
      }
      final a = (t - 0.4) * period;
      final y = home.dy + run + 0.5 * gravity * a * a;
      if (y >= surfaceY) continue;
      final v = gravity * a;
      for (var k = 0; k < 3; k++) {
        b.put(
          Offset(home.dx, y - k * v * 0.012),
          col,
          (0.9 - 0.28 * k) * opacity,
        );
      }
    }

    // Ready: embers of blood rising round it.
    if (ready > 0.02) {
      for (var i = 0; i < _embers; i++) {
        final ph = (i * 0.618) % 1;
        final u = (time * (0.16 + 0.1 * ((i * 0.37) % 1)) + ph) % 1;
        final side = ((i * 0.73) % 1) - 0.5;
        final x =
            feet.dx + side * _bw * s * 1.1 + math.sin(time * 1.3 + i) * grain;
        final y = feet.dy - u * tall * 1.1;
        final c = Color.lerp(
          kBloodDeep,
          const Color(0xFFFF4D5E),
          (i * 0.41) % 1,
        )!;
        b.put(Offset(x, y), c, ready * math.sin(math.pi * u) * 0.85 * opacity);
      }
    }
    b.flush(canvas);
  }
}

/// Grains in their own colours, one atlas draw a frame.
class BloodGrainBatch {
  BloodGrainBatch(int n)
    : _xf = Float32List(n * 4),
      _src = Float32List(n * 4),
      _col = Int32List(n) {
    for (var i = 0; i < n; i++) {
      _src[i * 4 + 2] = 8;
      _src[i * 4 + 3] = 8;
    }
  }

  final Float32List _xf, _src;
  final Int32List _col;
  int _n = 0;
  double _size = 1;

  static final Paint _paint = Paint()..filterQuality = FilterQuality.low;

  static final ui.Image _dot = () {
    const d = 8.0;
    final rec = ui.PictureRecorder();
    Canvas(rec).drawCircle(
      const Offset(d / 2, d / 2),
      d / 2,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final p = rec.endRecording();
    final image = p.toImageSync(d.toInt(), d.toInt());
    p.dispose();
    return image;
  }();

  void begin(double size) {
    _n = 0;
    _size = size;
  }

  void put(Offset p, Color c, double alpha) {
    if (alpha <= 0.02 || _n >= _col.length) return;
    final j = _n * 4;
    _xf[j] = _size / 8;
    _xf[j + 1] = 0;
    _xf[j + 2] = p.dx - _size / 2;
    _xf[j + 3] = p.dy - _size / 2;
    _col[_n] =
        (((c.a * alpha) * 255).round().clamp(0, 255) << 24) |
        ((c.r * 255).round() << 16) |
        ((c.g * 255).round() << 8) |
        (c.b * 255).round();
    _n++;
  }

  void flush(Canvas canvas) {
    if (_n == 0) return;
    canvas.drawRawAtlas(
      _dot,
      Float32List.sublistView(_xf, 0, _n * 4),
      Float32List.sublistView(_src, 0, _n * 4),
      Int32List.sublistView(_col, 0, _n),
      BlendMode.modulate,
      null,
      _paint,
    );
    _n = 0;
  }
}

/// A Bloodborn Vial in a chamber: the round vessel's pool and the one
/// forming out of it, at [progress]; whole and beating when [isReady]. A
/// held finger parts the blood, as it parts a cultivation's grains.
class BloodbornVial extends StatefulWidget {
  const BloodbornVial({
    super.key,
    required this.payload,
    this.progress,
    this.isReady = false,
    this.grains = 640,
    this.radiusFactor = 0.47,
    this.interactive = true,
  });

  final Map<String, dynamic> payload;
  final double? progress;
  final bool isReady;

  /// The whole budget: about two thirds the body, a third the pool.
  final int grains;

  /// The vessel's radius, as a share of the box's shorter side.
  final double radiusFactor;
  final bool interactive;

  @override
  State<BloodbornVial> createState() => _BloodbornVialState();
}

class _BloodbornVialState extends State<BloodbornVial>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  BloodbornVialField? _field;
  Duration _last = Duration.zero;
  double _time = 0, _ready = 0, _stir = 0;
  Offset? _pointer;

  @override
  void initState() {
    super.initState();
    _ready = widget.isReady ? 1 : 0;
    _ticker = createTicker(_tick)..start();
    _load();
  }

  Future<void> _load() async {
    CreatureCatalog? catalog;
    try {
      catalog = context.read<CreatureCatalog>();
    } catch (_) {}
    final budget = widget.grains;
    final body = await BloodbornVialGrains.forPayload(
      widget.payload,
      catalog,
      maxGrains: (budget * 0.66).round(),
    );
    if (!mounted) return;
    setState(
      () => _field = BloodbornVialField(body, pool: (budget * 0.34).round()),
    );
  }

  @override
  void didUpdateWidget(BloodbornVial old) {
    super.didUpdateWidget(old);
    if (old.grains != widget.grains ||
        old.payload['baseId'] != widget.payload['baseId']) {
      _load();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    _time += dt;
    final target = widget.isReady ? 1.0 : 0.0;
    _ready += (target - _ready) * math.min(1.0, dt * 1.2);
    final stir = _pointer == null ? 0.0 : 1.0;
    _stir += (stir - _stir) * math.min(1.0, dt * 6);
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  double get _progress => widget.isReady ? 1 : (widget.progress ?? 0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final paint = CustomPaint(
          size: size,
          painter: _VialPainter(this, repaint: _frame),
        );
        if (!widget.interactive) return paint;
        return GestureDetector(
          onLongPressStart: (d) {
            HapticFeedback.selectionClick();
            _pointer = d.localPosition;
          },
          onLongPressMoveUpdate: (d) => _pointer = d.localPosition,
          onLongPressEnd: (_) => _pointer = null,
          onLongPressCancel: () => _pointer = null,
          child: paint,
        );
      },
    );
  }
}

class _VialPainter extends CustomPainter {
  _VialPainter(this.state, {super.repaint});
  final _BloodbornVialState state;

  @override
  void paint(Canvas canvas, Size size) {
    final field = state._field;
    if (field == null) return;
    final r = math.min(size.width, size.height) * state.widget.radiusFactor;
    field.paintVessel(
      canvas,
      size.center(Offset.zero),
      r,
      progress: state._progress,
      ready: state._ready,
      time: state._time,
      pointer: state._pointer,
      stir: state._stir,
    );
  }

  @override
  bool shouldRepaint(_VialPainter old) => old.state != state;
}
