import 'dart:math' as math;
import 'package:flutter/material.dart';

/// VoidRift — a swirling dark void of indigo/violet energy that looks like
/// cracks tearing through space.  Three layered animations:
///   1. A slow counter-rotating dark sweep gradient (the "rift field")
///   2. Six radiating cracks that pulse in opacity
///   3. Floating void sparks that orbit/drift outward
class VoidRift extends StatefulWidget {
  final double size;
  const VoidRift({super.key, required this.size});

  @override
  State<VoidRift> createState() => _VoidRiftState();
}

class _VoidRiftState extends State<VoidRift> with TickerProviderStateMixin {
  late AnimationController _rotationA;
  late AnimationController _rotationB;
  late AnimationController _pulseController;
  late AnimationController _sparkController;

  late Animation<double> _outerGlow;
  late Animation<double> _innerPulse;

  @override
  void initState() {
    super.initState();

    // Outer rift field — slow clockwise
    _rotationA = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    // Inner fracture layer — slightly faster counter-clockwise
    _rotationB = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    )..repeat();

    // Pulse for the glow rings
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat(reverse: true);

    _outerGlow = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    _innerPulse = Tween<double>(begin: 0.6, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Void sparks
    _sparkController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationA.dispose();
    _rotationB.dispose();
    _pulseController.dispose();
    _sparkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotationA,
        _rotationB,
        _pulseController,
        _sparkController,
      ]),
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // ── Layer 1: Outer sweeping rift field ──────────────────────────
            Transform.rotate(
              angle: _rotationA.value * 2 * math.pi,
              child: Container(
                width: s * 2.0,
                height: s * 2.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      const Color(
                        0xFF4B0082,
                      ).withValues(alpha: 0.0), // invisible indigo
                      const Color(
                        0xFF6A0DAD,
                      ).withValues(alpha: 0.45 * _outerGlow.value), // violet
                      const Color(0xFF000000).withValues(
                        alpha: 0.55 * _outerGlow.value,
                      ), // void black
                      const Color(0xFF9400D3).withValues(
                        alpha: 0.35 * _outerGlow.value,
                      ), // dark violet
                      const Color(0xFF000000).withValues(
                        alpha: 0.45 * _outerGlow.value,
                      ), // void black
                      const Color(0xFF4B0082).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.18, 0.38, 0.56, 0.76, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 2: Counter-rotating fracture ring ─────────────────────
            Transform.rotate(
              angle: -_rotationB.value * 2 * math.pi,
              child: Container(
                width: s * 1.5,
                height: s * 1.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      const Color(
                        0xFFBB00FF,
                      ).withValues(alpha: 0.5 * _outerGlow.value),
                      Colors.transparent,
                      const Color(
                        0xFF000000,
                      ).withValues(alpha: 0.6 * _outerGlow.value),
                      const Color(
                        0xFFBB00FF,
                      ).withValues(alpha: 0.3 * _outerGlow.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.15, 0.35, 0.55, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // ── Layer 3: Dark radial core ────────────────────────────────────
            Transform.scale(
              scale: _innerPulse.value,
              child: Container(
                width: s * 0.9,
                height: s * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF000000).withValues(alpha: 0.8),
                      const Color(0xFF3D0070).withValues(alpha: 0.6),
                      const Color(0xFF6A0DAD).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 0.75, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF9400D3,
                      ).withValues(alpha: 0.6 * _outerGlow.value),
                      blurRadius: s * 0.6,
                      spreadRadius: s * 0.1,
                    ),
                  ],
                ),
              ),
            ),

            // ── Layer 4: Six void sparks orbiting outward ────────────────────
            ...List.generate(8, (i) {
              final angleOffset = (i / 8) * 2 * math.pi;
              final phase = (_sparkController.value + i / 8) % 1.0;
              final angle = angleOffset + _rotationA.value * 2 * math.pi;
              final dist = s * 0.7 + phase * s * 0.55;
              final x = math.cos(angle) * dist;
              final y = math.sin(angle) * dist;
              final opacity = (math.sin(
                phase * math.pi,
              )).clamp(0.0, 1.0).toDouble();
              final sparkSize = 3.5 + (1.0 - phase) * 3.0;

              return Transform.translate(
                offset: Offset(x, y),
                child: Container(
                  width: sparkSize,
                  height: sparkSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      const Color(0xFFBB00FF),
                      const Color(0xFF00EAFF),
                      phase,
                    )!.withValues(alpha: opacity * 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFFBB00FF,
                        ).withValues(alpha: opacity * 0.6),
                        blurRadius: sparkSize * 2,
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ── Layer 5: Radiating crack lines ──────────────────────────────
            CustomPaint(
              size: Size(s * 2.2, s * 2.2),
              painter: _VoidCrackPainter(
                rotation: _rotationA.value * 2 * math.pi,
                opacity: _outerGlow.value * 0.7,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VoidCrackPainter extends CustomPainter {
  final double rotation;
  final double opacity;

  const _VoidCrackPainter({required this.rotation, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final crackCount = 6;
    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < crackCount; i++) {
      final baseAngle = rotation + (i / crackCount) * 2 * math.pi;

      // Each crack has a main line + a short branch
      final mainLen = size.width * 0.28;
      final branchLen = mainLen * 0.45;
      final branchAngle = baseAngle + 0.35;

      final endX = center.dx + math.cos(baseAngle) * mainLen;
      final endY = center.dy + math.sin(baseAngle) * mainLen;
      final branchX =
          center.dx +
          math.cos(baseAngle) * mainLen * 0.55 +
          math.cos(branchAngle) * branchLen;
      final branchY =
          center.dy +
          math.sin(baseAngle) * mainLen * 0.55 +
          math.sin(branchAngle) * branchLen;

      // Fade from center outward
      final gradient = uiGradient(center, Offset(endX, endY), opacity);

      paint.shader = gradient;
      canvas.drawLine(center, Offset(endX, endY), paint);

      // Branch line
      final branchStart = Offset(
        center.dx + math.cos(baseAngle) * mainLen * 0.55,
        center.dy + math.sin(baseAngle) * mainLen * 0.55,
      );
      canvas.drawLine(branchStart, Offset(branchX, branchY), paint);
    }
  }

  @pragma('vm:never-inline')
  Shader uiGradient(Offset from, Offset to, double opacity) {
    return LinearGradient(
      colors: [
        const Color(0xFFBB00FF).withValues(alpha: opacity),
        const Color(0xFF4B0082).withValues(alpha: opacity * 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromPoints(from, to));
  }

  @override
  bool shouldRepaint(_VoidCrackPainter old) =>
      old.rotation != rotation || old.opacity != opacity;
}
