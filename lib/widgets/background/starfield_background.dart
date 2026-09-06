import 'dart:math' as math;
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

/// A reusable starfield background — soft twinkling stars on a dark base,
/// with optional nebula glow tint. Drop it behind any screen that should
/// share the constellation visual language.
///
/// Wrap your content in a [Stack] or use [StarfieldBackgroundScaffold]
/// which embeds this beneath a transparent [Scaffold].
class StarfieldBackground extends StatefulWidget {
  /// Solid backdrop behind the stars. Defaults to deep space black.
  final Color baseColor;

  /// Optional tint for the nebula glow. Null = no nebula.
  final Color? nebulaColor;

  /// How many stars to render. Mobile-friendly default.
  final int starCount;

  const StarfieldBackground({
    super.key,
    this.baseColor = const Color(0xFF050810),
    this.nebulaColor,
    this.starCount = 140,
  });

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _stars = List.generate(widget.starCount, (i) {
      final layer = i < widget.starCount * 0.65
          ? _StarLayer.far
          : (i < widget.starCount * 0.92 ? _StarLayer.mid : _StarLayer.near);
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: layer == _StarLayer.far
            ? 0.6 + rng.nextDouble() * 0.8
            : layer == _StarLayer.mid
            ? 1.0 + rng.nextDouble() * 0.9
            : 1.6 + rng.nextDouble() * 1.2,
        baseOpacity: layer == _StarLayer.far
            ? 0.18 + rng.nextDouble() * 0.18
            : layer == _StarLayer.mid
            ? 0.32 + rng.nextDouble() * 0.28
            : 0.55 + rng.nextDouble() * 0.35,
        twinkleSpeed: 0.4 + rng.nextDouble() * 1.4,
        phase: rng.nextDouble() * math.pi * 2,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _StarfieldPainter(
              stars: _stars,
              time: _controller.value * 60.0,
              baseColor: widget.baseColor,
              nebulaColor: widget.nebulaColor,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

enum _StarLayer { far, mid, near }

class _Star {
  final double x; // 0..1 normalized
  final double y;
  final double size;
  final double baseOpacity;
  final double twinkleSpeed;
  final double phase;

  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.baseOpacity,
    required this.twinkleSpeed,
    required this.phase,
  });
}

class _StarfieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double time;
  final Color baseColor;
  final Color? nebulaColor;

  _StarfieldPainter({
    required this.stars,
    required this.time,
    required this.baseColor,
    required this.nebulaColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);

    if (nebulaColor != null) {
      final nebula = Paint()
        ..shader = RadialGradient(
          colors: [
            nebulaColor!.withValues(alpha: 0.18),
            nebulaColor!.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, nebula);
    }

    final starPaint = Paint();
    for (final s in stars) {
      final twinkle = math.sin(time * s.twinkleSpeed + s.phase);
      final variation =
          math.sin(time * s.twinkleSpeed * 0.7 + s.phase + 1.0) * 0.3;
      final factor = (0.55 + (twinkle + variation) * 0.45).clamp(0.0, 1.0);
      starPaint.color = Colors.white.withValues(
        alpha: (s.baseOpacity * factor).clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.size,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) =>
      old.time != time ||
      old.baseColor != baseColor ||
      old.nebulaColor != nebulaColor;
}

/// Scaffold wrapper that places a [StarfieldBackground] behind a transparent
/// [Scaffold]. Use this for screens that should share the constellation
/// visual language (progress, milestones, etc).
class StarfieldBackgroundScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? nebulaColor;
  final Color baseColor;

  const StarfieldBackgroundScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.nebulaColor,
    this.baseColor = const Color(0xFF050810),
  });

  @override
  Widget build(BuildContext context) {
    // A starfield is dark by definition, so this scaffold pins its subtree to
    // the dark faction theme regardless of the app's light/dark setting.
    // Without this, running the app in light mode painted near-black inherited
    // text straight onto the star field.
    return ForcedFactionBrightness(
      brightness: Brightness.dark,
      child: Stack(
        children: [
          Positioned.fill(
            child: StarfieldBackground(
              baseColor: baseColor,
              nebulaColor: nebulaColor,
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: appBar,
            body: body,
          ),
        ],
      ),
    );
  }
}
