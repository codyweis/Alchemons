import 'dart:math';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

/// Enhanced particle for alchemy brewing effects
class AlchemyParticle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double opacity;
  double rotation;
  double rotationSpeed;
  double life; // 0.0 to 1.0
  double energy; // for reaction effects
  String elementType; // which parent this came from ("parentA" | "parentB")

  // Pre-baked draw color: color * opacity * life. Set in _resetParticle and
  // refreshed via bakeColor() whenever opacity or life changes. Eliminates
  // a Color alloc + withValues() call in the hot draw path every frame.
  Color drawnColor;

  AlchemyParticle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.opacity,
    required this.elementType,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.life = 1.0,
    this.energy = 1.0,
  }) : drawnColor = color.withValues(alpha: opacity);

  void bakeColor() {
    drawnColor = color.withValues(alpha: (opacity * life).clamp(0.0, 1.0));
  }
}

/// Reaction spark particle (created when elements collide)
class ReactionSpark {
  Offset position;
  Color color;
  double size;
  double life;

  ReactionSpark({
    required this.position,
    required this.color,
    required this.size,
    this.life = 1.0,
  });
}

/// Configuration for element-specific behavior
class ElementConfig {
  final String elementId;
  final List<Color> colors;
  final double minSize;
  final double maxSize;
  final double minSpeed;
  final double maxSpeed;
  final ParticleMovementPattern movement;
  final ParticleShape shape;

  const ElementConfig({
    required this.elementId,
    required this.colors,
    this.minSize = 2.0,
    this.maxSize = 6.0,
    this.minSpeed = 0.5,
    this.maxSpeed = 2.0,
    this.movement = ParticleMovementPattern.rising,
    this.shape = ParticleShape.circle,
  });
}

enum ParticleMovementPattern {
  rising,
  falling,
  flowing,
  swirling,
  crackling,
  floating,
  growing,
  pulsing,
}

enum ParticleShape { circle, square, diamond, star, leaf, shard }

/// Element configurations
class ElementalConfigs {
  static const fire = ElementConfig(
    elementId: 'T001',
    colors: [Color(0xFFFF7E57), Color(0xFFFF8C00), Color(0xFFFFD700)],
    minSize: 3.0,
    maxSize: 8.0,
    minSpeed: 1.0,
    maxSpeed: 3.0,
    movement: ParticleMovementPattern.rising,
    shape: ParticleShape.circle,
  );

  static const water = ElementConfig(
    elementId: 'T002',
    colors: [Color(0xFF1574A1), Color(0xFF38BDF8), Color(0xFF7DD3FC)],
    minSize: 2.5,
    maxSize: 6.0,
    minSpeed: 0.5,
    maxSpeed: 2.0,
    movement: ParticleMovementPattern.flowing,
    shape: ParticleShape.circle,
  );

  static const earth = ElementConfig(
    elementId: 'T003',
    colors: [Color(0xFF94502B), Color(0xFFB45309), Color(0xFFE7C9B0)],
    minSize: 4.0,
    maxSize: 9.0,
    minSpeed: 0.3,
    maxSpeed: 1.0,
    movement: ParticleMovementPattern.falling,
    shape: ParticleShape.square,
  );

  static const air = ElementConfig(
    elementId: 'T004',
    colors: [Color(0xFFCEDAB1), Color(0xFFA5F3FC), Color(0xFF67E8F9)],
    minSize: 2.0,
    maxSize: 5.0,
    minSpeed: 1.5,
    maxSpeed: 3.5,
    movement: ParticleMovementPattern.swirling,
    shape: ParticleShape.circle,
  );

  static const steam = ElementConfig(
    elementId: 'T005',
    colors: [Color(0xFF6C838E), Color(0xFF93C5FD), Color(0xFFFCA5A5)],
    minSize: 4.0,
    maxSize: 10.0,
    minSpeed: 0.8,
    maxSpeed: 2.5,
    movement: ParticleMovementPattern.rising,
    shape: ParticleShape.circle,
  );

  static const lava = ElementConfig(
    elementId: 'T006',
    colors: [Color(0xFF631C1C), Color(0xFFF97316), Color(0xFFFB923C)],
    minSize: 5.0,
    maxSize: 11.0,
    minSpeed: 0.2,
    maxSpeed: 0.8,
    movement: ParticleMovementPattern.falling,
    shape: ParticleShape.circle,
  );

  static const lightning = ElementConfig(
    elementId: 'T007',
    colors: [Color(0xFFE3B325), Color(0xFFFEF08A), Color(0xFFFDE047)],
    minSize: 2.0,
    maxSize: 4.0,
    minSpeed: 3.0,
    maxSpeed: 6.0,
    movement: ParticleMovementPattern.crackling,
    shape: ParticleShape.diamond,
  );

  static const mud = ElementConfig(
    elementId: 'T008',
    colors: [Color(0xFF48321F), Color(0xFF8D6E63), Color(0xFFB08968)],
    minSize: 4.0,
    maxSize: 8.0,
    minSpeed: 0.2,
    maxSpeed: 0.9,
    movement: ParticleMovementPattern.falling,
    shape: ParticleShape.circle,
  );

  static const ice = ElementConfig(
    elementId: 'T009',
    colors: [Color(0xFF93E8FF), Color(0xFFBAE6FD), Color(0xFF93C5FD)],
    minSize: 3.0,
    maxSize: 7.0,
    minSpeed: 0.3,
    maxSpeed: 1.5,
    movement: ParticleMovementPattern.floating,
    shape: ParticleShape.shard,
  );

  static const dust = ElementConfig(
    elementId: 'T010',
    colors: [Color(0xFFD6C6AC), Color(0xFFF5F5F4), Color(0xFFD6D3D1)],
    minSize: 1.5,
    maxSize: 4.0,
    minSpeed: 1.0,
    maxSpeed: 3.0,
    movement: ParticleMovementPattern.swirling,
    shape: ParticleShape.circle,
  );

  static const crystal = ElementConfig(
    elementId: 'T011',
    colors: [Color(0xFFB6AEFF), Color(0xFFE9D5FF), Color(0xFFC4B5FD)],
    minSize: 3.0,
    maxSize: 7.0,
    minSpeed: 0.5,
    maxSpeed: 1.8,
    movement: ParticleMovementPattern.floating,
    shape: ParticleShape.diamond,
  );

  static const plant = ElementConfig(
    elementId: 'T012',
    colors: [Color(0xFF76CF82), Color(0xFFA7F3D0), Color(0xFF86EFAC)],
    minSize: 3.0,
    maxSize: 7.0,
    minSpeed: 0.4,
    maxSpeed: 1.5,
    movement: ParticleMovementPattern.growing,
    shape: ParticleShape.leaf,
  );

  static const poison = ElementConfig(
    elementId: 'T013',
    colors: [Color(0xFF472CBE), Color(0xFFA7F3D0), Color(0xFF34D399)],
    minSize: 3.0,
    maxSize: 7.0,
    minSpeed: 0.3,
    maxSpeed: 1.2,
    movement: ParticleMovementPattern.pulsing,
    shape: ParticleShape.circle,
  );

  static const spirit = ElementConfig(
    elementId: 'T014',
    colors: [Color(0xFFFFFFFF), Color(0xFFE9D5FF), Color(0xFFBEA9FF)],
    minSize: 3.0,
    maxSize: 8.0,
    minSpeed: 0.8,
    maxSpeed: 2.5,
    movement: ParticleMovementPattern.swirling,
    shape: ParticleShape.circle,
  );

  static const dark = ElementConfig(
    elementId: 'T015',
    colors: [Color(0xFF111827), Color(0xFF1F2937), Color(0xFF4B5563)],
    minSize: 4.0,
    maxSize: 9.0,
    minSpeed: 0.5,
    maxSpeed: 1.8,
    movement: ParticleMovementPattern.pulsing,
    shape: ParticleShape.circle,
  );

  static const light = ElementConfig(
    elementId: 'T016',
    colors: [Color(0xFFFFF1B7), Color(0xFFFFF7ED), Color(0xFFFCD34D)],
    minSize: 2.0,
    maxSize: 6.0,
    minSpeed: 1.0,
    maxSpeed: 3.0,
    movement: ParticleMovementPattern.pulsing,
    shape: ParticleShape.star,
  );

  static const blood = ElementConfig(
    elementId: 'T017',
    colors: [Color(0xFFB91C1C), Color(0xFFEF4444), Color(0xFFFCA5A5)],
    minSize: 3.0,
    maxSize: 7.0,
    minSpeed: 0.4,
    maxSpeed: 1.5,
    movement: ParticleMovementPattern.flowing,
    shape: ParticleShape.circle,
  );

  static ElementConfig? getConfig(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return fire;
      case 'water':
        return water;
      case 'earth':
        return earth;
      case 'air':
        return air;
      case 'steam':
        return steam;
      case 'lava':
        return lava;
      case 'lightning':
        return lightning;
      case 'mud':
        return mud;
      case 'ice':
        return ice;
      case 'dust':
        return dust;
      case 'crystal':
        return crystal;
      case 'plant':
        return plant;
      case 'poison':
        return poison;
      case 'spirit':
        return spirit;
      case 'dark':
        return dark;
      case 'light':
        return light;
      case 'blood':
        return blood;
      default:
        return null;
    }
  }
}

/// Custom painter for alchemy brewing effect + fusion glyphs
class AlchemyBrewingPainter extends CustomPainter {
  final List<AlchemyParticle> particles;
  final List<ReactionSpark> sparks;
  final ElementConfig config1;
  final ElementConfig? config2;
  final double animationProgress;
  final double speedMultiplier;
  final Size containerSize;
  final double idleAngle;

  /// Fusion UI
  final double fusionT; // 0..1
  final bool isFusion;
  final bool useSimpleFusion;
  final FactionTheme? theme;
  final bool fromCinematic;

  // FIX 3: Frame counter — replaces particle list identity check.
  // Increment this each update so shouldRepaint can detect real changes
  // without an always-true reference comparison.
  final int frameCount;

  // FIX 2: Cached Paint objects — allocated once on the painter, reused
  // every frame. Eliminates ~3,600 Paint allocs/sec at 60fps × 60 particles.
  final _particlePaint = Paint()..style = PaintingStyle.fill;
  final _glowPaint = Paint()..style = PaintingStyle.fill;
  final _corePaint = Paint()..style = PaintingStyle.fill;
  final _sparkGlowPaint = Paint()..style = PaintingStyle.fill;
  final _sparkCorePaint = Paint()..style = PaintingStyle.fill;
  final _strokePaint = Paint()..style = PaintingStyle.stroke;

  AlchemyBrewingPainter({
    required this.particles,
    required this.sparks,
    required this.config1,
    this.config2,
    required this.animationProgress,
    required this.speedMultiplier,
    required this.containerSize,
    this.fusionT = 0.0,
    this.isFusion = false,
    this.idleAngle = 0.0,
    this.useSimpleFusion = false,
    this.theme,
    this.fromCinematic = false,
    this.frameCount = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw reaction sparks — iterate ring buffer, skip dead slots
    for (final spark in sparks) {
      if (spark.life <= 0) continue;
      _sparkGlowPaint.color = spark.color.withValues(alpha: spark.life * 0.15);
      _sparkCorePaint.color = spark.color.withValues(alpha: spark.life * 0.8);
      canvas.drawCircle(spark.position, spark.size * 2.5, _sparkGlowPaint);
      canvas.drawCircle(spark.position, spark.size, _sparkCorePaint);
    }

    // Draw main particles
    for (final particle in particles) {
      _drawParticle(canvas, particle);
    }

    // Energy field when brewing is intense (disabled during fusion to declutter)
    if (speedMultiplier > 2.0 && !isFusion) {
      _drawEnergyField(canvas, size);
    }

    // Fusion visuals
    if (isFusion) {
      if (useSimpleFusion) {
        _drawSimpleFusion(canvas, size);
      } else {
        if (fusionT < 1.0) {
          _drawFusion(canvas, size, fusionT);
        } else {
          _drawFusion(canvas, size, 1.0);
        }
      }
    }
  }

  void _drawSimpleFusion(Canvas canvas, Size size) {
    double t = 1.0;
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor = theme?.text ?? Colors.black;

    double smoothstep(double x) => x <= 0
        ? 0
        : x >= 1
        ? 1
        : x * x * (3 - 2 * x);

    final steadySpin = idleAngle;
    final breathe = 0.5 + 0.5 * sin(idleAngle * 3 / (2 * pi));
    final pulse = 0.7 + 0.3 * sin(idleAngle * 4 / (2 * pi));
    final handoff = smoothstep(((t - 0.88) / 0.12).clamp(0.0, 1.0));

    final b = ((t - 0.35) / 0.5).clamp(0.0, 1.0);
    if (b > 0 || t >= 1.0) {
      final liveB = max(b, 0.0001);

      canvas.save();
      canvas.translate(center.dx, center.dy);

      final liveRot1 = 2 * pi * liveB;
      final liveRot2 = -2 * pi * liveB * 1.3;
      final rot1 = t >= 1.0
          ? steadySpin
          : (1 - handoff) * liveRot1 + handoff * steadySpin;
      final rot2 = t >= 1.0
          ? -steadySpin * 1.1
          : (1 - handoff) * liveRot2 + handoff * (-steadySpin * 1.1);

      _drawSacredGeometry(
        canvas,
        Size(500, 500),
        baseColor,
        rot1,
        rot2,
        liveB,
        breathe,
        pulse,
        t >= 1.0,
        useFlower: false,
      );

      canvas.restore();
    }
  }

  void _drawEnergyField(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.5;

    final gradient = RadialGradient(
      colors: [
        _blendColors(
          config1.colors.first,
          config2?.colors.first ?? config1.colors.first,
        ).withValues(alpha: 0.3),
        Colors.transparent,
      ],
    );

    _glowPaint.shader = gradient.createShader(
      Rect.fromCircle(center: center, radius: maxRadius),
    );
    canvas.drawCircle(center, maxRadius, _glowPaint);
    _glowPaint.shader = null;
  }

  void _drawParticle(Canvas canvas, AlchemyParticle particle) {
    // Use pre-baked color — no withValues() alloc here
    _particlePaint.color = particle.drawnColor;

    final config = particle.elementType == 'parentA'
        ? config1
        : (config2 ?? config1);

    // Circle fast-path: skip save/translate/rotate/restore entirely.
    // drawCircle accepts a world-space center directly and circles are
    // rotationally symmetric so rotation is irrelevant. Covers fire, water,
    // air, steam, lava, mud, dust, poison, spirit, dark, blood — the
    // majority of real element combinations.
    if (config.shape == ParticleShape.circle) {
      canvas.drawCircle(particle.position, particle.size, _particlePaint);
      return;
    }

    // Non-circle shapes need a local transform for rotation + positioning
    canvas.save();
    canvas.translate(particle.position.dx, particle.position.dy);
    canvas.rotate(particle.rotation);

    switch (config.shape) {
      case ParticleShape.circle:
        break; // unreachable — handled above
      case ParticleShape.square:
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size * 2,
            height: particle.size * 2,
          ),
          _particlePaint,
        );
        break;
      case ParticleShape.diamond:
        _drawDiamond(canvas, _particlePaint, particle.size);
        break;
      case ParticleShape.star:
        _drawStar(canvas, _particlePaint, particle.size);
        break;
      case ParticleShape.leaf:
        _drawLeaf(canvas, _particlePaint, particle.size);
        break;
      case ParticleShape.shard:
        _drawShard(canvas, _particlePaint, particle.size);
        break;
    }

    canvas.restore();
  }

  void _drawDiamond(Canvas canvas, Paint paint, double size) {
    final path = Path()
      ..moveTo(0, -size)
      ..lineTo(size, 0)
      ..lineTo(0, size)
      ..lineTo(-size, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    const points = 5;
    final angle = (pi * 2) / points;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? size : size / 2;
      final x = r * cos(i * angle / 2 - pi / 2);
      final y = r * sin(i * angle / 2 - pi / 2);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawLeaf(Canvas canvas, Paint paint, double size) {
    final path = Path()
      ..moveTo(0, -size)
      ..quadraticBezierTo(size * 0.7, -size * 0.3, size, size)
      ..quadraticBezierTo(0, size * 0.7, 0, -size)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawShard(Canvas canvas, Paint paint, double size) {
    final path = Path()
      ..moveTo(0, -size)
      ..lineTo(size * 0.3, size * 0.5)
      ..lineTo(-size * 0.3, size)
      ..lineTo(-size * 0.3, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawFusion(Canvas canvas, Size size, double t) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor = _blendColors(
      config1.colors.first,
      (config2 ?? config1).colors.first,
    );

    double easeOut(double x) => 1 - pow(1 - x, 2).toDouble();
    double smoothstep(double x) => x <= 0
        ? 0
        : x >= 1
        ? 1
        : x * x * (3 - 2 * x);

    final steadySpin = idleAngle;
    final breathe = 0.5 + 0.5 * sin(idleAngle * 3 / (2 * pi));
    final pulse = 0.7 + 0.3 * sin(idleAngle * 4 / (2 * pi));
    final handoff = smoothstep(((t - 0.88) / 0.12).clamp(0.0, 1.0));

    final a = (t / 0.4).clamp(0.0, 1.0);
    if (a > 0 || t >= 1.0) {
      _drawTransmutationCircles(
        canvas,
        center,
        size,
        baseColor,
        a > 0 ? easeOut(a) : 1.0,
        breathe,
        steadySpin,
      );
    }

    final b = ((t - 0.35) / 0.5).clamp(0.0, 1.0);
    if (b > 0 || t >= 1.0) {
      final liveB = max(b, 0.0001);

      canvas.save();
      canvas.translate(center.dx, center.dy);

      final liveRot1 = 2 * pi * liveB;
      final liveRot2 = -2 * pi * liveB * 1.3;
      final rot1 = t >= 1.0
          ? steadySpin
          : (1 - handoff) * liveRot1 + handoff * steadySpin;
      final rot2 = t >= 1.0
          ? -steadySpin * 1.1
          : (1 - handoff) * liveRot2 + handoff * (-steadySpin * 1.1);

      _drawSacredGeometry(
        canvas,
        size,
        baseColor,
        rot1,
        rot2,
        liveB,
        breathe,
        pulse,
        t >= 1.0,
      );

      canvas.restore();
    }

    final c = ((t - 0.75) / 0.25).clamp(0.0, 1.0);
    if (c > 0 || t >= 1.0) {
      _drawAlchemicalCore(
        canvas,
        center,
        size,
        baseColor,
        c,
        breathe,
        pulse,
        steadySpin,
        t >= 1.0,
      );
    }
  }

  void _drawTransmutationCircles(
    Canvas canvas,
    Offset center,
    Size size,
    Color baseColor,
    double progress,
    double breathe,
    double rotation,
  ) {
    final maxRadius = min(size.width, size.height) * 0.45;

    // No MaskFilter.blur — blur requires a full rasterize+convolve pass on
    // the GPU and spikes frame time on mid-range devices. Simple stroked
    // circles at varying opacity are visually close and essentially free.
    for (int ring = 0; ring < 3; ring++) {
      final radius = maxRadius * (0.4 + ring * 0.2) * progress;
      // Outer rings slightly more transparent for a natural fade-out feel
      final alpha = (0.35 - ring * 0.08) * progress;

      _strokePaint
        ..strokeWidth = 1.5 - ring * 0.3
        ..color = baseColor.withValues(alpha: alpha.clamp(0.0, 1.0));

      canvas.drawCircle(center, radius, _strokePaint);
    }
  }

  void _drawSacredGeometry(
    Canvas canvas,
    Size size,
    Color baseColor,
    double rot1,
    double rot2,
    double progress,
    double breathe,
    double pulse,
    bool isIdle, {
    bool useFlower = true,
  }) {
    final r1 = min(size.width, size.height) * 0.16;
    final r2 = min(size.width, size.height) * 0.10;

    canvas.save();
    canvas.rotate(rot1);

    if (useFlower) {
      _strokePaint
        ..strokeWidth = 0.8
        ..color = baseColor.withValues(
          alpha: 0.3 * progress * (isIdle ? pulse : 1.0),
        );

      for (int i = 0; i < 6; i++) {
        final angle = i * pi / 3;
        final offset = Offset(cos(angle) * r1 * 0.5, sin(angle) * r1 * 0.5);
        canvas.drawCircle(offset, r1 * 0.5, _strokePaint);
      }
    }
    canvas.restore();

    canvas.save();
    canvas.rotate(rot2);

    _strokePaint
      ..strokeWidth = 0.5
      ..color = baseColor.withValues(
        alpha: 0.25 * progress * (isIdle ? breathe : 1.0),
      );

    final points = <Offset>[];
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      points.add(Offset(cos(angle) * r2, sin(angle) * r2));
    }

    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        canvas.drawLine(points[i], points[j], _strokePaint);
      }
    }

    canvas.restore();
  }

  void _drawAlchemicalCore(
    Canvas canvas,
    Offset center,
    Size size,
    Color baseColor,
    double progress,
    double breathe,
    double pulse,
    double rotation,
    bool isIdle,
  ) {
    final maxRadius = min(size.width, size.height) * 0.15;

    double coreExpansionProgress;
    double fadeMultiplier;

    if (!isIdle) {
      if (progress < 0.5) {
        coreExpansionProgress = easeOut(progress * 2);
        fadeMultiplier = 1.0;
      } else {
        coreExpansionProgress = easeOut(1.0 - (progress - 0.5) * 2);
        fadeMultiplier = progress < 0.8 ? 1.0 : 1.0 - ((progress - 0.8) / 0.2);
      }
    } else {
      coreExpansionProgress = 0.0;
      fadeMultiplier = 1.0;
    }

    const baseIdleRadius = 18.0;
    const maxExpansion = 25.0;
    final coreRadius =
        baseIdleRadius +
        (maxExpansion * coreExpansionProgress) +
        (isIdle ? 4 * breathe : 0);

    final outerGlowOpacity = isIdle
        ? 0.1 * pulse
        : 0.15 * coreExpansionProgress * fadeMultiplier;

    _glowPaint.shader = RadialGradient(
      colors: [
        baseColor.withValues(alpha: outerGlowOpacity),
        baseColor.withValues(alpha: outerGlowOpacity * 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: coreRadius * 3));

    canvas.drawCircle(center, coreRadius * 3, _glowPaint);

    final coreOpacity = isIdle
        ? 0.3 + 0.2 * breathe
        : 0.3 + 0.5 * coreExpansionProgress * fadeMultiplier;

    _corePaint.shader = RadialGradient(
      colors: [
        baseColor.withValues(alpha: coreOpacity),
        baseColor.withValues(alpha: coreOpacity * 0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.7, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: coreRadius));

    canvas.drawCircle(center, coreRadius, _corePaint);

    // Clear shaders
    _glowPaint.shader = null;
    _corePaint.shader = null;

    if (!isIdle && coreExpansionProgress > 0.5) {
      final rayAlpha = (coreExpansionProgress - 0.5) * 2;
      _strokePaint
        ..strokeWidth = 0.5
        ..color = baseColor.withValues(alpha: 0.2 * rayAlpha * fadeMultiplier);

      for (int i = 0; i < 8; i++) {
        final angle = i * pi / 4 + rotation * 0.2;
        final innerR = coreRadius * 0.8;
        final outerR = coreRadius + (maxRadius * coreExpansionProgress * 0.3);

        canvas.drawLine(
          center + Offset(cos(angle) * innerR, sin(angle) * innerR),
          center + Offset(cos(angle) * outerR, sin(angle) * outerR),
          _strokePaint,
        );
      }
    }

    if (isIdle) {
      for (int i = 0; i < 3; i++) {
        final orbitAngle = rotation * (1 + i * 0.3) + (i * 2 * pi / 3);
        final orbitRadius = coreRadius * 1.5 + i * 5;
        final particlePos =
            center +
            Offset(
              cos(orbitAngle) * orbitRadius,
              sin(orbitAngle) * orbitRadius,
            );

        _particlePaint.color = baseColor.withValues(alpha: 0.6 * pulse);
        canvas.drawCircle(particlePos, 3, _particlePaint);
      }
    }
  }

  double easeOut(double x) => 1 - pow(1 - x, 2).toDouble();

  Color _blendColors(Color c1, Color c2) {
    return Color.fromARGB(
      255,
      ((c1.r + c2.r) * 127.5).round(),
      ((c1.g + c2.g) * 127.5).round(),
      ((c1.b + c2.b) * 127.5).round(),
    );
  }

  // FIX 3: shouldRepaint now uses frameCount instead of particle list identity.
  // The old check (particles != oldDelegate.particles) was always true because
  // we mutate the same list in-place — every frame triggered a repaint even
  // when no particles had moved. frameCount is incremented in _updateParticles,
  // so repaints only happen when state has actually changed.
  @override
  bool shouldRepaint(AlchemyBrewingPainter oldDelegate) {
    return frameCount != oldDelegate.frameCount ||
        fusionT != oldDelegate.fusionT ||
        idleAngle != oldDelegate.idleAngle;
  }
}

/// Main widget for alchemy brewing particle system
class AlchemyBrewingParticleSystem extends StatefulWidget {
  final String parentATypeId;
  final String? parentBTypeId;
  final int particleCount;
  final double speedMultiplier;

  /// When true, slows particles and plays a one-shot fusion glyph animation.
  final bool fusion;

  final bool useSimpleFusion;
  final FactionTheme? theme;
  final bool fromCinematic;

  const AlchemyBrewingParticleSystem({
    super.key,
    required this.parentATypeId,
    this.parentBTypeId,
    this.particleCount = 60,
    this.speedMultiplier = 1.0,
    this.fusion = false,
    this.useSimpleFusion = false,
    this.theme,
    this.fromCinematic = false,
  });

  @override
  State<AlchemyBrewingParticleSystem> createState() =>
      _AlchemyBrewingParticleSystemState();
}

class _AlchemyBrewingParticleSystemState
    extends State<AlchemyBrewingParticleSystem>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _fusionCtrl;
  bool _fusionPlayed = false;

  // FIX 1: Object pool — pre-allocate the maximum number of particles once.
  // _updateParticles resets fields in-place instead of calling _createParticle,
  // eliminating allocation pressure and GC jank on mid-range devices.
  static const _maxPoolSize = 72;
  late final List<AlchemyParticle> _pool;

  late List<AlchemyParticle> _particles;
  // Ring buffer for reaction sparks — fixed capacity, no list reallocation
  // or element shifting. Head advances on write; life==0 means slot is empty.
  static const _sparkCapacity = 54; // 18 sparks x 3 per event
  final _sparkBuf = List<ReactionSpark>.generate(
    54,
    (_) => ReactionSpark(
      position: Offset.zero,
      color: Colors.transparent,
      size: 0,
      life: 0,
    ),
  );
  int _sparkHead = 0;
  int _sparkCount = 0;
  late ElementConfig _configA;
  ElementConfig? _configB;
  final Random _random = Random();

  Size _lastSize = Size.zero;
  bool _hasInitializedParticles = false;

  // FIX 3: Frame counter incremented each update, passed to painter.
  int _frameCount = 0;

  // Pre-separated parentA index list for O(1) spark candidate lookup.
  final List<int> _parentAIndices = [];

  void _onFusionStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        mounted &&
        _hasInitializedParticles) {
      setState(() {
        _initParticles();
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _configA =
        ElementalConfigs.getConfig(widget.parentATypeId) ??
        ElementalConfigs.fire;
    _configB = widget.parentBTypeId != null
        ? ElementalConfigs.getConfig(widget.parentBTypeId!)
        : null;

    // FIX 1: Pre-allocate pool with dummy values — fields will be
    // overwritten by _resetParticle before any particle is used.
    _pool = List.generate(
      _maxPoolSize,
      (_) => AlchemyParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        size: 4,
        color: Colors.transparent,
        opacity: 0,
        elementType: 'parentA',
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fusionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addStatusListener(_onFusionStatusChanged);

    _particles = [];

    if (widget.fusion) {
      _fusionPlayed = true;
      _fusionCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AlchemyBrewingParticleSystem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.fusion && !_fusionPlayed) {
      _fusionPlayed = true;
      _fusionCtrl.forward(from: 0.0);
    }

    if (oldWidget.parentATypeId != widget.parentATypeId ||
        oldWidget.parentBTypeId != widget.parentBTypeId) {
      _configA =
          ElementalConfigs.getConfig(widget.parentATypeId) ??
          ElementalConfigs.fire;
      _configB = widget.parentBTypeId != null
          ? ElementalConfigs.getConfig(widget.parentBTypeId!)
          : null;

      if (_hasInitializedParticles) {
        _initParticles();
      }
    }
  }

  void _initParticles() {
    _particles.clear();
    _parentAIndices.clear();

    if (widget.fusion && _fusionCtrl.value >= 1.0) {
      // Idle/fusion: small set of orbital particles
      _particles.add(_createIdleParticle(_configA, 'parentA', isMain: true));
      if (_configB != null) {
        _particles.add(_createIdleParticle(_configB!, 'parentB', isMain: true));
      }

      for (int i = 0; i < 5; i++) {
        _particles.add(_createIdleParticle(_configA, 'parentA', isMain: false));
      }

      if (_configB != null) {
        for (int i = 0; i < 5; i++) {
          _particles.add(
            _createIdleParticle(_configB!, 'parentB', isMain: false),
          );
        }
      }

      // No spark candidates during idle fusion
      return;
    }

    // Normal brewing: pull from pool up to particleCount
    final halfCount = widget.particleCount ~/ 2;
    final totalCount = widget.particleCount.clamp(0, _maxPoolSize);

    for (int i = 0; i < halfCount && i < totalCount; i++) {
      final p = _pool[i];
      _resetParticle(p, _configA, 'parentA');
      _particles.add(p);
      _parentAIndices.add(_particles.length - 1);
    }

    if (_configB != null) {
      for (int i = halfCount; i < totalCount; i++) {
        final p = _pool[i];
        _resetParticle(p, _configB!, 'parentB');
        _particles.add(p);
      }
    }
  }

  // FIX 1: Reset an existing particle from the pool in-place.
  // No allocation — just overwrites the fields.
  void _resetParticle(
    AlchemyParticle p,
    ElementConfig config,
    String elementType,
  ) {
    final size =
        config.minSize +
        _random.nextDouble() * (config.maxSize - config.minSize);
    final color = config.colors[_random.nextInt(config.colors.length)];

    final startFromEdge = _random.nextBool();
    Offset position;

    if (startFromEdge) {
      final offscreenMargin = config.maxSize * 2;
      final edge = _random.nextInt(4);
      switch (edge) {
        case 0:
          position = Offset(
            _random.nextDouble() * _lastSize.width,
            -offscreenMargin,
          );
          break;
        case 1:
          position = Offset(
            _lastSize.width + offscreenMargin,
            _random.nextDouble() * _lastSize.height,
          );
          break;
        case 2:
          position = Offset(
            _random.nextDouble() * _lastSize.width,
            _lastSize.height + offscreenMargin,
          );
          break;
        default:
          position = Offset(
            -offscreenMargin,
            _random.nextDouble() * _lastSize.height,
          );
      }
    } else {
      position = Offset(
        _random.nextDouble() * _lastSize.width,
        _random.nextDouble() * _lastSize.height,
      );
    }

    final center = Offset(_lastSize.width / 2, _lastSize.height / 2);
    final toCenter = center - position;
    final dx = toCenter.dx;
    final dy = toCenter.dy;
    final dist2 = dx * dx + dy * dy;

    Offset velocity;
    if (dist2 > 0) {
      final invDist = 1.0 / sqrt(dist2);
      final speed =
          config.minSpeed +
          _random.nextDouble() * (config.maxSpeed - config.minSpeed);

      final angleVariation = (_random.nextDouble() - 0.5) * 0.8;
      final cosA = cos(angleVariation);
      final sinA = sin(angleVariation);
      final nx = dx * invDist;
      final ny = dy * invDist;
      velocity = Offset(
        (nx * cosA - ny * sinA) * speed,
        (nx * sinA + ny * cosA) * speed,
      );
    } else {
      velocity = _getInitialVelocity(config);
    }

    p.position = position;
    p.velocity = velocity;
    p.size = size;
    p.color = color;
    p.opacity = 0.5 + _random.nextDouble() * 0.5;
    p.rotation = _random.nextDouble() * pi * 2;
    p.rotationSpeed = (_random.nextDouble() - 0.5) * 0.05;
    p.life = 0.5 + _random.nextDouble() * 0.5;
    p.energy = _random.nextDouble();
    p.elementType = elementType;
    p.bakeColor();
  }

  AlchemyParticle _createIdleParticle(
    ElementConfig config,
    String elementType, {
    required bool isMain,
  }) {
    final center = Offset(_lastSize.width / 2, _lastSize.height / 2);

    if (isMain) {
      final isParentA = elementType == 'parentA';
      final angle = isParentA ? 0.0 : pi;
      const orbitRadius = 40.0;

      final position =
          center + Offset(cos(angle) * orbitRadius, sin(angle) * orbitRadius);
      final velocity = Offset(-sin(angle) * 0.3, cos(angle) * 0.3);

      return AlchemyParticle(
        position: position,
        velocity: velocity,
        size: config.maxSize * 1.5,
        color: config.colors.first,
        opacity: 0.8,
        rotation: 0,
        rotationSpeed: 0.02,
        life: 1.0,
        energy: 1.0,
        elementType: elementType,
      );
    } else {
      final randomAngle = _random.nextDouble() * 2 * pi;
      final randomRadius = 20.0 + _random.nextDouble() * 50.0;

      final position =
          center +
          Offset(
            cos(randomAngle) * randomRadius,
            sin(randomAngle) * randomRadius,
          );

      final driftAngle = _random.nextDouble() * 2 * pi;
      final driftSpeed = 0.1 + _random.nextDouble() * 0.2;
      final velocity = Offset(
        cos(driftAngle) * driftSpeed,
        sin(driftAngle) * driftSpeed,
      );

      return AlchemyParticle(
        position: position,
        velocity: velocity,
        size:
            config.minSize +
            _random.nextDouble() * (config.maxSize - config.minSize),
        color: config.colors[_random.nextInt(config.colors.length)],
        opacity: 0.4 + _random.nextDouble() * 0.4,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.03,
        life: 1.0,
        energy: 1.0,
        elementType: elementType,
      );
    }
  }

  Offset _getInitialVelocity(ElementConfig config) {
    final speed =
        config.minSpeed +
        _random.nextDouble() * (config.maxSpeed - config.minSpeed);

    switch (config.movement) {
      case ParticleMovementPattern.rising:
        return Offset((_random.nextDouble() - 0.5) * 0.5, -speed);
      case ParticleMovementPattern.falling:
        return Offset((_random.nextDouble() - 0.5) * 0.5, speed);
      case ParticleMovementPattern.flowing:
        return Offset((_random.nextDouble() - 0.5) * speed, speed * 0.3);
      case ParticleMovementPattern.swirling:
        final angle = _random.nextDouble() * pi * 2;
        return Offset(cos(angle) * speed, sin(angle) * speed);
      case ParticleMovementPattern.crackling:
        return Offset(
          (_random.nextDouble() - 0.5) * speed * 2,
          (_random.nextDouble() - 0.5) * speed * 2,
        );
      case ParticleMovementPattern.floating:
        return Offset((_random.nextDouble() - 0.5) * speed * 0.5, -speed * 0.3);
      case ParticleMovementPattern.growing:
        return Offset((_random.nextDouble() - 0.5) * 0.3, -speed * 0.8);
      case ParticleMovementPattern.pulsing:
        final angle = _random.nextDouble() * pi * 2;
        return Offset(cos(angle) * speed * 0.5, sin(angle) * speed * 0.5);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _fusionCtrl.removeStatusListener(_onFusionStatusChanged);
    _fusionCtrl.dispose();
    super.dispose();
  }

  // Idle angle accumulated in _updateParticles to stay continuous across
  // controller cycles. The controller repeats 0→1 every 3s; each tick we
  // add the delta so the angle never jumps back to 0 at the wrap boundary.
  double _idleAngle = 0.0;
  double _lastControllerValue = 0.0;

  double get _continuousIdleAngle => _idleAngle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newSize = Size(constraints.maxWidth, constraints.maxHeight);

        if (newSize != Size.zero && newSize != _lastSize) {
          _lastSize = newSize;
          if (!_hasInitializedParticles) {
            _hasInitializedParticles = true;
            _initParticles();
          }
        }

        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _fusionCtrl]),
          builder: (context, child) {
            if (_hasInitializedParticles) {
              _updateParticles();
            }

            return CustomPaint(
              painter: AlchemyBrewingPainter(
                particles: _particles,
                sparks: _sparkBuf,
                config1: _configA,
                config2: _configB,
                animationProgress: _controller.value,
                speedMultiplier: widget.speedMultiplier,
                containerSize: _lastSize,
                fusionT: _fusionCtrl.value,
                isFusion: _fusionPlayed,
                useSimpleFusion: widget.useSimpleFusion,
                idleAngle: _continuousIdleAngle,
                theme: widget.theme,
                fromCinematic: widget.fromCinematic,
                frameCount: _frameCount,
              ),
              size: _lastSize,
            );
          },
        );
      },
    );
  }

  void _updateParticles() {
    // Accumulate idle angle from controller delta so it stays continuous
    // across repeat cycles. The controller goes 0→1 then wraps; reading
    // .value directly would cause a jump to 0 each cycle. Instead we
    // compute how much it advanced this tick and add that to a running total.
    final currentValue = _controller.value;
    double delta = currentValue - _lastControllerValue;
    // Handle the wrap: if the controller repeated, delta will be large and
    // negative. Treat it as the small positive remainder instead.
    if (delta < 0) delta += 1.0;
    // Scale: controller period is 3s, one full rotation every 24s → factor 3/24
    _idleAngle += delta * 2 * pi * (3.0 / 24.0);
    _lastControllerValue = currentValue;

    final width = _lastSize.width;
    final height = _lastSize.height;
    final center = Offset(width / 2, height / 2);

    // IDLE MODE
    if (widget.fusion && _fusionCtrl.value >= 1.0) {
      for (int i = 0; i < _particles.length; i++) {
        final p = _particles[i];
        final toCenter = center - p.position;
        final distance = toCenter.distance;

        if (i < 2) {
          if (distance > 0) {
            final angle = atan2(p.velocity.dy, p.velocity.dx);
            final newAngle = angle + 0.02;
            p.velocity = Offset(cos(newAngle) * 0.3, sin(newAngle) * 0.3);
            p.position += p.velocity;
            p.rotation += p.rotationSpeed;
          }
        } else {
          p.position += p.velocity;
          p.rotation += p.rotationSpeed;

          if (distance > 70) {
            p.velocity += Offset(
              (toCenter.dx / distance) * 0.01,
              (toCenter.dy / distance) * 0.01,
            );
          }

          p.velocity *= 0.99;

          if (distance > 90) {
            final wrapAngle = _random.nextDouble() * 2 * pi;
            p.position =
                center + Offset(cos(wrapAngle) * 30, sin(wrapAngle) * 30);
          }
        }
      }
      _frameCount++;
      return;
    }

    // FUSION TRANSITION
    if (widget.fusion && _fusionCtrl.value < 1.0) {
      const fadeStart = 0.5;
      if (_fusionCtrl.value > fadeStart) {
        final fadeProgress =
            (_fusionCtrl.value - fadeStart) / (1.0 - fadeStart);

        final targetParticleCount =
            2 + ((1.0 - fadeProgress) * (_particles.length - 2)).round();

        for (int i = 0; i < _particles.length; i++) {
          final p = _particles[i];

          p.opacity *= (1.0 - fadeProgress * 0.1);
          p.bakeColor();

          final toCenter = center - p.position;
          final distance = toCenter.distance;
          if (distance > 0) {
            p.velocity += Offset(
              (toCenter.dx / distance) * 0.3 * fadeProgress,
              (toCenter.dy / distance) * 0.3 * fadeProgress,
            );
          }

          p.position += p.velocity * 0.5;
          p.rotation += p.rotationSpeed;

          if (i >= targetParticleCount) {
            p.life = 0;
          }
        }

        _particles.removeWhere((p) => p.life <= 0);
        _frameCount++;
        return;
      }
    }

    // BREWING MODE

    // Decay sparks in ring buffer — no shifting, just decrement life
    for (int i = 0; i < _sparkCapacity; i++) {
      final s = _sparkBuf[i];
      if (s.life > 0) {
        s.life -= 0.03;
        if (s.life < 0) s.life = 0;
      }
    }

    final baseMult = widget.speedMultiplier;
    final fusionDamp = widget.fusion ? 0.35 : 1.0;
    final speedMult = baseMult * fusionDamp;

    // FIX 2 (trig hoist): Compute swirl rotation constants once outside the
    // loop. The old code called atan2+cos+sin per particle per frame.
    // A 2D rotation matrix only needs cos/sin of the delta angle — computed
    // once here, then applied with pure multiplies inside the loop.
    final swirlDelta = (widget.fusion ? 0.01 : 0.03) * speedMult;
    final swirlCos = cos(swirlDelta);
    final swirlSin = sin(swirlDelta);

    final pullStrength = widget.fusion ? 0.12 : 0.02;
    final rotSpeedMult = speedMult; // named for clarity

    final boundLeft = -30.0;
    final boundRight = width + 30.0;
    final boundTop = -30.0;
    final boundBottom = height + 30.0;

    final particleCount = _particles.length;

    for (int i = 0; i < particleCount; i++) {
      final p = _particles[i];
      final config = p.elementType == 'parentA'
          ? _configA
          : (_configB ?? _configA);

      p.position += p.velocity * speedMult;
      p.rotation += p.rotationSpeed * rotSpeedMult;

      // Center attraction — use distance-squared to avoid sqrt when possible
      final toCenterDx = center.dx - p.position.dx;
      final toCenterDy = center.dy - p.position.dy;
      final dist2 = toCenterDx * toCenterDx + toCenterDy * toCenterDy;

      if (dist2 > 36) {
        // FIX 2: One sqrt, only when the pull is actually needed
        final invDist = 1.0 / sqrt(dist2);
        p.velocity += Offset(
          toCenterDx * invDist * pullStrength,
          toCenterDy * invDist * pullStrength,
        );
      }

      // FIX 2: Apply swirl via rotation matrix — zero trig calls per particle
      final vx = p.velocity.dx;
      final vy = p.velocity.dy;
      p.velocity = Offset(
        vx * swirlCos - vy * swirlSin,
        vx * swirlSin + vy * swirlCos,
      );

      if (config.movement == ParticleMovementPattern.pulsing) {
        final amp = widget.fusion ? 0.4 : 0.7;
        p.opacity = 0.3 + amp * ((sin(_controller.value * pi * 2) + 1) / 2);
        p.bakeColor();
      }

      p.life -= 0.002 * speedMult;

      if (p.life <= 0 ||
          p.position.dx < boundLeft ||
          p.position.dx > boundRight ||
          p.position.dy < boundTop ||
          p.position.dy > boundBottom) {
        // FIX 1: Reset pool particle in-place instead of allocating new one
        _resetParticle(p, config, p.elementType);
        if (widget.fusion) {
          p.position = Offset(
            _random.nextDouble() * width,
            _random.nextBool() ? -20 : height + 20,
          );
        }
      }
    }

    // Spark generation — uses pre-separated parentA index list for O(1) lookup
    if (_configB != null && !widget.fusion && _parentAIndices.isNotEmpty) {
      const checksPerFrame = 3;
      final progressEstimate = ((speedMult - 0.1) / (6.0 - 0.1)).clamp(
        0.0,
        1.0,
      );
      final progressSquared = progressEstimate * progressEstimate;
      final sparkChance = 0.015 + (progressSquared * 0.085);
      final threshold = sparkChance * speedMult;

      for (int check = 0; check < checksPerFrame; check++) {
        if (_random.nextDouble() < threshold) {
          final idx = _parentAIndices[_random.nextInt(_parentAIndices.length)];
          if (idx < _particles.length) {
            final p = _particles[idx];
            final offset = Offset(
              (_random.nextDouble() - 0.5) * 30,
              (_random.nextDouble() - 0.5) * 30,
            );
            _createReactionSpark(
              p.position + offset,
              _configA.colors[_random.nextInt(_configA.colors.length)],
              _configB!.colors[_random.nextInt(_configB!.colors.length)],
            );
          }
        }
      }
    }

    // FIX 3: Tick frame counter so shouldRepaint can detect real changes
    _frameCount++;
  }

  void _createReactionSpark(Offset position, Color color1, Color color2) {
    final blendedColor = Color.fromARGB(
      255,
      ((color1.r + color2.r) * 127.5).round(),
      ((color1.g + color2.g) * 127.5).round(),
      ((color1.b + color2.b) * 127.5).round(),
    );
    // Write into ring buffer slots, overwriting the oldest if full
    for (int i = 0; i < 3; i++) {
      final slot = _sparkBuf[_sparkHead];
      slot.position =
          position +
          Offset(
            (_random.nextDouble() - 0.5) * 5,
            (_random.nextDouble() - 0.5) * 5,
          );
      slot.color = blendedColor;
      slot.size = 2 + _random.nextDouble() * 3;
      slot.life = 1.0;
      _sparkHead = (_sparkHead + 1) % _sparkCapacity;
      if (_sparkCount < _sparkCapacity) _sparkCount++;
    }
  }
}
