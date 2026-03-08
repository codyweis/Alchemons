// lib/screens/cosmic/elemental_nexus_screen.dart
//
// The Elemental Nexus — a hidden black portal easter-egg in cosmic space.
//
// Flow:
//   1. Dark screen fades in, text: "Guarantee Harvester Found" (added to inventory)
//   2. Four elemental portals appear with staggered animation (Fire, Water, Earth, Air)
//   3. Tapping one starts an encounter with a Prismatic Kin of that element
//      (stats: all 3.0 starting, 4.5 potential)
//   4. After catch/flee → pops back to cosmic screen

import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────
// RESULT passed back to cosmic_screen
// ─────────────────────────────────────────────────────────

class NexusResult {
  /// True if an encounter was completed (caught/fused).
  final bool caught;

  /// The element portal chosen (Fire/Water/Earth/Air), or null if fled early.
  final String? chosenElement;

  const NexusResult({this.caught = false, this.chosenElement});
}

// ─────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────

class ElementalNexusScreen extends StatefulWidget {
  /// If non-null, we are resuming mid-nexus (e.g. after a crash).
  final NexusPhase resumePhase;
  final String? resumeElement;
  final bool harvesterAlreadyAwarded;

  const ElementalNexusScreen({
    super.key,
    this.resumePhase = NexusPhase.outside,
    this.resumeElement,
    this.harvesterAlreadyAwarded = false,
  });

  @override
  State<ElementalNexusScreen> createState() => _ElementalNexusScreenState();
}

class _ElementalNexusScreenState extends State<ElementalNexusScreen>
    with TickerProviderStateMixin {
  // ── Phase state ──
  late NexusPhase _phase;
  String? _chosenElement;
  bool _harvesterAwarded = false;

  // ── Intro text animation ──
  late AnimationController _introCtrl;
  late AnimationController _portalRevealCtrl;
  late AnimationController _encounterCtrl;

  // ── Encounter state ──
  Creature? _encounterCreature;
  bool _encounterActive = false;
  Creature? _selectedPartyCreature;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation inside the nexus encounter
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _phase = widget.resumePhase == NexusPhase.outside
        ? NexusPhase.inEncounter
        : widget.resumePhase;
    _chosenElement = widget.resumeElement;
    _harvesterAwarded = widget.harvesterAlreadyAwarded;

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _portalRevealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _encounterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    if (_phase == NexusPhase.inEncounter && _chosenElement != null) {
      // Start encounter directly — portal choice made in pocket world
      _introCtrl.value = 1.0;
      _portalRevealCtrl.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startEncounter(_chosenElement!);
      });
    } else if (_phase == NexusPhase.choosingPortal && !_harvesterAwarded) {
      // Legacy: Play intro → award harvester → reveal portals
      _introCtrl.forward().whenComplete(() {
        _awardHarvester();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _portalRevealCtrl.forward();
        });
      });
    } else if (_phase == NexusPhase.choosingPortal && _harvesterAwarded) {
      // Resuming after crash during choosing — skip intro
      _introCtrl.value = 1.0;
      _portalRevealCtrl.forward();
    }
  }

  Future<void> _awardHarvester() async {
    if (_harvesterAwarded) return;
    _harvesterAwarded = true;
    final db = context.read<AlchemonsDatabase>();
    await db.inventoryDao.addItemQty(InvKeys.harvesterGuaranteed, 1);
    HapticFeedback.heavyImpact();
    if (mounted) setState(() {});
  }

  void _onPortalChosen(String element) {
    if (_encounterActive) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _chosenElement = element;
      _phase = NexusPhase.inEncounter;
    });
    // Persist the choice immediately in case of crash
    _persistPhase();
    _startEncounter(element);
  }

  void _persistPhase() {
    // This is handled by the parent cosmic screen via the nexus state callbacks.
    // We rely on the pop result to sync state.
  }

  void _startEncounter(String element) {
    final repo = context.read<CreatureCatalog>();

    // Find a Kin of the chosen element
    final pool = repo.creatures
        .where(
          (c) =>
              c.mutationFamily?.toLowerCase() == 'kin' &&
              c.types.any((t) => t == element),
        )
        .toList();

    if (pool.isEmpty) {
      // Fallback: any creature of that element
      final fallback = repo.creatures
          .where(
            (c) =>
                c.rarity.toLowerCase() != 'mystic' &&
                c.types.any((t) => t == element),
          )
          .toList();
      if (fallback.isEmpty) {
        Navigator.of(context).pop(const NexusResult(caught: false));
        return;
      }
      pool.addAll(fallback);
    }

    final rng = Random();
    final picked = pool[rng.nextInt(pool.length)];

    // Generate prismatic version with fixed stats: 3.0 starting, 4.5 potential
    final gen = WildlifeGenerator(
      repo,
      tuning: const WildlifeTuning(prismaticSkinChance: 1.0),
    );
    var hydrated = gen.generate(picked.id, rarity: 'legendary');
    if (hydrated == null) {
      Navigator.of(context).pop(const NexusResult(caught: false));
      return;
    }

    // Override stats to fixed values
    hydrated = hydrated.copyWith(
      stats: const CreatureStats(
        speed: 3.0,
        intelligence: 3.0,
        strength: 3.0,
        beauty: 3.0,
        speedPotential: 4.5,
        intelligencePotential: 4.5,
        strengthPotential: 4.5,
        beautyPotential: 4.5,
      ),
      isPrismaticSkin: true,
    );

    setState(() {
      _encounterCreature = hydrated;
      _encounterActive = true;
    });
  }

  @override
  void dispose() {
    // Restore all orientations when leaving the nexus encounter
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _introCtrl.dispose();
    _portalRevealCtrl.dispose();
    _encounterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Subtle particle background ──
          _NexusParticleField(controller: _encounterCtrl),

          // ── Intro text ──
          if (_phase == NexusPhase.choosingPortal)
            AnimatedBuilder(
              animation: _introCtrl,
              builder: (context, _) {
                final t = _introCtrl.value;
                // Phase 1: 0→0.4 = "Guarantee Harvester Found" fades in
                // Phase 2: 0.4→0.7 = hold
                // Phase 3: 0.7→1.0 = text moves up, portals start appearing
                double textOpacity;
                double textOffsetY;
                if (t < 0.4) {
                  textOpacity = (t / 0.4).clamp(0.0, 1.0);
                  textOffsetY = 20.0 * (1 - t / 0.4);
                } else if (t < 0.7) {
                  textOpacity = 1.0;
                  textOffsetY = 0;
                } else {
                  textOpacity = 1.0;
                  textOffsetY = -60.0 * ((t - 0.7) / 0.3);
                }

                return Center(
                  child: Transform.translate(
                    offset: Offset(0, textOffsetY),
                    child: Opacity(
                      opacity: textOpacity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            color: Colors.amber.withValues(alpha: textOpacity),
                            size: 28,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'GUARANTEE HARVESTER FOUND',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.amber.withValues(
                                alpha: textOpacity,
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  blurRadius: 20,
                                  color: Colors.amber.withValues(
                                    alpha: textOpacity * 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '+1 added to inventory',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.white54.withValues(
                                alpha: textOpacity * 0.8,
                              ),
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          // ── Four elemental portals ──
          if (_phase == NexusPhase.choosingPortal && !_encounterActive)
            AnimatedBuilder(
              animation: _portalRevealCtrl,
              builder: (context, _) {
                final t = _portalRevealCtrl.value;
                if (t < 0.01) return const SizedBox.shrink();
                return _ElementalPortalGrid(
                  revealProgress: t,
                  pulseTime: _encounterCtrl.value * pi * 2 * 3,
                  onPortalChosen: _onPortalChosen,
                );
              },
            ),

          // ── Encounter creature display ──
          if (_encounterCreature != null && _encounterActive)
            Center(
              child: _VoidSprite(
                creature: _encounterCreature!,
                size: 170,
                isPrismatic: true,
                flipHorizontal: false,
              ),
            ),

          // ── Party creature (left side) ──
          if (_selectedPartyCreature != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.32,
              child: Center(
                child: _VoidSprite(
                  creature: _selectedPartyCreature!,
                  size: 140,
                  isPrismatic: _selectedPartyCreature!.isPrismaticSkin == true,
                  flipHorizontal: true,
                ),
              ),
            ),

          // ── Encounter overlay ──
          if (_encounterCreature != null && _encounterActive)
            EncounterOverlay(
              encounter: WildEncounter(
                wildBaseId: _encounterCreature!.id,
                baseBreedChance: breedChanceForRarity(
                  EncounterRarity.legendary,
                ),
                rarity: 'legendary',
                voidBred: true,
                source: 'elemental_nexus',
              ),
              hydratedWildCreature: _encounterCreature!,
              party: const [], // harvester-only capture in cosmic
              highlightPartyHUD: false,
              isTutorial: false,
              warnOnRun: true,
              onPreRollShake: () {},
              onPartyCreatureSelected: (c) {
                setState(() => _selectedPartyCreature = c);
              },
              onClosedWithResult: (success) {
                if (!mounted) return;
                Navigator.of(context).pop(
                  NexusResult(caught: success, chosenElement: _chosenElement),
                );
              },
            ),

          // ── Back button (only during portal choosing) ──
          if (_phase == NexusPhase.choosingPortal && !_encounterActive)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const NexusResult(caught: false)),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),

          // ── Title header ──
          if (!_encounterActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, left: 60),
                  child: AnimatedBuilder(
                    animation: _portalRevealCtrl,
                    builder: (context, _) {
                      final t = _portalRevealCtrl.value;
                      return Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ELEMENTAL NEXUS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.5,
                              ),
                            ),
                            Text(
                              'CHOOSE YOUR PATH',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ELEMENTAL PORTAL GRID
// ─────────────────────────────────────────────────────────

class _ElementalPortalGrid extends StatelessWidget {
  final double revealProgress; // 0→1
  final double pulseTime;
  final ValueChanged<String> onPortalChosen;

  const _ElementalPortalGrid({
    required this.revealProgress,
    required this.pulseTime,
    required this.onPortalChosen,
  });

  static const _portals = [
    _PortalDef(
      'Fire',
      Color(0xFFFF5722),
      Color(0xFF1A0500),
      Icons.local_fire_department_rounded,
    ),
    _PortalDef(
      'Water',
      Color(0xFF448AFF),
      Color(0xFF000D1A),
      Icons.water_drop_rounded,
    ),
    _PortalDef(
      'Earth',
      Color(0xFF795548),
      Color(0xFF1A0A00),
      Icons.terrain_rounded,
    ),
    _PortalDef('Air', Color(0xFF81D4FA), Color(0xFF001020), Icons.air_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: isLandscape ? 40 : 100),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: List.generate(_portals.length, (i) {
            // Staggered reveal: each portal appears 0.15 apart
            final stagger = (i * 0.15).clamp(0.0, 0.6);
            final localT = ((revealProgress - stagger) / 0.4).clamp(0.0, 1.0);
            final portal = _portals[i];

            return _PortalButton(
              def: portal,
              revealT: localT,
              pulseTime: pulseTime,
              onTap: () => onPortalChosen(portal.element),
            );
          }),
        ),
      ),
    );
  }
}

class _PortalDef {
  final String element;
  final Color color;
  final Color coreColor;
  final IconData icon;

  const _PortalDef(this.element, this.color, this.coreColor, this.icon);
}

class _PortalButton extends StatelessWidget {
  final _PortalDef def;
  final double revealT;
  final double pulseTime;
  final VoidCallback onTap;

  const _PortalButton({
    required this.def,
    required this.revealT,
    required this.pulseTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (revealT <= 0) return const SizedBox.shrink();

    final pulse = 0.85 + 0.15 * sin(pulseTime + def.element.hashCode);
    final scale = Curves.elasticOut.transform(revealT);
    final opacity = revealT.clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 130,
            height: 160,
            decoration: BoxDecoration(
              color: def.coreColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: def.color.withValues(alpha: 0.6 * pulse),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: def.color.withValues(alpha: 0.3 * pulse),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Portal visual
                CustomPaint(
                  size: const Size(70, 70),
                  painter: _MiniPortalPainter(
                    color: def.color,
                    coreColor: def.coreColor,
                    time: pulseTime,
                  ),
                ),
                const SizedBox(height: 12),
                // Element label
                Text(
                  def.element.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: def.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  def.icon,
                  color: def.color.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// MINI PORTAL PAINTER (for the four portal cards)
// ─────────────────────────────────────────────────────────

class _MiniPortalPainter extends CustomPainter {
  final Color color;
  final Color coreColor;
  final double time;

  const _MiniPortalPainter({
    required this.color,
    required this.coreColor,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.32;
    final pulse = 0.88 + 0.12 * sin(time * 0.7);

    // Outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 2.0,
      Paint()
        ..color = color.withValues(alpha: 0.1 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Event horizon
    canvas.drawCircle(Offset(cx, cy), r * pulse, Paint()..color = coreColor);

    // Orbiting sparks
    for (var j = 0; j < 5; j++) {
      final a = time * 0.9 + j * pi * 2 / 5;
      final sr = r * 1.3;
      canvas.drawCircle(
        Offset(cx + cos(a) * sr, cy + sin(a) * sr * 0.5),
        2 * pulse,
        Paint()..color = color.withValues(alpha: 0.55 * pulse),
      );
    }

    // Rim
    canvas.drawCircle(
      Offset(cx, cy),
      r * pulse,
      Paint()
        ..color = color.withValues(alpha: 0.3 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_MiniPortalPainter old) => old.time != time;
}

// ─────────────────────────────────────────────────────────
// SUBTLE PARTICLE FIELD BACKGROUND
// ─────────────────────────────────────────────────────────

class _NexusParticleField extends StatelessWidget {
  final AnimationController controller;

  const _NexusParticleField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _NexusBgPainter(time: controller.value * pi * 2 * 3),
        );
      },
    );
  }
}

class _NexusBgPainter extends CustomPainter {
  final double time;

  // Stable particles generated once
  static final List<_BgDot> _dots = _buildDots();

  static List<_BgDot> _buildDots() {
    final rng = Random(99);
    return List.generate(40, (i) {
      return _BgDot(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        speed: 0.1 + rng.nextDouble() * 0.3,
        size: 0.8 + rng.nextDouble() * 1.5,
        opacity: 0.15 + rng.nextDouble() * 0.25,
      );
    });
  }

  const _NexusBgPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in _dots) {
      final px = d.x * size.width;
      final py = (d.y + sin(time * d.speed + d.x * 10) * 0.02) * size.height;
      canvas.drawCircle(
        Offset(px, py),
        d.size,
        Paint()
          ..color = Colors.white.withValues(
            alpha: d.opacity * (0.8 + 0.2 * sin(time * 2 + d.x * 20)),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_NexusBgPainter old) => old.time != time;
}

class _BgDot {
  final double x, y, speed, size, opacity;
  const _BgDot({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

// ─────────────────────────────────────────────────────────
// VOID SPRITE (reused from rift_portal_screen pattern)
// ─────────────────────────────────────────────────────────

class _VoidSprite extends StatelessWidget {
  final Creature creature;
  final double size;
  final bool isPrismatic;
  final bool flipHorizontal;

  const _VoidSprite({
    required this.creature,
    required this.size,
    required this.isPrismatic,
    required this.flipHorizontal,
  });

  @override
  Widget build(BuildContext context) {
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
          isPrismatic: isPrismatic,
          tint: visuals.tint,
          alchemyEffect: visuals.alchemyEffect,
          variantFaction: visuals.variantFaction,
        ),
      );
    } else {
      sprite = SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.pets, color: Colors.white24, size: size * 0.5),
      );
    }

    if (flipHorizontal) {
      return Transform.scale(scaleX: -1, child: sprite);
    }
    return sprite;
  }
}
