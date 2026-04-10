import 'dart:math' as math;

import 'package:flutter/material.dart';

class BloodAura extends StatefulWidget {
  const BloodAura({super.key, required this.size});

  final double size;

  @override
  State<BloodAura> createState() => _BloodAuraState();
}

class _BloodAuraState extends State<BloodAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pulse = 0.92 + (math.sin(t * math.pi * 2) * 0.08);
        final outerPulse = 1.0 + (math.cos(t * math.pi * 2) * 0.06);
        return SizedBox.square(
          dimension: widget.size * 2.0,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: outerPulse,
                child: Container(
                  width: widget.size * 1.45,
                  height: widget.size * 1.45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0x00FFCDD2),
                        const Color(0x66FF1744),
                        const Color(0x44B71C1C),
                        const Color(0x00120000),
                      ],
                      stops: const [0.18, 0.48, 0.8, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x66FF1744),
                        blurRadius: widget.size * 0.34,
                        spreadRadius: widget.size * 0.02,
                      ),
                    ],
                  ),
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: widget.size * 1.0,
                  height: widget.size * 1.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x99FF8A80),
                      width: widget.size * 0.035,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x55FF1744),
                        blurRadius: widget.size * 0.18,
                        spreadRadius: widget.size * 0.02,
                      ),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < 6; i++)
                _BloodMote(
                  size: widget.size,
                  progress: t,
                  index: i,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BloodMote extends StatelessWidget {
  const _BloodMote({
    required this.size,
    required this.progress,
    required this.index,
  });

  final double size;
  final double progress;
  final int index;

  @override
  Widget build(BuildContext context) {
    final orbit = ((progress + (index * 0.17)) % 1.0);
    final angle = orbit * math.pi * 2;
    final radius = size * (0.38 + (0.1 * math.sin((orbit * math.pi * 2) + index)));
    final dx = math.cos(angle) * radius;
    final dy = math.sin(angle) * radius * 0.7;
    final moteSize = size * (0.07 + ((index % 3) * 0.01));
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: moteSize,
        height: moteSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xCCFF5252),
          boxShadow: [
            BoxShadow(
              color: const Color(0x88D50000),
              blurRadius: moteSize,
              spreadRadius: moteSize * 0.15,
            ),
          ],
        ),
      ),
    );
  }
}
