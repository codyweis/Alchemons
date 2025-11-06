// lib/screens/scenes/scene_page.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/wilderness/wilderness_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flame/game.dart';

import 'package:alchemons/models/wilderness.dart'
    show PartyMember, WildEncounter;
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart';

class ScenePage extends StatefulWidget {
  final SceneDefinition scene;
  final List<PartyMember> party;
  final String sceneId;
  const ScenePage({
    super.key,
    required this.scene,
    this.party = const [],
    required this.sceneId,
  });

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> with TickerProviderStateMixin {
  late SceneGame _game;
  late EncounterService _encounters;
  bool _resolverHooked = false;

  // Saved references
  late WildernessSpawnService _spawnService;
  late EncounterPool _scenePool;
  late FactionService _factionService;
  late AlchemonsDatabase _db;
  late CreatureCatalog _repo;

  // Encounter state
  bool _inEncounter = false;
  Creature? _wildCreature;

  String? _usedSpawnPointId;

  @override
  void initState() {
    super.initState();

    // Lock to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _game = SceneGame(scene: widget.scene);

    _encounters = EncounterService(
      scene: widget.scene,
      party: widget.party,
      tableBuilder: valleyEncounterPools, // or your scene-specific builder
    );

    _game.attachEncounters(_encounters);

    _game.onStartEncounter = (speciesId, hydrated) {
      setState(() {
        _inEncounter = true;
        _wildCreature = hydrated as Creature;
      });
      HapticFeedback.mediumImpact();
    };

    // If your SceneGame calls back with the EncounterRoll (which includes spawnId),
    // capture the spawn point here:
    _game.onEncounter = (roll) {
      // EncounterRoll from EncounterService has an optional spawnId
      _usedSpawnPointId =
          roll.spawnId; // <- store it for when the overlay closes
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Save references
    _spawnService = context.read<WildernessSpawnService>();
    _scenePool = valleyEncounterPools(widget.scene).sceneWide;
    _factionService = context.read<FactionService>();
    _db = context.read<AlchemonsDatabase>();
    _repo = context.read<CreatureCatalog>();

    // Mark active scene in DB (to clean spawns if interrupted)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _db
          .into(_db.activeSceneEntry)
          .insertOnConflictUpdate(
            ActiveSceneEntryCompanion.insert(
              sceneId: widget.sceneId,
              enteredAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          );
    });

    // Initial sync of persisted spawns -> local encounter service
    _syncSpawnsFromService();

    // Listen for spawn changes while this page is alive
    _spawnService.addListener(_onSpawnServiceChanged);
  }

  @override
  void dispose() {
    // unlock orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _maybeRestoreWaterParty();

    // stop listening
    _spawnService.removeListener(_onSpawnServiceChanged);

    // Clear active scene marker + tidy spawns for this scene.
    // Post to next frame to avoid notifyListeners during dispose
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _db.delete(_db.activeSceneEntry).go();
      } catch (_) {}
      await _spawnService.clearSceneSpawns(widget.sceneId);
    });

    super.dispose();
  }

  // --- helpers ---------------------------------------------------------------

  void _onSpawnServiceChanged() {
    // keep the scene's local spawns in sync with the service
    _syncSpawnsFromService();
  }

  void _syncSpawnsFromService() {
    // wipe local spawns and reconstruct from service
    _encounters.clearSpawns();

    for (final sp in widget.scene.spawnPoints) {
      final enc = _spawnService.getSpawnAt(widget.sceneId, sp.id);
      if (enc == null) continue;

      // Convert EncounterRoll (service) -> WildEncounter (EncounterService API)
      final asWild = WildEncounter(
        wildBaseId: enc.speciesId,
        baseBreedChance: 0.12, // TODO: plug rarity-based rate if desired
        rarity: enc.rarity.name,
      );

      _encounters.forceSpawnAt(sp.id, asWild);
    }

    // ensure the game reads the refreshed encounter list
    _game.attachEncounters(_encounters);
  }

  Future<void> _maybeRestoreWaterParty() async {
    if (!(_factionService.isWater() && await _factionService.perk2Active()))
      return;

    for (final p in widget.party) {
      final inst = await _db.creatureDao.getInstance(p.instanceId);
      if (inst == null) continue;
      final base = _repo.getCreatureById(inst.baseId);
      if (base?.types.contains('Water') != true) continue;

      await _db.creatureDao.updateStamina(
        instanceId: inst.instanceId,
        staminaBars: inst.staminaMax,
        staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }
  }

  void _onPartyCreatureSelected(Creature hydrated) {
    _game.spawnPartyCreature(hydrated);
  }

  void _exitEncounter({bool clearWild = false}) {
    setState(() {
      _inEncounter = false;
    });
    _game.exitEncounterMode();

    if (clearWild) {
      _game.clearWild();
    }

    HapticFeedback.lightImpact();
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<CreatureCatalog>(
      builder: (context, gameState, _) {
        // Hook resolver once
        if (!_resolverHooked) {
          final repo = context.read<CreatureCatalog>();

          _game.wildVisualResolver = (speciesId, rarity) async {
            final gen = WildlifeGenerator(repo);
            return gen.generate(speciesId, rarity: rarity.name);
          };

          _resolverHooked = true;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _game.clearWild();
          });
        }

        return PopScope(
          // 1. Prevents the default system back action (pop the route)
          //    We prevent pop when in an encounter.
          canPop: false,
          child: Scaffold(
            body: Stack(
              children: [
                // Game view
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: GameWidget(game: _game),
                    );
                  },
                ),
                if (_inEncounter && _wildCreature != null)
                  EncounterOverlay(
                    encounter: WildEncounter(
                      wildBaseId: _wildCreature!.id,
                      baseBreedChance: 0.12, // or your rarity-based calc
                      rarity: _wildCreature!.rarity,
                    ),
                    party: widget.party,
                    onPartyCreatureSelected: _onPartyCreatureSelected,
                    onClosedWithResult: (success) async {
                      _exitEncounter(clearWild: success);

                      if (success && _usedSpawnPointId != null) {
                        // 1) remove from service (this also deletes from DB)
                        await _spawnService.removeSpawn(
                          widget.sceneId,
                          _usedSpawnPointId!,
                        );

                        // 3) resync local encounter list so the UI reflects the change
                        _syncSpawnsFromService();

                        // clear the remembered id
                        _usedSpawnPointId = null;
                      }
                    },
                  ),
                // Back / leave button
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: WildernessControls(
                        party: widget.party,
                        onLeave: () async {
                          // clear ActiveSceneEntry and rotate next spawn
                          await _db.delete(_db.activeSceneEntry).go();
                          await _spawnService.clearSceneSpawns(widget.sceneId);

                          if (mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
