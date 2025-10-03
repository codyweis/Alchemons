import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingCreature extends StatefulWidget {
  const FloatingCreature({required this.sprite});
  final Widget sprite;

  @override
  State<FloatingCreature> createState() => FloatingCreatureState();
}

class FloatingCreatureState extends State<FloatingCreature>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value; // 0..1
        final dx = math.sin(t * math.pi * 2) * 8;
        final dy = math.cos(t * math.pi * 2 * 0.8) * 6;
        final rot = math.sin(t * math.pi * 2 * 1.3) * 0.06;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(angle: rot, child: widget.sprite),
        );
      },
    );
  }
}
