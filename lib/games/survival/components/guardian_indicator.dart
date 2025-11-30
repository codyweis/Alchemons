// lib/games/survival/components/guardian_details.dart (Corrected)
import 'dart:ui';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GuardianRangeIndicator extends PositionComponent
    with HasGameRef<SurvivalHoardGame> {
  final HoardGuardian guardian;

  GuardianRangeIndicator({required this.guardian})
    : super(
        // Put this component's origin at the guardian's center
        position: guardian.size / 2,
        anchor: Anchor.center,
      );

  @override
  void update(double dt) {
    super.update(dt);

    // No more "force to zero" – that was anchoring it at top-left
    if (gameRef.selectedGuardianNotifier.value != guardian) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final unit = guardian.unit;
    final attackRange = unit.attackRange;
    final specialRange = unit.specialAbilityRange;

    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final specialPaint = Paint()
      ..color = Colors.tealAccent.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Now Offset.zero maps to guardian's center
    canvas.drawCircle(Offset.zero, attackRange, basePaint);
    canvas.drawCircle(Offset.zero, specialRange, specialPaint);

    // Optional debug dot:
    // canvas.drawCircle(Offset.zero, 2, Paint()..color = Colors.red);
  }
}
