import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
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
/// 0.80–0.92  : Silhouette reveal with explosive scale-in
/// 0.92–1.00  : Settle & exit
/// ==============================================
Future<void> playHatchingCinematicAlchemy({
  required BuildContext context,
  required String parentATypeId,
  String? parentBTypeId,
  required Color paletteMain,
  ImageProvider? creatureSilhouette,
  Duration totalDuration = const Duration(milliseconds: 4200), // Faster!
  HatchHintType hintType = HatchHintType.normal,
  Color? variantColor, // For variant hints
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

  const _HatchingCinematicPage({
    required this.parentATypeId,
    required this.paletteMain,
    this.parentBTypeId,
    this.creatureSilhouette,
    this.totalDuration = const Duration(milliseconds: 4200),
    this.hintType = HatchHintType.normal,
    this.variantColor,
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

    // Earlier silhouette reveal
    _reveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.80, 0.92, curve: Curves.easeOut),
      ),
    );
    _revealScale = Tween<double>(begin: 1.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.80, 0.92, curve: Curves.easeOutBack),
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
            final speed = t < 0.30
                ? ui.lerpDouble(0.2, baseSpeed, chargeInProgress)!
                : baseSpeed;

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
            int baseParticleCount = (t >= 0.55 && t < 0.65) ? 100 : 70;
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
                              tertiaryShockwaveT: 0, // Removed for speed
                              explosionT: _explosionAnim.value,
                              vignette: vignetteIntensity,
                              whiteout: whiteout,
                              flowerPic: _geoCache.flower,
                              cubePic: _geoCache.cube,
                              // Hint system
                              hintType: widget.hintType,
                              hintJoltT: _hintJoltAnim.value,
                              variantColor: widget.variantColor,
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

    return child;
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
  }) : _flowerPic = flowerPic,
       _cubePic = cubePic;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = palette;

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
      final geoRadius = size.shortestSide * 0.26;
      final geoBounds = Rect.fromCircle(center: center, radius: geoRadius);
      final opacityPaint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, geoOpacity);

      canvas.saveLayer(geoBounds, opacityPaint);

      final rot1 =
          2 * pi * Curves.easeOutCubic.transform((t - 0.30).clamp(0.0, .5) * 2);
      final rot2 =
          -2 *
          pi *
          Curves.easeOutCubic.transform((t - 0.38).clamp(0.0, .5) * 2);

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
          colors: [base.withValues(alpha: 0.18 * coreOpacity), Colors.transparent],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 2.4));
      canvas.drawCircle(center, r * 2.2, glow);

      // Orb
      final orb = Paint()
        ..shader = RadialGradient(
          colors: [base.withValues(alpha: 0.55 * coreOpacity), base.withValues(alpha: 0.0)],
          stops: const [0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, orb);

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

    // Explosion particles
    if (explosionT > 0 && explosionT < 0.75) {
      final particlePaint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      for (int i = 0; i < 16; i++) {
        final angle = (i * 2 * pi / 16) + (t * 0.5);
        final distance = size.shortestSide * 0.12 * explosionT;
        final particlePos =
            center + Offset(cos(angle) * distance, sin(angle) * distance);
        final particleAlpha = (1.0 - explosionT) * 0.75;
        final particleSize = ui.lerpDouble(3, 1, explosionT)!;

        particlePaint.color = palette.withValues(alpha: particleAlpha);
        canvas.drawCircle(particlePos, particleSize, particlePaint);
      }
    }

    // Whiteout
    if (whiteout > 0) {
      final paint = Paint()..color = Colors.white.withValues(alpha: whiteout * 0.9);
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

      // Apply alpha via saveLayer
      canvas.saveLayer(
        Rect.fromCircle(center: center, radius: joltRadius + 20),
        Paint()..color = Color.fromRGBO(255, 255, 255, joltAlpha * 0.8),
      );
      canvas.drawCircle(center, joltRadius, ringPaint);
      canvas.restore();

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
      for (int i = 0; i < 12; i++) {
        final angle = (i * 2 * pi / 12) + (t * 3);
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
        explosionT != old.explosionT ||
        vignette != old.vignette ||
        whiteout != old.whiteout ||
        hintType != old.hintType ||
        hintJoltT != old.hintJoltT ||
        variantColor != old.variantColor;
  }
}
