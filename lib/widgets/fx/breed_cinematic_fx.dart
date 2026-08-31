import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// What the fusion produced — selects the reveal flourish at the climax.
enum FusionRevealKind { standard, pureElement, pureSpecies, pureBoth }

/// Outcome of the fusion, resolved while the cinematic plays and consumed at
/// the reveal so the climax matches what was actually created.
class FusionRevealData {
  const FusionRevealData({
    this.kind = FusionRevealKind.standard,
    required this.accent,
    this.element,
    this.caption,
    this.foundedNewLine = false,
  });

  final FusionRevealKind kind;

  /// Dominant reveal colour (element colour for pure elements, gold for pure
  /// lineages, the parent mix for a standard fusion).
  final Color accent;

  /// Lowercased element name (`fire`/`water`/`air`/`earth`/…) used to pick the
  /// alchemical glyph for pure-element reveals.
  final String? element;

  /// Headline shown at the reveal (e.g. `NEW FIRE LINEAGE`).
  final String? caption;

  /// A brand-new pure line was established — adds radiant rays + a brighter pop.
  final bool foundedNewLine;
}

/// Show the full-screen fusion cinematic and run [task] while it plays.
///
/// The two parent specimens energise inside their containment chambers, their
/// essence is channelled into a central fusion core, and the reaction erupts
/// into a freshly synthesised particle cultivation.
///
/// When [leftSlotRect] / [rightSlotRect] / [coreRect] are supplied (global
/// screen coordinates of the on-screen chamber slots and the fusion orb), the
/// cinematic anchors itself to those positions and fades up from the live
/// screen, so the effect reads as a continuation of the real chambers rather
/// than a detached overlay.
///
/// The route closes only after BOTH the animation AND the task complete (the
/// task usually finishes far sooner than the ~5.5s timeline). A skip control
/// fast-forwards the timeline to the reveal. Returns the value from [task].
Future<T?> showAlchemyFusionCinematic<T>({
  required BuildContext context,
  required Widget leftSprite,
  bool drawSpecimens = true,
  required Widget rightSprite,
  required Color leftColor,
  required Color rightColor,
  Duration minDuration = const Duration(milliseconds: 4350),
  bool allowSkip = true,
  Rect? leftSlotRect,
  Rect? rightSlotRect,
  Rect? coreRect,
  ValueListenable<FusionRevealData?>? outcome,
  required Future<T> Function() task,
}) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => _AlchemyFusionCinematicPage<T>(
        leftSprite: leftSprite,
        drawSpecimens: drawSpecimens,
        rightSprite: rightSprite,
        leftColor: leftColor,
        rightColor: rightColor,
        minDuration: minDuration,
        allowSkip: allowSkip,
        leftSlotRect: leftSlotRect,
        rightSlotRect: rightSlotRect,
        coreRect: coreRect,
        outcome: outcome,
        task: task,
      ),
      transitionsBuilder: (_, a, __, child) {
        return FadeTransition(opacity: a, child: child);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Timeline phases (master controller value t in 0..1).
// ---------------------------------------------------------------------------
//   intake : 0.00 .. 0.13  chambers wake on the live screen, parents settle
//   charge : 0.11 .. 0.29  chambers energise, conduits light, arcs crackle
//   stream : 0.27 .. 0.72  specimens dissolve, essence flows to the core
//   core   : 0.49 .. 0.77  intake rings pull inward, screen shake builds
//   burst  : 0.75 .. 0.85  eruption + shockwave ring (heavy haptic)
//   reveal : 0.75 .. 1.00  cultivation blooms straight out of the eruption
// The opening (intake + charge) is intentionally brief — about half the time
// of the back half — so the fusion gets going quickly.
class _Phase {
  static const intakeStart = 0.00, intakeEnd = 0.13;
  static const chargeStart = 0.11, chargeEnd = 0.29;
  static const streamStart = 0.27, streamEnd = 0.72;
  static const coreStart = 0.49, coreEnd = 0.77;
  static const burstStart = 0.75, burstEnd = 0.85;
  // Reveal starts with the burst so the cultivation grows continuously out of
  // the eruption — the specimens are never gone with nothing on screen.
  static const revealStart = 0.75, revealEnd = 1.00;

  // THE MERGE. The two creatures used to fade out at 0.44 — a third of the way
  // in — and everything after that was apparatus: streams, a core, a burst.
  // You watched a machine work while the animals stood off to one side and
  // vanished. They now hold their ground through the charge, are hauled into
  // each other while the streams run, and only give up their shape at the very
  // last moment, INSIDE the core, where the burst takes them.
  static const hauledStart = 0.30, hauledEnd = 0.70;
  static const dissolveStart = 0.66, dissolveEnd = 0.79;
}

class _AlchemyFusionCinematicPage<T> extends StatefulWidget {
  const _AlchemyFusionCinematicPage({
    required this.leftSprite,
    required this.drawSpecimens,
    required this.rightSprite,
    required this.leftColor,
    required this.rightColor,
    required this.minDuration,
    required this.allowSkip,
    required this.leftSlotRect,
    required this.rightSlotRect,
    required this.coreRect,
    required this.outcome,
    required this.task,
  });

  final Widget leftSprite;

  /// False when the caller has already merged the real specimens itself.
  final bool drawSpecimens;
  final Widget rightSprite;
  final Color leftColor;
  final Color rightColor;
  final Duration minDuration;
  final bool allowSkip;
  final Rect? leftSlotRect;
  final Rect? rightSlotRect;
  final Rect? coreRect;
  final ValueListenable<FusionRevealData?>? outcome;
  final Future<T> Function() task;

  @override
  State<_AlchemyFusionCinematicPage<T>> createState() =>
      _AlchemyFusionCinematicPageState<T>();
}

class _AlchemyFusionCinematicPageState<T>
    extends State<_AlchemyFusionCinematicPage<T>>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl; // master timeline 0..1
  late final AnimationController _flashCtrl; // final settle flash
  T? _result;
  Object? _err;
  bool _taskDone = false;
  bool _skipped = false;
  bool _heavyFired = false; // burst haptic guard

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: widget.minDuration)
      ..addStatusListener(_maybeClose)
      ..addListener(_pulseHaptics);

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

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

  // Fire a heavy impact exactly once as the core erupts.
  void _pulseHaptics() {
    if (!_heavyFired && _ctrl.value >= _Phase.burstStart) {
      _heavyFired = true;
      HapticFeedback.heavyImpact();
    }
  }

  void _skip() {
    if (_skipped) return;
    _skipped = true;
    final remaining = (1.0 - _ctrl.value).clamp(0.0, 1.0);
    _ctrl.animateTo(
      1.0,
      duration:
          Duration(milliseconds: (650 * remaining).clamp(180, 650).toInt()),
      curve: Curves.easeOutCubic,
    );
    setState(() {});
  }

  void _maybeClose(AnimationStatus s) async {
    if (s != AnimationStatus.completed || !_taskDone) return;

    try {
      await _flashCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 70));
    } finally {
      if (mounted) {
        Navigator.of(context).pop<T>(_err != null ? null : _result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final anchored = widget.coreRect != null ||
        widget.leftSlotRect != null ||
        widget.rightSlotRect != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (_, c) {
          final size = Size(c.maxWidth, c.maxHeight);

          // Resolve anchor centres in screen space (with sensible fallbacks).
          final leftC = widget.leftSlotRect?.center ??
              Offset(size.width * 0.30, size.height * 0.46);
          final rightC = widget.rightSlotRect?.center ??
              Offset(size.width * 0.70, size.height * 0.46);
          final coreC = widget.coreRect?.center ??
              Offset(size.width * 0.5, (leftC.dy + rightC.dy) / 2);
          final chR = (widget.leftSlotRect?.width != null)
              ? (widget.leftSlotRect!.width * 0.40).clamp(48.0, 120.0)
              : math.min(size.width, size.height) * 0.16;

          final layout = _FusionLayout(
            leftC: leftC,
            rightC: rightC,
            coreC: coreC,
            chR: chR,
            anchored: anchored,
          );

          final driver = widget.outcome == null
              ? _ctrl
              : Listenable.merge([_ctrl, widget.outcome!]);

          return AnimatedBuilder(
            animation: driver,
            builder: (_, __) {
              final t = _ctrl.value;
              final outcome = widget.outcome?.value;

              // Background darkens once the reaction takes focus; when
              // anchored we hold the live screen visible during intake.
              final bg = anchored
                  ? _interval(t, 0.14, 0.34)
                  : _interval(t, 0.0, 0.10);

              // Screen shake: ramps through core, peaks at burst.
              final shake = math.max(
                _interval(t, _Phase.coreStart, _Phase.burstStart) * 0.55,
                _interval(t, _Phase.burstStart, _Phase.burstEnd),
              );
              final amp = shake * 12.0;
              final dx = math.sin(t * math.pi * 30) * amp;
              final dy = math.cos(t * math.pi * 24) * amp * .6;

              return Stack(
                children: [
                  // Dimmer + vignette that fade in over the live screen.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(
                              (coreC.dx / size.width) * 2 - 1,
                              (coreC.dy / size.height) * 2 - 1,
                            ),
                            radius: 1.2,
                            colors: [
                              // Lighter than it was (.45/.72/.90): the scrim
                              // is here to isolate the pair, and it was
                              // hiding them.
                              Colors.black.withValues(alpha: .30 * bg),
                              Colors.black.withValues(alpha: .58 * bg),
                              Colors.black.withValues(alpha: .82 * bg),
                            ],
                            stops: const [0.25, 0.65, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Transform.translate(
                    offset: Offset(dx, dy),
                    child: Stack(
                      children: [
                        // Chamber apparatus, conduits, arcs, vortex, vial.
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ChamberPainter(
                              t: t,
                              a: widget.leftColor,
                              b: widget.rightColor,
                              layout: layout,
                              outcome: outcome,
                            ),
                          ),
                        ),

                        // THE SPECIMENS ARE ONLY DRAWN HERE IF NOBODY ELSE
                        // HAS THEM.
                        //
                        // The breed chamber now performs the merge on its own
                        // live slot widgets and hands over once the pair have
                        // gone into the core — so drawing them again here
                        // would be the duplicate this whole change exists to
                        // remove. Hosts with no chamber to animate (and the
                        // wilderness encounter, which has no slots at all)
                        // still pass them and still get them drawn.
                        if (widget.drawSpecimens) ...[
                          _SpecimenAt(
                            t: t,
                            sprite: widget.leftSprite,
                            color: widget.leftColor,
                            from: leftC,
                            core: coreC,
                          ),
                          _SpecimenAt(
                            t: t,
                            sprite: widget.rightSprite,
                            color: widget.rightColor,
                            from: rightC,
                            core: coreC,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Final settle flash.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity:
                            _flashCtrl.drive(CurveTween(curve: Curves.easeOut)),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  // Phase label.
                  Positioned(
                    bottom: 36,
                    left: 0,
                    right: 0,
                    child: Center(child: _PhaseLabel(t: t, outcome: outcome)),
                  ),

                  // Skip control.
                  if (widget.allowSkip)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      right: 16,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _skipped ? 0.0 : 1.0,
                        child: _SkipButton(onTap: _skip),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 0 before [start], 1 after [end], linear & clamped in between.
double _interval(double t, double start, double end) {
  final v = ((t - start) / (end - start)).clamp(0.0, 1.0);
  return v.isNaN ? 0.0 : v;
}

/// Screen-space geometry shared between the painter and the sprites.
class _FusionLayout {
  const _FusionLayout({
    required this.leftC,
    required this.rightC,
    required this.coreC,
    required this.chR,
    required this.anchored,
  });

  final Offset leftC;
  final Offset rightC;
  final Offset coreC;
  final double chR;
  final bool anchored;
}

// ---------------------------------------------------------------------------
// A single specimen, positioned at its chamber anchor, dissolving inward.
// ---------------------------------------------------------------------------
class _SpecimenAt extends StatelessWidget {
  const _SpecimenAt({
    required this.t,
    required this.sprite,
    required this.color,
    required this.from,
    required this.core,
  });

  final double t;
  final Widget sprite;
  final Color color;
  final Offset from; // chamber centre (screen space)
  final Offset core; // fusion core centre (screen space)

  @override
  Widget build(BuildContext context) {
    final intake = _interval(t, _Phase.intakeStart, _Phase.intakeEnd);
    final hauled = _interval(t, _Phase.hauledStart, _Phase.hauledEnd);
    final dissolve = _interval(t, _Phase.dissolveStart, _Phase.dissolveEnd);

    // HAULED IN. All the way to the core, not a 28% drift toward it: the two
    // creatures have to actually meet, and overlap, for the fusion to be
    // something they do rather than something done off-screen.
    final travel = Curves.easeInCubic.transform(hauled);
    final pos = Offset.lerp(from, core, travel)!;

    // They pop into their chambers, swell as they resist the pull, and only
    // collapse once they are inside each other.
    final pop = Curves.easeOutBack.transform(intake);
    final scale =
        (0.90 + 0.14 * pop) + 0.16 * hauled -
        0.86 * Curves.easeInCubic.transform(dissolve);
    final opacity = (1.0 - dissolve).clamp(0.0, 1.0);

    // Agitation: a buzz while the charge builds, rising to a hard shudder as
    // they are dragged together.
    final buzz = _interval(t, _Phase.chargeStart, _Phase.streamStart);
    final jitter =
        math.sin(t * math.pi * 40) * (buzz * 2.2 + hauled * 3.6);

    // Bigger, because they are the subject. 120 in a full-screen stage is a
    // thumbnail.
    const box = 172.0;
    return Positioned(
      left: pos.dx - box / 2 + jitter,
      top: pos.dy - box / 2,
      width: box,
      height: box,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale.clamp(0.1, 1.2),
          child: _Glow(
            color: color,
            intensity: .5 + buzz * .6 + dissolve * .8,
            child: Center(child: sprite),
          ),
        ),
      ),
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
    // A DISC behind the specimen, not a box shadow. A creature sprite is a
    // transparent png, so a boxShadow glows its bounding RECTANGLE — which is
    // most of why the pair read as flat panels rather than as animals. This
    // also drops two gaussian passes per specimen per frame.
    final a = intensity.clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: .34 * a),
                    color.withValues(alpha: .16 * a),
                    color.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The fusion apparatus, drawn in a single painter for tight per-frame cost.
// ---------------------------------------------------------------------------
class _ChamberPainter extends CustomPainter {
  _ChamberPainter({
    required this.t,
    required this.a,
    required this.b,
    required this.layout,
    required this.outcome,
  });

  final double t;
  final Color a, b;
  final _FusionLayout layout;
  final FusionRevealData? outcome;

  @override
  void paint(Canvas canvas, Size size) {
    final leftCh = layout.leftC;
    final rightCh = layout.rightC;
    final core = layout.coreC;
    final chR = layout.chR;
    final unit = math.min(size.width, size.height);
    final coreR = unit * 0.14;

    final mix = Color.lerp(a, b, .5)!;

    final charge = _interval(t, _Phase.chargeStart, _Phase.chargeEnd);
    final stream = _interval(t, _Phase.streamStart, _Phase.streamEnd);
    final coreP = _interval(t, _Phase.coreStart, _Phase.coreEnd);
    final burst = _interval(t, _Phase.burstStart, _Phase.burstEnd);
    final reveal = _interval(t, _Phase.revealStart, _Phase.revealEnd);

    _drawConduit(canvas, leftCh, core, a, charge, stream);
    _drawConduit(canvas, rightCh, core, b, charge, stream);

    _drawChamber(canvas, leftCh, chR, a, charge, stream);
    _drawChamber(canvas, rightCh, chR, b, charge, stream);

    _drawEssence(canvas, leftCh, core, a, stream);
    _drawEssence(canvas, rightCh, core, b, stream);

    if (charge > 0 && reveal < 0.6) {
      _drawArcs(canvas, leftCh, core, a, charge * (1 - reveal));
      _drawArcs(canvas, rightCh, core, b, charge * (1 - reveal));
    }

    // Core fades out as the cultivation blooms over it.
    if (reveal < 1) {
      _drawCore(canvas, core, coreR, a, b, mix, charge, coreP, burst, reveal);
    }

    // The eruption + reveal take on the outcome's colour when it's a pure line.
    final revealAccent = outcome?.accent ?? mix;
    if (burst > 0) _drawShockwave(canvas, core, unit, revealAccent, burst);

    if (reveal > 0) {
      _drawCultivation(canvas, core, unit, a, b, mix, reveal);
    }
  }

  Offset _ctrlFor(Offset from, Offset to) =>
      Offset((from.dx + to.dx) / 2, math.min(from.dy, to.dy) - 44);

  Path _conduitPath(Offset from, Offset to) {
    final ctrl = _ctrlFor(from, to);
    return Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
  }

  Offset _conduitPoint(Offset from, Offset to, double s) {
    final ctrl = _ctrlFor(from, to);
    final u = 1 - s;
    return Offset(
      u * u * from.dx + 2 * u * s * ctrl.dx + s * s * to.dx,
      u * u * from.dy + 2 * u * s * ctrl.dy + s * s * to.dy,
    );
  }

  void _drawConduit(
    Canvas canvas,
    Offset ch,
    Offset core,
    Color color,
    double charge,
    double stream,
  ) {
    final path = _conduitPath(ch, core);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: .08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    final glow = (charge * .6 + stream * .4).clamp(0.0, 1.0);
    if (glow > 0) {
      // Soft halo (wide, faint) + crisp bright core — no blur, reads cleaner.
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .28 * glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 + 3 * glow
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(color, Colors.white, .4)!
              .withValues(alpha: .85 * glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawChamber(
    Canvas canvas,
    Offset c,
    double r,
    Color color,
    double charge,
    double stream,
  ) {
    final fill = (charge * (1 - stream)).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .10 + .35 * fill),
            color.withValues(alpha: .04 + .12 * fill),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: .35 + .35 * charge)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(
      c,
      r * 0.82,
      Paint()
        ..color = color.withValues(alpha: .25 + .4 * charge)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      math.pi * 1.15,
      math.pi * 0.5,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: .25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEssence(
    Canvas canvas,
    Offset ch,
    Offset core,
    Color color,
    double stream,
  ) {
    if (stream <= 0) return;
    const count = 14;
    final flow = t * 2.4;
    for (int i = 0; i < count; i++) {
      final base = i / count;
      final s = (base + flow) % 1.0;
      final pos = _conduitPoint(ch, core, s);
      final rad = (1.2 + 2.6 * (1 - s)) * (0.5 + stream);
      final alpha = (.85 * stream * (1 - s * .5)).clamp(0.0, 1.0);
      // Faint halo + crisp mote — crisp particles instead of a blurry smear.
      canvas.drawCircle(
        pos,
        rad * 1.7,
        Paint()..color = color.withValues(alpha: alpha * .25),
      );
      canvas.drawCircle(
        pos,
        rad,
        Paint()
          ..color =
              Color.lerp(color, Colors.white, .35)!.withValues(alpha: alpha),
      );
    }
  }

  void _drawArcs(
    Canvas canvas,
    Offset from,
    Offset core,
    Color color,
    double intensity,
  ) {
    if (intensity <= 0) return;
    final rnd = math.Random((t * 24).floor() * 97 + from.dx.floor());
    final bolts = 1 + (intensity * 2).round();
    final p = Paint()
      ..color = Color.lerp(color, Colors.white, .6)!
          .withValues(alpha: (.55 * intensity).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (int b = 0; b < bolts; b++) {
      const segs = 6;
      final path = Path()..moveTo(from.dx, from.dy);
      for (int i = 1; i <= segs; i++) {
        final s = i / segs;
        final base = _conduitPoint(from, core, s);
        final off = (1 - s) * 18 * (rnd.nextDouble() - 0.5);
        path.lineTo(base.dx + off, base.dy + off * 0.6);
      }
      canvas.drawPath(path, p);
    }
  }

  void _drawCore(
    Canvas canvas,
    Offset c,
    double r,
    Color a,
    Color b,
    Color mix,
    double charge,
    double coreP,
    double burst,
    double reveal,
  ) {
    final fade = (1 - reveal).clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r * 1.35,
      Paint()
        ..color = Colors.white.withValues(alpha: .14 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    void ring(double radius, double rot, Color color, double alpha) {
      const seg = 20;
      final paint = Paint()
        ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < seg; i++) {
        final a0 = (i / seg) * 2 * math.pi + rot;
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: radius),
          a0,
          (2 * math.pi / seg) * .5,
          false,
          paint,
        );
      }
    }

    final ringAlpha = (.25 + charge * .4 + coreP * .4) * (1 - burst) * fade;
    ring(r * 0.95, t * 2 * math.pi * 0.9, a, ringAlpha);
    ring(r * 1.12, -t * 2 * math.pi * 1.1, b, ringAlpha);

    // Energy drawn inward: thin rings that spawn at the rim and contract into
    // the core, fading as they shrink. Reads as intake rather than a vortex.
    if (coreP > 0 && burst < 1) {
      final intake = coreP * (1 - burst) * fade;
      for (int k = 0; k < 2; k++) {
        final pull = ((t * 0.9) + k * 0.5) % 1.0;
        final ir = r * (1.2 - 0.95 * pull);
        canvas.drawCircle(
          c,
          ir,
          Paint()
            ..color = Color.lerp(mix, Colors.white, .2)!.withValues(
                alpha: (.55 * intake * (1 - pull)).clamp(0.0, 1.0))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    final heat = (charge * .4 + coreP * .6).clamp(0.0, 1.0);
    final pulse = math.sin(t * math.pi * 6) * .5 + .5;
    final heartR =
        r * (0.22 + heat * 0.32 + burst * 0.9) * (1 + pulse * 0.05 * heat);
    canvas.drawCircle(
      c,
      heartR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white
                .withValues(alpha: ((.7 * heat + burst) * fade).clamp(0.0, 1.0)),
            mix.withValues(alpha: (.6 * heat * fade).clamp(0.0, 1.0)),
            mix.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: heartR)),
    );
  }

  void _drawShockwave(
    Canvas canvas,
    Offset c,
    double unit,
    Color mix,
    double burst,
  ) {
    final e = Curves.easeOut.transform(burst);
    final r = unit * (0.1 + 0.6 * e);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: (.6 * (1 - e)).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - e) + 1,
    );
    canvas.drawCircle(
      c,
      r * 0.82,
      Paint()
        ..color = mix.withValues(alpha: (.4 * (1 - e)).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - e) + 1,
    );
  }

  // The synthesised cultivation: swirling particles bound inside an alchemical
  // containment sigil. The glyph + accent vary with the fusion outcome
  // (standard fusion, pure element, pure lineage, or both).
  void _drawCultivation(
    Canvas canvas,
    Offset c,
    double unit,
    Color a,
    Color b,
    Color mix,
    double reveal,
  ) {
    final kind = outcome?.kind ?? FusionRevealKind.standard;
    final accent = outcome?.accent ?? mix;
    final isPure = kind != FusionRevealKind.standard;
    final showRays = isPure || (outcome?.foundedNewLine ?? false);

    final e = Curves.easeOutBack.transform(reveal.clamp(0.0, 1.0));
    final R = unit * 0.165 * e;
    if (R <= 0) return;
    final spin = t * 2 * math.pi;

    // Radiant rays for pure / newly-founded lines (drawn behind the sigil).
    if (showRays) {
      final rayCount = kind == FusionRevealKind.pureBoth ? 16 : 12;
      final ray = Paint()
        ..color = accent.withValues(alpha: .28 * reveal)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < rayCount; i++) {
        final ang = (i / rayCount) * 2 * math.pi + spin * 0.15;
        final dir = Offset(math.cos(ang), math.sin(ang));
        final len = R * (1.7 + ((i.isEven) ? 0.5 : 0.0));
        canvas.drawLine(c + dir * R * 1.15, c + dir * len, ray);
      }
    }

    // Outer halo bloom.
    canvas.drawCircle(
      c,
      R * 1.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: .45 * reveal),
            accent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: R * 1.6)),
    );

    // Particle cultivation, clipped to the containment circle. Crisp motes
    // (no blur) for a cleaner read; pure reveals are single-accent themed.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: R)));
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(accent, Colors.white, .4)!.withValues(alpha: .55 * reveal),
            accent.withValues(alpha: .18 * reveal),
            Colors.black.withValues(alpha: .22 * reveal),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: R)),
    );
    final rnd = math.Random(7);
    const motes = 20;
    for (int i = 0; i < motes; i++) {
      final seed = rnd.nextDouble();
      final ang = seed * 2 * math.pi + t * (2.4 + seed * 2.0);
      final orbit = (0.15 + seed * 0.7) * R;
      final p = c + Offset(math.cos(ang), math.sin(ang * 1.2)) * orbit;
      final col = isPure
          ? Color.lerp(accent, Colors.white, seed * .5)!
          : (i.isEven ? a : b);
      canvas.drawCircle(
        p,
        (1.3 + seed * 2.0) * reveal,
        Paint()..color = col.withValues(alpha: (.9 * reveal).clamp(0.0, 1.0)),
      );
    }
    canvas.restore();

    // Containment ring + faint accent outer ring.
    canvas.drawCircle(
      c,
      R,
      Paint()
        ..color = Colors.white.withValues(alpha: .8 * reveal)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawCircle(
      c,
      R * 1.28,
      Paint()
        ..color = accent.withValues(alpha: .4 * reveal)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Rotating dashed ring between the two circles.
    final dash = Paint()
      ..color = accent.withValues(alpha: .75 * reveal)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const seg = 24;
    for (int i = 0; i < seg; i++) {
      final a0 = (i / seg) * 2 * math.pi + spin * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: R * 1.14),
        a0,
        (2 * math.pi / seg) * .45,
        false,
        dash,
      );
    }

    // Outcome-specific central glyph. The triangles/star spin in as they form
    // and then lock into perfect alignment as the reveal settles — `swirl`
    // unwinds to 0, and `lock` flashes them brighter the instant they align.
    final settle = Curves.easeOutCubic.transform(reveal.clamp(0.0, 1.0));
    final swirl = (1 - settle) * (math.pi * 1.25);
    final lock = Curves.easeInOut.transform(_interval(reveal, 0.7, 1.0));
    final glyph = Paint()
      ..color = Colors.white.withValues(alpha: ((.6 + .4 * lock) * reveal).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 + 1.0 * lock
      ..strokeJoin = StrokeJoin.round;
    switch (kind) {
      case FusionRevealKind.standard:
        _interlockedTriangles(canvas, c, R * 0.78, swirl, glyph);
        break;
      case FusionRevealKind.pureElement:
        _elementGlyph(canvas, c, R * 0.72, outcome?.element, swirl, settle, glyph);
        break;
      case FusionRevealKind.pureSpecies:
        _interlockedTriangles(canvas, c, R * 0.82, swirl, glyph);
        break;
      case FusionRevealKind.pureBoth:
        _interlockedTriangles(canvas, c, R * 0.82, swirl, glyph);
        _elementGlyph(canvas, c, R * 0.46, outcome?.element, swirl, settle, glyph);
        break;
    }

    // A clean bloom of light at the moment of alignment.
    if (lock > 0) {
      canvas.drawCircle(
        c,
        R * (0.9 + 0.3 * lock),
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: .0),
              Colors.white.withValues(alpha: .22 * lock),
              Colors.white.withValues(alpha: .0),
            ],
            stops: const [0.55, 0.8, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: R * 1.2)),
      );
    }

    // Bright core spark.
    canvas.drawCircle(
      c,
      R * 0.14,
      Paint()..color = Colors.white.withValues(alpha: .9 * reveal),
    );
  }

  // Two counter-rotating triangles that converge into an aligned six-pointed
  // star as [swirl] unwinds to 0.
  void _interlockedTriangles(
      Canvas canvas, Offset c, double rad, double swirl, Paint p) {
    _triangle(canvas, c, rad, -math.pi / 2 + swirl, p);
    _triangle(canvas, c, rad, math.pi / 2 - swirl, p);
  }

  void _triangle(Canvas canvas, Offset c, double rad, double rot, Paint p) {
    final path = Path();
    for (int i = 0; i < 3; i++) {
      final ang = rot + i * (2 * math.pi / 3);
      final v = c + Offset(math.cos(ang), math.sin(ang)) * rad;
      i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  // Classic alchemical element symbols for pure-element reveals. The triangle
  // spins in via [swirl]; the elemental bar fades in once it has settled.
  void _elementGlyph(Canvas canvas, Offset c, double rad, String? element,
      double swirl, double settle, Paint p) {
    final el = (element ?? '').toLowerCase();
    final pointsUp = el == 'fire' || el == 'air' || el == 'lava';
    final withBar = el == 'air' || el == 'earth';
    final base = pointsUp ? -math.pi / 2 : math.pi / 2;
    _triangle(canvas, c, rad, base + swirl * 0.6, p);
    if (withBar && settle > 0.6) {
      final barAlpha = _interval(settle, 0.6, 1.0);
      final y = c.dy + (pointsUp ? 1 : -1) * rad * 0.18;
      final half = rad * 0.42;
      canvas.drawLine(
        Offset(c.dx - half, y),
        Offset(c.dx + half, y),
        Paint()
          ..color = (p.color).withValues(
              alpha: (p.color.a * barAlpha).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = p.strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChamberPainter old) =>
      old.t != t ||
      old.a != a ||
      old.b != b ||
      old.layout != layout ||
      old.outcome != outcome;
}

// ---------------------------------------------------------------------------
// Chrome.
// ---------------------------------------------------------------------------
class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({required this.t, required this.outcome});
  final double t;
  final FusionRevealData? outcome;

  @override
  Widget build(BuildContext context) {
    final (text, vis) = _labelFor(t);
    final isReveal = t >= _Phase.revealStart;
    // Pure-line reveals get the accent colour for their headline.
    final color = (isReveal && outcome != null && outcome!.kind != FusionRevealKind.standard)
        ? Color.lerp(outcome!.accent, Colors.white, .35)!
        : const Color(0xFFE8EAED);
    return Opacity(
      opacity: vis,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: isReveal ? 15 : 13,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  (String, double) _labelFor(double t) {
    if (t < _Phase.chargeStart) {
      return ('PRIMING CHAMBERS', _interval(t, 0.02, 0.10));
    }
    if (t < _Phase.streamStart) return ('CHANNELING ESSENCE', 1.0);
    if (t < _Phase.coreStart) return ('GENETIC FUSION', 1.0);
    if (t < _Phase.revealStart) return ('STABILIZING REACTION', 1.0);
    final caption = outcome?.caption ?? 'CULTIVATION SYNTHESIZED';
    return (caption, _interval(t, _Phase.revealStart, 0.95));
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'SKIP',
                style: TextStyle(
                  color: Color(0xFFE8EAED),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.fast_forward_rounded,
                  size: 16, color: Color(0xFFE8EAED)),
            ],
          ),
        ),
      ),
    );
  }
}
