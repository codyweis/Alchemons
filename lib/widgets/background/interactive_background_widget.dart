import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/models/faction.dart';
import 'package:alchemons/providers/theme_provider.dart';
import 'package:alchemons/widgets/animations/shaders/fire_animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

  // Live tilt (dx = tiltX, dy = tiltY), read by the water painter.
  final ValueNotifier<Offset> _tilt = ValueNotifier<Offset>(Offset.zero);

  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _tiltX = 0.0, _tiltY = 0.0; // internal smoothed state

  @override
  void initState() {
    super.initState();
    _initializeParticles();

    const g = 9.81;

    // Smoother low-pass + per-event step clamp to kill micro-jitter.
    const lp = 0.06; // lower = smoother response
    const maxStep = 0.02; // max change per sensor event

    _accelSub =
        accelerometerEventStream(
          samplingPeriod:
              SensorInterval.gameInterval, // try uiInterval if needed
        ).listen((e) {
          final tx = (e.x / g).clamp(-1.0, 1.0);
          final ty = (-e.y / g).clamp(-1.0, 1.0);

          // Exponential smoothing
          final nx = _tiltX + (tx - _tiltX) * lp;
          final ny = _tiltY + (ty - _tiltY) * lp;

          // Clamp step to avoid tiny spikes
          double clampStep(double from, double to) {
            final d = to - from;
            if (d > maxStep) return from + maxStep;
            if (d < -maxStep) return from - maxStep;
            return to;
          }

          _tiltX = clampStep(_tiltX, nx);
          _tiltY = clampStep(_tiltY, ny);

          // Notify painter with the new live tilt
          _tilt.value = Offset(_tiltX, _tiltY);
        });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  void _initializeParticles() {
    for (int i = 0; i < maxParticles; i++) {
      _particles.add(Particle(index: i, maxParticles: maxParticles));
    }
  }

  // ---- Interaction helpers ----
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
    final themeNotifier = context.watch<ThemeNotifier>();
    final current = themeNotifier.themeMode;
    final isDark = current == ThemeMode.dark;
    final intensity = isDark ? 1.0 : 5.0;
    final rise = isDark ? 0.68 : 1.0;
    final noise = isDark ? 2.0 : 5.0;
    final speedFactor = isDark ? 1.0 : .5;
    final c = widget.waveController;
    switch (widget.factionType) {
      case FactionId.volcanic:
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
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
            ),
            FireFX(
              intensity: intensity,
              rise: rise,
              turbulence: 1.25,
              noiseScale: noise,
              softEdge: 0.22,
              speedFactor: speedFactor,
            ),
          ],
        );
      case FactionId.oceanic:
        return RepaintBoundary(
          child: CustomPaint(
            painter: RainSplashPainter(
              controller: c,
              speedFactor: widget.elementalSpeed,
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
              tilt: _tilt, // live tilt
            ),
            isComplex: true,
            willChange: true,
          ),
        );
      case FactionId.verdant:
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
      case FactionId.earthen:
        return RepaintBoundary(
          child: CustomPaint(
            painter: EarthPlantsPainter(
              controller: c,
              speedFactor: widget.elementalSpeed,
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
              bandFraction: 0.25,
              bandFeather: 0.08,
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
                    widget.primaryColor.withOpacity(.2),
                    widget.secondaryColor.withOpacity(0.5),
                    widget.accentColor.withOpacity(0.05),
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
                child: const SizedBox.expand(child: _FactionLayerProxy()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Proxy so AnimatedSwitcher children are uniform.
/// It grabs the nearest InteractiveBackground state and paints the faction effect.
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
    final timeSeconds =
        (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;
    final loop = timeSeconds - timeSeconds.floorToDouble();

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

      final phase = t * speed + stagger;
      final u = phase - phase.floor();

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
          ..color = primaryColor.withOpacity(opacity * 0.4);
        canvas.drawCircle(Offset(x, y), emberSize * 2.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(FirePainter oldDelegate) => true;
}

// ---------------------- WATER - Rain splashes (crown + jet + foam) ----------------------

class RainSplashPainter extends CustomPainter {
  final AnimationController controller;
  final double speedFactor;
  final Color primaryColor;
  final Color secondaryColor;
  final ValueListenable<Offset> tilt;

  // --- NEW: tiny bit of persistent state for smoothing / integration
  double _tiltXSmooth = 0.0;
  double _tiltYSmooth = 0.0;
  double _lastT = 0.0;
  double _adv1Acc = 0.0; // integrated phase shift for wave 1
  double _adv2Acc = 0.0; // integrated phase shift for wave 2

  RainSplashPainter({
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tilt,
    this.speedFactor = 1.0,
  }) : super(repaint: Listenable.merge([controller, tilt]));

  double _timeSeconds() =>
      (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  // helper
  static double _ease01(double x) => x * x * (3 - 2 * x);

  @override
  void paint(Canvas canvas, Size size) {
    final t = _timeSeconds() * speedFactor;

    // --- Smooth the live tilt with an exponential moving average
    final raw = tilt.value;
    final tiltX = raw.dx.clamp(-1.0, 1.0);
    final tiltY = raw.dy.clamp(-1.0, 1.0);

    // elapsed step (defensive against resets)
    double dt = t - _lastT;
    if (dt < 0 || dt > 0.25) dt = 0.0; // clamp large jumps
    _lastT = t;

    // time-constant ~120ms feels nice; smaller = snappier, larger = more floaty
    const tau = 0.12;
    final alpha = dt <= 0 ? 1.0 : (1 - math.exp(-dt / tau));

    // optional mild deadzone to avoid micro-jitter near flat
    double deadzone(double v, [double d = 0.02]) => (v.abs() < d) ? 0.0 : v;

    _tiltXSmooth += (deadzone(tiltX) - _tiltXSmooth) * alpha;
    _tiltYSmooth += (deadzone(tiltY) - _tiltYSmooth) * alpha;

    final easedTiltX = _ease01(_tiltXSmooth.abs()) * _tiltXSmooth.sign;
    final easedTiltY = _ease01(_tiltYSmooth.abs()) * _tiltYSmooth.sign;

    // ----- Pool layout (unchanged shape, but uses smoothed tilt Y)
    const basePoolFraction = 0.22;
    const poolFeather = 0.05;

    final poolHeight = size.height * (basePoolFraction + easedTiltY * 0.02);
    final baseTop = size.height - poolHeight;

    // Slope from smoothed/eased tilt
    final maxSlopePx = size.height * 0.2;
    final slope = -(easedTiltX.clamp(-1.0, 1.0)) * maxSlopePx;

    // Continuous “downhill” influence (no .sign snapping)
    final downhill = easedTiltX; // [-1..1], not just {-1,0,1}

    // Base linear waterline (no waves)
    double yLinear(double x) {
      final tx = (x / size.width).clamp(0.0, 1.0);
      final yL = baseTop + slope;
      final yR = baseTop - slope;
      return (1 - tx) * yL + tx * yR;
    }

    // ----- Traveling surface waves (same k/ω, but velocity is integrated)
    final A1 = 6.0 + 4.0 * easedTiltX.abs();
    final A2 = 3.5 + 2.0 * easedTiltX.abs();
    final k1 = 2 * math.pi / 140.0;
    final k2 = 2 * math.pi / 70.0;
    final w1 = 2 * math.pi * 0.55;
    final w2 = 2 * math.pi * 1.05;

    // Continuous advection velocity (px/sec), direction from smoothed tilt
    final v1 = (80.0 + 120.0 * easedTiltX.abs()) * downhill;
    final v2 = (50.0 + 80.0 * easedTiltX.abs()) * downhill;

    // Integrate phase shift: s(t) = ∫ v(τ) dτ  (prevents instant re-phasing)
    _adv1Acc += v1 * dt;
    _adv2Acc += v2 * dt;

    double ySurface(double x) {
      final base = yLinear(x);
      final a = A1 * math.sin(k1 * (x + _adv1Acc) + w1 * t);
      final b = A2 * math.sin(k2 * (x - _adv2Acc) - w2 * t);
      return base + 0.6 * a + 0.4 * b;
    }

    final featherPx = size.height * poolFeather;
    double poolMask(double x, double y) {
      final top = ySurface(x);
      if (y <= top) return 0.0;
      if (y >= top + featherPx) return 1.0;
      final f = (y - top) / featherPx;
      return f * f * (3 - 2 * f);
    }

    // ----- Draw pool
    final top = Path()..moveTo(0, ySurface(0));
    const step = 8.0;
    for (double x = step; x <= size.width; x += step) {
      top.lineTo(x, ySurface(x));
    }
    final pool = Path.from(top)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final poolBounds = Rect.fromLTWH(
      0,
      baseTop,
      size.width,
      size.height - baseTop,
    );
    final poolPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withOpacity(.5),
          primaryColor.withOpacity(0.18),
          primaryColor.withOpacity(0.26),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(poolBounds);
    canvas.drawPath(pool, poolPaint);

    final crestPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withOpacity(0.07);
    canvas.drawPath(top, crestPaint);

    // ----- Rain + splashes (keep behavior, but make wind continuous & softer)
    const rainCount = 60;
    const int maxActiveSplashes = 1;
    int activeSplashes = 0;
    final gateBucket = (t * 3).floor();
    final keepProb = maxActiveSplashes / rainCount;

    final fadeZone = size.height * 0.15;
    final totalRange = size.height + fadeZone * 2;
    final yStart = -fadeZone;

    final rainPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0;
    final jetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dropletPaint = Paint()..style = PaintingStyle.fill;
    final foamStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final foamBlob = Paint()..style = PaintingStyle.fill;

    // Physics
    const double g = 900.0;
    const double jetVy0 = 0.0;
    const double sideVy0 = 200.0;
    const double sideVxMax = 150.0;
    const double splashLifetime = 0.3;

    for (int i = 0; i < rainCount; i++) {
      final rx = _seededRandom(i, 0);
      final speed = 0.50 + _seededRandom(i, 1) * 0.50;
      final sway = _seededRandom(i, 2) * 20 - 10;
      final stag = _seededRandom(i, 4);

      final phase = t * speed + stag;
      final u = phase - phase.floor();

      // softer, continuous wind push
      final wind = easedTiltX * 6.0; // was 10 and snapped by sign before
      final xNow = rx * size.width + math.sin(phase * math.pi) * sway + wind;
      final yNow = yStart + (u * totalRange);

      if (yNow < size.height) {
        double fade = 1.0;
        if (yNow < fadeZone && yNow >= 0) {
          fade = yNow / fadeZone;
        } else if (yNow > size.height - fadeZone && yNow <= size.height) {
          fade = (size.height - yNow) / fadeZone;
        } else if (yNow < 0 || yNow > size.height) {
          fade = 0.0;
        }

        if (fade > 0) {
          rainPaint.color = primaryColor.withOpacity(0.13 * fade);
          final len = 9.0 + _seededRandom(i, 3) * 5;
          canvas.drawLine(
            Offset(xNow, yNow),
            Offset(xNow, yNow + len),
            rainPaint,
          );
        }
      }

      // Impact timing (mean waterline)
      final uHitFlat = (baseTop - yStart) / totalRange;
      var du = u - uHitFlat;
      if (du < 0) du += 1.0;

      final periodSec = 1.0 / speed;
      final dts = du * periodSec;

      final gateRand = _seededRandom(i, 1000.0 + gateBucket);
      final passGate = gateRand < keepProb;

      if (dts <= splashLifetime &&
          passGate &&
          activeSplashes < maxActiveSplashes) {
        activeSplashes++;
        final life = (1.0 - dts / splashLifetime).clamp(0.0, 1.0);

        // Impact position (using integrated wind at hit moment)
        final phaseHit = (phase - u) + uHitFlat;
        final xHit =
            rx * size.width + math.sin(phaseHit * math.pi) * sway + wind;
        final ySurf = ySurface(xHit);
        final origin = Offset(xHit, ySurf + 8.0);

        // Central jet
        final hJet = jetVy0 * dts - 0.5 * g * dts * dts;
        if (hJet > 0) {
          jetPaint
            ..color = Color.lerp(
              primaryColor,
              Colors.white,
              0.35,
            )!.withOpacity(0.55 * life)
            ..strokeWidth = 2.2 - 1.2 * (1 - life);
          final lean = easedTiltX * 10.0; // continuous
          canvas.drawLine(origin, origin.translate(lean, -hJet), jetPaint);
        }

        // Crown + droplets (unchanged except using helpers)
        final crownR = 6.0 + 26.0 * (1.0 - life);
        final crownA = math.pi * 0.45;

        final crown = Path()
          ..moveTo(
            origin.dx - crownR * math.cos(crownA),
            ySurf - crownR * 0.35 * math.sin(crownA),
          );
        for (double a = -crownA; a <= crownA; a += crownA / 10) {
          final px = origin.dx + crownR * math.cos(a);
          final py = ySurf - crownR * 0.35 * math.sin(a);
          crown.lineTo(px, py);
        }
        final crownPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 - 0.8 * (1 - life)
          ..color = Color.lerp(
            primaryColor,
            Colors.white,
            0.45,
          )!.withOpacity(0.35 * life);
        canvas.drawPath(crown, crownPaint);

        for (int k = -2; k <= 2; k++) {
          if (k == 0) continue;
          final side = k.sign;
          final idx = (i * 31 + k * 7);
          final vx =
              side * (0.45 + 0.55 * _seededRandom(idx, 7)) * sideVxMax * 0.8;
          final vy = (0.65 + 0.35 * _seededRandom(idx, 8)) * sideVy0 * 0.9;

          final x = origin.dx + vx * dts;
          final y = origin.dy - (vy * dts - 0.5 * g * dts * dts);

          if (y < ySurface(x) - 2 && x > -10 && x < size.width + 10) {
            final r = 1.2 + 0.9 * life + 0.4 * _seededRandom(idx, 10);
            dropletPaint.color = Color.lerp(
              primaryColor,
              Colors.white,
              0.50,
            )!.withOpacity(0.55 * life);
            canvas.drawCircle(Offset(x, y), r, dropletPaint);
          }
        }

        final foamR = 5.0 + 22.0 * (1.0 - life);
        final foamAlpha =
            (poolMask(origin.dx, origin.dy) * 0.75 + 0.25) * (life * life);

        foamBlob.color = Colors.white.withOpacity(0.10 * foamAlpha);
        canvas.drawCircle(Offset(xHit, ySurf + 6.0), foamR, foamBlob);

        foamStroke
          ..color = Colors.white.withOpacity(0.18 * foamAlpha)
          ..strokeWidth = 1.1 + 0.6 * life;
        canvas.drawCircle(Offset(xHit, ySurf + 6.0), foamR * 1.15, foamStroke);
      }
    }

    // Sheen band (unchanged)
    final sheenPath = Path()..moveTo(0, ySurface(0) + 10);
    for (double x = step; x <= size.width; x += step) {
      sheenPath.lineTo(x, ySurface(x) + 10);
    }
    final sheenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.05), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, baseTop, size.width, 16));
    canvas.drawPath(sheenPath, sheenPaint);
  }

  @override
  bool shouldRepaint(RainSplashPainter old) =>
      old.speedFactor != speedFactor ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor;
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

  final Paint cloudPaint = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _timeSeconds() * speedFactor;

    for (int i = 0; i < 6; i++) {
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
        for (int j = 0; j < 2; j++) {
          final cloudPath = Path()
            ..addOval(
              Rect.fromCenter(
                center: Offset(x + j * 20, y + j * 6),
                width: 120 + math.sin(phase * 3 * math.pi + j) * 20,
                height: 60 + j * 6,
              ),
            );

          final opacity = (0.18 - j * 0.03) * fadeOpacity;
          final cloudPaint = Paint()
            ..color = (j % 2 == 0 ? primaryColor : secondaryColor).withOpacity(
              opacity,
            )
            ..style = PaintingStyle.fill
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

          canvas.drawPath(cloudPath, cloudPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(AirPainter oldDelegate) => true;
}

// ---------------------- EARTH - Seamless plants ----------------------

class EarthPlantsPainter extends CustomPainter {
  final AnimationController controller;
  final double speedFactor;
  final Color primaryColor;
  final Color secondaryColor;

  /// Bottom band where plants live (0..1 of the screen height).
  final double bandFraction;

  /// Soft fade thickness near the top of the band (0..1 of screen height).
  final double bandFeather;

  EarthPlantsPainter({
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    this.speedFactor = 1.0,
    this.bandFraction = 0.25,
    this.bandFeather = 0.08,
  }) : super(repaint: controller);

  double _timeSeconds() =>
      (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _timeSeconds() * speedFactor;

    // ----- Layout band (bottom band where plants grow)
    final bandHeight = size.height * bandFraction;
    final bandTopY = size.height - bandHeight;
    final bandFadePx = size.height * bandFeather;
    final groundY = size.height - 2.0;

    double verticalBandFade(double y) {
      if (y <= bandTopY) return 0.0;
      if (y >= bandTopY + bandFadePx) return 1.0;
      final x = (y - bandTopY) / bandFadePx;
      return x * x * (3 - 2 * x);
    }

    final stemPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final leafPaint = Paint()..style = PaintingStyle.fill;
    final budPaint = Paint()..style = PaintingStyle.fill;

    final plantCount = (12 + size.width / 60).clamp(12, 26).toInt();

    for (int i = 0; i < plantCount; i++) {
      final baseX = _seededRandom(i, 0) * size.width;
      final speed = 0.14 + _seededRandom(i, 1) * 0.16;
      final swaySeed = (_seededRandom(i, 2) - 0.5);
      final heightFrac = 0.55 + _seededRandom(i, 3) * 0.35;
      final stagger = _seededRandom(i, 4);
      final hueMix = _seededRandom(i, 5);

      final phase = t * speed + stagger;
      final u = phase - phase.floor();

      final growIn = (u < 0.65)
          ? _easeOutCubic((u / 0.65).clamp(0.0, 1.0))
          : 1.0;
      final fadeOut = (u > 0.85) ? ((u - 0.85) / 0.15).clamp(0.0, 1.0) : 0.0;

      final h = (bandHeight - 10.0) * heightFrac;
      final stemBase = Offset(baseX, groundY);
      final stemTipY = (groundY - h);

      final swayA = swaySeed * 18.0 + math.sin(phase * 2 * math.pi) * 6.0;
      final swayB =
          -swaySeed * 14.0 + math.sin(phase * 1.5 * math.pi + 1.7) * 5.0;
      final tipSway = swaySeed * 10.0 + math.sin(phase * 3.1) * 4.0;
      final stemCtrl1 = Offset(baseX + swayA, groundY - h * 0.33);
      final stemCtrl2 = Offset(baseX + swayB, groundY - h * 0.66);
      final stemTip = Offset(baseX + tipSway, stemTipY);

      final fullStem = Path()
        ..moveTo(stemBase.dx, stemBase.dy)
        ..cubicTo(
          stemCtrl1.dx,
          stemCtrl1.dy,
          stemCtrl2.dx,
          stemCtrl2.dy,
          stemTip.dx,
          stemTip.dy,
        );

      final metric = fullStem.computeMetrics().isEmpty
          ? null
          : fullStem.computeMetrics().first;
      if (metric == null) continue;

      final drawLen = metric.length * growIn * (1.0 - 0.5 * fadeOut);
      final stemPart = metric.extractPath(0, drawLen);

      final tipSample =
          metric.getTangentForOffset(drawLen)?.position ?? stemTip;
      final bandAlpha = verticalBandFade(tipSample.dy);
      final lifeAlpha = (1.0 - fadeOut);
      final alpha = (bandAlpha * lifeAlpha).clamp(0.0, 1.0);

      final stemWidth = 1.6 + (h / 140.0);
      final stemColor = Color.lerp(
        primaryColor.withOpacity(0.85),
        secondaryColor.withOpacity(0.85),
        hueMix,
      )!;

      stemPaint
        ..color = stemColor.withOpacity(0.75 * alpha)
        ..strokeWidth = stemWidth;

      canvas.drawPath(stemPart, stemPaint);

      final leafSlots = <double>[0.35, 0.55, 0.75];
      for (int li = 0; li < leafSlots.length; li++) {
        final slot = leafSlots[li];
        if (drawLen < metric.length * (slot * 0.92)) continue;

        final tangent = metric.getTangentForOffset(
          (metric.length * slot).clamp(0.0, drawLen),
        );
        if (tangent == null) continue;

        final side = (li % 2 == 0) ? 1.0 : -1.0;

        final localGrow =
            ((drawLen / metric.length) - slot) / 0.15; // ~0.15 window
        final leafK = localGrow.clamp(0.0, 1.0);
        final leafAlpha = (leafK * (1.0 - fadeOut) * alpha).clamp(0.0, 1.0);

        final baseLeafW = 14.0 + h * 0.05;
        final baseLeafH = 8.0 + h * 0.03;
        final leafW = baseLeafW * (0.6 + 0.4 * leafK);
        final leafH = baseLeafH * (0.6 + 0.4 * leafK);

        final breathe = 1.0 + math.sin(phase * 2 * math.pi + li) * 0.03;
        final angle = tangent.vector.direction + side * (math.pi / 2) * 0.88;

        canvas.save();
        canvas.translate(tangent.position.dx, tangent.position.dy);
        canvas.rotate(angle);
        canvas.scale(breathe, breathe);

        final leafPath = Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(leafW * 0.35, 0),
              width: leafW,
              height: leafH,
            ),
          );

        leafPaint.color = stemColor.withOpacity(0.7 * leafAlpha);
        canvas.drawPath(leafPath, leafPaint);

        final veinPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.white.withOpacity(0.25 * leafAlpha);
        canvas.drawLine(Offset(0, 0), Offset(leafW * 0.6, 0), veinPaint);

        canvas.restore();
      }

      if (growIn > 0.6) {
        final budK = ((growIn - 0.6) / 0.25).clamp(0.0, 1.0);
        final budSize = (2.6 + h * 0.015) * budK * (1.0 - fadeOut);
        final pos = tipSample;
        final budColor = Color.lerp(
          secondaryColor,
          primaryColor,
          0.2 + 0.6 * hueMix,
        )!.withOpacity(0.9 * alpha * (1.0 - 0.4 * fadeOut));
        budPaint.color = budColor;
        canvas.drawCircle(pos, budSize, budPaint);
      }

      final baseGlow = Paint()..color = primaryColor.withOpacity(0.06 * alpha);
      canvas.drawCircle(stemBase, 6.0, baseGlow);
    }

    final soilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primaryColor.withOpacity(0.12), primaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, bandTopY - 8, size.width, 16));
    canvas.drawRect(Rect.fromLTWH(0, bandTopY - 8, size.width, 16), soilPaint);
  }

  static double _easeOutCubic(double x) => 1 - math.pow(1 - x, 3).toDouble();

  @override
  bool shouldRepaint(EarthPlantsPainter old) => true;
}
