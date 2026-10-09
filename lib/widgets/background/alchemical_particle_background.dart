// widgets/alchemical_particle_background.dart
import 'dart:math';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
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

  /// Which batch it is drawn in: its color, size and strength.
  final int bucket;
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
    required this.bucket,
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
    this.densityMultiplier = 1.0,
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

  /// Scale the particle count without changing the visual system behavior.
  final double densityMultiplier;

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
  Size? _lastSize;

  /// The palette the motes were made from, and their batches: one point
  /// draw per color, size and strength rather than a circle per mote.
  List<Color> _palette = _particleColors;
  GrainBatch _batch = GrainBatch(_particleColors.length * _MoteLook.count);

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
    if (_isInitialized) return;
    final palette = widget.colors ?? _particleColors;
    if (palette.length != _palette.length) {
      _batch = GrainBatch(palette.length * _MoteLook.count);
    }
    _palette = palette;

    final particleCount =
        ((size.width * size.height * 0.0002) * widget.densityMultiplier)
            .clamp(40, 500)
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
          bucket:
              _random.nextInt(palette.length) * _MoteLook.count +
              _random.nextInt(_MoteLook.count),
        ),
      );
    }

    _isInitialized = true;
  }

  void _resetForSize(Size size) {
    _particles.clear();
    _isInitialized = false;
    _initializeParticles(size);
  }

  void _updateParticles() {
    if (!_isInitialized) return;
    final size = _lastSize;
    if (size == null) return;

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
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final last = _lastSize;
        final sizeChanged =
            last != null &&
            ((last.width - size.width).abs() > 1.0 ||
                (last.height - size.height).abs() > 1.0);
        if (sizeChanged) {
          _resetForSize(size);
        }
        _lastSize = size;
        _initializeParticles(size);

        final painter = _ParticlePainter(
          particles: _particles,
          palette: _palette,
          batch: _batch,
          globalOpacity: widget.opacity,
          repaint: _controller,
        );

        // The painter repaints every frame off [_controller]. Without a
        // boundary of its own it marks the nearest ancestor boundary dirty —
        // which, sitting as a bare Stack sibling of the screen's Scaffold, is
        // the whole screen. Every scrolling list drawn above this background
        // would be re-recorded 60x/s for the sake of a few drifting motes.
        Widget layer = RepaintBoundary(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: painter,
            ),
          ),
        );

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

/// The sizes and strengths a mote can have: a small faint one, a small
/// bright one, a large faint one and a large bright one, spanning what the
/// motes used to pick from at random (radius 0.5–2, alpha 0.2–0.7).
abstract final class _MoteLook {
  static const int count = 4;
  static double radius(int look) => look < 2 ? 0.875 : 1.625;
  static double alpha(int look) => look.isEven ? 0.325 : 0.575;
}

// 5. The CustomPainter
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final List<Color> palette;
  final GrainBatch batch;
  final double globalOpacity;

  _ParticlePainter({
    required this.particles,
    required this.palette,
    required this.batch,
    required this.globalOpacity,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final b = batch..clear();
    for (final p in particles) {
      b.add(p.bucket, p.x, p.y);
    }
    for (var c = 0; c < palette.length; c++) {
      for (var look = 0; look < _MoteLook.count; look++) {
        b.draw(
          canvas,
          c * _MoteLook.count + look,
          _MoteLook.radius(look) * 2,
          palette[c].withValues(alpha: _MoteLook.alpha(look) * globalOpacity),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.palette != palette ||
      oldDelegate.globalOpacity != globalOpacity;
}
