// lib/widgets/fx/harvest_cinematic_fx.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Show the full-screen harvest cinematic and run [task] while it plays.
/// The route closes only after BOTH the animation AND the task complete.
/// Returns true if harvest succeeded, false if failed.
Future<bool> showHarvestCinematic({
  required BuildContext context,
  required Widget targetSprite,
  required Color targetColor,
  required String deviceLabel,
  Duration minDuration = const Duration(milliseconds: 1600),
  required Future<bool> Function() task,
}) {
  return Navigator.of(context)
      .push<bool>(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (_, __, ___) => _HarvestCinematicPage(
            targetSprite: targetSprite,
            targetColor: targetColor,
            deviceLabel: deviceLabel,
            minDuration: minDuration,
            task: task,
          ),
          transitionsBuilder: (_, a, __, child) {
            return FadeTransition(opacity: a, child: child);
          },
        ),
      )
      .then((value) => value ?? false);
}

class _HarvestCinematicPage extends StatefulWidget {
  const _HarvestCinematicPage({
    required this.targetSprite,
    required this.targetColor,
    required this.deviceLabel,
    required this.minDuration,
    required this.task,
  });

  final Widget targetSprite;
  final Color targetColor;
  final String deviceLabel;
  final Duration minDuration;
  final Future<bool> Function() task;

  @override
  State<_HarvestCinematicPage> createState() => _HarvestCinematicPageState();
}

class _HarvestCinematicPageState extends State<_HarvestCinematicPage>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl; // master timeline 0..1
  late final AnimationController _flashCtrl; // flash on success
  late final AnimationController _failShakeCtrl; // shake on failure

  bool? _success;
  bool _taskDone = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: widget.minDuration)
      ..addStatusListener(_maybeClose);

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _failShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Kick off haptics + animation
    HapticFeedback.mediumImpact();
    _ctrl.forward();

    // Run the task in parallel
    () async {
      try {
        _success = await widget.task();
      } catch (e) {
        _success = false;
      } finally {
        _taskDone = true;
        _maybeClose(_ctrl.status);
      }
    }();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _flashCtrl.dispose();
    _failShakeCtrl.dispose();
    super.dispose();
  }

  void _maybeClose(AnimationStatus s) async {
    if (s != AnimationStatus.completed || !_taskDone) return;

    if (_success == true) {
      // Success: white flash + heavy haptic
      try {
        HapticFeedback.heavyImpact();
        await _flashCtrl.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 100));
      } finally {
        if (!mounted) return;
        Navigator.of(context).pop<bool>(true);
      }
    } else {
      // Failure: error shake + light haptic
      try {
        HapticFeedback.lightImpact();
        await _failShakeCtrl.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 600));
      } finally {
        if (!mounted) return;
        Navigator.of(context).pop<bool>(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(.70),
      body: Stack(
        children: [
          // Vignette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(.6),
                    Colors.black.withOpacity(.85),
                  ],
                  stops: const [0.25, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // Center harvest container
          Center(
            child: LayoutBuilder(
              builder: (_, c) {
                final w = math.min(c.maxWidth, 500.0);
                final h = math.min(c.maxHeight, 500.0);
                final size = Size(w, h);
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_ctrl, _failShakeCtrl]),
                    builder: (_, __) {
                      final t = _ctrl.value; // 0..1

                      // Camera shake during harvest (0.4..0.8)
                      final shakePhase = _interval(t, 0.4, 0.85);
                      final amp = Curves.easeOut.transform(shakePhase) * 8.0;
                      final dx = math.sin(t * math.pi * 16) * amp;
                      final dy = math.cos(t * math.pi * 13) * amp * .5;

                      // Failure shake (if failed)
                      final failShake = _failShakeCtrl.value;
                      final failAmp = math.sin(failShake * math.pi * 8) * 12.0;

                      return Transform.translate(
                        offset: Offset(dx + failAmp, dy),
                        child: Stack(
                          children: [
                            // Extraction rings
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _HarvestRingsPainter(
                                  t: t,
                                  color: widget.targetColor,
                                  success: _success,
                                ),
                              ),
                            ),

                            // Target creature (scales down during extraction)
                            Positioned.fill(
                              child: _TargetCreature(
                                t: t,
                                sprite: widget.targetSprite,
                                color: widget.targetColor,
                                success: _success,
                              ),
                            ),

                            // Extraction beam
                            Positioned.fill(
                              child: _ExtractionBeam(
                                t: t,
                                color: widget.targetColor,
                                success: _success,
                              ),
                            ),

                            // Success flash
                            if (_success == true)
                              Positioned.fill(
                                child: FadeTransition(
                                  opacity: _flashCtrl.drive(
                                    CurveTween(curve: Curves.easeOut),
                                  ),
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                            // Failure indicator
                            if (_success == false && _taskDone)
                              Positioned.fill(
                                child: _FailureIndicator(
                                  animation: _failShakeCtrl,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Status label
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = _ctrl.value;

                  String text;
                  if (!_taskDone) {
                    text = 'INITIATING ${widget.deviceLabel.toUpperCase()}';
                  } else if (_success == true) {
                    text = 'HARVEST SUCCESSFUL';
                  } else {
                    text = 'HARVEST FAILED';
                  }

                  final o = _interval(t, 0.05, 0.25);
                  final color = _success == false
                      ? const Color(0xFFFF4444)
                      : const Color(0xFFE8EAED);

                  return Opacity(
                    opacity: o,
                    child: Text(
                      text,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.2,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 0 before start, 1 after end, with clamped range
double _interval(double t, double start, double end) {
  final v = ((t - start) / (end - start)).clamp(0.0, 1.0);
  return v.isNaN ? 0.0 : v;
}

/// Target creature that gets extracted
class _TargetCreature extends StatelessWidget {
  const _TargetCreature({
    required this.t,
    required this.sprite,
    required this.color,
    required this.success,
  });

  final double t;
  final Widget sprite;
  final Color color;
  final bool? success;

  @override
  Widget build(BuildContext context) {
    // Phases:
    // 0.00..0.35: creature appears and holds steady
    // 0.35..0.70: extraction begins, creature glows/pulses
    // 0.70..0.95: creature dissolves/scales down
    final appear = _interval(t, 0.0, 0.35);
    final extract = _interval(t, 0.35, 0.70);
    final dissolve = _interval(t, 0.70, 0.95);

    final scale = 1.0 - (Curves.easeIn.transform(dissolve) * 0.6);
    final opacity = 1.0 - (Curves.easeIn.transform(dissolve) * 0.85);

    // Pulse during extraction
    final pulse = extract > 0 ? (math.sin(t * math.pi * 8) * 0.5 + 0.5) : 0.0;
    final glowIntensity = extract * 0.8 + pulse * 0.2;

    return Align(
      alignment: Alignment.center,
      child: Opacity(
        opacity: (appear * opacity).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: _Glow(color: color, intensity: glowIntensity, child: sprite),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.child, required this.color, this.intensity = 0.5});

  final Widget child;
  final Color color;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.4 * intensity),
            blurRadius: 25,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: color.withOpacity(.2 * intensity),
            blurRadius: 50,
            spreadRadius: 15,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Rotating extraction rings and technical glyphs
class _HarvestRingsPainter extends CustomPainter {
  _HarvestRingsPainter({
    required this.t,
    required this.color,
    required this.success,
  });

  final double t;
  final Color color;
  final bool? success;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final baseR = math.min(size.width, size.height) * .28;

    final paint = Paint()
      ..color = color.withOpacity(.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer containment circle
    canvas.drawCircle(
      c,
      baseR * 1.4,
      Paint()
        ..color = Colors.white.withOpacity(.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Spinning extraction rings
    void dashedRing(double r, double rot, double opacity) {
      const seg = 24;
      for (int i = 0; i < seg; i++) {
        final a0 = (i / seg) * 2 * math.pi + rot;
        final a1 = a0 + (2 * math.pi / seg) * .4;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          a0,
          a1 - a0,
          false,
          Paint()
            ..color = color.withOpacity(opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }

    final rot1 = t * 2 * math.pi * 1.2;
    final rot2 = -t * 2 * math.pi * 0.8;

    // During extraction (0.35..0.95), rings intensify
    final extractPhase = _interval(t, 0.35, 0.95);
    final ringOpacity = 0.5 + extractPhase * 0.5;

    dashedRing(baseR * 0.9, rot1, ringOpacity);
    dashedRing(baseR * 1.15, rot2, ringOpacity * 0.8);

    // Directional extraction markers (triangles pointing inward)
    if (extractPhase > 0) {
      final markerPaint = Paint()
        ..color = color.withOpacity(extractPhase * 0.7)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 6; i++) {
        final ang = rot1 * 0.5 + i * (2 * math.pi / 6);
        final p0 = c + Offset(math.cos(ang), math.sin(ang)) * (baseR * 1.3);
        final p1 = c + Offset(math.cos(ang), math.sin(ang)) * (baseR * 1.15);
        final p2 =
            c +
            Offset(math.cos(ang + 0.3), math.sin(ang + 0.3)) * (baseR * 1.23);
        final path = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        canvas.drawPath(path, markerPaint);
      }
    }

    // Core extraction point pulse
    final corePulse = (math.sin(t * math.pi * 3) * .5 + .5);
    final coreR = baseR * (0.15 + corePulse * 0.08);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(.6), Colors.white.withOpacity(.0)],
      ).createShader(Rect.fromCircle(center: c, radius: coreR * 2));
    canvas.drawCircle(c, coreR * 2, corePaint);
  }

  @override
  bool shouldRepaint(covariant _HarvestRingsPainter old) =>
      old.t != t || old.success != success;
}

/// Extraction beam effect during harvest
class _ExtractionBeam extends StatelessWidget {
  const _ExtractionBeam({
    required this.t,
    required this.color,
    required this.success,
  });

  final double t;
  final Color color;
  final bool? success;

  @override
  Widget build(BuildContext context) {
    final p = _interval(t, 0.40, 0.90); // only during extraction
    if (p <= 0) return const SizedBox.shrink();

    final h = Curves.easeInOut.transform(p);
    final opacity = (0.15 + h * 0.7).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Stack(
        children: [
          // Radial extraction field
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color.withOpacity(.12 * opacity),
                    color.withOpacity(.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Vertical extraction column
          Align(
            alignment: Alignment.center,
            child: Opacity(
              opacity: opacity * 0.8,
              child: Container(
                width: 8 + 60 * h,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      color.withOpacity(.85),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.1, 0.5, 0.9],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Failure indicator (red X)
class _FailureIndicator extends StatelessWidget {
  const _FailureIndicator({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = Curves.easeOut.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(.2),
                border: Border.all(color: Colors.red, width: 3),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.red,
                size: 80,
              ),
            ),
          ),
        );
      },
    );
  }
}
