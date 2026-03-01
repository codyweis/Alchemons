// lib/games/survival/survival_hud.dart
import 'dart:math' as math;
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class SurvivalHud extends PositionComponent
    with HasGameRef<SurvivalHoardGame>, TapCallbacks {
  SurvivalHud() : super(priority: 100);

  // Collapse state
  bool _isCollapsed = false;
  bool get isCollapsed => _isCollapsed;

  // Animation
  double _collapseProgress = 0.0; // 0 = expanded, 1 = collapsed
  static const double _collapseSpeed = 5.0;

  // Panel paints
  late Paint _bgPaint;
  late Paint _borderPaint;
  late Paint _accentBorderPaint;

  // HP bar paints
  late Paint _hpBgPaint;
  late Paint _hpGoodPaint;
  late Paint _hpMidPaint;
  late Paint _hpLowPaint;

  // Orb paints
  late Paint _orbBgPaint;
  late Paint _orbFillGoodPaint;
  late Paint _orbFillMidPaint;
  late Paint _orbFillLowPaint;
  late Paint _orbGlowPaint;
  late Paint _orbBorderPaint;

  // Transmutation progress paints
  late Paint _transmuteBgPaint;
  late Paint _transmuteGlowPaint;

  // Text paints
  late TextPaint _orbHpPaint;
  late TextPaint _smallLabelPaint;

  // Layout constants
  static const double _padding = 12.0;
  static const double _orbSectionHeight = 48.0;
  static const double _dividerHeight = 12.0;
  static const double _guardianRowHeight = 28.0;
  static const double _columnSpacing = 10.0;
  static const double _transmuteBarWidth = 6.0;

  // Collapsed dimensions
  static const double _collapsedWidth = 140.0;
  static const double _collapsedHeight = 56.0;

  // Expanded dimensions (calculated)
  double _expandedWidth = 280.0;
  double _expandedHeight = 120.0;

  // Toggle button area
  Rect _toggleButtonRect = Rect.zero;

  // Guardian tap areas - map of Rect to guardian index
  final List<_GuardianTapArea> _guardianTapAreas = [];

  @override
  Future<void> onLoad() async {
    _initPaints();
    _calculateExpandedSize();
    _updateSize();
  }

  void _initPaints() {
    // Panel
    _bgPaint = Paint()
      ..color = const Color(0xE6101018)
      ..style = PaintingStyle.fill;

    _borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    _accentBorderPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // HP bars
    _hpBgPaint = Paint()..color = Colors.white.withValues(alpha: 0.1);
    _hpGoodPaint = Paint()..color = const Color(0xFF10B981);
    _hpMidPaint = Paint()..color = const Color(0xFFF59E0B);
    _hpLowPaint = Paint()..color = const Color(0xFFEF4444);

    // Orb health
    _orbBgPaint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    _orbFillGoodPaint = Paint()..color = const Color(0xFF10B981);
    _orbFillMidPaint = Paint()..color = const Color(0xFFF59E0B);
    _orbFillLowPaint = Paint()..color = const Color(0xFFEF4444);
    _orbGlowPaint = Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.3);
    _orbBorderPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Transmutation progress
    _transmuteBgPaint = Paint()..color = Colors.white.withValues(alpha: 0.1);
    _transmuteGlowPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.5);

    // Text paints
    _orbHpPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFFFD700),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        fontFamily: 'monospace',
      ),
    );

    _smallLabelPaint = TextPaint(
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 7,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        fontFamily: 'monospace',
      ),
    );
  }

  void _calculateExpandedSize() {
    final guardians = gameRef.guardians;
    final rows = (guardians.length / 2).ceil().clamp(1, 4);

    _expandedHeight =
        _padding * 2 +
        _orbSectionHeight +
        _dividerHeight +
        rows * _guardianRowHeight +
        8;
    _expandedWidth = 280.0;
  }

  void _updateSize() {
    // Lerp between collapsed and expanded size

    final currentWidth = lerpDouble(
      _expandedWidth,
      _collapsedWidth,
      _collapseProgress,
    )!;
    final currentHeight = lerpDouble(
      _expandedHeight,
      _collapsedHeight,
      _collapseProgress,
    )!;

    size = Vector2(currentWidth, currentHeight);
    anchor = Anchor.bottomLeft;

    // Update toggle button rect (top-right corner)
    _toggleButtonRect = Rect.fromLTWH(size.x - 24, 4, 20, 20);
  }

  double? lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }

  void toggle() {
    _isCollapsed = !_isCollapsed;
  }

  @override
  void onTapUp(TapUpEvent event) {
    final localPoint = event.localPosition;
    final offset = Offset(localPoint.x, localPoint.y);

    // Check if tap is on toggle button
    if (_toggleButtonRect.contains(offset)) {
      toggle();
      return;
    }

    // Check if tap is on a guardian (only when expanded)
    if (!_isCollapsed && _collapseProgress < 0.1) {
      for (final tapArea in _guardianTapAreas) {
        if (tapArea.rect.contains(offset)) {
          // Select this guardian
          final guardians = gameRef.guardians;
          if (tapArea.index < guardians.length) {
            final guardian = guardians[tapArea.index];
            // Toggle selection - if already selected, deselect
            if (gameRef.selectedGuardianNotifier.value == guardian) {
              gameRef.selectGuardian(null);
            } else {
              gameRef.selectGuardian(guardian);
            }
          }
          return;
        }
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return size.toRect().contains(point.toOffset());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    position = Vector2(10, size.y - 10);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Animate collapse/expand
    final targetProgress = _isCollapsed ? 1.0 : 0.0;
    if (_collapseProgress != targetProgress) {
      final diff = targetProgress - _collapseProgress;
      final step = _collapseSpeed * dt;

      if (diff.abs() < step) {
        _collapseProgress = targetProgress;
      } else {
        _collapseProgress += diff.sign * step;
      }
      _collapseProgress = _collapseProgress.clamp(0.0, 1.0);
    }

    // Update size based on animation
    _calculateExpandedSize();
    _updateSize();
  }

  @override
  void render(Canvas canvas) {
    final stats = gameRef.statsNotifier.value;

    // Main panel background
    _drawPanel(canvas);

    // Toggle button (always visible)
    _drawToggleButton(canvas);

    if (_collapseProgress > 0.9) {
      // Fully collapsed - minimal view
      _drawCollapsedView(canvas);
    } else if (_collapseProgress < 0.1) {
      // Fully expanded - full view
      _drawExpandedView(canvas, stats);
    } else {
      // Transitioning - show collapsed view with fade
      _drawCollapsedView(canvas);

      // Fade in expanded content
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: 1 - _collapseProgress),
      );
      _drawExpandedView(canvas, stats);
      canvas.restore();
    }
  }

  void _drawCollapsedView(Canvas canvas) {
    final orb = gameRef.orb;
    final currentHp = orb.currentHp;
    final maxHp = orb.maxHp;
    final orbRatio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

    final killsNeeded = gameRef.killsRequiredForNextLevel;
    final killsCurrent = gameRef.killsSinceLastChoice;
    final transmuteRatio = killsNeeded > 0
        ? (killsCurrent / killsNeeded).clamp(0.0, 1.0)
        : 0.0;

    // Compact orb display
    final orbCenterX = _padding + 16.0;
    final orbCenterY = size.y / 2;
    final orbRadius = 14.0;

    // Orb glow
    canvas.drawCircle(
      Offset(orbCenterX, orbCenterY),
      orbRadius + 3,
      _orbGlowPaint,
    );

    // Orb background
    canvas.drawCircle(Offset(orbCenterX, orbCenterY), orbRadius, _orbBgPaint);

    // Orb fill
    if (orbRatio > 0) {
      canvas.save();
      final clipPath = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(orbCenterX, orbCenterY),
            radius: orbRadius,
          ),
        );
      canvas.clipPath(clipPath);

      final fillHeight = orbRadius * 2 * orbRatio;
      final fillTop = orbCenterY + orbRadius - fillHeight;

      Paint fillPaint = orbRatio > 0.6
          ? _orbFillGoodPaint
          : orbRatio > 0.3
          ? _orbFillMidPaint
          : _orbFillLowPaint;

      canvas.drawRect(
        Rect.fromLTWH(
          orbCenterX - orbRadius,
          fillTop,
          orbRadius * 2,
          fillHeight,
        ),
        fillPaint,
      );
      canvas.restore();
    }

    // Orb border
    canvas.drawCircle(
      Offset(orbCenterX, orbCenterY),
      orbRadius,
      _orbBorderPaint,
    );

    // HP text next to orb
    final hpText = '$currentHp';
    _orbHpPaint.render(
      canvas,
      hpText,
      Vector2(orbCenterX + orbRadius + 8, orbCenterY - 6),
    );

    // Small max HP
    final maxText = '/ $maxHp';
    _smallLabelPaint.render(
      canvas,
      maxText,
      Vector2(orbCenterX + orbRadius + 8, orbCenterY + 6),
    );

    // Transmutation bar (compact, horizontal)
    final barX = orbCenterX + orbRadius + 50;
    final barY = orbCenterY - 8;
    final barWidth = size.x - barX - 30;
    final barHeight = 16.0;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barWidth, barHeight),
        const Radius.circular(4),
      ),
      _transmuteBgPaint,
    );

    // Fill
    if (transmuteRatio > 0) {
      final gradientPaint = Paint()
        ..shader =
            const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
            ).createShader(
              Rect.fromLTWH(barX, barY, barWidth * transmuteRatio, barHeight),
            );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barWidth * transmuteRatio, barHeight),
          const Radius.circular(4),
        ),
        gradientPaint,
      );

      // Glow when nearly full
      if (transmuteRatio > 0.8) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barWidth * transmuteRatio, barHeight),
            const Radius.circular(4),
          ),
          _transmuteGlowPaint,
        );
      }
    }

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barWidth, barHeight),
        const Radius.circular(4),
      ),
      Paint()
        ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Ready indicator
    if (transmuteRatio >= 1.0) {
      canvas.drawCircle(
        Offset(barX + barWidth + 8, barY + barHeight / 2),
        6,
        Paint()..color = const Color(0xFFD946EF),
      );
      canvas.drawCircle(
        Offset(barX + barWidth + 8, barY + barHeight / 2),
        5,
        Paint()..color = const Color(0xFFD946EF),
      );
    }
  }

  void _drawExpandedView(Canvas canvas, SurvivalGameStats stats) {
    // Orb health section
    _drawOrbSection(canvas);

    // Divider
    _drawDivider(canvas, _padding + _orbSectionHeight);

    // Guardian rows
    _drawGuardianSection(canvas);

    // Transmutation progress (right edge)
    _drawTransmutationProgress(canvas);

    // Wave & time in top right
    _drawWaveTime(canvas, stats);
  }

  void _drawToggleButton(Canvas canvas) {
    // Button background
    canvas.drawRRect(
      RRect.fromRectAndRadius(_toggleButtonRect, const Radius.circular(4)),
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );

    // Arrow icon
    final centerX = _toggleButtonRect.center.dx;
    final centerY = _toggleButtonRect.center.dy;

    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (_isCollapsed) {
      // Down arrow (expand)
      canvas.drawLine(
        Offset(centerX - 4, centerY - 2),
        Offset(centerX, centerY + 2),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(centerX, centerY + 2),
        Offset(centerX + 4, centerY - 2),
        arrowPaint,
      );
    } else {
      // Up arrow (collapse)
      canvas.drawLine(
        Offset(centerX - 4, centerY + 2),
        Offset(centerX, centerY - 2),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(centerX, centerY - 2),
        Offset(centerX + 4, centerY + 2),
        arrowPaint,
      );
    }
  }

  void _drawPanel(Canvas canvas) {
    final r = size.toRect();
    final bgRrect = RRect.fromRectAndRadius(r, const Radius.circular(12));

    // Background
    canvas.drawRRect(bgRrect, _bgPaint);

    // Border
    canvas.drawRRect(bgRrect, _borderPaint);

    // Accent glow on left edge
    final accentRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 8, 3, size.y - 16),
      topLeft: const Radius.circular(2),
      bottomLeft: const Radius.circular(2),
    );
    canvas.drawRRect(accentRect, _accentBorderPaint);
  }

  void _drawOrbSection(Canvas canvas) {
    final orb = gameRef.orb;
    final currentHp = orb.currentHp;
    final maxHp = orb.maxHp;
    final ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

    // Section starts at top padding
    final sectionY = _padding;
    final sectionHeight = _orbSectionHeight;

    // Orb icon area (left side)
    final orbCenterX = _padding + 20.0;
    final orbCenterY = sectionY + sectionHeight / 2;
    final orbRadius = 16.0;

    // Draw orb glow
    canvas.drawCircle(
      Offset(orbCenterX, orbCenterY),
      orbRadius + 4,
      _orbGlowPaint,
    );

    // Draw orb background
    canvas.drawCircle(Offset(orbCenterX, orbCenterY), orbRadius, _orbBgPaint);

    // Draw orb fill (from bottom up)
    if (ratio > 0) {
      canvas.save();
      final clipPath = Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(orbCenterX, orbCenterY),
            radius: orbRadius,
          ),
        );
      canvas.clipPath(clipPath);

      final fillHeight = orbRadius * 2 * ratio;
      final fillTop = orbCenterY + orbRadius - fillHeight;

      Paint fillPaint;
      if (ratio > 0.6) {
        fillPaint = _orbFillGoodPaint;
      } else if (ratio > 0.3) {
        fillPaint = _orbFillMidPaint;
      } else {
        fillPaint = _orbFillLowPaint;
      }

      canvas.drawRect(
        Rect.fromLTWH(
          orbCenterX - orbRadius,
          fillTop,
          orbRadius * 2,
          fillHeight,
        ),
        fillPaint,
      );
      canvas.restore();
    }

    // Draw orb border
    canvas.drawCircle(
      Offset(orbCenterX, orbCenterY),
      orbRadius,
      _orbBorderPaint,
    );

    // Draw inner shine
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(orbCenterX - 2, orbCenterY - 2),
        radius: orbRadius - 4,
      ),
      -math.pi * 0.8,
      math.pi * 0.5,
      false,
      shinePaint,
    );

    // Text area (right of orb)
    final textX = orbCenterX + orbRadius + 12;

    // "ALCHEMY ORB" label
    _smallLabelPaint.render(
      canvas,
      'ALCHEMY ORB',
      Vector2(textX, sectionY + 4),
    );

    // HP value
    final hpText = '$currentHp / $maxHp';
    _orbHpPaint.render(canvas, hpText, Vector2(textX, sectionY + 14));

    // HP bar
    final barX = textX;
    final barY = sectionY + 30;
    final barWidth = size.x - barX - _padding - _transmuteBarWidth - 8;
    final barHeight = 8.0;

    // Bar background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barWidth, barHeight),
        const Radius.circular(4),
      ),
      _orbBgPaint,
    );

    // Bar fill
    if (ratio > 0) {
      Paint barFillPaint;
      if (ratio > 0.6) {
        barFillPaint = _orbFillGoodPaint;
      } else if (ratio > 0.3) {
        barFillPaint = _orbFillMidPaint;
      } else {
        barFillPaint = _orbFillLowPaint;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barWidth * ratio, barHeight),
          const Radius.circular(4),
        ),
        barFillPaint,
      );
    }

    // Bar border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barWidth, barHeight),
        const Radius.circular(4),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawDivider(Canvas canvas, double y) {
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(_padding, y + _dividerHeight / 2),
      Offset(
        size.x - _padding - _transmuteBarWidth - 4,
        y + _dividerHeight / 2,
      ),
      dividerPaint,
    );
  }

  void _drawGuardianSection(Canvas canvas) {
    final guardians = gameRef.guardians;
    if (guardians.isEmpty) return;

    // Clear old tap areas and rebuild
    _guardianTapAreas.clear();

    final sectionY = _padding + _orbSectionHeight + _dividerHeight;
    final availableWidth =
        size.x - _padding * 2 - _transmuteBarWidth - 8 - _columnSpacing;
    final columnWidth = availableWidth / 2;

    for (int i = 0; i < guardians.length && i < 8; i++) {
      final g = guardians[i];
      final col = i % 2;
      final row = i ~/ 2;

      final x = _padding + col * (columnWidth + _columnSpacing);
      final y = sectionY + row * _guardianRowHeight;

      // Store tap area for this guardian
      _guardianTapAreas.add(
        _GuardianTapArea(
          rect: Rect.fromLTWH(
            x - 2,
            y - 2,
            columnWidth + 4,
            _guardianRowHeight,
          ),
          index: i,
        ),
      );

      _drawGuardianBar(
        canvas: canvas,
        name: g.unit.name,
        family: g.unit.family,
        currentHp: g.unit.currentHp,
        maxHp: g.unit.maxHp,
        level: g.unit.level,
        isDead: g.unit.isDead,
        isSelected: gameRef.selectedGuardianNotifier.value == g,
        transmuteRank: gameRef.getTransmuteRank(g.unit.id),
        specialRank: gameRef.getSpecialRankForUnit(g.unit),
        x: x,
        y: y,
        width: columnWidth,
      );
    }
  }

  void _drawGuardianBar({
    required Canvas canvas,
    required String name,
    required String family,
    required int currentHp,
    required int maxHp,
    required int level,
    required bool isDead,
    required bool isSelected,
    required int transmuteRank,
    required int specialRank,
    required double x,
    required double y,
    required double width,
  }) {
    final ratio = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final familyColor = _getFamilyColor(family);

    // Selection highlight
    if (isSelected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, y - 1, width + 4, _guardianRowHeight - 2),
          const Radius.circular(4),
        ),
        Paint()..color = familyColor.withValues(alpha: 0.15),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, y - 1, width + 4, _guardianRowHeight - 2),
          const Radius.circular(4),
        ),
        Paint()
          ..color = familyColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Family indicator dot
    canvas.drawCircle(
      Offset(x + 5, y + 6),
      4,
      Paint()..color = isDead ? Colors.grey : familyColor,
    );

    // Name + Level
    final displayName = name.length > 8 ? '${name.substring(0, 7)}…' : name;
    final nameText = isDead ? '$displayName ✗' : '$displayName L$level';

    final namePaint = TextPaint(
      style: TextStyle(
        color: isDead ? Colors.grey : Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w600,
        fontFamily: 'monospace',
      ),
    );
    namePaint.render(canvas, nameText, Vector2(x + 12, y + 2));

    // HP bar
    const barHeight = 5.0;
    final barY = y + 14;
    final barWidth = width - 36; // Leave room for pips

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, barY, barWidth, barHeight),
        const Radius.circular(2),
      ),
      _hpBgPaint,
    );

    // Fill
    if (!isDead && ratio > 0) {
      Paint fillPaint;
      if (ratio > 0.5) {
        fillPaint = _hpGoodPaint;
      } else if (ratio > 0.25) {
        fillPaint = _hpMidPaint;
      } else {
        fillPaint = _hpLowPaint;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, barY, barWidth * ratio, barHeight),
          const Radius.circular(2),
        ),
        fillPaint,
      );
    }

    // Upgrade pips (right side)
    final pipsX = x + barWidth + 4;
    final pipsY = barY;

    // Transmute pips (purple)
    for (int i = 0; i < 3; i++) {
      final filled = i < transmuteRank;
      canvas.drawCircle(
        Offset(pipsX + i * 6, pipsY + 2),
        2,
        Paint()
          ..color = filled
              ? const Color(0xFF8B5CF6)
              : Colors.white.withValues(alpha: 0.2),
      );
    }

    // Special pips (gold) - below transmute
    for (int i = 0; i < 3; i++) {
      final filled = i < specialRank;
      canvas.drawCircle(
        Offset(pipsX + i * 6, pipsY + 8),
        2,
        Paint()
          ..color = filled
              ? const Color(0xFFFFD700)
              : Colors.white.withValues(alpha: 0.2),
      );
    }
  }

  void _drawTransmutationProgress(Canvas canvas) {
    final killsNeeded = gameRef.killsRequiredForNextLevel;
    final killsCurrent = gameRef.killsSinceLastChoice;
    final ratio = killsNeeded > 0
        ? (killsCurrent / killsNeeded).clamp(0.0, 1.0)
        : 0.0;

    final barX = size.x - _transmuteBarWidth - 4;
    final barY = _padding + 20;
    final barHeight = size.y - barY - _padding - 8;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, _transmuteBarWidth, barHeight),
        const Radius.circular(3),
      ),
      _transmuteBgPaint,
    );

    // Fill (from bottom up)
    if (ratio > 0) {
      final fillHeight = barHeight * ratio;
      final fillY = barY + barHeight - fillHeight;

      // Glow effect
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX - 2, fillY, _transmuteBarWidth + 4, fillHeight),
          const Radius.circular(4),
        ),
        _transmuteGlowPaint,
      );

      // Fill gradient
      final gradientPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: const [Color(0xFF8B5CF6), Color(0xFFD946EF)],
            ).createShader(
              Rect.fromLTWH(barX, fillY, _transmuteBarWidth, fillHeight),
            );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, fillY, _transmuteBarWidth, fillHeight),
          const Radius.circular(3),
        ),
        gradientPaint,
      );
    }

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, _transmuteBarWidth, barHeight),
        const Radius.circular(3),
      ),
      Paint()
        ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Ready indicator at top
    if (ratio >= 1.0) {
      canvas.drawCircle(
        Offset(barX + _transmuteBarWidth / 2, barY - 6),
        5,
        Paint()..color = const Color(0xFFD946EF),
      );
      canvas.drawCircle(
        Offset(barX + _transmuteBarWidth / 2, barY - 6),
        4,
        Paint()..color = const Color(0xFFD946EF),
      );
    }

    // Label at bottom
    canvas.save();
    canvas.translate(barX + _transmuteBarWidth / 2, barY + barHeight + 2);
    canvas.rotate(-math.pi / 2);

    // Note: rotated text would need different positioning
    canvas.restore();
  }

  void _drawWaveTime(Canvas canvas, SurvivalGameStats stats) {
    // Wave badge (top area, but avoiding orb section overlap)
    final waveText = 'W${stats.wave}';

    final textX = size.x - _padding - _transmuteBarWidth - 8;

    // Small wave indicator
    final wavePaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFF8B5CF6),
        fontSize: 8,
        fontWeight: FontWeight.w800,
        fontFamily: 'monospace',
      ),
    );
    wavePaint.render(
      canvas,
      waveText,
      Vector2(textX - waveText.length * 5, _padding + 2),
      anchor: Anchor.topRight,
    );
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
}

/// Helper class to track guardian tap areas
class _GuardianTapArea {
  final Rect rect;
  final int index;

  const _GuardianTapArea({required this.rect, required this.index});
}
