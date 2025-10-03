import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ---- FireFX: widget that owns controller + composited paint ----
class FireFX extends StatefulWidget {
  const FireFX({
    super.key,
    this.intensity = 1.0,
    this.turbulence = 1.2,
    this.rise = 0.65,
    this.noiseScale = 2.1,
    this.softEdge = 0.22,
    this.primaryColor = const Color(0xFFFFA000), // for embers
    this.secondaryColor = const Color(0xFFFF5722), // for embers
    this.speedFactor = 1.0,
    this.blendOnTop = true,
  });

  final double intensity;
  final double turbulence;
  final double rise;
  final double noiseScale;
  final double softEdge;
  final Color primaryColor;
  final Color secondaryColor;
  final double speedFactor;
  final bool blendOnTop;

  @override
  State<FireFX> createState() => _FireFXState();
}

class _FireFXState extends State<FireFX> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  // Reused paints to avoid per-frame allocs
  final Paint _shaderPaint = Paint()..blendMode = BlendMode.plus;
  final Paint _bgClear = Paint()..blendMode = BlendMode.srcOver;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'assets/shaders/fire.frag',
    );
    setState(() {
      _program = program;
      _shader = program.fragmentShader();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _timeSeconds() =>
      (_controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            isComplex: true,
            willChange: true,
            painter: _FireShaderPainter(
              time: _timeSeconds() * widget.speedFactor,
              shader: _shader,
              intensity: widget.intensity,
              turbulence: widget.turbulence,
              rise: widget.rise,
              noiseScale: widget.noiseScale,
              softEdge: widget.softEdge,
              shaderPaint: _shaderPaint,
              bgPaint: _bgClear,
              blendOnTop: widget.blendOnTop,
            ),
            foregroundPainter: FireEmbersPainter(
              controller: _controller,
              speedFactor: widget.speedFactor,
              primaryColor: widget.primaryColor,
              secondaryColor: widget.secondaryColor,
            ),
          );
        },
      ),
    );
  }
}

// ---- Shader-backed painter ----
class _FireShaderPainter extends CustomPainter {
  _FireShaderPainter({
    required this.time,
    required this.shader,
    required this.intensity,
    required this.turbulence,
    required this.rise,
    required this.noiseScale,
    required this.softEdge,
    required this.shaderPaint, // can keep, but we'll not pass it to saveLayer
    required this.bgPaint,
    required this.blendOnTop,
  });

  final double time;
  final ui.FragmentShader? shader;
  final double intensity, turbulence, rise, noiseScale, softEdge;
  final Paint shaderPaint; // holds BlendMode.plus (that’s fine)
  final Paint bgPaint; // srcOver
  final bool blendOnTop;

  @override
  void paint(Canvas canvas, Size size) {
    if (shader == null) return;

    // ---- uniforms (guard zero sizes)
    final width = size.width <= 0 ? 1.0 : size.width;
    final height = size.height <= 0 ? 1.0 : size.height;
    final aspect = height == 0 ? 1.0 : width / height;

    shader!
      ..setFloat(0, time)
      ..setFloat(1, noiseScale)
      ..setFloat(2, rise)
      ..setFloat(3, turbulence)
      ..setFloat(4, intensity) // uBrightness
      ..setFloat(5, aspect) // uAspect (guarded)
      ..setFloat(6, softEdge)
      ..setFloat(7, width) // uWidth  (non-zero!)
      ..setFloat(8, height) // uHeight (non-zero!)
      ..setFloat(9, 0.2) // uBandTop
      ..setFloat(10, 0.4); // uBandFeather

    // ---- separate paints:
    // 1) Layer paint: only blend mode (no shader attached here)
    final layerPaint = Paint()..blendMode = BlendMode.srcOver;

    // 2) Draw paint: only the shader
    final drawPaint = Paint()..shader = shader;

    final bounds = Offset.zero & size;

    // You can even skip saveLayer while testing:
    // canvas.drawRect(bounds, drawPaint);

    canvas.saveLayer(bounds, layerPaint);
    canvas.drawRect(bounds, drawPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FireShaderPainter old) =>
      old.time != time ||
      old.shader != shader ||
      old.intensity != intensity ||
      old.turbulence != turbulence ||
      old.rise != rise ||
      old.noiseScale != noiseScale ||
      old.softEdge != softEdge ||
      old.blendOnTop != blendOnTop;
}

// ---- Lightweight ember particles (your code, tuned a bit) ----
class FireEmbersPainter extends CustomPainter {
  final AnimationController controller;
  final double speedFactor;
  final Color primaryColor;
  final Color secondaryColor;

  FireEmbersPainter({
    required this.controller,
    required this.primaryColor,
    required this.secondaryColor,
    this.speedFactor = 1.0,
  }) : super(repaint: controller);

  double _timeSeconds() =>
      (controller.lastElapsedDuration ?? Duration.zero).inMicroseconds / 1e6;

  // Fast hash-based seeded "random" (deterministic)
  double _seededRandom(int i, int salt) {
    final n = (i * 73856093) ^ (salt * 19349663);
    final s = math.sin(n.toDouble()) * 43758.5453123;
    return s - s.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = _timeSeconds() * speedFactor;

    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final emberPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 42; i++) {
      final randomX = _seededRandom(i, 0);
      final speed = 0.35 + _seededRandom(i, 1) * 0.45;
      final sway = _seededRandom(i, 2) * 55 - 27.5;
      final stagger = _seededRandom(i, 4);

      final phase = t * speed + stagger;
      final u = phase - phase.floor();

      final x = randomX * size.width + math.sin(phase * 2 * math.pi) * sway;

      final fadeZone = size.height * 0.15;
      final totalRange = size.height + fadeZone * 2;
      final yStart = size.height + fadeZone;
      final y = yStart - (u * totalRange);

      final emberSize = 1.6 + _seededRandom(i, 3) * 2.4;

      double fadeOpacity = 1.0;
      if (y > size.height - fadeZone && y <= size.height) {
        fadeOpacity = (size.height - y) / fadeZone;
      } else if (y < fadeZone && y >= 0) {
        fadeOpacity = y / fadeZone;
      } else if (y < 0 || y > size.height) {
        fadeOpacity = 0.0;
      }

      if (fadeOpacity > 0) {
        final flicker = 0.85 + math.sin(phase * 8 * math.pi) * 0.15;
        final opacity = fadeOpacity * 0.85 * flicker;

        final color = (i % 2 == 0 ? primaryColor : secondaryColor).withOpacity(
          opacity,
        );
        emberPaint.color = color;
        canvas.drawCircle(Offset(x, y), emberSize, emberPaint);

        glowPaint.color = primaryColor.withOpacity(opacity * 0.35);
        canvas.drawCircle(Offset(x, y), emberSize * 2.3, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(FireEmbersPainter old) => true;
}
