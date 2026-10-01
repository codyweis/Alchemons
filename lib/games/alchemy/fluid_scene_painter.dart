import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class FluidScenePainter extends CustomPainter {
  FluidScenePainter(this.shader, this.time, Listenable repaint)
    : super(repaint: repaint);
  final ui.FragmentShader shader;
  final double Function() time;
  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time());
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant FluidScenePainter oldDelegate) =>
      oldDelegate.shader != shader;
}
