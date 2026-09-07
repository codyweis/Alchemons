import 'dart:math';
import 'package:flutter/material.dart';
import 'survival_outbreak.dart';

final Path _sourceArrow = Path()
  ..moveTo(8, 0)
  ..lineTo(-6, -5)
  ..lineTo(-3, 0)
  ..lineTo(-6, 5)
  ..close();

/// Bounded arena geometry: at most three fields and three links, no particles.
void drawSurvivalOutbreak(
  Canvas canvas,
  SurvivalOutbreak event,
  Offset orb, {
  Rect? viewport,
}) {
  if (event.cleared) return;
  final color = event.color;
  final fill = Paint()
    ..color = color.withValues(alpha: event.surging ? 0.12 : 0.035);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = event.warning ? 2.5 : 1.2
    ..color = color.withValues(alpha: event.warning ? 0.85 : 0.35);
  for (final core in event.cores) {
    if (core.isDead) continue;
    final hasField = switch (event.kind) {
      SurvivalOutbreakKind.nigredo ||
      SurvivalOutbreakKind.mirror ||
      SurvivalOutbreakKind.cinder ||
      SurvivalOutbreakKind.voltaic => false,
      _ => true,
    };
    final radius = hasField ? event.fieldRadius : core.radius * 2.3;
    canvas.drawCircle(core.position, radius, fill);
    canvas.drawCircle(core.position, radius, stroke);
    if (event.warning) {
      canvas.drawArc(
        Rect.fromCircle(center: core.position, radius: radius),
        -pi / 2,
        2 * pi * event.warningProgress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = color,
      );
    }
    if (event.surging) {
      canvas.drawCircle(
        core.position,
        radius * (0.3 + 0.7 * event.cycle / 1.5),
        stroke,
      );
    }
    canvas.save();
    canvas.translate(core.position.dx, core.position.dy);
    final glyphRadius = core.radius * 1.65;
    // Shape supplements element tint, so the sources do not rely on color alone.
    switch (event.kind) {
      case SurvivalOutbreakKind.verdigris:
        for (var i = 0; i < 3; i++) {
          final a = i * 2 * pi / 3;
          canvas.drawCircle(Offset(cos(a), sin(a)) * glyphRadius, 8, stroke);
        }
      case SurvivalOutbreakKind.sanguine:
        canvas.drawLine(
          Offset(-glyphRadius, 0),
          Offset(glyphRadius, 0),
          stroke,
        );
        canvas.drawLine(
          Offset(0, -glyphRadius),
          Offset(0, glyphRadius),
          stroke,
        );
      case SurvivalOutbreakKind.quicksilver:
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset.zero, radius: glyphRadius + i * 9),
            event.elapsed * 0.5 + i,
            pi * 0.8,
            false,
            stroke,
          );
        }
      case SurvivalOutbreakKind.nigredo:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: glyphRadius * 2,
            height: glyphRadius,
          ),
          stroke,
        );
      case SurvivalOutbreakKind.crystal:
        canvas.save();
        canvas.rotate(pi / 4);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: glyphRadius * 1.6,
            height: glyphRadius * 1.6,
          ),
          stroke,
        );
        canvas.restore();
      case SurvivalOutbreakKind.cinder:
        for (var i = 0; i < 3; i++) {
          final a = i * 2 * pi / 3 + event.elapsed * 0.12;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(cos(a), sin(a)) * glyphRadius,
              width: 12,
              height: 20,
            ),
            stroke,
          );
        }
      case SurvivalOutbreakKind.frost:
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3;
          canvas.drawLine(
            Offset(cos(a), sin(a)) * glyphRadius,
            Offset(cos(a), sin(a)) * (glyphRadius + 18),
            stroke,
          );
        }
      case SurvivalOutbreakKind.voltaic:
        canvas.drawLine(Offset(-glyphRadius, -12), const Offset(0, 12), stroke);
        canvas.drawLine(const Offset(0, 12), Offset(glyphRadius, -12), stroke);
      case SurvivalOutbreakKind.calcified:
        for (var i = 0; i < 4; i++) {
          canvas.drawArc(
            Rect.fromCircle(
              center: Offset.zero,
              radius: glyphRadius + (event.surging ? 12 : 0),
            ),
            i * pi / 2,
            pi * 0.38,
            false,
            stroke..strokeWidth = 5,
          );
        }
        stroke.strokeWidth = 1.2;
      case SurvivalOutbreakKind.mirror:
        canvas.drawCircle(Offset(-glyphRadius, 0), 11, stroke);
        canvas.drawCircle(Offset(glyphRadius, 0), 11, stroke);
    }
    canvas.restore();
    if (event.kind == SurvivalOutbreakKind.nigredo) {
      canvas.drawLine(core.position, orb, stroke);
    }
    if (viewport != null && !viewport.deflate(24).contains(core.position)) {
      final safe = viewport.deflate(24);
      final edge = Offset(
        core.position.dx.clamp(safe.left, safe.right),
        core.position.dy.clamp(safe.top, safe.bottom),
      );
      canvas.save();
      canvas.translate(edge.dx, edge.dy);
      canvas.rotate(
        atan2(core.position.dy - edge.dy, core.position.dx - edge.dx),
      );
      canvas.drawPath(_sourceArrow, Paint()..color = color);
      canvas.restore();
    }
  }
  for (final (a, b) in event.links) {
    canvas.drawLine(
      a,
      b,
      stroke..strokeWidth = event.surging ? 5 : (event.warning ? 3 : 1),
    );
  }
}
