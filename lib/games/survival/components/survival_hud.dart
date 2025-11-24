// lib/games/survival/survival_hud.dart
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class SurvivalHud extends PositionComponent with HasGameRef<SurvivalHoardGame> {
  SurvivalHud() : super(priority: 100); // Ensure it draws on top

  late Paint _bgPaint;
  late Paint _borderPaint;

  // HP Paints
  late Paint _hpBgPaint;
  late Paint _hpGoodPaint;
  late Paint _hpMidPaint;
  late Paint _hpLowPaint;

  // XP / Alchemy Paints
  late Paint _xpBgPaint;
  late Paint _xpFillPaint;

  late TextPaint _textPaint;
  late TextPaint _labelPaint;

  @override
  Future<void> onLoad() async {
    // INCREASED HEIGHT: From 160 to 190 to fit the XP bar
    size = Vector2(260, 190);
    anchor = Anchor.bottomLeft;

    // Visual Styles (Dark Alchemy Theme)
    _bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    _borderPaint = Paint()
      ..color = Colors.amber.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    _hpBgPaint = Paint()..color = Colors.grey.withOpacity(0.3);
    _hpGoodPaint = Paint()..color = Colors.cyanAccent;
    _hpMidPaint = Paint()..color = Colors.amber;
    _hpLowPaint = Paint()..color = Colors.redAccent;

    // XP Paints (Purple/Gold Theme for "Alchemy")
    _xpBgPaint = Paint()..color = Colors.deepPurple.shade900.withOpacity(0.5);
    _xpFillPaint = Paint()..color = Colors.purpleAccent;

    _textPaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        fontFamily: 'monospace',
        shadows: [Shadow(blurRadius: 2, color: Colors.black)],
      ),
    );

    _labelPaint = TextPaint(
      style: const TextStyle(
        color: Colors.amberAccent,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
        fontFamily: 'monospace',
        shadows: [Shadow(blurRadius: 2, color: Colors.black)],
      ),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Keep it pinned to bottom left with a small padding
    position = Vector2(10, size.y - 10);
  }

  @override
  void render(Canvas canvas) {
    // 1. Draw HUD Background
    final r = size.toRect();
    final bgRrect = RRect.fromRectAndRadius(r, const Radius.circular(8));
    canvas.drawRRect(bgRrect, _bgPaint);
    canvas.drawRRect(bgRrect, _borderPaint);

    // --- NEW: XP / PROGRESS BAR ---
    // Ensure you have these getters in SurvivalHoardGame:
    // int get killsSinceLastChoice
    // int get killsRequiredForNextLevel
    final currentXP = gameRef.killsSinceLastChoice.toDouble();
    final maxXP = gameRef.killsRequiredForNextLevel.toDouble();

    _drawBar(
      canvas: canvas,
      label: "TRANSMUTATION PROGRESS", // Fancy name for XP
      current: currentXP,
      max: maxXP,
      xOffset: 10,
      yOffset: 10, // Top of the HUD
      barWidth: size.x - 20,
      fillPaintOverride: _xpFillPaint,
      bgPaintOverride: _xpBgPaint,
      heightOverride: 6.0,
      showValues: false, // Show "15 / 20" text
    );

    // 2. Draw Orb HP (Shifted down by ~25px)
    _drawBar(
      canvas: canvas,
      label: "CORE ORB",
      current: gameRef.orb.currentHp.toDouble(),
      max: gameRef.orb.maxHp.toDouble(),
      xOffset: 10,
      yOffset: 35, // Was 10
      barWidth: size.x - 20, // full width
      isMain: true,
    );

    // 3. Draw Guardians in 2 columns (Shifted down)
    final guardians = gameRef.guardians;

    final double topOffset = 70; // Was 45
    final double rowSpacing = 28;
    final double columnSpacing = 10;

    final double totalPadding = 20;
    final double availableWidth = size.x - totalPadding - columnSpacing;
    final double columnWidth = availableWidth / 2;

    for (int i = 0; i < guardians.length; i++) {
      final g = guardians[i];

      final int col = i % 2;
      final int row = i ~/ 2;

      final double x = 10 + col * (columnWidth + columnSpacing);
      final double y = topOffset + row * rowSpacing;

      _drawBar(
        canvas: canvas,
        label: g.unit.name,
        current: g.unit.currentHp.toDouble(),
        max: g.unit.maxHp.toDouble(),
        xOffset: x,
        yOffset: y,
        barWidth: columnWidth,
        isDead: g.unit.isDead,
      );
    }
  }

  void _drawBar({
    required Canvas canvas,
    required String label,
    required double current,
    required double max,
    required double xOffset,
    required double yOffset,
    required double barWidth,
    bool isMain = false,
    bool isDead = false,
    Paint? fillPaintOverride,
    Paint? bgPaintOverride,
    double heightOverride = 0,
    bool showValues = false,
  }) {
    final barHeight = heightOverride > 0
        ? heightOverride
        : (isMain ? 12.0 : 8.0);

    // Draw Label
    if (fillPaintOverride != null) {
      _labelPaint.render(canvas, label, Vector2(xOffset, yOffset));
    } else {
      _textPaint.render(
        canvas,
        isDead ? "$label (DEAD)" : label,
        Vector2(xOffset, yOffset),
      );
    }

    // Draw "15 / 20" value text to the right if requested
    if (showValues) {
      final valText = "${current.toInt()} / ${max.toInt()}";
      final textPainter = TextPainter(
        text: TextSpan(text: valText, style: _textPaint.style),
        textDirection: TextDirection.ltr,
      )..layout();
      final textWidth = textPainter.width;
      _textPaint.render(
        canvas,
        valText,
        Vector2(xOffset + barWidth - textWidth, yOffset),
      );
    }

    // Calculate Ratio
    double ratio = (current / max).clamp(0.0, 1.0);
    if (isDead) ratio = 0.0;
    if (max == 0) ratio = 0.0; // Prevent divide by zero issues

    // Bar Rects
    final barBgRect = Rect.fromLTWH(xOffset, yOffset + 14, barWidth, barHeight);
    final barFillRect = Rect.fromLTWH(
      xOffset,
      yOffset + 14,
      barWidth * ratio,
      barHeight,
    );

    // Draw Bar Background
    canvas.drawRect(barBgRect, bgPaintOverride ?? _hpBgPaint);

    // Draw Bar Fill
    Paint fillPaint;
    if (fillPaintOverride != null) {
      fillPaint = fillPaintOverride;
    } else {
      if (ratio > 0.5) {
        fillPaint = _hpGoodPaint;
      } else if (ratio > 0.25) {
        fillPaint = _hpMidPaint;
      } else {
        fillPaint = _hpLowPaint;
      }
    }

    if (!isDead && ratio > 0) {
      canvas.drawRect(barFillRect, fillPaint);
    }

    // Draw Bar Border
    canvas.drawRect(
      barBgRect,
      Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
