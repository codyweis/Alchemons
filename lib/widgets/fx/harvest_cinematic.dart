// lib/widgets/fx/harvest_cinematic.dart
//
// THE HARVEST — a containment field closing on a live specimen.
//
// The old version was an overlay animation: rings and a beam did all the
// moving while the creature sat in the middle at 120px behind a 70% scrim and
// a heavy vignette, glowing. You watched chrome. This one animates the
// CREATURE — it is seized, caged, and strains against a field that flexes
// where it pushes — and the apparatus is the thing in the background.
//
// The opening is identical whether the harvest lands or not, because the run
// does not know yet: the field holds and the specimen fights until the task
// answers. Only then does it resolve, and the two resolutions are opposites —
// the field collapses INWARD and takes it, or it shatters OUTWARD and the
// specimen is gone.
//
// No MaskFilter anywhere: glow is layered translucent strokes, which is this
// codebase's standing replacement (see the constellation screen, and the
// damage numbers that were paying a gaussian per shadow per frame).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Show the full-screen harvest cinematic and run [task] while it plays.
///
/// The route closes only after the resolution has played, and the resolution
/// does not begin until [task] has answered — so the specimen is still
/// fighting the field while the roll is being made. Returns the task's result.
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
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      )
      .then((value) => value ?? false);
}

/// How big the specimen stands on the stage. It used to be 120 inside a 500
/// box, which is why the rings read as the subject.
const double _kSpecimenBox = 208.0;

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
  /// SEIZE → LOCK → PRESSURE. Identical on both outcomes.
  late final AnimationController _seize;

  /// The strain loop, running under the hold so a slow task reads as the
  /// specimen still fighting rather than as a frozen frame.
  late final AnimationController _strain;

  /// COLLAPSE or SHATTER. Starts only once the outcome is known.
  late final AnimationController _resolve;

  bool? _success;
  bool _taskDone = false;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();

    _seize = AnimationController(vsync: this, duration: widget.minDuration)
      ..addStatusListener((_) => _maybeResolve());
    _strain = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _resolve = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    HapticFeedback.mediumImpact();
    _seize.forward();

    () async {
      try {
        _success = await widget.task();
      } catch (_) {
        _success = false;
      } finally {
        _taskDone = true;
        _maybeResolve();
      }
    }();
  }

  @override
  void dispose() {
    _seize.dispose();
    _strain.dispose();
    _resolve.dispose();
    super.dispose();
  }

  Future<void> _maybeResolve() async {
    if (_resolving) return;
    if (!_taskDone || _seize.status != AnimationStatus.completed) return;
    _resolving = true;
    if (mounted) setState(() {});

    HapticFeedback.heavyImpact();
    _strain.stop();
    await _resolve.forward(from: 0);
    // A beat on the aftermath before the world comes back.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted) Navigator.of(context).pop<bool>(_success ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Lighter than the old 70% + vignette. The stage has to isolate the
      // specimen, not hide it.
      backgroundColor: Colors.black.withValues(alpha: 0.62),
      body: AnimatedBuilder(
        animation: Listenable.merge([_seize, _strain, _resolve]),
        builder: (context, _) {
          final s = _seize.value;
          final r = _resolve.value;
          final beat = _HarvestBeat(
            seize: s,
            strain: _strain.value,
            resolve: r,
            success: _success ?? false,
            resolving: _resolving,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: SizedBox(
                  width: 420,
                  height: 420,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The apparatus, behind the specimen where it belongs.
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ContainmentFieldPainter(
                            beat: beat,
                            color: widget.targetColor,
                          ),
                        ),
                      ),
                      _Specimen(
                        beat: beat,
                        sprite: widget.targetSprite,
                        color: widget.targetColor,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 46,
                left: 24,
                right: 24,
                child: _Caption(beat: beat, device: widget.deviceLabel),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Everything the painters and the specimen need to know about where in the
/// harvest we are, worked out once per frame.
class _HarvestBeat {
  _HarvestBeat({
    required this.seize,
    required this.strain,
    required this.resolve,
    required this.success,
    required this.resolving,
  });

  /// 0..1 across the shared opening.
  final double seize;

  /// 0..1, looping, for the push-back pulse.
  final double strain;

  /// 0..1 across the resolution; 0 until the outcome is known.
  final double resolve;
  final bool success;
  final bool resolving;

  /// The field sweeping in from outside the frame.
  double get closing => _interval(seize, 0.02, 0.42);

  /// The moment it bites — the specimen recoils.
  double get lock => _interval(seize, 0.38, 0.55);

  /// The specimen leaning on the wall of the field.
  double get pressure => _interval(seize, 0.55, 1.0);

  /// 0..1 push cycle: 1 = shoving hardest. Freezes at the shove when the
  /// resolution takes over, so nothing snaps.
  double get push {
    if (resolving) return 1.0 - _interval(resolve, 0.0, 0.22);
    return pressure * (0.5 - 0.5 * math.cos(strain * math.pi * 2));
  }

  double get collapse => success ? resolve : 0.0;
  double get shatter => success ? 0.0 : resolve;
}

/// The specimen: big, centre stage, and the only thing acting.
class _Specimen extends StatelessWidget {
  const _Specimen({
    required this.beat,
    required this.sprite,
    required this.color,
  });

  final _HarvestBeat beat;
  final Widget sprite;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Arrives at full size, flinches when the field bites, then swells
    // against it on every push.
    final appear = Curves.easeOut.transform(_interval(beat.seize, 0.0, 0.2));
    final flinch = math.sin(beat.lock * math.pi); // 0 → 1 → 0
    var scale = 0.86 + 0.14 * appear;
    scale -= 0.09 * flinch;
    scale += 0.07 * beat.push;

    // Squashed and drawn down into the harvester. Quadratic, not cubic: a
    // cubic ease put the whole take in the last three hundred milliseconds,
    // so the specimen sat there and then blinked out.
    final c = Curves.easeIn.transform(beat.collapse);
    // ...or a hard recoil and gone.
    final sh = Curves.easeOutCubic.transform(beat.shatter);

    final sx = scale * (1.0 - 0.86 * c) * (1.0 + 0.22 * sh);
    final sy = scale * (1.0 - 0.94 * c) * (1.0 + 0.10 * sh);

    // Fighting: a fast tremble while the field holds it.
    final tremble = (beat.lock + beat.pressure) * (1 - beat.resolve);
    final jx = math.sin(beat.strain * math.pi * 14) * 3.4 * tremble;
    final jy = math.cos(beat.strain * math.pi * 11) * 2.0 * tremble;

    final opacity = (appear * (1.0 - c) * (1.0 - sh)).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(jx, jy + 62 * c),
      child: Opacity(
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(sx, sy, 1),
          child: SizedBox(
            width: _kSpecimenBox,
            height: _kSpecimenBox,
            child: Center(child: sprite),
          ),
        ),
      ),
    );
  }
}

/// The apparatus: rings that close, flex where the specimen pushes, and then
/// either fall inward or blow apart.
class _ContainmentFieldPainter extends CustomPainter {
  _ContainmentFieldPainter({required this.beat, required this.color});

  final _HarvestBeat beat;
  final Color color;

  static const _ember = Color(0xFFD07A4A);
  static const _amber = Color(0xFFE4C16A);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final cage = math.min(size.width, size.height) * 0.30;
    final closing = Curves.easeOutCubic.transform(beat.closing);
    final collapse = Curves.easeInOutCubic.transform(beat.collapse);
    final shatter = Curves.easeOutCubic.transform(beat.shatter);

    // The pool of light the field stands the specimen in — layered discs, not
    // a blur.
    final lit = (beat.closing * 0.5 + beat.push * 0.5) * (1 - collapse);
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        c,
        cage * (0.55 + i * 0.28),
        Paint()..color = color.withValues(alpha: 0.035 * lit / i),
      );
    }

    for (var ring = 0; ring < 3; ring++) {
      // Sweeps in from well outside the frame, settles just off the specimen.
      final rest = cage * (1.0 + ring * 0.19);
      final start = rest * (3.4 - ring * 0.4);
      var radius = start + (rest - start) * closing;
      radius *= 1.0 - 0.92 * collapse;
      radius *= 1.0 + 1.6 * shatter;
      if (radius <= 1) continue;

      final spin = beat.seize * (ring.isEven ? 1.0 : -1.0) * (1.1 + ring * 0.5);
      final segs = 5 + ring * 2;
      final flex = beat.push * cage * 0.11 * (1 - collapse);
      final alpha =
          (0.20 + 0.55 * closing) * (1 - collapse * 0.35) * (1 - shatter);
      if (alpha <= 0.01) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (ring == 0 ? 2.6 : 1.5) + 1.4 * beat.push
        ..color = Color.lerp(color, _amber, 0.35)!.withValues(alpha: alpha);

      for (var s = 0; s < segs; s++) {
        final a0 = spin + s * math.pi * 2 / segs;
        final a1 = a0 + math.pi * 2 / segs * 0.62;
        // Shards fly apart on a failure instead of holding their arc.
        final fly = shatter * cage * 1.4 * (0.6 + 0.4 * (s % 3));
        final off = shatter == 0
            ? Offset.zero
            : Offset(math.cos(a0), math.sin(a0)) * fly;
        final path = Path();
        const steps = 10;
        for (var k = 0; k <= steps; k++) {
          final a = a0 + (a1 - a0) * k / steps;
          // THE FLEX: the wall bulges where the specimen is leaning on it.
          final rr =
              radius + flex * math.sin(a * 3 - beat.strain * math.pi * 2);
          final p = c + Offset(math.cos(a), math.sin(a)) * rr + off;
          if (k == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(path, paint);
      }
    }

    // Anchors: four brackets that bite in as the field locks.
    final bite = Curves.easeOutBack.transform(
      _interval(beat.seize, 0.36, 0.58),
    );
    if (bite > 0.01 && collapse < 0.9 && shatter < 0.9) {
      final r = cage * (1.42 - 0.1 * bite) * (1 - 0.92 * collapse);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = _amber.withValues(
          alpha: 0.5 * bite * (1 - shatter) * (1 - collapse),
        );
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + math.pi / 4;
        final u = Offset(math.cos(a), math.sin(a));
        final across = Offset(-u.dy, u.dx);
        canvas.drawLine(c + u * r, c + u * (r + 16), p);
        canvas.drawLine(
          c + u * (r + 16) - across * 9,
          c + u * (r + 16) + across * 9,
          p,
        );
      }
    }

    // SUCCESS: the field falls in on itself and what it held goes down with
    // it — a warm implosion, not a white frame.
    if (collapse > 0.01) {
      final ring = cage * (1.0 - collapse) + 6;
      canvas.drawCircle(
        c,
        ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 10 * collapse
          ..color = _amber.withValues(alpha: 0.75 * (1 - collapse)),
      );
      final spark = math.sin(collapse * math.pi);
      for (var i = 3; i >= 1; i--) {
        canvas.drawCircle(
          c,
          10.0 * i * spark,
          Paint()..color = _amber.withValues(alpha: 0.30 * spark / i),
        );
      }
      // What is left of the specimen, streaming down the field into the
      // harvester. Streaks, not particles — the pool is a per-frame cost this
      // cinematic does not need to carry.
      final draw = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8;
      for (var i = 0; i < 14; i++) {
        final a = i * math.pi * 2 / 14 + collapse * 1.4;
        final u = Offset(math.cos(a), math.sin(a));
        // Each mote starts further out and is pulled in on its own schedule.
        final lead = ((collapse * 1.6) - (i % 5) * 0.12).clamp(0.0, 1.0);
        if (lead <= 0) continue;
        final outer = cage * (1.25 - 0.95 * lead);
        canvas.drawLine(
          c + u * outer,
          c + u * (outer - cage * 0.22 * (1 - lead)),
          draw
            ..color = Color.lerp(
              color,
              _amber,
              0.6,
            )!.withValues(alpha: 0.75 * (1 - lead)),
        );
      }
    }

    // FAILURE: the wall cracks outward and the specimen is simply not there.
    if (shatter > 0.01) {
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4 * (1 - shatter)
        ..color = _ember.withValues(alpha: 0.7 * (1 - shatter));
      for (var i = 0; i < 9; i++) {
        final a = i * math.pi * 2 / 9 + 0.3;
        final u = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          c + u * (cage * (0.9 + 0.7 * shatter)),
          c + u * (cage * (1.1 + 2.0 * shatter)),
          crack,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ContainmentFieldPainter old) => true;
}

class _Caption extends StatelessWidget {
  const _Caption({required this.beat, required this.device});

  final _HarvestBeat beat;
  final String device;

  @override
  Widget build(BuildContext context) {
    final String text;
    Color color = const Color(0xFFE8DFC8);
    if (!beat.resolving) {
      text = beat.pressure > 0.05
          ? 'THE FIELD HOLDS'
          : '${device.toUpperCase()} ENGAGED';
    } else if (beat.success) {
      text = 'SPECIMEN SECURED';
      color = const Color(0xFFE4C16A);
    } else {
      text = 'CONTAINMENT BROKEN';
      color = const Color(0xFFD07A4A);
    }
    return Opacity(
      opacity: _interval(beat.seize, 0.06, 0.24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

/// 0 before [start], 1 after [end], clamped in between.
double _interval(double t, double start, double end) {
  final v = ((t - start) / (end - start)).clamp(0.0, 1.0);
  return v.isNaN ? 0.0 : v;
}
