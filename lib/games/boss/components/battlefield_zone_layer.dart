// Flame layer that renders persistent battlefield ground zones below
// the combatant sprites. Reads from `BattlefieldZoneRegistry` every
// frame; positioning is fixed per side (one anchor under the boss, one
// under the player team). Painters mirror the visual vocabulary of
// cosmic survival's `_drawMaskGroundZone` family — kept slim and
// inlined here for Slice 4; the shared painter module lands in Slice 6.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/services/gameengines/battlefield_zone.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BattlefieldZoneLayer extends PositionComponent {
  final BattlefieldZoneRegistry registry;
  double _time = 0;

  /// Anchor point for player-side zones in game coordinates.
  Vector2 playerAnchor;

  /// Anchor point for boss-side zones in game coordinates.
  Vector2 bossAnchor;

  /// Base zone radius (game units).
  final double zoneRadius;

  BattlefieldZoneLayer({
    required this.registry,
    required this.playerAnchor,
    required this.bossAnchor,
    this.zoneRadius = 70,
  }) : super(priority: -50); // behind combatant sprites

  @override
  void update(double dt) {
    _time += dt;
    super.update(dt);
  }

  @override
  void render(ui.Canvas canvas) {
    for (final z in registry.zones) {
      final anchor = z.side == ZoneSide.boss ? bossAnchor : playerAnchor;
      final pos = ui.Offset(anchor.x, anchor.y);
      final color = _zoneColor(z.family, z.element);
      final pulse = 0.78 + 0.22 * sin(_time * 1.6 + z.spawnedAtTurn * 0.8);
      // Outer soft glow — layered concentric, no MaskFilter.blur.
      final glowPaint = ui.Paint();
      for (var i = 4; i >= 1; i--) {
        glowPaint.color = color.withValues(alpha: (0.04 + i * 0.025) * pulse);
        canvas.drawCircle(pos, zoneRadius * (0.6 + i * 0.12), glowPaint);
      }
      _paintZone(canvas, pos, zoneRadius, color, pulse, z);
    }
  }

  void _paintZone(
    ui.Canvas canvas,
    ui.Offset pos,
    double radius,
    Color color,
    double pulse,
    BattlefieldZone z,
  ) {
    final white = Color.lerp(color, const Color(0xFFFFFFFF), 0.4)!;
    switch (z.element) {
      case 'Poison':
        _paintPoisonPool(canvas, pos, radius, color, pulse);
        return;
      case 'Fire':
      case 'Lava':
      case 'Steam':
        _paintFireZone(canvas, pos, radius, color, white, pulse);
        return;
      case 'Ice':
        _paintIcePillar(canvas, pos, radius, color, white, pulse);
        return;
      case 'Plant':
        _paintPlantZone(canvas, pos, radius, color, pulse);
        return;
      case 'Crystal':
        _paintCrystalCluster(canvas, pos, radius, color, white, pulse);
        return;
      case 'Dark':
      case 'Spirit':
        _paintDarkVoid(canvas, pos, radius, color, pulse);
        return;
    }
    // Fallback: rim + faint fill so unrouted zones still read as
    // "something is on the ground here" rather than missing.
    _paintZoneFill(canvas, pos, radius, color, alpha: 0.28 * pulse, rim: 0.55);
  }

  // ── Painters (slim ports of cosmic_projectile_vfx) ─────────────────

  void _paintZoneFill(
    ui.Canvas canvas,
    ui.Offset position,
    double radius,
    Color color, {
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
    Color tint,
    int count,
    double pulse,
  ) {
    final p = ui.Paint();
    for (var i = 0; i < count; i++) {
      final phase = (_time * 0.9 + i * 0.7) % 1.0;
      final a = i * (pi * 2 / count) + _time * 0.18;
      final r = radius * (0.25 + 0.55 * phase);
      final pos2 = position + ui.Offset(cos(a), sin(a)) * r;
      final size = radius * (0.05 + 0.07 * (1 - phase));
      p.color = tint.withValues(alpha: (1 - phase) * 0.7 * pulse);
      canvas.drawCircle(pos2, size, p);
    }
  }

  void _paintPoisonPool(
    ui.Canvas canvas,
    ui.Offset position,
    double radius,
    Color color,
    double pulse,
  ) {
    _paintZoneFill(
      canvas,
      position,
      radius,
      color,
      alpha: 0.32 * pulse,
      rim: 0.65 * pulse,
    );
    final inner = ui.Paint()
      ..color = Color.lerp(
        color,
        const Color(0xFF2B0E3A),
        0.45,
      )!.withValues(alpha: 0.28 * pulse);
    canvas.drawCircle(position, radius * 0.62, inner);
    _paintBubbles(canvas, position, radius * 0.85, color, 7, pulse);
    final vapor = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.withValues(alpha: 0.55 * pulse);
    for (var i = 0; i < 3; i++) {
      final t = (_time * 0.5 + i * 0.33) % 1.0;
      final base =
          position +
          ui.Offset(
            cos(i * 2.1 + _time * 0.3) * radius * 0.4,
            sin(i * 1.7 + _time * 0.4) * radius * 0.4,
          );
      final tip = base + ui.Offset(0, -radius * 0.65 * t);
      canvas.drawLine(base, tip, vapor);
    }
  }

  void _paintFireZone(
    ui.Canvas canvas,
    ui.Offset position,
    double radius,
    Color color,
    Color white,
    double pulse,
  ) {
    final ground = ui.Paint()
      ..color = Color.lerp(
        color,
        const Color(0xFF1A0000),
        0.55,
      )!.withValues(alpha: 0.4 * pulse);
    canvas.drawCircle(position, radius, ground);
    final hot = ui.Paint()..color = color.withValues(alpha: 0.6 * pulse);
    canvas.drawCircle(position, radius * 0.5, hot);
    for (var i = 0; i < 7; i++) {
      final a = i * (pi * 2 / 7) + sin(_time * 4 + i) * 0.25;
      final h = radius * (0.55 + 0.4 * (1 + sin(_time * 8 + i * 0.7)) / 2);
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
        ..color = Color.lerp(color, white, 0.35)!.withValues(alpha: 0.7 * pulse);
      canvas.drawPath(tongue, flame);
    }
  }

  void _paintIcePillar(
    ui.Canvas canvas,
    ui.Offset position,
    double radius,
    Color color,
    Color white,
    double pulse,
  ) {
    final frost = ui.Paint()
      ..color = Color.lerp(
        color,
        white,
        0.55,
      )!.withValues(alpha: 0.35 * pulse);
    canvas.drawCircle(position, radius, frost);
    final flake = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = white.withValues(alpha: 0.7 * pulse);
    for (var i = 0; i < 6; i++) {
      final a = i * (pi / 3);
      final tip = position + ui.Offset(cos(a), sin(a)) * radius * 0.85;
      canvas.drawLine(position, tip, flake);
      final prongA = tip - ui.Offset(cos(a), sin(a)) * radius * 0.25;
      final pL =
          prongA + ui.Offset(cos(a + pi / 2), sin(a + pi / 2)) * radius * 0.18;
      final pR =
          prongA + ui.Offset(cos(a - pi / 2), sin(a - pi / 2)) * radius * 0.18;
      canvas.drawLine(prongA, pL, flake);
      canvas.drawLine(prongA, pR, flake);
    }
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
      ..strokeWidth = 1.4
      ..color = white.withValues(alpha: 0.85 * pulse);
    canvas.drawPath(pillarPath, pillarEdge);
  }

  void _paintPlantZone(
    ui.Canvas canvas,
    ui.Offset position,
    double radius,
    Color color,
    double pulse,
  ) {
    _paintZoneFill(
      canvas,
      position,
      radius,
      color,
      alpha: 0.32 * pulse,
      rim: 0.5,
    );
    final tendril = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = ui.StrokeCap.round
      ..color = Color.lerp(
        color,
        const Color(0xFF1F4F22),
        0.3,
      )!.withValues(alpha: 0.85 * pulse);
    for (var i = 0; i < 6; i++) {
      final a = i * (pi * 2 / 6) + _time * 0.05;
      final tip = position + ui.Offset(cos(a), sin(a)) * radius * 0.95;
      final mid =
          position + ui.Offset(cos(a + 0.6), sin(a + 0.6)) * radius * 0.55;
      final p = ui.Path()
        ..moveTo(position.dx, position.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
      canvas.drawPath(p, tendril);
      final bud = ui.Paint()
        ..color = Color.lerp(
          color,
          const Color(0xFFFFFFFF),
          0.55,
        )!.withValues(alpha: 0.85 * pulse);
      canvas.drawCircle(tip, 2.4, bud);
    }
  }

  void _paintCrystalCluster(
    ui.Canvas canvas,
    ui.Offset position,
    double radius,
    Color color,
    Color white,
    double pulse,
  ) {
    final base = ui.Paint()
      ..color = Color.lerp(
        color,
        const Color(0xFF000000),
        0.55,
      )!.withValues(alpha: 0.3 * pulse);
    canvas.drawCircle(position, radius * 0.6, base);
    const shardCount = 5;
    for (var i = 0; i < shardCount; i++) {
      final a = i * (pi * 2 / shardCount) + _time * 0.04;
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
        ..strokeWidth = 1.3
        ..color = white.withValues(alpha: 0.65 * pulse);
      canvas.drawPath(shard, edge);
      final mid = ui.Offset(
        (left.dx + tip.dx) * 0.5,
        (left.dy + tip.dy) * 0.5,
      );
      canvas.drawLine(mid, tip, edge);
    }
  }

  void _paintDarkVoid(
    ui.Canvas canvas,
    ui.Offset position,
    double radius,
    Color color,
    double pulse,
  ) {
    final pit = ui.Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.85 * pulse);
    canvas.drawCircle(position, radius * 0.55, pit);
    final accretion = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = color.withValues(alpha: 0.78 * pulse);
    canvas.drawCircle(position, radius * 0.65, accretion);
    final spiral = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color.withValues(alpha: 0.6 * pulse);
    for (var arm = 0; arm < 3; arm++) {
      final p = ui.Path();
      const segs = 22;
      for (var i = 0; i < segs; i++) {
        final t = i / (segs - 1);
        final a = arm * (pi * 2 / 3) + t * pi * 1.5 - _time * 0.7;
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

  Color _zoneColor(String family, String element) {
    switch (element) {
      case 'Poison':
        return const Color(0xFF7CFC8E);
      case 'Fire':
        return const Color(0xFFFF7043);
      case 'Ice':
        return const Color(0xFF8FE0FF);
      case 'Dark':
        return const Color(0xFF6A0DAD);
      case 'Crystal':
        return const Color(0xFF80DEEA);
      case 'Plant':
        return const Color(0xFF8BC34A);
      case 'Lava':
        return const Color(0xFFFF5722);
      case 'Water':
        return const Color(0xFF4FC3F7);
      case 'Lightning':
        return const Color(0xFFFFEE58);
      default:
        return const Color(0xFFE8DCC8);
    }
  }
}
