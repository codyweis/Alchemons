import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_portal.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, Ticker;
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

/// For a page entered through [VoidPortal.pushThroughGlyphs]: flips its
/// `revealReady` notifier the first time [isReady] returns true, so the
/// portal reveals a built page rather than a spinner. Polls every 50ms.
///
/// Create it in `initState`, dispose it in `dispose` — disposing also
/// reports ready, so a page that goes away never leaves a portal waiting.
class RevealWhenReady {
  RevealWhenReady(this.notifier, this.isReady) {
    final notifier = this.notifier;
    if (notifier == null || notifier.value) return;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!isReady()) return;
      timer.cancel();
      notifier.value = true;
    });
  }

  final ValueNotifier<bool>? notifier;
  final bool Function() isReady;
  Timer? _timer;

  void dispose() {
    _timer?.cancel();
    notifier?.value = true;
  }
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

  /// Push [page] through the glyph portal — the same tunnel of alchemical
  /// script the planet descents use, spelling [title] around its rings.
  ///
  /// The portal fades up over the current screen and pushes [page] once it
  /// fully covers it. With an [orientation] change it goes through black
  /// instead: the screen dips to black, the rotation, the push and the
  /// re-layout they force all happen while nothing on screen is moving, and
  /// only once that has settled does the portal start — a rotation hitches
  /// badly enough that it must never land mid-animation. Either way it then
  /// STAYS until [ready] turns true (or a safety timeout passes), so a
  /// page that needs a moment to load is revealed already built — the portal
  /// is its loading screen. Pass no [ready] for a page that is instant.
  ///
  /// [element] picks one of the 17 elemental twists and palettes ('' for
  /// the plain portal).
  ///
  /// Pass [orientation] to switch orientation while the portal covers the
  /// screen; [returnOrientation] is restored when the page is popped. The
  /// switch is hidden: the window is locked to `orientation.first` (so the
  /// rotation is known), the system's rotation animation is turned off, and
  /// the portal counter-rotates itself so it stays upright in the player's
  /// hand. The full [orientation] list is allowed again once revealed.
  ///
  /// Unlike [push], the returned future completes with the route's result
  /// when the page is popped.
  static Future<T?> pushThroughGlyphs<T>(
    BuildContext context, {
    required Widget page,
    required String title,
    String label = 'ENTERING',
    String element = '',
    ValueListenable<bool>? ready,
    List<Color>? palette,
    Color? tint,
    List<DeviceOrientation>? orientation,
    List<DeviceOrientation>? returnOrientation,
  }) {
    final navigator = Navigator.of(context);
    final routeResult = Completer<T?>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GlyphPortalOverlay(
        title: title,
        label: label,
        element: element,
        throughBlack: orientation != null,
        ready: ready,
        palette: palette,
        tint: tint,
        counterTurns: switch (orientation?.first) {
          DeviceOrientation.landscapeLeft => 3,
          DeviceOrientation.landscapeRight => 1,
          _ => 0,
        },
        onCovered: () async {
          try {
            if (orientation != null && orientation.isNotEmpty) {
              await _setSeamlessRotation(true);
              await SystemChrome.setPreferredOrientations([orientation.first]);
            }
            navigator
                .push<T>(
                  PageRouteBuilder(
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, __, ___) => page,
                  ),
                )
                .then((result) async {
                  if (returnOrientation != null) {
                    await SystemChrome.setPreferredOrientations(
                      returnOrientation,
                    );
                  }
                  routeResult.complete(result);
                }, onError: routeResult.completeError);
          } catch (e, st) {
            routeResult.completeError(e, st);
          }
        },
        onComplete: () {
          entry.remove();
          if (orientation != null && orientation.length > 1) {
            unawaited(SystemChrome.setPreferredOrientations(orientation));
          }
          if (orientation != null) unawaited(_setSeamlessRotation(false));
        },
      ),
    );
    navigator.overlay!.insert(entry);
    return routeResult.future;
  }

  /// Play the glyph portal over the current screen without navigating — for
  /// a change that happens IN a screen (starting a survival run).
  ///
  /// [onCovered] runs once the portal fully covers the screen; build the new
  /// state there. The portal then holds until [ready] turns true (or a
  /// safety timeout), and [onReveal] runs the moment it starts to fade — the
  /// first instant the player can see, so start anything time-sensitive
  /// there. The returned future completes when the portal has gone.
  static Future<void> coverWithGlyphs(
    BuildContext context, {
    required String title,
    required Future<void> Function() onCovered,
    VoidCallback? onReveal,
    String label = 'ENTERING',
    String element = '',
    ValueListenable<bool>? ready,
    List<Color>? palette,
    Color? tint,
  }) {
    final overlay = Navigator.of(context).overlay!;
    final done = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GlyphPortalOverlay(
        title: title,
        label: label,
        element: element,
        throughBlack: false,
        counterTurns: 0,
        ready: ready,
        palette: palette,
        tint: tint,
        onCovered: onCovered,
        onReveal: onReveal,
        onComplete: () {
          entry.remove();
          done.complete();
        },
      ),
    );
    overlay.insert(entry);
    return done.future;
  }

  static const MethodChannel _rotationChannel = MethodChannel(
    'alchemons/rotation',
  );

  /// Android only (MainActivity): suppress the system rotation animation
  /// while a transition hides the orientation change itself.
  static Future<void> _setSeamlessRotation(bool on) async {
    try {
      await _rotationChannel.invokeMethod<void>('setSeamless', on);
    } on MissingPluginException {
      // iOS / tests: the platform rotates the way it always has.
    } on PlatformException {
      // Same — never let a cosmetic hook break navigation.
    }
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
// Glyph portal overlay
// ============================================================================

class _GlyphPortalOverlay extends StatefulWidget {
  const _GlyphPortalOverlay({
    required this.title,
    required this.label,
    required this.element,
    required this.throughBlack,
    required this.counterTurns,
    required this.ready,
    required this.palette,
    required this.tint,
    required this.onCovered,
    required this.onComplete,
    this.onReveal,
  });

  final String title;
  final String label;
  final String element;

  /// Dip to black and do the push (and orientation switch) there before the
  /// portal starts. Off: the portal fades straight in over the old screen.
  final bool throughBlack;

  /// Quarter turns (clockwise) that keep the portal upright in the player's
  /// hand once the window has switched to the target landscape. 0 = none.
  final int counterTurns;
  final ValueListenable<bool>? ready;
  final List<Color>? palette;
  final Color? tint;

  /// Starts the orientation switch and the push; completes once both have
  /// been started (not when the page is popped).
  final Future<void> Function() onCovered;

  /// Runs once, the moment the portal starts to fade out.
  final VoidCallback? onReveal;
  final VoidCallback onComplete;

  @override
  State<_GlyphPortalOverlay> createState() => _GlyphPortalOverlayState();
}

class _GlyphPortalOverlayState extends State<_GlyphPortalOverlay>
    with SingleTickerProviderStateMixin {
  static const Color _void = Color(0xFF050507);

  /// The old screen dips to black in this long (through-black only).
  static const double _blackoutSeconds = 0.25;

  /// The portal fades straight in over the old screen in this long, and the
  /// page is pushed once it is opaque (direct only).
  static const double _coverSeconds = 0.4;

  /// How long to wait for the window to report its new orientation before
  /// starting the portal anyway.
  static const double _settleTimeoutSeconds = 1.0;

  /// Frames left to absorb the push and re-layout while still black.
  static const int _settleFrames = 3;

  /// Through-black: the portal fades up out of the black over this long.
  static const double _portalInSeconds = 0.25;

  /// The shortest the portal plays before revealing, even for a page that is
  /// ready instantly — long enough for the rings to gather and start rushing.
  static const double _minPortalSeconds = 1.1;

  /// Reveal regardless after this (wall time), so a page that never reports
  /// ready cannot trap the player behind the portal.
  static const double _timeoutSeconds = 8.0;

  static const double _fadeSeconds = 0.5;

  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  double _now = 0;
  bool _switchStarted = false;

  /// Wall time the portal animation began; null while still black.
  double? _portalStart;
  double? _fadeStart;
  bool _done = false;

  /// Whether the screen was portrait when the transition began, and whether
  /// it is now. Counter-rotation only applies once the window has flipped.
  bool? _startedPortrait;
  bool _portraitNow = true;

  @override
  void initState() {
    super.initState();
    if (!widget.throughBlack) _portalStart = 0;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_done) return;
    final t = _now = elapsed.inMicroseconds / 1e6;
    if (!_switchStarted) {
      if (widget.throughBlack && t >= _blackoutSeconds) {
        _switchStarted = true;
        unawaited(_switchWhileBlack());
      } else if (!widget.throughBlack && t >= _coverSeconds) {
        _switchStarted = true;
        unawaited(widget.onCovered());
      }
    }
    if (_portalStart == null && t >= _timeoutSeconds) {
      _portalStart = t - _minPortalSeconds;
    }
    final start = _portalStart;
    if (start != null &&
        _fadeStart == null &&
        t - start >= _minPortalSeconds &&
        ((widget.ready?.value ?? true) || t >= _timeoutSeconds)) {
      _fadeStart = t;
      widget.onReveal?.call();
    }
    if (_fadeStart != null && t >= _fadeStart! + _fadeSeconds) {
      _done = true;
      _ticker.stop();
      widget.onComplete();
      return;
    }
    _time.value = t;
  }

  /// Everything that costs a hitch happens here, on black frames.
  Future<void> _switchWhileBlack() async {
    final began = _now;
    try {
      await widget.onCovered();
    } catch (_) {
      // The push reports its own failure through the route future.
    }
    if (widget.counterTurns != 0) {
      while (mounted &&
          _portraitNow == _startedPortrait &&
          _now - began < _settleTimeoutSeconds) {
        await SchedulerBinding.instance.endOfFrame;
      }
    }
    for (var i = 0; i < _settleFrames && mounted; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (mounted && _portalStart == null) _portalStart = _now;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height >= size.width;
    _startedPortrait ??= portrait;
    _portraitNow = portrait;
    final turns = widget.counterTurns != 0 && _startedPortrait! && !portrait
        ? widget.counterTurns
        : 0;
    return IgnorePointer(
      child: RotatedBox(
        quarterTurns: turns,
        child: RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: _time,
            builder: (context, t, _) => _frame(t),
          ),
        ),
      ),
    );
  }

  Widget _frame(double t) {
    final start = _portalStart;
    if (start == null) {
      return Opacity(
        opacity: (t / _blackoutSeconds).clamp(0.0, 1.0),
        child: const ColoredBox(color: _void),
      );
    }
    final pt = t - start;
    final portalIn = widget.throughBlack
        ? (pt / _portalInSeconds).clamp(0.0, 1.0)
        : (pt / _coverSeconds).clamp(0.0, 1.0);
    final titleIn = ((pt - 0.35) / 0.4).clamp(0.0, 1.0);
    final Widget portal = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: PortalPainter(
            elapsed: pt,
            element: widget.element,
            title: widget.title,
            accent: const Color(0xFFE4C16A),
            palette: widget.palette,
            tint: widget.tint,
          ),
        ),
        Center(
          child: Opacity(
            opacity: titleIn,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Color(0xD9E8DFC8),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFE4C16A),
                    fontFamily: 'monospace',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.6,
                    decoration: TextDecoration.none,
                    shadows: [Shadow(color: Color(0xFFE4C16A), blurRadius: 14)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final fade = _fadeStart == null
        ? 1.0
        : (1 - (t - _fadeStart!) / _fadeSeconds).clamp(0.0, 1.0);
    return Opacity(
      opacity: fade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Black under the portal while it fades up, so the switch never
          // shows through.
          if (portalIn < 1 && widget.throughBlack)
            const ColoredBox(color: _void),
          if (portalIn < 1)
            Opacity(opacity: portalIn, child: portal)
          else
            portal,
        ],
      ),
    );
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
      (i) => config.starColor.withValues(alpha: i / 20),
    );
    final dimStarOpacities = List.generate(
      21,
      (i) => config.dimStarColor.withValues(alpha: i / 20),
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
      ..color = data.config.color.withValues(alpha: opacity);
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
    data.glowPaint.shader =
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
