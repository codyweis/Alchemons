// lib/games/planet_dungeon/dungeon_popup_chrome.dart
//
// Shared alchemical bracket-corner chrome for dungeon/raid popups.

import 'package:flutter/material.dart';

class DungeonBracketPainter extends CustomPainter {
  const DungeonBracketPainter({
    required this.color,
    this.bracketSize = 10,
    this.strokeWidth = 1.6,
  });

  final Color color;
  final double bracketSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final s = bracketSize;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0)
      ..moveTo(w - s, 0)
      ..lineTo(w, 0)
      ..lineTo(w, s)
      ..moveTo(0, h - s)
      ..lineTo(0, h)
      ..lineTo(s, h)
      ..moveTo(w - s, h)
      ..lineTo(w, h)
      ..lineTo(w, h - s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DungeonBracketPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
}
