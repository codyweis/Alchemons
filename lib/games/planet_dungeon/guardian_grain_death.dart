import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/painting.dart';

/// A guardian's death, in grains of itself.
///
/// The body is read into grains the moment it falls — the frame it was
/// showing, at the size it stood — so the death is played by the guardian's
/// own matter, in the particle language of the fusion and the harvest.
/// Plain Dart and driven by time alone: the dungeon ticks it and paints it,
/// and a test can scrub it.
///
/// The beats, in seconds:
///  * 0.00 – 1.25  SEIZE. A crest of sparkle runs down the body and cuts it
///                 away; behind it the body is grains. They shudder and
///                 loosen, cracks open through it and the heat inside shows
///                 through them, and flakes lift off the edges.
///  * 1.25 – 2.00  IMPLODE. Outline first, every grain is drawn round and in
///                 to the core, faster as it goes, into one hot turning knot.
///  * 2.00 – 2.45  BURST. The knot goes: a filled, lopsided spray of the
///                 guardian's own colours over a pool of light.
///  * 2.45 – 3.60  SETTLE. The spray slows and goes out grain by grain; the
///                 embers rise and fade last.
class GuardianGrainDeath {
  GuardianGrainDeath({required this.color});

  /// The guardian's element colour: its heat, its light, its embers.
  final Color color;

  static const double seize = 1.25;
  static const double implode = 0.75;
  static const double burst = 0.45;
  static const double settle = 1.15;
  static const double implodeAt = seize;
  static const double burstAt = seize + implode;
  static const double settleAt = burstAt + burst;
  static const double duration = settleAt + settle;

  /// When enough of it has gone out for something to rise from what is left
  /// (the guardian relic).
  static const double relicAt = settleAt + 0.15;

  /// The square the body is read out of, in world units centred on it, and
  /// how many pixels per unit it is read at.
  static const double box = 220;
  static const double pixelRatio = 2;

  /// A few thousand at most: this is drawn in the game loop.
  static const int maxGrains = 2600;

  static const double _crestStart = 0.06, _crestDur = 0.42;

  /// The latest the crest may start if the read is slow. Past it, the body
  /// is a disc of its colour rather than a body still standing at implode.
  static const double _crestLatest = 0.6;
  static const double _seamFrom = 0.45;
  static const double _releaseSpread = 0.34, _flight = 0.4;

  // ── the body ──────────────────────────────────────────────────────────

  ui.Image? _body;
  double _bodyBox = box;
  bool _reading = false, _failed = false, _disposed = false;
  SpecimenGrains? _grains;

  /// When the host first saw the grains (its own death clock). The crest
  /// starts then, or at its usual moment if they were ready sooner.
  double? readyAt;

  /// The grains, once read.
  SpecimenGrains? get grains => _grains;
  bool get hasGrains => _grains != null;

  /// Whether the read failed, so the host should fall back to a disc.
  bool get readFailed => _failed;

  /// Reads [body] — the guardian as it stood, [box] world units square at
  /// [pixelRatio] px per unit — into grains. Until they arrive the body is
  /// drawn whole from [body]; behind the crest, from the grains.
  Future<void> read(
    ui.Image body, {
    double box = GuardianGrainDeath.box,
    double pixelRatio = GuardianGrainDeath.pixelRatio,
  }) async {
    _body = body;
    _bodyBox = box;
    _reading = true;
    try {
      final data = await body.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (_disposed || data == null) return;
      final rgba = data.buffer.asUint8List();
      // Sorting a body into its tones is a few milliseconds of k-means, on
      // the frame the guardian dies — off the game loop's thread, then.
      SpecimenGrains g;
      try {
        g = await _readOffThread(rgba, body.width, body.height, pixelRatio);
      } catch (_) {
        g = _readGrains(rgba, body.width, body.height, pixelRatio);
      }
      if (_disposed) return;
      // Too late to be of use if the host already fell back to a disc.
      if (g.length >= 60 && _grains == null) _seed(g);
    } catch (_) {
      // Fall through to the disc.
    } finally {
      _reading = false;
      if (_grains == null) _failed = true;
      if (_disposed) _releaseBody();
    }
  }

  /// A ball of the guardian's colour, for a body that could not be read.
  void useFallback({double radius = 34}) {
    if (_grains != null) return;
    _seed(SpecimenGrains.disc(color, radius: radius));
  }

  void dispose() {
    _disposed = true;
    if (!_reading) _releaseBody();
  }

  void _releaseBody() {
    _body?.dispose();
    _body = null;
  }

  // ── the grains ────────────────────────────────────────────────────────

  int _n = 0;
  double _step = 1.4, _reach = 60, _minY = 0, _maxY = 0;
  late Float32List _hx, _hy, _phase, _crestFrac;
  late Float32List _seamX, _seamY, _flakeX, _flakeY, _shedAt;
  late Float32List _release, _knotR, _knotA, _spin;
  late Float32List _dir, _dist, _fadeAt;
  late Uint8List _tone, _flags;
  late List<Color> _tones;

  static const int _edge = 1, _ember = 2;

  void _seed(SpecimenGrains g) {
    final n = g.length;
    _n = n;
    _step = g.step;
    _tones = g.tones;
    _tone = g.tone;
    _hx = g.hx;
    _hy = g.hy;
    _phase = Float32List(n);
    _crestFrac = Float32List(n);
    _seamX = Float32List(n);
    _seamY = Float32List(n);
    _flakeX = Float32List(n);
    _flakeY = Float32List(n);
    _shedAt = Float32List(n);
    _release = Float32List(n);
    _knotR = Float32List(n);
    _knotA = Float32List(n);
    _spin = Float32List(n);
    _dir = Float32List(n);
    _dist = Float32List(n);
    _fadeAt = Float32List(n);
    _flags = Uint8List(n);

    var minY = double.infinity, maxY = double.negativeInfinity, reach = 1.0;
    for (var i = 0; i < n; i++) {
      minY = math.min(minY, _hy[i]);
      maxY = math.max(maxY, _hy[i]);
      reach = math.max(reach, math.sqrt(_hx[i] * _hx[i] + _hy[i] * _hy[i]));
    }
    _minY = n == 0 ? 0 : minY;
    _maxY = n == 0 ? 0 : maxY;
    _reach = reach;
    final ySpan = math.max(1.0, _maxY - _minY);

    final rng = math.Random(23);
    // The cracks: three jagged seams across the body, off its centre so they
    // split it unevenly rather than cutting it like a pie.
    final seams = [
      for (var k = 0; k < 3; k++)
        (
          angle: k * 1.05 + rng.nextDouble() * 0.6,
          px: (rng.nextDouble() - 0.5) * 0.6 * reach,
          py: (rng.nextDouble() - 0.5) * 0.6 * reach,
        ),
    ];
    final band = reach * 0.16;
    final edge = _step * 1.25;
    final lobeSeed = rng.nextDouble() * math.pi * 2;

    for (var i = 0; i < n; i++) {
      final hx = _hx[i], hy = _hy[i];
      final ph = rng.nextDouble();
      _phase[i] = ph;
      _crestFrac[i] = (hy - _minY) / ySpan;

      // How each seam pushes this grain away from itself as it opens.
      var sx = 0.0, sy = 0.0;
      for (var k = 0; k < seams.length; k++) {
        final s = seams[k];
        final ux = math.cos(s.angle), uy = math.sin(s.angle);
        final rx = hx - s.px, ry = hy - s.py;
        final along = rx * ux + ry * uy;
        final d =
            rx * -uy +
            ry * ux +
            reach * 0.05 * math.sin(along * 0.11 + k * 2.1) +
            reach * 0.025 * math.sin(along * 0.31 + k);
        final ad = d.abs();
        if (ad >= band) continue;
        final w = 1 - ad / band;
        final sign = d < 0 ? -1.0 : 1.0;
        sx += -uy * sign * w;
        sy += ux * sign * w;
        if (ad < edge) _flags[i] |= _edge;
      }
      _seamX[i] = sx;
      _seamY[i] = sy;

      final r = math.sqrt(hx * hx + hy * hy);
      final rn = (r / reach).clamp(0.0, 1.0);
      // Flakes: a few off the outline lift away as it seizes.
      if (rn > 0.55 && rng.nextDouble() < 0.1) {
        _shedAt[i] = 0.72 + rng.nextDouble() * 0.45;
        final inv = r < 1e-3 ? 0.0 : 1 / r;
        _flakeX[i] = hx * inv;
        _flakeY[i] = hy * inv;
      } else {
        _shedAt[i] = 1e9;
      }

      // The implosion takes the outline first.
      _release[i] =
          implodeAt +
          _releaseSpread * ((1 - rn) * 0.75 + rng.nextDouble() * 0.25);
      _knotR[i] = reach * 0.24 * math.sqrt(rng.nextDouble());
      _knotA[i] = rng.nextDouble() * math.pi * 2;
      _spin[i] = 6 + 4 * rng.nextDouble();

      // The burst: a filled spray, densest near the middle and lopsided — a
      // few lobes thrown further than the rest — so it never reads as a hoop.
      final dir = rng.nextDouble() * math.pi * 2;
      _dir[i] = dir;
      final lobes =
          0.85 +
          0.22 * math.sin(dir * 2 + lobeSeed) +
          0.14 * math.sin(dir * 3 + lobeSeed * 1.7) +
          0.08 * math.sin(dir * 5 + lobeSeed * 2.3) +
          0.12 * (rng.nextDouble() - 0.5);
      final reachOut = 0.04 + 1.75 * math.pow(rng.nextDouble(), 1.35);
      _dist[i] = reach * reachOut * lobes;
      if (rng.nextDouble() < 0.22) {
        _flags[i] |= _ember;
        _fadeAt[i] = duration - 0.45 * rng.nextDouble();
      } else {
        // The far ones burn out first, so what is left draws back to the
        // middle — where the relic rises.
        _fadeAt[i] =
            settleAt -
            0.1 +
            0.95 * ((1 - reachOut / 1.79) * 0.65 + rng.nextDouble() * 0.35);
      }
    }
    _grains = g;
  }

  // ── the timeline ──────────────────────────────────────────────────────

  static double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
  static double _smooth(double x) => x * x * (3 - 2 * x);

  double _crestFrom(double t) =>
      (readyAt ?? t).clamp(_crestStart, _crestLatest).toDouble();

  /// Where the crest is at [t], in the body's own units from its centre:
  /// above it the body is grains, below it still the body. −∞ before it
  /// starts, +∞ once it has passed (or before there are grains to show).
  double cutY(double t) {
    if (_grains == null) return double.negativeInfinity;
    final p = (t - _crestFrom(t)) / _crestDur;
    if (p <= 0) return double.negativeInfinity;
    if (p >= 1) return double.infinity;
    return _minY + p * (_maxY - _minY);
  }

  /// The body's shudder: growing through the seize, gone at the burst.
  static Offset shakeAt(double t) {
    if (t >= burstAt) return Offset.zero;
    final a = 2.8 * _smooth(_clamp01(t / seize));
    return Offset(math.sin(t * 47) * a, math.cos(t * 39) * a * 0.7);
  }

  // ── the look ──────────────────────────────────────────────────────────

  static const int _tonesB = SpecimenGrains.toneCount;
  static const int _hotB = _tonesB;
  static const int _emberB = _hotB + 1;
  static const int _glowB = _emberB + 1;
  static const int _glintB = _glowB + 1;
  final GrainBatch _batch = GrainBatch(_glintB + 1);
  final Paint _poolPaint = Paint();
  final Paint _bodyPaint = Paint()..filterQuality = FilterQuality.medium;

  static const Color _glint = Color(0xFFFFFBEA);

  /// Paints the death at [t] seconds, the body centred on [centre].
  void paint(Canvas canvas, Offset centre, double t) {
    if (t < 0 || t >= duration) return;
    final c = centre + shakeAt(t);
    final hot = Color.lerp(color, const Color(0xFFFFF4DC), 0.55)!;
    final reach = _reach;
    final iT = _clamp01((t - implodeAt) / implode);
    final bt = t - burstAt;
    final sT = _clamp01((t - settleAt) / settle);

    // Light under it: the heat inside, then the core, then the flash.
    if (t < implodeAt) {
      final s = _smooth(_clamp01(t / seize));
      _pool(canvas, c, reach * 1.15, hot, color, 0.36 * s);
    } else if (bt < 0) {
      final e = math.pow(iT, 1.5).toDouble();
      _pool(canvas, c, reach * (1.15 - 0.7 * e), hot, color, 0.36 + 0.3 * iT);
    } else {
      final e = 1 - math.pow(1 - _clamp01(bt / 0.42), 3).toDouble();
      final flash = math.pow(1 - e, 1.6).toDouble();
      _pool(canvas, c, reach * (0.7 + 2.5 * e), hot, color, 0.6 * flash);
      _pool(canvas, c, reach * 1.6, color, color, 0.12 * (1 - sT) * (1 - sT));
    }

    // The body, still standing below the crest.
    final cut = cutY(t);
    final body = _body;
    if (body != null && cut != double.infinity) {
      canvas.save();
      if (cut.isFinite) {
        canvas.clipRect(
          Rect.fromLTRB(
            c.dx - _bodyBox,
            c.dy + cut,
            c.dx + _bodyBox,
            c.dy + _bodyBox,
          ),
        );
      }
      canvas.drawImageRect(
        body,
        Rect.fromLTWH(0, 0, body.width.toDouble(), body.height.toDouble()),
        Rect.fromCenter(center: c, width: _bodyBox, height: _bodyBox),
        _bodyPaint,
      );
      canvas.restore();
    }
    if (_grains == null) return;

    final crestFrom = _crestFrom(t);
    final seizeS = _smooth(_clamp01((t - 0.35) / (seize - 0.35)));
    final openF = _smooth(_clamp01((t - _seamFrom) / (seize - _seamFrom)));
    final open = openF * reach * 0.07;
    final out = bt <= 0 ? 0.0 : 1 - math.exp(-6.5 * bt);
    final drift = math.max(0.0, bt - 0.3);
    final knot = (1 - 0.45 * iT) * (1 + 0.08 * iT * math.sin(t * 34));
    const knotAtBurst = 0.55;
    final shiver = 1.4 * iT;
    final burstGlints = bt > 0 && bt < 0.3;

    final b = _batch..clear();
    for (var i = 0; i < _n; i++) {
      final since = t - (crestFrom + _crestFrac[i] * _crestDur);
      if (since < 0) continue; // still the body
      final ph = _phase[i];
      final flags = _flags[i];
      double x, y;
      int bucket;
      if (bt < 0) {
        // Standing: loosened once the crest has passed, shuddering, the
        // cracks opening through it.
        final loose = _smooth(math.min(1.0, since / 0.3));
        final swell = 1 + 0.03 * loose + 0.04 * seizeS;
        final wob = _step * (0.35 * loose + 0.9 * seizeS);
        final sx =
            c.dx +
            _hx[i] * swell +
            _seamX[i] * open +
            wob * math.cos(ph * 18.85 + t * (5 + ph * 3));
        final sy =
            c.dy +
            _hy[i] * swell +
            _seamY[i] * open +
            wob * math.sin(ph * 25.13 + t * (4.3 + ph * 3));
        final shed = t - _shedAt[i];
        if (shed > 0) {
          // A flake, lifting off and burning away.
          if (shed > 0.7) continue;
          b.add(_glowB, sx, sy);
          b.add(
            _emberB,
            sx + _flakeX[i] * shed * 26,
            sy + _flakeY[i] * shed * 26 - shed * shed * 46,
          );
          continue;
        }
        final f = (t - _release[i]) / _flight;
        if (f <= 0) {
          x = sx;
          y = sy;
          bucket = (flags & _edge) != 0 && openF > 0.15 ? _hotB : _tone[i];
        } else {
          // Drawn round and in, faster as it goes, into the knot.
          final a = _knotA[i] + t * _spin[i];
          final kr = _knotR[i] * knot;
          final kx =
              c.dx + math.cos(a) * kr + math.sin(t * 50 + ph * 40) * shiver;
          final ky = c.dy + math.sin(a) * kr * 0.85;
          if (f >= 1) {
            x = kx;
            y = ky;
          } else {
            final e = f * f;
            final bend = math.sin(math.pi * f) * 0.35;
            final dx = kx - sx, dy = ky - sy;
            x = sx + dx * e - dy * bend;
            y = sy + dy * e + dx * bend;
          }
          bucket = _tone[i];
        }
      } else {
        // Thrown out of the knot, slowing; then settling and going out.
        if (t >= _fadeAt[i] || _shedAt[i] < burstAt) continue;
        final a0 = _knotA[i] + burstAt * _spin[i];
        final kr = _knotR[i] * knotAtBurst;
        final a = _dir[i] + 0.3 * out;
        final r = _dist[i] * out;
        final ca = math.cos(a), sa = math.sin(a);
        x = c.dx + math.cos(a0) * kr + ca * r;
        y = c.dy + math.sin(a0) * kr * 0.85 + sa * r;
        if ((flags & _ember) != 0) {
          x += ca * drift * 14 + math.sin(t * 2.3 + ph * 6) * drift * 7;
          y += sa * drift * 8 - drift * (26 + 24 * ph);
          bucket = _emberB;
        } else {
          x += ca * drift * 6;
          y += drift * drift * 7;
          bucket = _tone[i];
        }
      }
      b.add(_glowB, x, y);
      // Rare glints only, or the body bleaches: the grains the crest has
      // just passed, a slow twinkle, a little more as it bursts.
      final crest = since < 0.016 && ph < 0.22;
      final twinkle =
          (t * 0.23 + ph * 7.3) % 1.0 < (burstGlints ? 0.02 : 0.0035);
      if (crest || twinkle) {
        b.add(_glintB, x, y);
        continue;
      }
      b.add(bucket, x, y);
    }

    // Heat: the colours run hot as it is drawn in, and cool as it flies.
    final heat = bt < 0 ? 0.5 * iT * iT : 0.5 * math.exp(-4.5 * bt);
    final d = _step * 1.28 * (1 - 0.25 * sT);
    final spray = 1 - 0.45 * sT;
    final emberFade = 1 - _clamp01((t - (duration - 0.55)) / 0.55);
    b.draw(
      canvas,
      _glowB,
      d * 3.4,
      color.withValues(alpha: 0.05 * (1 + heat) * spray),
    );
    for (var k = 0; k < _tones.length; k++) {
      b.draw(
        canvas,
        k,
        d,
        Color.lerp(_tones[k], hot, heat)!.withValues(alpha: spray),
      );
    }
    b.draw(canvas, _hotB, d * 1.1, hot.withValues(alpha: 0.95));
    final ember = Color.lerp(color, const Color(0xFFFFE7B0), 0.5)!;
    b.draw(canvas, _emberB, d * 0.95, ember.withValues(alpha: 0.9 * emberFade));
    b.draw(canvas, _glintB, d * 2.6, _glint.withValues(alpha: 0.22));
    b.draw(canvas, _glintB, d * 1.4, _glint.withValues(alpha: 0.95));
  }

  /// A pool of light: a filled radial falloff, never a ring.
  void _pool(
    Canvas canvas,
    Offset c,
    double r,
    Color inner,
    Color outer,
    double alpha,
  ) {
    if (alpha <= 0.004 || r <= 0) return;
    _poolPaint.shader = ui.Gradient.radial(
      c,
      r,
      [
        inner.withValues(alpha: alpha),
        outer.withValues(alpha: alpha * 0.45),
        outer.withValues(alpha: 0),
      ],
      const [0.0, 0.45, 1.0],
    );
    canvas.drawCircle(c, r, _poolPaint);
  }
}

SpecimenGrains _readGrains(Uint8List rgba, int w, int h, double pixelRatio) =>
    SpecimenGrains.fromRgba(
      rgba,
      w,
      h,
      pixelRatio: pixelRatio,
      maxGrains: GuardianGrainDeath.maxGrains,
    );

/// Top-level, so the closure sent to the isolate carries only its arguments
/// (one made inside the death would drag the body's image along with it).
Future<SpecimenGrains> _readOffThread(
  Uint8List rgba,
  int w,
  int h,
  double pixelRatio,
) => Isolate.run(() => _readGrains(rgba, w, h, pixelRatio));
