// planet_dungeon_descent.dart
//
// The descent intro: diving through a planet's atmosphere toward its dungeon.
// Every element has its own descent — motion, palette, and particle language —
// so entering Pyrathis feels nothing like entering Aquathos.
//
// Performance: everything here is plain drawCircle / drawLine / small paths.
// No MaskFilter blurs (soft puffs are 3 layered discs), no saveLayers, and
// the two fullscreen gradients are cached per size instead of being rebuilt
// every frame. Deterministic hashed particles — no per-frame allocations
// beyond Offsets.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// How the atmosphere moves past the camera during the dive.
enum DescentMotion {
  /// Rushing outward from the vanishing point (diving through cloud decks).
  dive,

  /// Streaking upward past the camera (falling through rising embers).
  rise,

  /// Streaking downward past the camera (falling with the rain/snow).
  fall,

  /// Spiraling inward around the vanishing point (sucked into a vortex).
  swirl,
}

/// What a single atmosphere particle looks like.
enum DescentLook { puff, dot, streak, shard }

class DescentStyle {
  final DescentMotion motion;
  final DescentLook look;

  /// Element tint mixed into the sky edges.
  final Color skyTint;

  /// Particle colors, cycled by hash.
  final List<Color> colors;

  final int density;
  final double sizeMin;
  final double sizeMax;

  /// Lightning-style screen flashes + jagged bolts.
  final bool bolts;

  /// Rotating god-rays from the vanishing point.
  final bool rays;

  /// Keep the converging wind lines of the classic dive.
  final bool windLines;

  const DescentStyle({
    required this.motion,
    required this.look,
    required this.skyTint,
    required this.colors,
    this.density = 40,
    this.sizeMin = 2,
    this.sizeMax = 5,
    this.bolts = false,
    this.rays = false,
    this.windLines = false,
  });
}

/// One descent per element — 17 distinct atmospheres.
const Map<String, DescentStyle> kDescentStyles = {
  'air': DescentStyle(
    motion: DescentMotion.dive,
    look: DescentLook.puff,
    skyTint: Color(0xFF7BD4E8),
    colors: [Color(0xFFBFD2E6), Color(0xFFA5F3FC), Color(0xFF8FB8CB)],
    density: 30,
    sizeMin: 14,
    sizeMax: 42,
    windLines: true,
  ),
  'fire': DescentStyle(
    motion: DescentMotion.rise,
    look: DescentLook.streak,
    skyTint: Color(0xFFFF6A2B),
    colors: [Color(0xFFFF8C42), Color(0xFFFFB25E), Color(0xFFFFE08A)],
    density: 52,
    sizeMin: 1.4,
    sizeMax: 3.2,
  ),
  'water': DescentStyle(
    motion: DescentMotion.fall,
    look: DescentLook.streak,
    skyTint: Color(0xFF2A90E3),
    colors: [Color(0xFF7DD3FC), Color(0xFF38BDF8), Color(0xFFBAE6FD)],
    density: 56,
    sizeMin: 1.0,
    sizeMax: 2.2,
  ),
  'earth': DescentStyle(
    motion: DescentMotion.dive,
    look: DescentLook.shard,
    skyTint: Color(0xFF8A5A32),
    colors: [Color(0xFFB08968), Color(0xFF8D6E63), Color(0xFFE7C9B0)],
    density: 34,
    sizeMin: 3,
    sizeMax: 8,
    windLines: true,
  ),
  'steam': DescentStyle(
    motion: DescentMotion.dive,
    look: DescentLook.puff,
    skyTint: Color(0xFF93A9B8),
    colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8), Color(0xFFE2E8F0)],
    density: 26,
    sizeMin: 20,
    sizeMax: 54,
  ),
  'lava': DescentStyle(
    motion: DescentMotion.rise,
    look: DescentLook.puff,
    skyTint: Color(0xFFB91C1C),
    colors: [Color(0xFFF97316), Color(0xFF991B1B), Color(0xFFFB923C)],
    density: 30,
    sizeMin: 6,
    sizeMax: 18,
  ),
  'lightning': DescentStyle(
    motion: DescentMotion.dive,
    look: DescentLook.dot,
    skyTint: Color(0xFFD1AC06),
    colors: [Color(0xFFFDE047), Color(0xFFFEF08A), Color(0xFFE3B325)],
    density: 40,
    sizeMin: 1.2,
    sizeMax: 2.6,
    bolts: true,
    windLines: true,
  ),
  'mud': DescentStyle(
    motion: DescentMotion.fall,
    look: DescentLook.puff,
    skyTint: Color(0xFF5D4634),
    colors: [Color(0xFF8D6E63), Color(0xFF48321F), Color(0xFFB08968)],
    density: 30,
    sizeMin: 5,
    sizeMax: 12,
  ),
  'ice': DescentStyle(
    motion: DescentMotion.fall,
    look: DescentLook.dot,
    skyTint: Color(0xFF66CFFF),
    colors: [Color(0xFFBAE6FD), Color(0xFFE0F2FE), Color(0xFF93C5FD)],
    density: 48,
    sizeMin: 1.4,
    sizeMax: 3.4,
  ),
  'dust': DescentStyle(
    motion: DescentMotion.swirl,
    look: DescentLook.dot,
    skyTint: Color(0xFFB59B72),
    colors: [Color(0xFFD6C6AC), Color(0xFFD6D3D1), Color(0xFFF5F5F4)],
    density: 60,
    sizeMin: 1.0,
    sizeMax: 2.6,
  ),
  'crystal': DescentStyle(
    motion: DescentMotion.swirl,
    look: DescentLook.shard,
    skyTint: Color(0xFF6D4ACD),
    colors: [Color(0xFFC4B5FD), Color(0xFFE9D5FF), Color(0xFFB6AEFF)],
    density: 26,
    sizeMin: 3,
    sizeMax: 7,
  ),
  'plant': DescentStyle(
    motion: DescentMotion.swirl,
    look: DescentLook.puff,
    skyTint: Color(0xFF3F9C50),
    colors: [Color(0xFF86EFAC), Color(0xFF76CF82), Color(0xFFA7F3D0)],
    density: 34,
    sizeMin: 3,
    sizeMax: 8,
  ),
  'poison': DescentStyle(
    motion: DescentMotion.rise,
    look: DescentLook.puff,
    skyTint: Color(0xFF6F3FBE),
    colors: [Color(0xFF34D399), Color(0xFF7C5CBF), Color(0xFFA7F3D0)],
    density: 26,
    sizeMin: 5,
    sizeMax: 14,
  ),
  'spirit': DescentStyle(
    motion: DescentMotion.swirl,
    look: DescentLook.puff,
    skyTint: Color(0xFFBEA9FF),
    colors: [Color(0xFFFFFFFF), Color(0xFFE9D5FF), Color(0xFFBEA9FF)],
    density: 24,
    sizeMin: 6,
    sizeMax: 16,
  ),
  'dark': DescentStyle(
    motion: DescentMotion.swirl,
    look: DescentLook.puff,
    skyTint: Color(0xFF433061),
    colors: [Color(0xFF433061), Color(0xFF7C5CBF), Color(0xFF211A33)],
    density: 30,
    sizeMin: 10,
    sizeMax: 26,
  ),
  'light': DescentStyle(
    motion: DescentMotion.rise,
    look: DescentLook.dot,
    skyTint: Color(0xFFFCD34D),
    colors: [Color(0xFFFFF1B7), Color(0xFFFFF7ED), Color(0xFFFCD34D)],
    density: 40,
    sizeMin: 1.2,
    sizeMax: 3.0,
    rays: true,
  ),
  'blood': DescentStyle(
    motion: DescentMotion.fall,
    look: DescentLook.streak,
    skyTint: Color(0xFF7A0019),
    colors: [Color(0xFFEF4444), Color(0xFFB91C1C), Color(0xFFFCA5A5)],
    density: 40,
    sizeMin: 1.6,
    sizeMax: 3.4,
  ),
};

double _hash(int n) {
  final v = sin(n * 127.1) * 43758.5453;
  return v - v.floorToDouble();
}

/// Cached fullscreen gradients — rebuilt only when the size or tint changes,
/// not every frame (the old painter allocated two shaders per paint).
class _BgCache {
  Size? size;
  Color? tint;
  ui.Shader? sky;
  ui.Shader? vignette;
}

class DescentPainter extends CustomPainter {
  DescentPainter({
    required this.elapsed,
    required this.element,
    required this.accent,
  });

  final double elapsed;
  final String element;
  final Color accent;

  static final _BgCache _bg = _BgCache();
  // Dedicated paint for the fullscreen shader draws: a Paint's color alpha
  // MODULATES its shader, so reusing _fill (whose color the particle passes
  // mutate) would render the sky translucent and let the dungeon show
  // through the descent. This paint's color is never touched.
  static final Paint _bgPaint = Paint();
  static final Paint _fill = Paint();
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  DescentStyle get _style =>
      kDescentStyles[element.toLowerCase()] ??
      DescentStyle(
        motion: DescentMotion.dive,
        look: DescentLook.puff,
        skyTint: accent,
        colors: [Color.lerp(const Color(0xFFBFD2E6), accent, 0.35)!],
        density: 30,
        sizeMin: 14,
        sizeMax: 42,
        windLines: true,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final style = _style;
    final c = Offset(size.width / 2, size.height * 0.46);
    final maxR = size.longestSide * 0.75;

    // --- Sky + vignette (cached shaders) ---
    if (_bg.size != size || _bg.tint != style.skyTint) {
      _bg.size = size;
      _bg.tint = style.skyTint;
      _bg.sky = ui.Gradient.radial(c, maxR * 1.3, [
        const Color(0xFF0A1322),
        Color.lerp(const Color(0xFF060A12), style.skyTint, 0.16)!,
      ]);
      _bg.vignette = ui.Gradient.radial(
        c,
        maxR * 1.15,
        [const Color(0x00000000), const Color(0xCC000000)],
        [0.55, 1.0],
      );
    }
    _bgPaint.shader = _bg.sky;
    canvas.drawRect(Offset.zero & size, _bgPaint);

    // --- God-rays (light) ---
    if (style.rays) _drawRays(canvas, c, maxR, style);

    // --- Atmosphere particles ---
    for (var i = 0; i < style.density; i++) {
      final speed = 0.45 + _hash(i * 7 + 1) * 0.5;
      final phase = (elapsed * speed + _hash(i * 7 + 2)) % 1.0;
      final color = style.colors[i % style.colors.length];
      final psize =
          style.sizeMin + _hash(i * 7 + 3) * (style.sizeMax - style.sizeMin);

      switch (style.motion) {
        case DescentMotion.dive:
          final a = _hash(i * 7 + 4) * 2 * pi + elapsed * 0.1;
          final r = pow(phase, 1.7).toDouble() * maxR + 14;
          final alpha = ((1 - phase) * 0.35 * phase * 4).clamp(0.0, 0.4);
          if (alpha <= 0.01) break;
          _drawParticle(
            canvas,
            c + Offset(cos(a), sin(a)) * r,
            psize * (0.4 + phase),
            color.withValues(alpha: alpha),
            style.look,
            angle: a,
          );
          break;

        case DescentMotion.rise:
        case DescentMotion.fall:
          final down = style.motion == DescentMotion.fall;
          final x =
              _hash(i * 7 + 4) * size.width +
              sin(elapsed * 2 + i) * 6 * _hash(i * 7 + 5);
          final travel = phase * (size.height + 120) - 60;
          final y = down ? travel : size.height - travel;
          final alpha = (0.20 + 0.35 * _hash(i * 7 + 6)) *
              (phase < 0.1 ? phase * 10 : (phase > 0.9 ? (1 - phase) * 10 : 1));
          if (style.look == DescentLook.streak) {
            final len = 18 + speed * 46;
            _stroke
              ..color = color.withValues(alpha: alpha.clamp(0.0, 0.55))
              ..strokeWidth = psize;
            canvas.drawLine(
              Offset(x, y),
              Offset(x, down ? y - len : y + len),
              _stroke,
            );
          } else {
            _drawParticle(
              canvas,
              Offset(x, y),
              psize,
              color.withValues(alpha: alpha.clamp(0.0, 0.5)),
              style.look,
              angle: elapsed * 2 + i,
            );
          }
          break;

        case DescentMotion.swirl:
          // Spiral inward toward the vanishing point.
          final a = _hash(i * 7 + 4) * 2 * pi + phase * 4.2 + elapsed * 0.15;
          final r = (1 - pow(phase, 1.3)) * maxR * 0.9 + 10;
          final alpha =
              (0.12 + 0.3 * phase) * (phase > 0.92 ? (1 - phase) * 12 : 1);
          _drawParticle(
            canvas,
            c + Offset(cos(a), sin(a)) * r,
            psize * (0.5 + 0.7 * phase),
            color.withValues(alpha: alpha.clamp(0.0, 0.45)),
            style.look,
            angle: a + pi / 2,
          );
          break;
      }
    }

    // --- Converging wind lines (dive/dust feel) ---
    if (style.windLines) {
      for (var i = 0; i < 14; i++) {
        final a = i * pi / 7 + sin(elapsed * 0.6) * 0.08;
        final phase = ((elapsed * 1.4 + i * 0.13) % 1.0);
        final inner = maxR * (0.18 + phase * 0.5);
        final outer = inner + 40 + phase * 90;
        _stroke
          ..strokeWidth = 1.2
          ..color = style.colors.first.withValues(alpha: 0.20 * (1 - phase));
        canvas.drawLine(
          c + Offset(cos(a), sin(a)) * inner,
          c + Offset(cos(a), sin(a)) * outer,
          _stroke,
        );
      }
    }

    // --- Storm bolts + flash (lightning) ---
    if (style.bolts) _drawBolts(canvas, size, c, style);

    // --- Vignette (cached shader) ---
    _bgPaint.shader = _bg.vignette;
    canvas.drawRect(Offset.zero & size, _bgPaint);
  }

  /// Soft puff = 3 layered discs (no MaskFilter blur — that was the frame
  /// killer in the old painter). Dots and shards are single draws.
  void _drawParticle(
    Canvas canvas,
    Offset pos,
    double r,
    Color color,
    DescentLook look, {
    double angle = 0,
  }) {
    switch (look) {
      case DescentLook.puff:
        _fill.color = color.withValues(alpha: color.a * 0.30);
        canvas.drawCircle(pos, r, _fill);
        _fill.color = color.withValues(alpha: color.a * 0.55);
        canvas.drawCircle(pos, r * 0.62, _fill);
        _fill.color = color;
        canvas.drawCircle(pos, r * 0.32, _fill);
        break;
      case DescentLook.dot:
        _fill.color = color;
        canvas.drawCircle(pos, r, _fill);
        break;
      case DescentLook.streak:
        _fill.color = color;
        canvas.drawCircle(pos, r, _fill);
        break;
      case DescentLook.shard:
        _fill.color = color;
        final ca = cos(angle);
        final sa = sin(angle);
        final path = Path()
          ..moveTo(pos.dx + ca * r * 1.6, pos.dy + sa * r * 1.6)
          ..lineTo(pos.dx - sa * r * 0.7, pos.dy + ca * r * 0.7)
          ..lineTo(pos.dx - ca * r * 1.6, pos.dy - sa * r * 1.6)
          ..lineTo(pos.dx + sa * r * 0.7, pos.dy - ca * r * 0.7)
          ..close();
        canvas.drawPath(path, _fill);
        break;
    }
  }

  void _drawRays(Canvas canvas, Offset c, double maxR, DescentStyle style) {
    final rot = elapsed * 0.12;
    for (var i = 0; i < 10; i++) {
      final a = rot + i * 2 * pi / 10;
      final w = 0.05 + 0.03 * _hash(i + 40);
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + cos(a - w) * maxR * 1.3, c.dy + sin(a - w) * maxR * 1.3)
        ..lineTo(c.dx + cos(a + w) * maxR * 1.3, c.dy + sin(a + w) * maxR * 1.3)
        ..close();
      _fill.color = style.colors.first.withValues(
        alpha: 0.045 + 0.02 * sin(elapsed * 1.4 + i),
      );
      canvas.drawPath(path, _fill);
    }
  }

  void _drawBolts(Canvas canvas, Size size, Offset c, DescentStyle style) {
    // Deterministic flash windows: a bolt lives for the first 14% of each
    // ~0.9s cycle, seeded by the cycle index.
    final cycle = elapsed * 1.1;
    final flashPhase = cycle % 1.0;
    if (flashPhase > 0.14) return;
    final seed = cycle.floor();
    final fade = 1.0 - flashPhase / 0.14;

    // Dim full-screen flash.
    _fill.color = Colors.white.withValues(alpha: 0.06 * fade);
    canvas.drawRect(Offset.zero & size, _fill);

    // Jagged bolt from the top toward the vanishing point.
    final startX = size.width * (0.2 + 0.6 * _hash(seed * 13 + 1));
    var p = Offset(startX, -10);
    final path = Path()..moveTo(p.dx, p.dy);
    const segs = 6;
    for (var s = 1; s <= segs; s++) {
      final t = s / segs;
      p = Offset(
        ui.lerpDouble(startX, c.dx, t)! +
            (_hash(seed * 13 + s + 2) - 0.5) * 60 * (1 - t),
        ui.lerpDouble(-10, c.dy, t)!,
      );
      path.lineTo(p.dx, p.dy);
    }
    _stroke
      ..strokeWidth = 2.2
      ..color = style.colors[1].withValues(alpha: 0.85 * fade);
    canvas.drawPath(path, _stroke);
    _stroke
      ..strokeWidth = 5.0
      ..color = style.colors[1].withValues(alpha: 0.18 * fade);
    canvas.drawPath(path, _stroke);
  }

  @override
  bool shouldRepaint(covariant DescentPainter old) =>
      elapsed != old.elapsed || element != old.element;
}
