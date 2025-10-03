import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Show the full-screen cinematic and run [task] while it plays.
/// The route closes only after BOTH the animation AND the task complete.
/// Returns the value from [task].
Future<T?> showAlchemyFusionCinematic<T>({
  required BuildContext context,
  required Widget leftSprite,
  required Widget rightSprite,
  required Color leftColor,
  required Color rightColor,
  Duration minDuration = const Duration(milliseconds: 1800),
  required Future<T> Function() task,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => _AlchemyFusionCinematicPage<T>(
        leftSprite: leftSprite,
        rightSprite: rightSprite,
        leftColor: leftColor,
        rightColor: rightColor,
        minDuration: minDuration,
        task: task,
      ),
      transitionsBuilder: (_, a, __, child) {
        return FadeTransition(opacity: a, child: child);
      },
    ),
  );
}

class _AlchemyFusionCinematicPage<T> extends StatefulWidget {
  const _AlchemyFusionCinematicPage({
    required this.leftSprite,
    required this.rightSprite,
    required this.leftColor,
    required this.rightColor,
    required this.minDuration,
    required this.task,
  });

  final Widget leftSprite;
  final Widget rightSprite;
  final Color leftColor;
  final Color rightColor;
  final Duration minDuration;
  final Future<T> Function() task;

  @override
  State<_AlchemyFusionCinematicPage<T>> createState() =>
      _AlchemyFusionCinematicPageState<T>();
}

class _AlchemyFusionCinematicPageState<T>
    extends State<_AlchemyFusionCinematicPage<T>>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl; // master timeline 0..1
  late final AnimationController _flashCtrl; // white flash near the end
  T? _result;
  Object? _err;
  bool _taskDone = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: widget.minDuration)
      ..addStatusListener(_maybeClose);

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    // Kick off haptics + animation.
    HapticFeedback.mediumImpact();
    _ctrl.forward();

    // Run the task in parallel.
    () async {
      try {
        _result = await widget.task();
      } catch (e) {
        _err = e;
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
    super.dispose();
  }

  void _maybeClose(AnimationStatus s) async {
    if (s != AnimationStatus.completed || !_taskDone) return;

    // quick white flash & stronger haptic
    try {
      HapticFeedback.heavyImpact();
      await _flashCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 80));
    } finally {
      if (!mounted) return;
      if (_err != null) {
        Navigator.of(context).pop<T>(null); // let caller handle error
      } else {
        Navigator.of(context).pop<T>(_result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // darker background with subtle vignette
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(.65),
      body: Stack(
        children: [
          // vignette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(.55),
                    Colors.black.withOpacity(.8),
                  ],
                  stops: const [0.30, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Center ritual container
          Center(
            child: LayoutBuilder(
              builder: (_, c) {
                final w = math.min(c.maxWidth, 600.0);
                final h = math.min(c.maxHeight, 600.0);
                final size = Size(w, h);
                return SizedBox(
                  width: size.width,
                  height: size.height,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) {
                      final t = _ctrl.value; // 0..1

                      // Shake amplitude curve: peaks around merge (0.55..0.85)
                      final shakePhase = _interval(t, 0.55, 0.90);
                      final amp = Curves.easeOut.transform(shakePhase) * 10.0;
                      final dx = math.sin(t * math.pi * 14) * amp;
                      final dy = math.cos(t * math.pi * 11) * amp * .6;
                      final rot = math.sin(t * math.pi * 8) * amp * 0.002;

                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: Transform.rotate(
                          angle: rot,
                          child: Stack(
                            children: [
                              // Sigils
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _SigilPainter(
                                    t: t,
                                    a: widget.leftColor,
                                    b: widget.rightColor,
                                  ),
                                ),
                              ),

                              // Parent sprites slide in → orbit → converge
                              Positioned.fill(
                                child: _Orbits(
                                  t: t,
                                  left: widget.leftSprite,
                                  right: widget.rightSprite,
                                  a: widget.leftColor,
                                  b: widget.rightColor,
                                ),
                              ),

                              // Convergence beam/pulse
                              Positioned.fill(
                                child: _BeamPulse(
                                  t: t,
                                  a: widget.leftColor,
                                  b: widget.rightColor,
                                ),
                              ),

                              // Final white flash
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // Label
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final t = _ctrl.value;
                  final o = _interval(t, 0.05, 0.30);
                  return Opacity(
                    opacity: o,
                    child: const Text(
                      'INITIATING GENETIC FUSION',
                      style: TextStyle(
                        color: Color(0xFFE8EAED),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.1,
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

/// 0 before start, 1 after end, with clamped range.
double _interval(double t, double start, double end) {
  final v = ((t - start) / (end - start)).clamp(0.0, 1.0);
  return v.isNaN ? 0.0 : v;
}

/// Two sprites orbit in and converge with color glows.
class _Orbits extends StatelessWidget {
  const _Orbits({
    required this.t,
    required this.left,
    required this.right,
    required this.a,
    required this.b,
  });

  final double t;
  final Widget left;
  final Widget right;
  final Color a;
  final Color b;

  @override
  Widget build(BuildContext context) {
    // Phases:
    // 0.00..0.30: slide in
    // 0.30..0.55: orbit swirl
    // 0.55..0.75: converge & scale down
    // 0.75..1.00: hold in core
    final slide = _interval(t, 0.0, 0.30);
    final orbit = _interval(t, 0.30, 0.55);
    final converge = _interval(t, 0.55, 0.75);

    final center = Alignment.center;
    final leftPos = Alignment.lerp(
      const Alignment(-1.6, 0.0),
      const Alignment(-0.55, 0),
      Curves.easeOutBack.transform(slide),
    )!;
    final rightPos = Alignment.lerp(
      const Alignment(1.6, 0.0),
      const Alignment(0.55, 0),
      Curves.easeOutBack.transform(slide),
    )!;

    // Orbit offsets (counter-directions) then collapse to center
    final orbitAngle = orbit * math.pi * 2.2; // a couple turns
    final r = (1 - converge) * 60.0; // radius shrinks on converge
    final lx = math.cos(orbitAngle) * r;
    final ly = math.sin(orbitAngle) * r;
    final rx = math.cos(orbitAngle + math.pi) * r;
    final ry = math.sin(orbitAngle + math.pi) * r;

    final goCenter = Curves.easeIn.transform(converge);
    final leftAlign = Alignment.lerp(leftPos, center, goCenter)!;
    final rightAlign = Alignment.lerp(rightPos, center, goCenter)!;

    final scale = 1.0 - 0.25 * goCenter;

    return Stack(
      children: [
        Align(
          alignment: leftAlign,
          child: Transform.translate(
            offset: Offset(lx, ly),
            child: Transform.scale(
              scale: scale,
              child: _Glow(child: left, color: a, intensity: .55),
            ),
          ),
        ),
        Align(
          alignment: rightAlign,
          child: Transform.translate(
            offset: Offset(rx, ry),
            child: Transform.scale(
              scale: scale,
              child: _Glow(child: right, color: b, intensity: .55),
            ),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.child, required this.color, this.intensity = .5});
  final Widget child;
  final Color color;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.45 * intensity),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: color.withOpacity(.25 * intensity),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Rotating rings, runes, triangles.
class _SigilPainter extends CustomPainter {
  _SigilPainter({required this.t, required this.a, required this.b});
  final double t;
  final Color a, b;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final baseR = math.min(size.width, size.height) * .32;
    final paintA = Paint()
      ..color = a.withOpacity(.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final paintB = Paint()
      ..color = b.withOpacity(.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    // Outer faint circle
    canvas.drawCircle(
      c,
      baseR * 1.28,
      Paint()
        ..color = Colors.white.withOpacity(.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Spinning dashed rings
    void dashedRing(double r, double rot, Paint p) {
      const seg = 22;
      for (int i = 0; i < seg; i++) {
        final a0 = (i / seg) * 2 * math.pi + rot;
        final a1 = a0 + (2 * math.pi / seg) * .55;
        final p0 = c + Offset(math.cos(a0), math.sin(a0)) * r;
        final p1 = c + Offset(math.cos(a1), math.sin(a1)) * r;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          a0,
          a1 - a0,
          false,
          p,
        );
      }
    }

    final rot1 = t * 2 * math.pi * 0.7;
    final rot2 = -t * 2 * math.pi * 0.9;

    dashedRing(baseR * 0.95, rot1, paintA);
    dashedRing(baseR * 1.15, rot2, paintB);

    // Triangle glyphs
    final triPaint = Paint()
      ..color = Colors.white.withOpacity(.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (int i = 0; i < 3; i++) {
      final ang = rot1 + i * (2 * math.pi / 3);
      final p0 = c + Offset(math.cos(ang), math.sin(ang)) * (baseR * 0.55);
      final p1 =
          c + Offset(math.cos(ang + 2.1), math.sin(ang + 2.1)) * (baseR * 0.55);
      final p2 =
          c + Offset(math.cos(ang + 4.2), math.sin(ang + 4.2)) * (baseR * 0.55);
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();
      canvas.drawPath(path, triPaint);
    }

    // Core circle pulse
    final corePulse = (math.sin(t * math.pi * 2) * .5 + .5);
    final coreR = baseR * (0.25 + corePulse * 0.06);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(a, b, .5)!.withOpacity(.45),
          Colors.white.withOpacity(.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: coreR * 1.8));
    canvas.drawCircle(c, coreR * 1.8, corePaint);
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..color = Colors.white.withOpacity(.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _SigilPainter old) =>
      old.t != t || old.a != a || old.b != b;
}

/// Bright beam at convergence time.
class _BeamPulse extends StatelessWidget {
  const _BeamPulse({required this.t, required this.a, required this.b});
  final double t;
  final Color a, b;

  @override
  Widget build(BuildContext context) {
    final p = _interval(t, 0.58, 0.85); // only during merge
    if (p <= 0) return const SizedBox.shrink();

    final mix = Color.lerp(a, b, .5)!;
    final h = Curves.easeInOut.transform(p);
    final opacity = (0.2 + h * 0.8).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Stack(
        children: [
          // radial blast
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [mix.withOpacity(.15 * opacity), mix.withOpacity(.0)],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // vertical column
          Align(
            alignment: Alignment.center,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 10 + 90 * h,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(.9),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.15, 0.5, 0.85],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: mix.withOpacity(.5),
                      blurRadius: 40,
                      spreadRadius: 8,
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
