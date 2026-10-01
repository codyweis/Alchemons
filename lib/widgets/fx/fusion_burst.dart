import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';

import 'fusion_particles.dart';

/// The glyph a cultivation's sigil is drawn as (see [FusionBurstField]).
enum FusionSigil {
  /// Two triangles that turn into each other and lock as a six-point star.
  star,

  /// An element's triangle, point up or down, with a bar for air and earth.
  element,

  /// The star, with the element's triangle inside it.
  starAndElement,
}

/// The fusion cinematic's particles: the grains the two specimens were made
/// of, held as one hot knot, thrown out in an eruption, and gathered back
/// into the cultivation — a slowly turning sphere of both palettes with its
/// sigil drawn in grains across the middle.
///
/// Driven by [u], seconds since the merge handed over:
///  * 0.00 – 0.45  the knot, turning and swelling as it heats
///  * 0.45 – 0.95  the eruption, fast out and slowing
///  * 0.68 – 1.45  the shell gathers back, each grain on its own clock
///  * 0.90 – 1.70  the sigil is drawn in, along its own lines, still turning
///  * 1.55 – 2.00  it locks into place, and glints as it does
///  * after        it turns slowly, waiting
/// A fifth of the grains are never gathered: embers that drift on out of the
/// eruption and go out.
class FusionBurstField {
  FusionBurstField({
    required List<SpecimenGrains> grains,
    required this.radius,
    int maxGrains = 2600,
  }) : assert(grains.length == 2) {
    _seed(grains, maxGrains);
  }

  /// The cultivation's radius.
  final double radius;

  static const double burstAt = 0.45;
  static const double _shellFrom = 0.68, _shellSpread = 0.4, _gatherDur = 0.55;
  static const double _sigilFrom = 0.9, _sigilSpread = 0.45;
  static const double _lockFrom = 1.55, _lockEnd = 2.0;

  /// When the cultivation is whole and locked: the cinematic's reveal.
  static const double settledAt = _lockEnd;

  static const int _tones = SpecimenGrains.toneCount;

  late final int length;
  late final Uint8List _side, _tone, _role;
  late final Float32List _phase, _dir, _dist, _knotR, _gather;
  late final Float32List _lat, _lon0, _omega, _shellR, _along;
  late final List<List<Color>> _palettes;

  // Roles.
  static const int _shell = 0, _sigil = 1, _ember = 2;

  void _seed(List<SpecimenGrains> grains, int maxGrains) {
    final rng = math.Random(29);
    // As many of each specimen as it had, in proportion, up to the cap —
    // sampled evenly through its grains, so its colours come in the same
    // proportions it had them.
    final total = grains[0].length + grains[1].length;
    final take = [
      for (final g in grains)
        total == 0 ? 0 : (g.length * math.min(1.0, maxGrains / total)).round(),
    ];
    length = take[0] + take[1];
    _side = Uint8List(length);
    _tone = Uint8List(length);
    _role = Uint8List(length);
    _phase = Float32List(length);
    _dir = Float32List(length);
    _dist = Float32List(length);
    _knotR = Float32List(length);
    _gather = Float32List(length);
    _lat = Float32List(length);
    _lon0 = Float32List(length);
    _omega = Float32List(length);
    _shellR = Float32List(length);
    _along = Float32List(length);
    _palettes = [for (final g in grains) g.tones];

    final lobeSeed = rng.nextDouble() * math.pi * 2;
    var i = 0;
    for (var s = 0; s < 2; s++) {
      final g = grains[s];
      for (var j = 0; j < take[s]; j++, i++) {
        _side[i] = s;
        _tone[i] = g.length == 0 ? 0 : g.tone[(j * g.length) ~/ take[s]];
        _phase[i] = rng.nextDouble();
        final dir = rng.nextDouble() * math.pi * 2;
        _dir[i] = dir;
        // A filled spray, densest near the middle, and lopsided — a few
        // lobes thrown further than the rest — so it never reads as a hoop.
        final lobes =
            0.85 +
            0.2 * math.sin(dir * 2 + lobeSeed) +
            0.12 * math.sin(dir * 3 + lobeSeed * 1.7) +
            0.08 * math.sin(dir * 5 + lobeSeed * 2.3) +
            0.12 * (rng.nextDouble() - 0.5);
        _dist[i] =
            radius * (0.25 + 2.5 * math.pow(rng.nextDouble(), 1.3)) * lobes;
        _knotR[i] = radius * 0.32 * (0.2 + 0.8 * math.sqrt(rng.nextDouble()));
        final r = rng.nextDouble();
        _role[i] = r < 0.2 ? _ember : (r < 0.42 ? _sigil : _shell);
        _lat[i] = math.asin(rng.nextDouble() * 2 - 1);
        _lon0[i] = rng.nextDouble() * math.pi * 2;
        _omega[i] = 0.5 + 0.7 * rng.nextDouble();
        _shellR[i] = radius * (0.86 + 0.14 * rng.nextDouble());
        _along[i] = rng.nextDouble();
        _gather[i] = _shellFrom + rng.nextDouble() * _shellSpread;
      }
    }
    // The sigil is drawn in along its own lines, so its grains gather in the
    // order they lie along them.
    for (var k = 0; k < length; k++) {
      if (_role[k] == _sigil) {
        _gather[k] = _sigilFrom + _along[k] * _sigilSpread;
      }
    }
  }

  // ── the sigil ─────────────────────────────────────────────────────────

  /// Each polyline of the sigil, as unit-radius points, with how it turns as
  /// it is drawn in (+1 one way, −1 the other).
  List<(List<Offset>, double)> _lines = const [];
  (FusionSigil, String?)? _linesFor;
  late Float32List _lineLen;
  double _sigilLen = 1;

  static List<Offset> _triangle(double rot, double r) => [
    for (var k = 0; k <= 3; k++)
      Offset(
            math.cos(rot + k * 2 * math.pi / 3),
            math.sin(rot + k * 2 * math.pi / 3),
          ) *
          r,
  ];

  void _setSigil(FusionSigil sigil, String? element) {
    if (_linesFor == (sigil, element)) return;
    _linesFor = (sigil, element);
    final el = (element ?? '').toLowerCase();
    final up = el == 'fire' || el == 'air' || el == 'lava';
    final bar = el == 'air' || el == 'earth';
    List<(List<Offset>, double)> elementLines(double r) => [
      (_triangle(up ? -math.pi / 2 : math.pi / 2, r), 0.6),
      if (bar)
        (
          [
            Offset(-r * 0.42, (up ? 1 : -1) * r * 0.18),
            Offset(r * 0.42, (up ? 1 : -1) * r * 0.18),
          ],
          0.6,
        ),
    ];
    _lines = switch (sigil) {
      FusionSigil.star => [
        (_triangle(-math.pi / 2, 0.8), 1.0),
        (_triangle(math.pi / 2, 0.8), -1.0),
      ],
      FusionSigil.element => elementLines(0.74),
      FusionSigil.starAndElement => [
        (_triangle(-math.pi / 2, 0.82), 1.0),
        (_triangle(math.pi / 2, 0.82), -1.0),
        ...elementLines(0.46),
      ],
    };
    double len(List<Offset> pts) {
      var l = 0.0;
      for (var k = 1; k < pts.length; k++) {
        l += (pts[k] - pts[k - 1]).distance;
      }
      return l;
    }

    _lineLen = Float32List.fromList([for (final (p, _) in _lines) len(p)]);
    _sigilLen = _lineLen.fold(0.0, (a, b) => a + b);
  }

  /// Where along the sigil a grain at [along] (0..1 of its whole length)
  /// sits, turned by [swirl], at unit radius.
  Offset _onSigil(double along, double swirl) {
    var d = along * _sigilLen;
    for (var l = 0; l < _lines.length; l++) {
      final (pts, turn) = _lines[l];
      if (d > _lineLen[l] && l < _lines.length - 1) {
        d -= _lineLen[l];
        continue;
      }
      for (var k = 1; k < pts.length; k++) {
        final seg = (pts[k] - pts[k - 1]).distance;
        if (d <= seg || k == pts.length - 1) {
          final p = Offset.lerp(
            pts[k - 1],
            pts[k],
            seg == 0 ? 0 : (d / seg).clamp(0.0, 1.0),
          )!;
          final a = swirl * turn;
          final c = math.cos(a), s = math.sin(a);
          return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
        }
        d -= seg;
      }
    }
    return Offset.zero;
  }

  // ── the look ──────────────────────────────────────────────────────────

  static double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
  static double _smooth(double x) => x * x * (3 - 2 * x);
  static double _easeInOut(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  // Buckets: each specimen's tones, near and far; the sigil; embers; glow;
  // glints.
  static const int _farOff = 2 * _tones;
  static const int _sigilB = 4 * _tones;
  static const int _emberB = _sigilB + 1;
  static const int _glowB = _emberB + 2;
  static const int _glintB = _glowB + 2;
  final GrainBatch _batch = GrainBatch(_glintB + 1);

  /// Paints the cinematic's particles at [u] seconds round [core]. [accent]
  /// and [sigil] are the reveal's (null until the outcome is known: the
  /// cultivation is then drawn in the parents' own colours with the star).
  /// [colors] are the two specimens' element colours. [clock] keeps the
  /// settled cultivation turning while the cinematic waits.
  void paint(
    Canvas canvas,
    Offset core,
    double u, {
    required List<Color> colors,
    Color? accent,
    FusionSigil sigil = FusionSigil.star,
    String? element,
    bool pure = false,
    double clock = 0,
    bool darkBackdrop = true,
  }) {
    if (u < 0) return;
    _setSigil(sigil, element);
    final b = _batch..clear();
    final heat = _clamp01(u / burstAt);
    final burstT = u - burstAt;
    final out = burstT <= 0 ? 0.0 : 1 - math.exp(-6.0 * burstT);
    final lock = _smooth(_clamp01((u - _lockFrom) / (_lockEnd - _lockFrom)));
    final swirl =
        (1 - _smooth(_clamp01((u - _sigilFrom) / (_lockEnd - _sigilFrom)))) *
        math.pi *
        1.25;
    final turn = clock * 0.35;
    const tip = 0.3;
    final cosT = math.cos(tip), sinT = math.sin(tip);
    final pulse = 1 + 0.12 * heat * math.sin(u * 30);
    final emberFade = 1 - _clamp01((u - 0.9) / 0.8);

    for (var i = 0; i < length; i++) {
      final s = _side[i];
      final ph = _phase[i];
      double x, y;
      var far = false;
      if (burstT <= 0) {
        // The knot: tight and turning, drawn in harder as it heats, and
        // shivering.
        final a = _dir[i] + u * (6 + 4 * ph);
        final r = _knotR[i] * pulse * (1.0 - 0.45 * heat);
        final shiver = heat * 1.6 * math.sin(u * 50 + ph * 40);
        x = core.dx + math.cos(a) * r + shiver;
        y = core.dy + math.sin(a) * r * 0.85;
      } else {
        // Thrown out, slowing, with a little spin carried from the knot.
        final a = _dir[i] + 0.35 * out;
        final r = _knotR[i] + _dist[i] * out;
        var bx = core.dx + math.cos(a) * r;
        var by = core.dy + math.sin(a) * r;
        final role = _role[i];
        if (role == _ember) {
          // On out, and out.
          final drift = math.max(0.0, burstT - 0.4) * 22;
          bx += math.cos(a) * drift;
          by += math.sin(a) * drift - drift * 0.4;
          if (emberFade <= 0) continue;
          b.add(_emberB + s, bx, by);
          continue;
        }
        final g = _clamp01((u - _gather[i]) / _gatherDur);
        if (g <= 0) {
          x = bx;
          y = by;
        } else {
          double hx, hy;
          if (role == _sigil) {
            final p = _onSigil(_along[i], swirl);
            hx = core.dx + p.dx * radius;
            hy = core.dy + p.dy * radius;
          } else {
            // A point on the turning shell.
            final lon = _lon0[i] + _omega[i] * (u + turn);
            final cl = math.cos(_lat[i]);
            final px = _shellR[i] * cl * math.cos(lon);
            final py = _shellR[i] * math.sin(_lat[i]);
            final pz = _shellR[i] * cl * math.sin(lon);
            hx = core.dx + px;
            hy = core.dy + py * cosT + pz * sinT;
            far = g > 0.6 && pz * cosT - py * sinT < 0;
          }
          final e = _easeInOut(g);
          // Spiralled in, not dragged straight.
          final bend = math.sin(math.pi * g) * radius * 0.35 * (ph - 0.5);
          final dx = hx - bx, dy = hy - by;
          x = bx + dx * e - dy / (math.sqrt(dx * dx + dy * dy) + 1e-3) * bend;
          y = by + dy * e + dx / (math.sqrt(dx * dx + dy * dy) + 1e-3) * bend;
          if (role == _sigil && g >= 1) {
            // Glints as it locks, then only now and then.
            final glint = lock > 0 && lock < 1
                ? (ph + u * 2.2) % 1.0 < 0.3 * (1 - lock)
                : (clock * 0.3 + ph * 7.3) % 1.0 < 0.012;
            b.add(glint ? _glintB : _sigilB, x, y);
            continue;
          }
          if (role == _sigil) {
            b.add(_sigilB, x, y);
            continue;
          }
        }
      }
      b.add(_glowB + s, x, y);
      final twinkle =
          (clock * 0.23 + ph * 7.3) % 1.0 <
          (burstT > 0 && burstT < 0.5 ? 0.05 : 0.01);
      if (twinkle && !far) {
        b.add(_glintB, x, y);
        continue;
      }
      b.add((far ? _farOff : 0) + s * _tones + _tone[i], x, y);
    }

    // How far a pure reveal's colours have run into its accent.
    final formed = _clamp01((u - _shellFrom) / (_lockEnd - _shellFrom));
    final into = accent == null ? 0.0 : (pure ? 0.65 : 0.25) * formed;
    final grain = 1.6 + 0.5 * (1 - formed) * (burstT > 0 ? 1 : 0);
    final glowAlpha = darkBackdrop ? 0.07 : 0.04;
    for (var s = 0; s < 2; s++) {
      final glow = accent == null
          ? colors[s]
          : Color.lerp(colors[s], accent, into)!;
      b.draw(
        canvas,
        _glowB + s,
        grain * 3.8,
        glow.withValues(alpha: glowAlpha * (1 + heat)),
      );
    }
    for (var s = 0; s < 2; s++) {
      final tones = _palettes[s];
      for (var k = 0; k < tones.length; k++) {
        final c = accent == null
            ? tones[k]
            : Color.lerp(tones[k], accent, into)!;
        b.draw(
          canvas,
          _farOff + s * _tones + k,
          grain * 0.8,
          Color.lerp(c, const Color(0xFF000000), 0.45)!,
        );
        b.draw(canvas, s * _tones + k, grain, c);
      }
      final ember = Color.lerp(colors[s], const Color(0xFFFFF1D6), 0.4)!;
      b.draw(
        canvas,
        _emberB + s,
        1.5,
        ember.withValues(alpha: 0.85 * emberFade),
      );
    }
    final sigilCol = Color.lerp(
      const Color(0xFFFFFFFF),
      accent ?? const Color(0xFFFFE7B0),
      0.3,
    )!;
    b.draw(canvas, _sigilB, 3.6, sigilCol.withValues(alpha: 0.14 + 0.1 * lock));
    b.draw(canvas, _sigilB, 1.7 + 0.5 * lock, sigilCol.withValues(alpha: 0.9));
    const glint = Color(0xFFFFFBEA);
    b.draw(canvas, _glintB, grain * 2.6, glint.withValues(alpha: 0.22));
    b.draw(canvas, _glintB, grain * 1.4, glint.withValues(alpha: 0.95));
  }
}
