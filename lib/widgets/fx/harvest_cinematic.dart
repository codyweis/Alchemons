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
// The apparatus is particles ([HarvestParticleField]), the same as the Flame
// field in the scenes: a shell of the device's grains round the specimen; on
// a take the specimen turns to grains of itself, folds into a sphere of its
// own inside the shell, and lifts away; on a break the shell tears open.
//
// No caption. It used to spell the beats out in monospace ("THE FIELD
// HOLDS", "CONTAINMENT BROKEN"); the picture says it.
//
// No MaskFilter anywhere: light is radial-gradient pools.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvest_particles.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// A live specimen standing on the host's own screen, under the overlay, for
/// the take to turn to grains: how to read it, and how to cut it away.
class HarvestTarget {
  const HarvestTarget({required this.read, required this.onCut});

  /// Reads it as it is showing: its grains, where its centre is on screen,
  /// and how many logical pixels one grain unit is. Null if it cannot be.
  final Future<(SpecimenGrains, Offset, double)?> Function() read;

  /// The take's crest, in grain units from its centre (see
  /// [SpriteCrestClipper]); null hands it back whole.
  final ValueChanged<double?> onCut;
}

/// Show the full-screen harvest cinematic and run [task] while it plays.
///
/// The route closes only after the resolution has played, and the resolution
/// does not begin until [task] has answered — so the specimen is still
/// fighting the field while the roll is being made. Returns the task's result.
/// [targetSprite] null plays the apparatus over whatever is already on
/// screen, for callers whose specimen is standing there in their own layout.
///
/// The alternative is what this used to force everywhere: a freshly built
/// copy of the creature on a dark card, so the animal being harvested
/// blinked out and a duplicate appeared to be caught in its place. The
/// scenes solved that with their own in-world field; screens that are not
/// Flame scenes could not, and got the duplicate.
Future<bool> showHarvestCinematic({
  required BuildContext context,
  Widget? targetSprite,
  required Color targetColor,
  HarvesterProfile? profile,
  Duration minDuration = const Duration(milliseconds: 1600),
  Offset? focus,
  double focusScale = 1,
  HarvestTarget? liveTarget,
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
            profile: profile ?? HarvesterProfile.forBiome(null),
            minDuration: minDuration,
            focus: focus,
            focusScale: focusScale,
            liveTarget: liveTarget,
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
    required this.profile,
    required this.minDuration,
    required this.task,
    this.focus,
    this.focusScale = 1,
    this.liveTarget,
  });

  /// The specimen on the host's screen, when [targetSprite] is null and the
  /// host can hand it over for the take.
  final HarvestTarget? liveTarget;

  /// How large the field is drawn, for a live specimen smaller or larger
  /// than the stage it was designed around.
  final double focusScale;

  /// Where on screen the specimen stands, when it is a live one standing
  /// somewhere other than the middle. The field closes on that spot.
  final Offset? focus;

  /// Null when the specimen is already on screen behind this overlay.
  final Widget? targetSprite;
  final Color targetColor;

  /// The apparatus doing the taking.
  final HarvesterProfile profile;
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

  /// The apparatus, and on a take the specimen, in particles.
  late final HarvestParticleField _field = HarvestParticleField(
    profile: widget.profile,
    cage: 420 * 0.30,
    specimenColor: widget.targetColor,
  );

  /// The sprite this page draws itself, read into grains for a take.
  final GlobalKey _spriteKey = GlobalKey();

  /// Seconds since the field engaged, for its turning.
  double get _time =>
      _seize.value * widget.minDuration.inMicroseconds / 1e6 +
      (_resolving
          ? _resolve.value * _resolve.duration!.inMicroseconds / 1e6
          : 0);

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
    HarvestParticleField.announce(HarvestBeat.engage);
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
    if (_success ?? false) {
      // Read the specimen before the take, so the crest has grains to
      // leave behind it. Never held up for long: without them the field
      // still takes, it just takes nothing you can see go.
      try {
        await _readSpecimen().timeout(const Duration(milliseconds: 400));
      } catch (_) {}
    }
    final seconds = (_success ?? false)
        ? HarvestParticleField.takeSeconds
        : HarvestParticleField.breakSeconds;
    _resolve.duration = Duration(milliseconds: (seconds * 1000).round());
    HarvestParticleField.announce(
      (_success ?? false) ? HarvestBeat.take : HarvestBeat.shatter,
    );
    await _resolve.forward(from: 0);
    // A specimen that broke free is handed back whole. One that was taken is
    // left cut away: the host hides it, or it would flash back as this goes.
    if (!(_success ?? false)) widget.liveTarget?.onCut(null);
    // A beat on the aftermath before the world comes back.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted) Navigator.of(context).pop<bool>(_success ?? false);
  }

  /// Where on screen the stage's centre is, and how much it is scaled.
  Offset _stageCentre(Size screen) =>
      widget.focus ?? Offset(screen.width / 2, screen.height / 2);

  Future<void> _readSpecimen() async {
    if (widget.targetSprite != null) {
      final box = _spriteKey.currentContext?.findRenderObject();
      if (box is! RenderRepaintBoundary || !box.attached) return;
      await WidgetsBinding.instance.endOfFrame;
      final grains = await SpecimenGrains.capture(box, pixelRatio: 2);
      if (grains != null) _field.setSpecimen(grains, at: Offset.zero);
      return;
    }
    final live = widget.liveTarget;
    if (live == null || !mounted) return;
    final read = await live.read();
    if (read == null || !mounted) return;
    final (grains, at, scale) = read;
    final centre = _stageCentre(MediaQuery.sizeOf(context));
    // Into the stage's own units, through the scale it is drawn at.
    _field.setSpecimen(
      grains,
      at: (at - centre) / widget.focusScale,
      scale: scale / widget.focusScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Lighter than the old 70% + vignette. The stage has to isolate the
      // specimen, not hide it — and when the specimen is the live one on
      // the screen underneath, the stage must not hide THAT either, so the
      // scrim is only there to separate a sprite this page drew itself.
      backgroundColor: widget.targetSprite == null
          ? Colors.transparent
          : Colors.black.withValues(alpha: 0.62),
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
          final cut = _field.cutY(beat.collapse);
          // A live specimen on the host's screen is cut there — after this
          // frame, because the host's sprite is built by another widget and
          // cannot be marked dirty from inside this build.
          final live = widget.liveTarget;
          if (live != null && _field.hasSpecimen) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => live.onCut(cut),
            );
          }
          Widget field({required bool back}) => Positioned.fill(
            child: CustomPaint(
              painter: _FieldPainter(
                field: _field,
                beat: beat,
                time: _time,
                back: back,
              ),
            ),
          );
          final stage = SizedBox(
            width: 420,
            height: 420,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The far side of the field, behind the specimen.
                field(back: true),
                if (widget.targetSprite != null)
                  _Specimen(
                    beat: beat,
                    sprite: widget.targetSprite!,
                    color: widget.targetColor,
                    captureKey: _spriteKey,
                    cutY: _field.hasSpecimen ? cut : null,
                  ),
                // ...and the near side, over it.
                field(back: false),
              ],
            ),
          );
          final focus = widget.focus;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (focus == null)
                Center(
                  child: Transform.scale(
                    scale: widget.focusScale,
                    child: stage,
                  ),
                )
              else
                Positioned(
                  left: focus.dx - 210,
                  top: focus.dy - 210,
                  width: 420,
                  height: 420,
                  child: Transform.scale(
                    scale: widget.focusScale,
                    child: stage,
                  ),
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
    // A take holds it still at once, so it stands where its grains are read.
    if (resolving) return 1.0 - _interval(resolve, 0.0, success ? 0.08 : 0.22);
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
    required this.captureKey,
    this.cutY,
  });

  final _HarvestBeat beat;
  final Widget sprite;
  final Color color;

  /// Read into grains from here for a take.
  final GlobalKey captureKey;

  /// The take's crest, once it has grains to leave behind; null before.
  final double? cutY;

  @override
  Widget build(BuildContext context) {
    // Arrives at full size, flinches when the field bites, then swells
    // against it on every push.
    final appear = Curves.easeOut.transform(_interval(beat.seize, 0.0, 0.2));
    final flinch = math.sin(beat.lock * math.pi); // 0 → 1 → 0
    var scale = 0.86 + 0.14 * appear;
    scale -= 0.09 * flinch;
    scale += 0.07 * beat.push;

    // A take is the field's now: the specimen holds still and is cut away
    // behind the crest as its grains are drawn down. Without grains (it
    // could not be read) it fades as the field takes it.
    final c = cutY == null ? Curves.easeIn.transform(beat.collapse) : 0.0;
    // ...or a hard recoil and gone.
    final sh = Curves.easeOutCubic.transform(beat.shatter);

    final sx = scale * (1.0 - 0.86 * c) * (1.0 + 0.22 * sh);
    final sy = scale * (1.0 - 0.94 * c) * (1.0 + 0.10 * sh);

    // Fighting: a fast tremble while the field holds it.
    final tremble = (beat.lock + beat.pressure) * (beat.resolving ? 0 : 1);
    final jx = math.sin(beat.strain * math.pi * 14) * 3.4 * tremble;
    final jy = math.cos(beat.strain * math.pi * 11) * 2.0 * tremble;

    final opacity = (appear * (1.0 - c) * (1.0 - sh)).clamp(0.0, 1.0);

    final cut = cutY ?? double.negativeInfinity;
    return ClipRect(
      clipper: SpriteCrestClipper(cut),
      clipBehavior: cut == double.negativeInfinity ? Clip.none : Clip.hardEdge,
      child: Transform.translate(
        offset: Offset(jx, jy + 62 * c),
        child: Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(sx, sy, 1),
            child: RepaintBoundary(
              key: captureKey,
              child: SizedBox(
                width: _kSpecimenBox,
                height: _kSpecimenBox,
                child: Center(child: sprite),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One side of the particle field (see [HarvestParticleField]) at this beat.
class _FieldPainter extends CustomPainter {
  _FieldPainter({
    required this.field,
    required this.beat,
    required this.time,
    required this.back,
  });

  final HarvestParticleField field;
  final _HarvestBeat beat;
  final double time;
  final bool back;

  @override
  void paint(Canvas canvas, Size size) => field.paint(
    canvas,
    Offset(size.width / 2, size.height / 2),
    closing: beat.closing,
    lock: beat.lock,
    push: beat.push,
    strain: beat.strain,
    time: time,
    take: beat.collapse,
    shatter: beat.shatter,
    back: back,
  );

  @override
  bool shouldRepaint(covariant _FieldPainter old) => true;
}

/// 0 before [start], 1 after [end], clamped in between.
double _interval(double t, double start, double end) {
  final v = ((t - start) / (end - start)).clamp(0.0, 1.0);
  return v.isNaN ? 0.0 : v;
}
