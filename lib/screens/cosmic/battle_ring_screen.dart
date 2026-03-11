// lib/screens/cosmic/battle_ring_screen.dart
//
// Battle Ring — a 10-level 1v1 arena in cosmic space.
//
// Flow:
//   1. Dramatic intro showing level info
//   2. Generates an opponent creature matching the level's rarity/stats
//   3. Runs a 1v1 encounter using EncounterOverlay
//   4. On win → returns BattleRingResult(won: true)
//   5. On flee/lose → returns BattleRingResult(won: false)
//
// After level 10, becomes a practice arena where two of the player's
// Alchemons fight each other.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────
// RESULT passed back to cosmic_screen
// ─────────────────────────────────────────────────────────

class BattleRingResult {
  final bool won;
  final int levelCompleted; // 0-based level that was just completed
  final bool isPractice;

  const BattleRingResult({
    this.won = false,
    this.levelCompleted = 0,
    this.isPractice = false,
  });
}

// ─────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────

class BattleRingScreen extends StatefulWidget {
  final bool isPractice;
  final int level; // 0-based
  final CosmicPartyMember playerCreature1;
  final CosmicPartyMember? playerCreature2; // only for practice mode

  const BattleRingScreen({
    super.key,
    required this.isPractice,
    required this.level,
    required this.playerCreature1,
    this.playerCreature2,
  });

  @override
  State<BattleRingScreen> createState() => _BattleRingScreenState();
}

class _BattleRingScreenState extends State<BattleRingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final AnimationController _encounterCtrl;

  Creature? _encounterCreature;
  bool _encounterActive = false;
  bool _introComplete = false;

  @override
  void initState() {
    super.initState();

    // Lock to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _encounterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _introCtrl.forward().then((_) {
      if (mounted) {
        setState(() => _introComplete = true);
        _startEncounter();
      }
    });
  }

  void _startEncounter() {
    if (widget.isPractice) {
      _startPracticeEncounter();
      return;
    }

    final repo = context.read<CreatureCatalog>();

    // Fixed opponent for each level (0-based index)
    // Level 1: Firelet (common Let)
    // Level 2: Waterlet (common Let)
    // Level 3: Airlet (common Let)
    // Level 4: Firepip (uncommon Pip)
    // Level 5: Icemane (uncommon Mane)
    // Level 6: Crystalpip (uncommon Pip)
    // Level 7: Earthmane (uncommon Mane)
    // Level 8: Firehorn (rare Horn)
    // Level 9: Earthkin (legendary Kin)
    // Level 10: Firewing (legendary Wing)
    const levelOpponents = <int, (String, String)>{
      0: ('LET13', 'common'), // Poisonlet
      1: ('WNG04', 'legendary'), // Airwing
      2: ('MAN14', 'uncommon'), // Spiritmane
      3: ('MSK09', 'rare'), // Icemask
      4: ('HOR16', 'rare'), // Lighthorn
      5: ('MAN05', 'uncommon'), // Steammane
      6: ('PIP06', 'uncommon'), // Lavapip
      7: ('MAN03', 'uncommon'), // Earthmane
      8: ('KIN12', 'legendary'), // Plantkin
      9: ('WNG01', 'legendary'), // Firewing
    };

    final entry = levelOpponents[widget.level];
    if (entry == null) {
      Navigator.of(context).pop(const BattleRingResult(won: false));
      return;
    }
    final (speciesId, rarity) = entry;

    // Generate the fixed opponent
    final gen = WildlifeGenerator(repo);
    var hydrated = gen.generate(speciesId, rarity: rarity);
    if (hydrated == null) {
      Navigator.of(context).pop(const BattleRingResult(won: false));
      return;
    }

    // Scale stats: base from 1.5 (level 0), max caps at 4.75 (level 9).
    // Each stat gets a random value from base up to base+40% for variety.
    const startBase = 1.5;
    const maxCap = 4.75;
    final endBase = maxCap / 1.4; // ~3.39
    final statBase = startBase + (widget.level * (endBase - startBase) / 9.0);
    final rng = Random();
    double randStat() {
      return statBase + rng.nextDouble() * (statBase * 0.4);
    }

    hydrated = hydrated.copyWith(
      stats: CreatureStats(
        speed: randStat(),
        intelligence: randStat(),
        strength: randStat(),
        beauty: randStat(),
        speedPotential: maxCap,
        intelligencePotential: maxCap,
        strengthPotential: maxCap,
        beautyPotential: maxCap,
      ),
    );

    setState(() {
      _encounterCreature = hydrated;
      _encounterActive = true;
    });
  }

  void _startPracticeEncounter() {
    // In practice mode, creature2 fights creature1
    // We use creature2 as the "wild" encounter creature
    if (widget.playerCreature2 == null) {
      Navigator.of(context).pop(const BattleRingResult(won: false));
      return;
    }

    final repo = context.read<CreatureCatalog>();
    final gen = WildlifeGenerator(repo);
    var hydrated = gen.generate(widget.playerCreature2!.baseId);
    if (hydrated == null) {
      Navigator.of(context).pop(const BattleRingResult(won: false));
      return;
    }

    // Use creature2's actual stats
    hydrated = hydrated.copyWith(
      stats: CreatureStats(
        speed: widget.playerCreature2!.statSpeed,
        intelligence: widget.playerCreature2!.statIntelligence,
        strength: widget.playerCreature2!.statStrength,
        beauty: widget.playerCreature2!.statBeauty,
        speedPotential: widget.playerCreature2!.statSpeed,
        intelligencePotential: widget.playerCreature2!.statIntelligence,
        strengthPotential: widget.playerCreature2!.statStrength,
        beautyPotential: widget.playerCreature2!.statBeauty,
      ),
    );

    setState(() {
      _encounterCreature = hydrated;
      _encounterActive = true;
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _introCtrl.dispose();
    _encounterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levelDisplay = widget.level + 1;
    final isLegendary = widget.level >= 8;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Particle background ──
          _BattleRingParticleField(controller: _encounterCtrl),

          // ── Intro animation ──
          if (!_introComplete)
            AnimatedBuilder(
              animation: _introCtrl,
              builder: (context, _) {
                final t = _introCtrl.value;
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
                            widget.isPractice
                                ? Icons.sports_martial_arts
                                : Icons.sports_mma,
                            color:
                                (isLegendary
                                        ? Colors.amber
                                        : const Color(0xFFFFD740))
                                    .withValues(alpha: textOpacity),
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isPractice
                                ? 'PRACTICE ARENA'
                                : 'BATTLE RING',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color:
                                  (isLegendary
                                          ? Colors.amber
                                          : const Color(0xFFFFD740))
                                      .withValues(alpha: textOpacity),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!widget.isPractice)
                            Text(
                              'LEVEL $levelDisplay / ${BattleRing.maxLevels}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white.withValues(
                                  alpha: textOpacity * 0.7,
                                ),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isPractice
                                ? 'Your Alchemons face off!'
                                : isLegendary
                                ? 'A legendary challenger awaits...'
                                : '1v1 · All opponents Level 10',
                            style: TextStyle(
                              color: Colors.white.withValues(
                                alpha: textOpacity * 0.5,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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

          // ── Encounter overlay ──
          if (_encounterCreature != null && _encounterActive)
            EncounterOverlay(
              encounter: WildEncounter(
                wildBaseId: _encounterCreature!.id,
                baseBreedChance: widget.isPractice
                    ? 0
                    : breedChanceForRarity(
                        widget.level >= 8
                            ? EncounterRarity.legendary
                            : EncounterRarity.common,
                      ),
                rarity: widget.level >= 8 ? 'legendary' : 'common',
                source: widget.isPractice
                    ? 'battle_ring_practice'
                    : 'battle_ring',
              ),
              hydratedWildCreature: _encounterCreature!,
              party: [
                PartyMember(instanceId: widget.playerCreature1.instanceId),
              ],
              highlightPartyHUD: false,
              isTutorial: false,
              warnOnRun: true,
              onPreRollShake: () {},
              onPartyCreatureSelected: (_) {},
              onClosedWithResult: (success) {
                if (!mounted) return;
                Navigator.of(context).pop(
                  BattleRingResult(
                    won: success,
                    levelCompleted: widget.level,
                    isPractice: widget.isPractice,
                  ),
                );
              },
            ),

          // ── Back button (during intro) ──
          if (!_encounterActive)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const BattleRingResult(won: false)),
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PARTICLE FIELD BACKGROUND
// ─────────────────────────────────────────────────────────

class _BattleRingParticleField extends StatelessWidget {
  final AnimationController controller;
  const _BattleRingParticleField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(painter: _BattleFieldPainter(controller.value));
      },
    );
  }
}

class _BattleFieldPainter extends CustomPainter {
  final double t;
  _BattleFieldPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rng = Random(42);

    // Subtle drifting particles
    for (int i = 0; i < 60; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble() * pi * 2;
      final drift = t * 30 * speed;

      final x = (baseX + sin(drift + phase) * 30) % size.width;
      final y = (baseY + cos(drift * 0.7 + phase) * 20) % size.height;
      final alpha = (0.1 + 0.15 * sin(t * pi * 2 * speed + phase)).clamp(
        0.0,
        1.0,
      );

      canvas.drawCircle(
        Offset(x, y),
        1.5 + rng.nextDouble(),
        Paint()
          ..color = Color.fromRGBO(
            200 + rng.nextInt(55),
            150 + rng.nextInt(105),
            50 + rng.nextInt(100),
            alpha,
          ),
      );
    }

    // Subtle golden octagon outline in center
    final octR = min(cx, cy) * 0.35;
    final octPath = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 8;
      final px = cx + cos(a) * octR;
      final py = cy + sin(a) * octR;
      if (i == 0) {
        octPath.moveTo(px, py);
      } else {
        octPath.lineTo(px, py);
      }
    }
    octPath.close();

    canvas.drawPath(
      octPath,
      Paint()
        ..color = const Color(0xFFFFD740).withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BattleFieldPainter old) => true;
}
