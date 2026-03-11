// lib/games/survival/components/alchemy_orb.dart
import 'dart:math';

import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class AlchemyOrb extends PositionComponent {
  final double maxHp;
  double currentHp;

  // Skin identity & colors
  final OrbBaseSkin skinType;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;

  // NEW: transmutation / XP style progress (0..1)
  double transmutationProgress = 0.0;

  // Animation state
  double _time = 0;
  final Random _rng = Random();
  final List<_ManaMote> _particles = [];

  double _hitFlash = 0.0;

  // Paints
  late final Paint _corePaint;
  late final Paint _glowPaint;
  late final Paint _runePaint;
  late final Paint _hpBackgroundPaint;
  late final Paint _hpFillPaint;
  late final Paint _flashPaint;

  // NEW: transmutation circle paints
  late final Paint _transmuteBgPaint;
  late final Paint _transmuteFillPaint;

  AlchemyOrb({
    required this.maxHp,
    this.skinType = OrbBaseSkin.defaultOrb,
    this.primaryColor = const Color(0xFF00BCD4),
    this.secondaryColor = const Color(0xFF3F51B5),
    this.glowColor = const Color(0xFF00E5FF),
  }) : currentHp = maxHp,
       super(size: Vector2.all(160), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    _glowPaint = Paint()..color = glowColor.withValues(alpha: 0.5);

    _corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, primaryColor, secondaryColor],
        stops: const [0.1, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    _runePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _hpBackgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    _hpFillPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    _flashPaint = Paint()..color = Colors.red.withValues(alpha: 0.0);

    // NEW transmutation paints
    _transmuteBgPaint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    _transmuteFillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Breathing effect
    add(
      ScaleEffect.by(
        Vector2.all(1.05),
        EffectController(
          duration: 2.0,
          reverseDuration: 2.0,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    _hitFlash = (_hitFlash - dt * 4.0).clamp(0.0, 1.0).toDouble();

    if (_rng.nextDouble() < _particleSpawnRate) {
      _particles.add(_ManaMote(size / 2, _particleColor));
    }

    for (var p in _particles) {
      p.update(dt);
    }
    _particles.removeWhere((p) => p.life <= 0);
  }

  /// Particle spawn rate varies by skin
  double get _particleSpawnRate {
    switch (skinType) {
      case OrbBaseSkin.phantomWispOrb:
        return 0.2; // more ghostly wisps
      case OrbBaseSkin.prismHeartOrb:
        return 0.15;
      case OrbBaseSkin.verdantBloomOrb:
        return 0.12; // leaf motes
      default:
        return 0.1;
    }
  }

  /// Particle color varies by skin
  Color get _particleColor {
    switch (skinType) {
      case OrbBaseSkin.frozenNexusOrb:
        return Colors.white;
      case OrbBaseSkin.verdantBloomOrb:
        // alternate green/yellow
        return _rng.nextBool()
            ? const Color(0xFF7FFF00)
            : const Color(0xFF32CD32);
      case OrbBaseSkin.prismHeartOrb:
        // rainbow particles
        return HSVColor.fromAHSV(
          1.0,
          _rng.nextDouble() * 360,
          0.8,
          1.0,
        ).toColor();
      default:
        return glowColor;
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);

    // Skin-specific rendering
    switch (skinType) {
      case OrbBaseSkin.frozenNexusOrb:
        _renderFrozenNexus(canvas, center);
      case OrbBaseSkin.phantomWispOrb:
        _renderPhantomWisp(canvas, center);
      case OrbBaseSkin.prismHeartOrb:
        _renderPrismHeart(canvas, center);
      case OrbBaseSkin.verdantBloomOrb:
        _renderVerdantBloom(canvas, center);
      default:
        _renderDefault(canvas, center);
    }

    // Damage flash (shared)
    if (_hitFlash > 0) {
      final opacity = 0.5 * _hitFlash;
      _flashPaint.color = Colors.red.withValues(alpha: opacity);
      canvas.drawCircle(center, 40, _flashPaint);
    }

    // HP ring (shared)
    _renderCircularHp(canvas, center);

    // Transmutation ring (shared)
    _renderTransmutationCircle(canvas, center);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEFAULT skin — original cyan/blue rune rings
  // ─────────────────────────────────────────────────────────────────────────
  void _renderDefault(Canvas canvas, Offset center) {
    final particlePaint = Paint()..color = glowColor;

    // Outer glow
    canvas.drawCircle(center, 60, _glowPaint);

    // Particles
    for (var p in _particles) {
      particlePaint.color = p.color.withValues(alpha: p.life);
      canvas.drawCircle(p.position, p.size, particlePaint);
    }

    // Rotating runes
    _renderRuneRing(canvas, center, radius: 55, speed: 0.5, segments: 3);
    _renderRuneRing(canvas, center, radius: 70, speed: -0.3, segments: 5);

    // Core
    canvas.drawCircle(center, 40, _corePaint);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FROZEN NEXUS — ice crystal with orbiting frost shards
  // ─────────────────────────────────────────────────────────────────────────
  void _renderFrozenNexus(Canvas canvas, Offset center) {
    final particlePaint = Paint()..color = glowColor;

    // Frosty outer glow — larger, subtle
    final frostGlow = Paint()
      ..color = glowColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, 70, frostGlow);

    // Snowflake particles
    for (var p in _particles) {
      particlePaint.color = p.color.withValues(alpha: p.life * 0.8);
      // draw tiny diamond shapes instead of circles
      final d = p.size * 1.5;
      final path = Path()
        ..moveTo(p.position.dx, p.position.dy - d)
        ..lineTo(p.position.dx + d * 0.6, p.position.dy)
        ..lineTo(p.position.dx, p.position.dy + d)
        ..lineTo(p.position.dx - d * 0.6, p.position.dy)
        ..close();
      canvas.drawPath(path, particlePaint);
    }

    // Orbiting ice shards (6 jagged shards)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final shardPaint = Paint()
      ..color = const Color(0xFFB0EAFF).withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final shardOutline = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 6; i++) {
      final angle = _time * 0.4 + (i * pi / 3);
      final dist = 55.0 + sin(_time * 1.5 + i) * 5;
      final sx = cos(angle) * dist;
      final sy = sin(angle) * dist;

      canvas.save();
      canvas.translate(sx, sy);
      canvas.rotate(angle + _time * 0.8);

      // Jagged shard triangle
      final shard = Path()
        ..moveTo(0, -10)
        ..lineTo(4, 2)
        ..lineTo(2, 10)
        ..lineTo(-2, 10)
        ..lineTo(-4, 2)
        ..close();
      canvas.drawPath(shard, shardPaint);
      canvas.drawPath(shard, shardOutline);
      canvas.restore();
    }
    canvas.restore();

    // Core — icy faceted look with hex pattern
    final icePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, primaryColor, secondaryColor],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 40));
    canvas.drawCircle(center, 40, icePaint);

    // Inner frost lines
    final frostLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int i = 0; i < 8; i++) {
      final a = i * pi / 4 + _time * 0.1;
      canvas.drawLine(
        center,
        center + Offset(cos(a) * 35, sin(a) * 35),
        frostLine,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHANTOM WISP — ghostly flickering, semi-transparent
  // ─────────────────────────────────────────────────────────────────────────
  void _renderPhantomWisp(Canvas canvas, Offset center) {
    // Flickering opacity based on time
    final flicker = 0.5 + 0.3 * sin(_time * 3.0) + 0.2 * sin(_time * 7.1);

    // Ethereal glow layers (multiple large blurs)
    for (int i = 3; i >= 1; i--) {
      final ghostGlow = Paint()
        ..color = glowColor.withValues(alpha: 0.08 * i * flicker)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15.0 + i * 10);
      canvas.drawCircle(center, 50.0 + i * 10, ghostGlow);
    }

    // Ghost trail particles — wispy paths
    final particlePaint = Paint();
    for (var p in _particles) {
      particlePaint.color = p.color.withValues(alpha: p.life * flicker * 0.6);
      particlePaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(p.position, p.size * 2, particlePaint);
    }

    // Phase-shifting core — two offset cores that drift
    final drift1 = Offset(sin(_time * 2.0) * 4, cos(_time * 1.5) * 3);
    final drift2 = Offset(cos(_time * 2.5) * 3, sin(_time * 1.8) * 4);

    final core1 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: flicker * 0.8),
          primaryColor.withValues(alpha: flicker * 0.6),
          secondaryColor.withValues(alpha: flicker * 0.2),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center + drift1, radius: 38));
    canvas.drawCircle(center + drift1, 38, core1);

    final core2 = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: flicker * 0.4),
          glowColor.withValues(alpha: flicker * 0.2),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center + drift2, radius: 35));
    canvas.drawCircle(center + drift2, 35, core2);

    // Wispy ring — dashed, slowly rotating, fading in/out
    final wispRing = Paint()
      ..color = glowColor.withValues(alpha: 0.25 * flicker)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _renderRuneRing(
      canvas,
      center,
      radius: 60,
      speed: 0.2,
      segments: 8,
      overridePaint: wispRing,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRISM HEART — rainbow color-shifting with rotating facets
  // ─────────────────────────────────────────────────────────────────────────
  void _renderPrismHeart(Canvas canvas, Offset center) {
    // Rainbow rotating glow
    final hueShift = (_time * 30) % 360;
    final sweepColors = List.generate(
      7,
      (i) => HSVColor.fromAHSV(
        0.5,
        (hueShift + i * 51.4) % 360,
        0.9,
        1.0,
      ).toColor(),
    );

    final sweepGradient = SweepGradient(
      colors: [...sweepColors, sweepColors.first],
      startAngle: 0,
      endAngle: 2 * pi,
    );

    final glowRect = Rect.fromCircle(center: center, radius: 60);
    final prismGlow = Paint()
      ..shader = sweepGradient.createShader(glowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, 55, prismGlow);

    // Rainbow particles
    final particlePaint = Paint();
    for (var p in _particles) {
      particlePaint.color = p.color.withValues(alpha: p.life);
      canvas.drawCircle(p.position, p.size, particlePaint);
    }

    // Rotating faceted polygon (diamond/octagon shape)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_time * 0.3);

    final facets = 8;
    final facetRadius = 40.0;
    final facetPath = Path();
    for (int i = 0; i <= facets; i++) {
      final a = (i / facets) * 2 * pi;
      // alternate between inner and outer radii for a star/diamond effect
      final r = i.isEven ? facetRadius : facetRadius * 0.75;
      final x = cos(a) * r;
      final y = sin(a) * r;
      if (i == 0) {
        facetPath.moveTo(x, y);
      } else {
        facetPath.lineTo(x, y);
      }
    }
    facetPath.close();

    // Fill with shifting gradient
    final coreSweep = SweepGradient(
      colors: [...sweepColors, sweepColors.first],
      transform: GradientRotation(_time * 0.5),
    );

    final facetPaint = Paint()
      ..shader = coreSweep.createShader(
        Rect.fromCircle(center: Offset.zero, radius: facetRadius),
      );
    canvas.drawPath(facetPath, facetPaint);

    // White specular highlight
    final specular = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.0),
        ],
        center: const Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: facetRadius));
    canvas.drawPath(facetPath, specular);

    // Facet edges
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(facetPath, edgePaint);
    canvas.restore();

    // Radial refraction lines
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-_time * 0.15);
    final refrPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int i = 0; i < 12; i++) {
      final a = i * pi / 6;
      canvas.drawLine(
        Offset(cos(a) * 20, sin(a) * 20),
        Offset(cos(a) * 65, sin(a) * 65),
        refrPaint,
      );
    }
    canvas.restore();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VERDANT BLOOM — organic vine rings, leaf particles, pulsing life
  // ─────────────────────────────────────────────────────────────────────────
  void _renderVerdantBloom(Canvas canvas, Offset center) {
    // Organic glow — green, soft
    final lifeGlow = Paint()
      ..color = glowColor.withValues(alpha: 0.25 + 0.1 * sin(_time * 1.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(center, 60, lifeGlow);

    // Leaf particles (tiny leaf shapes)
    final leafPaint = Paint();
    for (var p in _particles) {
      leafPaint.color = p.color.withValues(alpha: p.life * 0.8);
      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.angle + _time * 0.5);
      final leafPath = Path()
        ..moveTo(0, -p.size * 1.5)
        ..quadraticBezierTo(p.size * 2, 0, 0, p.size * 1.5)
        ..quadraticBezierTo(-p.size * 2, 0, 0, -p.size * 1.5);
      canvas.drawPath(leafPath, leafPaint);
      canvas.restore();
    }

    // Vine rings — organic curves instead of perfect arcs
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final vinePaint = Paint()
      ..color = const Color(0xFF228B22).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Two vine rings with wavy distortion
    for (int ring = 0; ring < 2; ring++) {
      final baseRadius = ring == 0 ? 50.0 : 65.0;
      final speed = ring == 0 ? 0.25 : -0.2;
      final vinePath = Path();
      const segments = 40;
      for (int i = 0; i <= segments; i++) {
        final a = (i / segments) * 2 * pi + _time * speed;
        final wobble = sin(a * 4 + _time * 2) * 4;
        final r = baseRadius + wobble;
        final x = cos(a) * r;
        final y = sin(a) * r;
        if (i == 0) {
          vinePath.moveTo(x, y);
        } else {
          vinePath.lineTo(x, y);
        }
      }
      canvas.drawPath(vinePath, vinePaint);

      // Small bud dots along the vine
      final budPaint = Paint()
        ..color = const Color(0xFFFF69B4).withValues(alpha: 0.6);
      for (int i = 0; i < 5; i++) {
        final a = (i / 5) * 2 * pi + _time * speed;
        final wobble = sin(a * 4 + _time * 2) * 4;
        final r = baseRadius + wobble;
        canvas.drawCircle(Offset(cos(a) * r, sin(a) * r), 2.5, budPaint);
      }
    }
    canvas.restore();

    // Core — warm green with pulsing heartbeat
    final pulse = 1.0 + 0.08 * sin(_time * 3.0);
    final coreRadius = 38.0 * pulse;
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFF8DC), primaryColor, secondaryColor],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));
    canvas.drawCircle(center, coreRadius, corePaint);
  }

  void _renderRuneRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double speed,
    required int segments,
    Paint? overridePaint,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(_time * speed);

    final paint = overridePaint ?? _runePaint;
    final double gapSize = 0.2;
    final double sweepAngle = (2 * pi / segments) - gapSize;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * (2 * pi / segments);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
    canvas.restore();
  }

  void _renderCircularHp(Canvas canvas, Offset center) {
    final radius = 85.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, _hpBackgroundPaint);

    final percent = (currentHp / maxHp).clamp(0.0, 1.0);

    if (percent > 0.5) {
      _hpFillPaint.color = glowColor;
      _hpFillPaint.maskFilter = null;
    } else if (percent > 0.25) {
      _hpFillPaint.color = Colors.orangeAccent;
      _hpFillPaint.maskFilter = null;
    } else {
      _hpFillPaint.color = Colors.redAccent;
      _hpFillPaint.maskFilter = null;
    }

    canvas.drawArc(rect, -pi / 2, 2 * pi * percent, false, _hpFillPaint);
  }

  // NEW: purple outer circle that shows transmutation progress
  void _renderTransmutationCircle(Canvas canvas, Offset center) {
    if (transmutationProgress <= 0 && transmutationProgress < 1e-3) {
      // still draw faint bg circle so it feels “there”
      final bgRadius = 105.0;
      canvas.drawCircle(center, bgRadius, _transmuteBgPaint);
      return;
    }

    final radius = 105.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background circle
    canvas.drawCircle(center, radius, _transmuteBgPaint);

    // Sweep gradient around the circle
    final gradient = SweepGradient(
      colors: const [
        Colors.deepPurpleAccent,
        Colors.purpleAccent,
        Colors.pinkAccent,
        Colors.amberAccent,
        Colors.deepPurpleAccent,
      ],
      stops: const [0.0, 0.3, 0.6, 0.85, 1.0],
      startAngle: 0.0,
      endAngle: 2 * pi,
    );

    _transmuteFillPaint.shader = gradient.createShader(rect);

    // rotate so progress starts at top
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-pi / 2);

    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      0,
      2 * pi * transmutationProgress.clamp(0.0, 1.0),
      false,
      _transmuteFillPaint,
    );

    canvas.restore();
  }

  /// Call this from the game to update the purple ring.
  void setTransmutationProgress({
    required int currentKills,
    required int requiredKills,
  }) {
    if (requiredKills <= 0) {
      transmutationProgress = 0.0;
    } else {
      transmutationProgress = (currentKills / requiredKills)
          .clamp(0.0, 1.0)
          .toDouble();
    }
  }

  void takeDamage(int amount) {
    if (currentHp <= 0) return;
    currentHp = max(0.0, currentHp - amount);

    add(
      MoveEffect.by(
        Vector2(5, 0),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 4),
      ),
    );

    _hitFlash = 1.0;
  }

  void heal(int amount) {
    if (currentHp >= maxHp) return;
    currentHp = (currentHp + amount).clamp(0, maxHp).toDouble();

    add(
      ScaleEffect.by(
        Vector2.all(1.2),
        EffectController(duration: 0.2, reverseDuration: 0.2),
      ),
    );
  }

  bool get isDestroyed => currentHp <= 0;
}

class _ManaMote {
  Offset position;
  double life = 1.0;
  double size;
  final double speed;
  final double angle;
  final Color color;

  _ManaMote(Vector2 origin, [Color? particleColor])
    : position = Offset(origin.x, origin.y),
      size = Random().nextDouble() * 3 + 1,
      speed = Random().nextDouble() * 20 + 10,
      angle = Random().nextDouble() * 2 * pi,
      color = particleColor ?? Colors.cyanAccent;

  void update(double dt) {
    life -= dt * 0.5;
    position += Offset(cos(angle) * speed * dt, sin(angle) * speed * dt);
  }
}
