import 'package:alchemons/models/faction.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class InteractiveBackground extends StatefulWidget {
  // Controllers are created/started by the parent (..repeat()).
  final AnimationController particleController;
  final AnimationController rotationController;
  final AnimationController waveController;

  // Colors & state
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final FactionId factionType;

  // Speed knobs (independent of controller.duration)
  final double particleSpeed; // common particle drift speed
  final double rotationSpeed; // orbiting blob speed
  final double elementalSpeed; // elemental layer speed

  const InteractiveBackground({
    super.key,
    required this.particleController,
    required this.rotationController,
    required this.waveController,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.factionType,
    this.particleSpeed = 1.0,
    this.rotationSpeed = 1.0,
    this.elementalSpeed = 1.0,
  });

  @override
  State<InteractiveBackground> createState() => _InteractiveBackgroundState();
}

class _InteractiveBackgroundState extends State<InteractiveBackground> {
  final List<Particle> _particles = [];
  Offset? _lastTapPosition;
  double _rippleAnimation = 0.0;
  static const int maxParticles = 30;

  @override
  void initState() {
    super.initState();
    _initializeParticles();
  }

  void _initializeParticles() {
    for (int i = 0; i < maxParticles; i++) {
      _particles.add(Particle(index: i, maxParticles: maxParticles));
    }
  }

  // ---- Helpers ----
  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _lastTapPosition = details.localPosition;
      _rippleAnimation = 0.0;
    });

    for (var particle in _particles) {
      particle.applyForce(details.localPosition);
    }

    _handleRippleStep();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _lastTapPosition = null;
          _rippleAnimation = 0.0;
        });
      }
    });
  }

  void _handleRippleStep() {
    if (_rippleAnimation < 1.0) {
      Future.delayed(const Duration(milliseconds: 16), () {
        if (mounted && _lastTapPosition != null) {
          setState(() {
            _rippleAnimation += 0.05;
            if (_rippleAnimation < 1.0) {
              _handleRippleStep();
            }
          });
        }
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _lastTapPosition = details.localPosition;
      _rippleAnimation = 0.0;
    });

    for (var particle in _particles) {
      particle.applyForce(details.localPosition);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _lastTapPosition = null;
      _rippleAnimation = 0.0;
    });
  }

  Widget _buildFactionEffect() {
    final c = widget.waveController;
    switch (widget.factionType) {
      case FactionId.fire:
        return RepaintBoundary(
          child: CustomPaint(
            painter: FirePainter(
              controller: c,
              speedFactor: widget.elementalSpeed,
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
            ),
            isComplex: true,
            willChange: true,
          ),
        );
      case FactionId.water:
        return RepaintBoundary(
          child: CustomPaint(
            painter: WavePainter(
              controller: c,
              speedFactor: widget.elementalSpeed,
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
            ),
            isComplex: true,
            willChange: true,
          ),
        );
      case FactionId.air:
        return RepaintBoundary(
          child: CustomPaint(
            painter: AirPainter(
              controller: c,
              speedFactor: widget.elementalSpeed,
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
            ),
            isComplex: true,
            willChange: true,
          ),
        );
      case FactionId.earth:
        return RepaintBoundary(
          child: CustomPaint(
            painter: EarthPainter(
              controller: c,
              speedFactor: widget.elementalSpeed,
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
            ),
            isComplex: true,
            willChange: true,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.primaryColor.withOpacity(0.15),
                    widget.secondaryColor.withOpacity(0.15),
                    widget.accentColor.withOpacity(0.15),
                  ],
                ),
              ),
            ),
          ),

          // Particles: painter listens to particleController ticks
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: InteractiveParticlePainter(
                  controller: widget.particleController,
                  speedFactor: widget.particleSpeed,
                  particles: _particles,
                  tapPosition: _lastTapPosition,
                  rippleAnimation: _rippleAnimation,
                  primaryColor: widget.primaryColor,
                ),
                isComplex: true,
                willChange: true,
              ),
            ),
          ),

          // Orbiting radial blobs (rotation) — independent speed
          Positioned.fill(
            child: AnimatedBuilder(
              animation: widget.rotationController,
              builder: (context, child) {
                final seconds =
                    (widget.rotationController.lastElapsedDuration ??
                            Duration.zero)
                        .inMicroseconds /
                    1e6;
                final t = (seconds * widget.rotationSpeed) % 1.0; // 0..1
                return Stack(
                  children: [
                    Align(
                      alignment: Alignment(
                        0.7 * math.cos(t * 2 * math.pi),
                        0.5 * math.sin(t * 2 * math.pi),
                      ),
                      child: Container(
                        width: 350,
                        height: 350,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.primaryColor.withOpacity(0.25),
                              widget.primaryColor.withOpacity(0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(
                        -0.6 * math.cos(t * 2 * math.pi + math.pi),
                        -0.4 * math.sin(t * 2 * math.pi + math.pi),
                      ),
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.secondaryColor.withOpacity(0.2),
                              widget.secondaryColor.withOpacity(0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(
                        0.5 * math.sin(t * 2 * math.pi),
                        0.6 * math.cos(t * 2 * math.pi),
                      ),
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              widget.accentColor.withOpacity(0.18),
                              widget.accentColor.withOpacity(0.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Faction effects cross-fade when type changes (sized to fill)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(widget.factionType),
                child: const SizedBox.expand(
                  // ensure full constraints
                  child: _FactionLayerProxy(),
                ),
              ),
            ),
          ),

          // The proxy above renders the current faction effect behind the scenes
          // keeping AnimatedSwitcher children simple & consistently sized.
          // (See below _FactionLayerProxy)
        ],
      ),
    );
  }
}

/// We use a proxy so AnimatedSwitcher children are always the same widget
/// type/size, avoiding re-layout flicker. It grabs the nearest
/// InteractiveBackground state via context and paints the faction effect.
class _FactionLayerProxy extends StatelessWidget {
  const _FactionLayerProxy();

  @override
  Widget build(BuildContext context) {
    final state = context
        .findAncestorStateOfType<_InteractiveBackgroundState>()!;
    return state._buildFactionEffect();
  }
}

// ---------------------- Particles ----------------------

class Particle {
  final int index;
  final int maxParticles;
  double velocityX = 0;
  double velocityY = 0;
  double offsetX = 0;
  double offsetY = 0;

  Particle({required this.index, required this.maxParticles});

  void applyForce(Offset tapPosition) {
    const repulsionStrength = 50.0;
    velocityX += (math.Random().nextDouble() - 0.5) * repulsionStrength;
    velocityY += (math.Random().nextDouble() - 0.5) * repulsionStrength;
  }

  void update() {
    offsetX += velocityX;
    offsetY += velocityY;
    velocityX *= 0.95;
    velocityY *= 0.95;
    offsetX *= 0.98;
    offsetY *= 0.98;
  }
}

class InteractiveParticlePainter extends CustomPainter {
  final AnimationController controller;
  final double speedFactor;
  final List<Particle> particles;
  final Offset? tapPosition;
  final double rippleAnimation;
  final Color primaryColor;

  InteractiveParticlePainter({
    required this.controller,
    required this.particles,
    required this.primaryColor,
    this.speedFactor = 1.0,
    this.tapPosition,
    this.rippleAnimation = 0.0,
  }) : super(repaint: controller); // repaint every tick

  @override
  void paint(Canvas canvas, Size size) {
    // time from controller (monotonic seconds)
    final timeSeconds =
        (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;
    final loop = timeSeconds - timeSeconds.floorToDouble();

    // advance particles
    for (var particle in particles) {
      particle.update();
    }

    final paint = Paint()
      ..color = primaryColor.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    // Tap ripple
    if (tapPosition != null && rippleAnimation < 1.0) {
      final outerRadius = 10 + (rippleAnimation * 80);
      final outerOpacity = (1.0 - rippleAnimation) * 0.3;
      final outerRipple = Paint()
        ..color = primaryColor.withOpacity(outerOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(tapPosition!, outerRadius, outerRipple);

      if (rippleAnimation > 0.2) {
        final midRadius = 10 + ((rippleAnimation - 0.2) * 60);
        final midOpacity = (1.0 - rippleAnimation) * 0.25;
        final midRipple = Paint()
          ..color = primaryColor.withOpacity(midOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(tapPosition!, midRadius, midRipple);
      }

      final innerOpacity = (1.0 - rippleAnimation) * 0.2;
      final innerRipple = Paint()
        ..color = primaryColor.withOpacity(innerOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tapPosition!, 20, innerRipple);
    }

    // layout particles
    final positions = <Offset>[];
    final driftPerSecond = 120.0 * speedFactor; // 👈 speed knob
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      // Linear drift uses timeSeconds (no reset)
      final baseX =
          size.width / particles.length * i + timeSeconds * driftPerSecond;
      final baseY =
          size.height / particles.length * i +
          math.sin(loop * 2 * math.pi + i) * 100;

      var x = (baseX + p.offsetX) % size.width;
      var y = (baseY + p.offsetY) % size.height;
      if (x < 0) x += size.width;
      if (y < 0) y += size.height;
      final pos = Offset(x, y);
      positions.add(pos);

      final radius = 3 + math.sin(loop * 2 * math.pi + i) * 2;

      double particleOpacity = 0.25;
      if (tapPosition != null) {
        final distance = (pos - tapPosition!).distance;
        if (distance < 100) {
          particleOpacity = 0.25 + (1 - distance / 100) * 0.4;
        }
      }

      particleOpacity *= _edgeFade(pos, size, 40);

      paint.color = primaryColor.withOpacity(particleOpacity.clamp(0.0, 1.0));
      canvas.drawCircle(pos, radius, paint);
    }

    // connective lines
    for (int i = 0; i < positions.length; i++) {
      for (int j = i + 1; j < positions.length; j++) {
        final a = positions[i];
        final b = positions[j];
        final d = (b - a).distance;
        if (d < 100) {
          double lineOpacity = (1 - d / 100) * 0.4;

          if (tapPosition != null) {
            final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
            final td = (mid - tapPosition!).distance;
            if (td < 100) {
              lineOpacity += (1 - td / 100) * 0.3;
            }
          }

          lineOpacity *= math.min(
            _edgeFade(a, size, 40),
            _edgeFade(b, size, 40),
          );

          if (lineOpacity > 0) {
            final linePaint = Paint()
              ..color = primaryColor.withOpacity(lineOpacity)
              ..strokeWidth = 1.5;
            canvas.drawLine(a, b, linePaint);
          }
        }
      }
    }
  }

  double _edgeFade(Offset p, Size s, double width) {
    final dx = math.min(p.dx, s.width - p.dx);
    final dy = math.min(p.dy, s.height - p.dy);
    final f = math.min(dx, dy) / width;
    return f.clamp(0.0, 1.0);
  }

  @override
  bool shouldRepaint(InteractiveParticlePainter oldDelegate) => true;
}

// ---------------------- Shared seeded random ----------------------

double _seededRandom(int seed, double offset) {
  final value = math.sin(seed * 12.9898 + offset * 78.233) * 43758.5453;
  return value - value.floor();
}

// ---------------------- FIRE - Seamless rising embers ----------------------

class FirePainter extends CustomPainter {
  final AnimationController controller;
  final double speedFactor;
  final Color primaryColor;
  final Color secondaryColor;

  FirePainter({
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    this.speedFactor = 1.0,
  }) : super(repaint: controller);

  double _timeSeconds() =>
      (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _timeSeconds() * speedFactor; // scaled continuous time

    for (int i = 0; i < 35; i++) {
      final randomX = _seededRandom(i, 0);
      final speed = 0.3 + _seededRandom(i, 1) * 0.4;
      final sway = _seededRandom(i, 2) * 60 - 30;
      final stagger = _seededRandom(i, 4);

      final phase = t * speed + stagger; // continuous
      final u = phase - phase.floor(); // 0..1

      final x = randomX * size.width + math.sin(phase * 2 * math.pi) * sway;

      final fadeZone = size.height * 0.15;
      final totalRange = size.height + fadeZone * 2;
      final yStart = size.height + fadeZone;
      final y = yStart - (u * totalRange);

      final emberSize = 2 + _seededRandom(i, 3) * 2;

      double fadeOpacity = 1.0;
      if (y > size.height - fadeZone && y <= size.height) {
        fadeOpacity = (size.height - y) / fadeZone;
      } else if (y < fadeZone && y >= 0) {
        fadeOpacity = y / fadeZone;
      } else if (y < 0 || y > size.height) {
        fadeOpacity = 0.0;
      }

      if (fadeOpacity > 0) {
        final flicker = 0.8 + math.sin(phase * 8 * math.pi) * 0.2;
        final opacity = fadeOpacity * 0.8 * flicker;

        final paint = Paint()
          ..color = (i % 2 == 0 ? primaryColor : secondaryColor).withOpacity(
            opacity,
          )
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), emberSize, paint);

        final glowPaint = Paint()
          ..color = primaryColor.withOpacity(opacity * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(Offset(x, y), emberSize * 2.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(FirePainter oldDelegate) => true;
}

// ---------------------- WATER - Seamless rainfall ----------------------

class WavePainter extends CustomPainter {
  final AnimationController controller;
  final double speedFactor;
  final Color primaryColor;
  final Color secondaryColor;

  WavePainter({
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    this.speedFactor = 1.0,
  }) : super(repaint: controller);

  double _timeSeconds() =>
      (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _timeSeconds() * speedFactor;

    for (int i = 0; i < 50; i++) {
      final randomX = _seededRandom(i, 0);
      final speed = 0.5 + _seededRandom(i, 1) * 0.5;
      final sway = _seededRandom(i, 2) * 20 - 10;
      final stagger = _seededRandom(i, 4);

      final phase = t * speed + stagger;
      final u = phase - phase.floor();

      final x = randomX * size.width + math.sin(phase * math.pi) * sway;

      final fadeZone = size.height * 0.15;
      final totalRange = size.height + fadeZone * 2;
      final yStart = -fadeZone;
      final y = yStart + (u * totalRange);

      final dropLength = 8.0 + _seededRandom(i, 3) * 4;

      double fadeOpacity = 1.0;
      if (y < fadeZone && y >= 0) {
        fadeOpacity = y / fadeZone;
      } else if (y > size.height - fadeZone && y <= size.height) {
        fadeOpacity = (size.height - y) / fadeZone;
      } else if (y < 0 || y > size.height) {
        fadeOpacity = 0.0;
      }

      if (fadeOpacity > 0) {
        final rainPaint = Paint()
          ..color = primaryColor.withOpacity(0.15 * fadeOpacity)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x, y), Offset(x, y + dropLength), rainPaint);
      }
    }

    final paint = Paint()
      ..color = primaryColor.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(0, size.height * 0.7);
    for (double x = 0; x <= size.width; x += 10) {
      final y =
          size.height * 0.7 +
          math.sin((x / size.width) * 4 * math.pi + t * 2 * math.pi) * 40;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = secondaryColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path2 = Path()..moveTo(0, size.height * 0.8);
    for (double x = 0; x <= size.width; x += 10) {
      final y =
          size.height * 0.8 +
          math.sin((x / size.width) * 3 * math.pi + t * 2 * math.pi + math.pi) *
              35;
      path2.lineTo(x, y);
    }
    path2
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) => true;
}

// ---------------------- AIR - Seamless drifting clouds ----------------------

class AirPainter extends CustomPainter {
  final AnimationController controller;
  final double speedFactor;
  final Color primaryColor;
  final Color secondaryColor;

  AirPainter({
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    this.speedFactor = 1.0,
  }) : super(repaint: controller);

  double _timeSeconds() =>
      (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _timeSeconds() * speedFactor;

    for (int i = 0; i < 12; i++) {
      final randomY =
          _seededRandom(i, 0) * size.height * 0.6 + size.height * 0.2;
      final speed = 0.08 + _seededRandom(i, 1) * 0.12;
      final wave = _seededRandom(i, 2) * 50 - 25;
      final stagger = _seededRandom(i, 4);

      final phase = t * speed + stagger;
      final u = phase - phase.floor();

      final fadeZone = size.width * 0.2;
      final totalRange = size.width + fadeZone * 2;
      final xStart = -fadeZone;
      final x = xStart + (u * totalRange);
      final y = randomY + math.sin(phase * 2 * math.pi) * wave;

      double fadeOpacity = 1.0;
      if (x < fadeZone && x >= 0) {
        fadeOpacity = x / fadeZone;
      } else if (x > size.width - fadeZone && x <= size.width) {
        fadeOpacity = (size.width - x) / fadeZone;
      } else if (x < 0 || x > size.width) {
        fadeOpacity = 0.0;
      }

      if (fadeOpacity > 0) {
        for (int j = 0; j < 4; j++) {
          final cloudPath = Path()
            ..addOval(
              Rect.fromCenter(
                center: Offset(x + j * 20, y + j * 6),
                width: 90 + math.sin(phase * 3 * math.pi + j) * 20,
                height: 45 + j * 6,
              ),
            );

          final opacity = (0.18 - j * 0.03) * fadeOpacity;
          final cloudPaint = Paint()
            ..color = (j % 2 == 0 ? primaryColor : secondaryColor).withOpacity(
              opacity,
            )
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);

          canvas.drawPath(cloudPath, cloudPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(AirPainter oldDelegate) => true;
}

// ---------------------- EARTH - Seamless falling crystals ----------------------

class EarthPainter extends CustomPainter {
  final AnimationController controller;
  final double speedFactor;
  final Color primaryColor;
  final Color secondaryColor;

  EarthPainter({
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    this.speedFactor = 1.0,
  }) : super(repaint: controller);

  double _timeSeconds() =>
      (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _timeSeconds() * speedFactor;

    for (int i = 0; i < 25; i++) {
      final randomX = _seededRandom(i, 0);
      final speed = 0.25 + _seededRandom(i, 1) * 0.3;
      final sway = _seededRandom(i, 2) * 30 - 15;
      final rotSpeed = 0.5 + _seededRandom(i, 3) * 1.0;
      final stagger = _seededRandom(i, 4);

      final phase = t * speed + stagger;
      final u = phase - phase.floor();

      final x = randomX * size.width + math.sin(phase * math.pi) * sway;

      final fadeZone = size.height * 0.15;
      final totalRange = size.height + fadeZone * 2;
      final yStart = -fadeZone;
      final y = yStart + (u * totalRange);

      final rotation = phase * math.pi * rotSpeed;

      double fadeOpacity = 1.0;
      if (y < fadeZone && y >= 0) {
        fadeOpacity = y / fadeZone;
      } else if (y > size.height - fadeZone && y <= size.height) {
        fadeOpacity = (size.height - y) / fadeZone;
      } else if (y < 0 || y > size.height) {
        fadeOpacity = 0.0;
      }

      if (fadeOpacity > 0) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rotation);

        final crystalPath = Path()
          ..moveTo(0, -6)
          ..lineTo(4, 0)
          ..lineTo(0, 6)
          ..lineTo(-4, 0)
          ..close();

        final crystalPaint = Paint()
          ..color = (i % 2 == 0 ? primaryColor : secondaryColor).withOpacity(
            0.3 * fadeOpacity,
          )
          ..style = PaintingStyle.fill;

        canvas.drawPath(crystalPath, crystalPaint);

        final borderPaint = Paint()
          ..color = primaryColor.withOpacity(0.4 * fadeOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        canvas.drawPath(crystalPath, borderPaint);

        canvas.restore();
      }
    }

    final groundPath = Path()..moveTo(0, size.height * 0.9);
    for (double x = 0; x <= size.width; x += 15) {
      final y =
          size.height * 0.9 + (math.sin((x / size.width) * 10 * math.pi) * 3);
      groundPath.lineTo(x, y);
    }
    groundPath
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final groundPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawPath(groundPath, groundPaint);
  }

  @override
  bool shouldRepaint(EarthPainter oldDelegate) => true;
}
