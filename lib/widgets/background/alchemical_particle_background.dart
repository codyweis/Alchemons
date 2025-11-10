// widgets/alchemical_particle_background.dart
import 'dart:math';
import 'package:flutter/material.dart';

// -----------------------------------------------------------------
// 1. ADD THIS GLOBAL OBSERVER
// We need this so any "RouteAware" widget can subscribe to it.
// You can place this at the top of the file, outside the class.
// -----------------------------------------------------------------
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

// 2. Define the properties of a single particle
class _Particle {
  double baseX;
  double baseY;
  final double vx;
  final double vy;
  double angleX;
  double angleY;
  final double speedX;
  final double speedY;
  final double amplitudeX;
  final double amplitudeY;
  final Color color;
  final double radius;
  double opacity;
  double x = 0;
  double y = 0;

  _Particle({
    required this.baseX,
    required this.baseY,
    required this.vx,
    required this.vy,
    required this.angleX,
    required this.angleY,
    required this.speedX,
    required this.speedY,
    required this.amplitudeX,
    required this.amplitudeY,
    required this.color,
    required this.radius,
    required this.opacity,
  });
}

// 3. The main StatefulWidget
class AlchemicalParticleBackground extends StatefulWidget {
  const AlchemicalParticleBackground({
    super.key,
    this.opacity = 1.0,
    this.colors,
    this.backgroundColor,
    this.whiteBackground = false, // NEW PARAM
  });

  /// Global alpha for the whole layer (0..1)
  final double opacity;

  /// Optional solid background color behind particles
  final Color? backgroundColor;

  /// Override palette if desired (e.g., cooler at night)
  final List<Color>? colors;

  /// Convenience flag to render a white background.
  /// If [backgroundColor] is provided, it takes precedence.
  final bool whiteBackground; // NEW PARAM

  @override
  State<AlchemicalParticleBackground> createState() =>
      _AlchemicalParticleBackgroundState();
}

// 4. The State (THIS IS WHERE THE CHANGES ARE)
class _AlchemicalParticleBackgroundState
    extends State<AlchemicalParticleBackground>
    with SingleTickerProviderStateMixin, RouteAware {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();
  bool _isInitialized = false;

  static const List<Color> _particleColors = [
    Colors.cyanAccent,
    Colors.deepPurpleAccent,
    Colors.greenAccent,
    Color(0xFF00BFFF),
    Color(0xFF9400D3),
    Color.fromARGB(255, 172, 113, 57),
    Color.fromARGB(255, 255, 82, 59),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _controller.addListener(_updateParticles);
    _controller.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _controller.stop();
  }

  @override
  void didPopNext() {
    _controller.repeat();
  }

  void _initializeParticles(Size size) {
    final palette = widget.colors ?? _particleColors;
    if (_isInitialized) return;

    final particleCount = (size.width * size.height * 0.0002)
        .clamp(150, 500)
        .toInt();

    for (int i = 0; i < particleCount; i++) {
      _particles.add(
        _Particle(
          baseX: _random.nextDouble() * size.width,
          baseY: _random.nextDouble() * size.height,
          vx: (_random.nextDouble() - 0.5) * 0.15,
          vy: (_random.nextDouble() - 0.5) * 0.15,
          angleX: _random.nextDouble() * 2 * pi,
          angleY: _random.nextDouble() * 2 * pi,
          speedX: (_random.nextDouble() * 0.02) + 0.005,
          speedY: (_random.nextDouble() * 0.02) + 0.005,
          amplitudeX: _random.nextDouble() * 20 + 10,
          amplitudeY: _random.nextDouble() * 20 + 10,
          color: palette[_random.nextInt(palette.length)],
          radius: _random.nextDouble() * 1.5 + 0.5,
          opacity: _random.nextDouble() * 0.5 + 0.2,
        ),
      );
    }

    _isInitialized = true;
  }

  void _updateParticles() {
    if (!_isInitialized) return;
    final size = context.size;
    if (size == null) return;

    setState(() {
      for (final p in _particles) {
        p.baseX += p.vx;
        p.baseY += p.vy;
        p.angleX += p.speedX;
        p.angleY += p.speedY;
        p.x = p.baseX + sin(p.angleX) * p.amplitudeX;
        p.y = p.baseY + cos(p.angleY) * p.amplitudeY;

        if (p.baseX < -p.amplitudeX) {
          p.baseX = size.width + p.amplitudeX;
        } else if (p.baseX > size.width + p.amplitudeX) {
          p.baseX = -p.amplitudeX;
        }
        if (p.baseY < -p.amplitudeY) {
          p.baseY = size.height + p.amplitudeY;
        } else if (p.baseY > size.height + p.amplitudeY) {
          p.baseY = -p.amplitudeY;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _initializeParticles(Size(constraints.maxWidth, constraints.maxHeight));

        final painter = _ParticlePainter(
          particles: _particles,
          globalOpacity: widget.opacity,
        );

        Widget layer = CustomPaint(size: Size.infinite, painter: painter);

        // Prefer explicit backgroundColor; otherwise whiteBackground if true
        final Color? effectiveBg =
            widget.backgroundColor ??
            (widget.whiteBackground ? Colors.white : null);

        if (effectiveBg != null) {
          layer = ColoredBox(color: effectiveBg, child: layer);
        }

        return layer;
      },
    );
  }
}

// 5. The CustomPainter
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Paint _paint = Paint();
  final double globalOpacity;

  _ParticlePainter({required this.particles, required this.globalOpacity});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.largest, Paint());
    for (final p in particles) {
      _paint.color = p.color.withOpacity(p.opacity * globalOpacity);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, _paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
