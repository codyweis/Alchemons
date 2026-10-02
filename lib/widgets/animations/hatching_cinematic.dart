import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/wild_fusion.dart' show AlchemonMutation;
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart' show mutationAccent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:alchemons/widgets/animations/hatch_shell.dart';
import 'package:alchemons/widgets/nursery/hatch_curtain.dart';

/// Small helper to evaluate an Interval-like curve without allocating
/// CurvedAnimation objects every frame.
double _intervalValue(double t, double begin, double end, Curve curve) {
  if (t <= begin) return 0.0;
  if (t >= end) return 1.0;
  final localT = (t - begin) / (end - begin);
  return curve.transform(localT.clamp(0.0, 1.0));
}

/// Fraction of the ceremony the shell owns. Raised from 0.80: the tail left
/// 1.65s with no shell on screen — the silhouette fading in over nothing, then
/// simply sitting there — which is what made the ceremony end static.
const double _kShellWindow = 0.88;

/// Where the ceremony begins dissolving: the frame the silhouette's scale-in
/// lands on, which is also where the shell's arc ends. Past here nothing moves
/// under its own power.
const double _kDissolveFrom = 0.840;

/// Where the ceremony hands over to the next screen. The dissolve above
/// reaches zero exactly here, so the handover happens on an empty frame.
///
/// This is the prototype's own ending: its strands fade to zero alpha across
/// the unravel, so the arc finishes on nothing rather than on a picture. A
/// handover onto an empty frame cannot be seen as a cut, because there is no
/// image left to cut away from.
///
/// Popping at [_kDissolveFrom] instead -- with the ceremony still at full
/// brightness -- is what produced the hard seam: `await Navigator.push`
/// completes when the pop BEGINS, not when its reverse transition ends, so the
/// result dialog opened on top of a cinematic that had not faded yet, and
/// covered the fade entirely. Roughly 0.035 of the timeline (~260ms) separates
/// the two so the dissolve has time to actually land.
const double _kHandoverAt = 0.865;

/// When the newborn's grains start to leave the unravelling shell for their
/// places in its silhouette; they are all home by the reveal's end (0.840).
const double _kSilGatherFrom = 0.70;

/// Length of the shell's own arc, matching the prototype's 6.6s default.
/// [_kHatchCeremonyMs] is derived so the arc keeps that duration.
const double _kShellSeconds = 6.6;

/// Total ceremony length. Every window below is a fraction of this, so this
/// number paces the whole ceremony: at 7000 the shell's arc lands in 6.16s of
/// wall clock while [_kShellSeconds] still advances its motion clock to 6.6,
/// which runs the prototype's arc about 7% fast. That is the intended trade --
/// the ceremony reads as tightened rather than truncated, and nothing is cut.
/// Was 7500, which put the handover at 6.86s.
const int kHatchCeremonyMs = 7000;

/// Enum for special hatch types that get visual hints
enum HatchHintType { normal, variant, prismatic }

/// ==============================================
/// Fullscreen cinematic with timeline phases (v3, optimized & faster):
/// 0.00–0.30  : Charge-in (fusion glyphs fade-in, slow swirl)
/// 0.30–0.55  : Sacred geometry & CORE grow
/// 0.55–0.65  : Peak → BURST (flash + shockwave ring)
/// 0.65–0.80  : Explosion aftermath + HINT JOLTS
/// 0.84–0.95  : Silhouette reveal with explosive scale-in
/// 0.92–1.00  : Settle & exit
/// ==============================================
Future<void> playHatchingCinematicAlchemy({
  required BuildContext context,
  required String parentATypeId,
  String? parentBTypeId,

  /// The element the egg is hatching INTO. This is the prototype's third
  /// palette (`elemR`): at [HatchShellTuning.fuseAt] both parent palettes
  /// blend into it, so the shell is already wearing the offspring's colour by
  /// the time it unravels. Without it the fuse resolves to a flat single
  /// colour and the ceremony has no colour identity at its climax.
  String? resultTypeId,
  required Color paletteMain,
  ImageProvider? creatureSilhouette,
  Duration totalDuration = const Duration(milliseconds: kHatchCeremonyMs),
  HatchHintType hintType = HatchHintType.normal,
  Color? variantColor, // For variant hints
  String? pureElementTypeId, // Elementally pure lineage -> purity treatment
  String?
  mutationFamily, // Drives the shell's architecture (7 families + mystic)
  /// A wild-fusion mutation: Transmuted turns the shell and the newborn to
  /// gold, Alchemized strings the shell as grains and leaves the newborn's
  /// grains never settling.
  AlchemonMutation? mutation,
  CinematicQuality quality = CinematicQuality.cinematic,
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      // PageRouteBuilder's default is no transition at all, so only the black
      // barrier faded and the ceremony itself snapped on. It comes up with
      // the dark now.
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (_, __, ___) => HatchingCeremonyView(
        parentATypeId: parentATypeId,
        parentBTypeId: parentBTypeId,
        resultTypeId: resultTypeId,
        paletteMain: paletteMain,
        creatureSilhouette: creatureSilhouette,
        totalDuration: totalDuration,
        hintType: hintType,
        variantColor: variantColor,
        pureElementTypeId: pureElementTypeId,
        mutationFamily: mutationFamily,
        mutation: mutation,
        quality: quality,
      ),
    ),
  );
}

/// The ceremony itself, independent of how it is presented.
///
/// [playHatchingCinematicAlchemy] pushes this as a full-screen route, but the
/// batch extraction runs several at once inside a grid, so the widget must not
/// assume it owns the screen or the navigator. Two hooks make that work:
/// [onComplete] replaces the self-pop at handover, and [playSound] lets a grid
/// keep ONE ceremony cue for the whole batch instead of firing seven.
class HatchingCeremonyView extends StatefulWidget {
  final String parentATypeId;
  final String? parentBTypeId;
  final String? resultTypeId;
  final Color paletteMain;
  final ImageProvider? creatureSilhouette;
  final Duration totalDuration;
  final HatchHintType hintType;
  final Color? variantColor;
  final String? pureElementTypeId;
  final String? mutationFamily;
  final AlchemonMutation? mutation;
  final CinematicQuality quality;

  /// Called at the handover instead of popping the route. Null means this is a
  /// route and should pop itself.
  final VoidCallback? onComplete;

  /// False for grid cells after the first, so a batch plays one cue.
  final bool playSound;

  /// Grid cells have no SKIP of their own -- the batch owns that control.
  final bool showSkip;

  const HatchingCeremonyView({
    super.key,
    required this.parentATypeId,
    this.resultTypeId,
    required this.paletteMain,
    this.parentBTypeId,
    this.creatureSilhouette,
    this.totalDuration = const Duration(milliseconds: kHatchCeremonyMs),
    this.hintType = HatchHintType.normal,
    this.variantColor,
    this.pureElementTypeId,
    this.mutationFamily,
    this.mutation,
    this.quality = CinematicQuality.cinematic,
    this.onComplete,
    this.playSound = true,
    this.showSkip = true,
  });

  @override
  State<HatchingCeremonyView> createState() => _HatchingCeremonyViewState();
}

class _HatchingCeremonyViewState extends State<HatchingCeremonyView>
    with TickerProviderStateMixin {
  late AnimationController _timeline;

  late Animation<double> _reveal;
  late Animation<double> _revealScale;

  /// Guards the handover so it fires exactly once, whether it is reached by
  /// the timeline running out or by SKIP jumping it forward.
  bool _handedOver = false;

  /// THE CULTIVATION IT STARTS FROM. The extraction dialog hands its sphere
  /// on — the same grains, turned to where they were, standing where they
  /// stood — and the ceremony opens on it rather than on black: held in
  /// place while this route fades in over the curtain carrying it, then
  /// drawn to the middle, spun up, and unwound into the field the shell is
  /// made from. Null when there is nothing to carry (the batch grid, a
  /// hatch started elsewhere).
  CultivationHandoff? _handoff;

  /// The ceremony's own seconds at which it took the sphere over from the
  /// curtain; null while the curtain still holds it.
  double? _handoffFrom;
  double _handoffLastU = 0;

  /// The shell's strands, sorted by which parent's cluster they belong to,
  /// for the carried grains to aim at.
  List<List<int>>? _rootsBySide;

  /// The newborn, read into grains from its portrait: what the unravelling
  /// shell pours into, so the creature arrives made of particles — the same
  /// language as the fusion it came from — instead of a flat shape fading in.
  SpecimenGrains? _silGrains;
  double _silWidth = 1;

  Future<void> _readSilhouette() async {
    final p = widget.creatureSilhouette;
    if (p is! AssetImage) return;
    try {
      final data = await (p.bundle ?? rootBundle).load(p.assetName);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 200,
      );
      final img = (await codec.getNextFrame()).image;
      final bytes = await img.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (bytes == null || !mounted) return;
      final g = SpecimenGrains.fromRgba(
        bytes.buffer.asUint8List(),
        img.width,
        img.height,
        pixelRatio: 1,
        maxGrains: 1800,
        tones: 4,
      );
      _silWidth = img.width.toDouble();
      img.dispose();
      if (g.length >= 60 && mounted) setState(() => _silGrains = g);
    } catch (_) {
      // The image reveal stands in.
    }
  }

  static const double _handoffMove = 0.9, _handoffUnwindAt = 0.75;
  static const double _handoffUnwind = 1.15;

  bool _reducedEffects = false;
  AudioController? _audio;

  // Element tint for the purity treatment (null = not an elementally pure
  // lineage). Resolved once from the shared element configs so it matches
  // the chamber particles.
  late final Color? _pureColor = () {
    final id = widget.pureElementTypeId;
    if (id == null) return null;
    final cfg = ElementalConfigs.getConfig(id);
    if (cfg == null || cfg.colors.isEmpty) return widget.paletteMain;
    return cfg.colors.length > 1 ? cfg.colors[1] : cfg.colors.first;
  }();

  // Shell: built once per ceremony, buffers reused every frame.
  HatchShellModel? _shellModel;
  // Deliberately NOT _reducedEffects: that is a screen-size heuristic — any
  // phone under 430 logical px trips it — tuned for the old particle counts,
  // and it was silently handing every handset the degraded shell. The shell
  // follows the user's own cinematic-quality setting instead.
  HatchShellModel _shell() => _shellModel ??= _buildShellModel();

  HatchShellModel _buildShellModel() => HatchShellModel(
    species: hatchShellSpeciesFor(widget.mutationFamily),
    reduced: widget.quality == CinematicQuality.performance,
  );

  /// The shell wants an element's FULL three-colour palette, not one colour:
  /// strands mix between entries 0 and 1, and entry 2 is the bright accent.
  static List<Color> _elementPalette(String? typeId, Color fallback) {
    final cfg = typeId == null ? null : ElementalConfigs.getConfig(typeId);
    final c = cfg?.colors ?? const <Color>[];
    if (c.length >= 3) return [c[0], c[1], c[2]];
    if (c.length == 2) return [c[0], c[1], c[1]];
    if (c.length == 1) return [c[0], c[0], c[0]];
    return [fallback, fallback, fallback];
  }

  ShellRarity get _shellRarity {
    switch (widget.hintType) {
      case HatchHintType.prismatic:
        return ShellRarity.prismatic;
      case HatchHintType.variant:
        return ShellRarity.variant;
      case HatchHintType.normal:
        return ShellRarity.normal;
    }
  }

  /// Take away the cover the nursery raised over the dialog-to-cinematic
  /// seam, but not until this route is opaque — pulled early it would reveal
  /// the nursery through a half-faded ceremony, which is the flash it exists
  /// to prevent.
  void _dropHatchCurtainWhenVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final animation = ModalRoute.of(context)?.animation;
      if (animation == null || animation.isCompleted) {
        HatchCurtain.lower(fade: false);
        _carryHandoff();
        return;
      }
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        HatchCurtain.lower(fade: false);
        _carryHandoff();
      }

      animation.addStatusListener(onStatus);
    });
  }

  /// How much of the shell is showing. With a cultivation carried in, none
  /// until its grains reach the clusters, then rising as they arrive — the
  /// motes are made of what was carried, not dropped in beside it.
  double get _shellFadeIn {
    if (_handoff == null) return 1;
    final from = _handoffFrom;
    if (from == null) return 0;
    return _smooth((_seconds - from - 0.95) / 0.8);
  }

  /// The curtain is gone: from here the ceremony moves the sphere itself.
  void _carryHandoff() {
    final h = _handoff;
    if (h == null || _handoffFrom != null) return;
    h.carried = true;
    _handoffFrom = _seconds;
    _handoffLastU = 0;
    if (mounted) setState(() {});
  }

  double get _seconds =>
      _timeline.value * widget.totalDuration.inMicroseconds / 1e6;

  static double _smooth(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  @override
  void initState() {
    super.initState();
    // The curtain covers the dialog-to-cinematic seam of the FULL SCREEN
    // ceremony. A grid cell sits inside a route that is already up, so
    // lowering it from here would uncover the nursery mid-batch.
    if (widget.onComplete == null) {
      _handoff = CultivationHandoff.take();
      _dropHatchCurtainWhenVisible();
    }

    _timeline = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    );

    // === Timeline keyed ranges (compressed for snappier feel) ===

    // Faster shockwaves

    // THE SILHOUETTE, later and shorter. It used to land at 0.80 and then sit
    // there fully revealed for the last fifth of the run — a second and a
    // half of a still frame at the end of a cinematic that had just finished
    // being one. It arrives at 0.84 and the tail after it is a beat, not a
    // pause.
    _reveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        // The shell's unravel runs 0.748 -> 0.88 of the ceremony. The
        // silhouette lands inside that window so it is revealed BY the
        // explosion and swept straight on into the whiteout, instead of
        // arriving after the motion has stopped.
        curve: const Interval(0.748, 0.840, curve: Curves.easeOut),
      ),
    );
    // Two stages: scales in with the explosion, then keeps drifting outward
    // through the whiteout. A single tween settled at 1.0 and held, which is
    // a frozen frame however short the tail is.
    // The springy settle belongs INSIDE the first item, not on the animation
    // driving the sequence. easeOutBack overshoots past 1.0, and a
    // TweenSequence asserts its input is within [0, 1] -- driving it with an
    // overshooting curve crashes the moment the pop peaks.
    _revealScale =
        TweenSequence<double>([
          // Weighted 50/50 so the scale-in lands at t = 0.88, exactly where
          // the reveal completes and the fade starts -- it used to run to
          // 0.9424, past the point the silhouette had visually settled.
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.6,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeOutBack)),
            weight: 79,
          ),
          // 1.0 -> 1.28, LINEAR, across the whole fade. Two things were wrong
          // before. The range was 1.0 -> 1.09, which is not movement anyone
          // can see. And the curve was easeIn, which is slow-start: it spent
          // the visible half of the fade travelling 1.0 -> 1.09 and saved the
          // real motion for the last quarter, by which point the silhouette
          // is nearly transparent. Raising the range without fixing the curve
          // changed nothing on screen.
          //
          // Constant velocity means every frame of the fade-out has visible
          // movement in it, weighted to where the silhouette is still opaque
          // enough to read. Do not put an ease on this: the opacity is already
          // ramping linearly, and any slow-start curve here re-creates the
          // fades-without-moving that this is here to prevent.
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.28),
            weight: 21,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _timeline,
            // Ends on the handover, not on the controller. The whole 1.0 ->
            // 1.28 drift is spent inside the dissolve window, so the
            // silhouette is visibly swelling for every frame of the fade
            // rather than creeping through 8% of it and leaving the rest
            // unplayed.
            curve: const Interval(0.748, _kHandoverAt),
          ),
        );

    // Hand over to the next screen the instant the silhouette's scale-in
    // lands, rather than waiting for the controller to run out 900ms later.
    //
    // Everything after _kHandoverAt was the ceremony watching itself finish:
    // the shell's arc is over, the reveal is complete, and the scale-in has
    // settled, so the only thing left was a fade. Fading a motionless
    // silhouette is what read as "it stops and you can see it stop", and no
    // amount of retuning the fade curve fixed that, because the problem was
    // that the frame was still on screen at all.
    //
    // The route's own 200ms reverse FadeTransition now does the exit, and it
    // runs over a silhouette that is still drifting outward -- so the
    // ceremony is gone before it ever settles, and the next screen is already
    // coming up underneath.
    void handOver() {
      if (_handedOver || !mounted) return;
      if (_timeline.value < _kHandoverAt) return;
      _handedOver = true;
      _timeline.removeListener(handOver);
      final done = widget.onComplete;
      if (done != null) {
        done();
        return;
      }
      Navigator.of(context).pop();
    }

    _timeline.addListener(handOver);

    // Allocate the shell's buffers and decode the silhouette BEFORE the
    // timeline starts. Both used to happen lazily on the first frame that
    // needed them, which put a multi-megabyte allocation and an image decode
    // inside the opening beat — measured as repeated 0.1-0.4s stalls between
    // t=0.02 and t=0.21.
    _shellModel = _buildShellModel();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_readSilhouette());
      final silhouette = widget.creatureSilhouette;
      if (silhouette != null && mounted) {
        try {
          await precacheImage(silhouette, context);
        } catch (_) {
          // A missing asset must not stop the ceremony.
        }
      }
      if (!mounted) return;
      // Started on the same frame as the timeline, after the silhouette has
      // been precached -- the decode above can cost a frame or two, and a cue
      // fired before it would land ahead of the visuals it is scored to.
      if (widget.playSound) {
        context.sound(SoundCue.extractionCeremony, owner: this);
      }
      _timeline.forward(from: 0.0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audio = context.audio;
    final media = MediaQuery.of(context);
    final shortestSide = media.size.shortestSide;

    double scale;
    if (shortestSide < 380) {
      scale = 0.58;
    } else if (shortestSide < 430) {
      scale = 0.72;
    } else if (shortestSide < 500) {
      scale = 0.85;
    } else {
      scale = 1.0;
    }

    if (media.disableAnimations) {
      scale = 0.50;
    }

    final qualityMultiplier = switch (widget.quality) {
      CinematicQuality.cinematic => 1.0,
      CinematicQuality.performance => 1.0,
    };

    final combinedScale = (scale * qualityMultiplier).clamp(0.10, 2.45);
    _reducedEffects = combinedScale < 0.90;
  }

  @override
  void dispose() {
    _audio?.stopSoundOwner(this);
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.black;

    // A grid cell is a widget, not a screen -- seven Scaffolds would each add
    // their own layout and Material chrome for nothing.
    final embedded = widget.onComplete != null;
    final content = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _timeline,
        builder: (context, _) {
          final t = _timeline.value;
          final highQualityEffects = !_reducedEffects;

          // The shell runs its whole arc — motes, strings, converge, cinch,
          // hold, UNRAVEL — inside the first 80% of the ceremony, because
          // the whiteout begins at 0.80. Feeding it the raw timeline meant
          // its unravel (which starts at 0.85) was faded out before it ever
          // played, so the ceremony appeared to stop at the held shell.
          final shellT = (t / _kShellWindow).clamp(0.0, 1.0);
          // Motion is paced in the prototype's own seconds so twist and
          // breathing read at the rate they were tuned at.
          final shellClock = shellT * _kShellSeconds;

          // Whiteout at reveal
          // Starts the moment the shell's explosion finishes, so the
          // silhouette is carried out by it rather than left on screen.
          final whiteout = _intervalValue(t, 0.88, 0.97, Curves.easeInOutCubic);

          // Vignette
          final vignetteIntensity =
              _intervalValue(t, 0.00, 0.30, Curves.easeOutCubic) *
              (1.0 - whiteout);

          // Global fade. It begins at 0.88 -- the instant the shell's arc
          // ends and the silhouette's reveal completes -- because the
          // scale-in has visually settled by then and the 1.0 -> 1.09 drift
          // after it is too small to read as motion. Starting at 0.92 left
          // the silhouette sitting motionless at full opacity on the
          // whiteout for a beat before anything moved again, which is the
          // frozen frame the ceremony keeps being accused of.
          //
          // The dissolve. Linear, and pinned to reach zero exactly on
          // [_kHandoverAt] so the screen is empty on the frame we navigate.
          // Keep these two constants locked together: if the fade finishes
          // early the ceremony sits on black waiting, and if it finishes late
          // the handover cuts a visible image away.
          double globalFade = 1.0;
          if (t > _kDissolveFrom) {
            globalFade =
                1.0 -
                ((t - _kDissolveFrom) / (_kHandoverAt - _kDissolveFrom)).clamp(
                  0.0,
                  1.0,
                );
          }

          return Opacity(
            opacity: globalFade,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: bg.withValues(alpha: 0.98)),

                // Ambient motes: the field the shell lives in. Drifting
                // for the whole ceremony, behind and in front of the shell.
                RepaintBoundary(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _timeline,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: HatchShellAmbientPainter(
                            t: t,
                            clock: shellClock,
                            tint: widget.mutation == AlchemonMutation.transmuted
                                ? ShellMutationLook.gold
                                : widget.paletteMain,
                            accent: widget.mutation != null
                                ? mutationAccent(widget.mutation!)
                                : widget.variantColor ??
                                      _pureColor ??
                                      widget.paletteMain,
                            reduced: _reducedEffects,
                            opacity: 1.0 - whiteout,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // The shell itself — one drawVertices call.
                RepaintBoundary(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _timeline,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: HatchShellPainter(
                            t: shellT,
                            clock: shellClock,
                            model: _shell(),
                            paletteA: _elementPalette(
                              widget.parentATypeId,
                              widget.paletteMain,
                            ),
                            paletteB: _elementPalette(
                              widget.parentBTypeId ?? widget.parentATypeId,
                              widget.paletteMain,
                            ),
                            // resultTypeId first: pureElementTypeId is only
                            // non-null for elementally pure lineages, so
                            // every ordinary hatch was fusing into
                            // [paletteMain] repeated three times -- a flat
                            // colour standing in for an element palette.
                            paletteResult: _elementPalette(
                              widget.resultTypeId ?? widget.pureElementTypeId,
                              _pureColor ?? widget.paletteMain,
                            ),
                            behaviorA: ShellElementBehavior.of(
                              widget.parentATypeId,
                            ),
                            behaviorB: ShellElementBehavior.of(
                              widget.parentBTypeId ?? widget.parentATypeId,
                            ),
                            behaviorResult: ShellElementBehavior.of(
                              widget.resultTypeId ??
                                  widget.pureElementTypeId ??
                                  widget.parentATypeId,
                            ),
                            rarity: _shellRarity,
                            mutation: widget.mutation,
                            reduced:
                                widget.quality == CinematicQuality.performance,
                            opacity: (1.0 - whiteout) * _shellFadeIn,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // The cultivation it started from, coming undone into it.
                if (_handoff != null)
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _HandoffPainter(this),
                    ),
                  ),

                // Core + Geometry + Effects
                RepaintBoundary(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_timeline]),
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _CoreAndGeometryPainter(
                            t: t,
                            palette: widget.paletteMain,
                            vignette: vignetteIntensity,
                            whiteout: whiteout,
                            // Hint system
                            pureColor: _pureColor,
                            reducedEffects: _reducedEffects,
                            highQualityEffects: highQualityEffects,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // The newborn, gathered out of the unravelling shell in
                // grains, and carried out on the reveal's drift.
                if (_silGrains != null && t > _kSilGatherFrom)
                  IgnorePointer(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _SilhouetteGrainsPainter(
                        grains: _silGrains!,
                        imageWidth: _silWidth,
                        t: t,
                        drift: _revealScale.value,
                        glow: widget.paletteMain,
                        hintType: widget.hintType,
                        variantColor: widget.variantColor,
                        mutation: widget.mutation,
                      ),
                    ),
                  ),

                // Silhouette reveal — the image, for a newborn that could
                // not be read into grains.
                if (_silGrains == null &&
                    widget.creatureSilhouette != null &&
                    _reveal.value > 0)
                  IgnorePointer(
                    child: Opacity(
                      opacity: _reveal.value,
                      child: Transform.scale(
                        scale: _revealScale.value,
                        child: Center(
                          child: _SilhouetteReveal(
                            image: widget.creatureSilhouette!,
                            glowColor: widget.paletteMain,
                            hintType: widget.hintType,
                            variantColor: widget.variantColor,
                            mutation: widget.mutation,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Pure lineage caption, revealed with the silhouette
                if (widget.pureElementTypeId != null && t > 0.80)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 110,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: _intervalValue(t, 0.82, 0.90, Curves.easeOut),
                        child: Center(
                          child: Text(
                            '✦ PURE ${widget.pureElementTypeId!.toUpperCase()} LINEAGE ✦',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _pureColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3.0,
                              shadows: [
                                Shadow(
                                  color: (_pureColor ?? widget.paletteMain)
                                      .withValues(alpha: 0.8),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Skip button
                if (widget.showSkip)
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: GestureDetector(
                      onTap: context.soundAction(
                        () => _timeline.animateTo(
                          1.0,
                          duration: const Duration(milliseconds: 150),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
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
                  ),
              ],
            ),
          );
        },
      ),
    );
    if (embedded) return content;
    return Scaffold(backgroundColor: Colors.transparent, body: content);
  }
}

class _SilhouetteReveal extends StatelessWidget {
  final ImageProvider image;
  final Color glowColor;
  final HatchHintType hintType;
  final Color? variantColor;
  final AlchemonMutation? mutation;

  const _SilhouetteReveal({
    required this.image,
    required this.glowColor,
    this.hintType = HatchHintType.normal,
    this.variantColor,
    this.mutation,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.shortestSide * 0.45;

    // Determine silhouette color based on hint type
    Color silhouetteColor;
    switch (hintType) {
      case HatchHintType.prismatic:
        silhouetteColor = Colors.white;
        break;
      case HatchHintType.variant:
        silhouetteColor = variantColor ?? Colors.white.withValues(alpha: 0.95);
        break;
      case HatchHintType.normal:
        silhouetteColor = Colors.white.withValues(alpha: 0.95);
        break;
    }
    if (mutation == AlchemonMutation.alchemized &&
        hintType != HatchHintType.prismatic) {
      silhouetteColor = Color.lerp(
        Colors.white,
        mutationAccent(AlchemonMutation.alchemized),
        0.4,
      )!;
    }

    Widget child = Image(
      image: image,
      width: size,
      color: silhouetteColor,
      colorBlendMode: BlendMode.srcATop,
      filterQuality: FilterQuality.low,
      isAntiAlias: true,
    );

    // Add special effects for prismatic
    if (hintType == HatchHintType.prismatic) {
      child = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFFE66D),
            Color(0xFF4ECDC4),
            Color(0xFF6B5BFF),
            Color(0xFFFF6B6B),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: Image(
          image: image,
          width: size,
          color: Colors.white,
          colorBlendMode: BlendMode.srcATop,
          filterQuality: FilterQuality.low,
          isAntiAlias: true,
        ),
      );
    }

    // Gold replaces the colour, as it does on the sheet.
    if (mutation == AlchemonMutation.transmuted) {
      child = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ShellMutationLook.bronze,
            ShellMutationLook.gold,
            ShellMutationLook.paleGold,
            ShellMutationLook.gold,
            ShellMutationLook.bronze,
          ],
          stops: [0.0, 0.35, 0.5, 0.65, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: Image(
          image: image,
          width: size,
          color: Colors.white,
          colorBlendMode: BlendMode.srcATop,
          filterQuality: FilterQuality.low,
          isAntiAlias: true,
        ),
      );
    }

    // Soft aura behind the silhouette so it emerges out of light instead of
    // floating on flat black (gradient, not blur — no saveLayer cost).
    final haloColor = mutation != null
        ? mutationAccent(mutation!)
        : hintType == HatchHintType.variant
        ? (variantColor ?? glowColor)
        : glowColor;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 1.6,
          height: size * 1.6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                haloColor.withValues(alpha: 0.32),
                haloColor.withValues(alpha: 0.10),
                haloColor.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _CoreAndGeometryPainter extends CustomPainter {
  final double t;
  final Color palette;
  final double vignette;
  final double whiteout;

  // Hint system

  // Purity treatment: non-null for elementally pure lineages.
  final Color? pureColor;

  final bool reducedEffects;
  final bool highQualityEffects;

  _CoreAndGeometryPainter({
    required this.t,
    required this.palette,
    required this.vignette,
    required this.whiteout,
    this.pureColor,
    this.reducedEffects = false,
    this.highQualityEffects = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Vignette
    if (vignette > 0) {
      final vignettePaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.35 * vignette),
              ],
              stops: const [0.0, 1.0],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.longestSide),
            );
      canvas.drawRect(Offset.zero & size, vignettePaint);
    }

    // Sacred Geometry
    // Purity seal: a slow counter-rotating ticked ring with three triangle
    // seals, in the pure element's color, framing the sacred geometry.
    // Core Orb
    // === HINT JOLTS ===
    // Shockwaves
    // Radial speed-lines at the burst: a quick accent that sells the impact.
    //
    // These were evenly spaced, all the same length, width and alpha, which
    // draws a rigid asterisk rather than motion — and they outlived the
    // sacred geometry that fades at 0.55, so the frame went from line art to
    // a bare cross sitting on nothing. Now each spoke has its own angle,
    // reach and weight, and they are gone by 0.42 rather than lingering.
    // Explosion particles.
    //
    // These used to sit at evenly spaced angles all at the same radius and the
    // same size, which draws a ring of dots expanding in lockstep rather than
    // anything being thrown. Each one now gets its own angle jitter, reach,
    // size and rate, so the front is ragged and the field thins as it goes.
    // Whiteout — tinted faintly toward the palette (or pure element) so the
    // flash feels like the creature's light, not a camera flash.
    if (whiteout > 0) {
      final tint = pureColor ?? palette;
      final paint = Paint()
        ..color = Color.lerp(
          Colors.white,
          tint,
          0.12,
        )!.withValues(alpha: whiteout * 0.9);
      canvas.drawRect(Offset.zero & size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoreAndGeometryPainter old) {
    return t != old.t ||
        palette != old.palette ||
        vignette != old.vignette ||
        whiteout != old.whiteout ||
        pureColor != old.pureColor ||
        reducedEffects != old.reducedEffects ||
        highQualityEffects != old.highQualityEffects;
  }
}

/// The extraction dialog's sphere, carried into the ceremony: held where it
/// stood until the curtain under it is gone, then drawn to the middle as it
/// grows and spins up, its sigil coming apart, and unwound into the field.
class _HandoffPainter extends CustomPainter {
  _HandoffPainter(this.state);

  final _HatchingCeremonyViewState state;

  @override
  void paint(Canvas canvas, Size size) {
    final h = state._handoff;
    if (h == null) return;
    final from = state._handoffFrom;
    if (from == null) {
      // Still on the curtain, which moves it; drawn identically over it.
      h.paint(canvas, at: h.centre, radius: h.radius);
      return;
    }
    final u = math.max(0.0, state._seconds - from);
    // Spinning up as it is drawn in.
    final du = u - state._handoffLastU;
    state._handoffLastU = u;
    final rate =
        CultivationSphere.readySpin +
        4.2 * _HatchingCeremonyViewState._smooth(u / 1.1);
    if (du > 0) h.advance(du, rate);
    final move = _HatchingCeremonyViewState._smooth(
      u / _HatchingCeremonyViewState._handoffMove,
    );
    final centre = Offset.lerp(h.centre, size.center(Offset.zero), move)!;
    final target = size.shortestSide * 0.24;
    final radius = h.radius + (target - h.radius) * move;
    final unwind =
        ((u - _HatchingCeremonyViewState._handoffUnwindAt) /
                _HatchingCeremonyViewState._handoffUnwind)
            .clamp(0.0, 1.0);
    if (unwind >= 1) return;
    // Each grain flies to the ROOT of one of its own parent's strands — the
    // node that strand's line then grows out of — so the cultivation becomes
    // the shell's seeds, rather than a cloud the shell appears beside.
    final roots = state._shell();
    final bySide = state._rootsBySide ??= [
      for (var s = 0; s < 2; s++)
        [
          for (var k = 0; k < roots.strandCount; k++)
            if (roots.groupOf(k) == s) k,
        ],
    ];
    h.paint(
      canvas,
      at: centre,
      radius: radius,
      // The sigil gives way first.
      ready: h.ready * (1 - _HatchingCeremonyViewState._smooth(u / 0.45)),
      unwind: unwind,
      unwindTarget: (side, i) {
        final list = bySide[side];
        if (list.isEmpty) return Offset.zero;
        final k = list[i % list.length];
        return Offset(roots.rootX[k], roots.rootY[k]) - centre;
      },
      // Bright until they land; the nodes they land on carry it from there.
      opacity: 1 - _HatchingCeremonyViewState._smooth((unwind - 0.8) / 0.2),
    );
  }

  @override
  bool shouldRepaint(_HandoffPainter old) => true;
}

/// THE NEWBORN, IN GRAINS. Each grain of its silhouette leaves the
/// unravelling shell on its own clock and spirals in to its place, glinting
/// as it lands — and the whole shape then drifts outward on the reveal's
/// swell as the ceremony dissolves, as the image used to.
class _SilhouetteGrainsPainter extends CustomPainter {
  _SilhouetteGrainsPainter({
    required this.grains,
    required this.imageWidth,
    required this.t,
    required this.drift,
    required this.glow,
    required this.hintType,
    this.variantColor,
    this.mutation,
  });

  final SpecimenGrains grains;
  final double imageWidth;
  final double t;

  /// The reveal's scale: 1.6 → 1 as it lands, then a slow swell.
  final double drift;
  final Color glow;
  final HatchHintType hintType;
  final Color? variantColor;
  final AlchemonMutation? mutation;

  // Glow; the core in three steps of arrival (faint as a grain leaves the
  // shell, full once it is most of the way home); glints; prismatic hues
  // in the same three steps; Transmuted's four tones of gold in the same
  // three steps.
  static final GrainBatch _batch = GrainBatch(2 + 3 + 18 + 12);
  static const int _glowB = 0, _glintB = 1, _coreB = 2, _prismB = 5;
  static const int _goldB = 23;

  /// Transmuted's ramp for the newborn's own light and shade, darkest first.
  static const _goldTones = [
    ShellMutationLook.bronze,
    Color(0xFFA87A34),
    ShellMutationLook.gold,
    ShellMutationLook.paleGold,
  ];

  /// Ceremony seconds, for motion that runs on after a grain has landed.
  static const double _secs = kHatchCeremonyMs / 1000;

  static double _h(int i, int salt) {
    final v = math.sin(i * 127.1 + salt * 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  static double _ease(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final span = size.shortestSide;
    final display = span * 0.45;
    // Landing at 1.0, not the reveal's 1.6 overshoot: the grains do the
    // arriving themselves. Only the swell after it is kept.
    final k = display / imageWidth * math.max(1.0, drift);
    final centre = size.center(Offset.zero);
    final shell = Offset(size.width / 2, size.height * 0.47);
    final gather = (t - _kSilGatherFrom) / (0.835 - _kSilGatherFrom);
    final b = _batch..clear();
    final n = grains.length;
    var minY = double.infinity, maxY = double.negativeInfinity;
    var minX = double.infinity, maxX = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      minY = math.min(minY, grains.hy[i]);
      maxY = math.max(maxY, grains.hy[i]);
      minX = math.min(minX, grains.hx[i]);
      maxX = math.max(maxX, grains.hx[i]);
    }
    final ySpan = math.max(1.0, maxY - minY),
        xSpan = math.max(1.0, maxX - minX);
    var landed = 0.0;
    final gilded = mutation == AlchemonMutation.transmuted;
    final loose = mutation == AlchemonMutation.alchemized;
    final sec = t * _secs;
    // Transmuted's polish: one bright band wiped across the newborn, head to
    // foot, as the last of it lands.
    final sweep = (t - 0.800) / (0.858 - 0.800) * 1.5 - 0.25;
    final toneScale = 4 / math.max(1, grains.tones.length);
    for (var i = 0; i < n; i++) {
      // Head first, each on its own clock.
      final delay = 0.6 * _h(i, 1) + 0.4 * (grains.hy[i] - minY) / ySpan;
      final p = ((gather - delay * 0.45) / 0.55).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final e = _ease(p);
      final home = centre + Offset(grains.hx[i], grains.hy[i]) * k;
      final a = _h(i, 2) * math.pi * 2;
      final src =
          shell +
          Offset(math.cos(a), math.sin(a)) * span * (0.1 + 0.3 * _h(i, 3));
      final dx = home.dx - src.dx, dy = home.dy - src.dy;
      final len = math.sqrt(dx * dx + dy * dy) + 1e-3;
      final bend = math.sin(math.pi * p) * span * 0.07 * (_h(i, 4) - 0.5);
      var x = src.dx + dx * e - dy / len * bend;
      var y = src.dy + dy * e + dx / len * bend;
      if (loose) {
        // Alchemized: home is only where a grain hovers. Each keeps circling
        // its place on its own clock, and one in ten never comes in at all,
        // looping wide around the body -- the particles never settle back
        // into a creature.
        final ph = _h(i, 6) * math.pi * 2;
        final spd = 2.0 + 2.5 * _h(i, 7);
        final wide = _h(i, 8) < 0.1;
        final r = wide
            ? span * (0.025 + 0.05 * _h(i, 9))
            : grains.step * k * (0.6 + 0.8 * _h(i, 9));
        x += math.cos(sec * spd + ph) * r * e;
        y += math.sin(sec * spd * 0.8 + ph * 1.3) * r * e;
      }
      if (p >= 1) landed++;
      if (i % 4 == 0) b.add(_glowB, x, y);
      // A few glint as they land; most just arrive.
      if (p > 0.86 && p < 0.97 && _h(i, 5) < 0.12) {
        b.add(_glintB, x, y);
        continue;
      }
      final step = p < 0.2 ? 0 : (p < 0.5 ? 1 : 2);
      if (gilded) {
        if (p >= 1) {
          final u =
              0.7 * (grains.hy[i] - minY) / ySpan +
              0.3 * (grains.hx[i] - minX) / xSpan;
          if ((u - sweep).abs() < 0.06) {
            b.add(_glintB, x, y);
            continue;
          }
        }
        final tone = (grains.tone[i] * toneScale).floor().clamp(0, 3);
        b.add(_goldB + tone * 3 + step, x, y);
      } else if (hintType == HatchHintType.prismatic) {
        final hue = ((grains.hx[i] - minX) / xSpan * 6).floor().clamp(0, 5);
        b.add(_prismB + hue * 3 + step, x, y);
      } else {
        b.add(_coreB + step, x, y);
      }
    }
    if (n == 0) return;
    final home = landed / n;

    // The light it arrives in, coming up as it gathers.
    final pool = mutation != null
        ? mutationAccent(mutation!)
        : hintType == HatchHintType.variant
        ? (variantColor ?? glow)
        : glow;
    final r = display * 0.8 * math.max(1.0, drift);
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            pool.withValues(alpha: 0.3 * home),
            pool.withValues(alpha: 0.1 * home),
            pool.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: r)),
    );
    // Grains, not a fill: smaller than their spacing, so the shape is read
    // through the gaps between them the way the title's letters are.
    final d = (grains.step * k * 0.78).clamp(1.2, 2.6);
    b.draw(
      canvas,
      _glowB,
      d * 3.4,
      pool.withValues(alpha: loose ? 0.12 : 0.07),
    );
    const steps = [0.3, 0.6, 0.9];
    final core = switch (hintType) {
      _ when loose => const Color(0xFFE6DEFF),
      HatchHintType.variant => variantColor ?? const Color(0xFFFFF6E8),
      _ => const Color(0xFFFFF6E8),
    };
    for (var s = 0; s < 3; s++) {
      b.draw(canvas, _coreB + s, d, core.withValues(alpha: steps[s]));
    }
    const prism = [
      Color(0xFFFF6B6B),
      Color(0xFFFFB86B),
      Color(0xFFFFE66D),
      Color(0xFF4ECDC4),
      Color(0xFF6B9BFF),
      Color(0xFFB06BFF),
    ];
    for (var h = 0; h < 6; h++) {
      for (var s = 0; s < 3; s++) {
        b.draw(
          canvas,
          _prismB + h * 3 + s,
          d,
          prism[h].withValues(alpha: steps[s]),
        );
      }
    }
    for (var g = 0; g < 4; g++) {
      for (var s = 0; s < 3; s++) {
        b.draw(
          canvas,
          _goldB + g * 3 + s,
          d,
          _goldTones[g].withValues(alpha: steps[s] + 0.1),
        );
      }
    }
    final glint = gilded ? const Color(0xFFFFF4D2) : const Color(0xFFFFFBEA);
    b.draw(canvas, _glintB, d * 2.0, glint.withValues(alpha: 0.2));
    b.draw(canvas, _glintB, d * 1.1, glint);
  }

  @override
  bool shouldRepaint(_SilhouetteGrainsPainter old) =>
      old.t != t ||
      old.drift != drift ||
      old.grains != grains ||
      old.mutation != mutation;
}
