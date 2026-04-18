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
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
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
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
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

  final vs = projectile.visualScale.clamp(0.75, 2.6).toDouble();
  final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
  final perp = ui.Offset(-dir.dy, dir.dx);
  final len = (projectile.stationary ? 24.0 : 17.0) * vs;
  final start = position - dir * len;
  final end = position + dir * len;
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.42)!;
  final pulse = 0.72 + 0.28 * sin(time * 5.5 + projectile.life * 2.0);
  final fillPaint = ui.Paint();
  final strokePaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  final linePaint = ui.Paint()..strokeCap = ui.StrokeCap.round;

  void drawCoreSlash({
    double width = 3.0,
    double glowWidth = 8.0,
    double alpha = 0.86,
  }) {
    linePaint
      ..color = color.withValues(alpha: 0.18 * pulse)
      ..strokeWidth = glowWidth * vs
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7);
    canvas.drawLine(start, end, linePaint);
    linePaint
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = width * vs
      ..maskFilter = null;
    canvas.drawLine(start, end, linePaint);
    linePaint
      ..color = white.withValues(alpha: 0.55)
      ..strokeWidth = max(1.0, width * 0.36) * vs
      ..maskFilter = null;
    canvas.drawLine(position - dir * len * 0.55, end, linePaint);
  }

  void drawControlRead({double scale = 1.0}) {
    if (projectile.snareRadius <= 0 &&
        !projectile.stationary &&
        projectile.interceptCharges <= 0) {
      return;
    }
    final radius = projectile.snareRadius > 0
        ? (projectile.snareRadius * 0.32).clamp(18.0, 54.0) * scale
        : (22.0 * vs * scale);
    strokePaint
      ..color = color.withValues(alpha: 0.28 * pulse)
      ..strokeWidth = 1.4 * vs
      ..maskFilter = null;
    canvas.drawCircle(position, radius, strokePaint);
    linePaint
      ..color = color.withValues(alpha: 0.14 * pulse)
      ..strokeWidth = 3.0 * vs
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    canvas.drawLine(
      position - perp * radius * 0.85,
      position + perp * radius * 0.85,
      linePaint,
    );
  }

  switch (element) {
    case 'Fire':
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
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
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
        );
      }
      drawControlRead(scale: 1.05);
      break;
    case 'Earth':
      drawCoreSlash(width: 5.0, glowWidth: 11.0, alpha: 0.82);
      _drawCrackedPlate(canvas, position, color, 18.0 * vs, vs, time);
      drawControlRead(scale: 1.12);
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
      drawCoreSlash(width: 5.4, glowWidth: 12.0, alpha: 0.78);
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: position,
          width: 30.0 * vs,
          height: 17.0 * vs,
        ),
        fillPaint
          ..color = color.withValues(alpha: 0.16)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
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
      drawCoreSlash(width: 3.2, glowWidth: 9.0, alpha: 0.78);
      _drawVinePatch(canvas, position, color, 15.0 * vs, vs, time);
      drawControlRead(scale: 1.12);
      break;
    case 'Poison':
      drawCoreSlash(width: 3.6, glowWidth: 10.0, alpha: 0.74);
      canvas.drawCircle(
        position,
        18.0 * vs * pulse,
        fillPaint
          ..color = color.withValues(alpha: 0.14)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 9),
      );
      drawControlRead(scale: 1.10);
      break;
    case 'Spirit':
      drawCoreSlash(width: 3.0, glowWidth: 9.0, alpha: 0.72);
      _drawSpiritHalo(canvas, position, color, 14.0 * vs, vs, time);
      break;
    case 'Dark':
      drawCoreSlash(width: 4.1, glowWidth: 11.0, alpha: 0.76);
      canvas.drawCircle(
        position,
        17.0 * vs,
        fillPaint
          ..color = const ui.Color(0xFF05020A).withValues(alpha: 0.52)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
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
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, width * 0.18),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10),
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
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 9),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
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

  final hasMaskSignals =
      projectile.decoy ||
      projectile.tauntRadius > 0 ||
      projectile.snareRadius > 0 ||
      projectile.deathExplosionCount > 0;
  if (!hasMaskSignals) return false;

  final vs = projectile.visualScale.clamp(0.72, 2.8).toDouble();
  final pulse = 0.72 + 0.28 * sin(time * 4.3 + projectile.life * 1.7);
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.42)!;
  final coreR = (3.8 * vs * projectile.radiusMultiplier.clamp(0.8, 2.2))
      .clamp(3.8, 16.0)
      .toDouble();
  final tauntR = projectile.tauntRadius > 0
      ? (projectile.tauntRadius * 0.16).clamp(20.0, 98.0) * vs
      : 0.0;
  final snareR = projectile.snareRadius > 0
      ? (projectile.snareRadius * 0.22).clamp(16.0, 86.0) * vs
      : 0.0;
  final controlR = max(tauntR, snareR);

  final softGlow = ui.Paint()
    ..color = color.withValues(alpha: 0.16 * pulse)
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 6.0 * vs);
  final fillPaint = ui.Paint();
  final linePaint = ui.Paint()..strokeCap = ui.StrokeCap.round;
  final ring = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;

  canvas.drawCircle(position, coreR * 2.1, softGlow);

  // Star-sigil core so mask attacks read as traps/lures instead of darts.
  final points = List<ui.Offset>.generate(8, (i) {
    final angle = time * 0.22 + i * pi / 4;
    final r = i.isEven ? coreR * 1.35 : coreR * 0.68;
    return position + ui.Offset(cos(angle), sin(angle)) * r;
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

  if (projectile.decoy) {
    ring
      ..color = color.withValues(alpha: 0.44 * pulse)
      ..strokeWidth = 1.4 * vs;
    canvas.drawCircle(position, coreR * 1.9, ring);
  }

  if (snareR > 0) {
    ring
      ..color = color.withValues(alpha: 0.24 * pulse)
      ..strokeWidth = 1.25 * vs;
    canvas.drawCircle(position, snareR, ring);
    for (var i = 0; i < 6; i++) {
      final a = -time * 0.6 + i * (pi * 2 / 6);
      final inner = position + ui.Offset(cos(a), sin(a)) * (snareR * 0.75);
      final outer = position + ui.Offset(cos(a), sin(a)) * snareR;
      linePaint
        ..color = color.withValues(alpha: 0.28 * pulse)
        ..strokeWidth = 1.0 * vs;
      canvas.drawLine(inner, outer, linePaint);
    }
  }

  if (tauntR > 0) {
    ring
      ..color = white.withValues(alpha: 0.34 * pulse)
      ..strokeWidth = 1.55 * vs;
    canvas.drawCircle(position, tauntR, ring);
    final tickCount = 8;
    for (var i = 0; i < tickCount; i++) {
      final a = time * 0.48 + i * (pi * 2 / tickCount);
      final inner = position + ui.Offset(cos(a), sin(a)) * (tauntR * 0.82);
      final outer = position + ui.Offset(cos(a), sin(a)) * tauntR;
      linePaint
        ..color = white.withValues(alpha: 0.42 * pulse)
        ..strokeWidth = 1.15 * vs;
      canvas.drawLine(inner, outer, linePaint);
    }
  }

  if (projectile.deathExplosionCount > 0 || controlR > 0) {
    final burstR = (controlR > 0 ? controlR * 0.58 : coreR * 4.2)
        .clamp(coreR * 2.3, 64.0 * vs)
        .toDouble();
    ring
      ..color = color.withValues(alpha: 0.20 * pulse)
      ..strokeWidth = 1.0 * vs;
    canvas.drawCircle(position, burstR, ring);
  }

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

  _drawLetElementOverlay(canvas, projectile, position, color, element, time);
  return false;
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
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
  final snareVisualRadius = projectile.snareRadius > 0
      ? projectile.snareRadius * 0.34
      : 0.0;
  final tauntVisualRadius = projectile.tauntRadius > 0
      ? projectile.tauntRadius * 0.22
      : 0.0;
  final radius = max(
    8.5 * vs,
    max(snareVisualRadius, tauntVisualRadius),
  ).clamp(8.0, 76.0);
  final pulse = 0.76 + 0.24 * sin(time * 3.0 + projectile.life * 1.7);
  final soft = ui.Paint()
    ..color = color.withValues(alpha: 0.13 * pulse)
    ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, radius * 0.85);

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
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, radius * 0.35),
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
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, radius * 0.45),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
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
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
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
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, radius * 0.55),
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
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, radius * 0.45),
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
  canvas.drawCircle(
    position,
    radius,
    ui.Paint()..color = color.withValues(alpha: 0.18),
  );
  for (var i = 0; i < 5; i++) {
    final a = time * 0.04 + i * pi * 2 / 5;
    canvas.drawLine(
      position + ui.Offset(cos(a), sin(a)) * radius * 0.18,
      position + ui.Offset(cos(a + 0.12), sin(a + 0.12)) * radius,
      ui.Paint()
        ..color = const ui.Color(0xFFD7C1A5).withValues(alpha: 0.34)
        ..strokeWidth = 1.0 * vs
        ..strokeCap = ui.StrokeCap.round,
    );
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
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, radius * 0.55),
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
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3),
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
