import 'dart:math' as math;
import 'package:flutter/material.dart';

/// PrismaticCascade — the most premium alchemy effect.
///
/// Four layered animations rendered via CustomPainter:
///   1. Outer hue-cycling radial glow that slowly shifts through the full spectrum
///   2. Two counter-rotating rainbow sweep rings
///   3. 8 radiating light-ray beams with hue offsets
///   4. 16 prismatic sparkle stars that pulse and color-shift
class PrismaticCascade extends StatefulWidget {
  final double size;
  const PrismaticCascade({super.key, required this.size});

  @override
  State<PrismaticCascade> createState() => _PrismaticCascadeState();
}

class _PrismaticCascadeState extends State<PrismaticCascade>
    with TickerProviderStateMixin {
  /// Main driver — one full revolution = 10 s, everything derived from this.
  late AnimationController _main;

  /// Secondary pulse — 2 s reverse, drives global breathe scale.
  late AnimationController _pulse;

  late Animation<double> _breathe;

  @override
  void initState() {
    super.initState();
    _main = AnimationController(
      duration: const Duration(milliseconds: 10000),
      vsync: this,
    )..repeat();

    _pulse = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _breathe = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _main.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_main, _pulse]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size * 1.2, widget.size * 1.2),
          painter: _PrismaticPainter(
            t: _main.value, // 0..1
            breathe: _breathe.value,
            baseSize: widget.size,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

Color _hsl(double hue, {double s = 1.0, double l = 0.6, double a = 1.0}) =>
    HSLColor.fromAHSL(a.clamp(0, 1), hue % 360, s, l).toColor();

class _PrismaticPainter extends CustomPainter {
  final double t;
  final double breathe;
  final double baseSize;

  const _PrismaticPainter({
    required this.t,
    required this.breathe,
    required this.baseSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = baseSize;

    // Derived time values
    final angle = t * 2 * math.pi; // 0 → 2π over 10 s
    final hueBase = t * 360; // 0 → 360 over 10 s

    canvas.save();
    canvas.translate(cx, cy);

    // ── 1. Outer hue-cycling radial glow ────────────────────────────────────
    _drawOuterGlow(canvas, r, hueBase);

    // ── 2. Outer rainbow ring ──────────────────────────────────────────────
    _drawRainbowRing(
      canvas,
      radius: r * 1.45,
      thickness: r * 0.18,
      rotation: angle,
      hueOffset: hueBase,
      alpha: 0.55,
    );

    // ── 3. Light rays ────────────────────────────────────────────────────────
    _drawLightRays(canvas, r, angle * 0.4, hueBase);

    // ── 4. Sparkle stars ─────────────────────────────────────────────────────
    // The orbiting crystal shards that used to sit between the rays and the
    // sparkles read as floating leaves rather than refracted light, so the
    // cascade is rings + rays + sparkles now.
    _drawSparkles(canvas, r, angle, hueBase);

    canvas.restore();
  }

  // ── Layer 1 ─────────────────────────────────────────────────────────────────
  void _drawOuterGlow(Canvas canvas, double r, double hueBase) {
    // Pulsing hue-shifted glow — two concentric blurred circles
    for (int i = 0; i < 3; i++) {
      final layerHue = (hueBase + i * 60) % 360;
      final layerR = r * (1.8 - i * 0.3) * breathe;
      final opacity = (0.22 - i * 0.05).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = _hsl(layerHue, a: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, layerR * 0.35);
      canvas.drawCircle(Offset.zero, layerR, paint);
    }
  }

  // ── Layer 2 ─────────────────────────────────────────────────────────────────
  void _drawRainbowRing(
    Canvas canvas, {
    required double radius,
    required double thickness,
    required double rotation,
    required double hueOffset,
    required double alpha,
  }) {
    // Full-spectrum SweepGradient ring, drawn as a thick annular circle.
    final ringRect = Rect.fromCircle(center: Offset.zero, radius: radius);

    // Build 13 rainbow stops (red → back to red for seamless loop)
    final colors = List.generate(13, (i) {
      final hue = (hueOffset + i * (360 / 12)) % 360;
      return _hsl(hue, a: alpha);
    });
    final stops = List.generate(13, (i) => i / 12.0);

    final shader = SweepGradient(
      colors: colors,
      stops: stops,
      transform: GradientRotation(rotation),
    ).createShader(ringRect);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 0.4);

    canvas.drawCircle(Offset.zero, radius, paint);
  }

  // ── Layer 3 ─────────────────────────────────────────────────────────────────
  void _drawLightRays(
    Canvas canvas,
    double r,
    double rotation,
    double hueBase,
  ) {
    const rayCount = 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < rayCount; i++) {
      final rayAngle = rotation + (i / rayCount) * 2 * math.pi;
      final hue = (hueBase + i * (360 / rayCount)) % 360;

      final startR = r * 0.3;
      final endR = r * 1.6;

      final startPt = Offset(
        math.cos(rayAngle) * startR,
        math.sin(rayAngle) * startR,
      );
      final endPt = Offset(
        math.cos(rayAngle) * endR,
        math.sin(rayAngle) * endR,
      );

      paint.shader = LinearGradient(
        colors: [
          _hsl(hue, l: 0.8, a: 0.0),
          _hsl(hue, l: 0.75, a: 0.7),
          _hsl(hue, l: 0.65, a: 0.15),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromPoints(startPt, endPt));

      canvas.drawLine(startPt, endPt, paint);
    }
  }

  // ── Layer 4 ─────────────────────────────────────────────────────────────────
  void _drawSparkles(Canvas canvas, double r, double angle, double hueBase) {
    const sparkCount = 16;

    for (int i = 0; i < sparkCount; i++) {
      final phase = (t * 1.8 + i / sparkCount) % 1.0;
      // Radial distance pulses in and out
      final dist = r * 0.45 + r * 0.85 * (math.sin(phase * math.pi));
      final sparkAngle = angle * 0.7 + (i / sparkCount) * 2 * math.pi;
      final hue = (hueBase + i * (360.0 / sparkCount)) % 360;
      final alpha = (math.sin(phase * math.pi)).clamp(0.0, 1.0);

      final px = math.cos(sparkAngle) * dist;
      final py = math.sin(sparkAngle) * dist;

      // 4-pointed star
      final sparkR = (1.8 + (1 - phase) * 3.0) * breathe;
      _drawStar(canvas, Offset(px, py), sparkR, hue, alpha);
    }
  }

  void _drawStar(Canvas canvas, Offset pos, double r, double hue, double a) {
    final outer = r;
    final inner = r * 0.3;
    const points = 4;
    final path = Path();

    for (int i = 0; i < points * 2; i++) {
      final radR = i.isEven ? outer : inner;
      final ptAngle = (i / (points * 2)) * 2 * math.pi - math.pi / 4;
      final px = pos.dx + math.cos(ptAngle) * radR;
      final py = pos.dy + math.sin(ptAngle) * radR;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _hsl(hue, l: 0.85, a: a * 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
    );
    // White-hot core
    canvas.drawCircle(
      pos,
      r * 0.25,
      Paint()..color = Colors.white.withValues(alpha: a * 0.8),
    );
  }

  @override
  bool shouldRepaint(_PrismaticPainter old) =>
      old.t != t || old.breathe != breathe;
}
