import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';

bool drawPipElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  final element = projectile.element;
  if (element == null || projectile.visualStyle != ProjectileVisualStyle.dart) {
    return false;
  }
  final hasPipTempoSignals =
      projectile.homing ||
      projectile.bounceCount > 0 ||
      projectile.snareRadius > 0 ||
      projectile.interceptCharges > 0;
  if (!hasPipTempoSignals) return false;

  final vs = projectile.visualScale.clamp(0.72, 2.3).toDouble();
  final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
  final perp = ui.Offset(-dir.dy, dir.dx);
  final tailLen = (projectile.bounceCount > 0 ? 18.0 : 13.0) * vs;
  final tail = position - dir * tailLen;
  final pulse = 0.72 + 0.28 * sin(time * 7.0 + projectile.life * 2.0);
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.45)!;
  final fillPaint = ui.Paint();
  final strokePaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  final linePaint = ui.Paint()..strokeCap = ui.StrokeCap.round;

  void drawTail({double width = 3.2, double alpha = 0.26}) {
    linePaint
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = width * vs
      ..maskFilter = null;
    canvas.drawLine(tail, position, linePaint);
  }

  void drawDartHead({double length = 6.0, double width = 4.0}) {
    final tip = position + dir * length * 0.55 * vs;
    final back = position - dir * length * 0.45 * vs;
    final path = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + perp.dx * width * vs, back.dy + perp.dy * width * vs)
      ..lineTo(back.dx - perp.dx * width * vs, back.dy - perp.dy * width * vs)
      ..close();
    fillPaint.color = color.withValues(alpha: 0.92);
    canvas.drawPath(path, fillPaint);
    fillPaint.color = white.withValues(alpha: 0.82);
    canvas.drawCircle(tip, 1.3 * vs, fillPaint);
  }

  switch (element) {
    case 'Fire':
      drawTail(width: 5.0, alpha: 0.34);
      for (var i = 0; i < 2; i++) {
        final offset = (i == 0 ? -1.0 : 1.0) * 3.0 * vs;
        fillPaint.color = const ui.Color(0xFFFFD28A).withValues(alpha: 0.62);
        canvas.drawCircle(
          tail + perp * offset + dir * (i * 3.0 * vs),
          1.8 * vs,
          fillPaint,
        );
      }
      drawDartHead(length: 6.6, width: 3.4);
      break;
    case 'Lightning':
      final bolt = ui.Path()
        ..moveTo(tail.dx, tail.dy)
        ..lineTo(
          position.dx - dir.dx * 8 * vs + perp.dx * 3.5 * vs,
          position.dy - dir.dy * 8 * vs + perp.dy * 3.5 * vs,
        )
        ..lineTo(
          position.dx - dir.dx * 3 * vs - perp.dx * 3.0 * vs,
          position.dy - dir.dy * 3 * vs - perp.dy * 3.0 * vs,
        )
        ..lineTo(position.dx, position.dy);
      canvas.drawPath(
        bolt,
        strokePaint
          ..color = white.withValues(alpha: 0.92)
          ..strokeWidth = 1.8 * vs
          ..maskFilter = null,
      );
      drawDartHead(length: 5.2, width: 3.2);
      break;
    case 'Water':
      for (final side in [-1.0, 1.0]) {
        final path = ui.Path()
          ..moveTo(
            tail.dx + perp.dx * side * 2.4 * vs,
            tail.dy + perp.dy * side * 2.4 * vs,
          )
          ..quadraticBezierTo(
            position.dx - dir.dx * 5 * vs + perp.dx * side * 5 * vs,
            position.dy - dir.dy * 5 * vs + perp.dy * side * 5 * vs,
            position.dx,
            position.dy,
          );
        canvas.drawPath(
          path,
          strokePaint
            ..color = color.withValues(alpha: 0.38)
            ..strokeWidth = 1.4 * vs
            ..maskFilter = null,
        );
      }
      drawDartHead(length: 5.8, width: 3.4);
      break;
    case 'Ice':
      drawTail(width: 3.8, alpha: 0.22);
      _drawFrostStar(canvas, position, white, 5.5 * vs, vs, time);
      drawDartHead(length: 7.0, width: 3.0);
      break;
    case 'Steam':
      for (var i = 0; i < 3; i++) {
        final drift = i.toDouble();
        canvas.drawCircle(
          tail +
              dir * drift * 4.0 * vs +
              perp * sin(time * 3 + drift) * 2.5 * vs,
          (2.8 + drift * 0.6) * vs,
          ui.Paint()
            ..color = color.withValues(alpha: 0.14)
            ..maskFilter = null,
        );
      }
      drawDartHead(length: 5.4, width: 3.2);
      break;
    case 'Earth':
      drawTail(width: 3.0, alpha: 0.18);
      canvas.drawCircle(
        position,
        4.8 * vs,
        fillPaint..color = color.withValues(alpha: 0.82),
      );
      for (var i = 0; i < 3; i++) {
        final a = time * 0.2 + i * pi * 2 / 3;
        linePaint
          ..color = white.withValues(alpha: 0.30)
          ..strokeWidth = 0.8 * vs
          ..maskFilter = null;
        canvas.drawLine(
          position,
          position + ui.Offset(cos(a), sin(a)) * 5.2 * vs,
          linePaint,
        );
      }
      break;
    case 'Lava':
      drawTail(width: 5.6, alpha: 0.30);
      canvas.drawCircle(
        position,
        5.4 * vs,
        fillPaint..color = color.withValues(alpha: 0.90),
      );
      canvas.drawCircle(
        position + dir * 1.6 * vs - perp * 1.2 * vs,
        1.8 * vs,
        fillPaint..color = const ui.Color(0xFFFFE0A0).withValues(alpha: 0.78),
      );
      break;
    case 'Mud':
      drawTail(width: 4.8, alpha: 0.24);
      canvas.drawOval(
        ui.Rect.fromCenter(center: position, width: 9.0 * vs, height: 6.0 * vs),
        fillPaint..color = color.withValues(alpha: 0.86),
      );
      break;
    case 'Dust':
      drawTail(width: 2.4, alpha: 0.18);
      for (var i = 0; i < 5; i++) {
        final a = time * 1.7 + i * pi * 2 / 5;
        canvas.drawCircle(
          position - dir * 4.0 * vs + ui.Offset(cos(a), sin(a)) * 4.2 * vs,
          0.85 * vs,
          fillPaint..color = color.withValues(alpha: 0.42),
        );
      }
      drawDartHead(length: 4.8, width: 2.7);
      break;
    case 'Crystal':
      drawTail(width: 3.4, alpha: 0.24);
      final path = ui.Path()
        ..moveTo(
          position.dx + dir.dx * 6.8 * vs,
          position.dy + dir.dy * 6.8 * vs,
        )
        ..lineTo(
          position.dx + perp.dx * 4.0 * vs,
          position.dy + perp.dy * 4.0 * vs,
        )
        ..lineTo(
          position.dx - dir.dx * 5.2 * vs,
          position.dy - dir.dy * 5.2 * vs,
        )
        ..lineTo(
          position.dx - perp.dx * 4.0 * vs,
          position.dy - perp.dy * 4.0 * vs,
        )
        ..close();
      fillPaint.color = color.withValues(alpha: 0.82);
      canvas.drawPath(path, fillPaint);
      canvas.drawCircle(
        position + dir * 1.8 * vs,
        1.4 * vs,
        fillPaint..color = white.withValues(alpha: 0.8),
      );
      break;
    case 'Air':
      for (var i = 0; i < 2; i++) {
        final path = ui.Path();
        for (var j = 0; j < 6; j++) {
          final t = j / 5;
          final p =
              position -
              dir * (12 - t * 12) * vs +
              perp * sin(t * pi + i * pi) * 4.5 * vs;
          if (j == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(
          path,
          strokePaint
            ..color = color.withValues(alpha: 0.30)
            ..strokeWidth = 1.1 * vs
            ..maskFilter = null,
        );
      }
      drawDartHead(length: 5.0, width: 2.8);
      break;
    case 'Plant':
      drawTail(width: 3.0, alpha: 0.20);
      final vine = ui.Path()
        ..moveTo(tail.dx, tail.dy)
        ..quadraticBezierTo(
          position.dx - dir.dx * 7 * vs + perp.dx * 5 * vs,
          position.dy - dir.dy * 7 * vs + perp.dy * 5 * vs,
          position.dx,
          position.dy,
        );
      canvas.drawPath(
        vine,
        strokePaint
          ..color = color.withValues(alpha: 0.50)
          ..strokeWidth = 1.8 * vs
          ..maskFilter = null,
      );
      drawDartHead(length: 5.8, width: 3.2);
      break;
    case 'Poison':
      drawTail(width: 3.6, alpha: 0.24);
      canvas.drawCircle(
        position,
        5.2 * vs * pulse,
        fillPaint
          ..color = color.withValues(alpha: 0.24)
          ..maskFilter = null,
      );
      fillPaint
        ..color = const ui.Color(0xFFD98CFF).withValues(alpha: 0.65)
        ..maskFilter = null;
      canvas.drawCircle(position + perp * 2.2 * vs, 1.3 * vs, fillPaint);
      drawDartHead(length: 5.4, width: 3.4);
      break;
    case 'Spirit':
      drawTail(width: 3.2, alpha: 0.20);
      _drawSpiritHalo(canvas, position, color, 6.2 * vs, vs, time);
      drawDartHead(length: 5.3, width: 3.0);
      break;
    case 'Dark':
      drawTail(width: 4.2, alpha: 0.24);
      canvas.drawCircle(
        position,
        6.2 * vs,
        fillPaint
          ..color = const ui.Color(0xFF05020A).withValues(alpha: 0.70)
          ..maskFilter = null,
      );
      drawDartHead(length: 6.2, width: 3.6);
      break;
    case 'Light':
      drawTail(width: 3.4, alpha: 0.22);
      _drawLightCrown(canvas, position, color, 5.6 * vs, vs, time);
      drawDartHead(length: 5.4, width: 3.0);
      break;
    case 'Blood':
      drawTail(width: 4.8, alpha: 0.26);
      canvas.drawCircle(
        position,
        5.8 * vs,
        fillPaint
          ..color = color.withValues(alpha: 0.84)
          ..maskFilter = null,
      );
      canvas.drawCircle(
        position + dir * 1.5 * vs,
        1.8 * vs,
        fillPaint..color = const ui.Color(0xFFFFB4B4).withValues(alpha: 0.68),
      );
      break;
    default:
      drawTail();
      drawDartHead();
  }

  if (projectile.bounceCount > 0 || projectile.interceptCharges > 0) {
    strokePaint
      ..color = white.withValues(
        alpha: projectile.interceptCharges > 0 ? 0.46 : 0.26,
      )
      ..strokeWidth = 0.9 * vs
      ..maskFilter = null;
    canvas.drawCircle(
      position,
      (6.5 + projectile.bounceCount.clamp(0, 4)) * vs,
      strokePaint,
    );
  }
  if (projectile.snareRadius > 0) {
    strokePaint
      ..color = color.withValues(alpha: 0.26)
      ..strokeWidth = 1.0 * vs
      ..maskFilter = null;
    canvas.drawCircle(
      position,
      (projectile.snareRadius * 0.13).clamp(5.5, 12.0) * vs,
      strokePaint,
    );
  }

  return true;
}

bool drawManeElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  final element = projectile.element;
  if (element == null ||
      projectile.visualStyle != ProjectileVisualStyle.slash) {
    return false;
  }

  // Stationary Mane placements (Lightning orbs, Lava blobs from pierce,
  // Steam puffs along path, Mud puddle from split, Plant explosion
  // zones, etc.) get the modern terrain-zone painters so they read as
  // distinct fixtures instead of small abstract slashes.
  if (projectile.stationary && projectile.abilityFamily == 'mane') {
    final radius = max(
      24.0,
      [
        projectile.effectRadius,
        projectile.snareRadius * 0.95,
      ].fold<double>(0, (a, b) => max(a, b)),
    ).clamp(24.0, 220.0).toDouble();
    final pulse = 0.78 + 0.22 * sin(time * 1.6 + projectile.life * 0.8);
    final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.4)!;
    final glowR = radius * 1.05;
    // Layered concentric circles fake a radial blur without the
    // expensive MaskFilter.blur pass — outer is faintest, inner is
    // strongest. Reads as soft glow but is essentially free.
    final glowPaint = ui.Paint();
    for (var i = 4; i >= 1; i--) {
      glowPaint.color =
          color.withValues(alpha: (0.04 + i * 0.025) * pulse);
      canvas.drawCircle(
        position,
        glowR * (0.6 + i * 0.12),
        glowPaint,
      );
    }
    final visScale = projectile.visualScale.clamp(0.7, 4.0).toDouble();
    switch (element) {
      case 'Lava':
        _paintLavaPool(canvas, position, radius, color, time, pulse, visScale);
        return true;
      case 'Mud':
        _paintMudPool(canvas, position, radius, color, time, pulse, visScale);
        return true;
      case 'Steam':
        _paintSteamGeyser(canvas, position, radius, color, time, pulse, visScale);
        return true;
      case 'Plant':
        _paintPlantZone(canvas, position, radius, color, time, pulse, visScale);
        return true;
      case 'Lightning':
        _paintLightningField(
            canvas, position, radius, color, white, time, pulse, visScale);
        return true;
      case 'Fire':
        _paintFireZone(
            canvas, position, radius, color, white, time, pulse, visScale);
        return true;
      case 'Poison':
        _paintPoisonPool(
            canvas, position, radius, color, time, pulse, visScale);
        return true;
      case 'Ice':
        _paintIcePillar(
            canvas, position, radius, color, white, time, pulse, visScale);
        return true;
      case 'Water':
        _paintWaterPool(
            canvas, position, radius, color, time, pulse, visScale);
        return true;
      default:
        // Fall through to the slash renderer below for elements without
        // a dedicated zone painter.
        break;
    }
  }

  final vs = projectile.visualScale.clamp(0.75, 3.4).toDouble();
  final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
  final perp = ui.Offset(-dir.dy, dir.dx);
  // Heavier catapult shots — slash body bigger so the projectile feels
  // weighty in flight rather than a thin streak.
  final len = (projectile.stationary ? 32.0 : 26.0) * vs;
  final start = position - dir * len;
  final end = position + dir * len;
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.42)!;
  final pulse = 0.72 + 0.28 * sin(time * 5.5 + projectile.life * 2.0);

  // Motion trail for moving manes — directional gradient streak +
  // staggered afterimage discs. The gradient line gives the soft
  // "motion blur" feel without any MaskFilter.blur (which is a
  // full-screen render pass per draw and expensive at scale).
  if (!projectile.stationary) {
    final trailEnd = position - dir * (len * 2.6);
    canvas.drawLine(
      trailEnd,
      position,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          trailEnd,
          position,
          [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.45),
          ],
          const [0.0, 0.55, 1.0],
        )
        ..strokeWidth = 6.0 * vs
        ..strokeCap = ui.StrokeCap.round,
    );
    // Three afterimage discs along the trail. Solid translucent
    // circles — alpha falls off and radius grows so they read as
    // motion echoes rather than copies of the projectile.
    final discPaint = ui.Paint();
    for (var i = 1; i <= 3; i++) {
      final fade = 1.0 - i * 0.30;
      final back = position - dir * (len * 0.85 * i);
      // Two stacked translucent discs per echo: outer wider + softer,
      // inner tighter + brighter. Fakes the soft blur silhouette.
      discPaint.color = color.withValues(alpha: 0.10 * fade);
      canvas.drawCircle(back, (7.0 + i * 1.6) * vs, discPaint);
      discPaint.color = color.withValues(alpha: 0.22 * fade);
      canvas.drawCircle(back, (4.4 + i * 1.0) * vs, discPaint);
    }
  }
  final fillPaint = ui.Paint();
  final strokePaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  final linePaint = ui.Paint()..strokeCap = ui.StrokeCap.round;
  final groundedRadius = projectile.snareRadius > 0
      ? (projectile.snareRadius * 0.36).clamp(26.0, 96.0) * vs
      : (24.0 * projectile.radiusMultiplier.clamp(1.0, 3.4) * vs);

  void drawCoreSlash({
    double width = 3.0,
    double glowWidth = 8.0,
    double alpha = 0.86,
    double lengthScale = 1.0,
  }) {
    final resolvedLengthScale = projectile.stationary
        ? lengthScale * 0.58
        : lengthScale;
    final bodyLen = len * resolvedLengthScale * 1.28;
    final halfWidth = max(width * 1.25, glowWidth * 0.34) * vs;
    final nose = position + dir * bodyLen * 0.62;
    final leftShoulder = position - dir * bodyLen * 0.10 + perp * halfWidth;
    final leftRear = position - dir * bodyLen * 0.58 + perp * halfWidth * 0.55;
    final rightRear = position - dir * bodyLen * 0.58 - perp * halfWidth * 0.55;
    final rightShoulder = position - dir * bodyLen * 0.10 - perp * halfWidth;
    final body = ui.Path()
      ..moveTo(nose.dx, nose.dy)
      ..lineTo(leftShoulder.dx, leftShoulder.dy)
      ..lineTo(leftRear.dx, leftRear.dy)
      ..lineTo(rightRear.dx, rightRear.dy)
      ..lineTo(rightShoulder.dx, rightShoulder.dy)
      ..close();

    canvas.drawPath(body, fillPaint..color = color.withValues(alpha: alpha));
    canvas.drawPath(
      body,
      strokePaint
        ..color = white.withValues(alpha: 0.34 * pulse)
        ..strokeWidth = max(1.0, width * 0.26) * vs
        ..maskFilter = null,
    );
  }

  void drawEarthRockProjectile() {
    final rockLen = len * projectile.radiusMultiplier.clamp(1.0, 4.8) * 0.72;
    final rockWidth = rockLen * 0.58;
    final front = position + dir * rockLen * 0.58;
    final rear = position - dir * rockLen * 0.55;
    final body = ui.Path()
      ..moveTo(front.dx, front.dy)
      ..lineTo(
        position.dx + dir.dx * rockLen * 0.16 + perp.dx * rockWidth * 0.58,
        position.dy + dir.dy * rockLen * 0.16 + perp.dy * rockWidth * 0.58,
      )
      ..lineTo(
        rear.dx + perp.dx * rockWidth * 0.44,
        rear.dy + perp.dy * rockWidth * 0.44,
      )
      ..lineTo(
        rear.dx - perp.dx * rockWidth * 0.34,
        rear.dy - perp.dy * rockWidth * 0.34,
      )
      ..lineTo(
        position.dx + dir.dx * rockLen * 0.10 - perp.dx * rockWidth * 0.64,
        position.dy + dir.dy * rockLen * 0.10 - perp.dy * rockWidth * 0.64,
      )
      ..close();

    final base = ui.Color.lerp(color, const ui.Color(0xFF4A362B), 0.32)!;
    final high = ui.Color.lerp(color, const ui.Color(0xFFE2C6A8), 0.34)!;
    final low = ui.Color.lerp(color, const ui.Color(0xFF241915), 0.48)!;
    canvas.drawPath(body, fillPaint..color = base.withValues(alpha: 0.92));

    final topPlane = ui.Path()
      ..moveTo(front.dx, front.dy)
      ..lineTo(
        position.dx + dir.dx * rockLen * 0.16 + perp.dx * rockWidth * 0.58,
        position.dy + dir.dy * rockLen * 0.16 + perp.dy * rockWidth * 0.58,
      )
      ..lineTo(
        position.dx - dir.dx * rockLen * 0.18 + perp.dx * rockWidth * 0.08,
        position.dy - dir.dy * rockLen * 0.18 + perp.dy * rockWidth * 0.08,
      )
      ..close();
    canvas.drawPath(topPlane, fillPaint..color = high.withValues(alpha: 0.46));

    final lowerPlane = ui.Path()
      ..moveTo(front.dx, front.dy)
      ..lineTo(
        position.dx - dir.dx * rockLen * 0.18 + perp.dx * rockWidth * 0.08,
        position.dy - dir.dy * rockLen * 0.18 + perp.dy * rockWidth * 0.08,
      )
      ..lineTo(
        position.dx + dir.dx * rockLen * 0.10 - perp.dx * rockWidth * 0.64,
        position.dy + dir.dy * rockLen * 0.10 - perp.dy * rockWidth * 0.64,
      )
      ..close();
    canvas.drawPath(lowerPlane, fillPaint..color = low.withValues(alpha: 0.26));

    canvas.drawPath(
      body,
      strokePaint
        ..color = const ui.Color(0xFFD6B18F).withValues(alpha: 0.44)
        ..strokeWidth = max(1.0, 0.55 * vs)
        ..maskFilter = null,
    );
  }

  void drawGroundPatch() {
    if (!projectile.stationary) return;

    switch (element) {
      case 'Earth':
      case 'Mud':
      case 'Lava':
        _drawCrackedPlate(canvas, position, color, groundedRadius, vs, time);
        break;
      case 'Plant':
        _drawVinePatch(
          canvas,
          position,
          color,
          groundedRadius * 0.82,
          vs,
          time,
        );
        break;
      case 'Fire':
      case 'Poison':
      default:
        canvas.drawOval(
          ui.Rect.fromCenter(
            center: position,
            width: groundedRadius * 2.0,
            height: groundedRadius * 1.35,
          ),
          fillPaint..color = color.withValues(alpha: 0.20),
        );
        canvas.drawCircle(
          position,
          groundedRadius * 0.82,
          strokePaint
            ..color = color.withValues(alpha: 0.34)
            ..strokeWidth = 1.5 * vs
            ..maskFilter = null,
        );
    }
  }

  void drawControlRead({double scale = 1.0}) {
    if (projectile.snareRadius <= 0 &&
        !projectile.stationary &&
        projectile.interceptCharges <= 0) {
      return;
    }
    final radius = projectile.stationary
        ? groundedRadius * 0.92 * scale
        : projectile.snareRadius > 0
        ? (projectile.snareRadius * 0.32).clamp(18.0, 54.0) * scale
        : (22.0 * vs * scale);
    strokePaint
      ..color = color.withValues(alpha: 0.28 * pulse)
      ..strokeWidth = 1.4 * vs
      ..maskFilter = null;
    canvas.drawCircle(position, radius, strokePaint);
  }

  switch (element) {
    case 'Fire':
      drawGroundPatch();
      drawCoreSlash(width: 3.4, glowWidth: 10.0, alpha: 0.9);
      for (var i = 0; i < 3; i++) {
        final t = (i - 1) * 0.35;
        final flame = ui.Path()
          ..moveTo(
            start.dx + perp.dx * t * 10 * vs,
            start.dy + perp.dy * t * 10 * vs,
          )
          ..quadraticBezierTo(
            position.dx + perp.dx * (8 + i * 2) * vs,
            position.dy + perp.dy * (8 + i * 2) * vs,
            end.dx,
            end.dy,
          );
        canvas.drawPath(
          flame,
          strokePaint
            ..color = const ui.Color(0xFFFFD28A).withValues(alpha: 0.34)
            ..strokeWidth = 1.3 * vs
            ..maskFilter = null,
        );
      }
      drawControlRead(scale: 1.05);
      break;
    case 'Lightning':
      final bolt = ui.Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(
          position.dx - dir.dx * 7 * vs + perp.dx * 5 * vs,
          position.dy - dir.dy * 7 * vs + perp.dy * 5 * vs,
        )
        ..lineTo(
          position.dx + dir.dx * 2 * vs - perp.dx * 4 * vs,
          position.dy + dir.dy * 2 * vs - perp.dy * 4 * vs,
        )
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(
        bolt,
        strokePaint
          ..color = white.withValues(alpha: 0.92)
          ..strokeWidth = 2.4 * vs
          ..maskFilter = null,
      );
      break;
    case 'Water':
      for (final side in [-1.0, 1.0]) {
        final ribbon = ui.Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(
            position.dx + perp.dx * side * 14 * vs,
            position.dy + perp.dy * side * 14 * vs,
            end.dx,
            end.dy,
          );
        canvas.drawPath(
          ribbon,
          strokePaint
            ..color = color.withValues(alpha: 0.46)
            ..strokeWidth = 2.0 * vs
            ..maskFilter = null,
        );
      }
      drawControlRead(scale: 1.0);
      break;
    case 'Ice':
      drawCoreSlash(width: 3.1, glowWidth: 8.4, alpha: 0.76);
      _drawFrostStar(canvas, position, white, 11.0 * vs, vs, time);
      drawControlRead(scale: 1.08);
      break;
    case 'Steam':
      drawCoreSlash(width: 2.8, glowWidth: 7.0, alpha: 0.72);
      for (var i = 0; i < 4; i++) {
        final drift = i.toDouble();
        canvas.drawCircle(
          position -
              dir * (10.0 - drift * 4.0) * vs +
              perp * sin(time * 2.5 + drift) * 8.0 * vs,
          (5.0 + drift) * vs,
          fillPaint
            ..color = color.withValues(alpha: 0.13)
            ..maskFilter = null,
        );
      }
      drawControlRead(scale: 1.05);
      break;
    case 'Earth':
      drawEarthRockProjectile();
      drawControlRead(scale: 1.30);
      break;
    case 'Lava':
      drawCoreSlash(width: 5.6, glowWidth: 13.0, alpha: 0.88);
      canvas.drawLine(
        start + perp * 4.0 * vs,
        end - perp * 4.0 * vs,
        linePaint
          ..color = const ui.Color(0xFFFFE0A0).withValues(alpha: 0.58)
          ..strokeWidth = 1.7 * vs
          ..maskFilter = null,
      );
      drawControlRead(scale: 1.08);
      break;
    case 'Mud':
      drawGroundPatch();
      drawCoreSlash(width: 5.4, glowWidth: 12.0, alpha: 0.78);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: position,
          width: 30.0 * vs,
          height: 17.0 * vs,
        ),
        fillPaint
          ..color = color.withValues(alpha: 0.16)
          ..maskFilter = null,
      );
      drawControlRead(scale: 1.18);
      break;
    case 'Dust':
      drawCoreSlash(width: 2.1, glowWidth: 7.0, alpha: 0.66);
      for (var i = 0; i < 9; i++) {
        final a = time * 1.5 + i * pi * 2 / 9;
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * (7.0 + i) * vs,
          1.1 * vs,
          fillPaint
            ..color = color.withValues(alpha: 0.40)
            ..maskFilter = null,
        );
      }
      break;
    case 'Crystal':
      drawCoreSlash(width: 3.2, glowWidth: 8.5, alpha: 0.82);
      _drawCrystalSigil(canvas, position, color, 12.0 * vs, vs, time);
      break;
    case 'Air':
      _drawAirSwirl(canvas, position, color, 18.0 * vs, vs, time);
      drawCoreSlash(width: 2.2, glowWidth: 7.5, alpha: 0.64);
      break;
    case 'Plant':
      drawGroundPatch();
      drawCoreSlash(width: 2.6, glowWidth: 7.4, alpha: 0.68, lengthScale: 0.92);
      _drawVinePatch(canvas, position, color, 15.0 * vs, vs, time);
      drawCoreSlash(width: 2.1, glowWidth: 6.2, alpha: 0.50, lengthScale: 0.70);
      drawControlRead(scale: 1.12);
      break;
    case 'Poison':
      drawGroundPatch();
      drawCoreSlash(width: 2.8, glowWidth: 8.0, alpha: 0.64, lengthScale: 0.86);
      canvas.drawCircle(
        position,
        21.0 * vs * pulse,
        fillPaint
          ..color = color.withValues(alpha: 0.14)
          ..maskFilter = null,
      );
      drawCoreSlash(width: 1.9, glowWidth: 5.5, alpha: 0.44, lengthScale: 0.66);
      drawControlRead(scale: 1.10);
      break;
    case 'Spirit':
      drawCoreSlash(width: 2.4, glowWidth: 7.2, alpha: 0.62, lengthScale: 0.90);
      _drawSpiritHalo(canvas, position, color, 14.0 * vs, vs, time);
      break;
    case 'Dark':
      drawCoreSlash(width: 4.1, glowWidth: 11.0, alpha: 0.76);
      canvas.drawCircle(
        position,
        17.0 * vs,
        fillPaint
          ..color = const ui.Color(0xFF05020A).withValues(alpha: 0.52)
          ..maskFilter = null,
      );
      drawControlRead(scale: 1.06);
      break;
    case 'Light':
      drawCoreSlash(width: 3.4, glowWidth: 9.0, alpha: 0.86);
      _drawLightCrown(canvas, position, color, 13.0 * vs, vs, time);
      drawControlRead(scale: 1.0);
      break;
    case 'Blood':
      drawCoreSlash(width: 4.8, glowWidth: 11.0, alpha: 0.84);
      canvas.drawCircle(
        position,
        12.0 * vs * pulse,
        fillPaint
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = null,
      );
      drawControlRead(scale: 1.0);
      break;
    default:
      drawCoreSlash();
      drawControlRead();
  }

  if (projectile.interceptCharges > 0) {
    strokePaint
      ..color = white.withValues(alpha: 0.55 * pulse)
      ..strokeWidth = 1.6 * vs
      ..maskFilter = null;
    canvas.drawCircle(position, 20.0 * vs, strokePaint);
  }

  return true;
}

bool drawHornElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  final element = projectile.element;
  if (element == null ||
      projectile.visualStyle != ProjectileVisualStyle.hornImpact) {
    return false;
  }

  final vs = projectile.visualScale.clamp(0.75, 3.1).toDouble();
  final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
  final perp = ui.Offset(-dir.dy, dir.dx);
  final pulse = 0.72 + 0.28 * sin(time * 4.2 + projectile.life * 1.8);
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.42)!;
  final radius = (7.0 * projectile.radiusMultiplier * vs).clamp(7.0, 34.0);
  final tailLen = (projectile.stationary ? 5.0 : 18.0) * vs;
  final tail = position - dir * tailLen;

  void drawRamCore({double width = 5.0, double glow = 12.0}) {
    if (!projectile.stationary) {
      canvas.drawLine(
        tail,
        position,
        ui.Paint()
          ..color = color.withValues(alpha: 0.22)
          ..strokeWidth = glow * vs
          ..strokeCap = ui.StrokeCap.round
          ..maskFilter = null,
      );
    }
    final head = ui.Path()
      ..moveTo(
        position.dx + dir.dx * radius * 0.95,
        position.dy + dir.dy * radius * 0.95,
      )
      ..lineTo(
        position.dx - dir.dx * radius * 0.55 + perp.dx * radius * 0.72,
        position.dy - dir.dy * radius * 0.55 + perp.dy * radius * 0.72,
      )
      ..lineTo(
        position.dx - dir.dx * radius * 0.25,
        position.dy - dir.dy * radius * 0.25,
      )
      ..lineTo(
        position.dx - dir.dx * radius * 0.55 - perp.dx * radius * 0.72,
        position.dy - dir.dy * radius * 0.55 - perp.dy * radius * 0.72,
      )
      ..close();
    canvas.drawPath(
      head,
      ui.Paint()
        ..color = color.withValues(alpha: 0.88)
        ..maskFilter = null,
    );
    canvas.drawPath(
      head,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = max(1.0, width * 0.26) * vs
        ..color = white.withValues(alpha: 0.64),
    );
  }

  void drawGuardRings() {
    final snareR = projectile.snareRadius > 0
        ? (projectile.snareRadius * 0.25).clamp(14.0, 62.0)
        : 0.0;
    final tauntR = projectile.tauntRadius > 0
        ? (projectile.tauntRadius * 0.15).clamp(18.0, 68.0)
        : 0.0;
    final interceptR = projectile.interceptRadius > 0
        ? (projectile.interceptRadius * 0.72).clamp(16.0, 52.0)
        : 0.0;
    final guardR = max(snareR, max(tauntR, interceptR));
    if (guardR <= 0) return;

    canvas.drawCircle(
      position,
      guardR * pulse,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.5 * vs
        ..color = color.withValues(alpha: 0.30),
    );
    if (projectile.tauntRadius > 0) {
      canvas.drawCircle(
        position,
        guardR * 0.58,
        ui.Paint()
          ..color = color.withValues(alpha: 0.09)
          ..maskFilter = null,
      );
    }
    if (projectile.interceptCharges > 0) {
      for (var i = 0; i < 4; i++) {
        final a = time * 1.8 + i * pi / 2;
        canvas.drawLine(
          position + ui.Offset(cos(a), sin(a)) * guardR * 0.55,
          position + ui.Offset(cos(a), sin(a)) * guardR,
          ui.Paint()
            ..color = white.withValues(alpha: 0.46)
            ..strokeWidth = 1.4 * vs
            ..strokeCap = ui.StrokeCap.round,
        );
      }
    }
  }

  switch (element) {
    case 'Lightning':
      drawRamCore(width: 3.2, glow: 8.0);
      for (var i = 0; i < 2; i++) {
        final side = i == 0 ? -1.0 : 1.0;
        canvas.drawLine(
          tail + perp * side * 5.0 * vs,
          position + dir * 5.0 * vs - perp * side * 4.0 * vs,
          ui.Paint()
            ..color = white.withValues(alpha: 0.62)
            ..strokeWidth = 1.2 * vs
            ..strokeCap = ui.StrokeCap.round,
        );
      }
      break;
    case 'Water':
      drawRamCore(width: 4.2, glow: 10.0);
      for (final side in [-1.0, 1.0]) {
        final path = ui.Path()
          ..moveTo(tail.dx, tail.dy)
          ..quadraticBezierTo(
            position.dx + perp.dx * side * 12.0 * vs,
            position.dy + perp.dy * side * 12.0 * vs,
            position.dx + dir.dx * 8.0 * vs,
            position.dy + dir.dy * 8.0 * vs,
          );
        canvas.drawPath(
          path,
          ui.Paint()
            ..color = color.withValues(alpha: 0.34)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.7 * vs
            ..strokeCap = ui.StrokeCap.round,
        );
      }
      break;
    case 'Ice':
      drawRamCore(width: 5.8, glow: 12.0);
      _drawFrostStar(canvas, position, white, radius * 1.25, vs, time);
      break;
    case 'Steam':
      drawRamCore(width: 5.6, glow: 13.0);
      for (var i = 0; i < 4; i++) {
        final drift = i.toDouble();
        canvas.drawCircle(
          position + perp * sin(time * 2.2 + drift) * 8.0 * vs,
          (6.0 + drift) * vs,
          ui.Paint()
            ..color = color.withValues(alpha: 0.12)
            ..maskFilter = null,
        );
      }
      break;
    case 'Earth':
      drawRamCore(width: 7.0, glow: 15.0);
      _drawCrackedPlate(canvas, position, color, radius * 1.4, vs, time);
      break;
    case 'Lava':
      drawRamCore(width: 7.2, glow: 16.0);
      canvas.drawCircle(
        position + dir * 2.0 * vs - perp * 2.0 * vs,
        2.4 * vs,
        ui.Paint()..color = const ui.Color(0xFFFFE0A0).withValues(alpha: 0.78),
      );
      break;
    case 'Mud':
      drawRamCore(width: 7.0, glow: 15.0);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: position,
          width: radius * 2.2,
          height: radius * 1.25,
        ),
        ui.Paint()
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = null,
      );
      break;
    case 'Dust':
      drawRamCore(width: 3.0, glow: 8.0);
      _drawDustCloud(canvas, position, color, radius * 1.2, vs, time);
      break;
    case 'Crystal':
      drawRamCore(width: 4.8, glow: 10.0);
      _drawCrystalSigil(canvas, position, color, radius * 1.1, vs, time);
      break;
    case 'Air':
      drawRamCore(width: 3.5, glow: 9.0);
      _drawAirSwirl(canvas, position, color, radius * 1.15, vs, time);
      break;
    case 'Plant':
      drawRamCore(width: 5.2, glow: 12.0);
      _drawVinePatch(canvas, position, color, radius * 1.1, vs, time);
      break;
    case 'Poison':
      drawRamCore(width: 5.2, glow: 12.0);
      canvas.drawCircle(
        position,
        radius * 1.35,
        ui.Paint()
          ..color = color.withValues(alpha: 0.12)
          ..maskFilter = null,
      );
      break;
    case 'Spirit':
      drawRamCore(width: 4.5, glow: 11.0);
      _drawSpiritHalo(canvas, position, color, radius * 1.25, vs, time);
      break;
    case 'Dark':
      drawRamCore(width: 5.2, glow: 13.0);
      canvas.drawCircle(
        position,
        radius * 1.1,
        ui.Paint()
          ..color = const ui.Color(0xFF05020A).withValues(alpha: 0.48)
          ..maskFilter = null,
      );
      break;
    case 'Light':
      drawRamCore(width: 4.5, glow: 11.0);
      _drawLightCrown(canvas, position, color, radius * 1.2, vs, time);
      break;
    case 'Blood':
      drawRamCore(width: 5.5, glow: 13.0);
      canvas.drawCircle(
        position,
        radius * 0.8 * pulse,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.6 * vs
          ..color = white.withValues(alpha: 0.48),
      );
      break;
    default:
      drawRamCore();
  }

  drawGuardRings();
  return true;
}

/// Paints a ground-zone style trap visual sized to the projectile's
/// gameplay radius (effect/snare). Modern game traps read as terrain
/// patches, not floating sigils — a poison pool, a crystal cluster,
/// an ice field, etc.
void _drawMaskGroundZone({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required ui.Color white,
  required double time,
}) {
  final element = projectile.element ?? '';
  // Zone radius derived from gameplay flags: snare > effect > taunt.
  final zoneR = () {
    final candidates = <double>[
      projectile.snareRadius,
      projectile.effectRadius,
      projectile.tauntRadius * 0.45,
    ];
    final best = candidates.fold<double>(0, (a, b) => max(a, b));
    return max(20.0, best).clamp(20.0, 260.0).toDouble();
  }();
  final vs = projectile.visualScale.clamp(0.7, 4.0).toDouble();
  // Soft animated pulse. Slower/lower for ambient pool look.
  final pulse = 0.78 + 0.22 * sin(time * 1.6 + projectile.life * 0.8);
  final breathe = 1.0 + 0.04 * sin(time * 1.2 + projectile.life);
  final zoneSize = zoneR * breathe;

  switch (element) {
    case 'Poison':
      _paintPoisonPool(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Lava':
      _paintLavaPool(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Mud':
      _paintMudPool(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Water':
      _paintWaterPool(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Fire':
      _paintFireZone(canvas, position, zoneSize, color, white, time, pulse, vs);
      break;
    case 'Plant':
      _paintPlantZone(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Crystal':
      _paintCrystalCluster(
        canvas,
        position,
        zoneSize,
        color,
        white,
        time,
        pulse,
        vs,
      );
      break;
    case 'Ice':
      _paintIcePillar(
        canvas,
        position,
        zoneSize,
        color,
        white,
        time,
        pulse,
        vs,
      );
      break;
    case 'Lightning':
      _paintLightningField(
        canvas,
        position,
        zoneSize,
        color,
        white,
        time,
        pulse,
        vs,
      );
      break;
    case 'Steam':
      _paintSteamGeyser(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Light':
      _paintLightVoid(
        canvas,
        position,
        zoneSize,
        color,
        white,
        time,
        pulse,
        vs,
      );
      break;
    case 'Dark':
      _paintDarkVoid(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Spirit':
      _paintSpiritWisp(
        canvas,
        position,
        zoneSize,
        color,
        white,
        time,
        pulse,
        vs,
      );
      break;
    case 'Blood':
      _paintBloodBlob(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Earth':
      _paintEarthPool(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Air':
      _paintAirGust(canvas, position, zoneSize, color, white, time, pulse, vs);
      break;
    case 'Dust':
      _paintDustField(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    default:
      _paintGenericZone(canvas, position, zoneSize, color, time, pulse, vs);
  }
}

void _paintZoneFill(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color, {
  double alpha = 0.28,
  double rim = 0.55,
}) {
  final fill = ui.Paint()..color = color.withValues(alpha: alpha);
  canvas.drawCircle(position, radius, fill);
  final outline = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = color.withValues(alpha: rim);
  canvas.drawCircle(position, radius, outline);
}

void _paintBubbles(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color tint,
  double time,
  int count,
  double pulse, {
  double sizeMul = 1.0,
}) {
  final p = ui.Paint();
  for (var i = 0; i < count; i++) {
    final phase = (time * 0.9 + i * 0.7) % 1.0;
    final a = i * (pi * 2 / count) + time * 0.18;
    final r = radius * (0.25 + 0.55 * phase);
    final pos = position + ui.Offset(cos(a), sin(a)) * r;
    final size = radius * (0.05 + 0.07 * (1 - phase)) * sizeMul;
    p.color = tint.withValues(alpha: (1 - phase) * 0.7 * pulse);
    canvas.drawCircle(pos, size, p);
  }
}

void _paintPoisonPool(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Sickly green-purple pool with bubbling DoT particles.
  _paintZoneFill(
    canvas,
    position,
    radius,
    color,
    alpha: 0.32 * pulse,
    rim: 0.65 * pulse,
  );
  // Inner darker patch
  final inner = ui.Paint()
    ..color = ui.Color.lerp(
      color,
      const ui.Color(0xFF2B0E3A),
      0.45,
    )!.withValues(alpha: 0.28 * pulse);
  canvas.drawCircle(position, radius * 0.62, inner);
  _paintBubbles(canvas, position, radius * 0.85, color, time, 7, pulse);
  // A few rising vapor wisps
  final vapor = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.6 * vs
    ..color = color.withValues(alpha: 0.55 * pulse);
  for (var i = 0; i < 3; i++) {
    final t = (time * 0.5 + i * 0.33) % 1.0;
    final base =
        position +
        ui.Offset(
          cos(i * 2.1 + time * 0.3) * radius * 0.4,
          sin(i * 1.7 + time * 0.4) * radius * 0.4,
        );
    final tip = base + ui.Offset(0, -radius * 0.65 * t);
    canvas.drawLine(base, tip, vapor);
  }
}

void _paintLavaPool(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Molten fill + cracks + ember pops.
  _paintZoneFill(
    canvas,
    position,
    radius,
    color,
    alpha: 0.42 * pulse,
    rim: 0.75,
  );
  // Hot inner glow
  final hot = ui.Paint()
    ..color = ui.Color.lerp(
      color,
      const ui.Color(0xFFFFE08A),
      0.5,
    )!.withValues(alpha: 0.55 * pulse);
  canvas.drawCircle(position, radius * 0.55, hot);
  // Cracks
  final crack = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.4 * vs
    ..color = ui.Color.lerp(
      color,
      const ui.Color(0xFFFFFFFF),
      0.4,
    )!.withValues(alpha: 0.7 * pulse);
  for (var i = 0; i < 4; i++) {
    final a1 = i * (pi / 2) + time * 0.04;
    final start = position + ui.Offset(cos(a1), sin(a1)) * radius * 0.2;
    final mid =
        position + ui.Offset(cos(a1 + 0.3), sin(a1 + 0.3)) * radius * 0.55;
    final end =
        position + ui.Offset(cos(a1 + 0.05), sin(a1 + 0.05)) * radius * 0.85;
    final p = ui.Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(p, crack);
  }
  // Embers
  final ember = ui.Paint();
  for (var i = 0; i < 6; i++) {
    final phase = (time * 1.1 + i * 0.41) % 1.0;
    final a = i * (pi * 2 / 6) + time * 0.18;
    final r = radius * (0.3 + 0.6 * phase);
    final pos = position + ui.Offset(cos(a), sin(a)) * r;
    ember.color = const ui.Color(
      0xFFFFD160,
    ).withValues(alpha: (1 - phase) * 0.85 * pulse);
    canvas.drawCircle(pos, 1.6 * vs, ember);
  }
}

void _paintMudPool(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  _paintZoneFill(
    canvas,
    position,
    radius,
    color,
    alpha: 0.40 * pulse,
    rim: 0.6,
  );
  // Lumps and ripples
  final lump = ui.Paint();
  for (var i = 0; i < 4; i++) {
    final a = i * (pi / 2) + time * 0.1;
    final p =
        position +
        ui.Offset(cos(a), sin(a)) * radius * (0.3 + 0.18 * sin(time * 1.4 + i));
    lump.color = ui.Color.lerp(
      color,
      const ui.Color(0xFF000000),
      0.35,
    )!.withValues(alpha: 0.55 * pulse);
    canvas.drawCircle(p, radius * 0.18, lump);
  }
  _paintBubbles(canvas, position, radius * 0.7, color, time * 0.6, 4, pulse);
}

void _paintWaterPool(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  _paintZoneFill(
    canvas,
    position,
    radius,
    color,
    alpha: 0.32 * pulse,
    rim: 0.6,
  );
  // Ripple rings
  final ripple = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.2 * vs;
  for (var i = 0; i < 3; i++) {
    final phase = ((time * 0.5 + i * 0.33) % 1.0);
    final r = radius * (0.4 + 0.55 * phase);
    ripple.color = color.withValues(alpha: (1 - phase) * 0.75 * pulse);
    canvas.drawCircle(position, r, ripple);
  }
}

void _paintFireZone(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  ui.Color white,
  double time,
  double pulse,
  double vs,
) {
  // Smoldering charred ground + flame tongues.
  final ground = ui.Paint()
    ..color = ui.Color.lerp(
      color,
      const ui.Color(0xFF1A0000),
      0.55,
    )!.withValues(alpha: 0.4 * pulse);
  canvas.drawCircle(position, radius, ground);
  final hot = ui.Paint()..color = color.withValues(alpha: 0.6 * pulse);
  canvas.drawCircle(position, radius * 0.5, hot);
  // Flickering flame tongues
  for (var i = 0; i < 7; i++) {
    final a = i * (pi * 2 / 7) + sin(time * 4 + i) * 0.25;
    final h = radius * (0.55 + 0.4 * (1 + sin(time * 8 + i * 0.7)) / 2);
    final base = position + ui.Offset(cos(a), sin(a)) * radius * 0.35;
    final tip = position + ui.Offset(cos(a), sin(a)) * h;
    final tongue = ui.Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(
        position.dx + cos(a + 0.4) * radius * 0.45,
        position.dy + sin(a + 0.4) * radius * 0.45,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        position.dx + cos(a - 0.4) * radius * 0.45,
        position.dy + sin(a - 0.4) * radius * 0.45,
        base.dx,
        base.dy,
      );
    final flame = ui.Paint()
      ..color = ui.Color.lerp(
        color,
        white,
        0.35,
      )!.withValues(alpha: 0.7 * pulse);
    canvas.drawPath(tongue, flame);
  }
}

void _paintPlantZone(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Mossy ground patch with vine tendrils + small flower buds.
  _paintZoneFill(
    canvas,
    position,
    radius,
    color,
    alpha: 0.32 * pulse,
    rim: 0.5,
  );
  // Tendrils sprouting outward
  final tendril = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.8 * vs
    ..strokeCap = ui.StrokeCap.round
    ..color = ui.Color.lerp(
      color,
      const ui.Color(0xFF1F4F22),
      0.3,
    )!.withValues(alpha: 0.85 * pulse);
  for (var i = 0; i < 6; i++) {
    final a = i * (pi * 2 / 6) + time * 0.05;
    final tip = position + ui.Offset(cos(a), sin(a)) * radius * 0.95;
    final mid =
        position + ui.Offset(cos(a + 0.6), sin(a + 0.6)) * radius * 0.55;
    final p = ui.Path()
      ..moveTo(position.dx, position.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
    canvas.drawPath(p, tendril);
    // Flower bud at tip
    final bud = ui.Paint()
      ..color = ui.Color.lerp(
        color,
        const ui.Color(0xFFFFFFFF),
        0.55,
      )!.withValues(alpha: 0.85 * pulse);
    canvas.drawCircle(tip, 2.4 * vs, bud);
  }
}

void _paintCrystalCluster(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  ui.Color white,
  double time,
  double pulse,
  double vs,
) {
  // Cluster of upright crystal shards growing outward from a base.
  // Base patch
  final base = ui.Paint()
    ..color = ui.Color.lerp(
      color,
      const ui.Color(0xFF000000),
      0.55,
    )!.withValues(alpha: 0.3 * pulse);
  canvas.drawCircle(position, radius * 0.6, base);
  // 5–7 shards
  const shardCount = 5;
  for (var i = 0; i < shardCount; i++) {
    final a = i * (pi * 2 / shardCount) + time * 0.04;
    final h = radius * (0.7 + 0.18 * sin(i * 2.3));
    final tip = position + ui.Offset(cos(a), sin(a)) * h;
    final w = radius * 0.18;
    final left = position + ui.Offset(cos(a + pi / 2), sin(a + pi / 2)) * w;
    final right = position + ui.Offset(cos(a - pi / 2), sin(a - pi / 2)) * w;
    final shard = ui.Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    final fill = ui.Paint()..color = color.withValues(alpha: 0.85 * pulse);
    canvas.drawPath(shard, fill);
    final edge = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.3 * vs
      ..color = white.withValues(alpha: 0.65 * pulse);
    canvas.drawPath(shard, edge);
    // Inner highlight
    final mid = ui.Offset((left.dx + tip.dx) * 0.5, (left.dy + tip.dy) * 0.5);
    canvas.drawLine(mid, tip, edge);
  }
}

void _paintIcePillar(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  ui.Color white,
  double time,
  double pulse,
  double vs,
) {
  // Wide frost field on the ground + a tall pillar in the center.
  // Frost halo on the ground
  final frost = ui.Paint()
    ..color = ui.Color.lerp(
      color,
      white,
      0.55,
    )!.withValues(alpha: 0.35 * pulse);
  canvas.drawCircle(position, radius, frost);
  // Six-pointed snowflake pattern
  final flake = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.6 * vs
    ..color = white.withValues(alpha: 0.7 * pulse);
  for (var i = 0; i < 6; i++) {
    final a = i * (pi / 3);
    final tip = position + ui.Offset(cos(a), sin(a)) * radius * 0.85;
    canvas.drawLine(position, tip, flake);
    // Side prongs
    final prongA = tip - ui.Offset(cos(a), sin(a)) * radius * 0.25;
    final pL =
        prongA + ui.Offset(cos(a + pi / 2), sin(a + pi / 2)) * radius * 0.18;
    final pR =
        prongA + ui.Offset(cos(a - pi / 2), sin(a - pi / 2)) * radius * 0.18;
    canvas.drawLine(prongA, pL, flake);
    canvas.drawLine(prongA, pR, flake);
  }
  // Central pillar (diamond shape)
  final pillar = ui.Paint()..color = color.withValues(alpha: 0.85 * pulse);
  final pillarPath = ui.Path()
    ..moveTo(position.dx, position.dy - radius * 0.55)
    ..lineTo(position.dx + radius * 0.18, position.dy)
    ..lineTo(position.dx, position.dy + radius * 0.25)
    ..lineTo(position.dx - radius * 0.18, position.dy)
    ..close();
  canvas.drawPath(pillarPath, pillar);
  final pillarEdge = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.4 * vs
    ..color = white.withValues(alpha: 0.85 * pulse);
  canvas.drawPath(pillarPath, pillarEdge);
}

void _paintLightningField(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  ui.Color white,
  double time,
  double pulse,
  double vs,
) {
  _paintZoneFill(
    canvas,
    position,
    radius,
    color,
    alpha: 0.22 * pulse,
    rim: 0.5,
  );
  // Erratic lightning arcs jumping inside the field
  final arc = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.7 * vs
    ..strokeCap = ui.StrokeCap.round
    ..color = white.withValues(alpha: 0.85 * pulse);
  for (var i = 0; i < 5; i++) {
    final a1 = i * (pi * 2 / 5) + sin(time * 3 + i) * 0.4;
    final a2 = a1 + pi + sin(time * 4 + i) * 0.4;
    final p1 = position + ui.Offset(cos(a1), sin(a1)) * radius * 0.85;
    final p2 = position + ui.Offset(cos(a2), sin(a2)) * radius * 0.7;
    final mid = ui.Offset(
      (p1.dx + p2.dx) * 0.5 + sin(time * 5 + i) * 6 * vs,
      (p1.dy + p2.dy) * 0.5 + cos(time * 5 + i) * 6 * vs,
    );
    final p = ui.Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(p2.dx, p2.dy);
    canvas.drawPath(p, arc);
  }
  // Bright core
  final core = ui.Paint()..color = white.withValues(alpha: 0.9 * pulse);
  canvas.drawCircle(position, radius * 0.18, core);
}

void _paintSteamGeyser(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Geyser opening + rising puffs.
  final base = ui.Paint()
    ..color = ui.Color.lerp(
      color,
      const ui.Color(0xFF000000),
      0.6,
    )!.withValues(alpha: 0.5 * pulse);
  canvas.drawCircle(position, radius * 0.35, base);
  // Rising puffs
  for (var i = 0; i < 4; i++) {
    final phase = (time * 0.6 + i * 0.25) % 1.0;
    final pos = position + ui.Offset(0, -radius * phase);
    final p = ui.Paint()
      ..color = color.withValues(alpha: (1 - phase) * 0.65 * pulse);
    canvas.drawCircle(pos, radius * (0.18 + phase * 0.3), p);
  }
}

void _paintLightVoid(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  ui.Color white,
  double time,
  double pulse,
  double vs,
) {
  // Bright halo with rotating rays — like a rune circle.
  final halo = ui.Paint()..color = white.withValues(alpha: 0.4 * pulse);
  canvas.drawCircle(position, radius, halo);
  final core = ui.Paint()..color = white.withValues(alpha: 0.95 * pulse);
  canvas.drawCircle(position, radius * 0.25, core);
  final ray = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.4 * vs
    ..color = white.withValues(alpha: 0.85 * pulse);
  for (var i = 0; i < 16; i++) {
    final a = i * (pi * 2 / 16) + time * 0.25;
    final inner = position + ui.Offset(cos(a), sin(a)) * radius * 0.4;
    final outer = position + ui.Offset(cos(a), sin(a)) * radius * 0.95;
    canvas.drawLine(inner, outer, ray);
  }
  // Outer rune ring
  final rune = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.8 * vs
    ..color = color.withValues(alpha: 0.75 * pulse);
  canvas.drawCircle(position, radius * 0.95, rune);
}

void _paintDarkVoid(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Black hole — dark fill spiral inward with bright accretion ring.
  final pit = ui.Paint()
    ..color = const ui.Color(0xFF000000).withValues(alpha: 0.85 * pulse);
  canvas.drawCircle(position, radius * 0.55, pit);
  final accretion = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 3.0 * vs
    ..color = color.withValues(alpha: 0.78 * pulse);
  canvas.drawCircle(position, radius * 0.65, accretion);
  // Spiral arms
  final spiral = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.5 * vs
    ..color = color.withValues(alpha: 0.6 * pulse);
  for (var arm = 0; arm < 3; arm++) {
    final p = ui.Path();
    const segs = 22;
    for (var i = 0; i < segs; i++) {
      final t = i / (segs - 1);
      final a = arm * (pi * 2 / 3) + t * pi * 1.5 - time * 0.7;
      final r = radius * (0.95 - t * 0.45);
      final pt = position + ui.Offset(cos(a), sin(a)) * r;
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(p, spiral);
  }
}

void _paintSpiritWisp(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  ui.Color white,
  double time,
  double pulse,
  double vs,
) {
  // Soft glowing wisp orbs drifting around a central faint core.
  final faint = ui.Paint()..color = color.withValues(alpha: 0.18 * pulse);
  canvas.drawCircle(position, radius * 0.7, faint);
  for (var i = 0; i < 4; i++) {
    final a = time * 0.4 + i * (pi / 2);
    final r = radius * (0.4 + 0.18 * sin(time * 1.5 + i));
    final pos = position + ui.Offset(cos(a), sin(a)) * r;
    final glow = ui.Paint()..color = white.withValues(alpha: 0.7 * pulse);
    canvas.drawCircle(pos, radius * 0.14, glow);
    final tint = ui.Paint()..color = color.withValues(alpha: 0.55 * pulse);
    canvas.drawCircle(pos, radius * 0.08, tint);
  }
}

void _paintBloodBlob(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Pulsing irregular blob of blood with darker core.
  final blob = ui.Path();
  const lobes = 11;
  for (var i = 0; i < lobes; i++) {
    final a = i * (pi * 2 / lobes);
    final r = radius * (0.85 + 0.12 * sin(time * 1.5 + i * 0.9));
    final pt = position + ui.Offset(cos(a), sin(a)) * r;
    if (i == 0) {
      blob.moveTo(pt.dx, pt.dy);
    } else {
      blob.lineTo(pt.dx, pt.dy);
    }
  }
  blob.close();
  final fill = ui.Paint()..color = color.withValues(alpha: 0.65 * pulse);
  canvas.drawPath(blob, fill);
  final core = ui.Paint()
    ..color = const ui.Color(0xFF3A0008).withValues(alpha: 0.7 * pulse);
  canvas.drawCircle(position, radius * 0.4, core);
  // Drips around the rim
  for (var i = 0; i < 5; i++) {
    final a = i * (pi * 2 / 5) + time * 0.3;
    final tip = position + ui.Offset(cos(a), sin(a)) * radius * 1.05;
    final p = ui.Paint()..color = color.withValues(alpha: 0.6 * pulse);
    canvas.drawCircle(tip, radius * 0.08, p);
  }
}

void _paintEarthPool(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Healing earth ground patch with green moss and stones.
  _paintZoneFill(canvas, position, radius, color, alpha: 0.3 * pulse, rim: 0.5);
  // Green moss tint
  final moss = ui.Paint()
    ..color = const ui.Color(0xFF3A7A2E).withValues(alpha: 0.4 * pulse);
  canvas.drawCircle(position, radius * 0.7, moss);
  // Scattered stones
  for (var i = 0; i < 6; i++) {
    final a = i * (pi * 2 / 6) + time * 0.05;
    final r = radius * (0.35 + (i % 2) * 0.3);
    final pos = position + ui.Offset(cos(a), sin(a)) * r;
    final stone = ui.Paint()
      ..color = ui.Color.lerp(
        color,
        const ui.Color(0xFF2A1A0A),
        0.4,
      )!.withValues(alpha: 0.85 * pulse);
    canvas.drawCircle(pos, radius * 0.08, stone);
  }
  // Healing pulse ring
  final pulseRing = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.4 * vs
    ..color = const ui.Color(0xFFB7FFB7).withValues(alpha: 0.6 * pulse);
  final pulseR = radius * (0.5 + 0.4 * (sin(time * 1.2) + 1) / 2);
  canvas.drawCircle(position, pulseR, pulseRing);
}

void _paintAirGust(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  ui.Color white,
  double time,
  double pulse,
  double vs,
) {
  // Wispy swirling streamers — minimal ground tint.
  final tint = ui.Paint()..color = color.withValues(alpha: 0.16 * pulse);
  canvas.drawCircle(position, radius * 0.85, tint);
  // Spiraling streamers
  final stream = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.6 * vs
    ..strokeCap = ui.StrokeCap.round
    ..color = white.withValues(alpha: 0.6 * pulse);
  for (var i = 0; i < 4; i++) {
    final base = i * (pi / 2) + time * 0.7;
    final p = ui.Path();
    const segs = 12;
    for (var j = 0; j < segs; j++) {
      final t = j / (segs - 1);
      final a = base + t * pi * 1.1;
      final r = radius * (0.2 + t * 0.7);
      final pt = position + ui.Offset(cos(a), sin(a)) * r;
      if (j == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(p, stream);
  }
}

void _paintDustField(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Sandy ground tint + lots of small specks circling.
  _paintZoneFill(canvas, position, radius, color, alpha: 0.2 * pulse, rim: 0.4);
  final speck = ui.Paint();
  for (var i = 0; i < 14; i++) {
    final a = i * (pi * 2 / 14) + time * 0.4 + (i % 3) * 0.5;
    final r = radius * (0.25 + (i % 4) * 0.2);
    final pos = position + ui.Offset(cos(a), sin(a)) * r;
    speck.color = color.withValues(alpha: 0.8 * pulse);
    canvas.drawCircle(pos, 1.4 * vs, speck);
  }
}

void _paintGenericZone(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  _paintZoneFill(canvas, position, radius, color, alpha: 0.3 * pulse);
}

// Legacy small-sigil core renderer. Kept for cosmic-mode parity in
// case we re-enable per-style fall-throughs; mask survival path uses
// _drawMaskGroundZone instead.
// ignore: unused_element
void _drawMaskCoreForElementLegacy({
  required ui.Canvas canvas,
  required String element,
  required ui.Offset position,
  required ui.Color color,
  required ui.Color white,
  required double coreR,
  required double vs,
  required double time,
  required double pulse,
  required ui.Paint fillPaint,
  required ui.Paint linePaint,
}) {
  final stroke = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;

  switch (element) {
    case 'Plant':
      // Vine bloom: 5 curling tendrils sprouting outward.
      const branches = 5;
      for (var i = 0; i < branches; i++) {
        final a = i * (pi * 2 / branches) + time * 0.12;
        final tip = position + ui.Offset(cos(a), sin(a)) * coreR * 1.6;
        final mid =
            position + ui.Offset(cos(a + 0.5), sin(a + 0.5)) * coreR * 1.0;
        final path = ui.Path()
          ..moveTo(position.dx, position.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
        stroke
          ..color = color.withValues(alpha: 0.78 * pulse)
          ..strokeWidth = 1.6 * vs;
        canvas.drawPath(path, stroke);
      }
      fillPaint.color = white.withValues(alpha: 0.85 * pulse);
      canvas.drawCircle(position, coreR * 0.55, fillPaint);
      break;

    case 'Fire':
    case 'Lava':
      // Flame teardrops licking upward.
      const tongues = 6;
      for (var i = 0; i < tongues; i++) {
        final a = i * (pi * 2 / tongues) + sin(time * 3 + i) * 0.18;
        final r = coreR * (1.1 + 0.35 * (1 + sin(time * 6 + i)) / 2);
        final tip = position + ui.Offset(cos(a), sin(a)) * r * 1.5;
        final base = position + ui.Offset(cos(a), sin(a)) * coreR * 0.4;
        final path = ui.Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            position.dx + cos(a + 0.4) * coreR * 0.9,
            position.dy + sin(a + 0.4) * coreR * 0.9,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            position.dx + cos(a - 0.4) * coreR * 0.9,
            position.dy + sin(a - 0.4) * coreR * 0.9,
            base.dx,
            base.dy,
          );
        fillPaint.color = color.withValues(alpha: 0.65 * pulse);
        canvas.drawPath(path, fillPaint);
      }
      fillPaint.color = white.withValues(alpha: 0.85 * pulse);
      canvas.drawCircle(position, coreR * 0.5, fillPaint);
      break;

    case 'Lightning':
      // Jagged bolt cross — angular, fast.
      const arms = 4;
      for (var i = 0; i < arms; i++) {
        final a = i * (pi / 2) + time * 0.05;
        final p1 = position + ui.Offset(cos(a), sin(a)) * coreR * 0.5;
        final p2 =
            position + ui.Offset(cos(a + 0.45), sin(a + 0.45)) * coreR * 1.0;
        final p3 =
            position + ui.Offset(cos(a - 0.25), sin(a - 0.25)) * coreR * 1.5;
        stroke
          ..color = white.withValues(alpha: 0.85 * pulse)
          ..strokeWidth = 1.8 * vs;
        canvas.drawLine(position, p1, stroke);
        canvas.drawLine(p1, p2, stroke);
        canvas.drawLine(p2, p3, stroke);
      }
      fillPaint.color = white.withValues(alpha: 0.95 * pulse);
      canvas.drawCircle(position, coreR * 0.45, fillPaint);
      break;

    case 'Ice':
      // Six-fold snowflake/pillar.
      const spokes = 6;
      for (var i = 0; i < spokes; i++) {
        final a = i * (pi * 2 / spokes);
        final tip = position + ui.Offset(cos(a), sin(a)) * coreR * 1.6;
        stroke
          ..color = color.withValues(alpha: 0.85 * pulse)
          ..strokeWidth = 1.6 * vs;
        canvas.drawLine(position, tip, stroke);
        // Side prongs near tip
        final prongA = tip - ui.Offset(cos(a), sin(a)) * coreR * 0.45;
        final pL =
            prongA + ui.Offset(cos(a + pi / 2), sin(a + pi / 2)) * coreR * 0.3;
        final pR =
            prongA + ui.Offset(cos(a - pi / 2), sin(a - pi / 2)) * coreR * 0.3;
        stroke.strokeWidth = 1.1 * vs;
        canvas.drawLine(prongA, pL, stroke);
        canvas.drawLine(prongA, pR, stroke);
      }
      fillPaint.color = white.withValues(alpha: 0.88 * pulse);
      canvas.drawCircle(position, coreR * 0.4, fillPaint);
      break;

    case 'Crystal':
      // Hexagonal faceted gem.
      final hex = ui.Path();
      for (var i = 0; i < 6; i++) {
        final a = i * (pi / 3) + time * 0.08;
        final p = position + ui.Offset(cos(a), sin(a)) * coreR * 1.2;
        if (i == 0) {
          hex.moveTo(p.dx, p.dy);
        } else {
          hex.lineTo(p.dx, p.dy);
        }
      }
      hex.close();
      fillPaint.color = color.withValues(alpha: 0.65 * pulse);
      canvas.drawPath(hex, fillPaint);
      stroke
        ..color = white.withValues(alpha: 0.7 * pulse)
        ..strokeWidth = 1.4 * vs;
      canvas.drawPath(hex, stroke);
      // Inner triangles for facets
      for (var i = 0; i < 6; i += 2) {
        final a = i * (pi / 3) + time * 0.08;
        final p = position + ui.Offset(cos(a), sin(a)) * coreR * 1.2;
        stroke.strokeWidth = 1.0 * vs;
        canvas.drawLine(position, p, stroke);
      }
      break;

    case 'Light':
      // Bright halo with rays — distinct from execute void.
      fillPaint.color = white.withValues(alpha: 0.9 * pulse);
      canvas.drawCircle(position, coreR * 0.65, fillPaint);
      stroke
        ..color = white.withValues(alpha: 0.55 * pulse)
        ..strokeWidth = 1.0 * vs;
      const rays = 12;
      for (var i = 0; i < rays; i++) {
        final a = i * (pi * 2 / rays) + time * 0.2;
        final inner = position + ui.Offset(cos(a), sin(a)) * coreR * 0.85;
        final outer = position + ui.Offset(cos(a), sin(a)) * coreR * 1.7;
        canvas.drawLine(inner, outer, stroke);
      }
      break;

    case 'Dark':
      // Inward spiral — black hole reads.
      stroke
        ..color = color.withValues(alpha: 0.88 * pulse)
        ..strokeWidth = 1.6 * vs;
      final spiral = ui.Path();
      const spiralPts = 28;
      for (var i = 0; i < spiralPts; i++) {
        final t = i / (spiralPts - 1);
        final a = t * pi * 4 - time * 0.6;
        final r = coreR * 1.6 * (1 - t * 0.95);
        final p = position + ui.Offset(cos(a), sin(a)) * r;
        if (i == 0) {
          spiral.moveTo(p.dx, p.dy);
        } else {
          spiral.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(spiral, stroke);
      fillPaint.color = const ui.Color(
        0xFF000000,
      ).withValues(alpha: 0.6 * pulse);
      canvas.drawCircle(position, coreR * 0.45, fillPaint);
      break;

    case 'Spirit':
      // Drifting wisps — three soft orbs orbiting.
      for (var i = 0; i < 3; i++) {
        final a = time * 0.55 + i * (pi * 2 / 3);
        final p = position + ui.Offset(cos(a), sin(a)) * coreR * 1.0;
        fillPaint.color = white.withValues(alpha: 0.65 * pulse);
        canvas.drawCircle(p, coreR * 0.5, fillPaint);
        fillPaint.color = color.withValues(alpha: 0.55 * pulse);
        canvas.drawCircle(p, coreR * 0.32, fillPaint);
      }
      fillPaint.color = white.withValues(alpha: 0.75 * pulse);
      canvas.drawCircle(position, coreR * 0.42, fillPaint);
      break;

    case 'Poison':
    case 'Steam':
    case 'Mud':
      // Bubbling cloud — three offset puffs.
      for (var i = 0; i < 3; i++) {
        final a = i * (pi * 2 / 3) + sin(time * 1.4 + i) * 0.3;
        final off = ui.Offset(cos(a), sin(a)) * coreR * 0.6;
        fillPaint.color = color.withValues(alpha: 0.6 * pulse);
        canvas.drawCircle(position + off, coreR * 0.85, fillPaint);
      }
      fillPaint.color = white.withValues(alpha: 0.5 * pulse);
      canvas.drawCircle(position, coreR * 0.4, fillPaint);
      break;

    case 'Earth':
      // Stone cluster — chunky polygon.
      final rock = ui.Path();
      const sides = 7;
      for (var i = 0; i < sides; i++) {
        final a = i * (pi * 2 / sides);
        final r = coreR * (1.0 + 0.35 * sin(i * 1.3));
        final p = position + ui.Offset(cos(a), sin(a)) * r;
        if (i == 0) {
          rock.moveTo(p.dx, p.dy);
        } else {
          rock.lineTo(p.dx, p.dy);
        }
      }
      rock.close();
      fillPaint.color = color.withValues(alpha: 0.85 * pulse);
      canvas.drawPath(rock, fillPaint);
      stroke
        ..color = white.withValues(alpha: 0.4 * pulse)
        ..strokeWidth = 1.2 * vs;
      canvas.drawPath(rock, stroke);
      break;

    case 'Water':
      // Concentric ripple rings.
      stroke
        ..color = color.withValues(alpha: 0.7 * pulse)
        ..strokeWidth = 1.4 * vs;
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(position, coreR * (0.6 + i * 0.45), stroke);
      }
      fillPaint.color = white.withValues(alpha: 0.6 * pulse);
      canvas.drawCircle(position, coreR * 0.4, fillPaint);
      break;

    case 'Blood':
      // Pulsing irregular blob with a darker core.
      final blobPath = ui.Path();
      const lobes = 9;
      for (var i = 0; i < lobes; i++) {
        final a = i * (pi * 2 / lobes);
        final r = coreR * (1.05 + 0.18 * sin(time * 2.4 + i * 1.2));
        final p = position + ui.Offset(cos(a), sin(a)) * r;
        if (i == 0) {
          blobPath.moveTo(p.dx, p.dy);
        } else {
          blobPath.lineTo(p.dx, p.dy);
        }
      }
      blobPath.close();
      fillPaint.color = color.withValues(alpha: 0.78 * pulse);
      canvas.drawPath(blobPath, fillPaint);
      fillPaint.color = const ui.Color(
        0xFF400000,
      ).withValues(alpha: 0.55 * pulse);
      canvas.drawCircle(position, coreR * 0.5, fillPaint);
      break;

    case 'Air':
      // Spiraling streamers — three curving arcs.
      stroke
        ..color = color.withValues(alpha: 0.65 * pulse)
        ..strokeWidth = 1.5 * vs;
      for (var i = 0; i < 3; i++) {
        final base = i * (pi * 2 / 3) + time * 0.4;
        final path = ui.Path();
        const segs = 14;
        for (var j = 0; j < segs; j++) {
          final t = j / (segs - 1);
          final a = base + t * pi * 1.2;
          final r = coreR * (0.4 + t * 1.2);
          final p = position + ui.Offset(cos(a), sin(a)) * r;
          if (j == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(path, stroke);
      }
      break;

    case 'Dust':
      // Scattered specks orbiting at varying radii.
      for (var i = 0; i < 9; i++) {
        final a = i * (pi * 2 / 9) + time * 0.35;
        final r = coreR * (0.6 + (i % 3) * 0.45);
        final p = position + ui.Offset(cos(a), sin(a)) * r;
        fillPaint.color = color.withValues(alpha: 0.7 * pulse);
        canvas.drawCircle(p, 1.5 * vs, fillPaint);
      }
      fillPaint.color = white.withValues(alpha: 0.45 * pulse);
      canvas.drawCircle(position, coreR * 0.35, fillPaint);
      break;

    default:
      // Fallback: original 8-point sigil for any element not specialized.
      final points = List<ui.Offset>.generate(8, (i) {
        final a = time * 0.22 + i * pi / 4;
        final r = i.isEven ? coreR * 1.35 : coreR * 0.68;
        return position + ui.Offset(cos(a), sin(a)) * r;
      });
      final sigil = ui.Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        sigil.lineTo(points[i].dx, points[i].dy);
      }
      sigil.close();
      fillPaint.color = color.withValues(alpha: 0.78);
      canvas.drawPath(sigil, fillPaint);
      fillPaint.color = white.withValues(alpha: 0.72 * pulse);
      canvas.drawCircle(position, coreR * 0.58, fillPaint);
  }
}

bool drawMaskElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  if (projectile.visualStyle != ProjectileVisualStyle.sigil) {
    return false;
  }

  final element = projectile.element;
  if (element == null) return false;

  // Stationary placements with a tick effect (Pip Fire pools, Pip
  // Dust clouds, Mud trail puffs, Pip Poison line segments, Plant
  // vine zones, etc.) deserve the rich ground-zone art too — without
  // this, they fall back to a generic colored circle.
  final hasGroundZoneSignal =
      projectile.stationary &&
      projectile.tickEffect != AbilityEffectKind.none;
  final hasMaskSignals =
      hasGroundZoneSignal ||
      projectile.decoy ||
      projectile.tauntRadius > 0 ||
      projectile.snareRadius > 0 ||
      projectile.deathExplosionCount > 0;
  if (!hasMaskSignals) return false;

  final pulse = 0.72 + 0.28 * sin(time * 4.3 + projectile.life * 1.7);
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.42)!;
  // Soft outer glow sized to the gameplay zone, not the small core.
  final glowR = max(
    24.0,
    max(projectile.snareRadius, projectile.effectRadius),
  ).clamp(24.0, 260.0).toDouble();
  final softGlow = ui.Paint()
    ..color = color.withValues(alpha: 0.10 * pulse)
    ..maskFilter = null;
  canvas.drawCircle(position, glowR * 1.05, softGlow);

  // Modern game-style ground-zone trap visual (pool, crystal cluster,
  // ice pillar, etc.) sized to the gameplay radius. Replaces the
  // small abstract sigil that made every mask look the same.
  _drawMaskGroundZone(
    canvas: canvas,
    projectile: projectile,
    position: position,
    color: color,
    white: white,
    time: time,
  );

  return true;
}

bool drawLetElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  final element = projectile.element;
  if (element == null) return false;

  final isLetProjectile =
      projectile.visualStyle == ProjectileVisualStyle.meteor ||
      projectile.visualStyle == ProjectileVisualStyle.letShard ||
      (projectile.stationary &&
          !projectile.decoy &&
          (projectile.trailInterval > 0 ||
              projectile.snareRadius > 0 ||
              projectile.tauntRadius > 0));
  if (!isLetProjectile) return false;

  if (projectile.stationary && !projectile.decoy) {
    _drawLetFallout(canvas, projectile, position, color, element, time);
    return true;
  }

  if (projectile.visualStyle == ProjectileVisualStyle.meteor) {
    _drawSkyfallMeteor(canvas, projectile, position, color, time);
    return true;
  }

  _drawLetElementOverlay(canvas, projectile, position, color, element, time);
  return false;
}

void _drawSkyfallMeteor(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  ui.Color color,
  double time,
) {
  final vs = projectile.visualScale.clamp(1.2, 4.8).toDouble();
  // Trail trails the meteor's actual travel direction. Previous code
  // baked in a fixed upper-right "sky" bias that ignored angle.
  final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
  final dirLen = dir.distance;
  final travelDir = dirLen > 0.01 ? dir / dirLen : const ui.Offset(1, 0);
  final descent = 38.0 * vs;
  final trailStart = position - travelDir * descent;
  final pulse = 0.78 + 0.22 * sin(time * 6.0 + projectile.life * 1.5);

  // Single gradient comet tail behind the meteor, fading to transparent.
  final trailPaint = ui.Paint()
    ..shader = ui.Gradient.linear(
      trailStart,
      position,
      [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.55 * pulse),
      ],
      const [0.0, 1.0],
    )
    ..strokeWidth = 5.5 * vs
    ..strokeCap = ui.StrokeCap.round;
  canvas.drawLine(trailStart, position, trailPaint);

  // Soft outer halo + bright core. Two paints, not seven.
  canvas.drawCircle(
    position,
    7.5 * vs,
    ui.Paint()..color = color.withValues(alpha: 0.30 * pulse),
  );
  canvas.drawCircle(
    position,
    4.6 * vs,
    ui.Paint()..color = color.withValues(alpha: 0.92),
  );
  // Single white-hot core pip — gives the meteor a bright center.
  canvas.drawCircle(
    position,
    1.8 * vs,
    ui.Paint()
      ..color = const ui.Color(0xFFFFF5DC).withValues(alpha: 0.85 * pulse),
  );

  // Element-specific accents on the falling meteor so each one reads
  // distinct mid-fall (lava drips, ice spikes, lightning crackle, etc).
  final element = projectile.element ?? '';
  switch (element) {
    case 'Lava':
    case 'Fire':
      // Trailing ember sparks behind the meteor along its real travel
      // direction.
      for (var i = 0; i < 3; i++) {
        final t = (time * 1.4 + i * 0.33) % 1.0;
        final p = position - travelDir * (descent * 0.2 + descent * 0.5 * t);
        canvas.drawCircle(
          p + ui.Offset(-travelDir.dy, travelDir.dx) * sin(t * 6) * 2.5,
          1.8 * vs * (1 - t),
          ui.Paint()
            ..color = const ui.Color(
              0xFFFFB050,
            ).withValues(alpha: (1 - t) * 0.78),
        );
      }
      break;
    case 'Ice':
      // Frosted spikes radiating from the meteor.
      final spike = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.4 * vs
        ..color = const ui.Color(0xFFCFEAFF).withValues(alpha: 0.75);
      for (var i = 0; i < 6; i++) {
        final a = i * (pi / 3) + time * 0.1;
        canvas.drawLine(
          position + ui.Offset(cos(a), sin(a)) * 4.0 * vs,
          position + ui.Offset(cos(a), sin(a)) * 9.5 * vs,
          spike,
        );
      }
      break;
    case 'Lightning':
      // Erratic lightning arcs around the core.
      final arc = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.6 * vs
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.85);
      for (var i = 0; i < 3; i++) {
        final a1 = i * (pi * 2 / 3) + sin(time * 7 + i) * 0.5;
        final a2 = a1 + pi + sin(time * 9 + i) * 0.4;
        final p1 = position + ui.Offset(cos(a1), sin(a1)) * 7.0 * vs;
        final p2 = position + ui.Offset(cos(a2), sin(a2)) * 8.5 * vs;
        final mid = ui.Offset(
          (p1.dx + p2.dx) * 0.5 + sin(time * 12 + i) * 3 * vs,
          (p1.dy + p2.dy) * 0.5 + cos(time * 12 + i) * 3 * vs,
        );
        canvas.drawLine(p1, mid, arc);
        canvas.drawLine(mid, p2, arc);
      }
      break;
    case 'Dark':
      // Dark void pulling light inward — purple ring.
      canvas.drawCircle(
        position,
        9.5 * vs,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.6 * vs
          ..color = const ui.Color(0xFF6E22A8).withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        position,
        4.2 * vs,
        ui.Paint()..color = const ui.Color(0xFF000000).withValues(alpha: 0.78),
      );
      break;
    case 'Plant':
      // Vine wraps spiraling on the meteor surface.
      final vine = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.4 * vs
        ..color = const ui.Color(0xFF3E8F38).withValues(alpha: 0.85);
      for (var i = 0; i < 3; i++) {
        final a = time * 0.7 + i * (pi * 2 / 3);
        final p1 = position + ui.Offset(cos(a), sin(a)) * 4.0 * vs;
        final p2 = position + ui.Offset(cos(a + pi), sin(a + pi)) * 4.0 * vs;
        canvas.drawLine(p1, p2, vine);
      }
      break;
    case 'Spirit':
      // Ghost flicker — small wisps orbiting.
      for (var i = 0; i < 3; i++) {
        final a = time * 1.3 + i * (pi * 2 / 3);
        final p = position + ui.Offset(cos(a), sin(a)) * 8.0 * vs;
        canvas.drawCircle(
          p,
          1.6 * vs,
          ui.Paint()
            ..color = const ui.Color(0xFFE6CCFF).withValues(alpha: 0.78),
        );
      }
      break;
    case 'Light':
      // Holy halo with 4 rotating rays — keep the read clean.
      final ray = ui.Paint()
        ..strokeWidth = 1.0 * vs
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.65);
      for (var i = 0; i < 4; i++) {
        final a = i * (pi / 2) + time * 0.15;
        canvas.drawLine(
          position + ui.Offset(cos(a), sin(a)) * 6.0 * vs,
          position + ui.Offset(cos(a), sin(a)) * 10.5 * vs,
          ray,
        );
      }
      break;
    case 'Crystal':
      // Faceted crystal ring around the meteor.
      final hex = ui.Path();
      for (var i = 0; i < 6; i++) {
        final a = i * (pi / 3) + time * 0.08;
        final p = position + ui.Offset(cos(a), sin(a)) * 8.5 * vs;
        if (i == 0) {
          hex.moveTo(p.dx, p.dy);
        } else {
          hex.lineTo(p.dx, p.dy);
        }
      }
      hex.close();
      canvas.drawPath(
        hex,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.4 * vs
          ..color = color.withValues(alpha: 0.78),
      );
      break;
  }
}

void drawProjectileRoleOverlay({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
}) {
  final element = projectile.element;
  if (element == null) return;

  final vs = projectile.visualScale
      .clamp(
        0.75,
        projectile.visualStyle == ProjectileVisualStyle.mysticOrbital
            ? 3.5
            : 2.8,
      )
      .toDouble();
  final pulse = 0.76 + 0.24 * sin(time * 4.4 + projectile.life * 1.3);
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.45)!;

  if (projectile.tauntRadius > 0) {
    final tauntR = (projectile.tauntRadius * 0.14).clamp(16.0, 84.0) * vs;
    final ring = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.25 * vs
      ..strokeCap = ui.StrokeCap.round
      ..color = white.withValues(alpha: 0.34 * pulse);
    canvas.drawCircle(position, tauntR, ring);
    for (var i = 0; i < 8; i++) {
      final a = time * 0.7 + i * pi * 2 / 8;
      final inner = position + ui.Offset(cos(a), sin(a)) * (tauntR * 0.82);
      final outer = position + ui.Offset(cos(a), sin(a)) * tauntR;
      canvas.drawLine(
        inner,
        outer,
        ui.Paint()
          ..color = white.withValues(alpha: 0.42 * pulse)
          ..strokeWidth = 1.0 * vs
          ..strokeCap = ui.StrokeCap.round,
      );
    }
  }

  if (projectile.snareRadius > 0) {
    final snareR = (projectile.snareRadius * 0.17).clamp(14.0, 74.0) * vs;
    canvas.drawCircle(
      position,
      snareR,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.0 * vs
        ..color = color.withValues(alpha: 0.24 * pulse),
    );

    if (element == 'Ice') {
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 + time * 0.12;
        final inner = position + ui.Offset(cos(a), sin(a)) * (snareR * 0.44);
        final outer = position + ui.Offset(cos(a), sin(a)) * snareR;
        canvas.drawLine(
          inner,
          outer,
          ui.Paint()
            ..color = const ui.Color(0xFFE9FBFF).withValues(alpha: 0.5 * pulse)
            ..strokeWidth = 1.0 * vs
            ..strokeCap = ui.StrokeCap.round,
        );
      }
    }
  }

  if (projectile.interceptCharges > 0) {
    final guardR = (10.0 + projectile.interceptCharges * 1.8) * vs;
    final sweep = pi * 0.45;
    final arcPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.4 * vs
      ..strokeCap = ui.StrokeCap.round
      ..color = white.withValues(alpha: 0.52 * pulse);
    for (var i = 0; i < 3; i++) {
      final start = time * 0.7 + i * pi * 2 / 3;
      canvas.drawArc(
        ui.Rect.fromCircle(center: position, radius: guardR),
        start,
        sweep,
        false,
        arcPaint,
      );
    }
  }

  if (projectile.turretInterval > 0) {
    final turretR = (6.0 + projectile.radiusMultiplier * 2.2) * vs;
    final path = ui.Path();
    for (var i = 0; i < 4; i++) {
      final a = time * 0.85 + i * pi / 2 + pi / 4;
      final p = position + ui.Offset(cos(a), sin(a)) * turretR;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.1 * vs
        ..color = color.withValues(alpha: 0.34 * pulse),
    );
  }

  final isHealingOrbit =
      (projectile.visualStyle == ProjectileVisualStyle.kinOrbital ||
          projectile.visualStyle == ProjectileVisualStyle.mysticOrbital) &&
      (projectile.followShipOrbit ||
          projectile.transferToShipOrbit ||
          projectile.holdOrbit ||
          projectile.turretInterval > 0) &&
      (element == 'Light' ||
          element == 'Water' ||
          element == 'Plant' ||
          element == 'Blood' ||
          element == 'Steam');
  if (isHealingOrbit) {
    final healColor = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!;
    final rise = (time * 18.0) % (10.0 * vs);
    for (var i = 0; i < 3; i++) {
      final x = (i - 1) * 3.5 * vs;
      final y = -rise - i * 2.8 * vs;
      canvas.drawCircle(
        position + ui.Offset(x, y),
        0.95 * vs,
        ui.Paint()
          ..color = healColor.withValues(alpha: 0.55 - i * 0.1)
          ..maskFilter = null,
      );
    }
    final crossPaint = ui.Paint()
      ..color = healColor.withValues(alpha: 0.42 * pulse)
      ..strokeWidth = 1.0 * vs
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawLine(
      position + ui.Offset(0, -3.0 * vs),
      position + ui.Offset(0, 3.0 * vs),
      crossPaint,
    );
    canvas.drawLine(
      position + ui.Offset(-3.0 * vs, 0),
      position + ui.Offset(3.0 * vs, 0),
      crossPaint,
    );
  }
}

void _drawLetFallout(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  ui.Color color,
  String element,
  double time,
) {
  final vs = projectile.visualScale.clamp(0.7, 3.2).toDouble();
  // Use the actual gameplay zone radius (effect/snare/taunt) so the
  // visual matches the area the trap actually affects — ground-zone
  // style instead of a tiny floating sigil.
  final radius = max(
    18.0 * vs,
    [
      projectile.effectRadius,
      projectile.snareRadius * 0.95,
      projectile.tauntRadius * 0.55,
    ].fold<double>(0, (a, b) => max(a, b)),
  ).clamp(18.0, 220.0).toDouble();
  final pulse = 0.76 + 0.24 * sin(time * 3.0 + projectile.life * 1.7);
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.42)!;
  // Soft outer glow at the zone size so it reads as a terrain effect.
  final outerGlow = ui.Paint()
    ..color = color.withValues(alpha: 0.10 * pulse)
    ..maskFilter = null;
  canvas.drawCircle(position, radius * 1.05, outerGlow);
  final soft = ui.Paint()
    ..color = color.withValues(alpha: 0.13 * pulse)
    ..maskFilter = null;

  // Delegate to richer per-element painters where we have one. The
  // legacy small-art branches below are still used for elements that
  // don't have a dedicated zone painter yet.
  switch (element) {
    case 'Poison':
      _paintPoisonPool(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Lava':
      _paintLavaPool(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Mud':
      _paintMudPool(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Water':
      _paintWaterPool(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Fire':
      _paintFireZone(canvas, position, radius, color, white, time, pulse, vs);
      return;
    case 'Plant':
      _paintPlantZone(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Crystal':
      _paintCrystalCluster(
        canvas,
        position,
        radius,
        color,
        white,
        time,
        pulse,
        vs,
      );
      return;
    case 'Ice':
      _paintIcePillar(canvas, position, radius, color, white, time, pulse, vs);
      return;
    case 'Lightning':
      _paintLightningField(
        canvas,
        position,
        radius,
        color,
        white,
        time,
        pulse,
        vs,
      );
      return;
    case 'Steam':
      _paintSteamGeyser(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Light':
      _paintLightVoid(canvas, position, radius, color, white, time, pulse, vs);
      return;
    case 'Dark':
      _paintDarkVoid(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Spirit':
      _paintSpiritWisp(canvas, position, radius, color, white, time, pulse, vs);
      return;
    case 'Blood':
      _paintBloodBlob(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Earth':
      _paintEarthPool(canvas, position, radius, color, time, pulse, vs);
      return;
    case 'Air':
      _paintAirGust(canvas, position, radius, color, white, time, pulse, vs);
      return;
    case 'Dust':
      _paintDustField(canvas, position, radius, color, time, pulse, vs);
      return;
  }

  // Fallback (shouldn't trigger — every element above is handled).
  switch (element) {
    case 'Fire':
      _drawGlowPool(canvas, position, color, radius, pulse);
      for (var i = 0; i < 5; i++) {
        final a = time * 0.4 + i * pi * 2 / 5;
        canvas.drawLine(
          position + ui.Offset(cos(a), sin(a)) * radius * 0.25,
          position + ui.Offset(cos(a), sin(a)) * radius * 1.05,
          ui.Paint()
            ..color = const ui.Color(0xFFFFD6A6).withValues(alpha: 0.28)
            ..strokeWidth = 1.0 * vs
            ..strokeCap = ui.StrokeCap.round,
        );
      }
      break;
    case 'Lava':
      _drawGlowPool(canvas, position, color, radius * 1.25, pulse);
      for (var i = 0; i < 4; i++) {
        final a = time * 0.25 + i * pi / 2;
        final start = position + ui.Offset(cos(a), sin(a)) * radius * 0.25;
        final mid = position + ui.Offset(cos(a + 0.25), sin(a + 0.25)) * radius;
        final path = ui.Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid.dx, mid.dy);
        canvas.drawPath(
          path,
          ui.Paint()
            ..color = const ui.Color(0xFFFFC266).withValues(alpha: 0.52)
            ..strokeWidth = 1.8 * vs
            ..strokeCap = ui.StrokeCap.round,
        );
      }
      break;
    case 'Water':
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          position,
          radius * (0.55 + i * 0.32) * pulse,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.1 * vs
            ..color = color.withValues(alpha: 0.34 - i * 0.08),
        );
      }
      break;
    case 'Ice':
      _drawFrostStar(canvas, position, color, radius, vs, time);
      break;
    case 'Steam':
      for (var i = 0; i < 5; i++) {
        final a = i * pi * 2 / 5 + time * 0.2;
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * radius * 0.35,
          radius * (0.42 + i * 0.045),
          soft,
        );
      }
      break;
    case 'Earth':
      _drawCrackedPlate(canvas, position, color, radius, vs, time);
      break;
    case 'Mud':
      canvas.drawCircle(
        position,
        radius * 1.2,
        ui.Paint()
          ..color = color.withValues(alpha: 0.26)
          ..maskFilter = null,
      );
      canvas.drawCircle(
        position,
        radius * 0.55,
        ui.Paint()..color = color.withValues(alpha: 0.36),
      );
      break;
    case 'Dust':
      _drawDustCloud(canvas, position, color, radius, vs, time);
      break;
    case 'Crystal':
      _drawCrystalSigil(canvas, position, color, radius, vs, time);
      break;
    case 'Air':
      _drawAirSwirl(canvas, position, color, radius, vs, time);
      break;
    case 'Plant':
      _drawVinePatch(canvas, position, color, radius, vs, time);
      break;
    case 'Poison':
      canvas.drawCircle(position, radius * 1.2, soft);
      for (var i = 0; i < 6; i++) {
        final a = time * 0.5 + i * pi * 2 / 6;
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * radius * (0.35 + i * 0.04),
          1.4 * vs,
          ui.Paint()
            ..color = const ui.Color(0xFFD98CFF).withValues(alpha: 0.42),
        );
      }
      break;
    case 'Spirit':
      _drawSpiritHalo(canvas, position, color, radius, vs, time);
      break;
    case 'Dark':
      canvas.drawCircle(
        position,
        radius * 1.15,
        ui.Paint()
          ..color = const ui.Color(0xFF05020A).withValues(alpha: 0.72)
          ..maskFilter = null,
      );
      canvas.drawCircle(
        position,
        radius * 0.82 * pulse,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.4 * vs
          ..color = color.withValues(alpha: 0.62),
      );
      for (var i = 0; i < 5; i++) {
        final a = -time * 0.8 + i * pi * 2 / 5;
        canvas.drawLine(
          position + ui.Offset(cos(a), sin(a)) * radius * 0.95,
          position + ui.Offset(cos(a + 0.35), sin(a + 0.35)) * radius * 0.35,
          ui.Paint()
            ..color = color.withValues(alpha: 0.28)
            ..strokeWidth = 1.0 * vs
            ..strokeCap = ui.StrokeCap.round,
        );
      }
      break;
    case 'Light':
      _drawLightCrown(canvas, position, color, radius, vs, time);
      break;
    case 'Blood':
      canvas.drawCircle(position, radius, soft);
      canvas.drawCircle(
        position,
        radius * 0.66 * pulse,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.8 * vs
          ..color = color.withValues(alpha: 0.58),
      );
      canvas.drawCircle(
        position,
        radius * 0.28,
        ui.Paint()..color = const ui.Color(0xFFFFB4B4).withValues(alpha: 0.48),
      );
      break;
    default:
      _drawGlowPool(canvas, position, color, radius, pulse);
  }
}

void _drawLetElementOverlay(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  ui.Color color,
  String element,
  double time,
) {
  if (projectile.visualStyle == ProjectileVisualStyle.meteor) return;
  final vs = projectile.visualScale.clamp(0.65, 3.0).toDouble();
  final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
  final perp = ui.Offset(-dir.dy, dir.dx);
  final pulse = 0.75 + 0.25 * sin(time * 4.0 + projectile.life);

  switch (element) {
    case 'Water':
      for (var side in [-1.0, 1.0]) {
        final path = ui.Path()
          ..moveTo(
            position.dx - dir.dx * 10 * vs + perp.dx * side * 3 * vs,
            position.dy - dir.dy * 10 * vs + perp.dy * side * 3 * vs,
          )
          ..quadraticBezierTo(
            position.dx - dir.dx * 1 * vs + perp.dx * side * 7 * vs,
            position.dy - dir.dy * 1 * vs + perp.dy * side * 7 * vs,
            position.dx + dir.dx * 10 * vs,
            position.dy + dir.dy * 10 * vs,
          );
        canvas.drawPath(
          path,
          ui.Paint()
            ..color = color.withValues(alpha: 0.34)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.4 * vs
            ..strokeCap = ui.StrokeCap.round,
        );
      }
      break;
    case 'Lightning':
      final bolt = ui.Path()
        ..moveTo(position.dx - dir.dx * 13 * vs, position.dy - dir.dy * 13 * vs)
        ..lineTo(
          position.dx - dir.dx * 4 * vs + perp.dx * 3 * vs,
          position.dy - dir.dy * 4 * vs + perp.dy * 3 * vs,
        )
        ..lineTo(
          position.dx + dir.dx * 3 * vs - perp.dx * 3 * vs,
          position.dy + dir.dy * 3 * vs - perp.dy * 3 * vs,
        )
        ..lineTo(
          position.dx + dir.dx * 12 * vs,
          position.dy + dir.dy * 12 * vs,
        );
      canvas.drawPath(
        bolt,
        ui.Paint()
          ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.82)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.4 * vs
          ..strokeCap = ui.StrokeCap.round
          ..maskFilter = null,
      );
      break;
    case 'Dust':
      for (var i = 0; i < 5; i++) {
        final a = time * 1.7 + i * pi * 2 / 5;
        canvas.drawCircle(
          position - dir * (5.0 * vs) + ui.Offset(cos(a), sin(a)) * 4.5 * vs,
          0.9 * vs,
          ui.Paint()..color = color.withValues(alpha: 0.42),
        );
      }
      break;
    case 'Air':
      _drawAirSwirl(canvas, position, color, 7.0 * vs, vs, time);
      break;
    case 'Plant':
      _drawVinePatch(canvas, position, color, 6.0 * vs, vs, time);
      break;
    case 'Spirit':
      _drawSpiritHalo(canvas, position, color, 7.0 * vs, vs, time);
      break;
    case 'Light':
      _drawLightCrown(canvas, position, color, 6.0 * vs, vs, time);
      break;
    case 'Blood':
      canvas.drawCircle(
        position,
        6.5 * vs * pulse,
        ui.Paint()
          ..color = color.withValues(alpha: 0.16)
          ..maskFilter = null,
      );
      break;
    case 'Crystal':
      _drawCrystalSigil(canvas, position, color, 6.0 * vs, vs, time);
      break;
  }
}

void _drawGlowPool(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double pulse,
) {
  canvas.drawCircle(
    position,
    radius * 1.15 * pulse,
    ui.Paint()
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = null,
  );
  canvas.drawCircle(
    position,
    radius * 0.58,
    ui.Paint()..color = color.withValues(alpha: 0.22),
  );
}

void _drawFrostStar(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double vs,
  double time,
) {
  canvas.drawCircle(
    position,
    radius,
    ui.Paint()
      ..color = color.withValues(alpha: 0.10)
      ..maskFilter = null,
  );
  for (var i = 0; i < 6; i++) {
    final a = time * 0.08 + i * pi / 3;
    canvas.drawLine(
      position - ui.Offset(cos(a), sin(a)) * radius * 0.55,
      position + ui.Offset(cos(a), sin(a)) * radius,
      ui.Paint()
        ..color = const ui.Color(0xFFE9FBFF).withValues(alpha: 0.48)
        ..strokeWidth = 0.9 * vs
        ..strokeCap = ui.StrokeCap.round,
    );
  }
}

void _drawCrackedPlate(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double vs,
  double time,
) {
  final plateFill = ui.Paint()..color = color.withValues(alpha: 0.16);
  final crustStroke = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.0 * vs
    ..color = const ui.Color(0xFFE0C7A6).withValues(alpha: 0.44)
    ..strokeCap = ui.StrokeCap.round;
  final debrisPaint = ui.Paint()..color = color.withValues(alpha: 0.26);

  final pulse = 0.90 + 0.10 * sin(time * 1.4);
  final outer = ui.Path();
  final points = 9;
  for (var i = 0; i < points; i++) {
    final a = (i / points) * pi * 2 + time * 0.03;
    final jitter = (i.isEven ? 1.0 : 0.82) * pulse;
    final p = position + ui.Offset(cos(a), sin(a)) * radius * jitter;
    if (i == 0) {
      outer.moveTo(p.dx, p.dy);
    } else {
      outer.lineTo(p.dx, p.dy);
    }
  }
  outer.close();
  canvas.drawPath(outer, plateFill);
  canvas.drawPath(outer, crustStroke);

  for (var i = 0; i < 7; i++) {
    final a = time * 0.05 + i * pi * 2 / 7;
    final mid = position + ui.Offset(cos(a), sin(a)) * radius * 0.18;
    final tip = position + ui.Offset(cos(a + 0.16), sin(a + 0.16)) * radius;
    final crack = ui.Path()
      ..moveTo(
        position.dx + cos(a) * radius * 0.05,
        position.dy + sin(a) * radius * 0.05,
      )
      ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
    canvas.drawPath(crack, crustStroke);
  }

  for (var i = 0; i < 6; i++) {
    final a = time * 0.12 + i * pi * 2 / 6;
    final p =
        position + ui.Offset(cos(a), sin(a)) * radius * (0.34 + (i % 2) * 0.28);
    canvas.drawCircle(p, (1.1 + (i % 3) * 0.45) * vs, debrisPaint);
  }
}

void _drawDustCloud(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double vs,
  double time,
) {
  canvas.drawCircle(
    position,
    radius,
    ui.Paint()
      ..color = color.withValues(alpha: 0.10)
      ..maskFilter = null,
  );
  for (var i = 0; i < 9; i++) {
    final a = time * 0.6 + i * pi * 2 / 9;
    canvas.drawCircle(
      position + ui.Offset(cos(a), sin(a)) * radius * (0.24 + (i % 3) * 0.18),
      0.75 * vs,
      ui.Paint()..color = color.withValues(alpha: 0.34),
    );
  }
}

void _drawCrystalSigil(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double vs,
  double time,
) {
  for (var i = 0; i < 4; i++) {
    final a = time * 0.28 + i * pi / 2;
    final path = ui.Path()
      ..moveTo(position.dx + cos(a) * radius, position.dy + sin(a) * radius)
      ..lineTo(
        position.dx + cos(a + pi * 0.18) * radius * 0.38,
        position.dy + sin(a + pi * 0.18) * radius * 0.38,
      )
      ..lineTo(position.dx, position.dy)
      ..close();
    canvas.drawPath(path, ui.Paint()..color = color.withValues(alpha: 0.18));
  }
  canvas.drawCircle(
    position,
    1.8 * vs,
    ui.Paint()..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.55),
  );
}

void _drawAirSwirl(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double vs,
  double time,
) {
  for (var i = 0; i < 2; i++) {
    final start = time * 1.4 + i * pi;
    final path = ui.Path();
    for (var j = 0; j < 12; j++) {
      final t = j / 11;
      final a = start + t * pi * 1.25;
      final r = radius * (0.25 + t * 0.75);
      final p = position + ui.Offset(cos(a), sin(a)) * r;
      if (j == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.1 * vs
        ..strokeCap = ui.StrokeCap.round,
    );
  }
}

void _drawVinePatch(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double vs,
  double time,
) {
  for (var i = 0; i < 4; i++) {
    final a = time * 0.16 + i * pi / 2;
    final end = position + ui.Offset(cos(a), sin(a)) * radius;
    final control =
        position + ui.Offset(cos(a + 0.7), sin(a + 0.7)) * radius * 0.45;
    final path = ui.Path()
      ..moveTo(position.dx, position.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      ui.Paint()
        ..color = color.withValues(alpha: 0.38)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.2 * vs
        ..strokeCap = ui.StrokeCap.round,
    );
    canvas.drawCircle(
      end,
      1.1 * vs,
      ui.Paint()..color = const ui.Color(0xFFB8F7A0).withValues(alpha: 0.62),
    );
  }
}

void _drawSpiritHalo(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double vs,
  double time,
) {
  canvas.drawCircle(
    position,
    radius * (0.8 + 0.12 * sin(time * 2.0)),
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.1 * vs
      ..color = color.withValues(alpha: 0.36)
      ..maskFilter = null,
  );
  canvas.drawCircle(
    position,
    2.2 * vs,
    ui.Paint()..color = const ui.Color(0xFFE6E9FF).withValues(alpha: 0.42),
  );
}

void _drawLightCrown(
  ui.Canvas canvas,
  ui.Offset position,
  ui.Color color,
  double radius,
  double vs,
  double time,
) {
  canvas.drawCircle(
    position,
    radius,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0 * vs
      ..color = color.withValues(alpha: 0.44),
  );
  for (var i = 0; i < 6; i++) {
    final a = time * 0.9 + i * pi / 3;
    canvas.drawCircle(
      position + ui.Offset(cos(a), sin(a)) * radius,
      1.1 * vs,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.74),
    );
  }
}
