import 'dart:ui';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GuardianInspectHud extends PositionComponent
    with HasGameRef<SurvivalHoardGame> {
  GuardianInspectHud()
    : super(position: Vector2.zero(), anchor: Anchor.topCenter);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Place near bottom-center of the screen
    final vs = gameRef.cameraComponent.viewport;
    position = Vector2(vs.size.x / 2, vs.size.y - 80);

    // Reposition on viewport resize if needed
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final guardian = gameRef.selectedGuardianNotifier.value;
    if (guardian == null) return;

    final unit = guardian.unit;
    final transmuteRank = gameRef.getTransmuteRank(unit.id);
    final specialRank = gameRef.getSpecialRankForUnit(unit);
    final element = unit.types.firstOrNull ?? 'Normal';

    final textPainter =
        (String text, double size, {FontWeight weight = FontWeight.normal}) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: weight,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          return tp;
        };

    final nameTp = textPainter(
      '${unit.name} [${unit.family}]',
      14,
      weight: FontWeight.bold,
    );
    final rankTp = textPainter(
      'Transmute: $transmuteRank   Special: $specialRank',
      12,
    );
    final rangeTp = textPainter(
      'Range: ${unit.attackRange.toInt()}  •  ${element} Nova',
      11,
    );

    final width =
        [
          nameTp.width,
          rankTp.width,
          rangeTp.width,
        ].reduce((a, b) => a > b ? a : b) +
        24;

    const height = 60.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      const Radius.circular(12),
    );

    // Background
    final bgPaint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.save();
    canvas.translate(0, 0); // already centered by anchor
    canvas.drawRRect(rect, bgPaint);

    double y = -height / 2 + 10;

    nameTp.paint(canvas, Offset(-width / 2 + 12, y));
    y += nameTp.height + 2;
    rankTp.paint(canvas, Offset(-width / 2 + 12, y));
    y += rankTp.height + 2;
    rangeTp.paint(canvas, Offset(-width / 2 + 12, y));

    canvas.restore();
  }
}
