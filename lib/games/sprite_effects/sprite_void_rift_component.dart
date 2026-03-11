// lib/games/sprite_effects/sprite_void_rift_component.dart
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Flame-based VoidRift effect: a swirling dark void of indigo/violet energy.
/// Renders entirely with CustomPainter so it works cleanly in Flame scenes.
class VoidRiftComponent extends PositionComponent {
  final double baseSize;
  double _time = 0;

  VoidRiftComponent({required this.baseSize});

  @override
  Future<void> onLoad() async {
    size = Vector2.all(baseSize * 2.4);
    anchor = Anchor.center;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final cx = size.x / 2;
    final cy = size.y / 2;
    final center = Offset(cx, cy);
    final r = baseSize;

    // ── Outer rift field (sweep gradient) ───────────────────────────────────
    final outerGlow = (0.45 + math.sin(_time * 1.2) * 0.2).clamp(0.0, 1.0);
    final rotA = _time * (2 * math.pi / 12); // one full rotation per 12 s
    final rotB = -_time * (2 * math.pi / 7); // counter-rotation

    _drawSweepGradient(canvas, center, r * 2.0, rotA, outerGlow * 0.55);
    _drawSweepGradient(canvas, center, r * 1.5, rotB, outerGlow * 0.45);

    // ── Dark radial core ────────────────────────────────────────────────────
    final corePulse = (0.9 + math.sin(_time * 2.0) * 0.1).clamp(0.75, 1.15);
    _drawRadialCore(canvas, center, r * 0.45 * corePulse, outerGlow);

    // ── Crack lines ─────────────────────────────────────────────────────────
    _drawCracks(canvas, center, r, rotA, outerGlow * 0.7);

    // ── Void sparks ─────────────────────────────────────────────────────────
    _drawSparks(canvas, center, r, rotA, outerGlow);
  }

  void _drawSweepGradient(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    double opacity,
  ) {
    final shader = SweepGradient(
      transform: GradientRotation(rotation),
      colors: [
        Colors.transparent,
        const Color(0xFF6A0DAD).withValues(alpha: opacity),
        const Color(0xFF000000).withValues(alpha: opacity * 1.2),
        const Color(0xFF9400D3).withValues(alpha: opacity * 0.7),
        const Color(0xFF000000).withValues(alpha: opacity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.18, 0.38, 0.56, 0.76, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawRadialCore(
    Canvas canvas,
    Offset center,
    double radius,
    double opacity,
  ) {
    final shader = RadialGradient(
      colors: [
        const Color(0xFF000000).withValues(alpha: 0.85),
        const Color(0xFF3D0070).withValues(alpha: 0.6 * opacity),
        const Color(0xFF6A0DAD).withValues(alpha: 0.3 * opacity),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 0.75, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = shader
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5),
    );
  }

  void _drawCracks(
    Canvas canvas,
    Offset center,
    double r,
    double rotation,
    double opacity,
  ) {
    const crackCount = 6;
    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < crackCount; i++) {
      final angle = rotation + (i / crackCount) * 2 * math.pi;
      final len = r * 1.0;
      final endX = center.dx + math.cos(angle) * len;
      final endY = center.dy + math.sin(angle) * len;
      final end = Offset(endX, endY);

      paint.shader = LinearGradient(
        colors: [
          const Color(0xFFBB00FF).withValues(alpha: opacity),
          const Color(0xFF4B0082).withValues(alpha: opacity * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromPoints(center, end));

      canvas.drawLine(center, end, paint);

      // Short branch
      final branchAngle = angle + 0.35;
      final mid = Offset(
        center.dx + math.cos(angle) * len * 0.55,
        center.dy + math.sin(angle) * len * 0.55,
      );
      final branchEnd = Offset(
        mid.dx + math.cos(branchAngle) * len * 0.4,
        mid.dy + math.sin(branchAngle) * len * 0.4,
      );
      paint.shader = LinearGradient(
        colors: [
          const Color(0xFF9400D3).withValues(alpha: opacity * 0.7),
          Colors.transparent,
        ],
      ).createShader(Rect.fromPoints(mid, branchEnd));
      canvas.drawLine(mid, branchEnd, paint);
    }
  }

  void _drawSparks(
    Canvas canvas,
    Offset center,
    double r,
    double rotation,
    double opacity,
  ) {
    const sparkCount = 8;
    final sparkPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int i = 0; i < sparkCount; i++) {
      final phase = ((_time * 0.55) + i / sparkCount) % 1.0;
      final angle = rotation + (i / sparkCount) * 2 * math.pi;
      final dist = r * 0.7 + phase * r * 0.55;
      final x = center.dx + math.cos(angle) * dist;
      final y = center.dy + math.sin(angle) * dist;
      final alpha = (math.sin(phase * math.pi)).clamp(0.0, 1.0);
      final sparkR = 2.0 + (1.0 - phase) * 3.0;

      sparkPaint.color = Color.lerp(
        const Color(0xFFBB00FF),
        const Color(0xFF00EAFF),
        phase,
      )!.withValues(alpha: alpha * 0.9 * opacity);

      canvas.drawCircle(Offset(x, y), sparkR, sparkPaint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }
}
