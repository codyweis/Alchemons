// lib/screens/scenes/scene_page.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/scenes/valley/valley_scene.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/background/daynight_filter.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/wilderness/wilderness_controls.dart';
import 'package:drift/drift.dart';
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
  final bool isTutorial;
  final void Function(NavSection section, {int? breedInitialTab})?
  onNavigateSection;

  const ScenePage({
    super.key,
    required this.scene,
    this.party = const [],
    required this.sceneId,
    this.isTutorial = false,
    this.onNavigateSection,
  });

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> with TickerProviderStateMixin {
  late SceneGame _game;
  late EncounterService _encounters;
  bool _resolverHooked = false;
  bool _tutorialDialogShown = false;

  // Saved references
  late WildernessSpawnService _spawnService;
  late EncounterPool _scenePool;
  late FactionService _factionService;
  late AlchemonsDatabase _db;
  late CreatureCatalog _repo;

  // Encounter state
  bool _inEncounter = false;
  Creature? _wildCreature;
  bool _showTutorialHighlight = false;

  String? _usedSpawnPointId;

  @override
  void initState() {
    super.initState();

    _game = SceneGame(scene: widget.scene);

    // 🆕 Enable tutorial mode if this is tutorial
    if (widget.isTutorial) {
      _game.isTutorialMode = true;
    }

    _encounters = EncounterService(
      scene: widget.scene,
      party: widget.party,
      tableBuilder: valleyEncounterPools,
    );

    _game.attachEncounters(_encounters);

    _game.onStartEncounter = (spawnId, speciesId, hydrated) {
      _usedSpawnPointId = spawnId;
      setState(() {
        _inEncounter = true;
        _wildCreature = hydrated as Creature;
        _showTutorialHighlight = widget.isTutorial;
      });
      HapticFeedback.mediumImpact();
    };
  }

  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _spawnService = context.read<WildernessSpawnService>();
    _scenePool = valleyEncounterPools(widget.scene).sceneWide;
    _factionService = context.read<FactionService>();
    _db = context.read<AlchemonsDatabase>();
    _repo = context.read<CreatureCatalog>();

    if (!_initialized) {
      _initialized = true;

      _spawnService.markSceneActive(widget.sceneId);
      _spawnService.addListener(_onSpawnServiceChanged);

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _db
            .into(_db.activeSceneEntry)
            .insertOnConflictUpdate(
              ActiveSceneEntryCompanion.insert(
                sceneId: widget.sceneId,
                enteredAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
              ),
            );

        // 🆕 Guarantee tutorial spawn BEFORE showing dialog
        if (widget.isTutorial) {
          await _ensureTutorialSpawn();
        }

        if (widget.isTutorial && !_tutorialDialogShown && mounted) {
          _tutorialDialogShown = true;
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            await _showWelcomeDialog();
          }
        }
      });
    }

    _syncSpawnsFromService();
  }

  // 🆕 Guarantee a LET spawn for tutorial
  Future<void> _ensureTutorialSpawn() async {
    // Clear any existing spawns first
    await _spawnService.clearSceneSpawns(widget.sceneId);

    // Find the best spawn point for tutorial (front-center is ideal)
    // SP_valley_02 is at (0.58, 0.80) - front middle, perfect for tutorial
    const tutorialSpawnId = 'SP_valley_02';

    // Force spawn LET04 at common rarity
    final tutorialEncounter = EncounterRoll(
      speciesId: 'LET04',
      rarity: EncounterRarity.common,
      spawnId: tutorialSpawnId,
    );

    _spawnService.forceSpawnAt(
      widget.sceneId,
      tutorialSpawnId,
      tutorialEncounter,
    );

    // Persist to database
    await _db
        .into(_db.activeSpawns)
        .insert(
          ActiveSpawnsCompanion.insert(
            id: '${widget.sceneId}_$tutorialSpawnId',
            sceneId: widget.sceneId,
            spawnPointId: tutorialSpawnId,
            speciesId: 'LET04',
            rarity: 'common',
            spawnedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrReplace,
        );

    debugPrint('✨ Tutorial spawn guaranteed: LET04 at $tutorialSpawnId');
  }

  Future<void> _showWelcomeDialog() async {
    await LandscapeDialog.show(
      context,
      title: 'Alchemy is Power',
      message:
          'Tap the creature to begin your first fusion. Select one of your Alchemons to attempt the fuse. Alchemons are stronger here. Fusing with them should provide formidable results.',
      typewriter: true,
      kind: LandscapeDialogKind.info,
      icon: Icons.explore_rounded,
      primaryLabel: 'Begin',
      barrierDismissible: false,
    );
  }

  Future<void> _showSuccessDialog() async {
    await LandscapeDialog.show(
      context,
      title: 'Fusion Successful!',
      message: 'Your new Alchemon is cultivating in the chamber.',
      typewriter: false,
      kind: LandscapeDialogKind.success,
      icon: Icons.check_circle_rounded,
      primaryLabel: 'Return to Lab',
      barrierDismissible: false,
    );
  }

  @override
  void dispose() {
    _maybeRestoreWaterParty();
    _spawnService.markSceneInactive(widget.sceneId);
    _spawnService.removeListener(_onSpawnServiceChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _db.delete(_db.activeSceneEntry).go();
      } catch (_) {}
      await _spawnService.clearSceneSpawns(widget.sceneId);
    });

    super.dispose();
  }

  void _onSpawnServiceChanged() {
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
    if (_showTutorialHighlight) {
      setState(() {
        _showTutorialHighlight = false;
      });
    }
    _game.spawnPartyCreature(hydrated);
  }

  void _exitEncounter({String? clearSpawnId}) {
    setState(() {
      _inEncounter = false;
      _showTutorialHighlight = false;
    });
    _game.exitEncounterMode();

    if (clearSpawnId != null) {
      _game.clearWildAt(clearSpawnId);
    }

    HapticFeedback.lightImpact();
  }

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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final game = SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: GameWidget(game: _game),
                    );

                    return DayNightFilter(
                      intensity: night ? 1.0 : 0.0,
                      tint: const Color(0xFF081028),
                      minLuma: 0.45,
                      child: game,
                    );
                  },
                ),

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
                    highlightPartyHUD: _showTutorialHighlight,
                    isTutorial: widget.isTutorial, // 🆕 Pass tutorial flag
                    onPreRollShake: () {
                      _game.shake(
                        duration: const Duration(milliseconds: 800),
                        amplitude: 14,
                      );
                    },
                    onPartyCreatureSelected: _onPartyCreatureSelected,
                    onClosedWithResult: (success) async {
                      final id = _usedSpawnPointId;

                      _exitEncounter();

                      if (success && id != null) {
                        _game.clearWildAt(id);
                        await _spawnService.removeSpawn(widget.sceneId, id);
                        _syncSpawnsFromService();

                        _usedSpawnPointId = null;

                        // 🆕 Handle tutorial completion AFTER everything
                        if (!widget.isTutorial || !mounted) return;

                        await _showSuccessDialog();
                        if (!mounted) return;

                        final settingsDao = _db.settingsDao;
                        await settingsDao.setFieldTutorialCompleted();
                        await settingsDao.setNavLocked(false);

                        // Pop back with a result indicating tutorial completion
                        if (!mounted) return;
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);

                        // Signal the navigation request
                        if (widget.onNavigateSection != null) {
                          // Need to use the context AFTER we've returned to MainShell
                          // Use a microtask to ensure we're in the right build context
                          Future.microtask(() {
                            if (mounted) {
                              widget.onNavigateSection!(
                                NavSection.breed,
                                breedInitialTab: 1,
                              );
                            }
                          });
                        }
                      }
                    },
                  ),
                // Back / leave button - 🆕 Hidden in tutorial
                if (!widget.isTutorial)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: WildernessControls(
                          party: widget.party,
                          onLeave: () async {
                            await _db.delete(_db.activeSceneEntry).go();
                            await _spawnService.clearSceneSpawns(
                              widget.sceneId,
                            );

                            if (!mounted) return;

                            VoidPortal.pop(context);
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
