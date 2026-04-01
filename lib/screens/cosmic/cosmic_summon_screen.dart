// lib/screens/cosmic/cosmic_summon_screen.dart
import 'dart:math';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// A portal-encounter screen launched from Cosmic mode when a meter summon
/// completes.  Identical UX to [RiftPortalScreen] but uses the element's
/// color for all portal / background visuals instead of a rift faction.
class CosmicSummonScreen extends StatefulWidget {
  /// The species that was rolled by the meter recipe.
  final String speciesId;

  /// Display-friendly rarity string (Common / Uncommon / Rare / Legendary).
  final String rarity;

  /// Element name (Fire, Water, etc.) — used for header text.
  final String elementName;

  /// Primary accent color derived from the planet element.
  final Color portalColor;

  const CosmicSummonScreen({
    super.key,
    required this.speciesId,
    required this.rarity,
    required this.elementName,
    required this.portalColor,
  });

  @override
  State<CosmicSummonScreen> createState() => _CosmicSummonScreenState();
}

class _CosmicSummonScreenState extends State<CosmicSummonScreen>
    with TickerProviderStateMixin {
  late AnimationController _portalCtrl;
  late AnimationController _bannerCtrl;
  late AnimationController _entryCtrl;
  bool _entryDone = false;

  Creature? _creature;
  EncounterRarity _encounterRarity = EncounterRarity.common;
  bool _spawned = false;
  final bool _encounterActive = true;
  Creature? _selectedPartyCreature;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation for the summon encounter
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _portalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _entryCtrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2200),
          )
          ..forward().whenComplete(() {
            if (mounted) setState(() => _entryDone = true);
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_spawned) {
      _spawned = true;
      _hydrateCreature();
    }
  }

  void _hydrateCreature() {
    final repo = context.read<CreatureCatalog>();

    // Map display rarity → EncounterRarity
    final rarityMap = {
      'Common': EncounterRarity.common,
      'Uncommon': EncounterRarity.uncommon,
      'Rare': EncounterRarity.rare,
      'Legendary': EncounterRarity.legendary,
      'Mythic': EncounterRarity.legendary,
      'Variant': EncounterRarity.rare,
    };
    _encounterRarity = rarityMap[widget.rarity] ?? EncounterRarity.common;

    final gen = WildlifeGenerator(repo);
    final hydrated = gen.generate(
      widget.speciesId,
      rarity: _encounterRarity.label,
    );
    if (hydrated == null) return;

    setState(() {
      _creature = hydrated;
    });
    _bannerCtrl.forward();
  }

  @override
  void dispose() {
    // Restore all orientations when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _portalCtrl.dispose();
    _bannerCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Derived dark-core color from the portal color ─────────────────────────
  Color get _coreColor {
    final hsl = HSLColor.fromColor(widget.portalColor);
    return hsl.withLightness(0.04).withSaturation(0.9).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.portalColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Particle background ─────────────────────────────────────────
          IgnorePointer(
            child: AlchemicalParticleBackground(
              opacity: 0.55,
              backgroundColor: Colors.transparent,
              colors: [
                color.withValues(alpha: 0.7),
                color.withValues(alpha: 0.4),
                Colors.white.withValues(alpha: 0.3),
              ],
            ),
          ),

          // ── Portal ──────────────────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _portalCtrl,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(320, 320),
                  painter: _SummonPortalPainter(
                    color: color,
                    coreColor: _coreColor,
                    time: _portalCtrl.value * pi * 2 * 4,
                  ),
                );
              },
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white12, width: 1),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'COSMIC SUMMON',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                        ),
                      ),
                      Text(
                        widget.elementName.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Creature sprite — centred over the portal ───────────────────
          if (_creature != null)
            Center(
              child: AnimatedBuilder(
                animation: _bannerCtrl,
                builder: (context, child) {
                  final t = Curves.easeOutCubic.transform(_bannerCtrl.value);
                  return Opacity(opacity: t.clamp(0.0, 1.0), child: child);
                },
                child: _SummonSprite(creature: _creature!, size: 170),
              ),
            ),

          // ── Party creature — left side ──────────────────────────────────
          if (_selectedPartyCreature != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.32,
              child: Center(
                child: _SummonSprite(
                  creature: _selectedPartyCreature!,
                  size: 140,
                  flipHorizontal: true,
                ),
              ),
            ),

          // ── Encounter overlay ───────────────────────────────────────────
          if (_creature != null && _encounterActive)
            EncounterOverlay(
              encounter: WildEncounter(
                wildBaseId: _creature!.id,
                baseBreedChance: breedChanceForRarity(_encounterRarity),
                rarity: _encounterRarity.label,
                source: 'planet_summon',
              ),
              hydratedWildCreature: _creature!,
              party: const [], // no party in space — harvester only
              highlightPartyHUD: false,
              isTutorial: false,
              showFusionAction: false,
              warnOnRun: true,
              onPreRollShake: () {},
              onPartyCreatureSelected: (c) {
                setState(() => _selectedPartyCreature = c);
              },
              onClosedWithResult: (success) {
                if (!mounted) return;
                Navigator.of(context).pop(success);
              },
            ),

          // ── Entry flash ─────────────────────────────────────────────────
          if (!_entryDone)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _entryCtrl,
                builder: (context, _) =>
                    _SummonEntryFlash(color: color, progress: _entryCtrl.value),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Creature sprite widget ───────────────────────────────────────────────────

class _SummonSprite extends StatelessWidget {
  final Creature creature;
  final double size;
  final bool flipHorizontal;

  const _SummonSprite({
    required this.creature,
    required this.size,
    this.flipHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    // Ensure visuals are derived correctly even if CreatureInstance is null
    final visuals = visualsFromInstance(creature, null);

    Widget sprite;
    if (creature.spriteData != null) {
      final sheet = sheetFromCreature(creature);
      sprite = SizedBox(
        width: size,
        height: size,
        child: CreatureSprite(
          spritePath: sheet.path,
          totalFrames: sheet.totalFrames,
          rows: sheet.rows,
          frameSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          scale: visuals.scale,
          saturation: visuals.saturation,
          brightness: visuals.brightness,
          hueShift: visuals.hueShiftDeg,
          isPrismatic: visuals.isPrismatic, // Use visuals for consistency
          tint: visuals.tint,
          alchemyEffect: visuals.alchemyEffect, // Pass alchemyEffect
          variantFaction: visuals.variantFaction, // Pass variantFaction
          effectSlotSize: size,
        ),
      );
    } else {
      sprite = const SizedBox.shrink();
    }

    if (flipHorizontal) {
      return Transform.scale(scaleX: -1, child: sprite);
    }
    return sprite;
  }
}

// ── Portal painter (color-based, no faction) ─────────────────────────────────

class _SummonPortalPainter extends CustomPainter {
  final Color color;
  final Color coreColor;
  final double time;

  static final List<_PData> _particles = _buildParticles();

  static List<_PData> _buildParticles() {
    final rng = Random(42);
    return List.generate(28, (i) {
      return _PData(
        angle: (i / 28) * pi * 2,
        radius: 0.46 + rng.nextDouble() * 0.38,
        speed: 0.30 + rng.nextDouble() * 0.80,
        size: 1.4 + rng.nextDouble() * 2.6,
        opacity: 0.45 + rng.nextDouble() * 0.55,
      );
    });
  }

  const _SummonPortalPainter({
    required this.color,
    required this.coreColor,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.22;
    final pulse = 0.88 + 0.12 * sin(time * 0.63);

    // Outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 2.6,
      Paint()
        ..color = color.withValues(alpha: 0.08 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );

    // Mid glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.8,
      Paint()
        ..color = color.withValues(alpha: 0.16 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Accretion disk
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1.0, 0.28);
    final diskR = r * 3.0;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: diskR * 2, height: diskR * 2),
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.55 * pulse),
            color.withValues(alpha: 0),
          ],
          stops: const [0.42, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: diskR)),
    );
    canvas.restore();

    // Event horizon
    final coreRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: r * 2,
      height: r * 2,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      r * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: [coreColor, coreColor, Colors.black],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(coreRect),
    );

    // Orbiting particles
    for (final p in _particles) {
      final angle = p.angle + time * p.speed;
      final pr = r * (p.radius + 0.15);
      final px = cx + cos(angle) * pr;
      final py = cy + sin(angle) * pr * 0.42;
      canvas.drawCircle(
        Offset(px, py),
        p.size * pulse,
        Paint()
          ..color = color.withValues(alpha: p.opacity * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );
    }

    // Spiral arms
    final spiralPaint = Paint()
      ..color = color.withValues(alpha: 0.30 * pulse)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    for (int arm = 0; arm < 3; arm++) {
      final startA = time * 0.40 + (arm * pi * 2 / 3);
      final path = Path();
      bool first = true;
      for (double t = 0.05; t <= 1.0; t += 0.035) {
        final sr = r * t * 0.95;
        final sa = startA - t * pi * 3.2;
        final px = cx + cos(sa) * sr;
        final py = cy + sin(sa) * sr * 0.42;
        if (first) {
          path.moveTo(px, py);
          first = false;
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(path, spiralPaint);
    }

    // Rim
    canvas.drawCircle(
      Offset(cx, cy),
      r * pulse,
      Paint()
        ..color = color.withValues(alpha: 0.22 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(_SummonPortalPainter old) =>
      old.time != time || old.color != color;
}

class _PData {
  final double angle;
  final double radius;
  final double speed;
  final double size;
  final double opacity;
  const _PData({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

// ── Entry flash overlay ──────────────────────────────────────────────────────

class _SummonEntryFlash extends StatelessWidget {
  final Color color;
  final double progress;

  const _SummonEntryFlash({required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SummonFlashPainter(color: color, progress: progress),
      size: Size.infinite,
    );
  }
}

class _SummonFlashPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _SummonFlashPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.longestSide * 1.2;

    // Overall overlay opacity
    double overlayAlpha;
    if (progress < 0.12) {
      overlayAlpha = (progress / 0.12).clamp(0.0, 1.0);
    } else if (progress < 0.60) {
      overlayAlpha = 1.0;
    } else {
      overlayAlpha = 1.0 - ((progress - 0.60) / 0.40).clamp(0.0, 1.0);
    }
    if (overlayAlpha <= 0) return;

    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..color = Color.fromARGB((overlayAlpha * 255).round(), 255, 255, 255),
    );

    // Dark radial base
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            Color.lerp(color, Colors.black, 0.3)!.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.95),
          ],
        ).createShader(Offset.zero & size),
    );

    // White flash
    double flashAlpha = 0.0;
    if (progress >= 0.12 && progress <= 0.45) {
      final t = (progress - 0.12) / 0.33;
      flashAlpha = t < 0.35 ? (t / 0.35) : (1.0 - (t - 0.35) / 0.65);
      flashAlpha = flashAlpha.clamp(0.0, 1.0) * 0.92;
    }
    if (flashAlpha > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: flashAlpha),
      );
    }

    // Expanding rings
    for (int i = 0; i < 5; i++) {
      final start = 0.25 + i * 0.06;
      final end = start + 0.35;
      if (progress < start || progress > end) continue;
      final t = ((progress - start) / (end - start)).clamp(0.0, 1.0);
      final ringR = maxR * 0.15 + maxR * 0.85 * t;
      final ringAlpha = (1.0 - t).clamp(0.0, 1.0) * 0.5;
      final ringWidth = 3.0 + 5.0 * (1 - t);
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..color = color.withValues(alpha: ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Glow core
    if (progress < 0.55) {
      final glowAlpha = (1.0 - (progress / 0.55)).clamp(0.0, 1.0) * 0.6;
      canvas.drawCircle(
        center,
        maxR * 0.25,
        Paint()
          ..color = color.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SummonFlashPainter old) =>
      old.progress != progress || old.color != color;
}
