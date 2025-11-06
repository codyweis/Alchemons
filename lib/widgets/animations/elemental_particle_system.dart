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
  });
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw reaction sparks
    for (final spark in sparks) {
      final sparkPaint = Paint()
        ..color = spark.color.withOpacity(spark.life)
        ..style = PaintingStyle.fill
        ..maskFilter = fromCinematic
            ? null
            : const MaskFilter.blur(BlurStyle.normal, 5);

      final glowPaint = Paint()
        ..color = spark.color.withOpacity(spark.life * 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(spark.position, spark.size * 2, glowPaint);
      canvas.drawCircle(spark.position, spark.size, sparkPaint);
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
        // Simple geometric fusion
        _drawSimpleFusion(canvas, size);
      } else {
        // Full alchemical fusion animation
        if (fusionT < 1.0) {
          _drawFusion(canvas, size, fusionT);
        } else {
          // Idle state with full glyphs
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

    // Animation timing
    final steadySpin = idleAngle;
    final breathe = 0.5 + 0.5 * sin(idleAngle * 3 / (2 * pi));
    final pulse = 0.7 + 0.3 * sin(idleAngle * 4 / (2 * pi));
    final handoff = smoothstep(((t - 0.88) / 0.12).clamp(0.0, 1.0));

    // ===== PHASE B: 0.35..0.85 — Sacred geometry and energy flows
    final b = ((t - 0.35) / 0.5).clamp(0.0, 1.0);
    if (b > 0 || t >= 1.0) {
      final liveB = max(b, 0.0001);

      canvas.save();
      canvas.translate(center.dx, center.dy);

      // Sacred geometry rotation
      final liveRot1 = 2 * pi * liveB;
      final liveRot2 = -2 * pi * liveB * 1.3;
      final rot1 = t >= 1.0
          ? steadySpin
          : (1 - handoff) * liveRot1 + handoff * steadySpin;
      final rot2 = t >= 1.0
          ? -steadySpin * 1.1
          : (1 - handoff) * liveRot2 + handoff * (-steadySpin * 1.1);

      // Draw sacred geometry layers
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
        ).withOpacity(0.3),
        Colors.transparent,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: maxRadius),
      );

    canvas.drawCircle(center, maxRadius, paint);
  }

  void _drawParticle(Canvas canvas, AlchemyParticle particle) {
    final paint = Paint()
      ..color = particle.color.withOpacity(particle.opacity * particle.life)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(particle.position.dx, particle.position.dy);
    canvas.rotate(particle.rotation);

    final config = particle.elementType == 'parentA'
        ? config1
        : (config2 ?? config1);

    switch (config.shape) {
      case ParticleShape.circle:
        canvas.drawCircle(Offset.zero, particle.size, paint);
        break;
      case ParticleShape.square:
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size * 2,
            height: particle.size * 2,
          ),
          paint,
        );
        break;
      case ParticleShape.diamond:
        _drawDiamond(canvas, paint, particle.size);
        break;
      case ParticleShape.star:
        _drawStar(canvas, paint, particle.size);
        break;
      case ParticleShape.leaf:
        _drawLeaf(canvas, paint, particle.size);
        break;
      case ParticleShape.shard:
        _drawShard(canvas, paint, particle.size);
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

    // Easing functions
    double easeIn(double x) => x * x;
    double easeOut(double x) => 1 - pow(1 - x, 2).toDouble();
    double easeInOut(double x) =>
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2;
    double smoothstep(double x) => x <= 0
        ? 0
        : x >= 1
        ? 1
        : x * x * (3 - 2 * x);

    // Animation timing
    final steadySpin = idleAngle;
    final breathe = 0.5 + 0.5 * sin(idleAngle * 3 / (2 * pi));
    final pulse = 0.7 + 0.3 * sin(idleAngle * 4 / (2 * pi));
    final handoff = smoothstep(((t - 0.88) / 0.12).clamp(0.0, 1.0));

    // ===== PHASE A: 0..0.4 — Transmutation circles with runes
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

    // ===== PHASE B: 0.35..0.85 — Sacred geometry and energy flows
    final b = ((t - 0.35) / 0.5).clamp(0.0, 1.0);
    if (b > 0 || t >= 1.0) {
      final liveB = max(b, 0.0001);

      canvas.save();
      canvas.translate(center.dx, center.dy);

      // Sacred geometry rotation
      final liveRot1 = 2 * pi * liveB;
      final liveRot2 = -2 * pi * liveB * 1.3;
      final rot1 = t >= 1.0
          ? steadySpin
          : (1 - handoff) * liveRot1 + handoff * steadySpin;
      final rot2 = t >= 1.0
          ? -steadySpin * 1.1
          : (1 - handoff) * liveRot2 + handoff * (-steadySpin * 1.1);

      // Draw sacred geometry layers
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

    // ===== PHASE C: 0.75..1.0 — Core manifestation
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

    // Main transmutation circle with notches
    for (int ring = 0; ring < 3; ring++) {
      final radius = maxRadius * (0.4 + ring * 0.2) * progress;

      // Circle with gradient effect
      final gradientPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..shader = RadialGradient(
          colors: [
            baseColor.withOpacity(0.4 * progress),
            baseColor.withOpacity(0.2 * progress),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(center, radius, gradientPaint);
    }
  }

  void _drawAlchemicalSymbol(Canvas canvas, Paint paint, int type) {
    final path = Path();

    switch (type % 4) {
      case 0: // Triangle with line
        path.moveTo(0, -8);
        path.lineTo(-6, 6);
        path.lineTo(6, 6);
        path.close();
        path.moveTo(-8, 0);
        path.lineTo(8, 0);
        break;
      case 1: // Circle with cross
        path.addOval(const Rect.fromLTWH(-6, -6, 12, 12));
        path.moveTo(0, -9);
        path.lineTo(0, 9);
        path.moveTo(-9, 0);
        path.lineTo(9, 0);
        break;
      case 2: // Inverted triangle
        path.moveTo(0, 8);
        path.lineTo(-6, -6);
        path.lineTo(6, -6);
        path.close();
        break;
      case 3: // Diamond
        path.moveTo(0, -8);
        path.lineTo(6, 0);
        path.lineTo(0, 8);
        path.lineTo(-6, 0);
        path.close();
        break;
    }

    canvas.drawPath(path, paint);
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

    // Flower of Life pattern (outer)
    canvas.save();
    canvas.rotate(rot1);

    if (useFlower) {
      final flowerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = baseColor.withOpacity(0.3 * progress * (isIdle ? pulse : 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

      // Draw overlapping circles for flower of life
      for (int i = 0; i < 6; i++) {
        final angle = i * pi / 3;
        final offset = Offset(cos(angle) * r1 * 0.5, sin(angle) * r1 * 0.5);
        canvas.drawCircle(offset, r1 * 0.5, flowerPaint);
      }
    }
    canvas.restore();

    // Metatron's Cube elements (inner)
    canvas.save();
    canvas.rotate(rot2);

    final cubePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = baseColor.withOpacity(
        0.25 * progress * (isIdle ? breathe : 1.0),
      );

    // Draw interconnected lines
    final points = <Offset>[];
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      points.add(Offset(cos(angle) * r2, sin(angle) * r2));
    }

    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        canvas.drawLine(points[i], points[j], cubePaint);
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

    // ========== FUSION ANIMATION CORE ==========
    // Calculate core state based on progress
    double coreExpansionProgress;
    double fadeMultiplier;

    if (!isIdle) {
      // During animation: expand then contract
      if (progress < 0.5) {
        // Expansion phase (0.0 to 0.5)
        coreExpansionProgress = easeOut(progress * 2);
        fadeMultiplier = 1.0;
      } else {
        // Contraction phase (0.5 to 1.0)
        coreExpansionProgress = easeOut(1.0 - (progress - 0.5) * 2);
        // Start fading during final 20% of contraction
        fadeMultiplier = progress < 0.8 ? 1.0 : 1.0 - ((progress - 0.8) / 0.2);
      }
    } else {
      // Idle state - use minimal expansion with breathing
      coreExpansionProgress = 0.0;
      fadeMultiplier = 1.0;
    }

    // Core parameters
    final baseIdleRadius = 18.0;
    final maxExpansion = 25.0;
    final coreRadius =
        baseIdleRadius +
        (maxExpansion * coreExpansionProgress) +
        (isIdle ? 4 * breathe : 0);

    // Always draw the core (whether animating or idle)

    // OUTER GLOW
    final outerGlowOpacity = isIdle
        ? 0.1 *
              pulse // Subtle pulsing in idle
        : 0.15 * coreExpansionProgress * fadeMultiplier;

    final outerGlow = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          baseColor.withOpacity(outerGlowOpacity),
          baseColor.withOpacity(outerGlowOpacity * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius * 3));

    canvas.drawCircle(center, coreRadius * 3, outerGlow);

    // INNER CORE
    final coreOpacity = isIdle
        ? 0.3 +
              0.2 *
                  breathe // Breathing effect in idle
        : 0.3 + 0.5 * coreExpansionProgress * fadeMultiplier;

    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          baseColor.withOpacity(coreOpacity),
          baseColor.withOpacity(coreOpacity * 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));

    canvas.drawCircle(center, coreRadius, corePaint);

    // Energy rays (only during expansion, not in idle)
    if (!isIdle && coreExpansionProgress > 0.5) {
      final rayAlpha = (coreExpansionProgress - 0.5) * 2;
      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = baseColor.withOpacity(0.2 * rayAlpha * fadeMultiplier);

      for (int i = 0; i < 8; i++) {
        final angle = i * pi / 4 + rotation * 0.2;
        final innerR = coreRadius * 0.8;
        final outerR = coreRadius + (maxRadius * coreExpansionProgress * 0.3);

        canvas.drawLine(
          center + Offset(cos(angle) * innerR, sin(angle) * innerR),
          center + Offset(cos(angle) * outerR, sin(angle) * outerR),
          rayPaint,
        );
      }
    }

    // Orbiting particles (only in idle state)
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

        final particlePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = baseColor.withOpacity(0.6 * pulse);

        canvas.drawCircle(particlePos, 3, particlePaint);
      }
    }
  }

  void _drawFloatingSymbols(
    Canvas canvas,
    Offset center,
    Size size,
    Color baseColor,
    double rotation,
    double breathe,
    double progress,
  ) {
    final maxRadius = min(size.width, size.height) * 0.35;

    final symbolPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = baseColor.withOpacity(0.2 * progress * breathe)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Floating alchemical symbols
    for (int i = 0; i < 4; i++) {
      final angle = (i * pi / 2) + rotation * 0.2;
      final floatRadius = maxRadius * (0.8 + 0.1 * sin(rotation * 2 + i));
      final symbolPos =
          center + Offset(cos(angle) * floatRadius, sin(angle) * floatRadius);

      canvas.save();
      canvas.translate(symbolPos.dx, symbolPos.dy);
      canvas.rotate(rotation * 0.5 + i * pi / 4);
      canvas.scale(0.7 + 0.3 * breathe);

      _drawAlchemicalSymbol(canvas, symbolPaint, i);

      canvas.restore();
    }
  }

  double easeOut(double x) => 1 - pow(1 - x, 2).toDouble();

  Color _blendColors(Color c1, Color c2) {
    return Color.fromARGB(
      255,
      ((c1.red + c2.red) / 2).round(),
      ((c1.green + c2.green) / 2).round(),
      ((c1.blue + c2.blue) / 2).round(),
    );
  }

  @override
  bool shouldRepaint(AlchemyBrewingPainter oldDelegate) {
    return particles != oldDelegate.particles ||
        fusionT != oldDelegate.fusionT ||
        idleAngle != oldDelegate.idleAngle ||
        speedMultiplier != oldDelegate.speedMultiplier;
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
  late AnimationController _fusionCtrl; // drives fusion timeline
  bool _fusionPlayed = false; // sticky once triggered

  late List<AlchemyParticle> _particles;
  late List<ReactionSpark> _sparks;
  late ElementConfig _configA;
  ElementConfig? _configB;
  final Random _random = Random();
  Size _lastSize = const Size(200, 200);

  @override
  void initState() {
    super.initState();
    _configA =
        ElementalConfigs.getConfig(widget.parentATypeId) ??
        ElementalConfigs.fire;
    _configB = widget.parentBTypeId != null
        ? ElementalConfigs.getConfig(widget.parentBTypeId!)
        : null;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fusionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _particles = [];
    _sparks = [];
    _initParticles();

    // If fusion is already true on first build, kick it off.
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
      _fusionCtrl.forward();
    }

    // NEW: When fusion animation completes, replace particles
    _fusionCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _initParticles(); // This will now create only 2 idle particles
        });
      }
    });

    // Re-init if element types change
    if (oldWidget.parentATypeId != widget.parentATypeId ||
        oldWidget.parentBTypeId != widget.parentBTypeId) {
      _configA =
          ElementalConfigs.getConfig(widget.parentATypeId) ??
          ElementalConfigs.fire;
      _configB = widget.parentBTypeId != null
          ? ElementalConfigs.getConfig(widget.parentBTypeId!)
          : null;
      _initParticles();
    }
  }

  void _initParticles() {
    _particles.clear();

    // During idle/fusion, show representative particles
    if (widget.fusion && _fusionCtrl.value >= 1.0) {
      // 2 main orbital particles (one from each parent)
      _particles.add(_createIdleParticle(_configA, 'parentA', isMain: true));
      if (_configB != null) {
        _particles.add(_createIdleParticle(_configB!, 'parentB', isMain: true));
      }

      // 5 smaller particles from parent A
      for (int i = 0; i < 5; i++) {
        _particles.add(_createIdleParticle(_configA, 'parentA', isMain: false));
      }

      // 5 smaller particles from parent B (if exists)
      if (_configB != null) {
        for (int i = 0; i < 5; i++) {
          _particles.add(
            _createIdleParticle(_configB!, 'parentB', isMain: false),
          );
        }
      }

      return;
    }

    // Normal brewing: full particle count
    final halfCount = widget.particleCount ~/ 2;

    // Parent A particles
    for (int i = 0; i < halfCount; i++) {
      _particles.add(_createParticle(_configA, 'parentA'));
    }

    // Parent B particles (if exists)
    if (_configB != null) {
      for (int i = 0; i < widget.particleCount - halfCount; i++) {
        _particles.add(_createParticle(_configB!, 'parentB'));
      }
    }
  }

  AlchemyParticle _createIdleParticle(
    ElementConfig config,
    String elementType, {
    required bool isMain,
  }) {
    final center = Offset(_lastSize.width / 2, _lastSize.height / 2);

    if (isMain) {
      // Main orbital particles (2 total)
      final isParentA = elementType == 'parentA';
      final angle = isParentA ? 0.0 : pi; // 0° and 180° apart
      final orbitRadius = 40.0;

      final position =
          center + Offset(cos(angle) * orbitRadius, sin(angle) * orbitRadius);

      // Gentle orbital velocity
      final velocity = Offset(-sin(angle) * 0.3, cos(angle) * 0.3);

      return AlchemyParticle(
        position: position,
        velocity: velocity,
        size: config.maxSize * 1.5, // Larger for visibility
        color: config.colors.first, // Use primary color
        opacity: 0.8,
        rotation: 0,
        rotationSpeed: 0.02,
        life: 1.0,
        energy: 1.0,
        elementType: elementType,
      );
    } else {
      // Smaller random floating particles (10 total)
      final randomAngle = _random.nextDouble() * 2 * pi;
      final randomRadius = 20.0 + _random.nextDouble() * 50.0;

      final position =
          center +
          Offset(
            cos(randomAngle) * randomRadius,
            sin(randomAngle) * randomRadius,
          );

      // Random gentle drift
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
        color:
            config.colors[_random.nextInt(
              config.colors.length,
            )], // Random color from palette
        opacity: 0.4 + _random.nextDouble() * 0.4,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.03,
        life: 1.0,
        energy: 1.0,
        elementType: elementType,
      );
    }
  }

  AlchemyParticle _createParticle(ElementConfig config, String elementType) {
    final size =
        config.minSize +
        _random.nextDouble() * (config.maxSize - config.minSize);
    final color = config.colors[_random.nextInt(config.colors.length)];

    // Start from edge or random
    final startFromEdge = _random.nextBool();
    Offset position;
    Offset velocity;

    if (startFromEdge) {
      final offscreenMargin = config.maxSize * 2;
      final edge = _random.nextInt(4);
      switch (edge) {
        case 0: // top
          position = Offset(
            _random.nextDouble() * _lastSize.width,
            -offscreenMargin,
          );
          break;
        case 1: // right
          position = Offset(
            _lastSize.width + offscreenMargin,
            _random.nextDouble() * _lastSize.height,
          );
          break;
        case 2: // bottom
          position = Offset(
            _random.nextDouble() * _lastSize.width,
            _lastSize.height + offscreenMargin,
          );
          break;
        default: // left
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
    final distance = sqrt(
      toCenter.dx * toCenter.dx + toCenter.dy * toCenter.dy,
    );

    if (distance > 0) {
      final normalized = Offset(toCenter.dx / distance, toCenter.dy / distance);
      final speed =
          config.minSpeed +
          _random.nextDouble() * (config.maxSpeed - config.minSpeed);

      final angleVariation = (_random.nextDouble() - 0.5) * 0.8;
      final cosMath =
          normalized.dx * cos(angleVariation) -
          normalized.dy * sin(angleVariation);
      final sinMath =
          normalized.dx * sin(angleVariation) +
          normalized.dy * cos(angleVariation);
      velocity = Offset(cosMath * speed, sinMath * speed);
    } else {
      velocity = _getInitialVelocity(config);
    }

    return AlchemyParticle(
      position: position,
      velocity: velocity,
      size: size,
      color: color,
      opacity: 0.5 + _random.nextDouble() * 0.5,
      rotation: _random.nextDouble() * pi * 2,
      rotationSpeed: (_random.nextDouble() - 0.5) * 0.05,
      life: 0.5 + _random.nextDouble() * 0.5,
      energy: _random.nextDouble(),
      elementType: elementType,
    );
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
    _fusionCtrl.dispose();
    super.dispose();
  }

  double get _continuousIdleAngle {
    // One full rotation every 24s (smooth, continuous)
    final elapsedMs = _controller.lastElapsedDuration?.inMilliseconds ?? 0;
    const periodMs = 24000;
    final phase = (elapsedMs % periodMs) / periodMs; // 0..1 but wraps at 24s
    return 2 * pi * phase; // angle in radians, continuous across frames
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _fusionCtrl]),
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final newSize = Size(constraints.maxWidth, constraints.maxHeight);
            if (_lastSize != newSize) {
              _lastSize = newSize;
            }

            _updateParticles();
            return CustomPaint(
              painter: AlchemyBrewingPainter(
                particles: _particles,
                sparks: _sparks,
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
              ),
              size: newSize,
            );
          },
        );
      },
    );
  }

  void _updateParticles() {
    final width = _lastSize.width;
    final height = _lastSize.height;
    final center = Offset(width / 2, height / 2);

    // IDLE MODE: Simple orbital motion for main particles, gentle drift for small ones
    if (widget.fusion && _fusionCtrl.value >= 1.0) {
      for (int i = 0; i < _particles.length; i++) {
        final p = _particles[i];
        final toCenter = center - p.position;
        final distance = sqrt(
          toCenter.dx * toCenter.dx + toCenter.dy * toCenter.dy,
        );

        if (i < 2) {
          // Main particles: circular orbit
          if (distance > 0) {
            final angle = atan2(p.velocity.dy, p.velocity.dx);
            final newAngle = angle + 0.02; // Constant gentle rotation
            p.velocity = Offset(cos(newAngle) * 0.3, sin(newAngle) * 0.3);
            p.position += p.velocity;
            p.rotation += p.rotationSpeed;
          }
        } else {
          // Small particles: gentle float with slight center attraction
          p.position += p.velocity;
          p.rotation += p.rotationSpeed;

          // Gentle pull to keep them from drifting too far
          if (distance > 70) {
            p.velocity += Offset(
              (toCenter.dx / distance) * 0.01,
              (toCenter.dy / distance) * 0.01,
            );
          }

          // Gentle velocity damping
          p.velocity *= 0.99;

          // Wrap around if they go too far
          if (distance > 90) {
            final wrapAngle = _random.nextDouble() * 2 * pi;
            p.position =
                center + Offset(cos(wrapAngle) * 30, sin(wrapAngle) * 30);
          }
        }
      }
      return; // Skip all the complex brewing logic
    }

    // FUSION TRANSITION: Fade out particles smoothly
    if (widget.fusion && _fusionCtrl.value < 1.0) {
      // Start fading particles at 50% through the fusion animation
      final fadeStart = 0.5;
      if (_fusionCtrl.value > fadeStart) {
        final fadeProgress =
            (_fusionCtrl.value - fadeStart) / (1.0 - fadeStart);

        // Gradually reduce particle count during fade
        final targetParticleCount =
            2 + ((1.0 - fadeProgress) * (_particles.length - 2)).round();

        for (int i = 0; i < _particles.length; i++) {
          final p = _particles[i];

          // Fade out opacity
          p.opacity *= (1.0 - fadeProgress * 0.1); // Gradual fade

          // Pull strongly to center
          final toCenter = center - p.position;
          final distance = sqrt(
            toCenter.dx * toCenter.dx + toCenter.dy * toCenter.dy,
          );
          if (distance > 0) {
            p.velocity += Offset(
              (toCenter.dx / distance) * 0.3 * fadeProgress,
              (toCenter.dy / distance) * 0.3 * fadeProgress,
            );
          }

          p.position += p.velocity * 0.5;
          p.rotation += p.rotationSpeed;

          // Mark excess particles for removal
          if (i >= targetParticleCount) {
            p.life = 0;
          }
        }

        // Remove dead particles
        _particles.removeWhere((p) => p.life <= 0);

        return; // Skip normal brewing logic during fade
      }
    }

    // BREWING MODE: Full particle system below
    _sparks.removeWhere((spark) {
      spark.life -= 0.03;
      return spark.life <= 0;
    });

    final baseMult = widget.speedMultiplier;
    final fusionDamp = widget.fusion ? 0.35 : 1.0;
    final speedMult = baseMult * fusionDamp;

    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final config = p.elementType == 'parentA'
          ? _configA
          : (_configB ?? _configA);

      // Integrate
      p.position += p.velocity * speedMult;
      p.rotation += p.rotationSpeed * speedMult;

      // Attraction to center
      final toCenter = center - p.position;
      final distance = sqrt(
        toCenter.dx * toCenter.dx + toCenter.dy * toCenter.dy,
      );
      final pullStrength = widget.fusion ? 0.12 : 0.02;
      if (distance > 6) {
        p.velocity += Offset(
          (toCenter.dx / distance) * pullStrength,
          (toCenter.dy / distance) * pullStrength,
        );
      }

      // Swirl
      final angle = atan2(p.velocity.dy, p.velocity.dx);
      final newAngle = angle + (widget.fusion ? 0.01 : 0.03) * speedMult;
      final spd = sqrt(
        p.velocity.dx * p.velocity.dx + p.velocity.dy * p.velocity.dy,
      );
      p.velocity = Offset(cos(newAngle) * spd, sin(newAngle) * spd);

      // Pulsing elements
      if (config.movement == ParticleMovementPattern.pulsing) {
        final amp = widget.fusion ? 0.4 : 0.7;
        p.opacity = 0.3 + amp * ((sin(_controller.value * pi * 2) + 1) / 2);
      }

      // Life & bounds
      p.life -= 0.002 * speedMult;

      if (p.life <= 0 ||
          p.position.dx < -30 ||
          p.position.dx > width + 30 ||
          p.position.dy < -30 ||
          p.position.dy > height + 30) {
        _particles[i] = _createParticle(config, p.elementType);
        if (widget.fusion) {
          _particles[i].position = Offset(
            _random.nextDouble() * width,
            _random.nextBool() ? -20 : height + 20,
          );
        }
      }
    }

    // Probabilistic reaction sparks (only during brewing, not fusion)
    if (_configB != null && !widget.fusion) {
      final checksPerFrame = 3;

      for (int check = 0; check < checksPerFrame; check++) {
        final i = _random.nextInt(_particles.length);
        final p = _particles[i];

        if (p.elementType != 'parentA') continue;

        // Use speedMultiplier as progress proxy (0.1 -> 6.0 maps to 0 -> 1)
        final progressEstimate = ((speedMult - 0.1) / (6.0 - 0.1)).clamp(
          0.0,
          1.0,
        );
        final progressSquared = progressEstimate * progressEstimate;
        final sparkChance = 0.015 + (progressSquared * 0.085);

        if (_random.nextDouble() < sparkChance * speedMult) {
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

  void _createReactionSpark(Offset position, Color color1, Color color2) {
    if (_sparks.length > 50) return;

    final blendedColor = Color.fromARGB(
      255,
      ((color1.red + color2.red) / 2).round(),
      ((color1.green + color2.green) / 2).round(),
      ((color1.blue + color2.blue) / 2).round(),
    );

    for (int i = 0; i < 3; i++) {
      _sparks.add(
        ReactionSpark(
          position:
              position +
              Offset(
                (_random.nextDouble() - 0.5) * 5,
                (_random.nextDouble() - 0.5) * 5,
              ),
          color: blendedColor,
          size: 2 + _random.nextDouble() * 3,
          life: 1.0,
        ),
      );
    }
  }
}
