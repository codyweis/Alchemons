import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';

class _GeoCache {
  ui.Picture? flower;
  ui.Picture? cube;
  Size? size;
  Color? color;
}

/// Small helper to evaluate an Interval-like curve without allocating
/// CurvedAnimation objects every frame.
double _intervalValue(double t, double begin, double end, Curve curve) {
  if (t <= begin) return 0.0;
  if (t >= end) return 1.0;
  final localT = (t - begin) / (end - begin);
  return curve.transform(localT.clamp(0.0, 1.0));
}

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
  required Color paletteMain,
  ImageProvider? creatureSilhouette,
  Duration totalDuration = const Duration(milliseconds: 7200),
  HatchHintType hintType = HatchHintType.normal,
  Color? variantColor, // For variant hints
  String? pureElementTypeId, // Elementally pure lineage -> purity treatment
  CinematicQuality quality = CinematicQuality.cinematic,
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _HatchingCinematicPage(
        parentATypeId: parentATypeId,
        parentBTypeId: parentBTypeId,
        paletteMain: paletteMain,
        creatureSilhouette: creatureSilhouette,
        totalDuration: totalDuration,
        hintType: hintType,
        variantColor: variantColor,
        pureElementTypeId: pureElementTypeId,
        quality: quality,
      ),
    ),
  );
}

class _HatchingCinematicPage extends StatefulWidget {
  final String parentATypeId;
  final String? parentBTypeId;
  final Color paletteMain;
  final ImageProvider? creatureSilhouette;
  final Duration totalDuration;
  final HatchHintType hintType;
  final Color? variantColor;
  final String? pureElementTypeId;
  final CinematicQuality quality;

  const _HatchingCinematicPage({
    required this.parentATypeId,
    required this.paletteMain,
    this.parentBTypeId,
    this.creatureSilhouette,
    this.totalDuration = const Duration(milliseconds: 7200),
    this.hintType = HatchHintType.normal,
    this.variantColor,
    this.pureElementTypeId,
    this.quality = CinematicQuality.cinematic,
  });

  @override
  State<_HatchingCinematicPage> createState() => _HatchingCinematicPageState();
}

class _HatchingCinematicPageState extends State<_HatchingCinematicPage>
    with TickerProviderStateMixin {
  late AnimationController _timeline;
  late AnimationController _flashCtrl;
  late AnimationController _explosionCtrl;
  late AnimationController _hintJoltCtrl; // For special hint effects
  late Animation<double> _explosionAnim;
  late Animation<double> _hintJoltAnim;

  late Animation<double> _coreScale;
  late Animation<double> _coreOpacity;
  late Animation<double> _shockwave;
  late Animation<double> _secondaryShockwave;

  late Animation<double> _reveal;
  late Animation<double> _revealScale;

  late final _geoCache = _GeoCache();
  double _fxScale = 1.0;
  bool _reducedEffects = false;

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

  // Track hint jolt triggers
  int _hintJoltCount = 0;
  static const int _maxHintJolts = 3;

  @override
  void initState() {
    super.initState();

    _timeline = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _explosionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _hintJoltCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _explosionAnim = CurvedAnimation(
      parent: _explosionCtrl,
      curve: Curves.easeOutCubic,
    );
    _hintJoltAnim = CurvedAnimation(
      parent: _hintJoltCtrl,
      curve: Curves.easeOutBack,
    );

    // === Timeline keyed ranges (compressed for snappier feel) ===
    _coreOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.15, 0.55, curve: Curves.easeInOutCubic),
      ),
    );

    _coreScale = Tween<double>(begin: 0.0, end: 1.4).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.20, 0.55, curve: Curves.easeOutExpo),
      ),
    );

    // Faster shockwaves
    _shockwave = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.65, 0.82, curve: Curves.easeOutCubic),
      ),
    );
    _secondaryShockwave = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.68, 0.85, curve: Curves.easeOutQuad),
      ),
    );

    // THE SILHOUETTE, later and shorter. It used to land at 0.80 and then sit
    // there fully revealed for the last fifth of the run — a second and a
    // half of a still frame at the end of a cinematic that had just finished
    // being one. It arrives at 0.84 and the tail after it is a beat, not a
    // pause.
    _reveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.84, 0.95, curve: Curves.easeOut),
      ),
    );
    _revealScale = Tween<double>(begin: 1.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.84, 0.95, curve: Curves.easeOutBack),
      ),
    );

    _timeline.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });

    // Trigger flash + explosion at BURST (0.55)
    _timeline.addListener(() {
      final t = _timeline.value;
      if (t >= 0.55 && !_flashCtrl.isAnimating && _flashCtrl.value == 0) {
        _flashCtrl.forward(from: 0);
        _explosionCtrl.forward(from: 0);
      }

      // Trigger hint jolts during aftermath phase (0.65-0.80)
      if (widget.hintType != HatchHintType.normal) {
        _maybeFireHintJolt(t);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _buildPictures(size, widget.paletteMain, _geoCache);
      setState(() {});
      _timeline.forward(from: 0.0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    _fxScale = combinedScale;
    _reducedEffects = combinedScale < 0.90;
  }

  void _maybeFireHintJolt(double t) {
    if (_hintJoltCount >= _maxHintJolts) return;

    // Fire jolts at specific points during aftermath
    final joltTimes = [0.68, 0.73, 0.78];
    if (_hintJoltCount < joltTimes.length && t >= joltTimes[_hintJoltCount]) {
      _hintJoltCount++;
      _hintJoltCtrl.forward(from: 0);
    }
  }

  void _buildPictures(Size size, Color base, _GeoCache cache) {
    if (cache.size == size && cache.color == base) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide * 0.20; // Slightly smaller
    final innerR = size.shortestSide * 0.11;

    // Flower
    {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = base
        ..isAntiAlias = true;
      c.save();
      c.translate(center.dx, center.dy);
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3;
        final off = Offset(cos(a) * outer * 0.5, sin(a) * outer * 0.5);
        c.drawCircle(off, outer * 0.44, p);
      }
      c.restore();
      cache.flower = rec.endRecording();
    }

    // Cube
    {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = base;
      c.save();
      c.translate(center.dx, center.dy);
      final pts = <Offset>[];
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3;
        pts.add(Offset(cos(a) * innerR, sin(a) * innerR));
      }
      for (int i = 0; i < pts.length; i++) {
        for (int j = i + 1; j < pts.length; j++) {
          c.drawLine(pts[i], pts[j], p);
        }
      }
      final inner = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = base;
      c.drawCircle(Offset.zero, innerR * 0.55, inner);
      c.restore();
      cache.cube = rec.endRecording();
    }

    cache.size = size;
    cache.color = base;
  }

  @override
  void dispose() {
    _timeline.dispose();
    _flashCtrl.dispose();
    _explosionCtrl.dispose();
    _hintJoltCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Colors.black;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _timeline,
          builder: (context, _) {
            final t = _timeline.value;
            final highQualityEffects = !_reducedEffects;

            // Whiteout at reveal
            final whiteout = _intervalValue(
              t,
              0.80,
              0.88,
              Curves.easeInOutCubic,
            );

            // Vignette
            final vignetteIntensity =
                _intervalValue(t, 0.00, 0.30, Curves.easeOutCubic) *
                (1.0 - whiteout);

            // Charge-in progress
            final chargeInProgress = t < 0.25
                ? Curves.easeOutCubic.transform(t / 0.25)
                : 1.0;

            // Particle speed profile
            final baseSpeed = t < 0.30
                ? 0.9
                : (t < 0.55 ? 0.6 : (t < 0.65 ? 2.8 : 1.0));
            final speed =
                (t < 0.30
                    ? ui.lerpDouble(0.2, baseSpeed, chargeInProgress)!
                    : baseSpeed) *
                (highQualityEffects && t >= 0.52 && t < 0.74 ? 1.14 : 1.0);

            // Geometry opacity
            double geoOpacity;
            if (t < 0.28) {
              geoOpacity = _intervalValue(t, 0.12, 0.28, Curves.easeOutCubic);
            } else if (t < 0.55) {
              geoOpacity = 1.0;
            } else {
              final fadeOut = _intervalValue(
                t,
                0.55,
                0.70,
                Curves.easeOutCubic,
              );
              geoOpacity = 1.0 - fadeOut;
            }

            // Particle count
            int baseParticleCount = (t >= 0.55 && t < 0.65) ? 90 : 62;
            if (highQualityEffects && t >= 0.50 && t < 0.72) {
              baseParticleCount += 20;
            }
            final maxParticles = highQualityEffects ? 210 : 180;
            baseParticleCount = (baseParticleCount * _fxScale).round().clamp(
              6,
              maxParticles,
            );
            if (t < 0.25) {
              baseParticleCount = ui
                  .lerpDouble(
                    0,
                    baseParticleCount.toDouble(),
                    chargeInProgress,
                  )!
                  .round();
            }
            if (t > 0.88) {
              final fadeT = ((t - 0.88) / 0.12).clamp(0.0, 1.0);
              baseParticleCount = (baseParticleCount * (1.0 - fadeT)).round();
            }
            final tertiaryShockwaveT = highQualityEffects
                ? _intervalValue(t, 0.71, 0.90, Curves.easeOutQuart)
                : 0.0;

            // Global fade
            double globalFade = 1.0;
            if (t > 0.92) {
              globalFade =
                  1.0 -
                  Curves.easeInCubic.transform(
                    ((t - 0.92) / 0.08).clamp(0.0, 1.0),
                  );
            }

            return Opacity(
              opacity: globalFade,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: bg.withValues(alpha: 0.98)),

                  // Particles
                  if (t > 0.02)
                    RepaintBoundary(
                      child: IgnorePointer(
                        child: AlchemyBrewingParticleSystem(
                          parentATypeId: widget.parentATypeId,
                          parentBTypeId: widget.parentBTypeId,
                          particleCount: baseParticleCount,
                          speedMultiplier: speed,
                          fusion: true,
                          pureElementTypeId: widget.pureElementTypeId,
                          fromCinematic: true,
                        ),
                      ),
                    )
                  else
                    const SizedBox.expand(),

                  // Core + Geometry + Effects
                  RepaintBoundary(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _timeline,
                          _flashCtrl,
                          _explosionCtrl,
                          _hintJoltCtrl,
                        ]),
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _CoreAndGeometryPainter(
                              t: t,
                              palette: widget.paletteMain,
                              geoOpacity: geoOpacity,
                              coreOpacity: _coreOpacity.value,
                              coreScale: _coreScale.value,
                              shockwaveT: _shockwave.value,
                              secondaryShockwaveT: _secondaryShockwave.value,
                              tertiaryShockwaveT: tertiaryShockwaveT,
                              explosionT: _explosionAnim.value,
                              vignette: vignetteIntensity,
                              whiteout: whiteout,
                              flowerPic: _geoCache.flower,
                              cubePic: _geoCache.cube,
                              // Hint system
                              hintType: widget.hintType,
                              hintJoltT: _hintJoltAnim.value,
                              variantColor: widget.variantColor,
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
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: GestureDetector(
                      onTap: () => _timeline.animateTo(
                        1.0,
                        duration: const Duration(milliseconds: 150),
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
      ),
    );
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
  final double geoOpacity;
  final double coreOpacity;
  final double coreScale;
  final double shockwaveT;
  final double secondaryShockwaveT;
  final double tertiaryShockwaveT;
  final double explosionT;
  final double vignette;
  final double whiteout;
  final ui.Picture? _flowerPic;
  final ui.Picture? _cubePic;

  // Hint system
  final HatchHintType hintType;
  final double hintJoltT;
  final Color? variantColor;

  // Purity treatment: non-null for elementally pure lineages.
  final Color? pureColor;

  final bool reducedEffects;
  final bool highQualityEffects;

  // Rainbow colors for prismatic
  static const _rainbowColors = [
    Color(0xFFFF6B6B), // Red
    Color(0xFFFF9F43), // Orange
    Color(0xFFFFE66D), // Yellow
    Color(0xFF4ECDC4), // Cyan
    Color(0xFF6B5BFF), // Purple
    Color(0xFFFF6B9D), // Pink
  ];

  _CoreAndGeometryPainter({
    required this.t,
    required this.palette,
    required this.geoOpacity,
    required this.coreOpacity,
    required this.coreScale,
    required this.shockwaveT,
    required this.secondaryShockwaveT,
    required this.tertiaryShockwaveT,
    required this.explosionT,
    required this.vignette,
    required this.whiteout,
    required ui.Picture? flowerPic,
    required ui.Picture? cubePic,
    this.hintType = HatchHintType.normal,
    this.hintJoltT = 0,
    this.variantColor,
    this.pureColor,
    this.reducedEffects = false,
    this.highQualityEffects = false,
  }) : _flowerPic = flowerPic,
       _cubePic = cubePic;

  // Cheap deterministic hash for star mote placement (no allocations).
  static double _hash(int n) {
    final v = sin(n * 127.1) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = palette;

    // Background star motes: sparse twinkling points that give the black
    // void depth. Fixed positions (hashed), sin flicker, fade out at whiteout.
    // Cheap (plain circles), so phones get a thinned count rather than none.
    if (whiteout < 1.0) {
      final envelope =
          _intervalValue(t, 0.02, 0.18, Curves.easeOut) * (1.0 - whiteout);
      if (envelope > 0.01) {
        final moteCount = highQualityEffects ? 42 : (reducedEffects ? 16 : 26);
        final motePaint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < moteCount; i++) {
          final mx = _hash(i * 3 + 1) * size.width;
          final my = _hash(i * 3 + 2) * size.height;
          final tw = 0.5 + 0.5 * sin(t * 4 * pi + i * 1.7);
          motePaint.color = Color.lerp(
            Colors.white,
            base,
            0.35,
          )!.withValues(alpha: (0.08 + 0.20 * tw) * envelope);
          canvas.drawCircle(Offset(mx, my), 0.7 + 1.1 * tw, motePaint);
        }
      }
    }

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
    if (geoOpacity > 0 && (_flowerPic != null || _cubePic != null)) {
      final rot1 =
          2 * pi * Curves.easeOutCubic.transform((t - 0.30).clamp(0.0, .5) * 2);
      final rot2 =
          -2 *
          pi *
          Curves.easeOutCubic.transform((t - 0.38).clamp(0.0, .5) * 2);
      if (reducedEffects) {
        if (_flowerPic != null) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(rot1);
          canvas.translate(-center.dx, -center.dy);
          canvas.drawPicture(_flowerPic);
          canvas.restore();
        }
      } else {
        final geoRadius = size.shortestSide * 0.26;
        final geoBounds = Rect.fromCircle(center: center, radius: geoRadius);
        final opacityPaint = Paint()
          ..color = Color.fromRGBO(255, 255, 255, geoOpacity);

        canvas.saveLayer(geoBounds, opacityPaint);

        if (_flowerPic != null) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(rot1);
          canvas.translate(-center.dx, -center.dy);
          canvas.drawPicture(_flowerPic);
          canvas.restore();
        }

        if (_cubePic != null) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(rot2);
          canvas.translate(-center.dx, -center.dy);
          canvas.drawPicture(_cubePic);
          canvas.restore();
        }

        canvas.restore();
      }
    }

    // Purity seal: a slow counter-rotating ticked ring with three triangle
    // seals, in the pure element's color, framing the sacred geometry.
    if (pureColor != null && geoOpacity > 0.01) {
      final sealR = size.shortestSide * 0.31;
      final rot = -t * 2 * pi * 0.55;
      final sealAlpha = 0.55 * geoOpacity;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = pureColor!.withValues(alpha: sealAlpha * 0.7);
      canvas.drawCircle(center, sealR, ringPaint);

      final tickPaint = Paint()
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..color = pureColor!.withValues(alpha: sealAlpha);
      for (int i = 0; i < 24; i++) {
        final a = rot + i * 2 * pi / 24;
        final len = i % 6 == 0 ? 7.0 : 3.0;
        final ca = cos(a);
        final sa = sin(a);
        canvas.drawLine(
          center + Offset(ca * sealR, sa * sealR),
          center + Offset(ca * (sealR + len), sa * (sealR + len)),
          tickPaint,
        );
      }

      // Three outward-pointing triangle seals (alchemical purity marks).
      final sealPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = pureColor!.withValues(alpha: sealAlpha);
      for (int k = 0; k < 3; k++) {
        final a = rot + k * 2 * pi / 3;
        final tip = center + Offset(cos(a), sin(a)) * (sealR + 14);
        final baseL =
            center + Offset(cos(a - 0.045), sin(a - 0.045)) * (sealR + 4);
        final baseR =
            center + Offset(cos(a + 0.045), sin(a + 0.045)) * (sealR + 4);
        final tri = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(baseL.dx, baseL.dy)
          ..lineTo(baseR.dx, baseR.dy)
          ..close();
        canvas.drawPath(tri, sealPaint);
      }
    }

    // Core Orb
    if (coreOpacity > 0 || coreScale > 0) {
      final radiusBase = size.shortestSide * 0.08;
      final r = radiusBase * (0.6 + coreScale);

      // Explosion glow
      if (explosionT > 0) {
        final explosionGlow = Paint()
          ..shader = RadialGradient(
            colors: [
              base.withValues(alpha: 0.4 * (1 - explosionT)),
              base.withValues(alpha: 0.0),
            ],
            stops: const [0.1, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r * 4));
        canvas.drawCircle(center, r * 4, explosionGlow);
      }

      // Outer glow
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            base.withValues(alpha: 0.18 * coreOpacity),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 2.4));
      canvas.drawCircle(center, r * 2.2, glow);

      // Orb
      final orb = Paint()
        ..shader = RadialGradient(
          colors: [
            base.withValues(alpha: 0.55 * coreOpacity),
            base.withValues(alpha: 0.0),
          ],
          stops: const [0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, orb);

      // Ember orbiters: small motes circling the charging core with short
      // trails — makes the charge-up feel alive instead of a static glow.
      if (t < 0.66 && coreOpacity > 0.05) {
        final orbCount = reducedEffects ? 5 : 9;
        final fadeOut = 1.0 - _intervalValue(t, 0.58, 0.66, Curves.easeIn);
        final emberPaint = Paint()..style = PaintingStyle.fill;
        for (int i = 0; i < orbCount; i++) {
          final a = t * 2 * pi * (2.0 + (i % 3) * 0.8) + i * 2 * pi / orbCount;
          final orbR = r * (1.45 + 0.45 * sin(i * 2.1 + t * 10));
          emberPaint.color = base.withValues(
            alpha: 0.75 * coreOpacity * fadeOut,
          );
          canvas.drawCircle(
            center + Offset(cos(a) * orbR, sin(a) * orbR),
            1.5 + (i % 3) * 0.5,
            emberPaint,
          );
          // trailing mote
          final ta = a - 0.20;
          emberPaint.color = base.withValues(
            alpha: 0.30 * coreOpacity * fadeOut,
          );
          canvas.drawCircle(
            center + Offset(cos(ta) * orbR, sin(ta) * orbR),
            1.0,
            emberPaint,
          );
        }
      }

      // Rays near peak
      if (coreScale > 1.0) {
        final rays = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = base.withValues(alpha: 0.2 * coreOpacity);
        final k = (coreScale - 1.0).clamp(0.0, 0.4) / 0.4;
        for (int i = 0; i < 8; i++) {
          final a = (i * 2 * pi / 8) + (t * 1.5);
          final r1 = r * (0.4 + 0.2 * sin(i));
          final r2 = r * (1.0 + 0.7 * k);
          canvas.drawLine(
            center + Offset(cos(a) * r1, sin(a) * r1),
            center + Offset(cos(a) * r2, sin(a) * r2),
            rays,
          );
        }
      }
    }

    // === HINT JOLTS ===
    if (hintJoltT > 0 && hintType != HatchHintType.normal) {
      _drawHintJolt(canvas, size, center);
    }

    // Shockwaves
    _drawShockwave(canvas, size, center, palette, shockwaveT, 0.60, 8, 1, 0.5);
    _drawShockwave(
      canvas,
      size,
      center,
      palette,
      secondaryShockwaveT,
      0.70,
      5,
      0.5,
      0.35,
    );
    if (highQualityEffects) {
      _drawShockwave(
        canvas,
        size,
        center,
        palette,
        tertiaryShockwaveT,
        0.78,
        4,
        0.8,
        0.24,
      );
    }
    // Pure lineages ride an extra element-colored wave out of the burst.
    if (pureColor != null) {
      _drawShockwave(
        canvas,
        size,
        center,
        pureColor!,
        secondaryShockwaveT,
        0.66,
        3,
        0.6,
        0.5,
      );
    }

    // Radial speed-lines at the burst: quick anime-style accents that sell
    // the impact, gone by explosionT 0.6. Cheap lines — phones get a thinned
    // count rather than none.
    if (explosionT > 0 && explosionT < 0.6) {
      final lineAlpha = (1.0 - explosionT / 0.6) * 0.45;
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = palette.withValues(alpha: lineAlpha);
      final n = highQualityEffects ? 20 : (reducedEffects ? 10 : 14);
      final r1 = size.shortestSide * (0.10 + 0.45 * explosionT);
      final r2 = r1 + size.shortestSide * 0.11 * (1.0 - explosionT);
      for (int i = 0; i < n; i++) {
        final a = i * 2 * pi / n + 0.35;
        final ca = cos(a);
        final sa = sin(a);
        canvas.drawLine(
          center + Offset(ca * r1, sa * r1),
          center + Offset(ca * r2, sa * r2),
          linePaint,
        );
      }
    }

    // Explosion particles
    if (explosionT > 0 && explosionT < 0.75) {
      final particlePaint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      final burstParticleCount = reducedEffects
          ? 10
          : (highQualityEffects ? 24 : 16);
      for (int i = 0; i < burstParticleCount; i++) {
        final angle = (i * 2 * pi / burstParticleCount) + (t * 0.5);
        final distance = size.shortestSide * 0.12 * explosionT;
        final particlePos =
            center + Offset(cos(angle) * distance, sin(angle) * distance);
        final particleAlpha = (1.0 - explosionT) * 0.75;
        final particleSize = ui.lerpDouble(
          highQualityEffects ? 3.4 : 3.0,
          1,
          explosionT,
        )!;

        particlePaint.color = palette.withValues(alpha: particleAlpha);
        canvas.drawCircle(particlePos, particleSize, particlePaint);
      }
    }

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

  void _drawHintJolt(Canvas canvas, Size size, Offset center) {
    final maxRadius = size.shortestSide * 0.55;
    final joltRadius = maxRadius * hintJoltT;
    final joltAlpha = (1.0 - hintJoltT).clamp(0.0, 1.0);

    if (hintType == HatchHintType.prismatic) {
      // Rainbow gradient ring for prismatic
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ui.lerpDouble(20, 4, hintJoltT)!
        ..shader = SweepGradient(
          colors: _rainbowColors,
          startAngle: t * pi * 2,
          endAngle: t * pi * 2 + pi * 2,
        ).createShader(Rect.fromCircle(center: center, radius: joltRadius))
        ..isAntiAlias = true;

      if (reducedEffects) {
        canvas.drawCircle(
          center,
          joltRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = ui.lerpDouble(12, 3, hintJoltT)!
            ..color = _rainbowColors[((t * 6) % 6).floor()].withValues(
              alpha: joltAlpha * 0.85,
            ),
        );
      } else {
        // Apply alpha via saveLayer
        canvas.saveLayer(
          Rect.fromCircle(center: center, radius: joltRadius + 20),
          Paint()..color = Color.fromRGBO(255, 255, 255, joltAlpha * 0.8),
        );
        canvas.drawCircle(center, joltRadius, ringPaint);
        canvas.restore();
      }

      // Inner glow with shifting rainbow
      final colorIndex = ((t * 6) % 6).floor();
      final glowColor = _rainbowColors[colorIndex];
      final innerGlow = Paint()
        ..shader =
            RadialGradient(
              colors: [
                glowColor.withValues(alpha: 0.3 * joltAlpha),
                glowColor.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: joltRadius * 0.5),
            );
      canvas.drawCircle(center, joltRadius * 0.5, innerGlow);

      // Sparkle particles in rainbow colors
      final sparkleCount = reducedEffects ? 6 : 12;
      for (int i = 0; i < sparkleCount; i++) {
        final angle = (i * 2 * pi / sparkleCount) + (t * 3);
        final dist = joltRadius * 0.7;
        final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
        final sparkleColor = _rainbowColors[i % _rainbowColors.length];
        final sparklePaint = Paint()
          ..color = sparkleColor.withValues(alpha: joltAlpha * 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 3 * (1 - hintJoltT) + 1, sparklePaint);
      }
    } else if (hintType == HatchHintType.variant && variantColor != null) {
      // Variant color ring
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ui.lerpDouble(16, 3, hintJoltT)!
        ..color = variantColor!.withValues(alpha: joltAlpha * 0.85)
        ..isAntiAlias = true;
      canvas.drawCircle(center, joltRadius, ringPaint);

      // Variant inner glow
      final innerGlow = Paint()
        ..shader =
            RadialGradient(
              colors: [
                variantColor!.withValues(alpha: 0.35 * joltAlpha),
                variantColor!.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: center, radius: joltRadius * 0.6),
            );
      canvas.drawCircle(center, joltRadius * 0.6, innerGlow);

      // Variant sparkles
      for (int i = 0; i < 8; i++) {
        final angle = (i * 2 * pi / 8) + (t * 2.5);
        final dist = joltRadius * 0.65;
        final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
        final sparklePaint = Paint()
          ..color = variantColor!.withValues(alpha: joltAlpha * 0.85)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 4 * (1 - hintJoltT) + 1.5, sparklePaint);
      }
    }
  }

  void _drawShockwave(
    Canvas canvas,
    Size size,
    Offset center,
    Color color,
    double t,
    double maxRatio,
    double startStroke,
    double endStroke,
    double maxOpacity,
  ) {
    if (t <= 0) return;
    final maxR = size.shortestSide * maxRatio;
    final r = ui.lerpDouble(0, maxR, t)!;
    final alpha = (1.0 - t).clamp(0.0, 1.0);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ui.lerpDouble(startStroke, endStroke, t)!
      ..color = color.withValues(alpha: maxOpacity * alpha)
      ..isAntiAlias = true;
    canvas.drawCircle(center, r, ring);
  }

  @override
  bool shouldRepaint(covariant _CoreAndGeometryPainter old) {
    return t != old.t ||
        palette != old.palette ||
        geoOpacity != old.geoOpacity ||
        coreOpacity != old.coreOpacity ||
        coreScale != old.coreScale ||
        shockwaveT != old.shockwaveT ||
        secondaryShockwaveT != old.secondaryShockwaveT ||
        tertiaryShockwaveT != old.tertiaryShockwaveT ||
        explosionT != old.explosionT ||
        vignette != old.vignette ||
        whiteout != old.whiteout ||
        hintType != old.hintType ||
        hintJoltT != old.hintJoltT ||
        variantColor != old.variantColor ||
        pureColor != old.pureColor ||
        reducedEffects != old.reducedEffects ||
        highQualityEffects != old.highQualityEffects;
  }
}
