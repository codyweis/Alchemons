// lib/screens/scenes/scene_page.dart
import 'package:alchemons/database/alchemons_db.dart';
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

class _ScenePageState extends State<ScenePage> {
  late SceneGame _game;
  late EncounterService _encounters;
  bool _resolverHooked = false; // only hook resolver once

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

    // lib/screens/scenes/scene_page.dart
    _game.onStartEncounter = (speciesId, hydrated) async {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      _game.pauseEngine();
      final result = await Navigator.push<EncounterResult>(
        context,
        MaterialPageRoute(
          builder: (_) => EncounterPage(
            speciesId: speciesId,
            party: widget.party, // your PartyMember list
            hydrated: hydrated,
          ),
        ),
      );
      _game.resumeEngine();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      if (result == EncounterResult.bred) {
        _game.clearWild();
      }
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
    super.dispose();
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
    return Consumer2<GameStateNotifier, CatalogData?>(
      builder: (context, gameState, catalogData, _) {
        // Wait until catalogs & repo are ready (same pattern as BreedScreen)
        if (catalogData == null ||
            !catalogData.isFullyLoaded ||
            gameState.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

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
              GameWidget(game: _game),
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
