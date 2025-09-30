import 'dart:math' as math;
import 'package:flutter/material.dart';

class Tilt extends StatefulWidget {
  final Widget child;
  final double maxTilt; // degrees
  final Duration ease; // ease duration
  const Tilt({
    super.key,
    required this.child,
    this.maxTilt = 10,
    this.ease = const Duration(milliseconds: 120),
  });

  @override
  State<Tilt> createState() => _TiltState();
}

class _TiltState extends State<Tilt> {
  double _rxDeg = 0; // rotateX degrees
  double _ryDeg = 0; // rotateY degrees

  void _update(Offset local, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final nx = (local.dx / size.width) * 2 - 1; // [-1, 1]
    final ny = (local.dy / size.height) * 2 - 1; // [-1, 1]
    setState(() {
      _rxDeg = -ny * widget.maxTilt;
      _ryDeg = nx * widget.maxTilt;
    });
  }

  void _reset() {
    setState(() {
      _rxDeg = 0;
      _ryDeg = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, c.maxHeight);

        return Listener(
          behavior: HitTestBehavior.opaque, // <- important
          onPointerDown: (e) => _update(e.localPosition, size),
          onPointerMove: (e) => _update(e.localPosition, size),
          onPointerUp: (_) => _reset(),
          onPointerCancel: (_) => _reset(),
          child: AnimatedContainer(
            duration: widget.ease,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateX(_rxDeg * math.pi / 180)
              ..rotateY(_ryDeg * math.pi / 180),
            child: widget.child,
          ),
        );
      },
    );
  }
}
