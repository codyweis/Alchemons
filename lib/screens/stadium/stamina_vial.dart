// lib/screens/stadium/stamina_vial.dart
//
// The Trials' stamina, as the player spends it (a race's BOOST, a bout's
// CHARGE): a glass vial with one chamber of the Alchemon's colour's grains
// for each bar. A tap pours the top chamber out as the Alchemon gathers
// itself; spent chambers stand empty.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';

const Color _ink = Color(0xFFE6E2DA);

class StaminaVial extends StatelessWidget {
  const StaminaVial({
    super.key,
    required this.total,
    required this.left,
    required this.pour,
    required this.clock,
    required this.lit,
    required this.color,
    required this.label,
    required this.onTap,
  });

  /// Bars in all, and still full.
  final int total, left;

  /// How far the chamber above [left] has poured out, 0..1, while one is
  /// being spent; null otherwise.
  final double? pour;

  /// Seconds, for the grains' slow turning.
  final double clock;

  /// How lit the label is: 1 ready, less while busy or spent.
  final double lit;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTap(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size(40, 25.0 * total + 10),
              painter: _VialPainter(total, left, pour, clock, color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: bracketText(
                context,
                10,
                _ink.withValues(alpha: lit),
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VialPainter extends CustomPainter {
  _VialPainter(this.total, this.left, this.pour, this.t, this.color);

  final int total, left;
  final double? pour;
  final double t;
  final Color color;

  static final GrainBatch _batch = GrainBatch(4);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w / 2),
    );
    // Dark glass, lit down its left side.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, 0),
          [
            const Color(0xFF2A2A30),
            const Color(0xFF111114),
            const Color(0xFF17171B),
          ],
          const [0, 0.55, 1],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.1, w * 0.09, h * 0.8),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    // Chambers, bottom up; the top full one pours while a bar is spent.
    final chamber = (h - 10) / total;
    final windup = (pour ?? 0).clamp(0.0, 1.0);
    final b = _batch..clear();
    for (var c = 0; c < total; c++) {
      final full = c < left;
      final pouring = pour != null && c == left;
      final top = h - 5 - (c + 1) * chamber;
      final centre = Offset(w / 2, top + chamber / 2);
      if (full || pouring) {
        final glow = pouring ? 1 - windup : 1.0;
        canvas.drawCircle(
          centre,
          chamber * 0.55,
          Paint()
            ..shader = ui.Gradient.radial(centre, chamber * 0.55, [
              color.withValues(alpha: 0.35 * glow),
              color.withValues(alpha: 0),
            ]),
        );
        for (var i = 0; i < 26; i++) {
          final h1 = hash01(i, 40 + c), h2 = hash01(i, 41 + c);
          final a = h1 * pi * 2 + t * (0.8 + h2) * (i.isEven ? 1 : -1);
          final r = (2 + h2 * (w * 0.3));
          var x = centre.dx + cos(a) * r;
          var y = centre.dy + sin(a) * r * (chamber / w) * 0.7;
          if (pouring) {
            // Up and out of the neck.
            final q = (windup * 1.4 - h2 * 0.4).clamp(0.0, 1.0);
            x += (w / 2 - x) * q;
            y += (-8 - y) * q * q;
          }
          b.add(h2 < 0.3 ? 1 : 0, x, y);
        }
      }
    }
    b.draw(canvas, 0, 2.1, color.withValues(alpha: 0.9));
    b.draw(canvas, 1, 2.6, Color.lerp(color, Colors.white, 0.45)!);
    // The bands between chambers.
    for (var c = 1; c < total; c++) {
      final y = h - 5 - c * chamber;
      canvas.drawRect(
        Rect.fromLTWH(w * 0.12, y - 0.8, w * 0.76, 1.6),
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_VialPainter old) => true;
}
