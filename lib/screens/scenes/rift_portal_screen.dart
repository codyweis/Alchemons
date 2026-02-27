// lib/screens/scenes/rift_portal_screen.dart
import 'dart:math';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RiftPortalScreen extends StatefulWidget {
  final RiftFaction faction;

  /// Party members available inside the void (already filtered to compatible
  /// by [_RiftVoidPage] before navigating here).
  final List<PartyMember> party;

  const RiftPortalScreen({
    super.key,
    required this.faction,
    this.party = const [],
  });

  @override
  State<RiftPortalScreen> createState() => _RiftPortalScreenState();
}

class _RiftPortalScreenState extends State<RiftPortalScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _bannerCtrl;
  late AnimationController _entryCtrl;
  bool _entryDone = false;

  Creature? _voidCreature;
  EncounterRarity _voidRarity = EncounterRarity.common;
  bool _spawned = false;
  bool _encounterActive = true;
  Creature? _selectedPartyCreature;

  // Rarity weights: common / uncommon / rare / legendary
  static const _rarityWeights = [60.0, 25.0, 10.0, 2.0];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
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
      _spawnVoidCreature();
    }
  }

  void _spawnVoidCreature() {
    final repo = context.read<CreatureCatalog>();
    final rng = Random();

    // Roll rarity using base weights.
    final total = _rarityWeights.reduce((a, b) => a + b);
    double roll = rng.nextDouble() * total;
    EncounterRarity rarity = EncounterRarity.common;
    for (int i = 0; i < EncounterRarity.values.length; i++) {
      roll -= _rarityWeights[i];
      if (roll <= 0) {
        rarity = EncounterRarity.values[i];
        break;
      }
    }

    // Filter catalog to species whose types overlap the faction.
    // Exclude Mystic rarity — they are not part of the standard encounter pool.
    final matchTypes = widget.faction.matchingTypes;
    final pool = repo.creatures
        .where(
          (c) =>
              c.rarity.toLowerCase() != 'mystic' &&
              c.types.any((t) => matchTypes.contains(t)),
        )
        .toList();

    if (pool.isEmpty) {
      debugPrint('⚠️ No creatures match faction ${widget.faction.factionKey}');
      return;
    }

    // Build a rarity-weighted list.
    // Guard against non-standard rarity strings (e.g. "Mystic") by falling
    // back to the rare weight so they can still appear but are uncommon.
    final weighted = <Creature>[];
    for (final c in pool) {
      final known = EncounterRarity.values.firstWhere(
        (e) => e.label == c.rarity.toLowerCase(),
        orElse: () => EncounterRarity.rare,
      );
      final w = known.baseWeight;
      for (int i = 0; i < (w / 5).round().clamp(1, 20); i++) {
        weighted.add(c);
      }
    }

    final picked = weighted[rng.nextInt(weighted.length)];

    // Generate a prismatic instance (100% prismatic chance for void spawns).
    final gen = WildlifeGenerator(
      repo,
      tuning: const WildlifeTuning(prismaticSkinChance: 1.0),
    );
    final hydrated = gen.generate(picked.id, rarity: rarity.label);
    if (hydrated == null) return;

    setState(() {
      _voidCreature = hydrated;
      _voidRarity = rarity;
    });
    _bannerCtrl.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _bannerCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final color = widget.faction.primaryColor;
    final factionName = widget.faction.displayName.toUpperCase();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Particle background ───────────────────────────────────────────
          IgnorePointer(
            child: AlchemicalParticleBackground(
              opacity: 0.55,
              backgroundColor: Colors.transparent,
            ),
          ),

          // ── Animated portal ───────────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(320, 320),
                  painter: _PortalPainter(
                    faction: widget.faction,
                    time: _controller.value * pi * 2 * 4,
                  ),
                );
              },
            ),
          ),

          // ── Header ────────────────────────────────────────────────────────
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
                        color: t.bg1.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: t.borderDim, width: 1),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: t.textPrimary,
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
                        'RIFT PORTAL',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                        ),
                      ),
                      Text(
                        factionName,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textPrimary,
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

          // ── Wild creature — centred over the portal ─────────────────────
          if (_voidCreature != null)
            Center(
              child: AnimatedBuilder(
                animation: _bannerCtrl,
                builder: (context, child) {
                  final t2 = Curves.easeOutCubic.transform(_bannerCtrl.value);
                  return Opacity(opacity: t2.clamp(0.0, 1.0), child: child);
                },
                child: _VoidSprite(
                  creature: _voidCreature!,
                  size: 170,
                  isPrismatic: true,
                  flipHorizontal: false,
                ),
              ),
            ),

          // ── Party creature — left side, flipped to face the wild ──────────
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
                  flipHorizontal: true, // face right → toward the wild
                ),
              ),
            ),

          // ── Encounter overlay (fuse / capture) ────────────────────────────
          if (_voidCreature != null && _encounterActive)
            EncounterOverlay(
              encounter: WildEncounter(
                wildBaseId: _voidCreature!.id,
                baseBreedChance: breedChanceForRarity(_voidRarity),
                rarity: _voidRarity.label,
                voidBred: true, // guarantees prismatic offspring on fuse
              ),
              hydratedWildCreature: _voidCreature!,
              party: widget.party,
              highlightPartyHUD: false,
              isTutorial: false,
              warnOnRun: true,
              onPreRollShake: () {},
              onPartyCreatureSelected: (c) {
                setState(() => _selectedPartyCreature = c);
              },
              onClosedWithResult: (success) {
                if (!mounted) return;
                if (success) {
                  // Breed or catch succeeded — pop and signal the scene to
                  // clear the portal.
                  Navigator.of(context).pop(true);
                } else {
                  // Ran away — return to scene without clearing the portal.
                  Navigator.of(context).pop(false);
                }
              },
            ),

          // ── Portal entry flash (plays once on first load) ─────────────────
          if (!_entryDone)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _entryCtrl,
                builder: (context, _) => _PortalEntryFlash(
                  faction: widget.faction,
                  progress: _entryCtrl.value,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Bare sprite — no borders, no labels ──────────────────────────────────────

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

// ── CustomPainter — mirrors the Flame component logic ─────────────────────────

class _PortalPainter extends CustomPainter {
  final RiftFaction faction;
  final double time;

  // Stable particle data generated once
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

  const _PortalPainter({required this.faction, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.22; // core radius relative to canvas
    final pulse = 0.88 + 0.12 * sin(time * 0.63);
    final color = faction.primaryColor;

    // Outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 2.6,
      Paint()
        ..color = color.withOpacity(0.08 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36),
    );

    // Mid glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 1.8,
      Paint()
        ..color = color.withOpacity(0.16 * pulse)
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
            color.withOpacity(0),
            color.withOpacity(0.55 * pulse),
            color.withOpacity(0),
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
          colors: [faction.coreColor, faction.coreColor, Colors.black],
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
          ..color = color.withOpacity(p.opacity * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
      );
    }

    // Spiral arms
    final spiralPaint = Paint()
      ..color = color.withOpacity(0.30 * pulse)
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
        ..color = color.withOpacity(0.22 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(_PortalPainter old) =>
      old.time != time || old.faction != faction;
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

// ── Portal entry flash overlay ────────────────────────────────────────────────
// Plays once when the screen loads to simulate stepping through the portal.
// progress: 0.0 → 1.0 (driven by _entryCtrl)
//
//  0.00 – 0.15  black → faction radial burst (fade in)
//  0.15 – 0.40  white flash peak
//  0.40 – 0.65  rings expand outward
//  0.65 – 1.00  entire overlay fades out to transparent

class _PortalEntryFlash extends StatelessWidget {
  final RiftFaction faction;
  final double progress; // 0.0 – 1.0

  const _PortalEntryFlash({required this.faction, required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EntryFlashPainter(faction: faction, progress: progress),
      size: Size.infinite,
    );
  }
}

class _EntryFlashPainter extends CustomPainter {
  final RiftFaction faction;
  final double progress;

  const _EntryFlashPainter({required this.faction, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final color = faction.primaryColor;
    final maxR = size.longestSide * 1.2;

    // ── Overall overlay opacity (0→1 fast, then 1→0 at end) ─────────────────
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

    // ── Dark radial base ─────────────────────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: [
            Color.lerp(color, Colors.black, 0.3)!.withOpacity(0.85),
            Colors.black.withOpacity(0.95),
          ],
        ).createShader(Offset.zero & size),
    );

    // ── White flash at progress 0.15–0.45 ───────────────────────────────────
    double flashAlpha = 0.0;
    if (progress >= 0.12 && progress <= 0.45) {
      final t = (progress - 0.12) / 0.33;
      // Triangle: peak at 0.35 of this sub-range
      flashAlpha = t < 0.35 ? (t / 0.35) : (1.0 - (t - 0.35) / 0.65);
      flashAlpha = flashAlpha.clamp(0.0, 1.0) * 0.92;
    }
    if (flashAlpha > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withOpacity(flashAlpha),
      );
    }

    // ── Expanding rings ───────────────────────────────────────────────────────
    // 5 rings with staggered starts; each ring lifespan = 0.25 of progress
    // appearing from progress 0.25 to 0.75
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
          ..color = color.withOpacity(ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // ── Faction glow core ─────────────────────────────────────────────────────
    if (progress < 0.55) {
      final glowAlpha = (1.0 - (progress / 0.55)).clamp(0.0, 1.0) * 0.6;
      canvas.drawCircle(
        center,
        maxR * 0.25,
        Paint()
          ..color = color.withOpacity(glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_EntryFlashPainter old) =>
      old.progress != progress || old.faction != faction;
}
