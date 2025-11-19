import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';

class _GeoCache {
  ui.Picture? flower;
  ui.Picture? cube;
  Size? size;
  Color? color;
}

/// ==============================================
/// Fullscreen cinematic with timeline phases (v2, optimized):
/// 0.00–0.40  : Charge-in (fusion glyphs fade-in, slow swirl)
/// 0.40–0.70  : Sacred geometry & CORE grow (ancient geometry to core shows & expands)
/// 0.70–0.80  : Peak → BURST (flash + shockwave ring, extra sparks)
/// 0.80–0.92  : Explosion aftermath (particles scatter, multiple shockwaves)
/// 0.92–1.00  : Silhouette reveal with explosive scale-in
/// ==============================================
Future<void> playHatchingCinematicAlchemy({
  required BuildContext context,
  required String parentATypeId,
  String? parentBTypeId,
  required Color paletteMain,
  ImageProvider? creatureSilhouette,
  Duration totalDuration = const Duration(milliseconds: 6000),
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => _HatchingCinematicPage(
        parentATypeId: parentATypeId,
        parentBTypeId: parentBTypeId,
        paletteMain: paletteMain,
        creatureSilhouette: creatureSilhouette,
        totalDuration: totalDuration,
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

  const _HatchingCinematicPage({
    required this.parentATypeId,
    required this.paletteMain,
    this.parentBTypeId,
    this.creatureSilhouette,
    this.totalDuration = const Duration(milliseconds: 3800),
  });

  @override
  State<_HatchingCinematicPage> createState() => _HatchingCinematicPageState();
}

class _HatchingCinematicPageState extends State<_HatchingCinematicPage>
    with TickerProviderStateMixin {
  late AnimationController _timeline; // 0..1 master timeline
  late AnimationController _flashCtrl; // quick white flash on burst
  late AnimationController _explosionCtrl; // secondary explosion effects
  late Animation<double> _flashAnim;
  late Animation<double> _explosionAnim;

  // Small focus ring that grows with the core
  late Animation<double> _coreScale; // 0..1.4 scale
  late Animation<double> _coreOpacity; // fade in/out
  late Animation<double> _shockwave; // 0..1 ring radius/opacity
  late Animation<double> _secondaryShockwave; // second wave
  late Animation<double> _tertiaryShockwave; // third wave

  // Optional creature silhouette reveal (delayed until very end)
  late Animation<double> _reveal;
  late Animation<double> _revealScale; // explosive scale-in

  late final _geoCache = _GeoCache();

  @override
  void initState() {
    super.initState();

    _timeline = AnimationController(
      vsync: this,
      duration: widget.totalDuration,
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _explosionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flashAnim = CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOutQuad);
    _explosionAnim = CurvedAnimation(
      parent: _explosionCtrl,
      curve: Curves.easeOutCubic,
    );

    // === Timeline keyed ranges (t = 0..1) matching the trimline ===
    _coreScale = Tween<double>(begin: 0.0, end: 1.4).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.40, 0.70, curve: Curves.easeOutExpo),
      ),
    );
    _coreOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.35, 0.70, curve: Curves.easeInOutCubic),
      ),
    );

    // Aftermath 0.80–0.96 (slightly extended to smooth out)
    _shockwave = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.80, 0.92, curve: Curves.easeOutCubic),
      ),
    );
    _secondaryShockwave = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.82, 0.94, curve: Curves.easeOutQuad),
      ),
    );
    _tertiaryShockwave = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.84, 0.96, curve: Curves.easeOutQuad),
      ),
    );

    // Silhouette reveal 0.92–1.00 with explosive scale-in
    _reveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.92, 1.00, curve: Curves.easeOut),
      ),
    );
    _revealScale = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _timeline,
        curve: const Interval(0.92, 1.00, curve: Curves.easeOutBack),
      ),
    );

    _timeline.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });

    // Trigger flash + explosion at the BURST window start (≥ 0.70)
    _timeline.addListener(() {
      final t = _timeline.value;
      if (t >= 0.70 && !_flashCtrl.isAnimating && _flashCtrl.value == 0) {
        _flashCtrl.forward(from: 0);
        _explosionCtrl.forward(from: 0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      _buildPictures(size, widget.paletteMain, _geoCache);

      // Ensure geometry is ready BEFORE the cinematic actually starts
      setState(() {});

      // Now start the timeline at exactly 0 with a clean first frame
      _timeline.forward(from: 0.0);
    });
  }

  void _buildPictures(Size size, Color base, _GeoCache cache) {
    if (cache.size == size && cache.color == base) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide * 0.22;
    final innerR = size.shortestSide * 0.12;

    // Flower - NOTE: Paint colors are now at FULL opacity
    // We'll apply the geometry opacity separately when drawing
    {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color =
            base // Full opacity here
        ..isAntiAlias = true;
      c.save();
      c.translate(center.dx, center.dy);
      for (int i = 0; i < 6; i++) {
        final a = i * pi / 3;
        final off = Offset(cos(a) * outer * 0.5, sin(a) * outer * 0.5);
        c.drawCircle(off, outer * 0.46, p);
      }
      c.restore();
      cache.flower = rec.endRecording();
    }

    // Cube-ish - Same here, full opacity
    {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = base; // Full opacity
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
        ..color = base; // Full opacity
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

            // Whiteout kept at 0.92–1.00
            final whiteout = CurvedAnimation(
              parent: _timeline,
              curve: const Interval(0.92, 1.0, curve: Curves.easeInOutCubic),
            ).value;

            // Backdrop vignette intensity (0–0.40), backs off during whiteout
            final vignetteIntensity =
                CurvedAnimation(
                  parent: _timeline,
                  curve: const Interval(0.00, 0.40, curve: Curves.easeOutCubic),
                ).value *
                (1.0 - whiteout);

            // Ease-in factor for the charge-in window 0..0.30
            final chargeInProgress = t < 0.30
                ? Curves.easeOutCubic.transform(t / 0.30)
                : 1.0;

            // Particle speed profile per phase – now modulated by chargeInProgress at start
            final baseSpeed = t < 0.40
                ? 0.9 // Charge-in
                : (t < 0.70
                      ? 0.55 // Build
                      : (t < 0.80
                            ? 2.5 // Peak/Burst
                            : 1.2)); // Aftermath + Reveal

            final speed = t < 0.40
                ? ui.lerpDouble(0.2, baseSpeed, chargeInProgress)!
                : baseSpeed;

            // Geometry visibility: quick fade-in, hold, then fade out after burst
            double geoOpacity;

            if (t < 0.35) {
              // 0.15 → 0.35 smooth fade-in
              final fadeIn = CurvedAnimation(
                parent: _timeline,
                curve: const Interval(0.15, 0.35, curve: Curves.easeOutCubic),
              ).value;
              geoOpacity = fadeIn;
            } else if (t < 0.70) {
              // Hold at full intensity during main build phase
              geoOpacity = 1.0;
            } else {
              // Fade out 0.70 → 0.82
              final fadeOut = CurvedAnimation(
                parent: _timeline,
                curve: const Interval(0.70, 0.82, curve: Curves.easeOutCubic),
              ).value;
              geoOpacity = 1.0 - fadeOut;
            }

            // Base particle count (with burst bump)
            int baseParticleCount = (t >= 0.70 && t < 0.80) ? 120 : 80;

            // Ramp-in particle count at the start (0.00–0.30)
            if (t < 0.30) {
              baseParticleCount = ui
                  .lerpDouble(
                    10,
                    baseParticleCount.toDouble(),
                    chargeInProgress,
                  )!
                  .round();
            }

            // Fade-out particle count at the end (0.92–1.00)
            if (t > 0.92) {
              final fadeT = ((t - 0.92) / 0.08).clamp(0.0, 1.0);
              final factor = 1.0 - fadeT;
              baseParticleCount = (baseParticleCount * factor).round().clamp(
                0,
                9999,
              );
            }

            // Global soft fade-in/out to hide any remaining startup/end jank
            double globalFade = 1.0;
            // Keep only the outro fade; let the route handle intro.
            if (t > 0.92) {
              globalFade =
                  1.0 -
                  Curves.easeInCubic.transform(
                    ((t - 0.92) / 0.08).clamp(0.0, 1.0),
                  ); // 1 → 0
            }

            return Opacity(
              opacity: globalFade,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop
                  ColoredBox(color: bg.withOpacity(0.98)),

                  // Particle system (no global Opacity to avoid saveLayer)
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
                  ),

                  // Geometry + Core + Shockwaves + Vignette + Whiteout (all in one painter)
                  RepaintBoundary(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _timeline,
                          _flashCtrl,
                          _explosionCtrl,
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
                              tertiaryShockwaveT: _tertiaryShockwave.value,
                              explosionT: _explosionAnim.value,
                              vignette: vignetteIntensity,
                              whiteout: whiteout,
                              flowerPic: _geoCache.flower,
                              cubePic: _geoCache.cube,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Silhouette (cheaper during motion: no heavy boxShadow until settled)
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
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Tap to skip
                  Positioned(
                    bottom: 24,
                    right: 24,
                    child: GestureDetector(
                      onTap: () => _timeline.animateTo(
                        1.0,
                        duration: const Duration(milliseconds: 200),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF), // .withOpacity(0.08)
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          border: Border.all(
                            color: const Color(
                              0x2EFFFFFF,
                            ), // .withOpacity(0.18)
                          ),
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

/// Separate widget so we can switch image filterQuality / effects based on settle state
class _SilhouetteReveal extends StatelessWidget {
  final ImageProvider image;
  final Color glowColor;
  const _SilhouetteReveal({required this.image, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.shortestSide * 0.45;

    // Keep it light while scaling; add glow only when settled
    final child = Image(
      image: image,
      width: size,
      color: Colors.white.withOpacity(0.95),
      colorBlendMode: BlendMode.srcATop,
      filterQuality: FilterQuality.low,
      isAntiAlias: true,
    );

    return child;
  }
}

/// Painter: draws vignette + sacred geometry (cached) + core + shockwaves + explosion + whiteout.
class _CoreAndGeometryPainter extends CustomPainter {
  final double t; // 0..1 timeline
  final Color palette;
  final double geoOpacity; // 0..1
  final double coreOpacity; // 0..1
  final double coreScale; // ~0..1.4
  final double shockwaveT; // 0..1
  final double secondaryShockwaveT; // 0..1
  final double tertiaryShockwaveT; // 0..1
  final double explosionT; // 0..1
  final double vignette; // 0..1
  final double whiteout; // 0..1

  final ui.Picture? _flowerPic;
  final ui.Picture? _cubePic;
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
  }) : _flowerPic = flowerPic,
       _cubePic = cubePic;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = palette;

    // ====== Vignette (no overlay widgets) ======
    if (vignette > 0) {
      final vignettePaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.35 * vignette),
              ],
              stops: const [0.0, 1.0],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.longestSide),
            );
      canvas.drawRect(Offset.zero & size, vignettePaint);
    }

    // ====== Sacred Geometry (cached pictures with proper opacity) ======
    if (geoOpacity > 0) {
      final rot1 =
          2 * pi * Curves.easeOutCubic.transform((t - 0.40).clamp(0.0, .5) * 2);
      final rot2 =
          -2 *
          pi *
          Curves.easeOutCubic.transform((t - 0.48).clamp(0.0, .5) * 2);

      // Flower (outer) - Apply opacity via saveLayer
      if (_flowerPic != null) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(rot1);
        canvas.translate(-center.dx, -center.dy);

        // Apply geometry opacity properly
        final opacityPaint = Paint()
          ..color = Color.fromRGBO(255, 255, 255, geoOpacity);
        canvas.saveLayer(null, opacityPaint);
        canvas.drawPicture(_flowerPic!);
        canvas.restore(); // restore saveLayer

        canvas.restore(); // restore transform
      }

      // Cube - Apply opacity via saveLayer
      if (_cubePic != null) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(rot2);
        canvas.translate(-center.dx, -center.dy);

        // Apply geometry opacity properly
        final opacityPaint = Paint()
          ..color = Color.fromRGBO(255, 255, 255, geoOpacity);
        canvas.saveLayer(null, opacityPaint);
        canvas.drawPicture(_cubePic!);
        canvas.restore(); // restore saveLayer

        canvas.restore(); // restore transform
      }
    }

    // ====== Core Orb (grows and then bursts) ======
    if (coreOpacity > 0 || coreScale > 0) {
      final radiusBase = size.shortestSide * 0.08;
      final r = radiusBase * (0.6 + coreScale);

      // Explosion extra glow
      if (explosionT > 0) {
        final explosionGlow = Paint()
          ..shader = RadialGradient(
            colors: [
              base.withOpacity(0.35 * (1 - explosionT)),
              base.withOpacity(0.0),
            ],
            stops: const [0.1, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r * 4.5));
        canvas.drawCircle(center, r * 4.5, explosionGlow);

        // Extra glow
        final glow = Paint()
          ..shader = RadialGradient(
            colors: [
              base.withOpacity(0.16 * coreOpacity),
              base.withOpacity(0.0),
            ],
            stops: const [0.2, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: r * 2.6));
        canvas.drawCircle(center, r * 2.6, glow);
      }

      // Outer glow (cheaper gradient)
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [base.withOpacity(0.16 * coreOpacity), Colors.transparent],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r * 2.6));

      canvas.drawCircle(center, r * 2.2, glow);

      // Orb
      final orb = Paint()
        ..shader = RadialGradient(
          colors: [base.withOpacity(0.52 * coreOpacity), base.withOpacity(0.0)],
          stops: const [0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, orb);

      // Rays (near peak)
      if (coreScale > 1.0) {
        final rays = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = base.withOpacity(0.17 * coreOpacity);
        final k = (coreScale - 1.0).clamp(0.0, 0.4) / 0.4;
        for (int i = 0; i < 10; i++) {
          final a = (i * 2 * pi / 10) + (t * 1.3);
          final r1 = r * (0.4 + 0.2 * sin(i));
          final r2 = r * (1.0 + 0.6 * k);
          canvas.drawLine(
            center + Offset(cos(a) * r1, sin(a) * r1),
            center + Offset(cos(a) * r2, sin(a) * r2),
            rays,
          );
        }
      }
    }

    // ====== Shockwaves ======
    _drawShockwave(
      canvas,
      size,
      center,
      palette,
      shockwaveT,
      0.65,
      10,
      1,
      6,
      0.45,
    );
    _drawShockwave(
      canvas,
      size,
      center,
      palette,
      secondaryShockwaveT,
      0.75,
      6,
      0.5,
      4,
      0.35,
    );
    _drawShockwave(
      canvas,
      size,
      center,
      palette,
      tertiaryShockwaveT,
      0.85,
      4,
      0.5,
      3,
      0.25,
    );

    // ====== Explosion particles ======
    if (explosionT > 0 && explosionT < 0.8) {
      final particlePaint = Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      for (int i = 0; i < 20; i++) {
        final angle = (i * 2 * pi / 20) + (t * 0.5);
        final distance = size.shortestSide * 0.15 * explosionT;
        final particlePos =
            center + Offset(cos(angle) * distance, sin(angle) * distance);
        final particleAlpha = (1.0 - explosionT) * 0.8;
        final particleSize = ui.lerpDouble(3, 1, explosionT)!;

        particlePaint.color = palette.withOpacity(particleAlpha);
        canvas.drawCircle(particlePos, particleSize, particlePaint);
      }
    }

    // ====== Whiteout (no widget opacity) ======
    if (whiteout > 0) {
      final paint = Paint()..color = Colors.white.withOpacity(whiteout);
      canvas.drawRect(Offset.zero & size, paint);
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
    double blurSigma,
    double maxOpacity,
  ) {
    if (t <= 0) return;
    final maxR = size.shortestSide * maxRatio;
    final r = ui.lerpDouble(0, maxR, t)!;
    final alpha = (1.0 - t).clamp(0.0, 1.0);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ui.lerpDouble(startStroke, endStroke, t)!
      ..color = color.withOpacity(maxOpacity * alpha)
      ..isAntiAlias = true;
    canvas.drawCircle(center, r, ring);
  }

  @override
  bool shouldRepaint(covariant _CoreAndGeometryPainter old) {
    // We repaint often (timeline), but the heavy geometry is cached.
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
        whiteout != old.whiteout;
  }
}
