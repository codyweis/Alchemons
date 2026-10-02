import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

// The fusion chamber's merge, in particles — the home title's recipe applied
// to the two specimens. Each is read into grains that sit where its pixels
// were and carry their colours, so at rest the grains ARE the sprite (same
// shape, same markings), only made of particles. Then the two pour into the
// orb and become one.

/// A specimen read into grains.
class SpecimenGrains {
  SpecimenGrains._(this.hx, this.hy, this.tone, this.tones, this.step);

  /// Grains laid out by hand, for a body that was never a sprite — an
  /// element's orb, say. [tones] darkest first, as a read sprite's are.
  SpecimenGrains.points(this.hx, this.hy, this.tone, this.tones, this.step);

  /// Where each grain sits, from the centre of the box it was read out of,
  /// in logical px.
  final Float32List hx, hy;

  /// Each grain's colour, as an index into [tones].
  final Uint8List tone;

  /// The specimen's palette, darkest first.
  final List<Color> tones;

  /// Spacing between grains, in logical px.
  final double step;

  int get length => hx.length;

  /// Colours each specimen is sorted into. Enough that a painted sprite
  /// keeps its shading and its small accents (eyes, a horn tip); each tone
  /// is one draw.
  static const int toneCount = 32;

  /// The most grains one specimen is read into. A big sprite is read more
  /// coarsely rather than into more grains.
  static const int maxGrains = 3200;

  /// Reads whatever [boundary] is showing right now.
  ///
  /// Reading the screen rather than the sprite sheet gets exactly what the
  /// player is looking at — this frame of the animation, with the genetics
  /// colouring already on it — and a few hundred pixels where the sheet
  /// would be 20 MB. Null when there is nothing there to read.
  static Future<SpecimenGrains?> capture(
    RenderRepaintBoundary boundary, {
    required double pixelRatio,
  }) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return null;
      final grains = fromRgba(
        data.buffer.asUint8List(),
        image.width,
        image.height,
        pixelRatio: pixelRatio,
      );
      return grains.length < 60 ? null : grains;
    } finally {
      image.dispose();
    }
  }

  /// Reads straight-alpha RGBA pixels into grains, centred on the image.
  static SpecimenGrains fromRgba(
    Uint8List rgba,
    int w,
    int h, {
    required double pixelRatio,
    int maxGrains = maxGrains,
    int tones = toneCount,
  }) {
    var solid = 0;
    for (var o = 3; o < rgba.length; o += 4) {
      if (rgba[o] >= 128) solid++;
    }
    if (solid == 0) {
      return SpecimenGrains._(
        Float32List(0),
        Float32List(0),
        Uint8List(0),
        const [],
        1,
      );
    }
    // As fine as the title's grain, unless that would be too many.
    final area = solid / (pixelRatio * pixelRatio);
    final step = math.max(1.15, math.sqrt(area / maxGrains));
    final sp = step * pixelRatio;
    final q = sp * 0.25;
    final cx = w / 2, cy = h / 2;
    final rng = math.Random(5);
    final xs = <double>[], ys = <double>[];
    final rs = <double>[], gs = <double>[], bs = <double>[];
    // Each grain is the alpha-weighted mean of five taps across its cell, so
    // it takes the patch's colour rather than whichever pixel it landed on.
    const taps = [0.0, 0.0, -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0];
    for (var sy = sp / 2; sy < h; sy += sp) {
      for (var sx = sp / 2; sx < w; sx += sp) {
        // Jittered off the grid, as the title is: a grid reads as a mosaic.
        final jx = sx + (rng.nextDouble() - 0.5) * 0.7 * sp;
        final jy = sy + (rng.nextDouble() - 0.5) * 0.7 * sp;
        var a = 0.0, r = 0.0, g = 0.0, b = 0.0;
        for (var k = 0; k < taps.length; k += 2) {
          final px = (jx + taps[k] * q).round().clamp(0, w - 1);
          final py = (jy + taps[k + 1] * q).round().clamp(0, h - 1);
          final o = (py * w + px) * 4;
          final al = rgba[o + 3].toDouble();
          a += al;
          r += rgba[o] * al;
          g += rgba[o + 1] * al;
          b += rgba[o + 2] * al;
        }
        // Mostly empty: the edge of the body, or a faint aura.
        if (a < 5 * 120) continue;
        xs.add((jx - cx) / pixelRatio);
        ys.add((jy - cy) / pixelRatio);
        rs.add(r / a);
        gs.add(g / a);
        bs.add(b / a);
      }
    }
    final (tone, palette) = _quantise(rs, gs, bs, tones);
    return SpecimenGrains._(
      Float32List.fromList(xs),
      Float32List.fromList(ys),
      tone,
      palette,
      step,
    );
  }

  /// The same grains, flipped left to right — for a sprite that is drawn
  /// mirrored where it stands but was read the right way round.
  SpecimenGrains mirrored() => SpecimenGrains._(
    Float32List.fromList([for (final x in hx) -x]),
    hy,
    tone,
    tones,
    step,
  );

  /// A ball of grains in [color], for a specimen that could not be read.
  factory SpecimenGrains.disc(Color color, {double radius = 28}) {
    const step = 1.4;
    const shades = 8;
    final rng = math.Random(3);
    final xs = <double>[], ys = <double>[], tone = <int>[];
    for (var y = -radius; y <= radius; y += step) {
      for (var x = -radius; x <= radius; x += step) {
        final jx = x + (rng.nextDouble() - 0.5) * step * 0.7;
        final jy = y + (rng.nextDouble() - 0.5) * step * 0.7;
        final d = math.sqrt(jx * jx + jy * jy);
        if (d > radius) continue;
        xs.add(jx);
        ys.add(jy);
        tone.add(((1 - d / radius) * (shades - 1)).round());
      }
    }
    final dark = Color.lerp(color, const Color(0xFF000000), 0.45)!;
    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.45)!;
    return SpecimenGrains._(
      Float32List.fromList(xs),
      Float32List.fromList(ys),
      Uint8List.fromList(tone),
      [
        for (var i = 0; i < shades; i++)
          Color.lerp(dark, light, i / (shades - 1))!,
      ],
      step,
    );
  }

  /// Sorts the grains' colours into at most [toneCount] tones: k-means on an
  /// even subsample, seeded farthest-point so a small accent that is unlike
  /// the rest still gets a tone of its own, then numbered dark to light.
  static (Uint8List, List<Color>) _quantise(
    List<double> rs,
    List<double> gs,
    List<double> bs,
    int toneCount,
  ) {
    final n = rs.length;
    if (n == 0) return (Uint8List(0), const []);
    final k = math.min(toneCount, n);
    final stride = math.max(1, n ~/ 1400);
    final sub = [for (var i = 0; i < n; i += stride) i];
    final m = sub.length;
    final cr = Float64List(k), cg = Float64List(k), cb = Float64List(k);

    double dist(int i, int c) {
      final dr = rs[i] - cr[c], dg = gs[i] - cg[c], db = bs[i] - cb[c];
      return dr * dr + dg * dg + db * db;
    }

    int nearest(int i) {
      var best = 0;
      var bestD = double.infinity;
      for (var c = 0; c < k; c++) {
        final d = dist(i, c);
        if (d < bestD) {
          bestD = d;
          best = c;
        }
      }
      return best;
    }

    // First seed: the sample nearest the mean colour.
    var mr = 0.0, mg = 0.0, mb = 0.0;
    for (final i in sub) {
      mr += rs[i];
      mg += gs[i];
      mb += bs[i];
    }
    mr /= m;
    mg /= m;
    mb /= m;
    var pick = 0;
    var pickD = double.infinity;
    for (var j = 0; j < m; j++) {
      final i = sub[j];
      final dr = rs[i] - mr, dg = gs[i] - mg, db = bs[i] - mb;
      final d = dr * dr + dg * dg + db * db;
      if (d < pickD) {
        pickD = d;
        pick = j;
      }
    }
    final minD = Float64List(m)..fillRange(0, m, double.infinity);
    for (var c = 0; c < k; c++) {
      final s = sub[pick];
      cr[c] = rs[s];
      cg[c] = gs[s];
      cb[c] = bs[s];
      var far = 0;
      var farD = -1.0;
      for (var j = 0; j < m; j++) {
        final d = dist(sub[j], c);
        if (d < minD[j]) minD[j] = d;
        if (minD[j] > farD) {
          farD = minD[j];
          far = j;
        }
      }
      pick = far;
    }

    for (var round = 0; round < 8; round++) {
      final sr = Float64List(k), sg = Float64List(k), sb = Float64List(k);
      final sn = Int32List(k);
      for (final i in sub) {
        final c = nearest(i);
        sr[c] += rs[i];
        sg[c] += gs[i];
        sb[c] += bs[i];
        sn[c]++;
      }
      for (var c = 0; c < k; c++) {
        if (sn[c] == 0) continue;
        cr[c] = sr[c] / sn[c];
        cg[c] = sg[c] / sn[c];
        cb[c] = sb[c] / sn[c];
      }
    }

    double lum(int c) => 0.3 * cr[c] + 0.59 * cg[c] + 0.11 * cb[c];
    final byLum = List.generate(k, (c) => c)
      ..sort((a, b) => lum(a).compareTo(lum(b)));
    final rank = Uint8List(k);
    for (var r = 0; r < k; r++) {
      rank[byLum[r]] = r;
    }
    final tone = Uint8List(n);
    for (var i = 0; i < n; i++) {
      tone[i] = rank[nearest(i)];
    }
    final tones = [
      for (final c in byLum)
        Color.fromARGB(
          255,
          cr[c].round().clamp(0, 255),
          cg[c].round().clamp(0, 255),
          cb[c].round().clamp(0, 255),
        ),
    ];
    return (tone, tones);
  }
}

/// What a merge leaves for the cinematic that follows it: where on screen
/// the pair became one, and what they were made of, so the eruption is made
/// of the same grains.
class FusionMergeHandoff {
  const FusionMergeHandoff({required this.at, required this.grains});

  /// Where the two met, in global (screen) coordinates.
  final Rect at;

  /// Both specimens, as they were read.
  final List<SpecimenGrains> grains;
}

// ── the merge ───────────────────────────────────────────────────────────────

/// Two specimens, turned to grains, pouring into the fusion orb to become
/// one. Plain Dart and driven by time alone, so the breed tab can run it off
/// its merge controller and a test can scrub it.
///
/// The timeline, in seconds:
///  * 0.05 – 0.52  a line of sparkle runs down each specimen; behind it the
///                 sprite is grains (it is cut away to match)
///  * 0.52 – 0.90  they stand there as particles, loose and glinting, the
///                 side nearest the orb leaning towards it
///  * 0.90 – 1.90  peeled off nearest-the-orb first, so each stays itself
///                 while it is used up, the grains arc over the gap into one
///                 cloud round the orb — a sphere of both, the two turning
///                 opposite ways so each winds through the other
///  * 1.90 – 2.15  the whole cloud, both of them, turning as one
///  * 2.15 – 2.60  it falls into the orb, the colours run together and it
///                 goes out in a bloom
class FusionParticleField {
  factory FusionParticleField({
    required List<SpecimenGrains> specimens,
    required List<Offset> centres,
    required List<double> scales,
    required Offset core,
    required double coreRadius,
    required List<Color> colors,
    bool darkBackdrop = true,
  }) {
    assert(specimens.length == 2);
    assert(centres.length == 2 && scales.length == 2 && colors.length == 2);
    return FusionParticleField._(
      specimens,
      centres,
      scales,
      core,
      coreRadius,
      colors,
      darkBackdrop,
      specimens[0].length + specimens[1].length,
    ).._seed();
  }

  FusionParticleField._(
    this._specimens,
    this._centres,
    this._scales,
    this.core,
    this.coreRadius,
    this._colors,
    this.darkBackdrop,
    this.length,
  ) : _side = Uint8List(length),
      _tone = Uint8List(length),
      _relX = Float32List(length),
      _relY = Float32List(length),
      _phase = Float32List(length),
      _near = Float32List(length),
      _crestAt = Float32List(length),
      _release = Float32List(length),
      _orbitR = Float32List(length),
      _omega = Float32List(length),
      _lon0 = Float32List(length),
      _lat = Float32List(length),
      _bulge = Float32List(length),
      _x = Float32List(length),
      _y = Float32List(length),
      _depth = Float32List(length),
      _mode = Uint8List(length),
      _fused = Color.lerp(
        Color.lerp(_colors[0], _colors[1], 0.5)!,
        const Color(0xFFFFFFFF),
        0.3,
      )!;

  /// How long the whole merge takes, in seconds.
  static const double duration = 2.6;

  /// By now both specimens are wholly grains, and nothing has left them yet:
  /// where a merge can wait for a verdict, and run back from if it fails.
  static const double standTime = 0.62;

  static const double _crestStart = 0.05, _crestDur = 0.4;
  static const List<double> _crestDelay = [0.0, 0.07];
  static const double _wispStart = 0.68;
  static const double _pourStart = 0.9, _pourWindow = 0.55, _flight = 0.45;
  static const double _collapseStart = 2.15, _collapseEnd = 2.5;

  /// How far the cloud's axis is tipped towards the viewer, so its near
  /// side passes below the orb and its far side above it.
  static const double _tip = 0.32;

  final List<SpecimenGrains> _specimens;
  final List<Offset> _centres;
  final List<double> _scales;
  final List<Color> _colors;

  /// How far each specimen has been pushed from where it was read — a
  /// knock-back, say. Moves its standing grains, not the ones in flight.
  final List<Offset> shift = [Offset.zero, Offset.zero];

  /// The orb's centre, and the radius of the cloud the grains make round it.
  final Offset core;
  final double coreRadius;
  final bool darkBackdrop;

  /// The grains, both specimens together.
  final int length;

  /// The two specimens the field was made from.
  List<SpecimenGrains> get specimens => _specimens;

  final Uint8List _side, _tone;
  final Float32List _relX, _relY, _phase, _near, _crestAt, _release;
  final Float32List _orbitR, _omega, _lon0, _lat, _bulge;

  // Where each grain is at [_laidAt]: 0 not yet a grain, 1 standing, 2 in
  // flight, 3 in the cloud. Depth below zero is the orb's far side.
  final Float32List _x, _y, _depth;
  final Uint8List _mode;
  double _laidAt = double.nan, _laidClock = double.nan;
  Offset _laidShiftA = Offset.zero, _laidShiftB = Offset.zero;

  /// What both colours run together into at the end.
  final Color _fused;

  // Per specimen: the crest's range, the way to the orb, the way the arcs
  // bow, and the grain's size.
  final _minY = Float64List(2), _maxY = Float64List(2);
  final _dirX = Float64List(2), _dirY = Float64List(2);
  final _perpX = Float64List(2), _perpY = Float64List(2);
  final _grainD = Float64List(2), _wobble = Float64List(2);

  void _seed() {
    final rng = math.Random(17);
    var i = 0;
    for (var s = 0; s < 2; s++) {
      final g = _specimens[s];
      final k = _scales[s];
      final to = core - _centres[s];
      final dist = to.distance;
      final dx = dist == 0 ? 1.0 : to.dx / dist;
      final dy = dist == 0 ? 0.0 : to.dy / dist;
      _dirX[s] = dx;
      _dirY[s] = dy;
      // Across the crossing, turned up the screen: the arcs rise over the
      // gap like the cinematic's conduits.
      var px = -dy, py = dx;
      if (py > 0) {
        px = -px;
        py = -py;
      }
      _perpX[s] = px;
      _perpY[s] = py;
      _grainD[s] = g.step * k * 1.28;
      _wobble[s] = g.step * k * 0.42;

      var minY = double.infinity, maxY = double.negativeInfinity;
      var pMin = double.infinity, pMax = double.negativeInfinity;
      for (var j = 0; j < g.length; j++) {
        minY = math.min(minY, g.hy[j]);
        maxY = math.max(maxY, g.hy[j]);
        final p = g.hx[j] * dx + g.hy[j] * dy;
        pMin = math.min(pMin, p);
        pMax = math.max(pMax, p);
      }
      if (g.length == 0) minY = maxY = 0;
      _minY[s] = minY;
      _maxY[s] = maxY;
      final ySpan = math.max(1.0, maxY - minY);
      final pSpan = math.max(1.0, pMax - pMin);

      // Where round the cloud this specimen's grains come in: the side
      // facing it, so they join the turning rather than cutting across it.
      final arriveAt = math.atan2(0, -dx);
      final midY = (minY + maxY) / 2, halfY = math.max(1.0, (maxY - minY) / 2);

      for (var j = 0; j < g.length; j++, i++) {
        _side[i] = s;
        _tone[i] = g.tone[j];
        _relX[i] = g.hx[j] * k;
        _relY[i] = g.hy[j] * k;
        _phase[i] = rng.nextDouble();
        _crestAt[i] =
            _crestStart + _crestDelay[s] + (g.hy[j] - minY) / ySpan * _crestDur;
        final near = (g.hx[j] * dx + g.hy[j] * dy - pMin) / pSpan;
        _near[i] = near;
        var release =
            _pourStart +
            _pourWindow * ((1 - near) * 0.8 + rng.nextDouble() * 0.2);
        if (rng.nextDouble() < 0.05) {
          // A few go early: wisps drawn off before the rest gives way.
          release = _wispStart + rng.nextDouble() * (_pourStart - _wispStart);
        }
        release = math.max(release, _crestAt[i] + 0.12);
        _release[i] = release;
        // A thick shell. Each grain keeps its height: what was the top of
        // the specimen goes round the top of the cloud.
        _orbitR[i] = coreRadius * (0.72 + 0.4 * rng.nextDouble());
        final v =
            ((g.hy[j] - midY) / halfY * 0.9 + (rng.nextDouble() - 0.5) * 0.25)
                .clamp(-0.97, 0.97);
        _lat[i] = math.asin(v);
        // The two specimens turn opposite ways, each coming round the near
        // side first, so they wind through each other instead of turning as
        // two halves of one ball. Rates of their own shear each into bands.
        final w = (s == 0 ? -1.0 : 1.0) * (2.2 + 3.6 * rng.nextDouble());
        _omega[i] = w;
        _lon0[i] =
            arriveAt +
            (rng.nextDouble() - 0.5) * 1.6 -
            w * _spin(release + _flight);
        final up = rng.nextDouble() < 0.72;
        _bulge[i] = (up ? 1.0 : -0.5) * (6 + 16 * rng.nextDouble());
      }
    }
  }

  // ── the timeline ──────────────────────────────────────────────────────

  static double _interval(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  static double _smooth(double x) => x * x * (3 - 2 * x);

  static double _easeInOut(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  /// How far the cloud has turned by [t]: steady, then spinning up as it
  /// falls in (its rate is 1 + 6c², integrated).
  static double _spin(double t) {
    final c = _interval(t, _collapseStart, _collapseEnd);
    return t + 2 * (_collapseEnd - _collapseStart) * c * c * c;
  }

  /// Where the crest is on specimen [side] at [t], in the captured box's own
  /// coordinates (y from its centre): above it the specimen is grains, below
  /// it still the sprite. −∞ before it starts, +∞ once it has passed.
  double cutY(int side, double t) {
    final p = (t - _crestStart - _crestDelay[side]) / _crestDur;
    if (p <= 0) return double.negativeInfinity;
    if (p >= 1) return double.infinity;
    return _minY[side] + p * (_maxY[side] - _minY[side]);
  }

  /// 0..1 as specimen [side]'s chamber empties.
  double chamberEmpty(int side, double t) =>
      _smooth(_interval(t, _pourStart + 0.15, _pourStart + _pourWindow + 0.15));

  /// [clock] runs the motion that is not the merge — the drift, the
  /// breathing, the twinkle — so a merge held still while it waits on a
  /// verdict stays alive. Without one it is the merge's own time.
  void _layout(double t, double clock) {
    if (t == _laidAt &&
        clock == _laidClock &&
        shift[0] == _laidShiftA &&
        shift[1] == _laidShiftB) {
      return;
    }
    _laidAt = t;
    _laidClock = clock;
    _laidShiftA = shift[0];
    _laidShiftB = shift[1];
    final c = _interval(t, _collapseStart, _collapseEnd);
    final shrink = 1 - 0.94 * c * c * c;
    final spin = _spin(t);
    final lean = _smooth(_interval(t, _wispStart - 0.2, _pourStart)) * 4.0;
    final cosT = math.cos(_tip), sinT = math.sin(_tip);
    for (var i = 0; i < length; i++) {
      final since = t - _crestAt[i];
      if (since < 0) {
        _mode[i] = 0;
        continue;
      }
      final s = _side[i];
      final ph = _phase[i];

      // Standing. Loosened once the crest has passed: the body swells a
      // little so the gaps between grains open, and each grain drifts on a
      // small loop of its own.
      final loose = _smooth(math.min(1.0, since / 0.32));
      final breathe =
          1 + loose * (0.035 + 0.012 * math.sin(clock * 5.0 + s * 2.1));
      final wob = _wobble[s] * loose;
      final pull = lean * _near[i] * _near[i];
      final rx =
          _centres[s].dx +
          shift[s].dx +
          _relX[i] * breathe +
          wob * math.cos(ph * 18.85 + clock * (4.6 + ph * 3)) +
          _dirX[s] * pull;
      final ry =
          _centres[s].dy +
          shift[s].dy +
          _relY[i] * breathe +
          wob * math.sin(ph * 25.13 + clock * (3.9 + ph * 3)) +
          _dirY[s] * pull;

      final f = (t - _release[i]) / _flight;
      if (f <= 0) {
        _x[i] = rx;
        _y[i] = ry;
        _depth[i] = 1;
        _mode[i] = 1;
        continue;
      }

      // Its place in the cloud right now: a point on a turning sphere, its
      // axis tipped so the near side passes below the orb.
      final lon = _lon0[i] + _omega[i] * spin;
      final r = _orbitR[i] * shrink;
      final cl = math.cos(_lat[i]);
      final px = r * cl * math.cos(lon);
      final py = r * math.sin(_lat[i]);
      final pz = r * cl * math.sin(lon);
      final tx = core.dx + px;
      final ty = core.dy + py * cosT + pz * sinT;
      final d = pz * cosT - py * sinT;
      if (f >= 1) {
        _x[i] = tx;
        _y[i] = ty;
        _depth[i] = d;
        _mode[i] = 3;
        continue;
      }
      // In flight: eased onto its moving place in the cloud, bowed off the
      // straight line.
      final e = _easeInOut(f);
      final arc = _bulge[i] * math.sin(math.pi * f);
      _x[i] = rx + (tx - rx) * e + _perpX[s] * arc;
      _y[i] = ry + (ty - ry) * e + _perpY[s] * arc;
      _depth[i] = e > 0.6 ? d : 1;
      _mode[i] = 2;
    }
  }

  /// Where grain [i] is at [t], or null if it has not become a grain yet.
  Offset? debugGrain(int i, double t) {
    _layout(t, t);
    return _mode[i] == 0 ? null : Offset(_x[i], _y[i]);
  }

  // ── the look ──────────────────────────────────────────────────────────

  static const int _tones = SpecimenGrains.toneCount;
  // The far side of the cloud is drawn darker and needs fewer tones.
  static const int _backTones = 8;
  static const int _back = 2 * _tones;
  static const int _glowFront = _back + 2 * _backTones;
  static const int _glowBack = _glowFront + 2;
  static const int _glint = _glowBack + 2;
  final GrainBatch _batch = GrainBatch(_glint + 1);

  int _backTone(int s, int tone) =>
      (tone * _backTones) ~/ math.max(1, _specimens[s].tones.length);

  /// Paints the grains on the orb's far side ([back]) or everything else.
  /// The breed tab paints the far side under the orb and the rest over it.
  void paint(Canvas canvas, double t, {required bool back, double? clock}) {
    if (t <= 0 || t >= duration) return;
    final now = clock ?? t;
    _layout(t, now);
    final c = _interval(t, _collapseStart, _collapseEnd);
    // How far the two palettes have run together.
    final fuse = c * c * 0.85;
    final b = _batch..clear();
    for (var i = 0; i < length; i++) {
      final m = _mode[i];
      if (m == 0) continue;
      if ((_depth[i] < 0) != back) continue;
      final s = _side[i];
      final x = _x[i], y = _y[i];
      if (back) {
        b.add(_back + s * _backTones + _backTone(s, _tone[i]), x, y);
        b.add(_glowBack + s, x, y);
        continue;
      }
      b.add(_glowFront + s, x, y);
      // Rare glints only, or the specimen bleaches: some of the grains the
      // crest has just passed, a slow twinkle, and a little more often in
      // flight.
      final crest = t - _crestAt[i] < 0.02 && _phase[i] < 0.35;
      final twinkle =
          (now * 0.23 + _phase[i] * 7.3) % 1.0 < (m == 2 ? 0.025 : 0.009);
      if (crest || twinkle) {
        b.add(_glint, x, y);
        continue;
      }
      b.add(s * _tones + _tone[i], x, y);
    }

    final shrink = 1 - 0.7 * c;
    final glowAlpha = darkBackdrop ? 0.06 : 0.035;
    for (var s = 0; s < 2; s++) {
      final d = _grainD[s] * shrink;
      final glow = Color.lerp(_colors[s], _fused, fuse)!;
      b.draw(
        canvas,
        back ? _glowBack + s : _glowFront + s,
        d * (back ? 3.0 : 3.6),
        glow.withValues(alpha: back ? glowAlpha * 0.6 : glowAlpha),
      );
    }
    for (var s = 0; s < 2; s++) {
      final d = _grainD[s] * shrink;
      final tones = _specimens[s].tones;
      if (back) {
        for (var k = 0; k < _backTones; k++) {
          final rep =
              tones[((k + 0.5) * tones.length / _backTones).floor().clamp(
                0,
                tones.length - 1,
              )];
          b.draw(
            canvas,
            _back + s * _backTones + k,
            d * 0.82,
            Color.lerp(
              Color.lerp(rep, _fused, fuse)!,
              const Color(0xFF000000),
              0.42,
            )!,
          );
        }
      } else {
        for (var k = 0; k < tones.length; k++) {
          b.draw(
            canvas,
            s * _tones + k,
            d,
            Color.lerp(tones[k], _fused, fuse)!,
          );
        }
      }
    }
    if (back) return;

    final d = (_grainD[0] + _grainD[1]) / 2 * shrink;
    const glint = Color(0xFFFFFBEA);
    b.draw(canvas, _glint, d * 2.6, glint.withValues(alpha: 0.22));
    b.draw(canvas, _glint, d * 1.4, glint.withValues(alpha: 0.95));

    // Out in a bloom as the cloud falls into the core.
    final k = _interval(t, _collapseEnd - 0.2, duration);
    if (k > 0 && k < 1) {
      final a = math.sin(math.pi * k);
      final r = coreRadius * (0.35 + 0.75 * k);
      canvas.drawCircle(
        core,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            core,
            r,
            [
              const Color(0xFFFFFFFF).withValues(alpha: 0.55 * a),
              _fused.withValues(alpha: 0.35 * a),
              _fused.withValues(alpha: 0),
            ],
            const [0.0, 0.4, 1.0],
          ),
      );
    }
  }
}

/// Points in buckets, each bucket one round-capped point draw: how every
/// particle effect here draws thousands of grains in a few dozen calls.
class GrainBatch {
  GrainBatch(int buckets)
    : _pts = List.generate(buckets, (_) => Float32List(256)),
      _n = List.filled(buckets, 0);

  final List<Float32List> _pts;
  final List<int> _n;

  static final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void clear() => _n.fillRange(0, _n.length, 0);

  void add(int b, double x, double y) {
    var buf = _pts[b];
    final i = _n[b] * 2;
    if (i + 2 > buf.length) {
      _pts[b] = buf = Float32List(buf.length * 2)..setAll(0, buf);
    }
    buf[i] = x;
    buf[i + 1] = y;
    _n[b]++;
  }

  void draw(Canvas c, int b, double diameter, Color color) {
    final n = _n[b];
    if (n == 0 || color.a <= 0) return;
    _paint
      ..strokeWidth = diameter
      ..color = color;
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_pts[b], 0, n * 2),
      _paint,
    );
  }
}

/// Paints one layer of a [FusionParticleField] at the time [now] reads.
class FusionParticlePainter extends CustomPainter {
  FusionParticlePainter(
    this.field,
    this.now, {
    required this.back,
    this.clock,
    super.repaint,
  });

  final FusionParticleField field;
  final double Function() now;

  /// The field's idle clock (see [FusionParticleField.paint]), if it has one.
  final double Function()? clock;

  /// The orb's far side, drawn under it.
  final bool back;

  @override
  void paint(Canvas canvas, Size size) =>
      field.paint(canvas, now(), back: back, clock: clock?.call());

  @override
  bool shouldRepaint(FusionParticlePainter old) =>
      old.field != field || old.back != back;
}

/// Keeps the part of a sprite the crest has not reached: everything below
/// [cutY], measured from the box's centre.
class SpriteCrestClipper extends CustomClipper<Rect> {
  const SpriteCrestClipper(this.cutY);

  final double cutY;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -size.width,
    size.height / 2 + cutY.clamp(-1e4, 1e4),
    size.width * 2,
    size.height * 2,
  );

  @override
  bool shouldReclip(SpriteCrestClipper old) => old.cutY != cutY;
}
