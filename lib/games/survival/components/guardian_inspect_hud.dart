// lib/games/survival/components/guardian_inspect_hud.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class GuardianInspectHud extends PositionComponent
    with HasGameRef<SurvivalHoardGame>, TapCallbacks {
  GuardianInspectHud()
    : super(position: Vector2.zero(), anchor: Anchor.topLeft);

  // Interactive areas
  RRect? _targetButtonRect;
  RRect? _closeButtonRect;

  // Animation
  double _slideProgress = 0.0;
  bool _isVisible = false;
  double _pulseTimer = 0.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    priority = 1000;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final hasSelection = gameRef.selectedGuardianNotifier.value != null;

    // Animate slide in/out
    if (hasSelection && !_isVisible) {
      _isVisible = true;
    } else if (!hasSelection && _isVisible) {
      _isVisible = false;
    }

    final targetProgress = _isVisible ? 1.0 : 0.0;
    final diff = targetProgress - _slideProgress;
    if (diff.abs() > 0.01) {
      _slideProgress += diff * dt * 8.0;
      _slideProgress = _slideProgress.clamp(0.0, 1.0);
    } else {
      _slideProgress = targetProgress;
    }

    _pulseTimer += dt;
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    // Position at top-left of screen
    position = Vector2(10, 60);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _targetButtonRect = null;
    _closeButtonRect = null;

    if (_slideProgress < 0.01) return;

    final guardian = gameRef.selectedGuardianNotifier.value;
    if (guardian == null) return;

    final unit = guardian.unit;
    final transmuteRank = gameRef.getTransmuteRank(unit.id);
    final specialRank = gameRef.getSpecialRankForUnit(unit);
    final element = unit.types.firstOrNull ?? 'Normal';
    final familyColor = _getFamilyColor(unit.family);

    // Panel dimensions
    const panelWidth = 220.0;
    const panelHeight = 195.0;

    // Slide animation offset (slide in from left)
    final slideOffset = (1.0 - _slideProgress) * -(panelWidth + 20);

    canvas.save();
    canvas.translate(slideOffset, 0);

    // Draw panel background (now drawn from 0,0 to the right)
    final panelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, panelWidth, panelHeight),
      const Radius.circular(12),
    );

    // Background with blur effect simulation
    final bgPaint = Paint()..color = const Color(0xE6101018);
    canvas.drawRRect(panelRect, bgPaint);

    // Family color accent on right edge
    final accentRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(panelWidth - 4, 8, 4, panelHeight - 16),
      topRight: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );
    canvas.drawRRect(accentRect, Paint()..color = familyColor);

    // Border
    canvas.drawRRect(
      panelRect,
      Paint()
        ..color = familyColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Content area
    double y = 12.0;
    const leftPad = 14.0;
    final rightPad = panelWidth - 14.0;

    // === HEADER: Name + Close button ===
    _drawText(
      canvas,
      unit.name,
      leftPad,
      y,
      size: 14,
      weight: FontWeight.bold,
      color: Colors.white,
    );

    // Close button (X)
    final closeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rightPad - 22, y - 2, 22, 22),
      const Radius.circular(4),
    );
    _closeButtonRect = closeRect;
    canvas.drawRRect(closeRect, Paint()..color = Colors.white.withOpacity(0.1));
    _drawText(
      canvas,
      '✕',
      rightPad - 16,
      y + 2,
      size: 12,
      color: Colors.white60,
    );

    y += 22;

    // === Family + Element row ===
    // Family badge
    final familyBadgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftPad, y, 50, 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      familyBadgeRect,
      Paint()..color = familyColor.withOpacity(0.25),
    );
    canvas.drawRRect(
      familyBadgeRect,
      Paint()
        ..color = familyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _drawText(
      canvas,
      unit.family.toUpperCase(),
      leftPad + 6,
      y + 3,
      size: 10,
      weight: FontWeight.bold,
      color: familyColor,
    );

    // Element badge
    final elementColor = _getElementColor(element);
    final elementBadgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftPad + 56, y, 55, 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      elementBadgeRect,
      Paint()..color = elementColor.withOpacity(0.25),
    );
    _drawText(
      canvas,
      element.toUpperCase(),
      leftPad + 62,
      y + 3,
      size: 10,
      weight: FontWeight.w600,
      color: elementColor,
    );

    // Level
    _drawText(
      canvas,
      'Lv ${unit.level}',
      rightPad - 40,
      y + 3,
      size: 10,
      weight: FontWeight.bold,
      color: Colors.amber,
    );

    y += 26;

    // === HP Bar ===
    final hpPercent = unit.maxHp > 0 ? unit.currentHp / unit.maxHp : 0.0;
    final hpColor = hpPercent > 0.5
        ? const Color(0xFF10B981)
        : hpPercent > 0.25
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    _drawText(canvas, 'HP', leftPad, y, size: 9, color: Colors.white60);
    _drawText(
      canvas,
      '${unit.currentHp}/${unit.maxHp}',
      rightPad - 60,
      y,
      size: 9,
      color: hpColor,
    );

    y += 12;

    // HP bar
    final hpBarBg = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftPad, y, panelWidth - 28, 6),
      const Radius.circular(3),
    );
    canvas.drawRRect(hpBarBg, Paint()..color = Colors.white.withOpacity(0.1));

    if (hpPercent > 0) {
      final hpBarFill = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftPad, y, (panelWidth - 28) * hpPercent, 6),
        const Radius.circular(3),
      );
      canvas.drawRRect(hpBarFill, Paint()..color = hpColor);
    }

    y += 14;

    // === Stats row ===
    final physAtk = unit.getEffectivePhysAtk();
    final elemAtk = unit.getEffectiveElemAtk();
    final physDef = unit.getEffectivePhysDef();
    final elemDef = unit.getEffectiveElemDef();

    // ATK
    _drawText(canvas, 'ATK', leftPad, y, size: 9, color: Colors.white60);
    _drawText(
      canvas,
      '$physAtk',
      leftPad + 28,
      y,
      size: 10,
      weight: FontWeight.bold,
      color: const Color(0xFFEF4444),
    );
    _drawText(canvas, '/', leftPad + 45, y, size: 9, color: Colors.white30);
    _drawText(
      canvas,
      '$elemAtk',
      leftPad + 52,
      y,
      size: 10,
      weight: FontWeight.bold,
      color: const Color(0xFF8B5CF6),
    );

    // DEF
    _drawText(canvas, 'DEF', leftPad + 85, y, size: 9, color: Colors.white60);
    _drawText(
      canvas,
      '$physDef',
      leftPad + 113,
      y,
      size: 10,
      weight: FontWeight.bold,
      color: const Color(0xFF3B82F6),
    );
    _drawText(canvas, '/', leftPad + 130, y, size: 9, color: Colors.white30);
    _drawText(
      canvas,
      '$elemDef',
      leftPad + 137,
      y,
      size: 10,
      weight: FontWeight.bold,
      color: const Color(0xFF06B6D4),
    );

    y += 18;

    // === Range ===
    _drawText(
      canvas,
      'Range: ${unit.attackRange.toInt()}',
      leftPad,
      y,
      size: 10,
      color: Colors.white70,
    );

    y += 18;

    // === Upgrade pips ===
    _drawText(canvas, 'Transmute', leftPad, y, size: 9, color: Colors.white60);
    for (int i = 0; i < 3; i++) {
      final filled = i < transmuteRank;
      final pipX = leftPad + 60 + i * 14;
      canvas.drawCircle(
        Offset(pipX, y + 5),
        5,
        Paint()
          ..color = filled
              ? const Color(0xFF8B5CF6)
              : Colors.white.withOpacity(0.15),
      );
      if (filled) {
        canvas.drawCircle(
          Offset(pipX, y + 5),
          5,
          Paint()..color = const Color(0xFF8B5CF6).withOpacity(0.5),
        );
      }
    }

    _drawText(
      canvas,
      'Special',
      leftPad + 110,
      y,
      size: 9,
      color: Colors.white60,
    );
    for (int i = 0; i < 3; i++) {
      final filled = i < specialRank;
      final pipX = leftPad + 158 + i * 14;
      canvas.drawCircle(
        Offset(pipX, y + 5),
        5,
        Paint()
          ..color = filled
              ? const Color(0xFFFFD700)
              : Colors.white.withOpacity(0.15),
      );
      if (filled) {
        canvas.drawCircle(
          Offset(pipX, y + 5),
          5,
          Paint()..color = const Color(0xFFFFD700).withOpacity(0.5),
        );
      }
    }

    y += 22;

    // === Target Priority button ===
    final targetLabel = guardian.targetPriorityLabel;
    final targetRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(leftPad, y, panelWidth - 28, 24),
      const Radius.circular(6),
    );
    _targetButtonRect = targetRect;

    // Button background with pulse when hovered
    final pulse = 0.5 + 0.5 * math.sin(_pulseTimer * 3);
    canvas.drawRRect(
      targetRect,
      Paint()..color = const Color(0xFF8B5CF6).withOpacity(0.15 + pulse * 0.05),
    );
    canvas.drawRRect(
      targetRect,
      Paint()
        ..color = const Color(0xFF8B5CF6).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _drawText(
      canvas,
      '⎯  Target: $targetLabel  ⎯',
      leftPad + 30,
      y + 5,
      size: 11,
      weight: FontWeight.w600,
      color: const Color(0xFF8B5CF6),
    );

    canvas.restore();

    // Update size for hit testing
    size = Vector2(panelWidth, panelHeight);
  }

  void _drawText(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double size = 12,
    FontWeight weight = FontWeight.normal,
    Color color = Colors.white,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  Color _getFamilyColor(String family) {
    switch (family.toLowerCase()) {
      case 'let':
        return const Color(0xFF3B82F6);
      case 'pip':
        return const Color(0xFFF59E0B);
      case 'mane':
        return const Color(0xFFEF4444);
      case 'mask':
        return const Color(0xFF8B5CF6);
      case 'horn':
        return const Color(0xFF10B981);
      case 'wing':
        return const Color(0xFF06B6D4);
      case 'kin':
        return const Color(0xFFEC4899);
      case 'mystic':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getElementColor(String element) {
    switch (element.toLowerCase()) {
      case 'fire':
        return const Color(0xFFFF6B35);
      case 'water':
        return const Color(0xFF3B82F6);
      case 'earth':
        return const Color(0xFF92400E);
      case 'air':
        return const Color(0xFF67E8F9);
      case 'lightning':
        return const Color(0xFFFDE047);
      case 'plant':
        return const Color(0xFF4ADE80);
      case 'poison':
        return const Color(0xFFA855F7);
      case 'dark':
        return const Color(0xFF581C87);
      case 'light':
        return const Color(0xFFFEF3C7);
      case 'ice':
        return const Color(0xFF7DD3FC);
      case 'spirit':
        return const Color(0xFF818CF8);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  bool containsPoint(Vector2 point) {
    if (_slideProgress < 0.5) return false;

    final local = parentToLocal(point);
    // Panel is drawn from 0,0 to the right
    return local.x >= 0 && local.x <= 220 && local.y >= 0 && local.y <= 195;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);

    final guardian = gameRef.selectedGuardianNotifier.value;
    if (guardian == null) return;

    final local = event.localPosition;
    final pos = Offset(local.x, local.y);

    // Check close button
    if (_closeButtonRect != null && _closeButtonRect!.contains(pos)) {
      gameRef.selectGuardian(null);
      return;
    }

    // Check target button
    if (_targetButtonRect != null && _targetButtonRect!.contains(pos)) {
      guardian.cycleTargetPriority();
      return;
    }
  }
}
