import 'dart:async';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:flutter/material.dart';
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
        return;
      }
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        HatchCurtain.lower(fade: false);
      }

      animation.addStatusListener(onStatus);
    });
  }

  @override
  void initState() {
    super.initState();
    // The curtain covers the dialog-to-cinematic seam of the FULL SCREEN
    // ceremony. A grid cell sits inside a route that is already up, so
    // lowering it from here would uncover the nursery mid-batch.
    if (widget.onComplete == null) {
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
                            tint: widget.paletteMain,
                            accent:
                                widget.variantColor ??
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
                            reduced:
                                widget.quality == CinematicQuality.performance,
                            opacity: 1.0 - whiteout,
                          ),
                        );
                      },
                    ),
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

                // Silhouette reveal
                if (widget.creatureSilhouette != null && _reveal.value > 0)
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

  const _SilhouetteReveal({
    required this.image,
    required this.glowColor,
    this.hintType = HatchHintType.normal,
    this.variantColor,
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

    // Soft aura behind the silhouette so it emerges out of light instead of
    // floating on flat black (gradient, not blur — no saveLayer cost).
    final haloColor = hintType == HatchHintType.variant
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
