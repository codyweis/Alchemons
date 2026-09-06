// lib/screens/cosmic/widgets/trippy_cosmos_painter.dart
//
// The deep field behind the cosmic prologue.
//
// It is the open-world cosmic sky first — same near-black ground, same dense
// field of small white twinkling stars — with an abstract layer laid over it:
// orrery rings, fine measurement ticks, chord lines drawn between stars, and
// colour that surfaces and sinks again. Everything in that layer is deliberately
// faint. The sky should read as instrument-grade and slightly unreal, not as a
// rainbow.

import 'dart:math';

import 'package:flutter/material.dart';

/// The cosmic world's own background colour — matched on purpose.
const Color kCosmosGround = Color(0xFF020010);

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.brightness,
    required this.twinkleSpeed,
    required this.hue,
    required this.colorPhase,
    required this.colorRate,
  });

  final double x, y; // 0..1 screen space
  final double size;
  final double brightness;
  final double twinkleSpeed;

  /// Where on the wheel this star sits when it surfaces in colour.
  final double hue;

  /// Phase and rate of the slow surface/sink cycle.
  final double colorPhase;
  final double colorRate;
}

class _Chord {
  const _Chord(this.a, this.b, this.phase);
  final int a, b;
  final double phase;
}

/// Faint, slow, instrument-like. Stars twinkle white; a minority surface into
/// colour and sink back; rings and chords turn behind them.
class TrippyCosmosPainter extends CustomPainter {
  TrippyCosmosPainter({
    required this.t,
    required this.fade,
    required this.surge,
    required this.accent,
    this.warp = 0,
  });

  /// Free-running clock in radians.
  final double t;

  /// 0 → 1 as the field fades up at the start.
  final double fade;

  /// 0 → 1 once a path has been chosen; lifts the abstract layer slightly.
  final double surge;

  /// 0 → 1 → 0 across the hyperspace jump. Stars stretch into radial streaks,
  /// the instrument layer washes out, and the centre blooms.
  final double warp;

  /// Element tint once chosen.
  final Color accent;

  static final List<_Star> _stars = _buildStars();
  static final List<_Chord> _chords = _buildChords();

  static List<_Star> _buildStars() {
    final rng = Random(20260820);
    return List.generate(240, (i) {
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        // Matches the open-world star distribution.
        size: 0.5 + rng.nextDouble() * 2.0,
        brightness: 0.2 + rng.nextDouble() * 0.8,
        twinkleSpeed: 0.5 + rng.nextDouble() * 2.0,
        hue: rng.nextDouble(),
        colorPhase: rng.nextDouble(),
        colorRate: 0.05 + rng.nextDouble() * 0.10,
      );
    });
  }

  /// A handful of chords between star indices — drawn as if something were
  /// measuring the sky.
  static List<_Chord> _buildChords() {
    final rng = Random(7717);
    return List.generate(14, (i) {
      return _Chord(rng.nextInt(240), rng.nextInt(240), rng.nextDouble());
    });
  }

  /// Muted spectrum — desaturated on purpose so colour reads as a tint on a
  /// white star, never as a coloured dot.
  static Color _spectrum(double h, double alpha) {
    const stops = [
      Color(0xFFFF8AB0),
      Color(0xFFFFC98A),
      Color(0xFFF2F0A8),
      Color(0xFF9FE8C4),
      Color(0xFF8FC9F0),
      Color(0xFFC5A8F0),
    ];
    final f = (h % 1.0) * stops.length;
    final i = f.floor() % stops.length;
    final blend = Color.lerp(stops[i], stops[(i + 1) % stops.length], f - i)!;
    return blend.withValues(alpha: alpha);
  }

  /// A soft radial falloff. Used everywhere a glow is wanted: gradients raster
  /// far cheaper than a per-frame `MaskFilter.blur`, and this painter runs
  /// full-screen at 60fps.
  static Shader _falloff(Offset center, double radius, Color color) {
    return RadialGradient(
      colors: [
        color,
        color.withValues(alpha: color.a * 0.38),
        color.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.42, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(Offset.zero & size, Paint()..color = kCosmosGround);

    _paintDrift(canvas, size, c);
    if (warp < 0.98) _paintOrrery(canvas, size, c);
    final points = _paintStars(canvas, size, c);
    if (warp < 0.35) _paintChords(canvas, points);
    if (warp > 0) _paintWarpBloom(canvas, size, c);

    if (surge > 0) {
      final washR = size.shortestSide * 0.9;
      canvas.drawCircle(
        c,
        washR,
        Paint()
          ..shader = _falloff(c, washR, accent.withValues(alpha: 0.09 * surge)),
      );
    }
  }

  /// Very faint colour drifting under everything — the sky is never quite one
  /// colour, but you should have to look for it.
  void _paintDrift(Canvas canvas, Size size, Offset c) {
    for (var i = 0; i < 4; i++) {
      final a = t * (0.05 + i * 0.013) + i * 1.7;
      final rr = size.shortestSide * (0.42 + 0.12 * sin(t * 0.12 + i));
      final pos = Offset(
        c.dx + cos(a) * size.width * 0.30,
        c.dy + sin(a * 0.7) * size.height * 0.30,
      );
      final tint = _spectrum(
        t * 0.018 + i * 0.24,
        (0.045 + 0.026 * sin(t * 0.25 + i)) * fade,
      );
      canvas.drawCircle(pos, rr, Paint()..shader = _falloff(pos, rr, tint));
    }
  }

  /// Concentric orrery rings with fine tick marks — the "scientific" layer.
  void _paintOrrery(Canvas canvas, Size size, Offset c) {
    final reach = size.shortestSide;
    final base = (0.055 * fade + 0.035 * surge) * (1 - warp);

    for (var ring = 0; ring < 4; ring++) {
      final rr =
          reach * (0.20 + ring * 0.19) + sin(t * 0.16 + ring) * reach * 0.012;
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: rr * 2,
          height: rr * 2 * (0.42 + ring * 0.055),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = Colors.white.withValues(alpha: base * (1 - ring * 0.15)),
      );
    }

    // A slowly turning tick ring — like a bearing scale.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 0.035);
    final tick = Paint()
      ..strokeWidth = 0.9
      ..color = Colors.white.withValues(alpha: base * 1.25);
    final tr = reach * 0.62;
    for (var i = 0; i < 72; i++) {
      final a = i * (pi * 2 / 72);
      final long = i % 6 == 0;
      canvas.drawLine(
        Offset(cos(a) * tr, sin(a) * tr * 0.5),
        Offset(
          cos(a) * (tr + (long ? 13 : 6)),
          sin(a) * (tr + (long ? 13 : 6)) * 0.5,
        ),
        tick,
      );
    }
    canvas.restore();
  }

  /// Dense white twinkle, with a minority of stars surfacing into colour and
  /// sinking back out again.
  List<Offset> _paintStars(Canvas canvas, Size size, Offset centre) {
    final dot = Paint();
    final streak = Paint()..strokeCap = StrokeCap.round;
    final points = <Offset>[];
    // How far a star at the screen edge smears during the jump.
    final stretch = warp * warp * 2.6;

    for (final s in _stars) {
      final px = s.x * size.width;
      final py = s.y * size.height;
      points.add(Offset(px, py));

      final twinkle = 0.5 + 0.5 * sin(t * s.twinkleSpeed + s.x * 12);

      // Slow surface/sink cycle. Most of the time this is ~0 and the star is
      // plain white, exactly like the open-world sky.
      final cycle = (s.colorPhase + t * s.colorRate) % 1.0;
      final surfaced = cycle < 0.34 ? sin(cycle / 0.34 * pi) : 0.0;

      final alpha = s.brightness * twinkle * fade;
      dot.color = surfaced <= 0.01
          ? Colors.white.withValues(alpha: alpha)
          : Color.lerp(
              Colors.white,
              _spectrum(s.hue, 1.0),
              surfaced * 0.85,
            )!.withValues(alpha: alpha * (1 + surfaced * 0.35));

      if (stretch > 0.01) {
        // Radial smear away from centre — the further out, the longer the
        // streak, which is what sells forward motion.
        final v = Offset(px, py) - centre;
        final tip = Offset(px, py) + v * stretch;
        streak
          ..color = dot.color.withValues(alpha: alpha * 0.85)
          ..strokeWidth = s.size * (0.75 + warp * 0.55);
        canvas.drawLine(Offset(px, py), tip, streak);
      }

      canvas.drawCircle(Offset(px, py), s.size * (1 + surfaced * 0.5), dot);

      // Only the brightest surfaced stars get a soft bloom — no cross flares.
      if (warp < 0.2 && surfaced > 0.75 && s.brightness > 0.8) {
        final bloomR = s.size * 5.0;
        final at = Offset(px, py);
        canvas.drawCircle(
          at,
          bloomR,
          Paint()
            ..shader = _falloff(
              at,
              bloomR,
              _spectrum(s.hue, 0.30 * surfaced * fade),
            ),
        );
      }
    }
    return points;
  }

  /// The tunnel mouth: light gathering dead ahead as speed builds.
  void _paintWarpBloom(Canvas canvas, Size size, Offset c) {
    // Two nested falloffs, no solid fill: a hard-edged disc reads as a grey
    // plate sitting in front of the stars rather than as light gathering.
    final r = size.shortestSide * (0.14 + warp * 0.70);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = _falloff(
          c,
          r,
          Colors.white.withValues(alpha: 0.20 * warp * warp),
        ),
    );
    final core = r * 0.34;
    canvas.drawCircle(
      c,
      core,
      Paint()
        ..shader = _falloff(
          c,
          core,
          Colors.white.withValues(alpha: 0.45 * warp * warp * warp),
        ),
    );
  }

  /// Hairline chords between star pairs, surfacing and vanishing.
  void _paintChords(Canvas canvas, List<Offset> points) {
    final line = Paint()..strokeWidth = 0.7;
    for (final ch in _chords) {
      final cycle = (ch.phase + t * 0.045) % 1.0;
      final on = cycle < 0.45 ? sin(cycle / 0.45 * pi) : 0.0;
      if (on <= 0.02) continue;
      line.color = Colors.white.withValues(
        alpha: 0.075 * on * fade * (1 + surge * 0.6),
      );
      canvas.drawLine(points[ch.a], points[ch.b], line);
    }
  }

  @override
  bool shouldRepaint(TrippyCosmosPainter old) =>
      old.t != t ||
      old.fade != fade ||
      old.surge != surge ||
      old.warp != warp ||
      old.accent != accent;
}
