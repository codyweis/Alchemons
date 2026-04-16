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

  void drawTail({double width = 3.2, double alpha = 0.26}) {
    canvas.drawLine(
      tail,
      position,
      ui.Paint()
        ..color = color.withValues(alpha: alpha)
        ..strokeWidth = width * vs
        ..strokeCap = ui.StrokeCap.round
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );
  }

  void drawDartHead({double length = 6.0, double width = 4.0}) {
    final tip = position + dir * length * 0.55 * vs;
    final back = position - dir * length * 0.45 * vs;
    final path = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(back.dx + perp.dx * width * vs, back.dy + perp.dy * width * vs)
      ..lineTo(back.dx - perp.dx * width * vs, back.dy - perp.dy * width * vs)
      ..close();
    canvas.drawPath(path, ui.Paint()..color = color.withValues(alpha: 0.92));
    canvas.drawCircle(
      tip,
      1.3 * vs,
      ui.Paint()..color = white.withValues(alpha: 0.82),
    );
  }

  switch (element) {
    case 'Fire':
      drawTail(width: 5.0, alpha: 0.34);
      for (var i = 0; i < 2; i++) {
        final offset = (i == 0 ? -1.0 : 1.0) * 3.0 * vs;
        canvas.drawCircle(
          tail + perp * offset + dir * (i * 3.0 * vs),
          1.8 * vs,
          ui.Paint()
            ..color = const ui.Color(0xFFFFD28A).withValues(alpha: 0.62),
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
        ui.Paint()
          ..color = white.withValues(alpha: 0.92)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.8 * vs
          ..strokeCap = ui.StrokeCap.round
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
          ui.Paint()
            ..color = color.withValues(alpha: 0.38)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.4 * vs
            ..strokeCap = ui.StrokeCap.round,
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
        ui.Paint()..color = color.withValues(alpha: 0.82),
      );
      for (var i = 0; i < 3; i++) {
        final a = time * 0.2 + i * pi * 2 / 3;
        canvas.drawLine(
          position,
          position + ui.Offset(cos(a), sin(a)) * 5.2 * vs,
          ui.Paint()
            ..color = white.withValues(alpha: 0.30)
            ..strokeWidth = 0.8 * vs,
        );
      }
      break;
    case 'Lava':
      drawTail(width: 5.6, alpha: 0.30);
      canvas.drawCircle(
        position,
        5.4 * vs,
        ui.Paint()..color = color.withValues(alpha: 0.90),
      );
      canvas.drawCircle(
        position + dir * 1.6 * vs - perp * 1.2 * vs,
        1.8 * vs,
        ui.Paint()..color = const ui.Color(0xFFFFE0A0).withValues(alpha: 0.78),
      );
      break;
    case 'Mud':
      drawTail(width: 4.8, alpha: 0.24);
      canvas.drawOval(
        ui.Rect.fromCenter(center: position, width: 9.0 * vs, height: 6.0 * vs),
        ui.Paint()..color = color.withValues(alpha: 0.86),
      );
      break;
    case 'Dust':
      drawTail(width: 2.4, alpha: 0.18);
      for (var i = 0; i < 5; i++) {
        final a = time * 1.7 + i * pi * 2 / 5;
        canvas.drawCircle(
          position - dir * 4.0 * vs + ui.Offset(cos(a), sin(a)) * 4.2 * vs,
          0.85 * vs,
          ui.Paint()..color = color.withValues(alpha: 0.42),
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
      canvas.drawPath(path, ui.Paint()..color = color.withValues(alpha: 0.82));
      canvas.drawCircle(
        position + dir * 1.8 * vs,
        1.4 * vs,
        ui.Paint()..color = white.withValues(alpha: 0.8),
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
          ui.Paint()
            ..color = color.withValues(alpha: 0.30)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.1 * vs
            ..strokeCap = ui.StrokeCap.round,
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
        ui.Paint()
          ..color = color.withValues(alpha: 0.50)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.8 * vs
          ..strokeCap = ui.StrokeCap.round,
      );
      drawDartHead(length: 5.8, width: 3.2);
      break;
    case 'Poison':
      drawTail(width: 3.6, alpha: 0.24);
      canvas.drawCircle(
        position,
        5.2 * vs * pulse,
        ui.Paint()
          ..color = color.withValues(alpha: 0.24)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        position + perp * 2.2 * vs,
        1.3 * vs,
        ui.Paint()..color = const ui.Color(0xFFD98CFF).withValues(alpha: 0.65),
      );
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
        ui.Paint()
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
        ui.Paint()..color = color.withValues(alpha: 0.84),
      );
      canvas.drawCircle(
        position + dir * 1.5 * vs,
        1.8 * vs,
        ui.Paint()..color = const ui.Color(0xFFFFB4B4).withValues(alpha: 0.68),
      );
      break;
    default:
      drawTail();
      drawDartHead();
  }

  if (projectile.bounceCount > 0 || projectile.interceptCharges > 0) {
    canvas.drawCircle(
      position,
      (6.5 + projectile.bounceCount.clamp(0, 4)) * vs,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 0.9 * vs
        ..color = white.withValues(
          alpha: projectile.interceptCharges > 0 ? 0.46 : 0.26,
        ),
    );
  }
  if (projectile.snareRadius > 0) {
    canvas.drawCircle(
      position,
      (projectile.snareRadius * 0.13).clamp(5.5, 12.0) * vs,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.0 * vs
        ..color = color.withValues(alpha: 0.26),
    );
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
