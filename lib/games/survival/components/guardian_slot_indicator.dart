import 'dart:math' as math;

import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class GuardianSlotIndicator extends PositionComponent
    with TapCallbacks, HasGameRef<SurvivalHoardGame> {
  final int slotIndex;
  double _timer = 0;

  // We set size large (80x80 or 100x100) to ensure the "Tap Radius" is generous.
  // The visual drawing happens relative to the center.
  GuardianSlotIndicator({required this.slotIndex, required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(90), // Huge hit box for easy tapping
        anchor: Anchor.center,
      );

  @override
  void update(double dt) {
    super.update(dt);
    // Animate the timer for the pulse effect
    _timer += dt * 4.0;
  }

  @override
  void render(Canvas canvas) {
    // Calculate pulse (goes between 0.9 and 1.1)
    final double scale = 1.0 + (math.sin(_timer) * 0.15);
    final double alphaPulse = 0.5 + (math.sin(_timer) * 0.2);

    // Find the center of the component's size
    final double centerX = size.x / 2;
    final double centerY = size.y / 2;

    // 🛑 CRITICAL FIX: Translate the canvas origin to the center of the hitbox.
    canvas.translate(centerX, centerY);

    // Draw coordinate system is now relative to the center (0,0)
    final double drawRadius = (size.x / 2) * 0.6;

    // --- Drawing Logic Starts Here (Uses Offset.zero for Center) ---

    // 1. Outer Glow Ring (Pulsing)
    final paintGlow = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: alphaPulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(Offset.zero, drawRadius * scale, paintGlow);

    // 2. Inner Solid Ring
    final paintRim = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(Offset.zero, drawRadius * scale, paintRim);

    // 3. Core "Landing Pad" (Semi-transparent fill)
    final paintCore = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset.zero, (drawRadius * 0.7) * scale, paintCore);

    // 4. Crosshairs / Tech lines
    final paintLines = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final r = drawRadius * scale;
    // Horizontal line
    canvas.drawLine(Offset(-r, 0), Offset(-r + 10, 0), paintLines);
    canvas.drawLine(Offset(r - 10, 0), Offset(r, 0), paintLines);
    // Vertical line
    canvas.drawLine(Offset(0, -r), Offset(0, -r + 10), paintLines);
    canvas.drawLine(Offset(0, r - 10), Offset(0, r), paintLines);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    gameRef.confirmDeployAtSlot(slotIndex);
    // No need to remove manually here, gameRef handles cleanup of all indicators
  }
}
