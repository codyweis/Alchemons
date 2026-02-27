// lib/games/sprite_effects/sprite_prismatic_cascade_component.dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

Color _hsl(double hue, {double s = 1.0, double l = 0.6, double a = 1.0}) =>
    HSLColor.fromAHSL(a.clamp(0, 1), hue % 360, s, l).toColor();

/// Flame-based PrismaticCascade effect. Renders all five layers directly on
/// the Flame [Canvas] each frame, driven by accumulated [_time].
class PrismaticCascadeComponent extends PositionComponent {
  final double baseSize;
  double _time = 0;

  PrismaticCascadeComponent({required this.baseSize});

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 2.6);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  // t: normalised 0..1 cycling every 10 s
  double get _t => (_time % 10.0) / 10.0;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final cx = size.x / 2;
    final cy = size.y / 2;
    final r = baseSize;

    final angle = _t * 2 * math.pi;
    final hueBase = _t * 360;
    final breathe = 1.0 + math.sin(_time * math.pi) * 0.08;

    canvas.save();
    canvas.translate(cx, cy);

    // ── 1. Outer hue-cycling radial glow ────────────────────────────────────
    for (int i = 0; i < 3; i++) {
      final layerHue = (hueBase + i * 60) % 360;
      final layerR = r * (1.8 - i * 0.3) * breathe;
      final opacity = (0.22 - i * 0.05).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset.zero,
        layerR,
        Paint()
          ..color = _hsl(layerHue, a: opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, layerR * 0.35),
      );
    }

    // ── 2. Outer rainbow ring ──────────────────────────────────────────────
    _drawRing(canvas, r * 1.45, r * 0.18, angle, hueBase, 0.55);

    // ── 3. Light rays ────────────────────────────────────────────────────────
    _drawRays(canvas, r, angle * 0.4, hueBase);

    // ── 4. Crystal shards ────────────────────────────────────────────────────
    _drawShards(canvas, r, angle, hueBase);

    // ── 5. Sparkle stars ─────────────────────────────────────────────────────
    _drawSparkles(canvas, r, angle, hueBase, breathe);

    canvas.restore();
  }

  void _drawRing(
    Canvas canvas,
    double radius,
    double thickness,
    double rotation,
    double hueOffset,
    double alpha,
  ) {
    final ringRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final colors = List.generate(
      13,
      (i) => _hsl((hueOffset + i * 30) % 360, a: alpha),
    );
    final stops = List.generate(13, (i) => i / 12.0);

    final shader = SweepGradient(
      colors: colors,
      stops: stops,
      transform: GradientRotation(rotation),
    ).createShader(ringRect);

    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 0.4),
    );
  }

  void _drawRays(Canvas canvas, double r, double rotation, double hueBase) {
    const rayCount = 8;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < rayCount; i++) {
      final rayAngle = rotation + (i / rayCount) * 2 * math.pi;
      final hue = (hueBase + i * (360.0 / rayCount)) % 360;
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

  void _drawShards(Canvas canvas, double r, double angle, double hueBase) {
    const shardCount = 6;
    for (int ring = 0; ring < 2; ring++) {
      final orbitR = ring == 0 ? r * 0.75 : r * 1.2;
      final orbitSpeed = ring == 0 ? angle : -angle * 0.65;
      final shardLen = ring == 0 ? r * 0.18 : r * 0.14;
      final shardWidth = ring == 0 ? r * 0.065 : r * 0.05;

      for (int i = 0; i < shardCount; i++) {
        final shardAngle = orbitSpeed + (i / shardCount) * 2 * math.pi;
        final hue = (hueBase + ring * 30 + i * (360.0 / shardCount)) % 360;
        final phase = (_t + i / shardCount + ring * 0.5) % 1.0;
        final alpha = (0.5 + math.sin(phase * 2 * math.pi) * 0.45).clamp(
          0.15,
          0.95,
        );

        final px = math.cos(shardAngle) * orbitR;
        final py = math.sin(shardAngle) * orbitR;

        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(shardAngle + math.pi / 4);

        final path = Path()
          ..moveTo(0, -shardLen)
          ..lineTo(shardWidth, 0)
          ..lineTo(0, shardLen)
          ..lineTo(-shardWidth, 0)
          ..close();

        canvas.drawPath(
          path,
          Paint()
            ..color = _hsl(hue, l: 0.75, a: alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, shardLen * 0.3),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = _hsl(hue, l: 0.92, a: alpha * 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        canvas.restore();
      }
    }
  }

  void _drawSparkles(
    Canvas canvas,
    double r,
    double angle,
    double hueBase,
    double breathe,
  ) {
    const sparkCount = 16;
    for (int i = 0; i < sparkCount; i++) {
      final phase = (_t * 1.8 + i / sparkCount) % 1.0;
      final dist = r * 0.45 + r * 0.85 * math.sin(phase * math.pi);
      final sparkAngle = angle * 0.7 + (i / sparkCount) * 2 * math.pi;
      final hue = (hueBase + i * (360.0 / sparkCount)) % 360;
      final alpha = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final sparkR = (1.8 + (1 - phase) * 3.0) * breathe;

      final px = math.cos(sparkAngle) * dist;
      final py = math.sin(sparkAngle) * dist;
      final pos = Offset(px, py);

      // 4-pointed star
      const pts = 4;
      final outer = sparkR;
      final inner = sparkR * 0.3;
      final path = Path();
      for (int j = 0; j < pts * 2; j++) {
        final rad = j.isEven ? outer : inner;
        final a = (j / (pts * 2)) * 2 * math.pi - math.pi / 4;
        final ox = pos.dx + math.cos(a) * rad;
        final oy = pos.dy + math.sin(a) * rad;
        if (j == 0) {
          path.moveTo(ox, oy);
        } else {
          path.lineTo(ox, oy);
        }
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = _hsl(hue, l: 0.85, a: alpha * 0.9)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sparkR * 0.5),
      );
      canvas.drawCircle(
        pos,
        sparkR * 0.25,
        Paint()..color = Colors.white.withOpacity(alpha * 0.8),
      );
    }
  }
}
