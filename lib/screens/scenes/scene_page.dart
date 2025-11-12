// lib/screens/scenes/scene_page.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/background/daynight_filter.dart';
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

    _game = SceneGame(scene: widget.scene);

    _encounters = EncounterService(
      scene: widget.scene,
      party: widget.party,
      tableBuilder: valleyEncounterPools, // or your scene-specific builder
    );

    _game.attachEncounters(_encounters);

    _game.onStartEncounter = (spawnId, speciesId, hydrated) {
      _usedSpawnPointId = spawnId; // <-- 🔑 STORE THE ID HERE
      setState(() {
        _inEncounter = true;
        _wildCreature = hydrated as Creature;
      });
      HapticFeedback.mediumImpact();
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
    _encounters.clearSpawns();

    for (final sp in widget.scene.spawnPoints) {
      final enc = _spawnService.getSpawnAt(widget.sceneId, sp.id);
      if (enc == null) continue;

      final asWild = WildEncounter(
        wildBaseId: enc.speciesId,
        baseBreedChance: breedChanceForRarity(enc.rarity),
        rarity: enc.rarity.name,
      );

      _encounters.forceSpawnAt(sp.id, asWild);
    }

    _game.attachEncounters(_encounters);

    // 🔑 NEW: mirror EncounterService -> actual on-screen wilds
    _game.syncWildFromEncounters();
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

  void _exitEncounter({String? clearSpawnId}) {
    setState(() {
      _inEncounter = false;
    });
    _game.exitEncounterMode();

    if (clearSpawnId != null) {
      _game.clearWildAt(clearSpawnId); // <- remove only that one
    }

    HapticFeedback.lightImpact();
  }

  // --- UI --------------------------------------------------------------------
  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool night = isNight(now);

    return Consumer<CreatureCatalog>(
      builder: (context, gameState, _) {
        if (!_resolverHooked) {
          final repo = context.read<CreatureCatalog>();
          _game.wildVisualResolver = (speciesId, rarity) async {
            final gen = WildlifeGenerator(repo);
            return gen.generate(speciesId, rarity: rarity.name);
          };
          _resolverHooked = true;
        }

        return PopScope(
          canPop: false,
          child: Scaffold(
            body: Stack(
              children: [
                // 🎮 Game view with binary night filter
                LayoutBuilder(
                  builder: (context, constraints) {
                    final game = SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: GameWidget(game: _game),
                    );

                    return DayNightFilter(
                      intensity: night ? 1.0 : 0.0, // YES/NO filter
                      tint: const Color(0xFF081028), // darker blue tone
                      minLuma: 0.45, // 45 % brightness at night
                      child: game,
                    );
                  },
                ),

                // ✨ Always show particles
                IgnorePointer(
                  child: AlchemicalParticleBackground(
                    opacity: 0.9,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                if (_inEncounter && _wildCreature != null)
                  EncounterOverlay(
                    encounter: WildEncounter(
                      wildBaseId: _wildCreature!.id,
                      baseBreedChance: breedChanceForRarity(
                        EncounterRarity.values.byName(
                          _wildCreature!.rarity.toLowerCase(),
                        ),
                      ),
                      rarity: _wildCreature!.rarity,
                    ),
                    hydratedWildCreature: _wildCreature!,
                    party: widget.party,
                    onPreRollShake: () {
                      _game.shake(
                        duration: const Duration(milliseconds: 800),
                        amplitude: 14,
                      );
                    },
                    onPartyCreatureSelected: _onPartyCreatureSelected,
                    onClosedWithResult: (success) async {
                      final id = _usedSpawnPointId;

                      // exit encounter first (don’t clear anything yet)
                      _exitEncounter();

                      if (success && id != null) {
                        // a) remove visual immediately (snappy UX)
                        _game.clearWildAt(id);

                        // b) remove from the spawn service (DB + memory)
                        await _spawnService.removeSpawn(widget.sceneId, id);

                        // c) re-sync EncounterService -> visuals (no-ops for others)
                        _syncSpawnsFromService();

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
