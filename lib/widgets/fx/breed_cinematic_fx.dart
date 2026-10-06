import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/widgets/fx/fusion_burst.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

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
/// From the core on it is all particles ([FusionBurstField]): [grains] — what
/// the two specimens were read into, when the host merged them itself — are
/// held as one hot knot, erupt, and gather back into the cultivation with its
/// sigil drawn in grains. Without them it uses balls of the two colours.
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
  List<SpecimenGrains>? grains,
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
        grains: grains,
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
//   scatter: 0.24 .. 0.44  specimens come apart where they stand
//   stream : 0.44 .. 0.72  only then does the essence cross to the core
//   core   : 0.49 ..       the particles take over: from here the timeline
//                          is [FusionBurstField]'s, in seconds since the core
//                          (the knot, the eruption — heavy haptic — and the
//                          cultivation gathering out of it)
// Hosts that merge the pair themselves join at the core. The opening (intake
// + charge) is only for the ones that cannot, and is brief.
class _Phase {
  static const intakeStart = 0.00, intakeEnd = 0.13;
  static const chargeStart = 0.11, chargeEnd = 0.29;
  static const streamStart = 0.44, streamEnd = 0.72;
  // Where the particles take over (see [FusionBurstField]).
  static const coreStart = 0.49;

  // THE MERGE, in two beats rather than one. The specimens used to hold their
  // shape all the way into the core and only come apart once they were on top
  // of each other, so the merge read as two animals colliding. Now they come
  // apart FIRST, where they stand, and it is the matter that travels: each
  // one scatters in its own chamber, and the essence stream carries it to the
  // core to be put back together as something else.
  //
  // The two beats must not overlap, or the first thing you see is the pair
  // sliding together while still solid — which is the old collision read with
  // extra steps. So: they come apart WHERE THEY STAND and are completely gone
  // before anything crosses the gap. The specimens do not travel at all; the
  // essence stream is the entire crossing, and it does not start until the
  // scatter has finished.
  static const disintegrateStart = 0.24, disintegrateEnd = 0.44;
  static const dissolveStart = 0.24, dissolveEnd = 0.42;
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
    required this.grains,
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
  final List<SpecimenGrains>? grains;
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

  /// Keeps the last frame alive while the database catches up.
  ///
  /// The route pops when the timeline AND the task have both finished, and
  /// the timeline usually wins — so the reveal landed and then held one
  /// completely still frame until the write came back. A held frame at the
  /// end of a motion does not read as a pause, it reads as a hang. This
  /// breathes underneath it so the moment stays alive.
  late final AnimationController _settleCtrl;
  T? _result;
  Object? _err;
  bool _taskDone = false;
  bool _skipped = false;
  bool _heavyFired = false; // burst haptic guard
  bool _soundStarted = false;
  AudioController? _audio;

  /// Keeps the settled cultivation turning while the route waits on the task.
  final Stopwatch _clock = Stopwatch()..start();

  /// The particles, made once the cultivation's size is known.
  FusionBurstField? _burst;

  /// Seconds since the core: the particles' own time.
  double get _u =>
      (_ctrl.value - _Phase.coreStart) * _ctrl.duration!.inMicroseconds / 1e6;

  FusionBurstField _burstFor(double radius) {
    final existing = _burst;
    if (existing != null && existing.radius == radius) return existing;
    return _burst = FusionBurstField(
      grains:
          widget.grains ??
          [
            SpecimenGrains.disc(widget.leftColor, radius: radius * 0.45),
            SpecimenGrains.disc(widget.rightColor, radius: radius * 0.45),
          ],
      radius: radius,
    );
  }

  @override
  void initState() {
    super.initState();

    // [minDuration] is how long the route should VISIBLY last, so when it
    // joins the timeline part-way the controller has to be stretched to make
    // the remaining span take that long.
    final span = widget.drawSpecimens ? 1.0 : (1.0 - _Phase.coreStart);
    _ctrl =
        AnimationController(
            vsync: this,
            duration: Duration(
              microseconds: (widget.minDuration.inMicroseconds / span).round(),
            ),
          )
          ..addStatusListener(_maybeClose)
          ..addListener(_pulseHaptics);

    // PICK UP WHERE THE MERGE LEFT OFF.
    //
    // When the caller has already hauled the real specimens together, the
    // intake, the charge and the streams have all just happened for real —
    // replaying them here gave you two lit chambers with nothing in them,
    // essence pouring out of empty glass, and then a blob over the pair you
    // had just watched meet. The route joins the timeline at the core and
    // plays only what is left: the eruption and the reveal.
    _ctrl.value = widget.drawSpecimens ? 0.0 : _Phase.coreStart;

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _settleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );

    HapticFeedback.mediumImpact();
    _ctrl.forward(from: _ctrl.value);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audio = context.audio;
  }

  @override
  void dispose() {
    _audio?.stopSoundOwner(this);
    _ctrl.dispose();
    _flashCtrl.dispose();
    _settleCtrl.dispose();
    super.dispose();
  }

  // Fire a heavy impact exactly once as the core erupts.
  void _pulseHaptics() {
    // The cue is scored from the core on, so it starts there -- at once when
    // the route joins the timeline at the core, later when it plays the
    // intake itself.
    if (!_soundStarted && _u >= 0 && !_skipped) {
      _soundStarted = true;
      context.sound(SoundCue.fusionEruption, owner: this);
    }
    if (!_heavyFired && _u >= FusionBurstField.burstAt) {
      _heavyFired = true;
      HapticFeedback.heavyImpact();
    }
  }

  void _skip() {
    if (_skipped) return;
    _skipped = true;
    // Mid-eruption: the cue would carry on over the reveal it scores.
    _audio?.stopSoundOwner(this);
    final remaining = (1.0 - _ctrl.value).clamp(0.0, 1.0);
    _ctrl.animateTo(
      1.0,
      duration: Duration(
        milliseconds: (650 * remaining).clamp(180, 650).toInt(),
      ),
      curve: Curves.easeOutCubic,
    );
    setState(() {});
  }

  void _maybeClose(AnimationStatus s) async {
    if (s != AnimationStatus.completed) return;
    if (!_taskDone) {
      // Landed early. Breathe until the result arrives rather than freezing.
      if (!_settleCtrl.isAnimating) _settleCtrl.repeat(reverse: true);
      return;
    }
    _settleCtrl.stop();

    try {
      await _flashCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 70));
    } finally {
      if (mounted) {
        // Played through: its ring-out carries over the chamber coming back.
        _audio?.releaseSoundOwner(this);
        Navigator.of(context).pop<T>(_err != null ? null : _result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final anchored =
        widget.coreRect != null ||
        widget.leftSlotRect != null ||
        widget.rightSlotRect != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (_, c) {
          final size = Size(c.maxWidth, c.maxHeight);

          // Resolve anchor centres in screen space (with sensible fallbacks).
          final leftC =
              widget.leftSlotRect?.center ??
              Offset(size.width * 0.30, size.height * 0.46);
          final rightC =
              widget.rightSlotRect?.center ??
              Offset(size.width * 0.70, size.height * 0.46);
          final coreC =
              widget.coreRect?.center ??
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

          final driver = Listenable.merge([
            _ctrl,
            _settleCtrl,
            if (widget.outcome != null) widget.outcome!,
          ]);
          final burst = _burstFor(math.min(size.width, size.height) * 0.165);

          return AnimatedBuilder(
            animation: driver,
            builder: (_, __) {
              final t = _ctrl.value;
              final outcome = widget.outcome?.value;
              // Only ever non-zero in the wait after the timeline lands.
              final settle = _settleCtrl.value;

              // Background darkens once the reaction takes focus; when
              // anchored we hold the live screen visible during intake.
              final bg = anchored
                  ? _interval(t, 0.14, 0.34)
                  : _interval(t, 0.0, 0.10);

              // Screen shake: ramps through the knot, peaks at the eruption.
              final u = _u;
              final shake = u < FusionBurstField.burstAt
                  ? _interval(u, 0, FusionBurstField.burstAt) * 0.55
                  : 1 - _interval(u, FusionBurstField.burstAt, 0.85);
              final amp = shake * 12.0;
              final dx = math.sin(t * math.pi * 30) * amp;
              final dy = math.cos(t * math.pi * 24) * amp * .6;

              // A slow swell around the landed reveal, anchored on the core
              // so nothing appears to drift. Zero for the whole timeline;
              // it only exists during the wait at the end.
              return Transform.scale(
                scale: 1 + 0.016 * settle,
                origin: Offset.zero,
                alignment: Alignment.topLeft,
                child: Transform.translate(
                  offset: coreC * (-0.016 * settle),
                  child: Stack(
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
                                  u: u,
                                  a: widget.leftColor,
                                  b: widget.rightColor,
                                  layout: layout,
                                  outcome: outcome,
                                  drawChambers: widget.drawSpecimens,
                                  burst: burst,
                                  clock: _clock.elapsedMicroseconds / 1e6,
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
                            opacity: _flashCtrl.drive(
                              CurveTween(curve: Curves.easeOut),
                            ),
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
                        child: Center(
                          child: _PhaseLabel(t: t, u: u, outcome: outcome),
                        ),
                      ),

                      // Skip control — bottom right, where the hatching
                      // cinematic puts its own. Two ceremonies a minute apart
                      // should not hide the same control in two places.
                      if (widget.allowSkip)
                        Positioned(
                          bottom: 24,
                          right: 24,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _skipped ? 0.0 : 1.0,
                            child: _SkipButton(onTap: _skip),
                          ),
                        ),
                    ],
                  ),
                ),
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
    final dissolve = _interval(t, _Phase.dissolveStart, _Phase.dissolveEnd);

    // They do not travel. Standing still is the whole point: the pair coming
    // together before they are gone reads as a collision, so the crossing is
    // left entirely to the essence stream, which starts once they are.
    final pos = from;

    // COMING APART. They pop into their chambers, then break outward rather
    // than shrinking away — a body giving up its shape reads as expansion and
    // thinning, where a collapse to a point just reads as the sprite being
    // switched off. Both curves are ease-OUT so the break is visible from its
    // first frames; an ease-in spends the early window looking untouched.
    final pop = Curves.easeOutBack.transform(intake);
    final comeApart = Curves.easeOutCubic.transform(dissolve);
    final swell = _interval(t, _Phase.chargeStart, _Phase.dissolveStart);
    final scale = (0.90 + 0.14 * pop) + 0.10 * swell + 0.34 * comeApart;
    final opacity = (1.0 - Curves.easeOutQuad.transform(dissolve)).clamp(
      0.0,
      1.0,
    );

    // Agitation: a buzz while the charge builds, rising to a hard shudder as
    // they are dragged together.
    // Agitation peaks as they break up. It shakes hardest at the start of the
    // dissolve and eases off as there is less left to shake.
    final buzz = _interval(t, _Phase.chargeStart, _Phase.dissolveStart);
    final shudder = comeApart * (1.0 - dissolve);
    final jitter = math.sin(t * math.pi * 40) * (buzz * 2.2 + shudder * 7.0);

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
          scale: scale.clamp(0.1, 1.6),
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
    required this.u,
    required this.a,
    required this.b,
    required this.layout,
    required this.outcome,
    required this.drawChambers,
    required this.burst,
    required this.clock,
  });

  final double t;

  /// Seconds since the core (negative before it).
  final double u;
  final Color a, b;
  final _FusionLayout layout;
  final FusionRevealData? outcome;
  final FusionBurstField burst;
  final double clock;

  /// False once the caller has already merged the real specimens where they
  /// stood. Drawing the apparatus then leaves two lit chambers with nothing
  /// in them and two conduits carrying essence out of nowhere.
  final bool drawChambers;

  @override
  void paint(Canvas canvas, Size size) {
    final leftCh = layout.leftC;
    final rightCh = layout.rightC;
    final core = layout.coreC;
    final chR = layout.chR;

    final charge = _interval(t, _Phase.chargeStart, _Phase.chargeEnd);
    final stream = _interval(t, _Phase.streamStart, _Phase.streamEnd);
    final scatter = _interval(
      t,
      _Phase.disintegrateStart,
      _Phase.disintegrateEnd,
    );

    if (drawChambers) {
      _drawConduit(canvas, leftCh, core, a, charge, stream);
      _drawConduit(canvas, rightCh, core, b, charge, stream);

      _drawChamber(canvas, leftCh, chR, a, charge, stream);
      _drawChamber(canvas, rightCh, chR, b, charge, stream);

      // The specimens come apart here, before anything crosses: motes break
      // off each chamber and are drawn back toward the conduit mouth, so the
      // essence flowing to the core is visibly what was standing there.
      _drawDisintegration(canvas, leftCh, core, chR, a, scatter);
      _drawDisintegration(canvas, rightCh, core, chR, b, scatter);

      _drawEssence(canvas, leftCh, core, a, stream);
      _drawEssence(canvas, rightCh, core, b, stream);

      final arcs = charge * (1 - _interval(u, 0, FusionBurstField.burstAt));
      if (arcs > 0) {
        _drawArcs(canvas, leftCh, core, a, arcs);
        _drawArcs(canvas, rightCh, core, b, arcs);
      }
    }
    if (u < 0) return;

    // FROM THE CORE ON, IT IS ALL PARTICLES. This used to be dashed rings
    // turning round the core, a hoop of a shockwave and an outlined vial
    // with a line-drawn star in it — UI pulses, next to a merge made of the
    // creatures' own grains. Now those grains are the core, the eruption and
    // the cultivation, and light is only ever a soft pool.
    final kind = outcome?.kind ?? FusionRevealKind.standard;
    final pure = kind != FusionRevealKind.standard;
    final accent = outcome?.accent;
    final mix = Color.lerp(a, b, 0.5)!;
    final glow = accent ?? mix;
    final r = burst.radius;
    final burstT = u - FusionBurstField.burstAt;

    // The heat of the knot, swelling until it goes.
    final heat = _interval(u, 0, FusionBurstField.burstAt);
    final heart = burstT < 0 ? 1.0 : 1 - _interval(burstT, 0, 0.18);
    if (heart > 0) {
      _softPool(
        canvas,
        core,
        r * (0.35 + 0.45 * heat),
        Colors.white,
        mix,
        (0.25 + 0.6 * heat) * heart,
      );
    }
    // The eruption's light: wide, faint, and gone fast.
    if (burstT >= 0 && burstT < 0.45) {
      final e = burstT / 0.45;
      _softPool(
        canvas,
        core,
        r * (0.8 + 2.6 * Curves.easeOut.transform(e)),
        Colors.white,
        glow,
        0.55 * (1 - e) * (1 - e),
      );
    }
    // The cultivation's own light, coming up as it forms.
    final formed = _interval(u, 0.7, FusionBurstField.settledAt);
    if (formed > 0) {
      _softPool(
        canvas,
        core,
        r * 1.7,
        glow,
        glow,
        (pure ? 0.42 : 0.3) * formed,
        inner: 0.0,
      );
    }

    burst.paint(
      canvas,
      core,
      u,
      colors: [a, b],
      accent: accent,
      pure: pure,
      sigil: switch (kind) {
        FusionRevealKind.pureElement => FusionSigil.element,
        FusionRevealKind.pureBoth => FusionSigil.octagramAndElement,
        _ => FusionSigil.octagram,
      },
      element: outcome?.element,
      clock: clock,
    );

    // A line newly founded gets a slow corona: grains streaming off the
    // cultivation in rays, instead of the ruled lines it used to have.
    if (pure || (outcome?.foundedNewLine ?? false)) {
      _drawCorona(canvas, core, r, accent ?? mix, formed, kind);
    }
  }

  /// A radial pool of light: [hot] at the centre running out to [edge].
  void _softPool(
    Canvas canvas,
    Offset c,
    double radius,
    Color hot,
    Color edge,
    double alpha, {
    double inner = 0.45,
  }) {
    if (alpha <= 0 || radius <= 0) return;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            hot.withValues(alpha: alpha.clamp(0.0, 1.0)),
            edge.withValues(alpha: (alpha * 0.55).clamp(0.0, 1.0)),
            edge.withValues(alpha: 0),
          ],
          stops: [0.0, inner == 0 ? 0.35 : inner, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
  }

  final _corona = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _drawCorona(
    Canvas canvas,
    Offset c,
    double r,
    Color accent,
    double formed,
    FusionRevealKind kind,
  ) {
    if (formed <= 0) return;
    final rays = kind == FusionRevealKind.pureBoth ? 16 : 12;
    const perRay = 7;
    final pts = Float32List(rays * perRay * 2);
    var n = 0;
    final turn = clock * 0.08;
    for (var i = 0; i < rays; i++) {
      final ang = i / rays * 2 * math.pi + turn;
      final dir = Offset(math.cos(ang), math.sin(ang));
      final reach = i.isEven ? 1.0 : 0.7;
      for (var k = 0; k < perRay; k++) {
        // Each grain runs out along its ray and starts again.
        final f = (clock * 0.35 + k / perRay + i * 0.13) % 1.0;
        final p = c + dir * r * (1.15 + 0.9 * reach * f);
        pts[n++] = p.dx;
        pts[n++] = p.dy;
      }
    }
    _corona
      ..strokeWidth = 2.2
      ..color = Color.lerp(
        accent,
        Colors.white,
        0.35,
      )!.withValues(alpha: 0.55 * formed);
    canvas.drawRawPoints(ui.PointMode.points, pts, _corona);
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
          ..color = Color.lerp(
            color,
            Colors.white,
            .4,
          )!.withValues(alpha: .85 * glow)
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

  /// A specimen giving up its shape: motes burst outward off the chamber, hang
  /// at the edge, then are pulled back in toward the conduit mouth. Seeded off
  /// the index so the scatter is stable frame to frame rather than boiling.
  void _drawDisintegration(
    Canvas canvas,
    Offset ch,
    Offset core,
    double chR,
    Color color,
    double scatter,
  ) {
    if (scatter <= 0 || scatter >= 1) return;

    const count = 26;
    // Out fast, then reeled back: peaks early and returns to the mouth.
    final out = Curves.easeOutCubic.transform(math.min(1.0, scatter * 2.2));
    final pull = Curves.easeInCubic.transform(
      math.max(0.0, (scatter - 0.45) / 0.55),
    );
    final toward = (core - ch);
    final towardLen = toward.distance;
    final dir = towardLen == 0 ? Offset.zero : toward / towardLen;

    for (int i = 0; i < count; i++) {
      // Deterministic pseudo-scatter: no RNG per frame, so motes hold still.
      final ang = (i * 2.39996) % (math.pi * 2);
      final spread = 0.55 + ((i * 37) % 100) / 100.0 * 0.85;
      final reach = chR * (0.35 + spread * 1.15) * out;

      final burstAt = ch + Offset(math.cos(ang), math.sin(ang)) * reach;
      // Reeled toward the conduit mouth rather than straight home, so the
      // motion hands off to the stream instead of stopping dead.
      final mouth = ch + dir * (chR * 0.9);
      final pos = Offset.lerp(burstAt, mouth, pull)!;

      final fade = (1.0 - scatter * 0.65).clamp(0.0, 1.0);
      final rad = (0.9 + 2.0 * (1 - out)) * (0.6 + scatter);
      canvas.drawCircle(
        pos,
        rad * 1.8,
        Paint()..color = color.withValues(alpha: fade * 0.22),
      );
      canvas.drawCircle(
        pos,
        rad,
        Paint()
          ..color = Color.lerp(
            color,
            Colors.white,
            0.4,
          )!.withValues(alpha: fade * 0.9),
      );
    }
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
          ..color = Color.lerp(
            color,
            Colors.white,
            .35,
          )!.withValues(alpha: alpha),
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
      ..color = Color.lerp(
        color,
        Colors.white,
        .6,
      )!.withValues(alpha: (.55 * intensity).clamp(0.0, 1.0))
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

  @override
  bool shouldRepaint(covariant _ChamberPainter old) =>
      old.t != t ||
      old.u != u ||
      old.clock != clock ||
      old.a != a ||
      old.b != b ||
      old.layout != layout ||
      old.outcome != outcome;
}

// ---------------------------------------------------------------------------
// Chrome.
// ---------------------------------------------------------------------------
class _PhaseLabel extends StatelessWidget {
  const _PhaseLabel({required this.t, required this.u, required this.outcome});
  final double t;

  /// Seconds since the core.
  final double u;
  final FusionRevealData? outcome;

  bool get _isReveal => u >= FusionBurstField.burstAt + 0.45;

  @override
  Widget build(BuildContext context) {
    final (text, vis) = _labelFor(t);
    final isReveal = _isReveal;
    // Pure-line reveals get the accent colour for their headline.
    final color =
        (isReveal &&
            outcome != null &&
            outcome!.kind != FusionRevealKind.standard)
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
    if (u < 0) return ('GENETIC FUSION', 1.0);
    if (!_isReveal) return ('STABILIZING REACTION', 1.0);
    final caption = outcome?.caption ?? 'CULTIVATION SYNTHESIZED';
    final from = FusionBurstField.burstAt + 0.45;
    return (caption, _interval(u, from, from + 0.5));
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
        onTap: context.soundAction(onTap),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // The hatching cinematic's chrome, to the pixel.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: const Color(0x2EFFFFFF)),
          ),
          child: const Text(
            'SKIP',
            style: TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}
