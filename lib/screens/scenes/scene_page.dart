// lib/screens/scenes/scene_page.dart
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/valley_pool.dart';
import 'package:alchemons/screens/encounter/encounter_screen.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flame/game.dart';

import 'package:alchemons/models/wilderness.dart' show PartyMember;
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/games/scene_game.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart'; // your WildlifeGenerator file
import 'package:alchemons/providers/app_providers.dart'; // GameStateNotifier, CatalogData

class ScenePage extends StatefulWidget {
  final SceneDefinition scene;
  final List<PartyMember> party;
  const ScenePage({super.key, required this.scene, this.party = const []});

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> with TickerProviderStateMixin {
  late SceneGame _game;
  late EncounterService _encounters;
  bool _resolverHooked = false; // only hook resolver once

  late AnimationController _encounterCtrl;
  bool _transitioning = false; // overlay on/off

  @override
  void initState() {
    super.initState();

    // lock to landscape while in scene
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _game = SceneGame(scene: widget.scene);

    _encounters = EncounterService(
      scene: widget.scene,
      party: widget.party,
      tableBuilder: valleyEncounterPools,
    );
    _game.attachEncounters(_encounters);

    // NEW: encounter cinematic
    _encounterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650), // out
      reverseDuration: const Duration(milliseconds: 520), // in
    );

    // lib/screens/scenes/scene_page.dart
    // _game.onStartEncounter = (speciesId, hydrated) async {
    //   SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    //   _game.pauseEngine();
    //   final result = await Navigator.push<EncounterResult>(
    //     context,
    //     MaterialPageRoute(
    //       builder: (_) => EncounterPage(
    //         speciesId: speciesId,
    //         party: widget.party, // your PartyMember list
    //         hydrated: hydrated,
    //       ),
    //     ),
    //   );
    //   _game.resumeEngine();
    //   SystemChrome.setPreferredOrientations([
    //     DeviceOrientation.landscapeLeft,
    //     DeviceOrientation.landscapeRight,
    //   ]);

    //   if (result == EncounterResult.bred) {
    //     _game.clearWild();
    //   }
    // };
    _game.onStartEncounter = (speciesId, hydrated) async {
      // If your engine guarantees this is a Creature, cast once:
      final creature = hydrated as Creature;
      await _startEncounterWithTransition(speciesId, creature);
    };
    _game.onEncounter = (roll) {
      // Handle the encounter event
    };
  }

  @override
  void dispose() {
    _maybeRestoreWaterParty();
    // restore portrait when leaving scene
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _encounterCtrl.dispose();
    super.dispose();
  }

  Future<void> _startEncounterWithTransition(
    String speciesId,
    Creature hydrated,
  ) async {
    // OUT: shake + fade to black
    _transitioning = true;
    setState(() {});
    HapticFeedback.mediumImpact();
    await _encounterCtrl.forward(); // 0 -> 1

    // Switch to portrait & pause while fully black
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _game.pauseEngine();

    final result = await Navigator.push<EncounterResult>(
      context,
      MaterialPageRoute(
        builder: (_) => EncounterPage(
          speciesId: speciesId,
          party: widget.party,
          hydrated: hydrated,
        ),
      ),
    );

    // Back to scene: resume behind black, then fade in
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _game.resumeEngine();

    // IN: fade from black + tiny settle shake
    await _encounterCtrl.reverse(); // 1 -> 0
    _transitioning = false;
    if (mounted) setState(() {});

    if (result == EncounterResult.bred) {
      _game.clearWild();
    }
  }

  Future<void> _maybeRestoreWaterParty() async {
    final factions = context.read<FactionService>();
    if (!(factions.isWater() && await factions.perk2Active())) return;

    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    for (final p in widget.party) {
      final inst = await db.getInstance(p.instanceId);
      if (inst == null) continue;
      final base = repo.getCreatureById(inst.baseId);
      if (base?.types.contains('Water') != true) continue;

      await db.updateStamina(
        instanceId: inst.instanceId,
        staminaBars: inst.staminaMax,
        staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameStateNotifier>(
      builder: (context, gameState, _) {
        // Hook the resolver ONCE, now that catalogs are ready
        if (!_resolverHooked) {
          final repo = context.read<CreatureRepository>();

          _game.wildVisualResolver = (speciesId, rarity) async {
            // Use your existing WildlifeGenerator to hydrate genes/nature/prismatic
            final gen = WildlifeGenerator(repo);
            return gen.generate(speciesId, rarity: rarity.name);
          };

          _resolverHooked = true;

          // If the game spawned before resolver existed, force a fresh spawn now
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _game.clearWild();
          });
        }

        return Scaffold(
          body: Stack(
            children: [
              // 1) GAME + screen shake
              AnimatedBuilder(
                animation: _encounterCtrl,
                child: GameWidget(game: _game),
                builder: (_, child) {
                  final v = _encounterCtrl.value; // 0..1
                  final phaseOut = Curves.easeOutCubic.transform(v);
                  final phaseIn = Curves.easeOutCubic.transform(1 - v);
                  final outAmp = (1 - phaseOut) * 12.0; // px
                  final inAmp = (1 - phaseIn) * 4.0; // px
                  final amp = _encounterCtrl.status == AnimationStatus.reverse
                      ? inAmp
                      : outAmp;

                  final t = v;
                  final dx = math.sin(t * math.pi * 14) * amp;
                  final dy = math.cos(t * math.pi * 11) * amp * 0.7;
                  final rot = math.sin(t * math.pi * 9) * (amp * 0.0022);

                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.rotate(angle: rot, child: child),
                  );
                },
              ),

              // 2) SINGLE overlay: fade-to-black + vignette
              AnimatedBuilder(
                animation: _encounterCtrl,
                builder: (_, __) {
                  final v = _encounterCtrl.value;
                  final black = const Interval(
                    0.15,
                    1.0,
                    curve: Curves.easeInExpo,
                  ).transform(v);
                  if (!_transitioning && black == 0)
                    return const SizedBox.shrink();
                  return IgnorePointer(
                    ignoring: true,
                    child: Stack(
                      children: [
                        // base blackout layer
                        Positioned.fill(
                          child: Opacity(
                            opacity: black,
                            child: const ColoredBox(color: Colors.black),
                          ),
                        ),
                        // vignette on top
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 1.15,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(black * 0.65),
                                  Colors.black.withOpacity(black),
                                ],
                                stops: const [0.45, 0.78, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Back button
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FloatingActionButton.small(
                      heroTag: 'back',
                      backgroundColor: const Color(0xFF6B46C1),
                      foregroundColor: Colors.white,
                      onPressed: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
