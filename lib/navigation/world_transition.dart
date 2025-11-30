import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Configuration for the Warp Portal effect
class VoidPortalConfig {
  const VoidPortalConfig({
    this.duration = const Duration(milliseconds: 700),
    this.starCount = 80,
    this.color = const Color(0xFF000000),
    this.starColor = const Color(0xFFFFFFFF),
    this.dimStarColor = const Color(0xFF888888),
    this.showGlow = true,
    this.enableBlur = true,
  });

  final Duration duration;
  final int starCount;
  final Color color;
  final Color starColor;
  final Color dimStarColor;
  final bool showGlow;
  final bool enableBlur;

  /// Get effective star count (reduced on Android)
  int get effectiveStarCount {
    if (_isAndroid) {
      return (starCount * 0.6).round().clamp(30, 50);
    }
    return starCount;
  }

  /// Check if blur should be enabled (disabled on Android by default)
  bool get effectiveBlur => enableBlur && !_isAndroid;

  static bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false; // Web or other platform
    }
  }

  /// Standard black hole with stars
  static const standard = VoidPortalConfig();

  /// More stars, slower
  static const cinematic = VoidPortalConfig(
    duration: Duration(milliseconds: 1000),
    starCount: 120,
  );

  /// Fast and snappy
  static const quick = VoidPortalConfig(
    duration: Duration(milliseconds: 400),
    starCount: 60,
  );

  /// Optimized for low-end devices
  static const performance = VoidPortalConfig(
    duration: Duration(milliseconds: 500),
    starCount: 40,
    showGlow: false,
    enableBlur: false,
  );
}

/// Main portal utility class
class VoidPortal {
  VoidPortal._();

  /// Push a page with portal animation (no orientation change)
  static Future<T?> push<T>(
    BuildContext context, {
    required Widget page,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    final navigator = Navigator.of(context);
    T? result;

    final handle = _showPortalWarp(
      context,
      config: config,
      onMidpoint: () async {
        result = await navigator.push<T>(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => page,
          ),
        );
      },
    );

    await handle.future;
    return result;
  }

  /// Pop the current page behind a portal
  static Future<void> pop<T>(
    BuildContext context, {
    T? result,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    final navigator = Navigator.of(context);

    final handle = _showPortalWarp(
      context,
      config: config,
      onMidpoint: () {
        navigator.pop(result);
      },
    );

    await handle.future;
  }

  /// Push a page and force Landscape orientation seamlessly
  static Future<T?> pushLandscape<T>(
    BuildContext context, {
    required Widget page,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    return pushWithOrientation(
      context,
      page: page,
      targetOrientation: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
      config: config,
    );
  }

  /// Push a page with specific orientation changes
  static Future<T?> pushWithOrientation<T>(
    BuildContext context, {
    required Widget page,
    required List<DeviceOrientation> targetOrientation,
    required List<DeviceOrientation> returnOrientation,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    final navigator = Navigator.of(context);
    T? result;

    final handleIn = _showPortalWarp(
      context,
      config: config,
      onMidpoint: () async {
        await SystemChrome.setPreferredOrientations(targetOrientation);

        result = await navigator.push<T>(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => page,
          ),
        );

        await SystemChrome.setPreferredOrientations(returnOrientation);
      },
    );
    await handleIn.future;

    return result;
  }

  /// Just play the animation (useful for dramatic reveals, etc.)
  static Future<void> playEffect(
    BuildContext context, {
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    final handle = _showPortalWarp(context, config: config, onMidpoint: () {});
    await handle.future;
  }

  /// Show portal in, execute async work, then portal out
  static Future<T> wrapAsync<T>(
    BuildContext context, {
    required Future<T> Function() work,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    late T result;

    final handle = _showPortalWarp(
      context,
      config: config,
      onMidpoint: () async {
        result = await work();
      },
    );

    await handle.future;
    return result;
  }
}

// ============================================================================
// Internal Implementation (Optimized for 60FPS)
// ============================================================================

_PortalHandle _showPortalWarp(
  BuildContext context, {
  required VoidPortalConfig config,
  required FutureOr<void> Function() onMidpoint,
}) {
  final overlay = Navigator.of(context).overlay!;
  late OverlayEntry entry;
  final handle = _PortalHandle();

  entry = OverlayEntry(
    builder: (_) => _WarpEffectOverlay(
      config: config,
      onMidpoint: onMidpoint,
      onComplete: () {
        entry.remove();
        handle._complete();
      },
    ),
  );

  overlay.insert(entry);
  return handle;
}

class _PortalHandle {
  final _completer = Completer<void>();
  Future<void> get future => _completer.future;
  void _complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

class _WarpEffectOverlay extends StatefulWidget {
  const _WarpEffectOverlay({
    required this.config,
    required this.onMidpoint,
    required this.onComplete,
  });

  final VoidPortalConfig config;
  final FutureOr<void> Function() onMidpoint;
  final VoidCallback onComplete;

  @override
  State<_WarpEffectOverlay> createState() => _WarpEffectOverlayState();
}

class _WarpEffectOverlayState extends State<_WarpEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final _WarpPainterData _painterData;
  bool _midpointFired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.config.duration,
    );

    // Pre-generate all data once
    _painterData = _WarpPainterData.generate(widget.config);

    _controller.addListener(_tick);
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  void _tick() {
    if (!_midpointFired && _controller.value >= 0.5) {
      _midpointFired = true;
      widget.onMidpoint();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: size,
              painter: _WarpPainter(
                progress: _controller.value,
                data: _painterData,
                size: size,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ----------------------------------------------------------------------------
// Pre-computed Data Structures
// ----------------------------------------------------------------------------

class _Star {
  final double angle;
  final double cosAngle;
  final double sinAngle;
  final double distance; // Starting distance from center (0.0 - 1.0)
  final double size;
  final double speedVariance;
  final double brightness; // 0.0 - 1.0

  _Star({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speedVariance,
    required this.brightness,
  }) : cosAngle = math.cos(angle),
       sinAngle = math.sin(angle);

  factory _Star.random(math.Random r) {
    return _Star(
      angle: r.nextDouble() * math.pi * 2,
      distance: 0.1 + r.nextDouble() * 0.9, // Spread across the screen
      size: 0.1 + r.nextDouble(), // Small dots
      speedVariance: 0.5 + r.nextDouble() * 1.0,
      brightness: 0.3 + r.nextDouble() * 0.7,
    );
  }
}

/// Pre-computed painter data to avoid allocations during paint
class _WarpPainterData {
  final VoidPortalConfig config;
  final List<_Star> stars;

  // Pre-computed colors at various opacities
  final List<Color> starOpacities;
  final List<Color> dimStarOpacities;

  // Reusable paint objects
  final Paint backgroundPaint;
  final Paint starPaint;
  final Paint glowPaint;

  _WarpPainterData._({
    required this.config,
    required this.stars,
    required this.starOpacities,
    required this.dimStarOpacities,
    required this.backgroundPaint,
    required this.starPaint,
    required this.glowPaint,
  });

  factory _WarpPainterData.generate(VoidPortalConfig config) {
    final random = math.Random();

    // Generate stars
    final stars = List.generate(
      config.effectiveStarCount,
      (_) => _Star.random(random),
    );

    // Pre-compute opacity variants
    final starOpacities = List.generate(
      21,
      (i) => config.starColor.withOpacity(i / 20),
    );
    final dimStarOpacities = List.generate(
      21,
      (i) => config.dimStarColor.withOpacity(i / 20),
    );

    // Create reusable paints
    final backgroundPaint = Paint();
    final starPaint = Paint();
    final glowPaint = Paint();

    return _WarpPainterData._(
      config: config,
      stars: stars,
      starOpacities: starOpacities,
      dimStarOpacities: dimStarOpacities,
      backgroundPaint: backgroundPaint,
      starPaint: starPaint,
      glowPaint: glowPaint,
    );
  }

  Color getStarWithOpacity(double opacity) {
    final index = (opacity.clamp(0.0, 1.0) * 20).round();
    return starOpacities[index];
  }

  Color getDimStarWithOpacity(double opacity) {
    final index = (opacity.clamp(0.0, 1.0) * 20).round();
    return dimStarOpacities[index];
  }
}

// ----------------------------------------------------------------------------
// Optimized Painter
// ----------------------------------------------------------------------------

class _WarpPainter extends CustomPainter {
  _WarpPainter({
    required this.progress,
    required this.data,
    required this.size,
  });

  final double progress;
  final _WarpPainterData data;
  final Size size;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxDist =
        math.sqrt(size.width * size.width + size.height * size.height) * 0.7;

    final bool isWarpingIn = progress < 0.5;
    final double t = isWarpingIn ? progress * 2 : (progress - 0.5) * 2;
    final double easedT = isWarpingIn ? _easeInQuad(t) : _easeOutQuad(t);

    // 1. Black background
    _drawBackground(canvas, size, easedT, isWarpingIn);

    // 2. Stars being pulled into/out of the void
    _drawStars(canvas, centerX, centerY, maxDist, easedT, isWarpingIn);

    // 3. Subtle center glow (white, like a distant light)
    if (data.config.showGlow) {
      _drawCenterGlow(canvas, centerX, centerY, easedT, isWarpingIn);
    }
  }

  void _drawBackground(Canvas canvas, Size size, double t, bool isWarpingIn) {
    final opacity = isWarpingIn ? t : (1.0 - t);
    if (opacity <= 0) return;

    data.backgroundPaint
      ..shader = null
      ..color = data.config.color.withOpacity(opacity);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      data.backgroundPaint,
    );
  }

  void _drawStars(
    Canvas canvas,
    double centerX,
    double centerY,
    double maxDist,
    double t,
    bool isWarpingIn,
  ) {
    for (final star in data.stars) {
      // Calculate star position - moving toward or away from center
      double distanceRatio;
      double alpha;
      double currentSize;

      if (isWarpingIn) {
        // Stars rush toward center
        final adjustedT = (t * star.speedVariance).clamp(0.0, 1.0);
        distanceRatio = star.distance * (1.0 - _easeInCubic(adjustedT));
        alpha = star.brightness * (0.3 + adjustedT * 0.7);
        // Stars stretch slightly as they accelerate
        currentSize = star.size * (1.0 + adjustedT * 2.0);
      } else {
        // Stars rush away from center
        final adjustedT = (t * star.speedVariance).clamp(0.0, 1.0);
        distanceRatio = star.distance * _easeOutCubic(adjustedT);
        alpha = star.brightness * (1.0 - adjustedT * 0.7);
        currentSize = star.size * (3.0 - adjustedT * 2.0);
      }

      if (alpha <= 0.05 || distanceRatio <= 0) continue;

      final dist = maxDist * distanceRatio;
      final x = centerX + star.cosAngle * dist;
      final y = centerY + star.sinAngle * dist;

      // Draw star as a small circle
      final starColor = star.brightness > 0.6
          ? data.getStarWithOpacity(alpha)
          : data.getDimStarWithOpacity(alpha);

      data.starPaint
        ..color = starColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), currentSize, data.starPaint);

      // Add subtle glow to bright stars
      if (data.config.enableBlur && star.brightness > 0.7 && alpha > 0.5) {
        data.starPaint
          ..color = data.getStarWithOpacity(alpha * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(x, y), currentSize * 1.5, data.starPaint);
        data.starPaint.maskFilter = null;
      }
    }
  }

  void _drawCenterGlow(
    Canvas canvas,
    double centerX,
    double centerY,
    double t,
    bool isWarpingIn,
  ) {
    final glowIntensity = isWarpingIn ? t : (1.0 - t);
    if (glowIntensity <= 0) return;

    // Soft white glow at center
    data.glowPaint
      ..shader =
          RadialGradient(
            colors: [
              data.getStarWithOpacity(glowIntensity * 0.4),
              data.getStarWithOpacity(glowIntensity * 0.1),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: 100),
          );

    canvas.drawCircle(Offset(centerX, centerY), 100, data.glowPaint);
  }

  // Inline easing functions
  static double _easeInCubic(double t) => t * t * t;
  static double _easeOutCubic(double t) {
    final t1 = t - 1;
    return t1 * t1 * t1 + 1;
  }

  static double _easeInQuad(double t) => t * t;
  static double _easeOutQuad(double t) => t * (2 - t);

  @override
  bool shouldRepaint(_WarpPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
