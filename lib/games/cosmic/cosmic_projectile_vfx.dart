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
    // Longer and keener than the call sites ask for.
    //
    // Every element passes a length between 4.8 and 7.0, which built a stubby
    // little wedge — and it used to sit inside a soft halo several times its
    // size, so the shape may as well not have been there. Stretched here
    // rather than at thirteen call sites, and swept back into a barb instead
    // of a flat-based triangle, so the thing reads as a dart at the size it
    // actually draws at.
    final reach = length * 1.45;
    final tip = position + dir * reach * 0.62 * vs;
    final back = position - dir * reach * 0.48 * vs;
    final barb = position - dir * reach * 0.18 * vs;
    final span = perp * width * vs;
    final path = ui.Path()
      ..moveTo(tip.dx, tip.dy)
      // Out to the barb, back to the swept tail, and mirrored — a flat base
      // reads as a triangle, a swept one reads as a point that is travelling.
      ..lineTo(barb.dx + span.dx, barb.dy + span.dy)
      ..lineTo(back.dx + span.dx * 0.30, back.dy + span.dy * 0.30)
      ..lineTo(back.dx - span.dx * 0.30, back.dy - span.dy * 0.30)
      ..lineTo(barb.dx - span.dx, barb.dy - span.dy)
      ..close();
    fillPaint.color = color.withValues(alpha: 0.92);
    canvas.drawPath(path, fillPaint);
    // A hot spine down the middle rather than a blob on the nose, so the
    // brightest part of the dart is its edge.
    linePaint
      ..color = white.withValues(alpha: 0.80)
      ..strokeWidth = 1.15 * vs
      ..maskFilter = null;
    canvas.drawLine(barb, tip, linePaint);
  }

  if (projectile.abilityFamily == 'pip') {
    // Special-only frame: makes pip specials read clearly distinct from
    // basics. Basics share the dart silhouette below but skip this block.
    // Layered translucent circles fake a soft halo without MaskFilter.blur.
    final specialPulse = 0.78 + 0.22 * sin(time * 6.5 + projectile.life * 2.5);

    // A glow with a direction, not a ball.
    //
    // This used to be four concentric translucent circles out to twenty-one
    // times scale, which is several times the dart inside them. Whatever the
    // dart was doing, a pip special read as a soft glowing bead: no axis, no
    // point, and identical across all seventeen elements but for hue. On the
    // one family whose whole identity is a small fast thing that ricochets,
    // the silhouette said "slow floating orb".
    //
    // Stretched along travel instead, so the glow says which way the dart is
    // going and stays out of the way of its shape.
    drawDirectionalBloom(
      canvas: canvas,
      centre: position,
      travelDir: dir,
      length: 13.0 * vs,
      width: 4.6 * vs,
      color: color,
      alpha: 0.30 * specialPulse,
    );

    // Long comet ribbon — visually stretches the projectile so a moving
    // salvo reads as guided missiles, not basic-attack sprinkle.
    final ribbonTail = position - dir * 34.0 * vs;
    canvas.drawLine(
      ribbonTail,
      position,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ribbonTail,
          position,
          [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.34 * specialPulse),
            white.withValues(alpha: 0.62 * specialPulse),
          ],
          const [0.0, 0.55, 1.0],
        )
        ..strokeWidth = 3.4 * vs
        ..strokeCap = ui.StrokeCap.round,
    );

    // How much ricochet is left, drawn on the dart.
    //
    // Bouncing is the family's entire premise and nothing on screen said
    // anything about it — a dart with five bounces banked looked exactly like
    // one on its last. Chevrons stacked behind the head, one per remaining
    // bounce, so a Lightning salvo visibly carries more than a Lava one and
    // every dart visibly spends itself as it chains.
    final banked = projectile.bounceCount.clamp(0, 5);
    for (var i = 0; i < banked; i++) {
      final back = position - dir * (7.0 + i * 4.2) * vs;
      final spanV = perp * (3.0 - i * 0.28) * vs;
      final tipV = dir * 2.6 * vs;
      strokePaint
        ..color = white.withValues(
          alpha: (0.66 - i * 0.09).clamp(0.0, 1.0) * specialPulse,
        )
        ..strokeWidth = 1.25 * vs
        ..maskFilter = null;
      canvas.drawPath(
        ui.Path()
          ..moveTo(back.dx + spanV.dx, back.dy + spanV.dy)
          ..lineTo(back.dx + tipV.dx, back.dy + tipV.dy)
          ..lineTo(back.dx - spanV.dx, back.dy - spanV.dy),
        strokePaint,
      );
    }

    // Element-specific special accent telegraphs the kill/hit identity.
    // Each accent is intentionally cheap (handful of draws, no blur)
    // so a salvo of pip specials stays performant.
    switch (element) {
      case 'Fire':
        // Trailing embers — preview of the fire pool that drops on kill.
        for (var i = 0; i < 3; i++) {
          final t = (time * 1.4 + i * 0.31) % 1.0;
          final emberPos =
              position -
              dir * (10.0 + t * 22.0) * vs +
              perp * sin(time * 4 + i) * 3.0 * vs;
          fillPaint
            ..color = const ui.Color(
              0xFFFFD160,
            ).withValues(alpha: (1 - t) * 0.72)
            ..maskFilter = null;
          canvas.drawCircle(emberPos, 1.6 * vs * (1.0 - t * 0.5), fillPaint);
        }
        break;
      case 'Lightning':
        // Branching sub-arcs — telegraph "double the ricochet" identity.
        for (var i = 0; i < 2; i++) {
          final side = i.isEven ? -1.0 : 1.0;
          final phase = time * 6.0 + i * pi + projectile.life * 4.0;
          final p1 = position - dir * 5.0 * vs + perp * side * 3.0 * vs;
          final p2 =
              position -
              dir * 14.0 * vs +
              perp * side * (8.0 + sin(phase) * 3.0) * vs;
          final p3 = position - dir * 22.0 * vs + perp * side * 4.0 * vs;
          final arc = ui.Path()
            ..moveTo(p1.dx, p1.dy)
            ..lineTo(p2.dx, p2.dy)
            ..lineTo(p3.dx, p3.dy);
          canvas.drawPath(
            arc,
            strokePaint
              ..color = white.withValues(alpha: 0.58 * specialPulse)
              ..strokeWidth = 1.3 * vs
              ..maskFilter = null,
          );
        }
        break;
      case 'Ice':
        // Orbiting frost motes — telegraph freeze on hit.
        for (var i = 0; i < 3; i++) {
          final a = time * 2.2 + i * pi * 2 / 3;
          final p = position + ui.Offset(cos(a), sin(a)) * 9.0 * vs;
          fillPaint
            ..color = white.withValues(alpha: 0.72)
            ..maskFilter = null;
          canvas.drawCircle(p, 1.35 * vs, fillPaint);
        }
        break;
      case 'Crystal':
        // Rotating crystal facets — telegraph taunt crystal on kill.
        for (var i = 0; i < 3; i++) {
          final a = time * 1.6 + i * pi * 2 / 3 + projectile.life;
          final c = position + ui.Offset(cos(a), sin(a)) * 8.0 * vs;
          final facet = ui.Path()
            ..moveTo(c.dx, c.dy - 2.2 * vs)
            ..lineTo(c.dx + 1.7 * vs, c.dy)
            ..lineTo(c.dx, c.dy + 2.2 * vs)
            ..lineTo(c.dx - 1.7 * vs, c.dy)
            ..close();
          fillPaint
            ..color = white.withValues(alpha: 0.62)
            ..maskFilter = null;
          canvas.drawPath(facet, fillPaint);
        }
        break;
      case 'Lava':
        // Dripping molten blobs — heavy "burns on hit" identity.
        for (var i = 0; i < 3; i++) {
          final t = (time * 1.0 + i * 0.4) % 1.0;
          final drip =
              position -
              dir * (8.0 + t * 12.0) * vs +
              perp * sin(time * 3 + i) * 1.5 * vs;
          fillPaint
            ..color = const ui.Color(
              0xFFFFB060,
            ).withValues(alpha: (1 - t) * 0.82)
            ..maskFilter = null;
          canvas.drawCircle(drip, (2.5 - t * 1.2) * vs, fillPaint);
        }
        break;
      case 'Mud':
        // Muddy splash gobs — telegraph the permanent mud-trail tag.
        for (var i = 0; i < 4; i++) {
          final t = (time * 1.1 + i * 0.27) % 1.0;
          final p =
              position -
              dir * (6.0 + t * 16.0) * vs +
              perp * sin(time * 2.0 + i * 1.7) * 4.0 * vs;
          fillPaint
            ..color = color.withValues(alpha: (1 - t) * 0.58)
            ..maskFilter = null;
          canvas.drawCircle(p, (1.9 - t * 0.8) * vs, fillPaint);
        }
        break;
      case 'Plant':
        // Orbiting spores — telegraph alchemy bonus on kill.
        for (var i = 0; i < 4; i++) {
          final a = time * 1.8 + i * pi / 2;
          final p = position + ui.Offset(cos(a), sin(a)) * 7.5 * vs;
          fillPaint
            ..color = const ui.Color(0xFFB0FFB0).withValues(alpha: 0.58)
            ..maskFilter = null;
          canvas.drawCircle(p, 1.25 * vs, fillPaint);
        }
        break;
      case 'Spirit':
        // Trailing wisps — telegraph kill-stacking toward empower window.
        for (var i = 0; i < 3; i++) {
          final t = (time * 0.9 + i * 0.33) % 1.0;
          final p =
              position -
              dir * (8.0 + t * 18.0) * vs +
              perp * sin(time * 2 + i * 2) * 5.0 * vs;
          fillPaint
            ..color = white.withValues(alpha: (1 - t) * 0.55)
            ..maskFilter = null;
          canvas.drawCircle(p, (2.3 - t) * vs, fillPaint);
        }
        break;
      case 'Dust':
        // Scattering motes — telegraph dust cloud on kill.
        for (var i = 0; i < 5; i++) {
          final a = time * 2.5 + i * pi * 2 / 5;
          final p =
              position + ui.Offset(cos(a), sin(a)) * (5.0 + (i % 2) * 3.0) * vs;
          fillPaint
            ..color = color.withValues(alpha: 0.48)
            ..maskFilter = null;
          canvas.drawCircle(p, 0.95 * vs, fillPaint);
        }
        break;
      case 'Air':
        // Spiraling wind streaks behind — telegraph knockback on survivors.
        for (var i = 0; i < 2; i++) {
          final side = i.isEven ? -1.0 : 1.0;
          final streak = ui.Path();
          for (var j = 0; j < 5; j++) {
            final t = j / 4;
            final phase = time * 3.0 + side * 2.0 + t * pi;
            final pt =
                position -
                dir * t * 18.0 * vs +
                perp * side * sin(phase) * 4.5 * vs;
            if (j == 0) {
              streak.moveTo(pt.dx, pt.dy);
            } else {
              streak.lineTo(pt.dx, pt.dy);
            }
          }
          canvas.drawPath(
            streak,
            strokePaint
              ..color = white.withValues(alpha: 0.42 * specialPulse)
              ..strokeWidth = 1.15 * vs
              ..maskFilter = null,
          );
        }
        break;
      case 'Blood':
        // Trailing blood drops — telegraph self-heal on kill.
        for (var i = 0; i < 3; i++) {
          final t = (time * 1.0 + i * 0.33) % 1.0;
          final p =
              position -
              dir * (7.0 + t * 14.0) * vs +
              perp * sin(time * 3 + i) * 2.0 * vs;
          fillPaint
            ..color = const ui.Color(
              0xFFFF6060,
            ).withValues(alpha: (1 - t) * 0.78)
            ..maskFilter = null;
          canvas.drawCircle(p, (1.9 - t * 0.8) * vs, fillPaint);
        }
        break;
      case 'Water':
        // Trailing droplets — telegraph splash chain.
        for (var i = 0; i < 4; i++) {
          final t = (time * 1.2 + i * 0.25) % 1.0;
          final p =
              position -
              dir * (5.0 + t * 15.0) * vs +
              perp * sin(time * 2.5 + i * 1.5) * 4.0 * vs;
          fillPaint
            ..color = color.withValues(alpha: (1 - t) * 0.62)
            ..maskFilter = null;
          canvas.drawCircle(p, (1.7 - t * 0.7) * vs, fillPaint);
        }
        break;
      case 'Steam':
        // Rising steam puffs — telegraph steam cloud / atk-speed ramp.
        for (var i = 0; i < 3; i++) {
          final t = (time * 1.0 + i * 0.4) % 1.0;
          final puff =
              position -
              dir * (4.0 + t * 12.0) * vs +
              perp * sin(time + i) * 3.0 * vs -
              ui.Offset(0, t * 6.0 * vs);
          fillPaint
            ..color = color.withValues(alpha: (1 - t) * 0.34)
            ..maskFilter = null;
          canvas.drawCircle(puff, (3.0 + t * 1.5) * vs, fillPaint);
        }
        break;
      case 'Earth':
        // Tumbling pebbles trailing — heavy hit-hard identity.
        for (var i = 0; i < 3; i++) {
          final t = (time * 1.0 + i * 0.35) % 1.0;
          final p =
              position -
              dir * (8.0 + t * 14.0) * vs +
              perp * sin(time * 4 + i * 2) * 3.0 * vs;
          fillPaint
            ..color = color.withValues(alpha: (1 - t) * 0.72)
            ..maskFilter = null;
          canvas.drawCircle(p, (1.9 - t * 0.6) * vs, fillPaint);
        }
        break;
      case 'Poison':
        // Bubbling particles — telegraph DoT on hit.
        for (var i = 0; i < 4; i++) {
          final a = time * 2.0 + i * pi / 2 + projectile.life;
          final p = position + ui.Offset(cos(a), sin(a)) * 7.0 * vs;
          fillPaint
            ..color = const ui.Color(0xFFC080FF).withValues(alpha: 0.58)
            ..maskFilter = null;
          canvas.drawCircle(p, 1.35 * vs, fillPaint);
        }
        break;
      case 'Light':
        // Radiating sparkles — telegraph orb heal on kill.
        for (var i = 0; i < 6; i++) {
          final a = time * 1.5 + i * pi / 3;
          final p = position + ui.Offset(cos(a), sin(a)) * 10.0 * vs;
          fillPaint
            ..color = white.withValues(alpha: 0.55 * specialPulse)
            ..maskFilter = null;
          canvas.drawCircle(p, 0.95 * vs, fillPaint);
        }
        break;
      default:
        break;
    }
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

  // Remaining bounces used to be told THREE ways at once: a stroked ring sized
  // by the count, a set of dots orbiting the head, and (once the special frame
  // added them) chevrons behind it. Stacked on top of the element accents,
  // every dart ended up wearing a halo of circles and the shape underneath was
  // lost — which is most of why the family read as beads rather than darts.
  //
  // The chevrons are kept because they are the only one of the three that has
  // a direction: they sit behind the head and point the way it is going, so
  // they say "travelling and spending itself" rather than "orbited by rings".
  //
  // Intercept charges keep a ring of their own, below: that one marks a real
  // radius the dart defends, so a circle is the honest shape for it.
  if (projectile.interceptCharges > 0) {
    strokePaint
      ..color = white.withValues(alpha: 0.46)
      ..strokeWidth = 0.9 * vs
      ..maskFilter = null;
    canvas.drawCircle(position, 8.0 * vs, strokePaint);
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
      glowPaint.color = color.withValues(alpha: (0.04 + i * 0.025) * pulse);
      canvas.drawCircle(position, glowR * (0.6 + i * 0.12), glowPaint);
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
        _paintSteamGeyser(
          canvas,
          position,
          radius,
          color,
          time,
          pulse,
          visScale,
        );
        return true;
      case 'Plant':
        // Mane's rooted residue is damaging growth, not a bed.
        _paintPlantZone(
          canvas,
          position,
          radius,
          color,
          time,
          pulse,
          visScale,
          style: PlantZoneStyle.vines,
        );
        return true;
      case 'Lightning':
        _paintLightningField(
          canvas,
          position,
          radius,
          color,
          white,
          time,
          pulse,
          visScale,
        );
        return true;
      case 'Fire':
        _paintFireZone(
          canvas,
          position,
          radius,
          color,
          white,
          time,
          pulse,
          visScale,
        );
        return true;
      case 'Poison':
        _paintPoisonPool(
          canvas,
          position,
          radius,
          color,
          time,
          pulse,
          visScale,
        );
        return true;
      case 'Ice':
        _paintIcePillar(
          canvas,
          position,
          radius,
          color,
          white,
          time,
          pulse,
          visScale,
        );
        return true;
      case 'Water':
        _paintWaterPool(canvas, position, radius, color, time, pulse, visScale);
        return true;
      default:
        // Fall through to the slash renderer below for elements without
        // a dedicated zone painter.
        break;
    }
  }

  final vs = element == 'Light'
      ? projectile.visualScale.clamp(0.75, 24.0).toDouble()
      : projectile.visualScale.clamp(0.75, 3.4).toDouble();
  final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
  final perp = ui.Offset(-dir.dy, dir.dx);
  // Heavier catapult shots — slash body bigger so the projectile feels
  // weighty in flight rather than a thin streak.
  final len = (projectile.stationary ? 32.0 : 26.0) * vs;
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.42)!;
  final pulse = 0.72 + 0.28 * sin(time * 5.5 + projectile.life * 2.0);

  // Motion trail for moving manes — directional gradient streak +
  // staggered afterimage discs. The gradient line gives the soft
  // "motion blur" feel without any MaskFilter.blur (which is a
  // full-screen render pass per draw and expensive at scale).
  if (!projectile.stationary) {
    // The clump of wisps riding behind the blade. Drawn, not spawned into the
    // shared particle pool — see [drawManeTrailWisps].
    drawManeTrailWisps(
      canvas: canvas,
      position: position,
      travelDir: dir,
      color: color,
      time: time,
      scale: vs,
      radiusMultiplier: projectile.radiusMultiplier,
      seed: projectile.life,
    );
    // The slipstream. Three afterimage discs used to stand in for motion, and
    // a chain of concentric circles behind a fast object reads as a caterpillar
    // — it has no direction and no edge.
    //
    // Reuses the Let meteor's wake painter at almost no waviness, which is
    // exactly the contrast between the two families: a falling rock drags a
    // turbulent, meandering plume, a blade fired flat leaves a tight clean
    // slipstream. Same code, opposite end of the same dial.
    final travelUnit = dir.distance > 0.01
        ? dir / dir.distance
        : const ui.Offset(1, 0);
    drawPlumeWake(
      canvas: canvas,
      head: position,
      travelDir: travelUnit,
      length: len * 2.4,
      headWidth: 7.0 * vs,
      color: color,
      time: time,
      alpha: 0.34 * pulse,
      hotColor: white,
      layers: 2,
      seed: projectile.life + projectile.angle,
      waveAmplitude: 0.10,
      waveFrequency: 0.7,
    );
  }

  final fillPaint = ui.Paint();
  final strokePaint = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  final groundedRadius = projectile.snareRadius > 0
      ? (projectile.snareRadius * 0.36).clamp(26.0, 96.0) * vs
      : (24.0 * projectile.radiusMultiplier.clamp(1.0, 3.4) * vs);

  void drawCoreSlash({
    double width = 3.0,
    double glowWidth = 8.0,
    double alpha = 0.86,
    double lengthScale = 1.0,
  }) {
    // A cleave with an edge and a direction.
    //
    // This was three stacked translucent discs plus a disc body plus a centre
    // pip — a fake radial blur. It is cheap, but a stack of concentric circles
    // has no axis and no outline, so eight Mane elements collapsed into the
    // same fuzzy ball separated only by hue, and none of them read as the
    // catapult/piercing cast they are.
    final coreR = (4.5 + glowWidth * 0.45) * vs;
    final scaled = alpha.clamp(0.0, 1.0);
    final travelDir = dir.distance > 0.01
        ? dir / dir.distance
        : const ui.Offset(1, 0);
    // Bloom stretched along travel instead of pooled round the body.
    drawDirectionalBloom(
      canvas: canvas,
      centre: position,
      travelDir: travelDir,
      length: coreR * 2.5 * lengthScale,
      width: coreR * 1.05,
      color: color,
      alpha: 0.26 * scaled * pulse,
    );
    // The blade itself.
    //
    // Length and bank vary per projectile off a hash of its own angle. The fan
    // angles come from the ability's mechanics and are not ours to touch, but a
    // fan of identical blades reads as a splayed hand; uneven ones read as a
    // spray of cuts. Deterministic, so it does not shimmer frame to frame.
    final jitter = (sin(projectile.angle * 12.9898) * 43758.5453);
    final vary = 0.72 + 0.56 * (jitter - jitter.floorToDouble());
    final bladeLen = coreR * 3.4 * vary * lengthScale;
    final bladeWidth = coreR * 0.62;
    // No spin term. The old core rolled on `time`, which is what made every
    // Mane blade read as a tumbling stick rather than something thrown edge-on.
    final blade = buildBladePath(
      centre: position,
      travelDir: travelDir,
      length: bladeLen,
      width: bladeWidth,
      bank: (vary - 1.0) * 0.5,
    );
    // A wider, fainter echo of the same silhouette sitting under the blade, so
    // the edge has some thickness to it without a second hard outline.
    canvas.drawPath(
      buildBladePath(
        centre: position,
        travelDir: travelDir,
        length: bladeLen * 1.16,
        width: bladeWidth * 1.7,
        bank: (vary - 1.0) * 0.5,
      ),
      fillPaint
        ..color = color.withValues(alpha: 0.20 * scaled * pulse)
        ..maskFilter = null,
    );
    // Element colour carries the body. The old fill was `white` — the element
    // hue lerped 42% toward white and then laid down at 0.72 — which washed
    // Lava, Dust and Plant out to the same cream and left hue doing all the
    // work of telling them apart.
    canvas.drawPath(
      blade,
      fillPaint
        ..color = color.withValues(alpha: 0.80 * scaled)
        ..maskFilter = null,
    );
    // A hot spine down the middle, tapering with the blade: the light along the
    // edge, rather than an outline drawn round the whole shape.
    canvas.drawPath(
      buildBladePath(
        centre: position + travelDir * bladeLen * 0.06,
        travelDir: travelDir,
        length: bladeLen * 0.74,
        width: bladeWidth * 0.34,
        bank: (vary - 1.0) * 0.5,
      ),
      fillPaint
        ..color = white.withValues(alpha: 0.85 * scaled * pulse)
        ..maskFilter = null,
    );
  }

  void drawEarthRockProjectile() {
    // Softened — was a solid 13-point rotating silhouette with a hard
    // outline and cracks. Now layered translucent halos in earthy
    // tones, mirroring the soft "particle cluster" feel of the
    // other Mane projectiles. Per-frame survival particles fill in
    // the chunky-rock impression with actual moving particles.
    final rockRadius =
        5.8 * vs * sqrt(projectile.radiusMultiplier.clamp(1.0, 4.6).toDouble());
    final base = ui.Color.lerp(color, const ui.Color(0xFF4A362B), 0.32)!;
    final high = ui.Color.lerp(color, const ui.Color(0xFFE2C6A8), 0.34)!;
    // A boulder, with an outline and a tumble. The halo-ring version had no
    // silhouette at all, which is why the heaviest Mane cast read as the
    // lightest.
    final travelDirE = dir.distance > 0.01
        ? dir / dir.distance
        : const ui.Offset(1, 0);
    drawDirectionalBloom(
      canvas: canvas,
      centre: position,
      travelDir: travelDirE,
      length: rockRadius * 2.2,
      width: rockRadius * 1.1,
      color: base,
      alpha: 0.24 * pulse,
    );
    canvas.drawPath(
      buildTumblingShardPath(
        centre: position,
        radius: rockRadius * 0.95,
        travelDir: travelDirE,
        spin: time * 1.9 + projectile.life,
        elongation: 1.12,
        flatten: 0.92,
      ),
      ui.Paint()
        ..color = base.withValues(alpha: 0.92)
        ..maskFilter = null,
    );
    // Lit leading edge, so the boulder has a face taking the impact.
    drawShardLeadingRim(
      canvas: canvas,
      centre: position,
      radius: rockRadius * 0.93,
      travelDir: travelDirE,
      spin: time * 1.9 + projectile.life,
      color: high.withValues(alpha: 0.75),
      width: 1.8 * vs,
      elongation: 1.12,
      flatten: 0.92,
    );
    // White-hot center pip for visibility.
    canvas.drawCircle(
      position,
      rockRadius * 0.22,
      ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.55)
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
    // Per design feedback: removed the outlined control-read ring
    // ("just let the effects show"). The snare/intercept gameplay
    // still works the same — the indicator outline is just gone.
  }

  switch (element) {
    case 'Fire':
      drawGroundPatch();
      // A fireball with a burning wake, not a ring with a dot in it.
      //
      // This was a filled disc, an off-centre highlight, and a stroked circle
      // pulsing around the outside — which is the exact recipe for a targeting
      // reticle, and it read as UI chrome sitting on the battlefield rather
      // than as the fastest shot in the family.
      drawCoreSlash(width: 3.4, glowWidth: 9.0, alpha: 0.80);
      // Embers shedding off the back, on their own cycles.
      for (var i = 0; i < 4; i++) {
        final t = (time * 1.5 + i * 0.25 + projectile.angle) % 1.0;
        canvas.drawCircle(
          position -
              dir * (len * 0.4 + len * 1.0 * t) +
              perp * sin(time * 3.0 + i * 1.7) * 3.0 * vs * t,
          (2.0 - 1.2 * t) * vs,
          fillPaint
            ..color = const ui.Color(
              0xFFFFB050,
            ).withValues(alpha: (1 - t) * 0.85)
            ..maskFilter = null,
        );
      }
      drawSparkleGlints(
        canvas: canvas,
        centre: position,
        travelDir: dir.distance > 0.01
            ? dir / dir.distance
            : const ui.Offset(1, 0),
        spread: 22.0 * vs,
        size: 2.0 * vs,
        color: const ui.Color(0xFFFFC46A),
        time: time,
        count: 4,
        seed: projectile.angle * 5.0,
        alpha: 0.8,
      );
      drawControlRead(scale: 1.05);
      break;
    case 'Lightning':
      // The shared bolt, the same one the Let meteor and every other discharge
      // in the game use. This was a hand-rolled three-segment polyline stroked
      // hard white — a drawn zigzag with fixed corners, so it never flickered,
      // never branched, and read as a lightning ICON rather than a discharge.
      drawCoreSlash(width: 2.4, glowWidth: 7.2, alpha: 0.62);
      final boltGlow = ui.Color.lerp(color, kLightningBoltGlow, 0.55)!;
      drawLightningBolt(
        canvas,
        position - dir * len * 1.5,
        position + dir * len * 0.6,
        time: time,
        width: 1.1 * vs,
        jitter: 1.9 * vs,
        segmentLength: 5.5 * vs,
        core: kLightningBoltCore,
        glow: boltGlow,
        alpha: 0.92,
        branches: 1,
        glowPasses: 2,
        seed: projectile.angle * 7.0,
      );
      drawLightningCrackle(
        canvas,
        position,
        7.0 * vs,
        time: time,
        count: 2,
        width: 0.9 * vs,
        glow: boltGlow,
        glowPasses: 1,
        seed: projectile.angle * 3.1,
      );
      break;
    case 'Water':
      // A wall, broadside to the direction it is sweeping.
      //
      // These were axis-aligned ovals — wide in screen-x regardless of where
      // the shot was going. The comment claimed "perpendicular to travel", but
      // Rect.fromCenter has no idea what travel is, so the only time the wall
      // read as a wall was when it happened to be moving vertically. Fired
      // sideways, which is most of the time, it was a bright pip inside
      // concentric rings: an eye.
      //
      // Rotated into the travel frame it is broad ACROSS the direction of
      // motion and thin along it, which is the sweep the design asks for.
      final wallW = 11.0 * vs;
      final wallH = 24.0 * vs;
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(atan2(dir.dy, dir.dx));
      for (var i = 3; i >= 1; i--) {
        final r = (i / 3.0);
        canvas.drawOval(
          ui.Rect.fromCenter(
            center: ui.Offset.zero,
            width: wallW * (0.7 + r * 0.6),
            height: wallH * (0.7 + r * 0.6),
          ),
          ui.Paint()
            ..color = color.withValues(alpha: (0.06 + i * 0.05) * pulse)
            ..maskFilter = null,
        );
      }
      // The crest: a curved front face bulging the way it is travelling, so
      // the wall has a leading edge carrying the water rather than a centre.
      final crest = ui.Path()
        ..moveTo(0, -wallH * 0.46)
        ..quadraticBezierTo(wallW * 0.95, 0, 0, wallH * 0.46)
        ..quadraticBezierTo(wallW * 0.30, 0, 0, -wallH * 0.46)
        ..close();
      canvas.drawPath(
        crest,
        ui.Paint()
          ..color = white.withValues(alpha: 0.50 * pulse)
          ..maskFilter = null,
      );
      canvas.restore();
      // No white centre pip. A bright dot in the middle of concentric rings is
      // what made this read as a pupil; the crest is the bright part of a wave,
      // and it belongs on the leading face.
      drawControlRead(scale: 1.0);
      break;
    case 'Ice':
      drawCoreSlash(width: 3.1, glowWidth: 8.4, alpha: 0.76);
      // Frost as light catching on crystal, not a drawn snowflake. The six
      // even spokes of _drawFrostStar read as a winter-holiday sticker pinned
      // to the blade — symmetrical, axis-less, and the last hard asterisk in
      // the family after the Let meteors dropped theirs for the same reason.
      drawSparkleGlints(
        canvas: canvas,
        centre: position,
        travelDir: dir.distance > 0.01
            ? dir / dir.distance
            : const ui.Offset(1, 0),
        spread: 20.0 * vs,
        size: 2.6 * vs,
        color: const ui.Color(0xFFCFEAFF),
        time: time,
        count: 6,
        seed: projectile.angle * 3.0,
        alpha: 0.85,
      );
      // Rime shearing off the trailing edge as it freezes the air behind it.
      for (var i = 0; i < 3; i++) {
        final t = (time * 0.85 + i * 0.34 + projectile.angle) % 1.0;
        canvas.drawCircle(
          position -
              dir * (len * 0.5 + len * 0.7 * t) +
              perp * sin(time * 2.0 + i) * 3.0 * vs,
          (1.6 + 2.4 * t) * vs,
          fillPaint
            ..color = const ui.Color(
              0xFFCFEAFF,
            ).withValues(alpha: (1 - t) * 0.24)
            ..maskFilter = null,
        );
      }
      drawControlRead(scale: 1.08);
      break;
    case 'Steam':
      // Pressure Vent Cuts — scalding vapour venting off the cleave.
      //
      // This was four flat circles at alpha 0.13 drifting behind the blade:
      // grey on a dark field, no edge, no heat, and the only thing separating
      // it from the other soft elements was hue it barely had. The design has
      // it laying down steam damage zones as it travels, so the blade should
      // look like it is venting, not fogging.
      drawCoreSlash(width: 2.8, glowWidth: 7.0, alpha: 0.80);
      final vapour = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.60)!;
      for (var i = 0; i < 4; i++) {
        // Each puff boils off, expands and thins on its own cycle, so the
        // vapour billows instead of sitting there as a static smear.
        final t = (time * 1.3 + i * 0.25 + projectile.angle) % 1.0;
        final p =
            position -
            dir * (len * 0.35 + len * 1.5 * t) +
            perp * sin(time * 1.9 + i * 2.0) * 6.0 * vs * t;
        canvas.drawCircle(
          p,
          (2.6 + 6.5 * t) * vs,
          fillPaint
            ..color = vapour.withValues(alpha: (1 - t) * (1 - t) * 0.30)
            ..maskFilter = null,
        );
      }
      // A bright vent at the trailing edge — the point the pressure escapes.
      canvas.drawCircle(
        position - dir * len * 0.45,
        2.2 * vs * (0.8 + 0.2 * sin(time * 8.0)),
        fillPaint
          ..color = vapour.withValues(alpha: 0.62 * pulse)
          ..maskFilter = null,
      );
      drawControlRead(scale: 1.05);
      break;
    case 'Earth':
      drawEarthRockProjectile();
      drawControlRead(scale: 1.30);
      break;
    case 'Lava':
      drawCoreSlash(width: 5.6, glowWidth: 13.0, alpha: 0.88);
      // Molten shed off the cleave. This was a straight cream rod drawn the
      // full length of the blade and out past both ends — the single most
      // stick-like thing in the family, and it sat on the element whose whole
      // read is that it is liquid.
      for (var i = 0; i < 3; i++) {
        final t = (time * 0.9 + i * 0.34 + projectile.angle) % 1.0;
        final drip =
            position -
            dir * (len * 0.3 + len * 0.9 * t) +
            perp * sin(time * 2.0 + i * 2.1) * 3.4 * vs * t;
        canvas.drawCircle(
          drip,
          (2.4 - 1.5 * t) * vs,
          fillPaint
            ..color = const ui.Color(
              0xFFFF8A2B,
            ).withValues(alpha: (1 - t) * 0.80)
            ..maskFilter = null,
        );
      }
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
      // Windblade Sweep — the fastest thing in the family, at twice the speed
      // of everything else.
      //
      // It used to wear _drawAirSwirl: two thin stroked spirals centred on the
      // body, at alpha 0.30. Curls drawn around a point say nothing about
      // direction, and on the one element defined by how fast it is going,
      // that left the whole cast reading as a faint smudge.
      //
      // Air is shown by what it drags along: motes streaming past the blade,
      // stretched back down the travel line. The helper is left alone — three
      // other abilities still use it as intended.
      drawCoreSlash(width: 2.2, glowWidth: 7.5, alpha: 0.78);
      for (var i = 0; i < 7; i++) {
        final t = (time * 2.6 + i * 0.143 + projectile.angle) % 1.0;
        final h = sin((i + 1) * 12.9898 + projectile.angle * 78.233) * 43758.5;
        final lateral = ((h - h.floorToDouble()) - 0.5) * 2.0;
        final p =
            position -
            dir * (len * 0.3 + len * 2.1 * t) +
            perp * lateral * 6.0 * vs * (0.3 + t);
        // Drawn as short streaks rather than dots: at this speed a round mote
        // reads as standing still.
        canvas.drawLine(
          p,
          p - dir * (5.0 + 7.0 * (1 - t)) * vs,
          strokePaint
            ..color = white.withValues(alpha: (1 - t) * 0.55)
            ..strokeWidth = 1.0 * vs
            ..maskFilter = null,
        );
      }
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
      // A void that swallows, shown by what is falling into it.
      //
      // This was a near-black disc laid over the blade: on a black starfield it
      // subtracted the artwork and put nothing back, so the slowest, heaviest
      // shot in the family was also the hardest one to see. The design has it
      // dragging enemies inward the whole way, so draw the drag — motes hauled
      // in from around it, winking out at the horizon — and give the horizon a
      // lit rim so the sphere has an edge against the dark.
      drawCoreSlash(width: 4.1, glowWidth: 11.0, alpha: 0.76);
      final voidR = 13.0 * vs;
      canvas.drawCircle(
        position,
        voidR,
        fillPaint
          ..color = const ui.Color(0xFF05020A).withValues(alpha: 0.88)
          ..maskFilter = null,
      );
      canvas.drawCircle(
        position,
        voidR,
        strokePaint
          ..color = ui.Color.lerp(
            color,
            const ui.Color(0xFFFFFFFF),
            0.35,
          )!.withValues(alpha: 0.55 * pulse)
          ..strokeWidth = 1.4 * vs
          ..maskFilter = null,
      );
      for (var i = 0; i < 6; i++) {
        final t = (time * 0.8 + i * 0.167 + projectile.angle) % 1.0;
        final a = i * (pi * 2 / 6) + t * 2.6;
        final rr = voidR * (2.5 - 1.7 * t);
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * rr,
          1.5 * vs * (1 - t * 0.8),
          fillPaint
            ..color = const ui.Color(
              0xFFB06BE8,
            ).withValues(alpha: (1 - t) * 0.70 * pulse)
            ..maskFilter = null,
        );
      }
      drawControlRead(scale: 1.06);
      break;
    case 'Light':
      canvas.drawCircle(
        position,
        15.0 * vs * pulse,
        fillPaint
          ..color = color.withValues(alpha: 0.16)
          ..maskFilter = null,
      );
      canvas.drawCircle(
        position,
        7.0 * vs,
        fillPaint
          ..color = color.withValues(alpha: 0.82)
          ..maskFilter = null,
      );
      canvas.drawCircle(
        position - dir * 1.6 * vs - perp * 1.2 * vs,
        3.2 * vs,
        fillPaint
          ..color = white.withValues(alpha: 0.72)
          ..maskFilter = null,
      );
      canvas.drawCircle(
        position,
        11.0 * vs,
        strokePaint
          ..color = white.withValues(alpha: 0.38 * pulse)
          ..strokeWidth = max(1.0, 0.9 * vs)
          ..maskFilter = null,
      );
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

    // Per design feedback: removed the outer stroke-ring "indicator
    // outline" on guard zones — just the inner soft fill + intercept
    // spokes carry the read without a hard outline.
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
      if (projectile.stationary &&
          projectile.tickEffect == AbilityEffectKind.chain) {
        // Horn+Lightning chain shockwave — minimal painter; the
        // burst visual is a particle storm spawned survival-side
        // (one-shot on release + per-frame flash sparkles). Painter
        // just renders a bright pulsing core so there's a stable
        // anchor under the particle cloud.
        final pulse2 = 0.78 + 0.22 * sin(time * 8.0 + projectile.life * 6.0);
        canvas.drawCircle(
          position,
          18.0 * vs * pulse2,
          ui.Paint()
            ..color = color.withValues(alpha: 0.18 * pulse2)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          10.0 * vs * pulse2,
          ui.Paint()
            ..color = white.withValues(alpha: 0.55 * pulse2)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          4.0 * vs,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.90)
            ..maskFilter = null,
        );
      } else {
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
      }
      break;
    case 'Water':
      if (projectile.stationary) {
        // Whirlpool — faint hazy disc, no hard rings or bright pip.
        // The spiral pull motion is conveyed entirely by the per-
        // frame particle stream spawned survival-side.
        final whirlR = max(40.0, projectile.radiusMultiplier * 18.0 + 20.0);
        final pulseW = 0.82 + 0.18 * sin(time * 2.3 + projectile.life * 1.6);
        for (var i = 4; i >= 1; i--) {
          canvas.drawCircle(
            position,
            whirlR * (0.45 + i * 0.16),
            ui.Paint()
              ..color = color.withValues(alpha: (0.025 + i * 0.022) * pulseW)
              ..maskFilter = null,
          );
        }
      } else {
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
      }
      break;
    case 'Ice':
      if (projectile.stationary) {
        // Ice wall segment / frost field: soft layered halo + small
        // bright core pip. Crystalline frost detail is conveyed by
        // the per-frame frost-mote particle drift survival-side.
        final iceR = max(20.0, projectile.radiusMultiplier * 16.0 + 8.0);
        final pulseI = 0.82 + 0.18 * sin(time * 3.0 + projectile.life * 1.6);
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            position,
            iceR * (0.45 + i * 0.18),
            ui.Paint()
              ..color = color.withValues(alpha: (0.06 + i * 0.04) * pulseI)
              ..maskFilter = null,
          );
        }
        canvas.drawCircle(
          position,
          4.0 * vs,
          ui.Paint()
            ..color = white.withValues(alpha: 0.65 * pulseI)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          2.0 * vs,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.85)
            ..maskFilter = null,
        );
      } else {
        drawRamCore(width: 5.8, glow: 12.0);
        _drawFrostStar(canvas, position, white, radius * 1.25, vs, time);
      }
      break;
    case 'Steam':
      if (projectile.stationary) {
        // Steam geyser: soft white-blue glow + bright core. Rising
        // steam puffs come from the per-frame particle hook.
        final steamR = max(38.0, projectile.radiusMultiplier * 18.0 + 18.0);
        final pulseS = 0.80 + 0.20 * sin(time * 3.2 + projectile.life * 2.0);
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            position,
            steamR * (0.5 + i * 0.18),
            ui.Paint()
              ..color = color.withValues(alpha: (0.05 + i * 0.04) * pulseS)
              ..maskFilter = null,
          );
        }
        canvas.drawCircle(
          position,
          5.0 * vs,
          ui.Paint()
            ..color = white.withValues(alpha: 0.55 * pulseS)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          2.4 * vs,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.85)
            ..maskFilter = null,
        );
      } else {
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
      }
      break;
    case 'Earth':
      if (projectile.stationary) {
        // Substitute clone — much softer. The cracked-earth pool
        // underneath does most of the silhouette work; the chunky
        // asteroid body on top is now translucent and rim-less so
        // it reads as a hazy stone presence rather than a solid
        // sprite cutout. No outline stroke.
        final earthRadius = max(36.0, radius * 2.4);
        _paintEarthPool(canvas, position, earthRadius, color, time, pulse, vs);
        final body = ui.Path();
        const points = 13;
        final wobBase = earthRadius * 0.58;
        for (var i = 0; i < points; i++) {
          final a = i * pi * 2 / points;
          final wob = wobBase * (0.88 + 0.20 * sin(i * 2.17 + 0.7));
          final p = position + ui.Offset(cos(a), sin(a)) * wob;
          if (i == 0) {
            body.moveTo(p.dx, p.dy);
          } else {
            body.lineTo(p.dx, p.dy);
          }
        }
        body.close();
        final base = ui.Color.lerp(color, const ui.Color(0xFF4A362B), 0.32)!;
        final high = ui.Color.lerp(color, const ui.Color(0xFFE2C6A8), 0.30)!;
        final low = ui.Color.lerp(color, const ui.Color(0xFF241915), 0.45)!;
        // Translucent body fill, no outline.
        canvas.drawPath(body, ui.Paint()..color = base.withValues(alpha: 0.42));
        // Soft highlight + shadow lobes (alpha halved).
        canvas.drawCircle(
          position + ui.Offset(-wobBase * 0.22, -wobBase * 0.18),
          wobBase * 0.30,
          ui.Paint()..color = high.withValues(alpha: 0.18),
        );
        canvas.drawCircle(
          position + ui.Offset(wobBase * 0.20, wobBase * 0.20),
          wobBase * 0.26,
          ui.Paint()..color = low.withValues(alpha: 0.14),
        );
      } else {
        drawRamCore(width: 7.0, glow: 15.0);
        _drawCrackedPlate(canvas, position, color, radius * 1.4, vs, time);
      }
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
      if (projectile.stationary) {
        // Dust cyclone — extra-faint hazy disc. The bulk of the
        // visual is the per-frame swirling dust motes spawned
        // survival-side. No bright core, just a soft cloud.
        final dustR = max(36.0, projectile.radiusMultiplier * 18.0 + 16.0);
        final pulseD = 0.85 + 0.15 * sin(time * 2.4 + projectile.life * 1.6);
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            position,
            dustR * (0.45 + i * 0.20),
            ui.Paint()
              ..color = color.withValues(alpha: (0.03 + i * 0.025) * pulseD)
              ..maskFilter = null,
          );
        }
      } else {
        drawRamCore(width: 3.0, glow: 8.0);
        _drawDustCloud(canvas, position, color, radius * 1.2, vs, time);
      }
      break;
    case 'Crystal':
      if (projectile.orbitRadius > 0 && projectile.holdOrbit) {
        // Horn+Crystal orbital shard — minimal body. Per-frame
        // _VfxParticle sparkles do the visual work. Painter only
        // draws a bright sparkle pip so each shard has a clear
        // pivot point as it orbits the horn.
        final pipR = 2.4 * vs;
        final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!;
        canvas.drawCircle(
          position,
          pipR * 1.8,
          ui.Paint()
            ..color = white.withValues(alpha: 0.30 * pulse)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          pipR,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.85)
            ..maskFilter = null,
        );
      } else {
        drawRamCore(width: 4.8, glow: 10.0);
        _drawCrystalSigil(canvas, position, color, radius * 1.1, vs, time);
      }
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
      if (projectile.decoy) {
        // Horn+Spirit phantom decoy — minimal body. The visible
        // bulk comes from the per-frame _VfxParticle wisps spawned
        // in the projectile update. Painter only draws a faint
        // bright core pip so there's something to anchor the
        // particle swarm to.
        final corePip = 2.2 * vs;
        final ghostColor = ui.Color.lerp(
          color,
          const ui.Color(0xFFFFFFFF),
          0.6,
        )!;
        canvas.drawCircle(
          position,
          corePip * 1.6,
          ui.Paint()
            ..color = ghostColor.withValues(alpha: 0.30 * pulse)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          corePip,
          ui.Paint()
            ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.85)
            ..maskFilter = null,
        );
      } else {
        drawRamCore(width: 4.5, glow: 11.0);
        _drawSpiritHalo(canvas, position, color, radius * 1.25, vs, time);
      }
      break;
    case 'Dark':
      if (projectile.stationary) {
        // Void zone: deep dark core with soft layered halo. Inward
        // suck particles are spawned per-frame survival-side so the
        // pull motion reads visually.
        final voidR = max(40.0, projectile.radiusMultiplier * 18.0 + 24.0);
        final pulseD = 0.78 + 0.22 * sin(time * 2.0 + projectile.life * 1.6);
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            position,
            voidR * (0.45 + i * 0.20),
            ui.Paint()
              ..color = color.withValues(alpha: (0.08 + i * 0.04) * pulseD)
              ..maskFilter = null,
          );
        }
        canvas.drawCircle(
          position,
          voidR * 0.45,
          ui.Paint()
            ..color = const ui.Color(
              0xFF05020A,
            ).withValues(alpha: 0.72 * pulseD)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          4.0 * vs,
          ui.Paint()
            ..color = const ui.Color(
              0xFFB89AFF,
            ).withValues(alpha: 0.55 * pulseD)
            ..maskFilter = null,
        );
      } else {
        drawRamCore(width: 5.2, glow: 13.0);
        canvas.drawCircle(
          position,
          radius * 1.1,
          ui.Paint()
            ..color = const ui.Color(0xFF05020A).withValues(alpha: 0.48)
            ..maskFilter = null,
        );
      }
      break;
    case 'Light':
      if (projectile.stationary && projectile.reflectsProjectiles) {
        // Horn+Light barrier: soft glowing dome instead of a
        // crystal-crown silhouette. Several layered translucent
        // rings with a bright pulsing core — reads as a protective
        // bubble. Sized off the projectile's visualScale * radiusMul.
        final domeR = max(60.0, projectile.radiusMultiplier * 20.0 + 70.0);
        final pulse2 = 0.85 + 0.15 * sin(time * 2.0 + projectile.life * 1.4);
        // 5 layered glow rings from soft to bright.
        for (var i = 5; i >= 1; i--) {
          canvas.drawCircle(
            position,
            domeR * (0.55 + i * 0.10),
            ui.Paint()
              ..color = color.withValues(alpha: (0.05 + i * 0.02) * pulse2)
              ..maskFilter = null,
          );
        }
        // Bright core wash.
        canvas.drawCircle(
          position,
          domeR * 0.55,
          ui.Paint()
            ..color = ui.Color.lerp(
              color,
              const ui.Color(0xFFFFFFFF),
              0.55,
            )!.withValues(alpha: 0.22 * pulse2)
            ..maskFilter = null,
        );
        // Hard rim line so the protection boundary reads clearly.
        canvas.drawCircle(
          position,
          domeR,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = color.withValues(alpha: 0.42 * pulse2),
        );
        // Subtle slow-rotating sparkle ring along the perimeter so
        // the dome feels alive rather than static.
        for (var i = 0; i < 8; i++) {
          final a = time * 0.6 + i * pi / 4;
          canvas.drawCircle(
            position + ui.Offset(cos(a), sin(a)) * domeR,
            1.6,
            ui.Paint()
              ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.65)
              ..maskFilter = null,
          );
        }
      } else {
        drawRamCore(width: 4.5, glow: 11.0);
        _drawLightCrown(canvas, position, color, radius * 1.2, vs, time);
      }
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
      if (projectile.abilityFamily == 'horn') {
        // Horn passive trail — faint translucent splotch, no rim
        // outline, much subtler than the standard poison pool so
        // a moving horn doesn't paint a heavy green carpet.
        canvas.drawCircle(
          position,
          zoneSize * 0.85,
          ui.Paint()
            ..color = color.withValues(alpha: 0.10 * pulse)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          zoneSize * 0.45,
          ui.Paint()
            ..color = ui.Color.lerp(
              color,
              const ui.Color(0xFF2B0E3A),
              0.35,
            )!.withValues(alpha: 0.13 * pulse)
            ..maskFilter = null,
        );
      } else {
        _paintPoisonPool(canvas, position, zoneSize, color, time, pulse, vs);
      }
      break;
    case 'Lava':
      _paintLavaPool(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Mud':
      if (projectile.abilityFamily == 'horn') {
        // Horn passive trail — looser, fainter, less geometric than
        // the standard mud pool. Splatter-blob shape + low alpha so
        // the running trail doesn't dominate the screen.
        _paintHornMudTrail(canvas, position, zoneSize, color, time, pulse, vs);
      } else {
        _paintMudPool(canvas, position, zoneSize, color, time, pulse, vs);
      }
      break;
    case 'Water':
      _paintWaterPool(canvas, position, zoneSize, color, time, pulse, vs);
      break;
    case 'Fire':
      // Mask Fire balls flash on contact (ball→pool ignition).
      final fireFlash = projectile.abilityFamily == 'mask'
          ? projectile.abilityGrowthTimer.clamp(0.0, 1.0).toDouble()
          : 0.0;
      if (fireFlash > 0.05) {
        final burstR = zoneSize * (1.0 + 0.65 * (1.0 - fireFlash));
        canvas.drawCircle(
          position,
          burstR,
          ui.Paint()
            ..color = const ui.Color(
              0xFFFFE7B0,
            ).withValues(alpha: 0.28 * fireFlash),
        );
        canvas.drawCircle(
          position,
          burstR * 0.55,
          ui.Paint()
            ..color = const ui.Color(
              0xFFFFB060,
            ).withValues(alpha: 0.50 * fireFlash),
        );
      }
      if (projectile.abilityFamily == 'horn') {
        // Horn Fire trail segment — much fainter than the standard
        // flame-tongue field. Just a soft warm haze; the dynamic
        // visual comes from per-frame ember particles spawned
        // survival-side.
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            position,
            zoneSize * (0.40 + i * 0.20),
            ui.Paint()
              ..color = color.withValues(alpha: (0.04 + i * 0.025) * pulse)
              ..maskFilter = null,
          );
        }
      } else {
        _paintFireZone(
          canvas,
          position,
          zoneSize,
          color,
          white,
          time,
          pulse,
          vs,
        );
      }
      break;
    case 'Plant':
      _paintPlantZone(
        canvas,
        position,
        zoneSize,
        color,
        time,
        pulse,
        vs,
        // Only Mask's vine gets the writhing tendril overlay on top (see
        // drawMaskPlantWormyTendrils, which the games call for mask+Plant
        // alone). Every other family's Plant zone was being drawn as the
        // deliberately-bare moss patch that overlay was designed to sit
        // under, and then nothing arrived to sit on it.
        //
        // Kin's is a healing GARDEN that drops flowers to harvest — attack
        // tendrils would be the wrong picture for it anyway. It gets growth
        // of its own instead.
        style: switch (projectile.abilityFamily) {
          'mask' => PlantZoneStyle.bare,
          'kin' => PlantZoneStyle.garden,
          _ => PlantZoneStyle.vines,
        },
      );
      break;
    case 'Crystal':
      final crystalFlash = projectile.abilityGrowthTimer.clamp(0.0, 1.0);
      _paintCrystalCluster(
        canvas,
        position,
        zoneSize * (1.0 + 0.45 * crystalFlash),
        color,
        white,
        time,
        pulse * (1.0 + 0.35 * crystalFlash),
        vs * (1.0 + 0.25 * crystalFlash),
      );
      if (crystalFlash > 0.05) {
        // Shatter burst: layered white halo bursting outward.
        final burstR = zoneSize * (1.0 + 0.7 * (1.0 - crystalFlash));
        canvas.drawCircle(
          position,
          burstR,
          ui.Paint()..color = white.withValues(alpha: 0.22 * crystalFlash),
        );
        canvas.drawCircle(
          position,
          burstR * 0.55,
          ui.Paint()..color = white.withValues(alpha: 0.45 * crystalFlash),
        );
      }
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
      // Mask Light void flashes brightly on instakill, then collapses.
      final lightFlash = projectile.abilityFamily == 'mask'
          ? projectile.abilityGrowthTimer.clamp(0.0, 1.0).toDouble()
          : 0.0;
      _paintLightVoid(
        canvas,
        position,
        zoneSize * (1.0 + 0.50 * lightFlash),
        color,
        white,
        time,
        pulse * (1.0 + 0.50 * lightFlash),
        vs * (1.0 + 0.30 * lightFlash),
      );
      if (lightFlash > 0.05) {
        // White-hot collapse — dome of brightness shrinking inward.
        final burstR = zoneSize * (0.8 + 1.2 * lightFlash);
        canvas.drawCircle(
          position,
          burstR,
          ui.Paint()..color = white.withValues(alpha: 0.45 * lightFlash),
        );
        canvas.drawCircle(
          position,
          burstR * 0.45,
          ui.Paint()
            ..color = const ui.Color(
              0xFFFFFFFF,
            ).withValues(alpha: 0.85 * lightFlash),
        );
      }
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
      // Mask Earth heal pool flashes green on each heal tick.
      final earthFlash = projectile.abilityFamily == 'mask'
          ? projectile.abilityGrowthTimer.clamp(0.0, 1.0).toDouble()
          : 0.0;
      _paintEarthPool(
        canvas,
        position,
        zoneSize * (1.0 + 0.25 * earthFlash),
        color,
        time,
        pulse * (1.0 + 0.40 * earthFlash),
        vs,
      );
      if (earthFlash > 0.05) {
        // Soft green heal pulse.
        final healR = zoneSize * (0.65 + 0.45 * (1.0 - earthFlash));
        canvas.drawCircle(
          position,
          healR,
          ui.Paint()
            ..color = const ui.Color(
              0xFFB7FFB7,
            ).withValues(alpha: 0.32 * earthFlash),
        );
      }
      break;
    case 'Air':
      // Activation flash: when the trap just knocked an enemy back,
      // abilityGrowthTimer is bumped to 1.0 and decays survival-side.
      // Pump zone scale + brightness + draw a brief outward gust ring
      // so the player sees which pad is firing.
      final airFlash = projectile.abilityGrowthTimer.clamp(0.0, 1.0);
      final airScale = 1.0 + 0.55 * airFlash;
      final airPulse = pulse * (1.0 + 0.40 * airFlash);
      _paintAirGust(
        canvas,
        position,
        zoneSize * airScale,
        color,
        white,
        time,
        airPulse,
        vs * (1.0 + 0.25 * airFlash),
      );
      if (airFlash > 0.05) {
        // Outward gust ring — soft expanding halo that swells as the
        // pad fires. Two layered fills (bright inner, faint outer)
        // for the alchemical particle look.
        final gustR = zoneSize * (1.10 + 0.55 * (1.0 - airFlash));
        canvas.drawCircle(
          position,
          gustR,
          ui.Paint()
            ..color = white.withValues(alpha: 0.18 * airFlash)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          position,
          gustR * 0.55,
          ui.Paint()
            ..color = white.withValues(alpha: 0.35 * airFlash)
            ..maskFilter = null,
        );
      }
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
  // ignore: unused_element
  double rim = 0.55,
}) {
  // Soft fill only — outline rim removed per design feedback ("just
  // let the effects show"). The `rim` parameter is kept for back-
  // compat with existing callers but no longer rendered.
  final fill = ui.Paint()..color = color.withValues(alpha: alpha);
  canvas.drawCircle(position, radius, fill);
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
  // Organic sickly pool — irregular silhouette + position-seeded
  // bubble + vapor placements so each pool reads as a unique
  // splotch, not a stamped sprite.
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  // Irregular outer blob (11 vertices, position-seeded wobble).
  final body = ui.Path();
  const points = 11;
  for (var i = 0; i < points; i++) {
    final a = i * pi * 2 / points;
    final wob = 0.78 + 0.32 * ((seed + i * 53) % 100) / 100.0;
    final p = position + ui.Offset(cos(a), sin(a)) * radius * 0.95 * wob;
    if (i == 0) {
      body.moveTo(p.dx, p.dy);
    } else {
      body.lineTo(p.dx, p.dy);
    }
  }
  body.close();
  canvas.drawPath(
    body,
    ui.Paint()
      ..color = color.withValues(alpha: 0.28 * pulse)
      ..maskFilter = null,
  );
  // Inner darker splotch (offset slightly from center).
  final innerColor = ui.Color.lerp(color, const ui.Color(0xFF2B0E3A), 0.45)!;
  final innerOffset = ui.Offset(
    (((seed >> 3) % 20) - 10) * 0.6,
    (((seed >> 7) % 20) - 10) * 0.6,
  );
  canvas.drawCircle(
    position + innerOffset,
    radius * 0.55,
    ui.Paint()
      ..color = innerColor.withValues(alpha: 0.30 * pulse)
      ..maskFilter = null,
  );
  // Bubbling dots at stable-random positions, twinkling per-bubble.
  final bubble = ui.Paint()..maskFilter = null;
  for (var i = 0; i < 6; i++) {
    final h = (seed + i * 131) & 0xFFFF;
    final a = (h % 360) * pi / 180;
    final r = radius * (0.20 + ((h >> 4) % 70) / 100.0);
    final p = position + ui.Offset(cos(a), sin(a)) * r;
    final twinkle = 0.45 + 0.55 * ((sin(time * 2.4 + (h % 17)) + 1) * 0.5);
    bubble.color = color.withValues(alpha: twinkle * 0.70 * pulse);
    canvas.drawCircle(p, 1.4 * vs + (h % 8) * 0.14, bubble);
  }
  // 2-3 vapor wisps rising from seeded base positions — short
  // dashes that fade as they travel upward.
  final vapor = ui.Paint()
    ..maskFilter = null
    ..strokeCap = ui.StrokeCap.round
    ..strokeWidth = 1.6 * vs;
  for (var i = 0; i < 3; i++) {
    final h = (seed + i * 211) & 0xFFFF;
    final phase = (time * 0.5 + (h % 100) / 100.0) % 1.0;
    final bx = (((h >> 5) % 80) - 40) * 0.012;
    final by = (((h >> 9) % 80) - 40) * 0.012;
    final base = position + ui.Offset(bx, by) * radius;
    final tip = base + ui.Offset(0, -radius * 0.55 * phase);
    vapor.color = color.withValues(alpha: (1 - phase) * 0.55 * pulse);
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
  // Organic molten splotch — replaces the stamped 90° crack +
  // 60° ember pattern with position-seeded irregular shapes so
  // each pool reads as a unique molten blob, not a sprite.
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  // Irregular 11-vertex outer blob silhouette.
  final body = ui.Path();
  const points = 11;
  for (var i = 0; i < points; i++) {
    final a = i * pi * 2 / points;
    final wob = 0.78 + 0.32 * ((seed + i * 47) % 100) / 100.0;
    final p = position + ui.Offset(cos(a), sin(a)) * radius * 0.95 * wob;
    if (i == 0) {
      body.moveTo(p.dx, p.dy);
    } else {
      body.lineTo(p.dx, p.dy);
    }
  }
  body.close();
  // Soft body fill.
  canvas.drawPath(
    body,
    ui.Paint()
      ..color = color.withValues(alpha: 0.34 * pulse)
      ..maskFilter = null,
  );
  // Hot inner glow at ~55% radius — single soft fill, no crack lines.
  final hot = ui.Color.lerp(color, const ui.Color(0xFFFFE08A), 0.5)!;
  canvas.drawCircle(
    position,
    radius * 0.55,
    ui.Paint()
      ..color = hot.withValues(alpha: 0.45 * pulse)
      ..maskFilter = null,
  );
  // Bright white-hot core pip.
  canvas.drawCircle(
    position,
    radius * 0.18,
    ui.Paint()
      ..color = const ui.Color(0xFFFFE8A0).withValues(alpha: 0.85 * pulse)
      ..maskFilter = null,
  );
  // Stable per-pool ember dots at seeded positions — animate alpha
  // only (no orbital motion) so they read as glowing pops on the
  // surface, not a rotating ring.
  final ember = ui.Paint()..maskFilter = null;
  for (var i = 0; i < 5; i++) {
    final h = (seed + i * 131) & 0xFFFF;
    final a = (h % 360) * pi / 180;
    final r = radius * (0.25 + ((h >> 4) % 65) / 100.0);
    final p = position + ui.Offset(cos(a), sin(a)) * r;
    // Twinkle phase per-ember so they pop in/out independently.
    final twinkle = 0.55 + 0.45 * ((sin(time * 2.0 + (h % 17)) + 1) * 0.5);
    ember.color = const ui.Color(
      0xFFFFD160,
    ).withValues(alpha: twinkle * 0.85 * pulse);
    canvas.drawCircle(p, 1.6 * vs + (h % 9) * 0.12, ember);
  }
}

// Horn-passive Mud trail — sloppier and fainter than the standard
// mud pool. No geometric 90° lump pattern; uses jittered splatter
// blobs and a soft irregular silhouette so a moving horn paints a
// looser organic trail. Cheap (handful of draws, no blur).
void _paintHornMudTrail(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs,
) {
  // Use the projectile's life/position-driven hash to pick a stable
  // "blob shape" per puff so it doesn't shimmer between frames.
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  // Irregular silhouette: 9-point wobbly disc instead of perfect ring.
  final body = ui.Path();
  const points = 9;
  for (var i = 0; i < points; i++) {
    final a = i * pi * 2 / points;
    // Stable per-vertex wobble (no time drift — keeps the trail calm).
    final wob = 0.78 + 0.32 * ((seed + i * 37) % 100) / 100.0;
    final p = position + ui.Offset(cos(a), sin(a)) * radius * 0.95 * wob;
    if (i == 0) {
      body.moveTo(p.dx, p.dy);
    } else {
      body.lineTo(p.dx, p.dy);
    }
  }
  body.close();
  // Soft body fill — much fainter than the standard mud pool's 0.40.
  canvas.drawPath(
    body,
    ui.Paint()
      ..color = color.withValues(alpha: 0.20 * pulse)
      ..maskFilter = null,
  );
  // Faint inner darker patch for a little depth.
  final innerColor = ui.Color.lerp(color, const ui.Color(0xFF221008), 0.45)!;
  canvas.drawCircle(
    position,
    radius * 0.55,
    ui.Paint()
      ..color = innerColor.withValues(alpha: 0.18 * pulse)
      ..maskFilter = null,
  );
  // Scattered splatter dots — random-feeling positions seeded by the
  // puff so they don't move between frames. 5 dots is enough to read
  // as "splatter" without overdrawing.
  final dotPaint = ui.Paint()..maskFilter = null;
  for (var i = 0; i < 5; i++) {
    final h = (seed + i * 131) & 0xFFFF;
    final a = (h % 360) * pi / 180;
    final r = radius * (0.20 + ((h >> 4) % 80) / 100.0);
    final p = position + ui.Offset(cos(a), sin(a)) * r;
    dotPaint.color = innerColor.withValues(alpha: 0.32 * pulse);
    canvas.drawCircle(p, 1.6 * vs + (h % 9) * 0.18, dotPaint);
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
  // Organic mud splotch — irregular silhouette + position-seeded
  // lumps so each pool reads as a unique sloppy splat, not a
  // stamped four-lump square pattern.
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  // 11-point wobbly silhouette.
  final body = ui.Path();
  const points = 11;
  for (var i = 0; i < points; i++) {
    final a = i * pi * 2 / points;
    final wob = 0.78 + 0.32 * ((seed + i * 41) % 100) / 100.0;
    final p = position + ui.Offset(cos(a), sin(a)) * radius * 0.95 * wob;
    if (i == 0) {
      body.moveTo(p.dx, p.dy);
    } else {
      body.lineTo(p.dx, p.dy);
    }
  }
  body.close();
  canvas.drawPath(
    body,
    ui.Paint()
      ..color = color.withValues(alpha: 0.34 * pulse)
      ..maskFilter = null,
  );
  // Position-seeded dark lumps at irregular positions (no cardinal
  // 90° grid).
  final lump = ui.Paint()..maskFilter = null;
  final darkColor = ui.Color.lerp(color, const ui.Color(0xFF000000), 0.40)!;
  for (var i = 0; i < 5; i++) {
    final h = (seed + i * 137) & 0xFFFF;
    final a = (h % 360) * pi / 180;
    final r = radius * (0.18 + ((h >> 4) % 60) / 100.0);
    final p = position + ui.Offset(cos(a), sin(a)) * r;
    lump.color = darkColor.withValues(alpha: 0.50 * pulse);
    canvas.drawCircle(p, radius * (0.10 + ((h >> 8) % 14) / 100.0), lump);
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
  // Organic water puddle silhouette + animated ripples (the rings
  // are kept since they ARE the authentic water-effect motion).
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  final body = ui.Path();
  const points = 11;
  for (var i = 0; i < points; i++) {
    final a = i * pi * 2 / points;
    final wob = 0.78 + 0.32 * ((seed + i * 67) % 100) / 100.0;
    final p = position + ui.Offset(cos(a), sin(a)) * radius * 0.95 * wob;
    if (i == 0) {
      body.moveTo(p.dx, p.dy);
    } else {
      body.lineTo(p.dx, p.dy);
    }
  }
  body.close();
  canvas.drawPath(
    body,
    ui.Paint()
      ..color = color.withValues(alpha: 0.26 * pulse)
      ..maskFilter = null,
  );
  // Inner highlight pip — bright water reflection.
  canvas.drawCircle(
    position,
    radius * 0.18,
    ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.40 * pulse)
      ..maskFilter = null,
  );
  // Animated ripple rings — kept as stroke since they ARE the
  // water effect (expanding wave fronts).
  final ripple = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 1.2 * vs;
  for (var i = 0; i < 3; i++) {
    final phase = ((time * 0.5 + i * 0.33) % 1.0);
    final r = radius * (0.4 + 0.55 * phase);
    ripple.color = color.withValues(alpha: (1 - phase) * 0.55 * pulse);
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
  // Organic flame patch — irregular charred ground silhouette +
  // position-seeded flame blobs that flicker independently. No
  // stamped 7-tongue rosette pattern.
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  // 11-point charred ground silhouette.
  final body = ui.Path();
  const points = 11;
  for (var i = 0; i < points; i++) {
    final a = i * pi * 2 / points;
    final wob = 0.78 + 0.32 * ((seed + i * 59) % 100) / 100.0;
    final p = position + ui.Offset(cos(a), sin(a)) * radius * 0.95 * wob;
    if (i == 0) {
      body.moveTo(p.dx, p.dy);
    } else {
      body.lineTo(p.dx, p.dy);
    }
  }
  body.close();
  final ground = ui.Color.lerp(color, const ui.Color(0xFF1A0000), 0.55)!;
  canvas.drawPath(
    body,
    ui.Paint()
      ..color = ground.withValues(alpha: 0.34 * pulse)
      ..maskFilter = null,
  );
  // Hot core glow.
  canvas.drawCircle(
    position,
    radius * 0.50,
    ui.Paint()
      ..color = color.withValues(alpha: 0.50 * pulse)
      ..maskFilter = null,
  );
  // Bright white-hot center pip.
  canvas.drawCircle(
    position,
    radius * 0.18,
    ui.Paint()
      ..color = const ui.Color(0xFFFFE8A0).withValues(alpha: 0.85 * pulse)
      ..maskFilter = null,
  );
  // 5 flame blobs at seeded irregular positions, flickering scale
  // independently. Each is a soft circle, not a quadratic-bezier
  // tongue silhouette.
  final flameColor = ui.Color.lerp(color, white, 0.35)!;
  final flame = ui.Paint()..maskFilter = null;
  for (var i = 0; i < 5; i++) {
    final h = (seed + i * 163) & 0xFFFF;
    final a = (h % 360) * pi / 180;
    final r = radius * (0.30 + ((h >> 4) % 50) / 100.0);
    final p = position + ui.Offset(cos(a), sin(a)) * r;
    final flicker = 0.55 + 0.45 * ((sin(time * 5.0 + (h % 23)) + 1) * 0.5);
    flame.color = flameColor.withValues(alpha: flicker * 0.62 * pulse);
    canvas.drawCircle(
      p,
      radius * (0.10 + ((h >> 8) % 14) / 100.0) * flicker,
      flame,
    );
  }
}

/// What a Plant ground zone is a picture OF.
///
/// All three used to render as the same bare moss patch, because that patch
/// was authored to sit under Mask's writhing tendril overlay and stay out of
/// its way — and that overlay is drawn for Mask alone. Every other family's
/// Plant zone was the empty bed of a picture whose subject never arrived.
enum PlantZoneStyle {
  /// Mask: the tendrils are drawn over the top, so the bed stays bare.
  bare,

  /// Kin: a healing garden that drops collectible flowers. Shoots rise and
  /// ripen into buds, so the bed looks like something producing them.
  garden,

  /// Let and Mane: damaging growth. Creeping thorned vines that spread from
  /// where they took root — the board's "vines grow from the ground and remain
  /// until an enemy collides with them".
  vines,
}

void _paintPlantZone(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  double time,
  double pulse,
  double vs, {
  PlantZoneStyle style = PlantZoneStyle.bare,
}) {
  final dark = ui.Color.lerp(color, const ui.Color(0xFF1F4F22), 0.55)!;
  canvas.drawCircle(
    position,
    radius * 0.55,
    ui.Paint()
      ..color = dark.withValues(alpha: 0.22 * pulse)
      ..maskFilter = null,
  );
  // Mask's vine has writhing tendrils drawn over the top of this, so the
  // patch stays bare on purpose and lets them carry the movement.
  if (style == PlantZoneStyle.bare) return;

  if (style == PlantZoneStyle.vines) {
    // Thorned creepers spreading out from where they rooted. Slower and
    // heavier than the garden's shoots, and barbed rather than budding,
    // because these exist to hurt whatever walks into them.
    final vine = ui.Color.lerp(color, const ui.Color(0xFF2E7D32), 0.40)!;
    final creeper = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..maskFilter = null;
    for (var i = 0; i < 6; i++) {
      final a = i * (pi * 2 / 6) + sin(time * 0.35 + i) * 0.22;
      final dir = ui.Offset(cos(a), sin(a));
      final perp = ui.Offset(-dir.dy, dir.dx);
      // Creeps out and back on a long slow cycle, so the patch looks alive
      // without ever reading as a spinning asterisk.
      final reach = radius * (0.62 + 0.26 * sin(time * 0.5 + i * 1.3));
      final mid = position + dir * reach * 0.55 + perp * reach * 0.26;
      final tip = position + dir * reach;
      creeper
        ..color = vine.withValues(alpha: 0.60 * pulse)
        ..strokeWidth = 2.0 * vs;
      canvas.drawPath(
        ui.Path()
          ..moveTo(position.dx, position.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy),
        creeper,
      );
      // Thorns along the outer half — what makes this a hazard and not a bed.
      for (var j = 1; j <= 2; j++) {
        final t = 0.55 + j * 0.2;
        final on =
            position +
            dir * reach * t +
            perp * reach * 0.26 * sin(t * pi);
        final barb = perp * (j.isEven ? 3.0 : -3.0) * vs;
        creeper
          ..color = vine.withValues(alpha: 0.70 * pulse)
          ..strokeWidth = 1.2 * vs;
        canvas.drawLine(on, on + barb - dir * 1.5 * vs, creeper);
      }
    }
    return;
  }

  // Garden: nothing is coming to fill this one in, so it grows its own.
  //
  // A garden, not a trap: shoots rising from the bed on their own cycles,
  // each swelling to a bud at the top. Kin's Plant drops a collectible
  // flower every few seconds, and the bed should look like something that
  // is producing them rather than a flat patch of moss.
  final leaf = ui.Color.lerp(color, const ui.Color(0xFF8FE07A), 0.45)!;
  final bloom = ui.Color.lerp(color, const ui.Color(0xFFFFF0A8), 0.55)!;
  final stalk = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..maskFilter = null;
  for (var i = 0; i < 7; i++) {
    final h1 = sin((i + 1) * 12.9898) * 43758.5453;
    final h2 = sin((i + 1) * 39.3468) * 24634.6345;
    final u = h1 - h1.floorToDouble();
    final v = h2 - h2.floorToDouble();
    // Each shoot runs its own slow grow-and-reseed cycle.
    final t = (time * 0.28 + u) % 1.0;
    final grow = sin(t * pi).clamp(0.0, 1.0);
    if (grow < 0.05) continue;
    final a = u * pi * 2;
    final root = position + ui.Offset(cos(a), sin(a)) * radius * 0.44 * v;
    // Leans a little as it rises, so the bed does not read as a pincushion.
    final lean = sin(time * 0.9 + i * 1.7) * radius * 0.07;
    final tip = root + ui.Offset(lean, -radius * 0.42 * grow);
    stalk
      ..color = leaf.withValues(alpha: 0.55 * grow * pulse)
      ..strokeWidth = 1.5 * vs;
    canvas.drawPath(
      ui.Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(
          root.dx + lean * 0.4,
          (root.dy + tip.dy) * 0.5,
          tip.dx,
          tip.dy,
        ),
      stalk,
    );
    // The bud swells only near the top of the cycle, so a shoot visibly
    // ripens rather than being born with a flower on it.
    final ripe = ((grow - 0.55) / 0.45).clamp(0.0, 1.0);
    if (ripe > 0) {
      canvas.drawCircle(
        tip,
        (1.1 + 1.6 * ripe) * vs,
        ui.Paint()..color = bloom.withValues(alpha: 0.75 * ripe * pulse),
      );
    }
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
  // Position-seeded shard placement so each cluster reads unique
  // instead of a perfect 72°-rotation pattern.
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  // Base patch (soft fill, no outline).
  canvas.drawCircle(
    position,
    radius * 0.6,
    ui.Paint()
      ..color = ui.Color.lerp(
        color,
        const ui.Color(0xFF000000),
        0.55,
      )!.withValues(alpha: 0.28 * pulse)
      ..maskFilter = null,
  );
  // 5 shards at seeded irregular angles + varying lengths/widths.
  const shardCount = 5;
  for (var i = 0; i < shardCount; i++) {
    final h1 = (seed + i * 191) & 0xFFFF;
    final a = (h1 % 360) * pi / 180;
    final hLen = radius * (0.65 + ((h1 >> 4) % 30) / 100.0);
    final tip = position + ui.Offset(cos(a), sin(a)) * hLen;
    final w = radius * (0.14 + ((h1 >> 8) % 10) / 100.0);
    final left = position + ui.Offset(cos(a + pi / 2), sin(a + pi / 2)) * w;
    final right = position + ui.Offset(cos(a - pi / 2), sin(a - pi / 2)) * w;
    final shard = ui.Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(
      shard,
      ui.Paint()..color = color.withValues(alpha: 0.58 * pulse),
    );
    // Soft tip glint — a small filled circle at the shard tip
    // instead of a stroked highlight line, so the shard reads as a
    // glowing pip rather than a hard-outlined geometric sprite.
    canvas.drawCircle(
      tip,
      max(1.6, 1.8 * vs),
      ui.Paint()..color = white.withValues(alpha: 0.55 * pulse),
    );
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
  // Faint frost mist + soft pillar core. No hard snowflake rosette,
  // no outlined diamond — layered translucent halos carry the read,
  // per-frame frost motes (spawned survival-side) provide the
  // sparkle. Pulse drives a subtle breathing shimmer.
  final mistOuter = ui.Paint()
    ..color = ui.Color.lerp(color, white, 0.6)!.withValues(alpha: 0.16 * pulse);
  canvas.drawCircle(position, radius * 1.05, mistOuter);
  final mistMid = ui.Paint()
    ..color = ui.Color.lerp(color, white, 0.5)!.withValues(alpha: 0.22 * pulse);
  canvas.drawCircle(position, radius * 0.78, mistMid);
  final mistInner = ui.Paint()
    ..color = ui.Color.lerp(
      color,
      white,
      0.35,
    )!.withValues(alpha: 0.32 * pulse);
  canvas.drawCircle(position, radius * 0.55, mistInner);
  // Soft pillar core — three layered halos shape a vertical "column"
  // by offsetting the centers slightly upward each layer.
  final coreA = ui.Paint()..color = color.withValues(alpha: 0.42 * pulse);
  canvas.drawCircle(
    position + ui.Offset(0, -radius * 0.10),
    radius * 0.40,
    coreA,
  );
  final coreB = ui.Paint()
    ..color = ui.Color.lerp(
      color,
      white,
      0.55,
    )!.withValues(alpha: 0.55 * pulse);
  canvas.drawCircle(
    position + ui.Offset(0, -radius * 0.18),
    radius * 0.26,
    coreB,
  );
  // Bright pip for the icy hot-center.
  final pip = ui.Paint()..color = white.withValues(alpha: 0.85 * pulse);
  canvas.drawCircle(position + ui.Offset(0, -radius * 0.22), 1.6 * vs, pip);
}

void _paintLightningField(
  ui.Canvas canvas,
  ui.Offset position,
  double radius,
  ui.Color color,
  ui.Color white,
  double time,
  double pulse,
  double vs, {
  bool reduceAmbient = false,
}) {
  _paintZoneFill(
    canvas,
    position,
    radius,
    color,
    alpha: 0.22 * pulse,
    rim: 0.5,
  );
  // The Voltara bolt, at field scale. The old version drew five straight
  // chords through the centre, which read as a spoked wheel rather than a
  // storm; these are real jagged discharges that fork and flicker off their
  // own beats. `drawLightningCrackle` is the shared renderer, so the same
  // arcs appear in survival, cosmic space and the dungeons.
  final glow = ui.Color.lerp(color, kLightningBoltGlow, 0.55)!;
  drawLightningCrackle(
    canvas,
    position,
    radius * 0.80,
    time: time,
    count: 5,
    width: 1.9 * vs,
    // Voltara's white-blue, not the field's own tint — the discharge is the
    // hottest thing in the zone and should read that way.
    core: kLightningBoltCore,
    glow: glow,
    alpha: 0.9 * pulse,
    glowPasses: reduceAmbient ? 0 : 2,
    branches: reduceAmbient ? 0 : 1,
  );
  // A ground strike into the centre — the field's heartbeat, one bright bolt
  // dropping in on a slow cadence so the zone punches instead of humming.
  final strikePhase = (time * 0.9) % 1.0;
  if (strikePhase < 0.30) {
    final fade = 1.0 - strikePhase / 0.30;
    final a = _boltNoise((time * 0.9).floorToDouble(), 1.0) * pi;
    drawLightningBolt(
      canvas,
      position + ui.Offset(cos(a), sin(a)) * radius,
      position,
      time: time,
      width: 2.4 * vs,
      jitter: radius * 0.16,
      segmentLength: max(8.0, radius * 0.22),
      core: kLightningBoltCore,
      glow: glow,
      alpha: fade,
      branches: reduceAmbient ? 0 : 2,
      glowPasses: reduceAmbient ? 0 : 2,
    );
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
  // Soft luminous well — layered faint halos that pulse with `time`,
  // a brighter inner core, and a single white-hot pip. No spokes,
  // no rune-ring outline. Position-seeded micro-glints provide the
  // alchemical sparkle without geometric stamping.
  final breathe = 0.9 + 0.10 * sin(time * 1.7);
  final haloOuter = ui.Paint()..color = white.withValues(alpha: 0.10 * pulse);
  canvas.drawCircle(position, radius * 1.05 * breathe, haloOuter);
  final haloMid = ui.Paint()..color = white.withValues(alpha: 0.22 * pulse);
  canvas.drawCircle(position, radius * 0.75 * breathe, haloMid);
  final haloInner = ui.Paint()..color = white.withValues(alpha: 0.40 * pulse);
  canvas.drawCircle(position, radius * 0.45 * breathe, haloInner);
  final coreTint = ui.Paint()..color = color.withValues(alpha: 0.45 * pulse);
  canvas.drawCircle(position, radius * 0.28, coreTint);
  final pip = ui.Paint()..color = white.withValues(alpha: 0.95 * pulse);
  canvas.drawCircle(position, max(2.2, 1.6 * vs), pip);
  // Position-seeded micro-glints — placed once per spawn (no orbiting
  // sweep) so the well reads as static-but-alive instead of a
  // rotating ring.
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  final glint = ui.Paint();
  for (var i = 0; i < 5; i++) {
    final h = (seed + i * 197) & 0xFFFF;
    final a = (h % 360) * pi / 180;
    final r = radius * (0.40 + ((h >> 4) % 50) / 100.0);
    final twinkle = 0.55 + 0.45 * sin(time * 2.1 + i * 1.3);
    glint.color = white.withValues(alpha: 0.75 * pulse * twinkle);
    canvas.drawCircle(
      position + ui.Offset(cos(a), sin(a)) * r,
      1.1 * vs,
      glint,
    );
  }
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
  // Black hole — dark fill + soft purple halo + spiral arms.
  // (Removed the hard accretion ring outline per design feedback;
  // halo + spirals carry the read.)
  final pit = ui.Paint()
    ..color = const ui.Color(0xFF000000).withValues(alpha: 0.85 * pulse);
  canvas.drawCircle(position, radius * 0.55, pit);
  final accretion = ui.Paint()..color = color.withValues(alpha: 0.28 * pulse);
  canvas.drawCircle(position, radius * 0.72, accretion);
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
  // Healing pulse — soft expanding halo (no hard outline ring).
  final pulseR = radius * (0.5 + 0.4 * (sin(time * 1.2) + 1) / 2);
  final pulseFill = ui.Paint()
    ..color = const ui.Color(
      0xFFB7FFB7,
    ).withValues(alpha: 0.18 * pulse * (1.0 - (pulseR / radius)));
  canvas.drawCircle(position, pulseR, pulseFill);
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
  // Soft updraft — three layered translucent halos + a few
  // position-seeded twinkling motes. No stroked spirals, no solid
  // tint circle. The actual rising wind streamers come from the
  // per-frame survival particle pass (`_spawnZoneParticles`).
  final faint = ui.Color.lerp(color, white, 0.55)!;
  // Three layered translucent rings — fade outward, never solid.
  canvas.drawCircle(
    position,
    radius * 0.95,
    ui.Paint()..color = color.withValues(alpha: 0.08 * pulse),
  );
  canvas.drawCircle(
    position,
    radius * 0.65,
    ui.Paint()..color = color.withValues(alpha: 0.14 * pulse),
  );
  canvas.drawCircle(
    position,
    radius * 0.38,
    ui.Paint()..color = faint.withValues(alpha: 0.20 * pulse),
  );
  // Air being LIFTED, not air sitting still.
  //
  // Three flat halos and five twinkling dots said "soft blue circle" and
  // nothing else — the comment promised rising streamers from the particle
  // pass, but a zone this size needs the lift in its own art or it reads as a
  // puddle. This is an updraft column: enemies are supposed to be unable to
  // walk through it because it picks them up.
  final lift = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..maskFilter = null;
  for (var i = 0; i < 9; i++) {
    final h1 = sin((i + 1) * 12.9898) * 43758.5453;
    final u = h1 - h1.floorToDouble();
    // Each streamer rises on its own loop and restarts at the floor.
    final t = (time * 0.85 + u) % 1.0;
    final a = u * pi * 2;
    // Spirals inward as it climbs, so the column reads as drawing air up
    // through itself rather than as parallel lines drifting.
    final band = radius * (0.86 - 0.34 * t);
    final swirl = a + t * 1.5;
    final base = position + ui.Offset(cos(swirl), sin(swirl)) * band;
    final rise = radius * 0.55 * t;
    final fade = sin(t * pi).clamp(0.0, 1.0);
    lift
      ..color = faint.withValues(alpha: 0.42 * fade * pulse)
      ..strokeWidth = (1.5 - 0.6 * t) * vs;
    canvas.drawPath(
      ui.Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          base.dx + cos(swirl + 0.6) * radius * 0.10,
          base.dy - rise * 0.55,
          base.dx,
          base.dy - rise,
        ),
      lift,
    );
  }
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  for (var i = 0; i < 5; i++) {
    final h = (seed + i * 197) & 0xFFFF;
    final a = (h % 360) * pi / 180;
    final r = radius * (0.25 + ((h >> 4) % 55) / 100.0);
    final twinkle = 0.55 + 0.45 * sin(time * 2.2 + i * 1.7);
    canvas.drawCircle(
      position + ui.Offset(cos(a), sin(a)) * r,
      1.0 * vs,
      ui.Paint()..color = white.withValues(alpha: 0.75 * pulse * twinkle),
    );
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
  // Faint sand cloud — layered translucent halos + a handful of
  // softly-twinkling motes at seeded positions. The orbiting per-
  // frame dust motes (spawned survival-side) carry the swirl.
  canvas.drawCircle(
    position,
    radius * 1.0,
    ui.Paint()..color = color.withValues(alpha: 0.10 * pulse),
  );
  canvas.drawCircle(
    position,
    radius * 0.70,
    ui.Paint()..color = color.withValues(alpha: 0.16 * pulse),
  );
  canvas.drawCircle(
    position,
    radius * 0.42,
    ui.Paint()..color = color.withValues(alpha: 0.22 * pulse),
  );
  final seed = position.dx.floor() * 7919 + position.dy.floor() * 6113;
  final mote = ui.Paint();
  for (var i = 0; i < 7; i++) {
    final h = (seed + i * 211) & 0xFFFF;
    final a = (h % 360) * pi / 180;
    final r = radius * (0.20 + ((h >> 4) % 65) / 100.0);
    final twinkle = 0.45 + 0.55 * sin(time * 2.4 + i * 0.9);
    mote.color = color.withValues(alpha: 0.55 * pulse * twinkle);
    canvas.drawCircle(position + ui.Offset(cos(a), sin(a)) * r, 1.1 * vs, mote);
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
      projectile.stationary && projectile.tickEffect != AbilityEffectKind.none;
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

/// [reduceAmbient] mirrors the performance visual mode gate: it trims the
/// secondary glow passes and the widest soft plumes, and never the authored
/// element silhouette (see docs/cosmic_ability_contract.md).
bool drawLetElementalProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,
  bool reduceAmbient = false,
}) {
  final element = projectile.element;
  if (element == null) return false;

  // The stationary catch-all below claims "any parked thing with a snare, a
  // taunt or a trail", which was written when Let was the only family placing
  // such things. It is not: Mystic parks orbitals carrying snare radii, and
  // they were being drawn as Let fallout craters — the single-slot ultimate
  // wearing another family's ground art, which is a large part of why Mystic
  // read as the same undifferentiated area damage as everything else.
  //
  // Styles that belong to another family are never Let's to claim.
  final claimedElsewhere =
      projectile.visualStyle == ProjectileVisualStyle.mysticOrbital ||
      projectile.visualStyle == ProjectileVisualStyle.kinOrbital;
  final isLetProjectile =
      projectile.visualStyle == ProjectileVisualStyle.meteor ||
      projectile.visualStyle == ProjectileVisualStyle.letShard ||
      (!claimedElsewhere &&
          projectile.stationary &&
          !projectile.decoy &&
          (projectile.trailInterval > 0 ||
              projectile.snareRadius > 0 ||
              projectile.tauntRadius > 0));
  if (!isLetProjectile) return false;

  if (projectile.stationary && !projectile.decoy) {
    _drawLetFallout(
      canvas,
      projectile,
      position,
      color,
      element,
      time,
      reduceAmbient: reduceAmbient,
    );
    return true;
  }

  if (projectile.visualStyle == ProjectileVisualStyle.meteor) {
    _drawSkyfallMeteor(
      canvas,
      projectile,
      position,
      color,
      time,
      reduceAmbient: reduceAmbient,
    );
    return true;
  }

  _drawLetElementOverlay(canvas, projectile, position, color, element, time);
  return false;
}

/// Per-element body and wake proportions for the Let meteors.
///
/// Without this every element was the same hexagon at the same size trailing
/// the same wedge, and identity rested entirely on a small accent stuck to the
/// front — which is what made the family read as one asset recoloured 17 times.
/// Earth is a slow heavy boulder with a stubby fat wake; Lightning is a small
/// fast sliver with a long thin one; Steam has almost no body at all.
///
/// (bodySize, elongation, flatten, wakeLength, wakeWidth)
const Map<String, (double, double, double, double, double)> _kLetPhysique = {
  'Earth': (1.55, 1.04, 0.96, 0.70, 1.35),
  'Mud': (1.34, 1.02, 1.00, 0.78, 1.34),
  'Lava': (1.30, 1.14, 0.90, 0.86, 1.26),
  'Steam': (1.22, 1.10, 0.96, 0.92, 1.50),
  'Dark': (1.18, 1.08, 0.94, 1.04, 1.02),
  'Water': (1.10, 1.58, 0.76, 1.20, 1.12),
  'Plant': (1.12, 1.16, 0.90, 0.96, 1.06),
  'Poison': (1.06, 1.26, 0.84, 1.00, 1.16),
  'Dust': (1.06, 1.20, 0.86, 1.02, 1.22),
  'Blood': (1.05, 1.30, 0.80, 1.00, 1.00),
  'Fire': (1.00, 1.36, 0.78, 1.26, 1.10),
  'Crystal': (1.00, 1.32, 0.68, 1.00, 0.90),
  'Ice': (0.96, 1.50, 0.60, 1.12, 0.82),
  'Light': (0.92, 1.46, 0.70, 1.30, 0.94),
  'Air': (0.90, 1.72, 0.64, 1.32, 0.90),
  'Spirit': (0.86, 1.52, 0.70, 1.16, 0.84),
  'Lightning': (0.80, 1.92, 0.52, 1.38, 0.70),
};

/// How each element's wake moves, as (wave amplitude, wave frequency).
///
/// Without this every Let dragged an identically-shaped plume and the family
/// separated on hue alone. Heavy wet elements billow slowly in big lazy
/// curves; light fast ones chop in a tight ripple; Earth barely moves at all,
/// because a boulder does not trail smoke so much as shove air.
///
/// (waveAmplitude, waveFrequency)
const Map<String, (double, double)> _kLetPlumeFlow = {
  'Earth': (0.30, 0.55),
  'Crystal': (0.38, 0.75),
  'Ice': (0.44, 0.80),
  'Mud': (1.14, 0.50),
  'Water': (1.18, 0.62),
  'Steam': (1.26, 0.58),
  'Blood': (0.98, 0.70),
  'Lava': (1.02, 0.66),
  'Poison': (1.08, 0.78),
  'Plant': (0.90, 0.86),
  'Fire': (0.94, 1.05),
  'Dust': (1.06, 1.15),
  'Dark': (0.82, 0.68),
  'Spirit': (1.12, 0.92),
  'Light': (0.64, 1.10),
  'Air': (1.20, 1.35),
  'Lightning': (0.72, 1.80),
};

void _drawSkyfallMeteor(
  ui.Canvas canvas,
  Projectile projectile,
  ui.Offset position,
  ui.Color color,
  double time, {
  bool reduceAmbient = false,
}) {
  // A falling meteor is far away when it enters the frame and close when it
  // lands, and distance is the one cue that makes a drop read as a drop. The
  // rock swells through the descent while its wake stretches — approach and
  // acceleration, from one number the runtime is already tracking.
  final fall = projectile.skyfallDuration > 0
      ? projectile.skyfallProgress
      : 1.0;
  final approach = 0.62 + 0.38 * fall;
  final wakeStretch = 0.70 + 0.62 * fall;

  final vs = projectile.visualScale.clamp(1.2, 4.8).toDouble() * approach;
  final phys =
      _kLetPhysique[projectile.element ?? ''] ?? (1.0, 1.24, 0.88, 1.0, 1.0);
  final elong = phys.$2;
  final flat = phys.$3;
  // Trail trails the meteor's actual travel direction. Previous code
  // baked in a fixed upper-right "sky" bias that ignored angle.
  final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
  final dirLen = dir.distance;
  final travelDir = dirLen > 0.01 ? dir / dirLen : const ui.Offset(1, 0);
  final perp = ui.Offset(-travelDir.dy, travelDir.dx);
  final descent = 62.0 * vs * phys.$4 * wakeStretch;
  final trailStart = position - travelDir * descent;
  final pulse = 0.78 + 0.22 * sin(time * 6.0 + projectile.life * 1.5);
  final white = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!;
  final ember = ui.Color.lerp(color, const ui.Color(0xFF000000), 0.55)!;

  // The wake. A flowing plume rather than a wedge — see [drawPlumeWake] for
  // why the straight-sided version had to go. Each element meanders on its own
  // amplitude and frequency so the family stops sharing one trail shape.
  final flow = _kLetPlumeFlow[projectile.element ?? ''] ?? (1.0, 0.9);
  drawPlumeWake(
    canvas: canvas,
    head: position,
    travelDir: travelDir,
    length: descent,
    headWidth: 10.0 * vs,
    color: color,
    time: time,
    alpha: 0.40 * pulse,
    hotColor: white,
    layers: reduceAmbient ? 1 : 3,
    seed: projectile.life,
    waveAmplitude: flow.$1,
    waveFrequency: flow.$2,
  );

  // Heat bloom. Was a plain disc bigger than the rock itself, which pooled
  // round the body and erased the silhouette; now it is stretched along travel
  // and biased backwards, so the glow reads as wake rather than aura.
  if (!reduceAmbient) {
    drawDirectionalBloom(
      canvas: canvas,
      centre: position,
      travelDir: travelDir,
      length: 13.0 * vs * phys.$4,
      width: 5.2 * vs * phys.$3,
      color: color,
      alpha: 0.15 * pulse,
    );
  }

  // The rock. A tumbling irregular body instead of a flat disc — this is
  // what gives every Let meteor a silhouette and a sense of mass. It spins
  // slowly on its own axis and is lit hot on the leading edge.
  // Spin fast enough to actually read between frames. The old body barely
  // varied from a circle, so a slow spin on it was invisible.
  final spin = time * 3.1 + projectile.life * 0.9;
  final bodyR = 5.0 * vs * phys.$1;
  final rock = buildTumblingShardPath(
    centre: position,
    radius: bodyR,
    travelDir: travelDir,
    spin: spin,
    elongation: elong,
    flatten: flat,
  );
  // One faint bleed, not two, and the body itself is translucent. Stacking
  // near-opaque fills made the meteor look painted on; letting the background
  // through keeps it reading as something lit from within.
  canvas.drawPath(
    buildTumblingShardPath(
      centre: position,
      radius: bodyR * 1.22,
      travelDir: travelDir,
      spin: spin,
      elongation: elong,
      flatten: flat,
    ),
    ui.Paint()..color = color.withValues(alpha: 0.13 * pulse),
  );
  canvas.drawPath(rock, ui.Paint()..color = color.withValues(alpha: 0.62));
  // A thin dark edge for volume — the old heavy stroke read as ink outline.
  canvas.drawPath(
    rock,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 0.8 * vs
      ..color = ember.withValues(alpha: 0.42),
  );
  // No white leading rim. A near-opaque bright stroke along the leading edge
  // outlined every meteor like cel shading and was the single worst-looking
  // thing on the family; only Lightning survived it, because its bolt drew
  // over the top. The rock's own translucent fill against the wake already
  // separates the leading face — it does not need an outline.
  // White-hot core pip, pushed toward the leading edge so the mass reads
  // as travelling rather than hovering.
  canvas.drawCircle(
    position + travelDir * bodyR * 0.22 + perp * sin(spin) * bodyR * 0.10,
    1.7 * vs,
    ui.Paint()
      ..color = const ui.Color(0xFFFFF5DC).withValues(alpha: 0.95 * pulse),
  );

  // Elemental sparkle shed into the wake. Small hard points of light read as
  // energy in a way that more translucent fill never does.
  if (!reduceAmbient) {
    drawSparkleGlints(
      canvas: canvas,
      centre: position,
      travelDir: travelDir,
      spread: descent * 0.62,
      size: 1.9 * vs,
      color: ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!,
      time: time,
      count: 6,
      seed: projectile.life,
      alpha: 0.85,
    );
  }

  // Element-specific accents on the falling meteor so each one reads
  // distinct mid-fall (lava drips, ice spikes, lightning crackle, etc).
  final element = projectile.element ?? '';
  switch (element) {
    case 'Fire':
      // A flame crown: tongues licking backwards off the rock. Fire is the
      // clean burn — no crust, no drips (that is Lava's job).
      // No licking tongues. Wagging bezier strokes trailing off the rock read
      // as worms, not flame — fire is carried by embers and glints instead.
      // Trailing ember sparks.
      for (var i = 0; i < 3; i++) {
        final t = (time * 1.4 + i * 0.33) % 1.0;
        final p = position - travelDir * (descent * 0.2 + descent * 0.5 * t);
        canvas.drawCircle(
          p + perp * sin(t * 6) * 2.5,
          1.8 * vs * (1 - t),
          ui.Paint()
            ..color = const ui.Color(
              0xFFFFB050,
            ).withValues(alpha: (1 - t) * 0.82),
        );
      }
      drawSparkleGlints(
        canvas: canvas,
        centre: position,
        travelDir: travelDir,
        spread: descent * 0.5,
        size: 2.2 * vs,
        color: const ui.Color(0xFFFFC46A),
        time: time,
        count: 5,
        seed: projectile.life + 4.0,
        alpha: 0.8,
      );
      break;
    case 'Lava':
      // A molten crust: glowing fissures across the rock plus fat drips
      // shedding off the back. Reads as heavy and wet where Fire reads dry.
      final fissure = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.0 * vs
        ..strokeCap = ui.StrokeCap.round
        ..color = ui.Color.lerp(
          color,
          const ui.Color(0xFFFFD08A),
          0.55,
        )!.withValues(alpha: 0.50 * pulse);
      for (var i = 0; i < 3; i++) {
        final a = spin * 0.6 + i * (pi * 2 / 3);
        canvas.drawLine(
          position + ui.Offset(cos(a), sin(a)) * bodyR * 0.25,
          position + ui.Offset(cos(a + 0.55), sin(a + 0.55)) * bodyR * 0.88,
          fissure,
        );
      }
      // Heavy drips: bigger, slower and more spread out than Fire's sparks.
      for (var i = 0; i < 3; i++) {
        final t = (time * 0.85 + i * 0.34) % 1.0;
        final p = position - travelDir * (descent * 0.15 + descent * 0.62 * t);
        canvas.drawCircle(
          p + perp * sin(time * 2.0 + i * 2.1) * 4.0 * vs * t,
          2.6 * vs * (1 - t * 0.85),
          ui.Paint()
            ..color = const ui.Color(
              0xFFFF8A2B,
            ).withValues(alpha: (1 - t) * 0.82),
        );
      }
      break;
    case 'Ice':
      // Comet Cluster — frost grows on the face meeting the air, and shears
      // off behind. Six spikes on a wheel read as a snowflake sticker pinned
      // to the rock, with no relationship to which way it was going.
      // Frost as glinting crystal, not drawn spikes — three lines jutting off
      // the nose read as a claw.
      drawSparkleGlints(
        canvas: canvas,
        centre: position + travelDir * bodyR * 0.3,
        travelDir: travelDir,
        spread: descent * 0.42,
        size: 2.6 * vs,
        color: const ui.Color(0xFFCFEAFF),
        time: time,
        count: 6,
        seed: projectile.life + 9.0,
        alpha: 0.85,
      );
      for (var i = 0; i < 3; i++) {
        final t = (time * 0.9 + i * 0.33) % 1.0;
        canvas.drawCircle(
          position -
              travelDir * (bodyR + descent * 0.28 * t) +
              perp * sin(time * 2.0 + i) * 3.0 * vs,
          (1.6 + 2.6 * t) * vs,
          ui.Paint()
            ..color = const ui.Color(
              0xFFCFEAFF,
            ).withValues(alpha: (1 - t) * 0.22),
        );
      }
      break;
    case 'Lightning':
      // Orbital Strike. The Voltara bolt, brought onto the meteor: a live
      // discharge running the full length of the descent trail, and static
      // crackling off the head. Element yellow is pulled toward Voltara's
      // electric blue for the halo so the storm reads the same everywhere
      // while the core stays Lightning-yellow-white.
      final boltGlow = ui.Color.lerp(color, kLightningBoltGlow, 0.55)!;
      drawLightningBolt(
        canvas,
        trailStart,
        position,
        time: time,
        width: 1.15 * vs,
        jitter: 1.5 * vs,
        segmentLength: 6.0 * vs,
        core: kLightningBoltCore,
        glow: boltGlow,
        alpha: 0.62 + 0.38 * pulse,
        // One branch, not two. At two the strays wandered clear of the
        // plume and crossed open space as detached white polylines, which
        // read as a drawn zigzag rather than as this meteor discharging.
        branches: 1,
        glowPasses: reduceAmbient ? 0 : 2,
        seed: projectile.life * 3.0,
      );
      drawLightningCrackle(
        canvas,
        position,
        8.5 * vs,
        time: time,
        count: 2,
        width: 1.0 * vs,
        glow: boltGlow,
        glowPasses: reduceAmbient ? 0 : 1,
        seed: projectile.life * 1.7,
      );
      break;
    case 'Dark':
      // Void Meteor — an event horizon, which is not a concentric ring. A full
      // circle centred on the body read as a loading spinner; light bends
      // round ONE side of a real one.
      canvas.drawCircle(
        position,
        bodyR * 0.92,
        ui.Paint()..color = const ui.Color(0xFF07020C).withValues(alpha: 0.92),
      );
      // No lensing arc. A crescent stroked round the body was still a drawn
      // ring, just an incomplete one. A void is shown by what falls into it:
      // motes spiralling inward and winking out at the horizon.
      for (var i = 0; i < 7; i++) {
        final t = (time * 0.85 + i * 0.143) % 1.0;
        // t = 0 far out, t = 1 swallowed.
        final a = i * (pi * 2 / 7) + t * 2.4 + spin * 0.3;
        final rr = bodyR * (2.6 - 1.9 * t);
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * rr,
          1.5 * vs * (1 - t * 0.8),
          ui.Paint()
            ..color = const ui.Color(
              0xFFB06BE8,
            ).withValues(alpha: (1 - t) * 0.7 * pulse),
        );
      }
      break;
    case 'Plant':
      // Seed Bombardment — seeds clinging to the rock and shaking loose. The
      // vine wrap was three lines through the centre, i.e. a spinning asterisk
      // drawn over the body.
      final seed = ui.Paint()
        ..color = const ui.Color(0xFF3E8F38).withValues(alpha: 0.72);
      for (var i = 0; i < 5; i++) {
        final a = spin * 0.6 + i * (pi * 2 / 5);
        final rr = bodyR * (0.45 + 0.32 * sin(i * 2.1));
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * rr,
          1.5 * vs,
          seed,
        );
      }
      for (var i = 0; i < 4; i++) {
        final t = (time * 1.1 + i * 0.25) % 1.0;
        canvas.drawCircle(
          position -
              travelDir * (bodyR + descent * 0.45 * t) +
              perp * sin(time * 2.2 + i * 1.6) * 4.0 * vs * t,
          1.6 * vs * (1 - t * 0.7),
          ui.Paint()
            ..color = const ui.Color(
              0xFF7BC96F,
            ).withValues(alpha: (1 - t) * 0.7),
        );
      }
      break;
    case 'Spirit':
      // Soul Harvest — the execute, made visible.
      //
      // This was three flat circles on a slow orbit: the least-considered
      // decoration in the family, and it said nothing about what the cast
      // does. Spirit's whole identity is a chance to simply delete what it
      // lands on, scaling with the caster.
      //
      // So: a pale halo that breathes, and wisps that stream INTO the rock
      // rather than circling it — something being collected, not escorted.
      // A breathing aura, filled and soft. Stroking it made a hoop, which is
      // the drawn-ring motif every other Let had removed; a haunt has no
      // outline.
      final breath = 1.7 + 0.35 * sin(time * 2.4 + projectile.life);
      for (var i = 3; i >= 1; i--) {
        canvas.drawCircle(
          position,
          bodyR * breath * (0.5 + i * 0.24),
          ui.Paint()
            ..color = const ui.Color(
              0xFFE6CCFF,
            ).withValues(alpha: (0.09 - i * 0.018) * pulse),
        );
      }
      for (var i = 0; i < 5; i++) {
        // t = 0 far out, t = 1 absorbed. Inward, so the meteor reads as
        // taking something rather than trailing it.
        final t = (time * 1.1 + i * 0.2 + projectile.life) % 1.0;
        final a = i * (pi * 2 / 5) + t * 1.8;
        final rr = bodyR * (3.0 - 2.2 * t);
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * rr,
          (1.7 - 0.9 * t) * vs,
          ui.Paint()
            ..color = const ui.Color(
              0xFFE6CCFF,
            ).withValues(alpha: (1 - t * 0.7) * 0.62 * pulse),
        );
      }
      break;
    case 'Light':
      // Celestial Rain — radiance, not a cone.
      //
      // Three nested wedges used to sit on the nose. However many layers they
      // had and however soft the alpha, a triangle is a triangle: it read as a
      // grey paper party hat taped to the front of the rock, and it was the
      // worst-looking thing in the family.
      //
      // Light is shown by what it does to everything around it — a bloom that
      // outreaches the body, and hard points of glint. No drawn geometry.
      for (var i = 3; i >= 1; i--) {
        canvas.drawCircle(
          position,
          bodyR * (1.5 + i * 0.75) * pulse,
          ui.Paint()
            ..color = const ui.Color(
              0xFFFFE9A8,
            ).withValues(alpha: (0.10 - i * 0.022) * pulse),
        );
      }
      drawSparkleGlints(
        canvas: canvas,
        centre: position,
        travelDir: travelDir,
        spread: descent * 0.45,
        size: 2.8 * vs,
        color: const ui.Color(0xFFFFF3C4),
        time: time,
        count: 7,
        seed: projectile.life + 2.0,
        alpha: 0.9,
      );
      break;
    case 'Crystal':
      // Starfall — light refracting, not plates bolted on.
      //
      // Three hard triangular facets used to jut out of the rock at fixed
      // angles. They read as origami taped to a stone, and they were the same
      // blade vocabulary Mane is built from — the last place the two families
      // still shared a shape.
      //
      // A crystal in flight is known by how it splits light: a cold rim on the
      // body and a scatter of prismatic glints, no drawn facets.
      // A lit core rather than a rim. A stroked circle round the body is the
      // same monocle Mud just lost — the glints carry "crystal", and the body
      // itself reads faceted because it is already an irregular tumbling
      // shard underneath.
      canvas.drawPath(
        buildTumblingShardPath(
          centre: position,
          radius: bodyR * 0.62,
          travelDir: travelDir,
          spin: spin * 1.4,
          elongation: elong,
          flatten: flat,
        ),
        ui.Paint()
          ..color = ui.Color.lerp(
            color,
            const ui.Color(0xFFFFFFFF),
            0.70,
          )!.withValues(alpha: 0.72 * pulse),
      );
      for (var i = 0; i < 3; i++) {
        drawSparkleGlints(
          canvas: canvas,
          centre: position,
          travelDir: travelDir,
          spread: descent * (0.22 + i * 0.14),
          size: (2.6 - i * 0.5) * vs,
          // Each pass tinted a little differently so the scatter splits colour
          // the way a prism does rather than repeating one white spark.
          color: ui.Color.lerp(
            const ui.Color(0xFFFFFFFF),
            [
              const ui.Color(0xFF9FFFE0),
              const ui.Color(0xFFCFE6FF),
              const ui.Color(0xFFFFE6F5),
            ][i],
            0.65,
          )!,
          time: time,
          count: 4,
          seed: projectile.life + 3.0 + i * 5.0,
          alpha: 0.85,
        );
      }
      break;
    case 'Water':
      // Tidal Meteor — a sheathing wave: two curved sheets of water peeled
      // back off the leading face.
      // Water sheds beads; it does not trail two drawn curves off its nose.
      for (var i = 0; i < 6; i++) {
        final t = (time * 1.15 + i * 0.17) % 1.0;
        final side = i.isEven ? 1.0 : -1.0;
        final pd =
            position -
            travelDir * (bodyR * 0.6 + descent * 0.5 * t) +
            perp * side * (2.0 + 5.0 * t) * vs;
        canvas.drawCircle(
          pd,
          (2.4 - 1.4 * t) * vs,
          ui.Paint()..color = white.withValues(alpha: (1 - t) * 0.6 * pulse),
        );
      }
      break;
    case 'Steam':
      // Geyser Strike — pressurised, about to burst.
      //
      // Grey puffs on a grey rock inside a grey plume: the row very nearly
      // vanished. The impact leaves a geyser that stands for twelve seconds,
      // so the meteor should read as something holding pressure on the way
      // down rather than as something quietly steaming.
      //
      // Jets vent in bursts on staggered cycles — brief, bright, directional —
      // instead of a steady drift of soft circles.
      final vent = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.72)!;
      for (var i = 0; i < 3; i++) {
        final cycle = (time * 1.6 + i * 0.37 + projectile.life) % 1.0;
        // Each jet is silent for most of its cycle, then blows.
        if (cycle > 0.45) continue;
        final t = cycle / 0.45;
        final a = spin * 0.4 + i * (pi * 2 / 3);
        final outDir = ui.Offset(cos(a), sin(a));
        for (var j = 0; j < 3; j++) {
          final reach = bodyR * (0.8 + j * 0.7) + descent * 0.12 * t;
          canvas.drawCircle(
            position + outDir * reach,
            (2.2 + j * 1.1) * vs * (1 - t * 0.6),
            ui.Paint()..color = vent.withValues(alpha: (1 - t) * 0.30),
          );
        }
      }
      // A hot core showing the pressure still inside it.
      canvas.drawCircle(
        position,
        bodyR * 0.55 * (0.85 + 0.15 * sin(time * 7.0)),
        ui.Paint()..color = vent.withValues(alpha: 0.55 * pulse),
      );
      break;
    case 'Earth':
      // Moon Drop — a genuine boulder: a heavy stone ring and a shed of
      // tumbling debris chunks, so the family's heaviest cast looks heavy.
      // A mantle of stone packed onto the face taking the impact — a full ring
      // round the body was the same concentric-circle motif four other Lets
      // already used.
      // Mass is carried by the big body and the shed rubble; an arc round the
      // front was just another drawn ring.
      for (var i = 0; i < 6; i++) {
        final t = (time * 0.7 + i * 0.25) % 1.0;
        final a = spin * 0.5 + i * (pi / 2);
        final p =
            position -
            travelDir * (bodyR + descent * 0.4 * t) +
            ui.Offset(cos(a), sin(a)) * 5.0 * vs;
        canvas.drawRect(
          ui.Rect.fromCenter(
            center: p,
            width: 2.8 * vs * (1 - t * 0.6),
            height: 2.2 * vs * (1 - t * 0.6),
          ),
          ui.Paint()..color = white.withValues(alpha: (1 - t) * 0.7),
        );
      }
      break;
    case 'Mud':
      // Quagmire Meteor — a sodden clod flinging fat globs.
      //
      // The stroked circle round the body has gone. A drawn ring is the exact
      // motif every other Let had already had removed for looking like a UI
      // element, and on this one it read as a monocle.
      //
      // Mud's element colour is nearly black, so the globs carry a lifted tone
      // or the whole cast disappears against space.
      final glob = ui.Color.lerp(color, const ui.Color(0xFFC79A6B), 0.55)!;
      // Wet mass clinging to the rock, lumpy and off-centre rather than a
      // concentric outline.
      for (var i = 0; i < 4; i++) {
        final a = spin * 0.5 + i * (pi * 2 / 4);
        final wobble = 0.75 + 0.25 * sin(time * 2.2 + i * 1.9);
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * bodyR * 0.72 * wobble,
          bodyR * 0.52 * wobble,
          ui.Paint()..color = glob.withValues(alpha: 0.42 * pulse),
        );
      }
      for (var i = 0; i < 4; i++) {
        final t = (time * 0.95 + i * 0.27) % 1.0;
        final p =
            position -
            travelDir * (bodyR + descent * 0.5 * t) +
            perp * sin(time * 1.4 + i * 2.4) * 6.0 * vs * t;
        canvas.drawCircle(
          p,
          2.6 * vs * (1 - t * 0.7),
          ui.Paint()..color = glob.withValues(alpha: (1 - t) * 0.78),
        );
      }
      break;
    case 'Air':
      // Atmospheric Bomb — a compression shell: sheared arcs stacked on the
      // leading face, the shock the falling mass piles up ahead of itself.
      // Stacked arcs on the nose read as drawn shockwave rings. Air is shown
      // by what it carries: motes streaming past and swirling off.
      for (var i = 0; i < 7; i++) {
        final t = (time * 1.35 + i * 0.143) % 1.0;
        final swirl = sin(time * 3.0 + i * 1.7) * 4.5 * vs * t;
        final pa =
            position -
            travelDir * (bodyR * 0.4 + descent * 0.62 * t) +
            perp * swirl;
        canvas.drawCircle(
          pa,
          (1.7 - 0.9 * t) * vs,
          ui.Paint()..color = white.withValues(alpha: (1 - t) * 0.5 * pulse),
        );
      }
      break;
    case 'Dust':
      // Sandstorm Meteor — a grit veil: a wide swarm of specks smeared back
      // along the trail rather than a tidy orbit.
      for (var i = 0; i < 7; i++) {
        final t = (time * 1.3 + i * 0.14) % 1.0;
        final p =
            position -
            travelDir * (bodyR + descent * 0.62 * t) +
            perp * sin(i * 2.3 + time * 2.2) * 7.5 * vs * t;
        canvas.drawCircle(
          p,
          1.2 * vs * (1 - t * 0.5),
          ui.Paint()..color = white.withValues(alpha: (1 - t) * 0.62),
        );
      }
      break;
    case 'Poison':
      // Toxic Storm — a sickly bloom: unevenly sized bubbles clinging to the
      // rock and shearing off, so it never reads like a plain purple ball.
      for (var i = 0; i < 5; i++) {
        final a = spin * 0.9 + i * (pi * 2 / 5);
        final wobble = 0.7 + 0.3 * sin(time * 3.1 + i * 1.7);
        canvas.drawCircle(
          position + ui.Offset(cos(a), sin(a)) * bodyR * 1.25 * wobble,
          (1.4 + 1.1 * wobble) * vs,
          ui.Paint()
            ..color = const ui.Color(
              0xFFD98CFF,
            ).withValues(alpha: 0.55 * pulse),
        );
      }
      canvas.drawCircle(
        position,
        bodyR * 1.7,
        ui.Paint()..color = color.withValues(alpha: 0.16 * pulse),
      );
      break;
    case 'Blood':
      // Transfusion Meteor — a wet clot: a thick crimson rim with strings of
      // droplets peeling off, the only Let that heals its caster on cast.
      // A meniscus of blood bulging on the leading face, pushed back by the
      // airstream — not another ring centred on the rock.
      // The droplet string carries this one; the meniscus arc was a drawn
      // crescent floating off the front.
      for (var i = 0; i < 6; i++) {
        final t = (time * 1.05 + i * 0.26) % 1.0;
        final p =
            position -
            travelDir * (bodyR + descent * 0.45 * t) +
            perp * (i.isEven ? 1 : -1) * 3.0 * vs * t;
        canvas.drawCircle(
          p,
          2.0 * vs * (1 - t * 0.75),
          ui.Paint()
            ..color = const ui.Color(
              0xFFB3131E,
            ).withValues(alpha: (1 - t) * 0.82),
        );
      }
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
    // Removed the outline ring per design feedback; keep the dashed
    // spoke marks since they still read as a beacon visual.
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
    // Removed the snare-indicator outline ring per design feedback.

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
  double time, {
  bool reduceAmbient = false,
}) {
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
      // Let+Plant leaves four of these standing for thirty seconds each —
      // the longest-lived placements in the game, and the board calls them
      // vines that remain until an enemy collides with them.
      _paintPlantZone(
        canvas,
        position,
        radius,
        color,
        time,
        pulse,
        vs,
        style: PlantZoneStyle.vines,
      );
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
        reduceAmbient: reduceAmbient,
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
  // Outline ring removed per design feedback. Layered translucent
  // halo fills + bright core pip carry the spirit-wisp read.
  final breathe = 0.85 + 0.15 * sin(time * 2.0);
  for (var i = 3; i >= 1; i--) {
    canvas.drawCircle(
      position,
      radius * (0.55 + i * 0.18) * breathe,
      ui.Paint()
        ..color = color.withValues(alpha: (0.04 + i * 0.03))
        ..maskFilter = null,
    );
  }
  canvas.drawCircle(
    position,
    2.2 * vs,
    ui.Paint()..color = const ui.Color(0xFFE6E9FF).withValues(alpha: 0.55),
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
  // Outline ring removed per design feedback. Soft halo fill +
  // orbiting crown petals do the visual on their own.
  canvas.drawCircle(
    position,
    radius * 0.95,
    ui.Paint()..color = color.withValues(alpha: 0.10),
  );
  for (var i = 0; i < 6; i++) {
    final a = time * 0.9 + i * pi / 3;
    canvas.drawCircle(
      position + ui.Offset(cos(a), sin(a)) * radius,
      1.3 * vs,
      ui.Paint()..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.78),
    );
  }
}

/// Sink for a single ambient zone-VFX particle. Each game adapts this to its
/// own particle pool (survival `_VfxParticle`, cosmic `VfxParticle`, dungeon
/// `_AlchemyParticle`). `arc` requests a lightning-zap render where the pool
/// supports it (otherwise the particle just renders as a normal wisp).
typedef ZoneVfxEmit =
    void Function(
      double x,
      double y,
      double vx,
      double vy,
      double size,
      double life,
      ui.Color color, {
      bool arc,
    });

/// Single source of truth for the per-element ambient wisps that make a
/// stationary zone/aura/trap projectile feel alive — embers off a Fire pool,
/// bubbles off a Poison cloud, rain inside a kin Water cloud, updraft
/// streamers for kin Air, etc. Lifted verbatim from Cosmic Survival (the
/// canonical look) so survival, cosmic space, and dungeons all emit identical
/// particles; each caller supplies [emit] to route into its own pool and is
/// responsible for the per-frame spawn cadence + pool cap.
void emitZoneParticles(Projectile p, Random rng, ZoneVfxEmit emit) {
  final element = p.element ?? '';
  final ec = elementColor(element);
  final r = p.effectRadius;
  if (r <= 0) return;

  // Kin-specific directional overrides — ship-attached auras get dedicated
  // visuals so they read as a rain cloud or updraft column instead of a
  // generic puddle.
  if (p.abilityFamily == 'kin' && p.attachedToSlot != -2) {
    if (element == 'Water') {
      // Rain drops: spawn near the top of the cloud and fall down.
      if (rng.nextDouble() > 0.85) return;
      final dx = (rng.nextDouble() - 0.5) * r * 1.4;
      emit(
        p.position.dx + dx,
        p.position.dy - r * 0.6,
        dx * 0.05,
        100 + rng.nextDouble() * 80,
        1.1 + rng.nextDouble() * 0.8,
        0.45 + rng.nextDouble() * 0.25,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.55)!,
      );
      return;
    }
    if (element == 'Air') {
      // Updraft streamers: spawn at the bottom and shoot up.
      if (rng.nextDouble() > 0.7) return;
      final a = rng.nextDouble() * 2 * pi;
      final rr = r * (0.30 + rng.nextDouble() * 0.60);
      emit(
        p.position.dx + cos(a) * rr,
        p.position.dy + sin(a) * rr * 0.35,
        cos(a) * (6 + rng.nextDouble() * 8),
        -110 - rng.nextDouble() * 70,
        1.0 + rng.nextDouble() * 1.0,
        0.45 + rng.nextDouble() * 0.30,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.55)!,
      );
      return;
    }
  }

  // Skip-rate per element: most zones spawn a wisp every ~2-3 frames (gentle
  // ambient shimmer). Fire/Lava/Lightning/Steam spawn more often.
  const activeElements = {'Lava', 'Fire', 'Lightning', 'Steam'};
  final spawnChance = activeElements.contains(element) ? 0.55 : 0.30;
  if (rng.nextDouble() > spawnChance) return;

  switch (element) {
    case 'Lava':
    case 'Fire':
      // Ember pop drifting upward + slightly outward.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.60);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (8 + rng.nextDouble() * 12),
        -25 - rng.nextDouble() * 30,
        1.4 + rng.nextDouble() * 1.4,
        0.45 + rng.nextDouble() * 0.35,
        rng.nextBool()
            ? const ui.Color(0xFFFFB060)
            : const ui.Color(0xFFFFD080),
      );
      break;
    case 'Poison':
      // Bubble pops drifting upward, tinted poison.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.60);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (4 + rng.nextDouble() * 8),
        -18 - rng.nextDouble() * 18,
        1.3 + rng.nextDouble() * 1.2,
        0.55 + rng.nextDouble() * 0.35,
        ec,
      );
      break;
    case 'Mud':
      // Sloppy splat dot — drops a bit, settles. Subtle.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.15 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (2 + rng.nextDouble() * 6),
        4 + rng.nextDouble() * 8,
        1.4 + rng.nextDouble() * 1.0,
        0.4 + rng.nextDouble() * 0.3,
        ui.Color.lerp(ec, const ui.Color(0xFF221008), 0.45)!,
      );
      break;
    case 'Water':
      // Droplet flicker — small, drifts outward gently.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.40 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (12 + rng.nextDouble() * 14),
        sin(a) * (12 + rng.nextDouble() * 14),
        1.1 + rng.nextDouble() * 0.9,
        0.35 + rng.nextDouble() * 0.3,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.45)!,
      );
      break;
    case 'Plant':
      // Spore particle drifting upward + slightly random.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * 6,
        -10 - rng.nextDouble() * 16,
        1.2 + rng.nextDouble() * 1.0,
        0.5 + rng.nextDouble() * 0.4,
        const ui.Color(0xFFB0FFB0),
      );
      break;
    case 'Crystal':
      // Sparkle mote orbiting outward briefly.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.65);
      final tang = ui.Offset(-sin(a), cos(a));
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        tang.dx * 18 + cos(a) * 6,
        tang.dy * 18 + sin(a) * 6,
        1.1 + rng.nextDouble() * 0.9,
        0.35 + rng.nextDouble() * 0.3,
        const ui.Color(0xFFFFFFFF),
      );
      break;
    case 'Ice':
      // Frost mote drifting outward + falling.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.25 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (6 + rng.nextDouble() * 10),
        sin(a) * (6 + rng.nextDouble() * 10) + 6,
        1.0 + rng.nextDouble() * 1.0,
        0.5 + rng.nextDouble() * 0.35,
        const ui.Color(0xFFFFFFFF),
      );
      break;
    case 'Lightning':
      // Arc flicker — bright zap that pops at a random position.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.15 + rng.nextDouble() * 0.80);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (15 + rng.nextDouble() * 25),
        sin(a) * (15 + rng.nextDouble() * 25),
        1.4 + rng.nextDouble() * 1.4,
        0.25 + rng.nextDouble() * 0.25,
        rng.nextBool() ? const ui.Color(0xFFFFFFFF) : ec,
        arc: true,
      );
      break;
    case 'Steam':
      // Steam puff rising upward + slight outward drift.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.15 + rng.nextDouble() * 0.50);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (8 + rng.nextDouble() * 8),
        -22 - rng.nextDouble() * 28,
        1.8 + rng.nextDouble() * 1.5,
        0.6 + rng.nextDouble() * 0.35,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.55)!,
      );
      break;
    case 'Earth':
      // Dust kick — small earthy speck pops up from the ground.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.30 + rng.nextDouble() * 0.50);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (4 + rng.nextDouble() * 8),
        -8 - rng.nextDouble() * 12,
        1.2 + rng.nextDouble() * 0.8,
        0.4 + rng.nextDouble() * 0.3,
        ui.Color.lerp(ec, const ui.Color(0xFF4A362B), 0.40)!,
      );
      break;
    case 'Dark':
      // Inward suck fleck — flies INTO the zone from the rim.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.85 + rng.nextDouble() * 0.20);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        -cos(a) * (35 + rng.nextDouble() * 50),
        -sin(a) * (35 + rng.nextDouble() * 50),
        1.3 + rng.nextDouble() * 1.2,
        0.4 + rng.nextDouble() * 0.3,
        rng.nextBool()
            ? const ui.Color(0xFFB89AFF)
            : const ui.Color(0xFF1A0A2A),
      );
      break;
    case 'Light':
      // Outward shine sparkle from the dome rim.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.55 + rng.nextDouble() * 0.40);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * (10 + rng.nextDouble() * 14),
        sin(a) * (10 + rng.nextDouble() * 14),
        1.2 + rng.nextDouble() * 0.9,
        0.4 + rng.nextDouble() * 0.3,
        const ui.Color(0xFFFFFFFF),
      );
      break;
    case 'Air':
      // Leaf-wind drift — particle swirls tangentially.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.30 + rng.nextDouble() * 0.60);
      final tang = ui.Offset(-sin(a), cos(a));
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        tang.dx * 25 + cos(a) * 8,
        tang.dy * 25 + sin(a) * 8,
        1.1 + rng.nextDouble() * 0.9,
        0.45 + rng.nextDouble() * 0.30,
        ui.Color.lerp(ec, const ui.Color(0xFFFFFFFF), 0.45)!,
      );
      break;
    case 'Dust':
      // Speck swirl — tangential drift like Air but tinted dust.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.65);
      final tang = ui.Offset(-sin(a), cos(a));
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        tang.dx * 20 + cos(a) * 6,
        tang.dy * 20 + sin(a) * 6,
        1.0 + rng.nextDouble() * 0.8,
        0.4 + rng.nextDouble() * 0.3,
        ec,
      );
      break;
    case 'Spirit':
      // Ghost wisp drifting upward + sideways.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.20 + rng.nextDouble() * 0.55);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * 8 + (rng.nextDouble() - 0.5) * 14,
        -10 - rng.nextDouble() * 18,
        1.4 + rng.nextDouble() * 1.2,
        0.55 + rng.nextDouble() * 0.35,
        const ui.Color(0xFFE6E9FF),
      );
      break;
    case 'Blood':
      // Drip pulse — small dark-red drip falls.
      final a = rng.nextDouble() * 2 * pi;
      final spawnR = r * (0.25 + rng.nextDouble() * 0.50);
      emit(
        p.position.dx + cos(a) * spawnR,
        p.position.dy + sin(a) * spawnR,
        cos(a) * 4,
        4 + rng.nextDouble() * 10,
        1.3 + rng.nextDouble() * 1.0,
        0.45 + rng.nextDouble() * 0.30,
        ec,
      );
      break;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SHARED LIGHTNING BOLT
//
// Lifted from the Voltara planet dungeon (`_drawJaggedBolt` in
// planet_dungeon_game_lightning.dart), which is the look the storm should
// have everywhere. The dungeon now calls straight into this, so survival,
// cosmic space and the dungeons all draw the identical bolt instead of each
// game growing its own zigzag.
//
// Cost: one Path with at most `_kBoltMaxSteps` lineTo's, stroked up to three
// times with module-cached Paints (glow → halo → white-hot core). No
// MaskFilter, no saveLayer, no per-frame allocation beyond the Path itself.
// ─────────────────────────────────────────────────────────────────────────

/// Voltara's white-blue bolt core.
const ui.Color kLightningBoltCore = ui.Color(0xFFEAF6FF);

/// Voltara's cool halo tone, the colour that makes the bolt read as electric.
const ui.Color kLightningBoltGlow = ui.Color(0xFF6BA8FF);

const int _kBoltMaxSteps = 18;

final ui.Paint _boltPaint = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

/// Deterministic, allocation-free hash in [-1, 1]. Same trick the dungeon's
/// bolt used (a sin-scramble seeded off position + index) so a bolt between
/// two fixed points animates rather than strobes randomly.
double _boltNoise(double a, double b) {
  final v = sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return (v - v.floorToDouble()) * 2.0 - 1.0;
}

/// Builds the jagged path between [a] and [b]: the straight run displaced
/// along its own normal by a time-driven wobble, exactly as Voltara does it.
ui.Path _boltPath(
  ui.Offset a,
  ui.Offset b,
  double time,
  double jitter,
  double segmentLength,
  double seed,
) {
  final delta = b - a;
  final len = delta.distance;
  final path = ui.Path()..moveTo(a.dx, a.dy);
  if (len < 1) {
    path.lineTo(b.dx, b.dy);
    return path;
  }
  final nrm = ui.Offset(-delta.dy / len, delta.dx / len);
  final steps = (len / segmentLength).clamp(2, _kBoltMaxSteps).floor();
  for (var i = 1; i < steps; i++) {
    final t = i / steps;
    // Taper the wobble toward both anchors so the bolt still connects
    // cleanly to whatever it is arcing between.
    final taper = 1.0 - (t * 2.0 - 1.0).abs() * 0.55;
    final j =
        sin(time * 22 + i * 1.7 + seed) * jitter * taper +
        _boltNoise(seed + i * 3.1, (time * 9).floorToDouble()) *
            jitter *
            0.45 *
            taper;
    final base = a + delta * t;
    path.lineTo(base.dx + nrm.dx * j, base.dy + nrm.dy * j);
  }
  path.lineTo(b.dx, b.dy);
  return path;
}

/// Strokes a bolt path as glow → halo → white-hot core. [glowPasses] is the
/// performance dial: 0 draws the core only (performance visual mode), 1 adds
/// the halo, 2 is the full Voltara stack.
void _strokeBolt(
  ui.Canvas canvas,
  ui.Path path,
  double width,
  ui.Color core,
  ui.Color glow,
  double alpha,
  int glowPasses,
) {
  if (glowPasses >= 2) {
    _boltPaint
      ..strokeWidth = width * 3.0
      ..color = glow.withValues(alpha: 0.14 * alpha);
    canvas.drawPath(path, _boltPaint);
  }
  if (glowPasses >= 1) {
    _boltPaint
      ..strokeWidth = width * 1.75
      ..color = glow.withValues(alpha: 0.34 * alpha);
    canvas.drawPath(path, _boltPaint);
  }
  _boltPaint
    ..strokeWidth = width
    ..color = core.withValues(alpha: 0.95 * alpha);
  canvas.drawPath(path, _boltPaint);
}

/// A crackling lightning segment between [a] and [b] — the single canonical
/// bolt for every game. A jittering zigzag with a layered core+glow ramp and
/// optional forks, so a bolt reads as a real discharge instead of a line.
///
/// [glowPasses]: 2 = full stack, 1 = halo + core, 0 = core only (performance
/// visual mode). The core is never dropped, so lightning identity survives.
void drawLightningBolt(
  ui.Canvas canvas,
  ui.Offset a,
  ui.Offset b, {
  required double time,
  double width = 3.4,
  double jitter = 6.0,
  double segmentLength = 26.0,
  ui.Color core = kLightningBoltCore,
  ui.Color glow = kLightningBoltGlow,
  double alpha = 1.0,
  int branches = 0,
  int glowPasses = 2,
  double seed = 0,
}) {
  final s = seed + a.dx * 0.05;
  final path = _boltPath(a, b, time, jitter, segmentLength, s);
  _strokeBolt(canvas, path, width, core, glow, alpha, glowPasses);
  if (branches <= 0) return;

  // Forks: short, thinner offshoots that leave the trunk part-way along and
  // veer off. Bounded by `branches` so the cost stays fixed.
  final delta = b - a;
  final len = delta.distance;
  if (len < 12) return;
  final dir = delta / len;
  final nrm = ui.Offset(-dir.dy, dir.dx);
  final fork = ui.Path();
  for (var i = 0; i < branches; i++) {
    final t = 0.28 + 0.44 * ((i + 0.5) / branches);
    final root = a + delta * t;
    // Flicker each fork on its own beat so they do not pop in unison.
    final beat = sin(time * 7.0 + i * 2.3 + s);
    if (beat < -0.15) continue;
    final side = i.isEven ? 1.0 : -1.0;
    final reach = len * (0.16 + 0.12 * _boltNoise(s + i, 4.0).abs());
    final tip =
        root +
        dir * reach * 0.55 +
        nrm * side * reach * (0.55 + 0.3 * _boltNoise(s + i, 9.0).abs());
    final mid = ui.Offset(
      (root.dx + tip.dx) * 0.5 + nrm.dx * side * reach * 0.18,
      (root.dy + tip.dy) * 0.5 + nrm.dy * side * reach * 0.18,
    );
    fork
      ..moveTo(root.dx, root.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(tip.dx, tip.dy);
  }
  _strokeBolt(
    canvas,
    fork,
    width * 0.52,
    core,
    glow,
    alpha * 0.72,
    glowPasses > 0 ? 1 : 0,
  );
}

/// A short arc that crawls around [center] — the "static crackle" form of the
/// shared bolt, used by lightning meteors and lightning fields so a discharge
/// clinging to a body looks like the same storm as a bolt spanning a room.
void drawLightningCrackle(
  ui.Canvas canvas,
  ui.Offset center,
  double radius, {
  required double time,
  required int count,
  double width = 1.6,
  ui.Color core = kLightningBoltCore,
  ui.Color glow = kLightningBoltGlow,
  double alpha = 1.0,
  int glowPasses = 2,
  double seed = 0,
  int branches = 0,
}) {
  for (var i = 0; i < count; i++) {
    // Each arc flickers on its own beat; a bolt that is always on reads as
    // wire, a bolt that blinks reads as electricity.
    final beat = sin(time * 13.0 + i * 2.7 + seed);
    if (beat < -0.35) continue;
    final a1 = i * (pi * 2 / count) + sin(time * 3.1 + i) * 0.6 + seed;
    // Short peripheral chords, not diameters — a discharge web that stays
    // inside the body/zone instead of skewering it corner to corner.
    final a2 = a1 + pi * (0.34 + 0.42 * _boltNoise(seed + i, 2.0).abs());
    final r1 = radius * (0.70 + 0.30 * _boltNoise(seed + i, 5.0).abs());
    final r2 = radius * (0.60 + 0.40 * _boltNoise(seed + i, 7.0).abs());
    drawLightningBolt(
      canvas,
      center + ui.Offset(cos(a1), sin(a1)) * r1,
      center + ui.Offset(cos(a2), sin(a2)) * r2,
      time: time,
      width: width,
      jitter: radius * 0.22,
      segmentLength: max(6.0, radius * 0.30),
      core: core,
      glow: glow,
      alpha: alpha * (0.55 + 0.45 * beat.abs()),
      glowPasses: glowPasses,
      branches: branches,
      seed: seed + i * 5.3,
    );
  }
}

/// One ambient ability particle (zone wisp, hit spark, burst fleck, …).
/// Mirrors Cosmic Survival's `_VfxParticle` exactly — same fields, same 0.92
/// drag, same `alpha` falloff — so it is the single canonical definition.
class AbilityVfxParticle {
  double x, y, vx, vy, size, life;
  final double maxLife;
  final ui.Color color;
  AbilityVfxParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
  }) : maxLife = life;
  double get alpha => (life / maxLife * 2).clamp(0.0, 1.0);
  bool get dead => life <= 0;
  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vx *= 0.92;
    vy *= 0.92;
    life -= dt;
  }
}

/// Shared pool + canonical render for combat-ability particles, so survival,
/// cosmic space, and dungeons draw them identically. Each game owns one
/// instance, calls [update]/[render] in its loop, and routes its ability
/// emitters here (via [add]) instead of into its own flavor-VFX pool. The
/// render is byte-for-byte survival's: a single soft circle, no glow/blur, so
/// it matches the source of truth.
class AbilityVfxPool {
  final List<AbilityVfxParticle> particles = [];

  int get length => particles.length;
  bool get isEmpty => particles.isEmpty;

  void add(
    double x,
    double y,
    double vx,
    double vy,
    double size,
    double life,
    ui.Color color,
  ) {
    particles.add(
      AbilityVfxParticle(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        size: size,
        life: life,
        color: color,
      ),
    );
  }

  void update(double dt) {
    for (final p in particles) {
      p.update(dt);
    }
    particles.removeWhere((p) => p.dead);
  }

  /// Survival's exact particle render. [reduceAmbient] mirrors survival's
  /// performance gate (skip every other particle).
  void render(ui.Canvas canvas, {bool reduceAmbient = false}) {
    for (var i = 0; i < particles.length; i++) {
      final p = particles[i];
      if (p.dead) continue;
      if (reduceAmbient && i.isOdd) continue;
      canvas.drawCircle(
        ui.Offset(p.x, p.y),
        p.size * p.alpha,
        ui.Paint()..color = p.color.withValues(alpha: p.alpha * 0.8),
      );
    }
  }
}

/// Mask+Plant "wormy tendrils" overlay — the writhing vines a Plant trap grows
/// as it feeds, reaching toward nearby enemies to bite. Lifted verbatim from
/// Cosmic Survival (the source of truth) so cosmic space + dungeons grow the
/// exact same plant. The caller passes [time] and [targetsInReach]: enemy
/// positions within the vine's reach, nearest-first (empty = idle sway).
void drawMaskPlantWormyTendrils({
  required ui.Canvas canvas,
  required Projectile vine,
  required ui.Color color,
  required double time,
  required List<ui.Offset> targetsInReach,
}) {
  final feeds = vine.effectStacks.clamp(0, 100);
  final feedT = feeds / 100.0;
  // Always at least 1 tendril once the vine exists, +1 per 10 feeds.
  final tendrilCount = (1 + (feeds ~/ 10)).clamp(1, 10);

  final t = time;
  final reach = max(vine.snareRadius, vine.effectRadius);
  final dark = ui.Color.lerp(color, const ui.Color(0xFF1F4F22), 0.45)!;
  final bright = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!;
  // Feed flash: abilityGrowthTimer is bumped to 1.0 on regular feeds and 2.0
  // on tendril-unlock feeds. Pump stroke width + brightness briefly so the
  // cast lands with weight.
  final rawFlash = vine.abilityGrowthTimer;
  final flash = rawFlash.clamp(0.0, 1.0);
  final flashBoost = 1.0 + 0.55 * flash;
  final strokeWidth = ((1.6 + 1.8 * feedT) * flashBoost)
      .clamp(1.4, 6.0)
      .toDouble();
  final amplitude = ((6.0 + 10.0 * feedT) * (1.0 + 0.30 * flash))
      .clamp(4.0, 24.0)
      .toDouble();
  // Idle tendril reach scales with the vine's visual radius so a bigger trunk
  // sprouts longer idle limbs.
  final idleReach = max(
    26.0,
    (vine.snareRadius > 0 ? vine.snareRadius * 0.55 : reach * 0.55),
  );
  const segs = 12;
  // Stable per-tendril seed so each one keeps its identity across frames
  // (idle direction, phase offset, target slot).
  final rootSeed =
      vine.position.dx.floor() * 7919 + vine.position.dy.floor() * 6113;

  final tendril = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  final tip = ui.Paint();

  // Feed-flash root halo — brief expanding pulse around the root. Larger /
  // brighter on tendril-unlock feeds (rawFlash > 1.0).
  if (flash > 0.01) {
    final isUnlock = rawFlash > 1.0;
    final unlockBoost = isUnlock ? 1.6 : 1.0;
    final pulseR =
        (vine.snareRadius > 0 ? vine.snareRadius * 0.35 : 28.0) *
        unlockBoost *
        (1.0 + 0.8 * (1.0 - flash));
    canvas.drawCircle(
      vine.position,
      pulseR,
      ui.Paint()..color = bright.withValues(alpha: 0.18 * flash),
    );
    canvas.drawCircle(
      vine.position,
      pulseR * 0.55,
      ui.Paint()
        ..color = bright.withValues(alpha: (isUnlock ? 0.45 : 0.32) * flash),
    );
  }

  for (var ti = 0; ti < tendrilCount; ti++) {
    // Tendril identity: a stable angle around the root for idle pose, a stable
    // phase offset for the wave.
    final h = (rootSeed + ti * 211) & 0xFFFF;
    final idleBaseAngle = (h % 360) * pi / 180;
    final phaseOffset = ti * 1.31 + ((h >> 8) % 100) / 100.0;

    // Pick this tendril's target by stable index — distributes tendrils across
    // multiple enemies when several are in range.
    ui.Offset endPoint;
    bool attacking;
    if (targetsInReach.isNotEmpty) {
      endPoint = targetsInReach[ti % targetsInReach.length];
      attacking = true;
    } else {
      // Idle: end point slowly drifts around the root.
      final sway =
          sin(t * 0.9 + phaseOffset * 2.7) * 0.45 +
          sin(t * 1.7 + phaseOffset) * 0.25;
      final pulse = 0.80 + 0.20 * sin(t * 1.3 + phaseOffset * 1.4);
      final a = idleBaseAngle + sway;
      endPoint = vine.position + ui.Offset(cos(a), sin(a)) * idleReach * pulse;
      attacking = false;
    }

    final delta = endPoint - vine.position;
    final dist = delta.distance;
    if (dist < 0.01) continue;
    final perp = ui.Offset(-delta.dy / dist, delta.dx / dist);

    // Wave amplitude: idle is gentler than attacking.
    final ampScale = attacking ? 1.0 : 0.60;

    final path = ui.Path();
    for (var s = 0; s <= segs; s++) {
      final tFrac = s / segs;
      final base = vine.position + delta * tFrac;
      // Envelope: 0 at root + tip, peak in middle (so the root stays anchored
      // and the tip bites cleanly).
      final env = sin(tFrac * pi);
      final wave =
          sin(tFrac * pi * 3.2 + t * (attacking ? 6.5 : 3.2) + phaseOffset) *
              0.65 +
          sin(tFrac * pi * 5.6 + t * (attacking ? 4.2 : 2.0) + phaseOffset) *
              0.35;
      final pt = base + perp * (wave * amplitude * env * ampScale);
      if (s == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }

    // Alpha lifts during the feed flash so the whole plant briefly glows
    // brighter on cast.
    final outerAlpha = (attacking ? 0.22 : 0.14) + 0.18 * flash;
    final mainAlpha = (attacking ? 0.90 : 0.70) + 0.10 * flash;
    final highlightAlpha = (attacking ? 0.60 : 0.42) + 0.35 * flash;
    tendril
      ..strokeWidth = strokeWidth * 2.2
      ..color = dark.withValues(alpha: outerAlpha.clamp(0.0, 1.0));
    canvas.drawPath(path, tendril);
    tendril
      ..strokeWidth = strokeWidth
      ..color = dark.withValues(alpha: mainAlpha.clamp(0.0, 1.0));
    canvas.drawPath(path, tendril);
    tendril
      ..strokeWidth = max(0.9, strokeWidth * 0.45)
      ..color = bright.withValues(alpha: highlightAlpha.clamp(0.0, 1.0));
    canvas.drawPath(path, tendril);

    if (attacking) {
      // Single pulsing fang at the enemy end.
      final bite = 0.55 + 0.45 * sin(t * 9.0 + phaseOffset);
      tip.color = bright.withValues(alpha: 0.55 * bite);
      canvas.drawCircle(endPoint, 1.4 + 1.2 * feedT, tip);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic projectile fallback
//
// What a projectile looks like when no authored family renderer claims it.
// kin (kinOrbital), mystic (mysticOrbital) and wing (standard) projectiles have
// no dedicated renderer, so this IS their artwork rather than a degraded stand-
// in; the meteor/slash/dart/sigil/hornImpact/letShard cases below are reached
// only when the family renderer declined the projectile.
//
// Lifted out of cosmic_survival_game so survival, cosmic space and the preview
// harness share one silhouette instead of survival owning a copy nothing else
// can reach. Paints are module-level and mutated in place, exactly as the
// survival instance fields were — no per-frame Paint allocation added.
// ─────────────────────────────────────────────────────────────────────────────

final ui.Paint _genericCorePaint = ui.Paint();
final ui.Paint _genericGlowPaint = ui.Paint();
final ui.Paint _genericLinePaint = ui.Paint()
  ..strokeCap = ui.StrokeCap.round
  ..style = ui.PaintingStyle.stroke;

void drawGenericProjectileVisual({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required ui.Color color,
  required double time,

  /// Performance visual mode. Survival early-returns before reaching this
  /// renderer when it is on, so today it is always false here; the parameter
  /// keeps the original guard honest instead of baking in that assumption.
  bool reduceAmbient = false,
}) {
  switch (projectile.visualStyle) {
    case ProjectileVisualStyle.meteor:
      final tailLen = 22.0 * projectile.visualScale;
      final tailStart = ui.Offset(
        position.dx - cos(projectile.angle) * tailLen,
        position.dy - sin(projectile.angle) * tailLen,
      );
      canvas.drawLine(
        tailStart,
        position,
        ui.Paint()
          ..shader = ui.Gradient.linear(
            tailStart,
            position,
            [
              color.withValues(alpha: 0.02),
              color.withValues(alpha: 0.35),
              ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.35)!,
            ],
            const [0.0, 0.6, 1.0],
          )
          ..strokeWidth = 7.5 * projectile.visualScale
          ..strokeCap = ui.StrokeCap.round,
      );
      canvas.drawCircle(
        position,
        6.0 * projectile.visualScale,
        ui.Paint()..color = color.withValues(alpha: 0.92),
      );
      canvas.drawCircle(
        ui.Offset(
          position.dx - cos(projectile.angle) * (2.5 * projectile.visualScale),
          position.dy - sin(projectile.angle) * (2.5 * projectile.visualScale),
        ),
        3.2 * projectile.visualScale,
        ui.Paint()
          ..color = ui.Color.lerp(color, const ui.Color(0xFF2B1A12), 0.55)!,
      );
      canvas.drawCircle(
        ui.Offset(
          position.dx +
              cos(projectile.angle + 0.6) * (1.8 * projectile.visualScale),
          position.dy +
              sin(projectile.angle + 0.6) * (1.8 * projectile.visualScale),
        ),
        1.7 * projectile.visualScale,
        ui.Paint()..color = const ui.Color(0xFFFFF2D6).withValues(alpha: 0.85),
      );

    case ProjectileVisualStyle.slash:
      final len = 8.0 * projectile.visualScale;
      _genericLinePaint
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 2.5;
      canvas.drawLine(
        ui.Offset(
          position.dx - cos(projectile.angle) * len,
          position.dy - sin(projectile.angle) * len,
        ),
        ui.Offset(
          position.dx + cos(projectile.angle) * len,
          position.dy + sin(projectile.angle) * len,
        ),
        _genericLinePaint,
      );

    case ProjectileVisualStyle.dart:
      _genericCorePaint.color = color.withValues(alpha: 0.9);
      canvas.drawCircle(
        position,
        2 * projectile.visualScale,
        _genericCorePaint,
      );
      _genericGlowPaint
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = null;
      canvas.drawCircle(
        position,
        4 * projectile.visualScale,
        _genericGlowPaint,
      );

    case ProjectileVisualStyle.sigil:
    case ProjectileVisualStyle.hornImpact:
      final pulse = 0.7 + 0.3 * sin(time * 4);
      _genericGlowPaint
        ..color = color.withValues(alpha: 0.4 * pulse)
        ..maskFilter = null;
      canvas.drawCircle(
        position,
        4 * projectile.visualScale,
        _genericGlowPaint,
      );
      _genericCorePaint.color = const ui.Color(
        0xFFFFFFFF,
      ).withValues(alpha: 0.6 * pulse);
      canvas.drawCircle(
        position,
        2 * projectile.visualScale,
        _genericCorePaint,
      );

    case ProjectileVisualStyle.kinOrbital:
      // Guardian-orb render: bright protective core + halo + two
      // satellite motes orbiting around it. Reads as a guardian
      // companion, not a generic colored circle.
      final radius = (1.6 * projectile.visualScale).clamp(1.4, 5.8).toDouble();
      final pulse = 0.78 + 0.22 * sin(time * 3.4 + projectile.life);
      if (!reduceAmbient) {
        _genericGlowPaint
          ..color = color.withValues(alpha: 0.20 * pulse)
          ..maskFilter = null;
        canvas.drawCircle(position, radius * 2.6, _genericGlowPaint);
        // Two satellite motes orbiting opposite sides
        for (var i = 0; i < 2; i++) {
          final sa = time * 2.4 + i * pi;
          final sp = position + ui.Offset(cos(sa), sin(sa)) * radius * 1.9;
          _genericCorePaint.color = color.withValues(alpha: 0.75 * pulse);
          canvas.drawCircle(sp, radius * 0.42, _genericCorePaint);
        }
      }
      _genericCorePaint.color = color.withValues(alpha: 0.92 * pulse);
      canvas.drawCircle(position, radius, _genericCorePaint);
      _genericCorePaint.color = const ui.Color(
        0xFFFFFFFF,
      ).withValues(alpha: 0.85 * pulse);
      canvas.drawCircle(position, radius * 0.42, _genericCorePaint);

    case ProjectileVisualStyle.mysticOrbital:
      // One clamp for both, so the figure always leads.
      //
      // The glow used to take the raw visualScale while the sigil was capped,
      // and Mystic casts run up to 5.4 — so the halo drew at nearly twice the
      // figure's size and fifteen of them merged into an orange wall. That
      // wall was most of why the family looked like undifferentiated area
      // damage.
      final mysticScale = projectile.visualScale.clamp(0.7, 3.2).toDouble();
      _genericGlowPaint
        ..color = color.withValues(alpha: 0.12)
        ..maskFilter = null;
      canvas.drawCircle(position, 6 * mysticScale, _genericGlowPaint);
      drawMysticSigil(
        canvas: canvas,
        position: position,
        color: color,
        scale: mysticScale,
        time: time,
        sides: mysticSigilSides(projectile.element),
        seed: projectile.life,
      );

    case ProjectileVisualStyle.letShard:
      final dir = ui.Offset(cos(projectile.angle), sin(projectile.angle));
      final perp = ui.Offset(-dir.dy, dir.dx);
      final tailLen = 30.0 * projectile.visualScale;
      final tail = position - dir * tailLen;

      canvas.drawLine(
        tail,
        position,
        ui.Paint()
          ..shader = ui.Gradient.linear(
            tail,
            position,
            [
              color.withValues(alpha: 0.0),
              color.withValues(alpha: 0.16),
              ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.18)!,
            ],
            const [0.0, 0.58, 1.0],
          )
          ..strokeWidth = 5.4 * projectile.visualScale
          ..strokeCap = ui.StrokeCap.round
          ..maskFilter = null,
      );

      final shard = ui.Path()
        ..moveTo(
          position.dx + dir.dx * (8.5 * projectile.visualScale),
          position.dy + dir.dy * (8.5 * projectile.visualScale),
        )
        ..lineTo(
          position.dx + perp.dx * (4.2 * projectile.visualScale),
          position.dy + perp.dy * (4.2 * projectile.visualScale),
        )
        ..lineTo(
          position.dx - dir.dx * (6.0 * projectile.visualScale),
          position.dy - dir.dy * (6.0 * projectile.visualScale),
        )
        ..lineTo(
          position.dx - perp.dx * (4.2 * projectile.visualScale),
          position.dy - perp.dy * (4.2 * projectile.visualScale),
        )
        ..close();

      canvas.drawPath(
        shard,
        ui.Paint()
          ..shader = ui.Gradient.linear(
            tail,
            position + dir * (10.0 * projectile.visualScale),
            [
              ui.Color.lerp(color, const ui.Color(0xFF1A1014), 0.42)!,
              color,
              ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!,
            ],
            const [0.0, 0.62, 1.0],
          ),
      );

      canvas.drawPath(
        shard,
        ui.Paint()
          ..color = ui.Color.lerp(
            color,
            const ui.Color(0xFFFFFFFF),
            0.42,
          )!.withValues(alpha: 0.8)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.1 * projectile.visualScale,
      );

      canvas.drawCircle(
        position - dir * (1.2 * projectile.visualScale),
        2.4 * projectile.visualScale,
        ui.Paint()..color = const ui.Color(0xFFFFF4DC).withValues(alpha: 0.85),
      );

    case ProjectileVisualStyle.standard:
      _genericCorePaint.color = color.withValues(alpha: 0.8);
      canvas.drawCircle(
        position,
        3 * projectile.visualScale,
        _genericCorePaint,
      );
      _genericGlowPaint
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = null;
      canvas.drawCircle(
        position,
        5 * projectile.visualScale,
        _genericGlowPaint,
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Directional silhouette primitives
//
// Both the Let meteors and the Mane cleaves used to be built out of stacked
// translucent concentric circles — a cheap fake radial blur. It is cheap, but a
// stack of discs has no axis and no edge, so every element collapsed into the
// same round blob wearing a different hue, and the body's tumble could not read
// because a near-circle looks identical at every rotation.
//
// These replace the disc stack with forms that have a direction and a real
// outline: a bloom stretched along travel, and a genuinely irregular body that
// visibly spins. Same cost class as what they replace — plain fills and strokes,
// no MaskFilter, no saveLayer, no per-frame Paint allocation.
// ─────────────────────────────────────────────────────────────────────────────

final ui.Paint _shapePaint = ui.Paint();
final ui.Paint _shapeStrokePaint = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

/// Irregular unit radii for a rock silhouette.
///
/// Two failure modes bracket this table. Too little variance (the old meteor
/// used 0.82..1.08) is a circle, and a circle cannot show its own rotation.
/// Variance that alternates high/low between neighbours makes a star — spiky,
/// symmetrical and far cheesier than the circle was. So: a wide range, but
/// neighbouring radii stay close, which gives lumps and one flattened face
/// instead of points.
const List<double> _kShardRadii = [
  1.00,
  1.10,
  1.06,
  0.86,
  0.72,
  0.76,
  0.92,
  1.08,
  1.02,
];

/// An irregular body that tumbles, stretched along [travelDir] so it reads as
/// travelling rather than hovering.
ui.Path buildTumblingShardPath({
  required ui.Offset centre,
  required double radius,
  required ui.Offset travelDir,
  required double spin,
  double elongation = 1.24,
  double flatten = 0.88,
}) {
  final perp = ui.Offset(-travelDir.dy, travelDir.dx);
  final path = ui.Path();
  final n = _kShardRadii.length;
  for (var i = 0; i < n; i++) {
    final a = spin + i * (pi * 2 / n);
    final r = radius * _kShardRadii[i];
    final along = cos(a) * r * elongation;
    final across = sin(a) * r * flatten;
    final p = centre + travelDir * along + perp * across;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

/// The lit leading edge, traced along the body's own outline instead of stroked
/// round a perfect circle — a circular rim arc was what re-rounded the meteor
/// silhouette after all the work of making it irregular.
void drawShardLeadingRim({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required ui.Offset travelDir,
  required double spin,
  required ui.Color color,
  required double width,
  double elongation = 1.24,
  double flatten = 0.88,
}) {
  final perp = ui.Offset(-travelDir.dy, travelDir.dx);
  final n = _kShardRadii.length;
  final rim = ui.Path();
  var started = false;
  for (var i = 0; i <= n; i++) {
    final idx = i % n;
    final a = spin + idx * (pi * 2 / n);
    final along = cos(a);
    if (along <= 0.05) {
      started = false;
      continue;
    }
    final r = radius * _kShardRadii[idx];
    final p =
        centre +
        travelDir * (along * r * elongation) +
        perp * (sin(a) * r * flatten);
    if (!started) {
      rim.moveTo(p.dx, p.dy);
      started = true;
    } else {
      rim.lineTo(p.dx, p.dy);
    }
  }
  _shapeStrokePaint
    ..color = color
    ..strokeWidth = width;
  canvas.drawPath(rim, _shapeStrokePaint);
}

/// A heat bloom with an axis: nested ovals stretched along [travelDir], so the
/// glow says which way the thing is going instead of pooling round it.
void drawDirectionalBloom({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required ui.Offset travelDir,
  required double length,
  required double width,
  required ui.Color color,
  double alpha = 0.22,
  int layers = 3,
  double trailBias = 0.35,
}) {
  final angle = atan2(travelDir.dy, travelDir.dx);
  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  canvas.rotate(angle);
  for (var i = layers; i >= 1; i--) {
    final f = i / layers;
    _shapePaint.color = color.withValues(alpha: alpha * (1.0 - f * 0.55));
    canvas.drawOval(
      ui.Rect.fromLTRB(
        -length * f * (1 + trailBias),
        -width * f,
        length * f * (1 - trailBias * 0.5),
        width * f,
      ),
      _shapePaint,
    );
  }
  canvas.restore();
}

/// A wake that flows.
///
/// The wedge this replaces was three nested triangles: straight sides, a blunt
/// cut across the head and a hard point at the tail. Whatever colour went into
/// it, the eye read cut paper — and because every Let wore the same wedge at
/// the same angle, the family had one silhouette seventeen times over, and
/// that silhouette was a slipstream, which is Mane's.
///
/// This is a ribbon instead. Its centreline meanders, its width bulges and
/// pinches on the way down, and each layer carries its own phase so the
/// stacked edges never agree on where the boundary is. Nothing in it is
/// straight, which is the whole point: a falling mass drags a turbulent plume,
/// and turbulence is what tells the eye this is smoke and not a shape.
///
/// Cost is the same class as the wedge — three filled paths and three linear
/// gradients, no MaskFilter, no saveLayer, no Paint allocation. The samples
/// are recomputed rather than buffered so nothing allocates per frame either.
void drawPlumeWake({
  required ui.Canvas canvas,
  required ui.Offset head,
  required ui.Offset travelDir,
  required double length,
  required double headWidth,
  required ui.Color color,
  required double time,
  double alpha = 0.34,
  ui.Color? hotColor,
  int layers = 3,
  double seed = 0.0,
  double waveAmplitude = 1.0,
  double waveFrequency = 1.0,
}) {
  if (length <= 0.5 || headWidth <= 0.2) return;
  final perp = ui.Offset(-travelDir.dy, travelDir.dx);
  final hot =
      hotColor ?? ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.6)!;
  // Sampled coarsely and then smoothed: the points are joined through their
  // own midpoints with quadratic segments, so the outline is a continuous
  // curve rather than a polyline. Straight segments between samples were
  // visible as folds and corners on plumes this long, which put the hard
  // edges straight back after all the work of bending the centreline.
  const samples = 12;

  for (var l = 0; l < layers; l++) {
    final layerAlpha = 1.0 - l * 0.34;
    final w0 = headWidth * (1.0 - l * 0.30);
    final len = length * (1.0 - l * 0.14);
    // Each layer drifts on its own phase and swings a little wider than the
    // one inside it, so the composite edge is broken instead of a single
    // agreed-upon line. The time term makes the plume crawl.
    final phase = seed * 1.7 + l * 2.3 - time * (1.6 + l * 0.35);
    // Sway is a fraction of the plume's LENGTH, not its width. Scaling it off
    // headWidth was the bug in the first pass: these wakes run five times
    // longer than they are wide, so a width-derived wander was a couple of
    // pixels over several hundred and the ribbon stayed visually straight.
    // The per-layer spread is small on purpose. Widening it pushes the outer
    // layers clear of the inner one and the wake stops being one plume with a
    // broken edge and becomes two or three separate ribbons crossing.
    final amp = len * 0.085 * waveAmplitude * (1.0 + l * 0.14);
    final tail = head - travelDir * len;

    // Half-width and lateral offset at position [u] along the plume, where 0
    // is the head and 1 the far tail.
    double swayAt(double u) =>
        sin(u * pi * 1.6 * waveFrequency + phase) * amp * u;
    double halfWidthAt(double u) {
      // Narrow where it meets the rock, widest a little way behind it, then
      // falling away to nothing. Peaking at the head made an arrowhead — the
      // plume has to look like it is pouring out from under the body, not
      // like the body is the point of a dart.
      final swell = sin(pi * (u * 0.62 + 0.10).clamp(0.0, 1.0));
      final taper = swell * (1.0 - u * 0.55);
      // Two harmonics that do not divide into each other, so the plume bulges
      // and pinches at irregular intervals instead of scalloping evenly.
      final lump =
          1.0 +
          0.34 * sin(u * pi * 2.4 * waveFrequency + phase * 1.3) +
          0.18 * sin(u * pi * 5.3 * waveFrequency - phase * 0.7);
      return w0 * 0.62 * taper * lump;
    }

    ui.Offset edge(double u, double side) {
      final centre = head - travelDir * (len * u) + perp * swayAt(u);
      return centre + perp * (halfWidthAt(u) * side);
    }

    // Walks one side of the plume as a smooth curve: each sampled point
    // becomes the control handle for a quadratic that lands on the midpoint
    // to the next one, which is the cheap standard way to round a polyline
    // without fitting real splines.
    void traceSide(ui.Path path, double side, bool forward) {
      ui.Offset at(int i) => edge(i / samples, side);
      if (forward) {
        for (var i = 1; i < samples; i++) {
          final c = at(i);
          final n = at(i + 1);
          path.quadraticBezierTo(
            c.dx,
            c.dy,
            (c.dx + n.dx) * 0.5,
            (c.dy + n.dy) * 0.5,
          );
        }
        final last = at(samples);
        path.lineTo(last.dx, last.dy);
      } else {
        for (var i = samples - 1; i > 0; i--) {
          final c = at(i);
          final n = at(i - 1);
          path.quadraticBezierTo(
            c.dx,
            c.dy,
            (c.dx + n.dx) * 0.5,
            (c.dy + n.dy) * 0.5,
          );
        }
        final last = at(0);
        path.lineTo(last.dx, last.dy);
      }
    }

    final path = ui.Path();
    final first = edge(0, 1);
    path.moveTo(first.dx, first.dy);
    traceSide(path, 1, true);
    traceSide(path, -1, false);
    // The reverse trace ended on the far edge of the head; curve from there
    // back to where it started, bulging slightly forward, so the plume closes
    // under the body instead of butting into it with a straight cut.
    final domeCtl = head + travelDir * w0 * 0.12;
    path.quadraticBezierTo(domeCtl.dx, domeCtl.dy, first.dx, first.dy);
    path.close();

    // Alpha ramps to nothing at the tail so the wake ends by dissolving, and
    // the colour cools from white-hot at the head to element at the far end.
    _shapePaint
      ..color = const ui.Color(0xFFFFFFFF)
      ..shader = ui.Gradient.linear(
        tail,
        head,
        [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: alpha * layerAlpha * 0.5),
          hot.withValues(alpha: alpha * layerAlpha),
        ],
        const [0.0, 0.6, 1.0],
      );
    canvas.drawPath(path, _shapePaint);
    _shapePaint.shader = null;
  }
}

/// Four-point star glints — the "sparkle" read.
///
/// Heavy translucent fills make a cast look painted; small bright points with
/// hard centres make it look lit. Positions are hashed off [seed] so they are
/// deterministic (no per-frame Random, no shimmer between frames), scattered
/// around the head and biased backwards into the wake, each twinkling on its
/// own phase so some vanish entirely at any given moment.
void drawSparkleGlints({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required ui.Offset travelDir,
  required double spread,
  required double size,
  required ui.Color color,
  required double time,
  int count = 4,
  double seed = 0.0,
  double alpha = 0.9,
}) {
  final perp = ui.Offset(-travelDir.dy, travelDir.dx);
  for (var i = 0; i < count; i++) {
    final h1 = sin((i + 1) * 12.9898 + seed * 78.233) * 43758.5453;
    final h2 = sin((i + 1) * 39.3468 + seed * 11.135) * 24634.6345;
    final u = h1 - h1.floorToDouble();
    final v = h2 - h2.floorToDouble();
    // Twinkle: below zero the glint is simply skipped this frame.
    final tw = sin(time * (3.2 + u * 2.6) + i * 2.1 + seed);
    if (tw <= 0.05) continue;
    final along = -spread * (0.08 + u * 0.95);
    // Lateral scatter is a fraction of how far back the glint is, so the
    // sparkle fans out along the wake instead of drifting off into open space
    // where it reads as an unrelated speck.
    final across = (v - 0.5) * spread * 0.20 * (0.25 + u);
    final c = centre + travelDir * along + perp * across;
    final r = size * (0.5 + v * 0.7) * tw;
    if (r < 0.25) continue;
    final path = ui.Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.17, c.dy - r * 0.17, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.17, c.dy + r * 0.17, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.17, c.dy + r * 0.17, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.17, c.dy - r * 0.17, c.dx, c.dy - r)
      ..close();
    _shapePaint.color = color.withValues(alpha: alpha * tw);
    canvas.drawPath(path, _shapePaint);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LET SKYFALL — the telegraph and the landing
//
// A Let meteor arrives from off-screen, so for most of its descent there is
// nothing on screen to look at. The telegraph is what makes the cast readable:
// it marks the committed impact point from the instant of the cast, tightens
// as the rock closes, and is the only thing in any family that does this.
//
// Both painters are plain fills and strokes with at most one gradient each —
// no MaskFilter, no saveLayer, no per-frame Paint allocation. Cost sits in the
// same class as the meteor's own wake, and only one meteor is usually falling.
// ─────────────────────────────────────────────────────────────────────────────

/// A blade: sharp at the nose, bellied forward, drawn out to a point at the
/// tail. Curved sides, no straight edges anywhere.
///
/// The Mane core used to be [buildTumblingShardPath] squashed to a third of its
/// width and spun on `time` — a long lumpy stick, rolling. That is the right
/// treatment for a meteor, which genuinely tumbles, and exactly wrong for a
/// shot whose whole identity is piercing: a blade that rolls in flight reads as
/// a thrown chopstick, and a fan of them reads as a handful of them.
///
/// The belly sits forward of centre so the widest part of the shape is the part
/// doing the cutting, and the tail runs long behind it. That asymmetry is what
/// makes the silhouette point somewhere.
ui.Path buildBladePath({
  required ui.Offset centre,
  required ui.Offset travelDir,
  required double length,
  required double width,
  double bellyBias = 0.30,
  double bank = 0.0,
}) {
  final len = travelDir.distance;
  final dir = len > 0.01 ? travelDir / len : const ui.Offset(1, 0);
  final perp = ui.Offset(-dir.dy, dir.dx);
  final half = length * 0.5;
  final nose = centre + dir * half;
  final tail = centre - dir * half;
  // Bank leans the blade off its travel axis a little, so a fan of them does
  // not look like a set of identical parts stamped from one mould.
  final lean = perp * (width * bank);
  // Control points ride at the belly, forward of centre. A cubic rather than a
  // quadratic so the nose can stay sharp while the tail still runs out long.
  final c1Along = half * (1.0 - bellyBias * 0.6);
  final c2Along = -half * bellyBias;

  ui.Offset ctl(double along, double side) =>
      centre + dir * along + perp * (width * side) + lean;

  return ui.Path()
    ..moveTo(nose.dx, nose.dy)
    ..cubicTo(
      ctl(c1Along, 1).dx,
      ctl(c1Along, 1).dy,
      ctl(c2Along, 1).dx,
      ctl(c2Along, 1).dy,
      tail.dx,
      tail.dy,
    )
    ..cubicTo(
      ctl(c2Along, -1).dx,
      ctl(c2Along, -1).dy,
      ctl(c1Along, -1).dx,
      ctl(c1Along, -1).dy,
      nose.dx,
      nose.dy,
    )
    ..close();
}

/// The clump of energy wisps that rides behind a moving Mane blade.
///
/// This used to be real particles pushed into the shared ambient pool — two or
/// three per projectile per frame. A Mane cast fans several projectiles at
/// once, each living a second or more, so the emission rate outran the pool's
/// drain rate and any cast at all pinned it at its ceiling for the whole
/// flight. Everything else that wanted a particle and gated below that ceiling
/// — hit sparks, kill bursts, zone wisps, meteor craters — silently got
/// nothing for as long as a Mane was in the air.
///
/// Drawing the wisps instead fixes that at the root: the pool is untouched, so
/// there is no budget to blow and nothing to starve. It also costs less than
/// what it replaces (a handful of circles per blade, no allocation, no update
/// step, no list churn), it is deterministic rather than random per frame, and
/// because it lives in the projectile painter all three games get it — cosmic
/// and the dungeon never had this trail at all.
///
/// Positions are hashed off [seed] and swept along a phase so the wisps appear
/// to shed backwards and fade, the same read the particles gave.
void drawManeTrailWisps({
  required ui.Canvas canvas,
  required ui.Offset position,
  required ui.Offset travelDir,
  required ui.Color color,
  required double time,
  required double scale,
  double radiusMultiplier = 1.0,
  double seed = 0.0,
  int count = 7,
}) {
  final len = travelDir.distance;
  final dir = len > 0.01 ? travelDir / len : const ui.Offset(1, 0);
  final perp = ui.Offset(-dir.dy, dir.dx);
  final whiteMix = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!;
  // Same clump width the particle version used, so the trail reads at the
  // size it always did.
  final clumpR = (4.0 + scale * 4.0 + radiusMultiplier * 6.0).clamp(4.0, 28.0);

  for (var i = 0; i < count; i++) {
    // Deterministic scatter — no per-frame Random, so the clump does not
    // shimmer between frames the way randomly respawned particles did.
    final h1 = sin((i + 1) * 12.9898 + seed * 78.233) * 43758.5453;
    final h2 = sin((i + 1) * 39.3468 + seed * 11.135) * 24634.6345;
    final u = h1 - h1.floorToDouble();
    final v = h2 - h2.floorToDouble();
    // Each wisp runs its own shed cycle: born at the blade, drifting back and
    // fading out, then recycling. Staggered so they do not pulse in unison.
    final t = (time * (1.5 + u * 0.9) + u * 3.1 + seed) % 1.0;
    final fade = 1.0 - t;
    if (fade <= 0.05) continue;
    final lateral = (v - 0.5) * 2.0;
    final centre =
        position -
        dir * (clumpR * 1.2 * t * 2.2) +
        perp * lateral * clumpR * (0.35 + t * 0.9);
    final r = (1.3 + v * 1.4) * fade;
    if (r < 0.2) continue;
    _shapePaint.color = (i.isEven ? color : whiteMix).withValues(
      alpha: fade * 0.62,
    );
    canvas.drawCircle(centre, r, _shapePaint);
  }
}

/// How many ambient particles ONE Mane cast's trail may hold at a time.
///
/// The pool the trail draws from tops out around 150 and is shared with every
/// other effect in the game. A Mane cast fans up to sixteen projectiles, and
/// the trail used to emit two or three particles per projectile per frame —
/// so a single wide cast claimed the entire pool within a few frames and held
/// it for the projectiles' whole flight, leaving nothing for hit sparks, kill
/// bursts, zone wisps or meteor craters.
///
/// This is the cap for the cast as a whole, deliberately not per projectile:
/// what the trail costs must not depend on how wide the fan is.
const int kManeTrailParticleBudget = 48;

/// A Mystic orbital: a small turning sigil, not a bead.
///
/// This replaced two circles — a filled core and a soft glow, which was the
/// entire painter for the family. Mystic is the single-slot pick, the longest
/// cooldown in the game and the densest cast at four to twenty projectiles, so
/// what the player saw for their one ultimate was a pile of identical soft
/// circles. That is what makes the family read as generic area damage: not the
/// mechanics (Pip chains single targets, Kin buffs and wards) but the fact
/// that its showpiece had no shape.
///
/// Sigil geometry is a language nothing else in the roster uses — Let falls and
/// craters, Mane cleaves, Pip darts, Kin grows ground cover — and it suits the
/// game's alchemical dressing. Angular and constructed, so it reads as
/// something deliberately invoked rather than something spilled.
///
/// [sides] varies the inner polygon per element, so a Fire cast and an Ice cast
/// are different figures rather than the same circle in two colours.
///
/// Cost: two stroked paths, two short arcs and two small fills. A twenty-orb
/// cast draws well under what the four concentric circles per Pip dart used to.
void drawMysticSigil({
  required ui.Canvas canvas,
  required ui.Offset position,
  required ui.Color color,
  required double scale,
  required double time,
  required int sides,
  double seed = 0.0,
}) {
  final r = 5.2 * scale;
  final hot = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.55)!;
  // The two rings turn against each other, which reads as mechanism rather
  // than as a sprite being spun.
  final outerSpin = time * 0.9 + seed;
  final innerSpin = -time * 1.4 - seed * 0.7;

  _shapeStrokePaint
    ..color = color.withValues(alpha: 0.55)
    ..strokeWidth = 0.9 * scale;
  canvas.drawCircle(position, r, _shapeStrokePaint);

  // Three ticks riding the outer ring — the "struck rune" read.
  for (var i = 0; i < 3; i++) {
    final a = outerSpin + i * (pi * 2 / 3);
    final d = ui.Offset(cos(a), sin(a));
    canvas.drawLine(
      position + d * (r * 0.82),
      position + d * (r * 1.28),
      _shapeStrokePaint,
    );
  }

  // Inner polygon, counter-turning. Sides carry the element apart.
  final n = sides.clamp(3, 7);
  final poly = ui.Path();
  for (var i = 0; i < n; i++) {
    final a = innerSpin + i * (pi * 2 / n);
    final p = position + ui.Offset(cos(a), sin(a)) * (r * 0.62);
    if (i == 0) {
      poly.moveTo(p.dx, p.dy);
    } else {
      poly.lineTo(p.dx, p.dy);
    }
  }
  poly.close();
  _shapeStrokePaint
    ..color = hot.withValues(alpha: 0.70)
    ..strokeWidth = 0.85 * scale;
  canvas.drawPath(poly, _shapeStrokePaint);

  // Core: the lit centre the figure is drawn around.
  _shapePaint.color = color.withValues(alpha: 0.32);
  canvas.drawCircle(position, r * 0.90, _shapePaint);
  _shapePaint.color = hot.withValues(alpha: 0.95);
  canvas.drawCircle(position, r * 0.26, _shapePaint);
}

/// How many sides a Mystic sigil's inner figure has, per element — so the
/// seventeen ultimates are seventeen different figures and not one shape
/// recoloured. Grouped by temperament rather than at random: the volatile
/// elements get the tightest, sharpest figures.
int mysticSigilSides(String? element) => switch (element) {
  'Fire' || 'Lightning' || 'Spirit' => 3,
  'Lava' || 'Poison' || 'Dark' => 4,
  'Crystal' || 'Ice' || 'Light' => 6,
  'Earth' || 'Mud' || 'Steam' => 5,
  _ => 7,
};

/// One Let meteor landing, alive just long enough to show the crater open.
///
/// Lives here rather than in any one game so all three hold the identical
/// struct and hand it to the identical painter — the same arrangement the
/// ability particle pool uses, and the reason the three modes stopped drifting
/// apart on ability art in the first place.
class LetSkyfallImpact {
  LetSkyfallImpact({
    required this.position,
    required this.color,
    required this.radius,
    this.duration = 0.42,
  }) : age = 0;

  final ui.Offset position;
  final ui.Color color;
  final double radius;
  final double duration;
  double age;

  /// 0 at touchdown, 1 when the flash is spent.
  double get t => (age / duration).clamp(0.0, 1.0);
  bool get dead => age >= duration;
}

/// Advances a game's list of craters and drops the spent ones. Each game owns
/// the list; the stepping and the painting are shared.
void updateLetSkyfallImpacts(List<LetSkyfallImpact> impacts, double dt) {
  if (impacts.isEmpty) return;
  for (final impact in impacts) {
    impact.age += dt;
  }
  impacts.removeWhere((impact) => impact.dead);
}

/// Adds one crater, evicting the oldest if the (deliberately small) cap is hit.
void pushLetSkyfallImpact(
  List<LetSkyfallImpact> impacts,
  LetSkyfallImpact impact, {
  int cap = 6,
}) {
  if (impacts.length >= cap) impacts.removeAt(0);
  impacts.add(impact);
}

/// The ground mark under an incoming meteor.
///
/// [progress] runs 0 at the cast to 1 at the landing. The outer ring contracts
/// onto the impact point over that span, which is the "incoming" read — a
/// static ring says "something is here", a closing one says "something is
/// arriving, and this is when".
///
/// Deliberately quiet. This is a mark the player reads at a glance in the
/// middle of a fight, not a light show: a wide bright telegraph competes with
/// the meteor it is announcing and washes out the arena underneath it.
void drawLetSkyfallTelegraph({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required ui.Color color,
  required double radius,
  required double progress,
  required double time,
  bool reduceAmbient = false,
}) {
  final t = progress.clamp(0.0, 1.0);
  // Fades up quickly at the start so the cast registers immediately, then
  // holds. A telegraph that eases in over the whole descent is invisible for
  // exactly the window in which it is useful.
  final presence = (t * 4.2).clamp(0.0, 1.0);
  final hot = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.45)!;

  // A stain on the ground, no wider than the crater it predicts. One radial
  // gradient rather than a stack of flat discs, so the edge dissolves instead
  // of banding.
  final stainR = radius * (1.20 - 0.22 * t);
  _shapePaint
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.radial(centre, stainR, [
      color.withValues(alpha: (0.16 + 0.14 * t) * presence),
      color.withValues(alpha: (0.07 + 0.08 * t) * presence),
      color.withValues(alpha: 0.0),
    ], const [0.0, 0.62, 1.0]);
  canvas.drawCircle(centre, stainR, _shapePaint);
  _shapePaint.shader = null;

  // The closing ring. Starts just wide of the crater and settles onto its rim
  // — close enough that it always reads as belonging to this mark, rather
  // than as a loose arc drawn somewhere near it.
  final ringR = radius * (1.24 - 0.26 * t);
  _shapeStrokePaint
    ..color = hot.withValues(alpha: (0.18 + 0.38 * t) * presence)
    ..strokeWidth = 1.0 + 1.2 * t;
  canvas.drawCircle(centre, ringR, _shapeStrokePaint);

  // Three short marks riding the ring, turning slowly. Enough to read as a
  // struck sigil rather than a targeting reticle, and the rotation keeps the
  // mark alive while the ring is still far out and barely moving.
  if (!reduceAmbient) {
    final spin = time * 0.9 + t * 1.6;
    _shapeStrokePaint
      ..color = hot.withValues(alpha: (0.26 + 0.38 * t) * presence)
      ..strokeWidth = 1.3 + 0.9 * t;
    for (var i = 0; i < 3; i++) {
      final a = spin + i * (pi * 2 / 3);
      final d = ui.Offset(cos(a), sin(a));
      canvas.drawLine(
        centre + d * (ringR - radius * 0.10),
        centre + d * (ringR + radius * 0.10),
        _shapeStrokePaint,
      );
    }
  }

  // The rock's own shadow, swelling as it drops. This is the part that sells
  // height: the ring says where, the shadow says how close.
  final shadowR = radius * (0.08 + 0.28 * t * t);
  _shapePaint.color = const ui.Color(
    0xFF000000,
  ).withValues(alpha: 0.34 * presence * t);
  canvas.drawCircle(centre, shadowR, _shapePaint);
  _shapePaint.color = hot.withValues(alpha: 0.30 * presence * t * t);
  canvas.drawCircle(centre, shadowR * 0.5, _shapePaint);
}

/// The landing. [age] runs 0 at touchdown to 1 when the flash is spent.
///
/// Round, not squashed. The arena is seen from directly overhead, so a crater
/// is a circle — an oval reads as an eye staring up out of the floor, which is
/// what the first pass at this looked like.
///
/// Kept thin and brief on purpose. The debris particles the same landing
/// throws carry most of the punch; what is drawn here is the flash and the
/// shock leaving it, and anything heavier turns every impact into a sticker.
void drawLetSkyfallImpact({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required ui.Color color,
  required double radius,
  required double age,
  bool reduceAmbient = false,
}) {
  final t = age.clamp(0.0, 1.0);
  final fade = 1.0 - t;
  if (fade <= 0.01) return;
  final hot = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.72)!;

  // White core, gone almost at once. The punch.
  final flash = fade * fade * fade;
  final coreR = radius * (0.55 - 0.34 * t);
  if (coreR > 0.5 && flash > 0.01) {
    _shapePaint
      ..color = const ui.Color(0xFFFFFFFF)
      ..shader = ui.Gradient.radial(centre, coreR, [
        const ui.Color(0xFFFFFFFF).withValues(alpha: 0.95 * flash),
        hot.withValues(alpha: 0.50 * flash),
        color.withValues(alpha: 0.0),
      ], const [0.0, 0.40, 1.0]);
    canvas.drawCircle(centre, coreR, _shapePaint);
    _shapePaint.shader = null;
  }

  // The shock leaving the crater: one thin ring, out fast and gone. Kept
  // mostly element-coloured — mixing it hot turned every neutral element's
  // ring into the same grey hoop, which read as a UI pulse rather than fire,
  // water or stone leaving a crater.
  final rim = ui.Color.lerp(color, const ui.Color(0xFFFFFFFF), 0.25)!;
  final shockR = radius * (0.38 + 0.78 * _easeOutFast(t));
  _shapeStrokePaint
    ..color = rim.withValues(alpha: 0.55 * fade * fade)
    ..strokeWidth = (radius * 0.05 + 0.8) * fade;
  canvas.drawCircle(centre, shockR, _shapeStrokePaint);

  if (!reduceAmbient) {
    // A fainter second front trailing the first, so the shock has depth
    // rather than being one travelling hoop.
    final innerR = radius * (0.24 + 0.54 * _easeOutFast(t));
    _shapeStrokePaint
      ..color = color.withValues(alpha: 0.32 * fade * fade)
      ..strokeWidth = (radius * 0.035 + 0.6) * fade;
    canvas.drawCircle(centre, innerR, _shapeStrokePaint);
  }

  // Scorch on the ground under it all. Faint — the element's own zone art is
  // what marks the crater from here on, and doubling up muddies both.
  _shapePaint
    ..color = const ui.Color(0xFFFFFFFF)
    ..shader = ui.Gradient.radial(centre, radius * 0.86, [
      color.withValues(alpha: 0.22 * fade),
      color.withValues(alpha: 0.07 * fade),
      color.withValues(alpha: 0.0),
    ], const [0.0, 0.55, 1.0]);
  canvas.drawCircle(centre, radius * 0.86, _shapePaint);
  _shapePaint.shader = null;
}

/// Fast out of the gate, long tail. Impacts read wrong on a linear ramp — the
/// energy has to be spent almost immediately and then coast.
double _easeOutFast(double t) => 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t);

/// Builds a closed, smoothly curved ribbon that follows [spine] and tapers
/// from [baseWidth] at the first point to [tipWidth] at the last.
///
/// Strokes cannot taper, and a plant has no constant thickness anywhere on it,
/// so anything organic has to be a filled shape swept along a curve. Corners
/// are rounded by running quadratics through the midpoints of the offset
/// samples rather than joining them with straight segments — a polyline reads
/// as folded paper no matter how many points it has.
ui.Path _tapered(List<ui.Offset> spine, double baseWidth, double tipWidth) {
  final path = ui.Path();
  if (spine.length < 2) return path;

  final left = <ui.Offset>[];
  final right = <ui.Offset>[];
  for (var i = 0; i < spine.length; i++) {
    final prev = spine[i == 0 ? 0 : i - 1];
    final next = spine[i == spine.length - 1 ? i : i + 1];
    var tangent = next - prev;
    final len = tangent.distance;
    if (len < 0.0001) {
      tangent = const ui.Offset(0, -1);
    } else {
      tangent = tangent / len;
    }
    final normal = ui.Offset(-tangent.dy, tangent.dx);
    final f = i / (spine.length - 1);
    final half = (baseWidth + (tipWidth - baseWidth) * f) * 0.5;
    left.add(spine[i] + normal * half);
    right.add(spine[i] - normal * half);
  }

  void trace(List<ui.Offset> side) {
    for (var i = 1; i < side.length - 1; i++) {
      final mid = ui.Offset(
        (side[i].dx + side[i + 1].dx) * 0.5,
        (side[i].dy + side[i + 1].dy) * 0.5,
      );
      path.quadraticBezierTo(side[i].dx, side[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(side.last.dx, side.last.dy);
  }

  path.moveTo(left.first.dx, left.first.dy);
  trace(left);
  final reversed = right.reversed.toList();
  path.lineTo(reversed.first.dx, reversed.first.dy);
  trace(reversed);
  path.close();
  return path;
}


/// Dark Mystic's maw: the hole it tears in the arena.
///
/// A world feature, not a cast — it holds open for as long as its Mystic
/// stands, so it breathes slowly and keeps a constant boundary rather than
/// throwing expanding rings, which read as an effect going off over and over.
void drawMysticMaw({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double pullRadius,
  required double horizonRadius,
  required double open,
  required double spin,
  required double alpha,
  required double time,
}) {
  final a = alpha;
  final pull = pullRadius * open;
  final horizon = horizonRadius * open;
  final violet = const ui.Color(0xFFB89AFF);
  final deep = const ui.Color(0xFF12061F);
  // A slow breath, not a strobe. The hole is a permanent feature of the
  // map for as long as the Mystic stands, so it should read as something
  // alive and steady rather than something firing.
  final pulse = 1.0 + 0.045 * sin(time * 0.85);

  // ONE boundary line for the pull, held at a constant radius. This used
  // to be three rings at different radii, which read as expanding shock
  // rings — an effect going off, repeatedly, instead of a hole staying
  // open.
  canvas.drawCircle(
    centre,
    pull * 0.94,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = violet.withValues(alpha: 0.09 * a),
  );

  // Accretion: two arcs close to the mouth, shearing against each other.
  final arcPaint = ui.Paint()..style = ui.PaintingStyle.stroke;
  for (var ring = 0; ring < 2; ring++) {
    final rr = horizon * (1.9 + ring * 0.75) * pulse;
    final turn = spin * (1.0 + ring * 0.5) + ring * 2.1;
    arcPaint
      ..strokeWidth = 2.8 - ring * 0.8
      ..color = ui.Color.lerp(violet, const ui.Color(0xFFFFFFFF), ring * 0.25)!
          .withValues(alpha: (0.32 - ring * 0.10) * a);
    canvas.drawArc(
      ui.Rect.fromCircle(center: centre, radius: rr),
      turn,
      2.4 - ring * 0.5,
      false,
      arcPaint,
    );
  }

  // The hole itself: a hard black disc with a bright rim, so it reads as
  // an absence rather than as a dark sphere.
  canvas.drawCircle(
    centre,
    horizon * 1.35 * pulse,
    ui.Paint()..color = deep.withValues(alpha: 0.55 * a),
  );
  canvas.drawCircle(
    centre,
    horizon * pulse,
    ui.Paint()..color = const ui.Color(0xFF000000).withValues(alpha: 0.96 * a),
  );
  canvas.drawCircle(
    centre,
    horizon * pulse,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = violet.withValues(alpha: 0.85 * a),
  );
  // Light bending round the rim.
  canvas.drawArc(
    ui.Rect.fromCircle(center: centre, radius: horizon * 1.12 * pulse),
    -spin * 0.8,
    1.5,
    false,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.55 * a),
  );
}

/// The curved spine of a grove vine, root first and head last.
///
/// Shared with the game rather than kept inside the painter, because the
/// spitter has to fire its thorns FROM its flower — and the flower is wherever
/// the swaying stem has carried it this frame. Spawning at the root instead
/// meant the shots appeared out of the ground under the plant.
List<ui.Offset> mysticGroveVineSpine({
  required ui.Offset root,
  required double growth,
  required double seed,
  required double time,
}) {
  // Both vines grow UPWARD. Which side of the caster a vine is rooted on is
  // about where it stands, not which way it points: mirroring the growth
  // direction hung the southern one downward with its flower at the bottom,
  // which just reads as a plant printed upside down.
  final height = 207.0 * growth;
  const samples = 16;
  return [
    for (var i = 0; i <= samples; i++)
      () {
        final f = i / samples;
        final wave =
            sin(f * 3.1 + time * 0.9 + seed) * 22.5 * f +
            sin(f * 6.4 + time * 0.55 + seed * 1.7) * 9.0 * f;
        return ui.Offset(root.dx + wave, root.dy - height * f);
      }(),
  ];
}

/// Where a grove vine's head — its whip root, or its flower — is right now.
ui.Offset mysticGroveVineHead({
  required ui.Offset root,
  required double growth,
  required double seed,
  required double time,
}) => mysticGroveVineSpine(
  root: root,
  growth: growth,
  seed: seed,
  time: time,
).last;

/// One of a Plant Mystic's two grove vines.
///
/// Built from tapered ribbons swept along curved spines rather than stroked
/// polylines with circles for leaves: a plant has no straight edges and no
/// constant thickness anywhere on it, and a constant-width stroke reads as
/// folded paper however many points it has.
void drawMysticGroveVine({
  required ui.Canvas canvas,
  required ui.Offset root,
  required bool lashes,
  required double growth,
  required double swing,
  required double aimAngle,
  required double reach,
  required double seed,
  required double alpha,
  required double time,
  required ui.Color plant,
}) {
  final a = alpha;
  final grow = growth;
  final bright = ui.Color.lerp(plant, const ui.Color(0xFFFFFFFF), 0.45)!;

  final spine = mysticGroveVineSpine(
    root: root,
    growth: grow,
    seed: seed,
    time: time,
  );

  canvas.drawPath(
    _tapered(spine, 22.5 * grow, 3.6 * grow),
    ui.Paint()..color = plant.withValues(alpha: 0.32 * a),
  );
  canvas.drawPath(
    _tapered(spine, 14.2 * grow, 2.2 * grow),
    ui.Paint()..color = plant.withValues(alpha: 0.90 * a),
  );
  // A highlight running up one side so the stem reads as round.
  canvas.drawPath(
    _tapered(
      [for (final p in spine) p.translate(-3.0 * grow, 0)],
      5.1 * grow,
      1.2 * grow,
    ),
    ui.Paint()..color = bright.withValues(alpha: 0.30 * a),
  );

  // Leaves peel off the stem, alternating sides and curling back toward the
  // tip — narrow blades rather than broad ones, to match the stem.
  final samples = spine.length - 1;
  for (var i = 2; i < samples - 1; i += 3) {
    final f = i / samples;
    final at = spine[i];
    final side = i % 6 == 2 ? 1.0 : -1.0;
    final droop = sin(time * 1.1 + i + seed) * 0.18;
    final len = (51.0 - f * 21.0) * grow;
    final leaf = <ui.Offset>[];
    for (var k = 0; k <= 5; k++) {
      final lf = k / 5;
      leaf.add(
        at +
            ui.Offset(
              side * len * lf * (1.0 - 0.25 * lf),
              -len * 0.42 * lf * lf + droop * len * lf,
            ),
      );
    }
    canvas.drawPath(
      _tapered(leaf, (10.5 - f * 3.6) * grow, 0.9),
      ui.Paint()..color = plant.withValues(alpha: 0.58 * a),
    );
  }

  final head = spine.last;

  if (lashes) {
    // The arm. At rest it curls back on itself; through a swing it
    // straightens along the aim and drags a tip across the arc.
    final extend = 0.34 + 0.66 * swing;
    final armLength = reach * 0.92 * extend * grow;
    final dir = ui.Offset(cos(aimAngle), sin(aimAngle));
    final perp = ui.Offset(-dir.dy, dir.dx);
    // Curl amount falls away as the whip lands, so the snap reads.
    final curl = armLength * 0.50 * (1.0 - swing);
    final whip = <ui.Offset>[];
    const ws = 14;
    for (var i = 0; i <= ws; i++) {
      final f = i / ws;
      whip.add(
        head +
            dir * (armLength * f) +
            perp * (curl * sin(f * pi) + sin(f * 4.0 + time * 3.0) * 6.0 * f),
      );
    }
    canvas.drawPath(
      _tapered(whip, 13.5 * grow, 1.5),
      ui.Paint()..color = plant.withValues(alpha: (0.48 + 0.42 * swing) * a),
    );
    canvas.drawPath(
      _tapered(whip, 5.4 * grow, 0.75),
      ui.Paint()..color = bright.withValues(alpha: (0.28 + 0.55 * swing) * a),
    );
    // The arc it just swept, trailing the tip.
    if (swing > 0.05) {
      canvas.drawArc(
        ui.Rect.fromCircle(center: head, radius: armLength),
        aimAngle - 1.15,
        2.30,
        false,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = bright.withValues(alpha: 0.20 * swing * a),
      );
    }
  } else {
    // The spitter's flower: curved petals that peel open as it fires and fold
    // back after, around a throat that brightens with the shot.
    final fire = swing;
    const petals = 6;
    for (var i = 0; i < petals; i++) {
      final pa =
          aimAngle +
          (i - (petals - 1) / 2) * 0.40 +
          sin(time * 1.3 + i + seed) * 0.06;
      final len = (39.0 + 13.5 * fire) * grow;
      final bend = 0.55 - 0.40 * fire;
      final petal = <ui.Offset>[];
      for (var k = 0; k <= 5; k++) {
        final f = k / 5;
        final ang = pa + bend * f;
        petal.add(head + ui.Offset(cos(ang), sin(ang)) * (len * f));
      }
      canvas.drawPath(
        _tapered(petal, (12.0 + 3.0 * fire) * grow, 0.9),
        ui.Paint()..color = plant.withValues(alpha: 0.62 * a),
      );
    }
    final throat = (16.5 + 6.0 * fire) * grow;
    canvas.drawCircle(
      head,
      throat,
      ui.Paint()..color = plant.withValues(alpha: 0.92 * a),
    );
    canvas.drawCircle(
      head,
      throat * (0.34 + 0.30 * fire),
      ui.Paint()
        ..color = bright.withValues(alpha: (0.60 + 0.35 * fire) * a),
    );
  }
}

/// A Spirit Mystic's revenant: an enemy that died inside the world and came
/// back on our side. White and lit from within, deliberately not the purple of
/// Mask+Spirit's collectible wisps — those are picked up, these fight.
void drawMysticRevenant({
  required ui.Canvas canvas,
  required ui.Offset position,
  required ui.Offset velocity,
  required double radius,
  required double rise,
  required double life,
  required double alpha,
  required double time,
  required double seed,
}) {
  final a = alpha * (life < 1.5 ? (life / 1.5).clamp(0.0, 1.0) : 1.0);
  final pulse = 0.72 + 0.28 * sin(time * 4.2 + seed);
  final rr = radius * (0.55 + 0.45 * rise);

  // A short wake behind the heading, so it reads as something moving
  // under its own will rather than a floating pickup.
  final v = velocity;
  if (v.distance > 1) {
    final back = -v / v.distance;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        position + back * (rr * 1.25 * i),
        rr * (0.72 - i * 0.16),
        ui.Paint()
          ..color = const ui.Color(
            0xFFAFC4FF,
          ).withValues(alpha: 0.16 * a / i),
      );
    }
  }

  canvas.drawCircle(
    position,
    rr * 2.1,
    ui.Paint()
      ..color = const ui.Color(0xFF8FA8FF).withValues(alpha: 0.14 * a * pulse),
  );
  canvas.drawCircle(
    position,
    rr,
    ui.Paint()
      ..color = const ui.Color(0xFFE8EEFF).withValues(alpha: 0.82 * a),
  );
  canvas.drawCircle(
    position,
    rr * 0.46,
    ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.95 * a * pulse),
  );
  // The turn itself: a ring that expands once as the body changes sides.
  if (rise < 1) {
    canvas.drawCircle(
      position,
      rr * (1.4 + rise * 3.2),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const ui.Color(
          0xFFFFFFFF,
        ).withValues(alpha: 0.55 * (1.0 - rise) * a),
    );
  }
}

/// One bolt from a Lightning Mystic's storm: a jagged fall out of the dark
/// onto a body, plus the flash it leaves on the ground.
///
/// Drawn from well above the strike and clipped by the viewport, so it reads
/// as coming out of the sky rather than as a beam between two points on the
/// floor.
void drawMysticLightningBolt({
  required ui.Canvas canvas,
  required ui.Offset strike,
  required double progress,
  required double seed,
  required bool onBoss,
}) {
  // Fast, bright, gone. A bolt that fades linearly reads as a flare.
  final t = (1.0 - progress).clamp(0.0, 1.0);
  final a = t * t;
  if (a <= 0.01) return;

  const fallHeight = 620.0;
  const segments = 11;
  final spine = <ui.Offset>[];
  for (var i = 0; i <= segments; i++) {
    final f = i / segments;
    // The jag narrows toward the ground, so the strike point stays precise
    // while the upper run wanders.
    final wobble =
        sin(f * 9.4 + seed * 5.1) * 34.0 * (1.0 - f) +
        sin(f * 21.0 + seed * 2.3) * 11.0 * (1.0 - f);
    spine.add(
      ui.Offset(strike.dx + wobble, strike.dy - fallHeight * (1.0 - f)),
    );
  }

  final glow = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  final path = ui.Path()..moveTo(spine.first.dx, spine.first.dy);
  for (final p in spine.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }

  glow
    ..strokeWidth = (onBoss ? 15.0 : 10.0)
    ..color = const ui.Color(0xFF7FB6FF).withValues(alpha: 0.22 * a);
  canvas.drawPath(path, glow);
  glow
    ..strokeWidth = (onBoss ? 6.0 : 4.0)
    ..color = const ui.Color(0xFFBFE0FF).withValues(alpha: 0.72 * a);
  canvas.drawPath(path, glow);
  glow
    ..strokeWidth = (onBoss ? 2.4 : 1.6)
    ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.95 * a);
  canvas.drawPath(path, glow);

  // Ground flash, spreading as it dies.
  final flash = (onBoss ? 58.0 : 38.0) * (1.0 + (1.0 - t) * 1.6);
  canvas.drawCircle(
    strike,
    flash,
    ui.Paint()
      ..color = const ui.Color(0xFF9FCCFF).withValues(alpha: 0.20 * a),
  );
  canvas.drawCircle(
    strike,
    flash * 0.34,
    ui.Paint()
      ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.55 * a),
  );
}

/// An Earth Mystic's quake, as a shock ring running out across the arena with
/// cracks opening behind it.
///
/// Expanding rings are wrong for a thing that stays (they read as an effect
/// re-firing), and exactly right for a thing that happens — this one lives
/// about a second and is gone.
void drawMysticQuake({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double progress,
  required ui.Color earth,
}) {
  final t = progress.clamp(0.0, 1.0);
  if (t >= 1) return;
  // Races out and slows, the way a front loses energy.
  final eased = 1.0 - (1.0 - t) * (1.0 - t);
  final a = (1.0 - t) * (1.0 - t);
  final r = radius * eased;

  // Subtler than it was. The screen itself shakes for a quake now, so the ring
  // only has to say WHERE the front is — a heavy ring with bright cracks was
  // doing all the work of conveying force on its own, and looked like a decal
  // for it.
  final ring = ui.Paint()..style = ui.PaintingStyle.stroke;
  ring
    ..strokeWidth = 10.0 * a + 1.5
    ..color = earth.withValues(alpha: 0.20 * a);
  canvas.drawCircle(centre, r, ring);
  ring
    ..strokeWidth = 3.0 * a + 0.8
    ..color = ui.Color.lerp(earth, const ui.Color(0xFFFFE2A8), 0.5)!
        .withValues(alpha: 0.34 * a);
  canvas.drawCircle(centre, r * 0.97, ring);

  // Cracks: short radial splits trailing the front.
  final crack = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = ui.StrokeCap.round
    ..color = earth.withValues(alpha: 0.24 * a);
  for (var i = 0; i < 8; i++) {
    final ang = i * (pi * 2 / 8) + 0.21;
    final dir = ui.Offset(cos(ang), sin(ang));
    final inner = r * 0.72;
    final jag = ui.Path()
      ..moveTo(centre.dx + dir.dx * inner, centre.dy + dir.dy * inner);
    for (var k = 1; k <= 3; k++) {
      final f = inner + (r - inner) * (k / 3);
      final off = ui.Offset(-dir.dy, dir.dx) * (sin(i * 2.7 + k) * 12.0);
      jag.lineTo(centre.dx + dir.dx * f + off.dx, centre.dy + dir.dy * f + off.dy);
    }
    canvas.drawPath(jag, crack);
  }
}

/// One patch of a Poison Mystic's trail.
///
/// Built from overlapping offset blobs rather than one circle: a spill has an
/// edge that wanders, and a ring of perfect circles down the ship's flight path
/// reads as a row of placed objects.
void drawMysticPoisonPatch({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double alpha,
  required double seed,
  required double time,
  required ui.Color poison,
}) {
  if (alpha <= 0.01) return;
  final body = ui.Paint()..color = poison.withValues(alpha: 0.20 * alpha);
  for (var i = 0; i < 5; i++) {
    final ang = seed + i * 1.27;
    final off = ui.Offset(cos(ang), sin(ang)) * (radius * 0.30);
    canvas.drawCircle(centre + off, radius * (0.62 + 0.16 * sin(seed + i)), body);
  }
  canvas.drawCircle(
    centre,
    radius * 0.58,
    ui.Paint()..color = poison.withValues(alpha: 0.26 * alpha),
  );

  // Bubbles surfacing and popping, so the patch is alive rather than a stain.
  final bubble = ui.Paint()
    ..color = ui.Color.lerp(poison, const ui.Color(0xFFEAFFD0), 0.6)!
        .withValues(alpha: 0.55 * alpha);
  for (var i = 0; i < 3; i++) {
    final phase = (time * 0.7 + seed + i * 0.41) % 1.0;
    final ang = seed * 2.1 + i * 2.09;
    final at = centre + ui.Offset(cos(ang), sin(ang)) * (radius * 0.42);
    canvas.drawCircle(at, (1.4 + 2.6 * phase) * (1.0 - phase), bubble);
  }
}

/// Ground cover a Mystic world grows on the map — small, per-element, and
/// scaled by [bloom], which carries it up out of the floor and back down.
///
/// Deliberately a different SHAPE per element rather than one sprout in
/// seventeen colours: a world the player cannot identify from the ground at a
/// glance is not really changing the map, it is tinting it.
/// Element colours are tuned for creatures on a light card; several are so
/// dark they vanish as ground cover on a near-black floor. Lift lightness with
/// the hue intact — lerping toward white would wash out the vivid ones.
ui.Color _floraInk(ui.Color c) {
  // Scaled up by its own brightest channel rather than lerped toward white:
  // that keeps the hue and the saturation exactly where they were and only
  // raises the level, so Mud stays brown and Poison stays violet.
  final peak = [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
  if (peak >= 0.62 || peak <= 0.001) return c;
  final gain = 0.62 / peak;
  return ui.Color.from(
    alpha: c.a,
    red: (c.r * gain).clamp(0.0, 1.0),
    green: (c.g * gain).clamp(0.0, 1.0),
    blue: (c.b * gain).clamp(0.0, 1.0),
  );
}

void drawMysticFlora({
  required ui.Canvas canvas,
  required ui.Offset at,
  required String element,
  required double size,
  required double bloom,
  required double seed,
  required double time,
  required ui.Color tint,
}) {
  if (bloom <= 0.02) return;
  final grow = bloom * size;
  // Every element's ground cover was built against Plant's sprout and came out
  // half its size, so on a dark floor only Plant read as anything. The rest are
  // scaled to match it.
  final lift = _floraInk(tint);
  final sway = sin(time * 1.4 + seed) * 0.16;
  final bright = ui.Color.lerp(tint, const ui.Color(0xFFFFFFFF), 0.45)!;

  switch (element) {
    case 'Plant':
      // A sprout: a curling stem with a couple of leaves and a flower on top.
      final h = 26.0 * grow;
      final stem = <ui.Offset>[
        for (var i = 0; i <= 6; i++)
          () {
            final f = i / 6;
            return ui.Offset(
              at.dx + sin(f * 2.2 + seed) * 6.0 * f + sway * 10 * f,
              at.dy - h * f,
            );
          }(),
      ];
      canvas.drawPath(
        _tapered(stem, 3.4 * grow, 1.0 * grow),
        ui.Paint()..color = tint.withValues(alpha: 0.80 * bloom),
      );
      for (var i = 0; i < 2; i++) {
        final at2 = stem[2 + i * 2];
        final side = i.isEven ? 1.0 : -1.0;
        final len = (11.0 - i * 2.0) * grow;
        final leaf = <ui.Offset>[
          for (var k = 0; k <= 4; k++)
            () {
              final lf = k / 4;
              return at2 +
                  ui.Offset(side * len * lf, -len * 0.34 * lf * lf);
            }(),
        ];
        canvas.drawPath(
          _tapered(leaf, 4.2 * grow, 0.6),
          ui.Paint()..color = tint.withValues(alpha: 0.62 * bloom),
        );
      }
      // The flower, opening with the bloom.
      final crown = stem.last;
      for (var i = 0; i < 5; i++) {
        final pa = seed + i * (pi * 2 / 5) + sway;
        canvas.drawCircle(
          crown + ui.Offset(cos(pa), sin(pa)) * (4.4 * grow),
          2.6 * grow,
          ui.Paint()..color = bright.withValues(alpha: 0.82 * bloom),
        );
      }
      canvas.drawCircle(
        crown,
        2.4 * grow,
        ui.Paint()
          ..color = const ui.Color(0xFFFFE9A8).withValues(alpha: 0.92 * bloom),
      );

    case 'Fire':
      // A cinder guttering on the ground.
      final flick = 0.7 + 0.3 * sin(time * 6.0 + seed);
      canvas.drawCircle(
        at,
        13.0 * grow * flick,
        ui.Paint()
          ..color = const ui.Color(0xFFFF6A1E).withValues(alpha: 0.16 * bloom),
      );
      final flame = ui.Path()
        ..moveTo(at.dx - 6.0 * grow, at.dy)
        ..quadraticBezierTo(
          at.dx + sway * 10,
          at.dy - 24.0 * grow * flick,
          at.dx + 6.0 * grow,
          at.dy,
        )
        ..close();
      canvas.drawPath(
        flame,
        ui.Paint()
          ..color = const ui.Color(0xFFFFB060).withValues(alpha: 0.80 * bloom),
      );

    case 'Poison':
      // A blister swelling and going down.
      final swell = 0.75 + 0.25 * sin(time * 2.2 + seed);
      canvas.drawCircle(
        at,
        15.0 * grow * swell,
        ui.Paint()..color = lift.withValues(alpha: 0.30 * bloom),
      );
      canvas.drawCircle(
        at + ui.Offset(sway * 5, -3.0 * grow),
        6.4 * grow * swell,
        ui.Paint()..color = bright.withValues(alpha: 0.62 * bloom),
      );

    case 'Spirit':
      // A grave-light: a pale ring standing over nothing.
      canvas.drawCircle(
        at,
        16.0 * grow,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const ui.Color(0xFFDCE8FF).withValues(alpha: 0.34 * bloom),
      );
      canvas.drawCircle(
        at + ui.Offset(sway * 7, -11.0 * grow),
        4.0 * grow,
        ui.Paint()
          ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.70 * bloom),
      );

    case 'Lightning':
      // Static crawling on the floor between two points.
      final arc = ui.Path()..moveTo(at.dx - 17.0 * grow, at.dy);
      for (var i = 1; i <= 4; i++) {
        final f = i / 4;
        arc.lineTo(
          at.dx + (-17.0 + 34.0 * f) * grow,
          at.dy + sin(seed + i * 2.1 + time * 9) * 7.0 * grow,
        );
      }
      canvas.drawPath(
        arc,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const ui.Color(0xFFBFE0FF).withValues(alpha: 0.72 * bloom),
      );

    case 'Mud':
      // A mire pit: a wet, uneven hole in the floor with a skin that bulges
      // and pops. Deliberately sunk INTO the ground where Earth's stone is
      // pushed out of it, so the two brown worlds are not one texture twice.
      final churn = 0.82 + 0.18 * sin(time * 1.6 + seed);
      // Mud's element colour is the darkest in the palette and this was
      // darkening it further, so a mire pit on a near-black floor was almost
      // nothing at all. Lifted, and the rim catches light like wet ground.
      for (var i = 0; i < 4; i++) {
        final ang = seed + i * 1.57;
        final off = ui.Offset(cos(ang), sin(ang)) * (9.0 * grow);
        canvas.drawCircle(
          at + off,
          (16.0 - i * 1.6) * grow * churn,
          ui.Paint()..color = lift.withValues(alpha: 0.44 * bloom),
        );
      }
      canvas.drawCircle(
        at,
        11.0 * grow * churn,
        ui.Paint()
          ..color = ui.Color.lerp(lift, const ui.Color(0xFF2A1608), 0.45)!
              .withValues(alpha: 0.85 * bloom),
      );
      canvas.drawCircle(
        at + ui.Offset(-2.5 * grow, -3.0 * grow),
        4.5 * grow * churn,
        ui.Paint()..color = bright.withValues(alpha: 0.28 * bloom),
      );
      // A bubble surfacing and bursting.
      final burst = (time * 0.9 + seed) % 1.0;
      canvas.drawCircle(
        at + ui.Offset(sway * 5, -1.5 * grow),
        (1.2 + 3.4 * burst) * grow * (1.0 - burst),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = bright.withValues(alpha: 0.50 * bloom * (1.0 - burst)),
      );

    case 'Earth':
      // A stone pushed up out of the floor.
      final stone = ui.Path()
        ..moveTo(at.dx - 15.0 * grow, at.dy + 5.0 * grow)
        ..lineTo(at.dx - 8.0 * grow, at.dy - 15.0 * grow)
        ..lineTo(at.dx + 9.0 * grow, at.dy - 11.0 * grow)
        ..lineTo(at.dx + 15.0 * grow, at.dy + 5.0 * grow)
        ..close();
      canvas.drawPath(
        stone,
        ui.Paint()..color = lift.withValues(alpha: 0.82 * bloom),
      );
      canvas.drawPath(
        stone,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = bright.withValues(alpha: 0.30 * bloom),
      );
  }
}

/// The sky gathering over the spot a Lightning Mystic is about to strike.
///
/// Drawn on the ground rather than in the air: the player needs to read WHERE,
/// and a glow up in the sky tells them nothing they can act on. It tightens as
/// it charges, so the shrinking ring is the countdown.
void drawMysticStormCharge({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double progress,
  required double seed,
  required double time,
}) {
  final t = progress.clamp(0.0, 1.0);
  // Comes up fast and holds, so the mark is legible for most of the wind-up
  // rather than only at the end.
  final a = (t * 3.2).clamp(0.0, 1.0);
  const outer = 96.0;
  final ring = outer * (1.0 - 0.62 * t);
  final pale = const ui.Color(0xFFBFE0FF);

  canvas.drawCircle(
    at,
    ring,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.4 + 2.2 * t
      ..color = pale.withValues(alpha: 0.34 * a),
  );
  // Sparks running inward along the ring, converging on the point.
  final spark = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeWidth = 1.6
    ..color = pale.withValues(alpha: 0.55 * a);
  for (var i = 0; i < 6; i++) {
    final ang = seed + i * (pi * 2 / 6) + time * 2.4;
    final dir = ui.Offset(cos(ang), sin(ang));
    canvas.drawLine(at + dir * ring, at + dir * (ring * 0.62), spark);
  }
  // The ground under it brightening as the charge builds.
  canvas.drawCircle(
    at,
    ring * 0.30,
    ui.Paint()
      ..color = pale.withValues(alpha: 0.10 + 0.45 * t * t),
  );
  // A last hard pip at the moment before it lands.
  if (t > 0.82) {
    final snap = (t - 0.82) / 0.18;
    canvas.drawCircle(
      at,
      4.0 + 10.0 * snap,
      ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.8 * snap),
    );
  }
}

/// A Crystal world's shard, waiting to be collected.
void drawMysticCrystalShard({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double alpha,
  required double seed,
  required double time,
  required ui.Color tint,
}) {
  if (alpha <= 0.01) return;
  // Turns slowly and catches the light, so it reads as something valuable
  // rather than as another projectile lying on the floor.
  final spin = time * 1.1 + seed;
  final facet = 0.72 + 0.28 * sin(time * 2.6 + seed);
  final bob = sin(time * 2.2 + seed) * 2.0;
  final c = at + ui.Offset(0, bob);
  final bright = ui.Color.lerp(tint, const ui.Color(0xFFFFFFFF), 0.55)!;

  canvas.drawCircle(
    c,
    13.0,
    ui.Paint()..color = tint.withValues(alpha: 0.14 * alpha * facet),
  );
  // A cut gem: two mirrored tapers meeting at the waist.
  final h = 9.0;
  final w = 5.4;
  final dir = ui.Offset(cos(spin), sin(spin));
  final side = ui.Offset(-dir.dy, dir.dx);
  final body = ui.Path()
    ..moveTo(c.dx + dir.dx * h, c.dy + dir.dy * h)
    ..lineTo(c.dx + side.dx * w, c.dy + side.dy * w)
    ..lineTo(c.dx - dir.dx * h, c.dy - dir.dy * h)
    ..lineTo(c.dx - side.dx * w, c.dy - side.dy * w)
    ..close();
  canvas.drawPath(body, ui.Paint()..color = tint.withValues(alpha: 0.88 * alpha));
  canvas.drawPath(
    body,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = bright.withValues(alpha: 0.75 * alpha),
  );
  canvas.drawCircle(
    c,
    2.0 * facet,
    ui.Paint()..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.9 * alpha),
  );
}

/// A Light world's star, hanging outside the arena and brightening toward dawn.
///
/// Drawn huge and far off, because the ability IS the wait: the player needs to
/// be able to glance at it from anywhere on the field and know how close it is.
void drawMysticDawnStar({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double charge,
  required double flare,
  required double alpha,
  required double time,
}) {
  if (alpha <= 0.01) return;
  final t = charge.clamp(0.0, 1.0);
  // Grows through the wait and blows out at the break.
  final core = 120.0 * (0.32 + 0.68 * t) + 260.0 * flare;
  final gold = const ui.Color(0xFFFFD98A);
  final white = const ui.Color(0xFFFFFFFF);
  final breath = 0.9 + 0.1 * sin(time * 1.4);

  // Corona, as a few nested discs rather than a blur.
  for (var i = 4; i >= 1; i--) {
    canvas.drawCircle(
      at,
      core * (1.0 + i * 0.55) * breath,
      ui.Paint()
        ..color = gold.withValues(alpha: (0.055 - i * 0.008) * alpha * (0.4 + t)),
    );
  }
  canvas.drawCircle(
    at,
    core * breath,
    ui.Paint()..color = gold.withValues(alpha: (0.30 + 0.55 * t) * alpha),
  );
  canvas.drawCircle(
    at,
    core * 0.58 * breath,
    ui.Paint()..color = white.withValues(alpha: (0.35 + 0.60 * t) * alpha),
  );

  // Rays reaching further as it fills, so the progress is readable from across
  // the arena without a bar.
  final ray = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeWidth = 3.0 + 6.0 * t
    ..color = gold.withValues(alpha: (0.16 + 0.34 * t) * alpha);
  for (var i = 0; i < 12; i++) {
    final ang = i * (pi * 2 / 12) + time * 0.12;
    final dir = ui.Offset(cos(ang), sin(ang));
    final inner = core * 1.1;
    final outer = inner + (60.0 + 220.0 * t) * (i.isEven ? 1.0 : 0.62);
    canvas.drawLine(at + dir * inner, at + dir * outer, ray);
  }
}

/// A Steam world venting: the arena exhaling, and the front of that exhale
/// running outward past everything it just threw.
///
/// Deliberately unlike Earth's quake ring, which is a hard crack with dust
/// trailing it. This is soft, billowing and pale — pressure, not fracture —
/// because the two are the only worlds that resolve as an arena-wide ring and
/// they have to be told apart at a glance.
void drawMysticVent({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double progress,
  required double time,
}) {
  final t = progress.clamp(0.0, 1.0);
  if (t >= 1) return;
  final eased = 1.0 - (1.0 - t) * (1.0 - t);
  final a = (1.0 - t) * (1.0 - t);
  final r = radius * eased;
  final pale = const ui.Color(0xFFE6F2FF);

  // The front, as a soft band rather than a line.
  final band = ui.Paint()..style = ui.PaintingStyle.stroke;
  for (var i = 0; i < 3; i++) {
    band
      ..strokeWidth = (34.0 - i * 10.0) * a + 2.0
      ..color = pale.withValues(alpha: (0.10 - i * 0.025) * a);
    canvas.drawCircle(centre, r * (1.0 - i * 0.03), band);
  }
  band
    ..strokeWidth = 3.0 * a + 1.0
    ..color = pale.withValues(alpha: 0.42 * a);
  canvas.drawCircle(centre, r, band);

  // Billows rolling along the front — the thing that makes it read as vapour
  // rather than as a shockwave.
  final puff = ui.Paint()..color = pale.withValues(alpha: 0.13 * a);
  for (var i = 0; i < 18; i++) {
    final ang = i * (pi * 2 / 18) + sin(time * 0.8 + i) * 0.08;
    final wobble = 1.0 + sin(i * 2.3 + time * 3.0) * 0.05;
    canvas.drawCircle(
      centre + ui.Offset(cos(ang), sin(ang)) * (r * wobble),
      (20.0 + 26.0 * t) * a + 4.0,
      puff,
    );
  }
}

/// A Lava world's fissure: a crack in the arena floor with molten light in it.
///
/// Drawn as a dark split with a glowing seam INSIDE it rather than a bright
/// line on top of the floor — a glowing line reads as a laser or a boundary
/// marker, where a crack has to read as depth the player is looking into.
void drawMysticFissure({
  required ui.Canvas canvas,
  required List<ui.Offset> points,
  required double alpha,
  required double flare,
  required double seed,
  required double time,
}) {
  if (alpha <= 0.01 || points.length < 2) return;
  final breath = 0.78 + 0.22 * sin(time * 1.5 + seed);
  final heat = (breath + flare * 1.4).clamp(0.0, 2.0);

  final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length - 1; i++) {
    final mid = ui.Offset(
      (points[i].dx + points[i + 1].dx) * 0.5,
      (points[i].dy + points[i + 1].dy) * 0.5,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);

  final stroke = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;

  // Heat bleeding onto the ground either side of the split.
  stroke
    ..strokeWidth = 26.0 + 10.0 * flare
    ..color = const ui.Color(0xFFFF6A1E).withValues(alpha: 0.07 * alpha * heat);
  canvas.drawPath(path, stroke);
  // The split itself: dark, so the seam inside it has something to glow out of.
  stroke
    ..strokeWidth = 11.0
    ..color = const ui.Color(0xFF180703).withValues(alpha: 0.92 * alpha);
  canvas.drawPath(path, stroke);
  // Molten seam.
  stroke
    ..strokeWidth = 5.0 + 2.5 * flare
    ..color = const ui.Color(0xFFFF7A1E).withValues(alpha: (0.55 * heat).clamp(0.0, 0.95) * alpha);
  canvas.drawPath(path, stroke);
  stroke
    ..strokeWidth = 1.8 + 1.6 * flare
    ..color = const ui.Color(0xFFFFD9A0).withValues(alpha: (0.60 * heat).clamp(0.0, 0.98) * alpha);
  canvas.drawPath(path, stroke);
}

/// A meteor a broken fissure threw up, on its way back down.
///
/// Falls into its impact point from off the top of the frame, with the shadow
/// on the ground tightening as it closes — that shadow is the only warning the
/// player gets, so it is drawn before the rock is anywhere near.
void drawMysticLavaMeteor({
  required ui.Canvas canvas,
  required ui.Offset impact,
  required double progress,
  required double seed,
}) {
  final t = progress.clamp(0.0, 1.0);
  const height = 560.0;
  // Accelerating, so it reads as falling rather than sliding down a wire.
  final drop = t * t;
  final at = impact - ui.Offset(0, height * (1.0 - drop));

  // Ground shadow: wide and faint at range, tight and dark on arrival.
  canvas.drawCircle(
    impact,
    46.0 - 28.0 * t,
    ui.Paint()
      ..color = const ui.Color(0xFF000000).withValues(alpha: 0.18 + 0.34 * t),
  );
  canvas.drawCircle(
    impact,
    (46.0 - 28.0 * t) * 0.62,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const ui.Color(0xFFFF7A1E).withValues(alpha: 0.30 + 0.45 * t),
  );

  // The rock, with a tail of what is burning off it.
  final tail = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeWidth = 7.0
    ..color = const ui.Color(0xFFFF7A1E).withValues(alpha: 0.45);
  canvas.drawLine(at, at - const ui.Offset(0, 58), tail);
  tail
    ..strokeWidth = 2.6
    ..color = const ui.Color(0xFFFFD9A0).withValues(alpha: 0.62);
  canvas.drawLine(at, at - const ui.Offset(0, 40), tail);

  canvas.drawCircle(
    at,
    12.0,
    ui.Paint()..color = const ui.Color(0xFFFF7A1E).withValues(alpha: 0.20),
  );
  canvas.drawCircle(
    at,
    7.0,
    ui.Paint()..color = const ui.Color(0xFF3A1408),
  );
  canvas.drawCircle(
    at + ui.Offset(cos(seed) * 2.0, sin(seed) * 2.0 - 1.5),
    3.2,
    ui.Paint()..color = const ui.Color(0xFFFFB060),
  );
}

/// The mark a lava meteor leaves, cooling from molten to ash.
void drawMysticScorch({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double age,
  required double maxAge,
  required double seed,
}) {
  final t = (age / maxAge).clamp(0.0, 1.0);
  final a = t > 0.72 ? ((1.0 - t) / 0.28).clamp(0.0, 1.0) : 1.0;
  // Cools through its life: bright at the moment of landing, ash by the end.
  final heat = (1.0 - t) * (1.0 - t);
  final r = 34.0 + 14.0 * t;

  canvas.drawCircle(
    at,
    r,
    ui.Paint()
      ..color = const ui.Color(0xFF1C0B04).withValues(alpha: 0.55 * a),
  );
  for (var i = 0; i < 5; i++) {
    final ang = seed + i * 1.26;
    canvas.drawCircle(
      at + ui.Offset(cos(ang), sin(ang)) * (r * 0.42),
      r * 0.34,
      ui.Paint()
        ..color = const ui.Color(0xFFFF6A1E).withValues(alpha: 0.30 * heat * a),
    );
  }
  canvas.drawCircle(
    at,
    r * 0.30,
    ui.Paint()
      ..color = const ui.Color(0xFFFFB060).withValues(alpha: 0.55 * heat * a),
  );
}

/// A Water world's maelstrom: the whole surface turning around one eye.
///
/// Spiral arms rather than concentric rings. Rings would only say "a circular
/// thing is here" — arms say which WAY the water is going, which is the thing
/// the player reads the crowd's motion against, and it is what keeps this from
/// looking like Dark's accretion disc in blue.
void drawMysticMaelstrom({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required double phase,
  required double alpha,
  required double time,
}) {
  if (alpha <= 0.01) return;
  final water = const ui.Color(0xFF3FC8E8);
  final pale = const ui.Color(0xFFDFF6FF);

  // The body of the water, darkening toward the eye.
  canvas.drawCircle(
    centre,
    radius,
    ui.Paint()..color = water.withValues(alpha: 0.055 * alpha),
  );
  canvas.drawCircle(
    centre,
    radius * 0.58,
    ui.Paint()..color = water.withValues(alpha: 0.06 * alpha),
  );

  // Arms. Logarithmic sweeps from the eye out to the rim, all turning together.
  final arm = ui.Paint()
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round;
  const arms = 5;
  for (var a = 0; a < arms; a++) {
    final base = phase + a * (pi * 2 / arms);
    final path = ui.Path();
    for (var i = 0; i <= 26; i++) {
      final f = i / 26;
      // Wraps harder near the eye, the way a real vortex tightens.
      final ang = base + f * 3.1 - (1.0 - f) * 1.6;
      final r = radius * (0.10 + 0.90 * f);
      final p = centre + ui.Offset(cos(ang), sin(ang)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    arm
      ..strokeWidth = 9.0
      ..color = water.withValues(alpha: 0.16 * alpha);
    canvas.drawPath(path, arm);
    arm
      ..strokeWidth = 2.4
      ..color = pale.withValues(alpha: 0.26 * alpha);
    canvas.drawPath(path, arm);
  }

  // Foam scattered along the current, so the surface has texture between arms.
  final foam = ui.Paint()..color = pale.withValues(alpha: 0.30 * alpha);
  for (var i = 0; i < 22; i++) {
    final f = 0.18 + (i % 7) / 7.0 * 0.78;
    final ang = phase * (0.5 + f) + i * 1.47;
    final r = radius * f;
    canvas.drawCircle(
      centre + ui.Offset(cos(ang), sin(ang)) * r,
      1.6 + 1.4 * sin(time * 3.0 + i),
      foam,
    );
  }

  // The eye: dark, still, and ringed by the fastest water on the field.
  canvas.drawCircle(
    centre,
    radius * 0.10,
    ui.Paint()..color = const ui.Color(0xFF04121C).withValues(alpha: 0.62 * alpha),
  );
  canvas.drawCircle(
    centre,
    radius * 0.10,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = pale.withValues(alpha: 0.50 * alpha),
  );
  // Rim, so the edge of the hold is unambiguous — everything inside it stops.
  canvas.drawCircle(
    centre,
    radius,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = water.withValues(alpha: 0.30 * alpha),
  );
}

/// An Air world's tornado, seen from above.
///
/// A funnel is a vertical thing and this arena is not, so it is drawn as a set
/// of OFFSET rings — each one further from the base than the last, leaning the
/// way the tornado is travelling. That lean is what sells height on a top-down
/// field, and it is also what keeps this from reading as another whirlpool:
/// the maelstrom is flat and concentric, this one is stacked and skewed.
void drawMysticTornado({
  required ui.Canvas canvas,
  required ui.Offset at,
  required double radius,
  required double phase,
  required double travelAngle,
  required double alpha,
  required double time,
}) {
  if (alpha <= 0.01) return;
  final pale = const ui.Color(0xFFDCF0FF);
  final lean = ui.Offset(cos(travelAngle), sin(travelAngle));

  // Dust skirt where it meets the ground: widest, faintest, and it stays put.
  canvas.drawCircle(
    at,
    radius,
    ui.Paint()..color = pale.withValues(alpha: 0.05 * alpha),
  );
  canvas.drawCircle(
    at,
    radius * 0.72,
    ui.Paint()..color = pale.withValues(alpha: 0.05 * alpha),
  );

  // The funnel: rings climbing away from the base, narrowing then flaring.
  final ring = ui.Paint()..style = ui.PaintingStyle.stroke;
  const bands = 7;
  for (var i = 0; i < bands; i++) {
    final f = i / (bands - 1);
    // Narrow at the waist, flared at the top — an hourglass read as height.
    final width = radius * (0.62 - 0.34 * sin(f * pi) + 0.42 * f);
    final centre = at - lean * (radius * 0.30 * f) - ui.Offset(0, radius * 0.52 * f);
    final wobble = sin(phase + f * 3.4) * radius * 0.06;
    ring
      ..strokeWidth = 2.6 - f * 1.1
      ..color = pale.withValues(alpha: (0.34 - f * 0.035) * alpha);
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: centre + ui.Offset(wobble, 0),
        width: width * 2,
        height: width * 1.05,
      ),
      ring,
    );
  }

  // Debris carried round the waist, so the direction of spin is unmistakable.
  final debris = ui.Paint()..color = pale.withValues(alpha: 0.55 * alpha);
  for (var i = 0; i < 14; i++) {
    final f = (i % 5) / 5.0;
    final ang = phase * (1.4 + f) + i * 1.32;
    final r = radius * (0.26 + 0.46 * f);
    final centre = at - lean * (radius * 0.30 * f) - ui.Offset(0, radius * 0.52 * f);
    canvas.drawCircle(
      centre + ui.Offset(cos(ang) * r, sin(ang) * r * 0.52),
      1.5 + 1.5 * (1.0 - f),
      debris,
    );
  }

  // Core, so the middle of the pull is obvious to aim around.
  canvas.drawCircle(
    at,
    radius * 0.16,
    ui.Paint()..color = pale.withValues(alpha: 0.20 * alpha),
  );
  // Rim: the edge of the lift.
  canvas.drawCircle(
    at,
    radius,
    ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = pale.withValues(alpha: 0.26 * alpha),
  );
}
