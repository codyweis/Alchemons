// lib/screens/scenes/scene_page.dart
import 'dart:async';
import 'dart:math';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/rift_state.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/arcane_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:alchemons/screens/scenes/rift_threshold.dart';
import 'package:alchemons/services/opening_wilderness_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/background/daynight_filter.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/wilderness/wilderness_controls.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:alchemons/services/cosmic_memory_tutorial_service.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alchemons/models/inventory.dart' show InvKeys;
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/models/wilderness.dart'
    show PartyMember, WildEncounter;
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/widgets/app_icons.dart';

SceneEncounterTables Function(SceneDefinition) _tableBuilderForScene(
  String sceneId, {
  bool isCosmicPlanetEntry = false,
  String? cosmicElementName,
}) {
  if (isCosmicPlanetEntry && cosmicElementName != null) {
    final element = cosmicElementName.trim().toLowerCase();
    final mappedSceneId = switch (element) {
      'fire' || 'lava' => 'volcano',
      'water' || 'ice' || 'steam' || 'mud' || 'poison' => 'swamp',
      'air' || 'lightning' => 'sky',
      'spirit' || 'dark' || 'blood' || 'light' => 'arcane',
      _ => 'valley',
    };
    return _tableBuilderForScene(mappedSceneId);
  }

  return switch (sceneId) {
    'sky' => skyEncounterPools,
    'volcano' => volcanoEncounterPools,
    'swamp' => swampEncounterPools,
    'arcane' => arcaneEncounterPools,
    _ => valleyEncounterPools,
  };
}

// Feature toggle for cosmic ship (temporary testing disable)
const bool kEnableCosmicShip = true;

class ScenePage extends StatefulWidget {
  final SceneDefinition scene;
  final List<PartyMember> party;
  final String sceneId;
  final bool isTutorial;
  final bool isCosmicPlanetEntry;
  final String? cosmicElementName;
  final bool showCosmicDesolationPopup;
  final void Function(NavSection section, {int? breedInitialTab})?
  onNavigateSection;

  const ScenePage({
    super.key,
    required this.scene,
    this.party = const [],
    required this.sceneId,
    this.isTutorial = false,
    this.isCosmicPlanetEntry = false,
    this.cosmicElementName,
    this.showCosmicDesolationPopup = false,
    this.onNavigateSection,
    this.revealReady,
  });

  /// Set true once the scene's game is loaded and attached, so an entry
  /// transition covering this page (VoidPortal.pushThroughGlyphs) reveals a
  /// built scene.
  final ValueNotifier<bool>? revealReady;

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> with TickerProviderStateMixin {
  static final RegExp _poisonSpeciesPattern = RegExp(
    r'^(LET|PIP|MAN|HOR|MSK|WNG|KIN)13$',
  );
  late SceneGame _game;

  late final RevealWhenReady _revealWhenReady;
  late EncounterService _encounters;
  bool _resolverHooked = false;
  bool _tutorialDialogShown = false;

  // Saved references
  late WildernessSpawnService _spawnService;
  late AlchemonsDatabase _db;
  late CreatureCatalog _repo;

  // Encounter state
  bool _inEncounter = false;
  Creature? _wildCreature;
  final Map<String, Creature> _preparedWildBySpawnId = <String, Creature>{};
  bool _showTutorialHighlight = false;
  bool _isCaptureTutorialScene = false;
  bool _riftSpawned = false;
  String? _shipSpawnId;
  bool _cosmicDesolationDialogShown = false;
  bool _usingSessionSceneSpawns = false;
  bool _consumingSceneBatch = false;
  final Map<String, EncounterRoll> _sessionSceneSpawns = {};

  String? _usedSpawnPointId;
  // Ship discovery state
  bool _shipPresent = false;
  String? _shipSceneId;
  bool _shipBeaconPlaced = false;

  late final AnimationController _biomeAmbienceCtrl;
  bool get _isCosmicPlanetMode => widget.isCosmicPlanetEntry;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isCosmicPlanetMode) {
        unawaited(context.read<AudioController>().playPlanetMusic());
      } else {
        unawaited(
          context.read<AudioController>().playWildMusicForScene(widget.sceneId),
        );
      }
    });

    _biomeAmbienceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _game = SceneGame(
      scene: widget.scene,
      transparentBackground: widget.isCosmicPlanetEntry,
    );

    // An entry portal is covering this page: tell it when the scene is
    // built. Flame only attaches its render box once the game has loaded.
    _revealWhenReady = RevealWhenReady(
      widget.revealReady,
      () => mounted && _game.isAttached,
    );

    // 🆕 Enable tutorial mode if this is tutorial
    if (widget.isTutorial) {
      _game.isTutorialMode = true;
    }

    _encounters = EncounterService(
      scene: widget.scene,
      party: widget.party,
      tableBuilder: _tableBuilderForScene(
        widget.sceneId,
        isCosmicPlanetEntry: widget.isCosmicPlanetEntry,
        cosmicElementName: widget.cosmicElementName,
      ),
    );

    _game.attachEncounters(_encounters);

    _game.onStartEncounter = (spawnId, speciesId, hydrated) {
      final incoming = hydrated as Creature;
      final prepared = _preparedWildBySpawnId[spawnId];
      _usedSpawnPointId = spawnId;
      setState(() {
        _inEncounter = true;
        _wildCreature = prepared?.id == incoming.id ? prepared : incoming;
        _showTutorialHighlight = widget.isTutorial || _isCaptureTutorialScene;
      });
      HapticFeedback.mediumImpact();
    };

    _game.onRiftTapped = (faction) => _onRiftTapped(faction);
  }

  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _spawnService = context.read<WildernessSpawnService>();
    _db = context.read<AlchemonsDatabase>();
    _repo = context.read<CreatureCatalog>();

    if (!_initialized) {
      _initialized = true;

      if (_isCosmicPlanetMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _seedTransientEncounterSpawns();
          await _maybeShowCosmicDesolationPopup();
        });
      } else {
        _spawnService.markSceneActive(widget.sceneId);
        _spawnService.addListener(_onSpawnServiceChanged);

        // A state the land is in (the Swamp gone dry) has to be there from
        // the first frame, not appear once the batch is taken in below.
        final land = _spawnService.weatherIn(widget.sceneId)?.kind;
        if (!widget.isTutorial && (land?.settled ?? false)) {
          _game.fieldWeather = land;
        }
        // So does the stage of a field's own cycle (the Volcano still,
        // smoking or erupting); the visit is counted once the scene is open,
        // so the next one finds the next stage. The tutorial's visit is
        // not counted.
        if (!widget.isTutorial) {
          _game.fieldStage = _spawnService.fieldStageFor(
            widget.sceneId,
            widget.scene,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _db
              .into(_db.activeSceneEntry)
              .insertOnConflictUpdate(
                ActiveSceneEntryCompanion.insert(
                  sceneId: widget.sceneId,
                  enteredAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              );

          // Track visited biomes and possibly create the cosmic ship in-world
          await _registerVisitedBiome();
          if (!widget.isTutorial && widget.scene.stages.isNotEmpty) {
            await _spawnService.noteFieldVisit(widget.sceneId);
          }

          final isCaptureTutorialScene =
              await OpeningWildernessService.isCaptureTutorialScene(
                _db.settingsDao,
                widget.sceneId,
              );
          if (mounted) {
            setState(() {
              _isCaptureTutorialScene = isCaptureTutorialScene;
            });
          } else {
            _isCaptureTutorialScene = isCaptureTutorialScene;
          }
          _game.isTutorialMode = widget.isTutorial || _isCaptureTutorialScene;

          // Ensure spawns exist (first visit or empty scene)
          if (!widget.isTutorial && !_isCaptureTutorialScene) {
            await _spawnService.ensureSpawnsForScene(widget.sceneId);
            await _enforcePoisonOnlySpawns();
            if (mounted) _syncSpawnsFromService();
          }

          // Load ship state for rendering (skip for tutorial flow).
          if (!widget.isTutorial && !_isCaptureTutorialScene) {
            await _loadShipState();
            await _syncShipBeaconPlacement();
            await _consumeSceneBatchOnEntry();
          }

          // Keep tutorial scenes pinned to the matching main Let.
          if (widget.isTutorial || _isCaptureTutorialScene) {
            _game.fieldWeather = null;
            if (widget.isTutorial) {
              await _ensureTutorialWildFusion();
            }
            await _ensureTutorialSpawn();
            if (_isCaptureTutorialScene) {
              await _ensureCaptureTutorialHarvester();
            }
            if (mounted) _syncSpawnsFromService();
          }

          if (widget.isTutorial && !_tutorialDialogShown && mounted) {
            _tutorialDialogShown = true;
            await _showFieldTutorialDialog();
          } else if (_isCaptureTutorialScene &&
              !_tutorialDialogShown &&
              mounted) {
            _tutorialDialogShown = true;
            await _showCaptureTutorialDialog();
          }

          if (mounted && !widget.isTutorial && !_isCaptureTutorialScene) {
            await _maybeShowFirstVisitWildernessStoryDialog();
          }

          if (!widget.isTutorial &&
              !_isCaptureTutorialScene &&
              !_riftSpawned &&
              mounted) {
            _riftSpawned = true;
            unawaited(_resolveRift());
          }
        });
      }
    }

    if (_isCosmicPlanetMode) {
      _game.attachEncounters(_encounters);
      _game.syncWildFromEncounters();
    } else {
      _syncSpawnsFromService();
    }
  }

  Future<void> _ensureTutorialWildFusion() async {
    final qty = await _db.inventoryDao.getItemQty(InvKeys.wildFusion);
    if (qty < 1) {
      await _db.inventoryDao.addItemQty(InvKeys.wildFusion, 1);
    }
  }

  Future<void> _maybeShowCosmicDesolationPopup() async {
    if (!_isCosmicPlanetMode ||
        !widget.showCosmicDesolationPopup ||
        _cosmicDesolationDialogShown ||
        !mounted) {
      return;
    }
    _cosmicDesolationDialogShown = true;
    await LandscapeDialog.show(
      context,
      title: 'Trees and valleys are absent in this universe.',
      message:
          'It is nothing but desolation and precariousness. Eventually reality seeps through the mind\'s defense. Why would I create such a world.',
      kind: LandscapeDialogKind.info,
      primaryLabel: 'Continue',
    );
  }

  Future<void> _maybeShowFirstVisitWildernessStoryDialog() async {
    if (_isCosmicPlanetMode || !mounted) return;
    const eligibleScenes = {'valley', 'sky', 'swamp', 'volcano'};
    if (!eligibleScenes.contains(widget.sceneId)) return;

    final settings = _db.settingsDao;
    final truthRevealPending =
        await settings.getSetting('wilderness_truth_reveal_pending_v1') == '1';

    // New saves hear this on their first Field entry after returning from
    // real cosmic space. The planet-revelation flags preserve reachability
    // for saves created before that return marker existed.
    const planetStorySeenKey = 'cosmic_planet_pathway_intro_seen_v1';
    final prefs = await SharedPreferences.getInstance();
    final planetStorySeen =
        (prefs.getBool(planetStorySeenKey) ?? false) ||
        await _db.settingsDao.getSetting('campaign_revelation_seen_v1') == '1';
    if (!truthRevealPending && !planetStorySeen || !mounted) return;

    const key = 'wilderness_post_planet_story_seen';
    final seen = (await settings.getSetting(key)) == '1';
    if (seen || !mounted) return;

    await LandscapeDialog.show(
      context,
      title: 'The Beautiful Lie',
      message:
          'I created this world to hide my shame from the death of Alchemons. '
          'I filled it with a perception of life and called that beauty. '
          'But beauty does not make it true.',
      kind: LandscapeDialogKind.info,
      primaryLabel: 'Continue',
      barrierDismissible: false,
    );
    await settings.setSetting(key, '1');
    await settings.deleteSetting('wilderness_truth_reveal_pending_v1');
  }

  // 🆕 Guarantee a LET spawn for tutorial
  Future<void> _ensureTutorialSpawn() async {
    // Clear any existing spawns first
    await _spawnService.clearSceneSpawns(widget.sceneId);
    final tutorialSpawnId = OpeningWildernessService.tutorialSpawnPointForScene(
      widget.sceneId,
    );
    final speciesId = OpeningWildernessService.mainLetForScene(widget.sceneId);

    final tutorialEncounter = EncounterRoll(
      speciesId: speciesId,
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
            speciesId: speciesId,
            rarity: 'common',
            spawnedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrReplace,
        );

    debugPrint(
      '✨ Tutorial spawn guaranteed: $speciesId at ${widget.sceneId}/$tutorialSpawnId',
    );
  }

  Future<void> _ensureCaptureTutorialHarvester() async {
    final inventoryKey = OpeningWildernessService.harvesterInventoryKeyForScene(
      widget.sceneId,
    );
    final qty = await _db.inventoryDao.getItemQty(inventoryKey);
    if (qty > 0) return;
    await _db.inventoryDao.addItemQty(inventoryKey, 1);
  }

  /// The first Field entry: the portal's story line, then what to do here,
  /// as two pages of one dialog.
  Future<void> _showFieldTutorialDialog() async {
    if (!mounted) return;
    await showStoryDialog(
      context,
      icon: AppIcons.auto_awesome,
      primaryLabel: 'BEGIN',
      beats: const [
        StoryBeat(
          title: 'Ancient Portal',
          message: '',
          voice:
              'This portal was created eons ago. Is this false perception? '
              'Beauty obstructs reality.',
        ),
        StoryBeat(
          title: 'Alchemy is Power',
          message:
              'Tap the wild Alchemon, then choose one of yours to fuse with it. '
              'Wild Alchemons are stronger, so what you make from them starts '
              'strong.',
        ),
      ],
    );
  }

  Future<void> _showCaptureTutorialDialog() async {
    await LandscapeDialog.show(
      context,
      title: 'Harvester Trial',
      message:
          'This wild Alchemon must be harvested, not fused. Open the harvester panel and use the issued device to capture the specimen.',
      kind: LandscapeDialogKind.info,
      icon: AppIcons.catching_pokemon_rounded,
      primaryLabel: 'Begin Capture',
      barrierDismissible: false,
    );
  }

  /// A rule of the game, not a story beat — so it is told the way every other
  /// rule is, and it no longer holds the end of the capture tutorial behind an
  /// acknowledgement.
  void _announcePureWild() {
    showGameSnack(
      context,
      'Wild Alchemons are pure — harvest for a pure replica, or fuse for something new',
      icon: AppIcons.auto_awesome_rounded,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    _revealWhenReady.dispose();
    try {
      if (_isCosmicPlanetMode) {
        unawaited(
          context.read<AudioController>().playCosmicExplorationMusic(
            cycle: false,
          ),
        );
      } else {
        unawaited(context.read<AudioController>().playHomeMusic());
      }
    } catch (_) {}

    if (_isCosmicPlanetMode) {
      _biomeAmbienceCtrl.dispose();
      super.dispose();
      return;
    }

    _biomeAmbienceCtrl.dispose();
    _spawnService.markSceneInactive(widget.sceneId);
    _spawnService.removeListener(_onSpawnServiceChanged);

    // Leaving one of the core biomes is what paces the cosmic memory. Counted
    // on teardown rather than on a particular exit button, because a scene can
    // be left several ways and all of them mean the same thing.
    if (OpeningWildernessService.coreScenes.contains(widget.sceneId)) {
      unawaited(
        CosmicMemoryTutorialService.recordBiomeExitIfEligible(_db.settingsDao),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _db.delete(_db.activeSceneEntry).go();
      } catch (_) {}
    });

    super.dispose();
  }

  void _onSpawnServiceChanged() {
    if (_isCosmicPlanetMode) return;
    if (_usingSessionSceneSpawns || _consumingSceneBatch) return;
    _syncSpawnsFromService();
  }

  void _syncSpawnsFromService() {
    if (_isCosmicPlanetMode) return;
    _encounters.clearSpawns();

    for (final sp in widget.scene.spawnPoints) {
      if (_shipSpawnId != null && sp.id == _shipSpawnId) continue;
      final enc = _usingSessionSceneSpawns
          ? _sessionSceneSpawns[sp.id]
          : _spawnService.getSpawnAt(widget.sceneId, sp.id);
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

  Future<void> _consumeSceneBatchOnEntry() async {
    if (_isCosmicPlanetMode || widget.isTutorial || _usingSessionSceneSpawns) {
      return;
    }

    _sessionSceneSpawns.clear();
    for (final sp in widget.scene.spawnPoints) {
      if (_shipSpawnId != null && sp.id == _shipSpawnId) continue;
      final enc = _spawnService.getSpawnAt(widget.sceneId, sp.id);
      if (enc != null) {
        _sessionSceneSpawns[sp.id] = enc;
      }
    }

    // Weather belongs to the batch it came with: it is over this visit, and
    // gone with the batch once the visit is over. The first clear visit
    // after a rainy one finds what the rain left (the Valley's rainbow).
    // Nothing announces either; the field shows it.
    final weather = _spawnService.weatherIn(widget.sceneId);
    _game.fieldWeather = weather?.kind;
    if (weather != null) {
      await _spawnService.noteWeatherVisit(widget.sceneId);
    } else {
      _game.fieldAftermath =
          await _spawnService.takeAftermath(widget.sceneId) != null;
    }

    // Scene uses local transient batch after entry. Persisted batch is consumed.
    _usingSessionSceneSpawns = true;
    _syncSpawnsFromService();

    _consumingSceneBatch = true;
    try {
      await _spawnService.clearSceneSpawns(widget.sceneId);
    } finally {
      _consumingSceneBatch = false;
    }
  }

  void _seedTransientEncounterSpawns() {
    _encounters.clearSpawns();

    final spawnPoints = List.of(widget.scene.spawnPoints);
    if (spawnPoints.isEmpty) return;

    if (_isCosmicPlanetMode && widget.cosmicElementName != null) {
      final element = widget.cosmicElementName!.trim();
      final candidates = _repo
          .byType(element)
          .where((c) => c.mutationFamily != 'Mystic')
          .toList();
      if (candidates.isEmpty) {
        debugPrint('⚠️ No cosmic candidates for element: $element');
        _game.attachEncounters(_encounters);
        _game.syncWildFromEncounters();
        return;
      }

      final rng = Random();
      final byRarity = {
        for (final r in EncounterRarity.values) r: <Creature>[],
      };
      for (final creature in candidates) {
        byRarity[_encounterRarityForCreature(creature.rarity)]!.add(creature);
      }

      // Keep cosmic encounters closer to center to reduce excessive panning.
      final centeredPoints = List.of(spawnPoints)
        ..sort(
          (a, b) => (a.normalizedPos.dx - 0.5).abs().compareTo(
            (b.normalizedPos.dx - 0.5).abs(),
          ),
        );
      final spawnPool =
          centeredPoints.take(min(5, centeredPoints.length)).toList()
            ..shuffle(rng);
      final targetCount = 1 + rng.nextInt(min(5, spawnPool.length));
      final chosenPoints = <SpawnPoint>[];

      // Guarantee at least one spawn in the initial no-pan viewport.
      final starterCandidates =
          spawnPoints.where((sp) => sp.normalizedPos.dx <= 0.52).toList()..sort(
            (a, b) => (a.normalizedPos.dx - 0.38).abs().compareTo(
              (b.normalizedPos.dx - 0.38).abs(),
            ),
          );
      if (starterCandidates.isNotEmpty) {
        chosenPoints.add(starterCandidates.first);
      }

      for (final sp in spawnPool) {
        if (chosenPoints.length >= targetCount) break;
        if (chosenPoints.any((existing) => existing.id == sp.id)) continue;
        chosenPoints.add(sp);
      }

      for (final sp in chosenPoints) {
        final creature = _pickCosmicCreatureByRarity(byRarity, rng);
        if (creature == null) continue;
        // Only a creature that can float is put in the open air.
        if (sp.aloft && !speciesCanFloat(creature.id)) continue;
        final rarity = _encounterRarityForCreature(creature.rarity);
        _encounters.forceSpawnAt(
          sp.id,
          WildEncounter(
            wildBaseId: creature.id,
            baseBreedChance: breedChanceForRarity(rarity),
            rarity: rarity.label,
          ),
        );
      }
    } else {
      for (final sp in spawnPoints) {
        // A point there only in some weather is not there in this one.
        if (sp.onlyIn != null) continue;
        final roll = _encounters.roll(spawnId: sp.id);
        _encounters.forceSpawnAt(
          sp.id,
          WildEncounter(
            wildBaseId: roll.speciesId,
            baseBreedChance: breedChanceForRarity(roll.rarity),
            rarity: roll.rarity.name,
          ),
        );
      }
    }

    _game.attachEncounters(_encounters);
    _game.syncWildFromEncounters();
  }

  EncounterRarity _encounterRarityForCreature(String rarity) {
    return switch (rarity.trim().toLowerCase()) {
      'common' => EncounterRarity.common,
      'uncommon' => EncounterRarity.uncommon,
      'rare' => EncounterRarity.rare,
      'mythic' || 'legendary' || 'variant' => EncounterRarity.legendary,
      _ => EncounterRarity.common,
    };
  }

  Creature? _pickCosmicCreatureByRarity(
    Map<EncounterRarity, List<Creature>> byRarity,
    Random rng,
  ) {
    // Target distribution:
    // legendary 1%, rare 10%, uncommon 30%, common 59%.
    final roll = rng.nextDouble();
    final target = switch (roll) {
      < 0.01 => EncounterRarity.legendary,
      < 0.11 => EncounterRarity.rare,
      < 0.41 => EncounterRarity.uncommon,
      _ => EncounterRarity.common,
    };

    final fallbackOrder = switch (target) {
      EncounterRarity.legendary => const [
        EncounterRarity.legendary,
        EncounterRarity.rare,
        EncounterRarity.uncommon,
        EncounterRarity.common,
      ],
      EncounterRarity.rare => const [
        EncounterRarity.rare,
        EncounterRarity.uncommon,
        EncounterRarity.common,
        EncounterRarity.legendary,
      ],
      EncounterRarity.uncommon => const [
        EncounterRarity.uncommon,
        EncounterRarity.common,
        EncounterRarity.rare,
        EncounterRarity.legendary,
      ],
      EncounterRarity.common => const [
        EncounterRarity.common,
        EncounterRarity.uncommon,
        EncounterRarity.rare,
        EncounterRarity.legendary,
      ],
    };

    for (final rarity in fallbackOrder) {
      final bucket = byRarity[rarity];
      if (bucket == null || bucket.isEmpty) continue;
      return bucket[rng.nextInt(bucket.length)];
    }
    return null;
  }

  void _removeTransientSpawn(String spawnId) {
    _preparedWildBySpawnId.remove(spawnId);
    _sessionSceneSpawns.remove(spawnId);
    final remaining = _encounters.spawns
        .where((s) => s.spawnPointId != spawnId)
        .toList();
    _encounters.clearSpawns();
    for (final s in remaining) {
      _encounters.forceSpawnAt(
        s.spawnPointId,
        WildEncounter(
          wildBaseId: s.speciesId,
          baseBreedChance: breedChanceForRarity(s.rarity),
          rarity: s.rarity.name,
        ),
      );
    }
    _game.attachEncounters(_encounters);
    _game.syncWildFromEncounters();
  }

  Future<void> _enforcePoisonOnlySpawns() async {
    if (widget.sceneId != 'poison') return;
    final ids = _spawnService.getActiveSpawnPoints(widget.sceneId);
    var invalidFound = false;
    final pointsById = {for (final sp in widget.scene.spawnPoints) sp.id: sp};
    for (final id in ids) {
      final enc = _spawnService.getSpawnAt(widget.sceneId, id);
      if (enc == null) continue;
      final point = pointsById[id];
      final outOfBand = point != null && point.normalizedPos.dy > 0.38;
      if (!_poisonSpeciesPattern.hasMatch(enc.speciesId) || outOfBand) {
        invalidFound = true;
        break;
      }
    }
    if (!invalidFound) return;

    await _spawnService.clearSceneSpawns(widget.sceneId);
    await _spawnService.ensureSpawnsForScene(widget.sceneId);
  }

  // Track which biomes the player has visited and spawn the cosmic ship
  Future<void> _registerVisitedBiome() async {
    // feature flag check — proceed only if enabled
    if (!kEnableCosmicShip) return;
    try {
      final settings = _db.settingsDao;
      final raw = await settings.getSetting('visited_biomes') ?? '';
      final parts = raw.isEmpty
          ? <String>[]
          : raw.split(',').where((s) => s.isNotEmpty).toList();
      final set = parts.toSet();
      const allowed = {'volcano', 'valley', 'sky', 'swamp'};
      if (!allowed.contains(widget.sceneId)) return;
      if (!set.contains(widget.sceneId)) {
        set.add(widget.sceneId);
        await settings.setSetting('visited_biomes', set.join(','));
      }

      // All four seen and the ship not yet claimed: it is owed to the Valley.
      final visitedCount = set.where((s) => allowed.contains(s)).length;
      final existingShip = await settings.getSetting('cosmic_ship_scene');
      final claimed = (await settings.getSetting('cosmic_ship_claimed')) == '1';
      final armed =
          await settings.getSetting(OpeningWildernessService.shipArmedKey) ==
          '1';
      if (existingShip != null && existingShip != 'valley' && !claimed) {
        await settings.setSetting('cosmic_ship_scene', 'valley');
      }
      if (visitedCount >= 4 && existingShip == null && !claimed && !armed) {
        // It comes down with the Valley's next batch of wild, and nothing
        // announces it: whoever goes into the Valley finds it there. The
        // spawn service lands it; an empty Valley entered right now is
        // filled on the way in, so that is a batch too.
        //
        // A Valley already holding wild is lit on the map already, so the
        // ship joins those rather than waiting for them to be cleared.
        final valleyWaiting =
            widget.sceneId != 'valley' &&
            _spawnService.getSceneSpawnCount('valley') > 0;
        if (valleyWaiting) {
          await settings.setSetting('cosmic_ship_scene', 'valley');
          await settings.setSetting('cosmic_ship_arrival_pending', '1');
        } else {
          await settings.setSetting(
            OpeningWildernessService.shipArmedKey,
            '1',
          );
        }
      }
    } catch (e) {
      debugPrint('Error registering visited biome: $e');
    }
  }

  Future<void> _loadShipState() async {
    try {
      final settings = _db.settingsDao;
      var scene = await settings.getSetting('cosmic_ship_scene');
      final claimed = (await settings.getSetting('cosmic_ship_claimed')) == '1';
      if (scene != null && scene != 'valley' && !claimed) {
        await settings.setSetting('cosmic_ship_scene', 'valley');
        scene = 'valley';
      }
      if (mounted) {
        setState(() {
          _shipSceneId = scene;
          _shipPresent = (scene != null && !claimed);
        });
        await _syncShipBeaconPlacement();
      }
    } catch (e) {
      debugPrint('Error loading ship state: $e');
    }
  }

  Future<void> _onShipTapped() async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    _game.shake(duration: const Duration(milliseconds: 600), amplitude: 6);

    await LandscapeDialog.show(
      context,
      title: 'The Cosmic Ship',
      message:
          '"Recognizing that the world is but an illusion, does not act as if it were real, so he escapes suffering."',
      kind: LandscapeDialogKind.success,
      icon: AppIcons.rocket_launch_rounded,
      primaryLabel: 'Claim',
      barrierDismissible: true,
    );

    try {
      final settings = _db.settingsDao;
      await settings.setSetting('cosmic_ship_claimed', '1');
      await settings.setSetting('cosmic_ship_unlocked', '1');
      await settings.setSetting('cosmic_ship_home_anim_pending', '1');
      // remove scene placement
      await settings.deleteSetting('cosmic_ship_scene');
    } catch (e) {
      debugPrint('Error claiming ship: $e');
    }

    if (mounted) {
      setState(() {
        _shipPresent = false;
        _shipSceneId = null;
        _shipBeaconPlaced = false;
      });
      // It takes off and leaves with its new pilot; its spot in the meadow
      // stays clear until it has gone.
      HapticFeedback.mediumImpact();
      _game.shake(duration: const Duration(milliseconds: 1400), amplitude: 3);
      _game.launchShipBeacon(
        onGone: () {
          if (mounted) setState(() => _shipSpawnId = null);
        },
      );
    }
  }

  String? _pickShipSpawnId() {
    if (widget.scene.spawnPoints.isEmpty) return null;
    if (widget.sceneId == 'valley') {
      for (final sp in widget.scene.spawnPoints) {
        if (sp.id == 'SP_valley_06') return sp.id;
      }
    }
    final points = List.of(widget.scene.spawnPoints)
      ..sort(
        (a, b) => (a.normalizedPos.dx - 0.5).abs().compareTo(
          (b.normalizedPos.dx - 0.5).abs(),
        ),
      );
    return points.first.id;
  }

  Future<void> _syncShipBeaconPlacement() async {
    if (_isCosmicPlanetMode) return;
    final shouldShow =
        _shipPresent &&
        _shipSceneId == widget.sceneId &&
        widget.sceneId == 'valley';
    if (!shouldShow) {
      _shipSpawnId = null;
      _shipBeaconPlaced = false;
      _game.clearShipBeacon();
      return;
    }

    // Already placed this session — don't clobber it (and avoid replaying
    // the crash-landing cinematic on a redundant sync call).
    if (_shipBeaconPlaced) return;

    final spawnId = _pickShipSpawnId();
    if (spawnId == null) return;
    _shipSpawnId = spawnId;

    // Reserve this spawn point for the ship beacon.
    if (_usingSessionSceneSpawns) {
      _sessionSceneSpawns.remove(spawnId);
    } else {
      await _spawnService.removeSpawn(widget.sceneId, spawnId);
    }
    _syncSpawnsFromService();

    // Consume the one-shot arrival flag — if set, the ship crash-lands.
    final settings = _db.settingsDao;
    final flyIn =
        (await settings.getSetting('cosmic_ship_arrival_pending')) == '1';
    if (flyIn) {
      await settings.deleteSetting('cosmic_ship_arrival_pending');
    }

    _game.placeShipBeaconAt(
      spawnId,
      // _onShipTapped already fires its own heavier haptic.
      onTap: _onShipTapped,
      flyIn: flyIn,
      onBurn: _onShipBurn,
      onCrashLanded: _onShipCrashLanded,
    );
    _shipBeaconPlaced = true;
  }

  /// The ship's engines open up to brake over the meadow: a low rumble.
  void _onShipBurn() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _game.shake(duration: const Duration(milliseconds: 1100), amplitude: 3);
  }

  void _onShipCrashLanded() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    // Kept modest: the camera has only just come round to it.
    _game.shake(duration: const Duration(milliseconds: 600), amplitude: 10);
  }

  void _showShipBeckoning() {
    HapticFeedback.mediumImpact();
    _game.shake(duration: const Duration(milliseconds: 320), amplitude: 5);
    LandscapeDialog.show(
      context,
      title: 'The Cosmic Ship',
      message: 'The ship is beckoning.',
      kind: LandscapeDialogKind.warning,
      icon: AppIcons.rocket_launch_rounded,
      primaryLabel: 'Stay',
      barrierDismissible: true,
    );
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

  // ── Rift persistence ───────────────────────────────────────────────────────
  //
  // A rift used to live only in the Flame game, so leaving the scene destroyed
  // it. Entering one needs a faction portal key you may not hold, which made
  // the correct response — go buy the key — the thing that lost you the rift.
  // It now survives for kRiftWindow so it can be returned to.

  static const String _riftSettingKey = 'wild_rift_pending_v1';

  Future<PendingRift?> _loadPendingRift() async {
    final db = context.read<AlchemonsDatabase>();
    return PendingRift.deserialise(
      await db.settingsDao.getSetting(_riftSettingKey),
    );
  }

  Future<void> _savePendingRift(PendingRift? rift) async {
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.setSetting(_riftSettingKey, rift?.serialise() ?? '');
  }

  /// Decide whether this scene shows a rift: restore one pending here, roll for
  /// a new one if none is pending anywhere, or do nothing while one waits in
  /// another scene (only one rift is open at a time).
  Future<void> _resolveRift() async {
    if (!mounted) return;
    final pending = await _loadPendingRift();
    if (!mounted) return;

    final action = riftActionForScene(
      pending: pending,
      sceneId: widget.sceneId,
      nowUtc: DateTime.now().toUtc(),
    );

    switch (action) {
      case RiftSceneAction.none:
        return;

      case RiftSceneAction.restore:
        final faction = RiftFaction.values.firstWhere(
          (f) => f.name == pending!.factionName,
          orElse: () => RiftFaction.values.first,
        );
        _game.spawnRift(faction);

      case RiftSceneAction.roll:
        // An expired rift also lands here, so clear the stale record before
        // rolling — otherwise the slot never frees up.
        if (pending != null) await _savePendingRift(null);
        final faction = _game.rollRiftFaction(widget.sceneId);
        if (faction == null || !mounted) return;
        _game.spawnRift(faction);
        await _savePendingRift(
          PendingRift(
            factionName: faction.name,
            sceneId: widget.sceneId,
            spawnedUtc: DateTime.now().toUtc(),
          ),
        );
    }
  }

  /// Consume the rift: it is gone from the world and from storage, which frees
  /// the slot for the next roll.
  Future<void> _consumeRift() async {
    _game.clearRift();
    await _savePendingRift(null);
  }

  // ── Rift portal ─────────────────────────────────────────────────────────────

  Future<void> _onRiftTapped(RiftFaction faction) async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final pending = await _loadPendingRift();
    if (!mounted) return;
    // The rift waits for a key to be fetched; say for how long.
    final closesIn =
        pending != null &&
            pending.factionName == faction.name &&
            pending.sceneId == widget.sceneId
        ? pending.remainingLabel(DateTime.now().toUtc())
        : null;
    await showRiftThreshold(
      context,
      faction: faction,
      closesIn: closesIn,
      onEnter: (threshold) => _enterRift(threshold, faction),
    );
  }

  /// The key has turned and the threshold has fallen to black: the glyph
  /// portal takes it into the rift, and leaving comes straight back here.
  Future<void> _enterRift(
    BuildContext thresholdContext,
    RiftFaction faction,
  ) async {
    unawaited(context.read<AudioController>().playPortalMusic());
    // Don't clear the rift yet — only clear it if the player successfully
    // breeds or catches inside the void.
    final success = await enterRift(
      thresholdContext,
      faction: faction,
      party: widget.party,
      // The scene behind is landscape.
      returnTo: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
    if (success == true) {
      await _consumeRift();
    }
    if (!mounted) return;
    if (_isCosmicPlanetMode) {
      unawaited(context.read<AudioController>().playPlanetMusic());
    } else {
      unawaited(
        context.read<AudioController>().playWildMusicForScene(widget.sceneId),
      );
    }
  }

  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;

  List<Color>? _particlePaletteForScene() {
    if (widget.isCosmicPlanetEntry && widget.cosmicElementName != null) {
      return _particlePaletteForElement(widget.cosmicElementName!);
    }

    return switch (widget.sceneId) {
      'poison' => const [
        Color(0xFFFF4FA2),
        Color(0xFFE040FB),
        Color(0xFFB388FF),
        Color(0xFF8E24AA),
        Color(0xFF3A0A3F),
      ],
      'arcane' => const [
        Color(0xFF6A1B9A),
        Color(0xFF3949AB),
        Color(0xFF00BCD4),
        Color(0xFF311B92),
      ],
      _ => null,
    };
  }

  List<Color> _particlePaletteForElement(String element) {
    return switch (element) {
      'Fire' => const [
        Color(0xFFFF7043),
        Color(0xFFFFAB40),
        Color(0xFFFF3D00),
        Color(0xFF6D1B00),
      ],
      'Lava' => const [
        Color(0xFFFF8A65),
        Color(0xFFFF6F00),
        Color(0xFFFFAB00),
        Color(0xFF4E1200),
      ],
      'Lightning' => const [
        Color(0xFFFFFF8D),
        Color(0xFFFFF176),
        Color(0xFFB3E5FC),
        Color(0xFF4A4A22),
      ],
      'Water' => const [
        Color(0xFF64B5F6),
        Color(0xFF42A5F5),
        Color(0xFF90CAF9),
        Color(0xFF0D2F5C),
      ],
      'Ice' => const [
        Color(0xFF80DEEA),
        Color(0xFFB3E5FC),
        Color(0xFFE1F5FE),
        Color(0xFF1D3C47),
      ],
      'Steam' => const [
        Color(0xFFCFD8DC),
        Color(0xFFB0BEC5),
        Color(0xFFECEFF1),
        Color(0xFF37474F),
      ],
      'Earth' => const [
        Color(0xFFA1887F),
        Color(0xFF8D6E63),
        Color(0xFFD7CCC8),
        Color(0xFF3E2723),
      ],
      'Mud' => const [
        Color(0xFF8D6E63),
        Color(0xFF795548),
        Color(0xFFBCAAA4),
        Color(0xFF2C1B16),
      ],
      'Dust' => const [
        Color(0xFFFFE0B2),
        Color(0xFFFFCC80),
        Color(0xFFFFF3E0),
        Color(0xFF5D4037),
      ],
      'Crystal' => const [
        Color(0xFF80CBC4),
        Color(0xFF26A69A),
        Color(0xFFB2DFDB),
        Color(0xFF004D40),
      ],
      'Air' => const [
        Color(0xFFB3E5FC),
        Color(0xFF81D4FA),
        Color(0xFFE1F5FE),
        Color(0xFF1A3B4A),
      ],
      'Plant' => const [
        Color(0xFFA5D6A7),
        Color(0xFF66BB6A),
        Color(0xFFC8E6C9),
        Color(0xFF1B5E20),
      ],
      'Poison' => const [
        Color(0xFFFF4FA2),
        Color(0xFFE040FB),
        Color(0xFFB388FF),
        Color(0xFF3A0A3F),
      ],
      'Spirit' => const [
        Color(0xFF9FA8DA),
        Color(0xFF7986CB),
        Color(0xFFC5CAE9),
        Color(0xFF1A237E),
      ],
      'Dark' => const [
        Color(0xFF9575CD),
        Color(0xFF673AB7),
        Color(0xFFB39DDB),
        Color(0xFF311B92),
      ],
      'Light' => const [
        Color(0xFFFFF59D),
        Color(0xFFFFF176),
        Color(0xFFFFE082),
        Color(0xFF5D4A00),
      ],
      'Blood' => const [
        Color(0xFFEF9A9A),
        Color(0xFFE57373),
        Color(0xFFFFCDD2),
        Color(0xFF7F1D1D),
      ],
      _ => const [
        Color(0xFF9FA8DA),
        Color(0xFF90CAF9),
        Color(0xFFC5CAE9),
        Color(0xFF1A237E),
      ],
    };
  }

  Widget? _elementalBackdropForScene() {
    if (widget.isCosmicPlanetEntry) {
      final cosmicElement = widget.cosmicElementName;
      return AnimatedBuilder(
        animation: _biomeAmbienceCtrl,
        builder: (_, __) => IgnorePointer(
          child: CustomPaint(
            painter: (cosmicElement ?? '') == 'Poison'
                ? _PoisonBiomePainter(phase: _biomeAmbienceCtrl.value)
                : _CosmicElementBiomePainter(
                    element: cosmicElement,
                    phase: _biomeAmbienceCtrl.value,
                  ),
          ),
        ),
      );
    }

    if (widget.sceneId == 'poison') {
      return AnimatedBuilder(
        animation: _biomeAmbienceCtrl,
        builder: (_, __) => IgnorePointer(
          child: CustomPaint(
            painter: _PoisonBiomePainter(phase: _biomeAmbienceCtrl.value),
          ),
        ),
      );
    }

    // A field drawn in code paints its own void.
    if (widget.sceneId == 'arcane' && widget.scene.art == null) {
      return IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0A0720),
                const Color(0xFF140028),
                const Color(0xFF020204),
              ],
            ),
          ),
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final bool night = isNight(now);
    final sceneBackdrop = _elementalBackdropForScene();

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
                if (sceneBackdrop != null)
                  Positioned.fill(child: sceneBackdrop),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final game = SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: GameWidget(game: _game),
                    );

                    // A field drawn in code lights its own night, and the
                    // filter costs two offscreen passes even when idle.
                    if (widget.scene.art != null) return game;
                    return DayNightFilter(
                      intensity: night ? 1.0 : 0.0,
                      tint: const Color(0xFF081028),
                      minLuma: 0.45,
                      child: game,
                    );
                  },
                ),
                // A field drawn in code has its own motes.
                if (!(widget.sceneId == 'arcane' && _inEncounter) &&
                    widget.scene.art == null)
                  IgnorePointer(
                    child: AlchemicalParticleBackground(
                      opacity: switch (widget.sceneId) {
                        'poison' => widget.isCosmicPlanetEntry ? 0.35 : 0.45,
                        _ when widget.isCosmicPlanetEntry => 0.55,
                        _ => 0.9,
                      },
                      densityMultiplier: switch (widget.sceneId) {
                        'arcane' => 0.5,
                        _ => 1.0,
                      },
                      backgroundColor: Colors.transparent,
                      colors: _particlePaletteForScene(),
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
                    onWildCreaturePrepared: (prepared) {
                      final spawnId = _usedSpawnPointId;
                      if (spawnId == null) return;
                      _preparedWildBySpawnId[spawnId] = prepared;
                      _wildCreature = prepared;
                    },
                    party: widget.party,
                    // A planet surface belongs to space; only the
                    // wilderness's own fields mutate a fusion.
                    fieldMutations: !_isCosmicPlanetMode,
                    highlightPartyHUD: _showTutorialHighlight,
                    isTutorial: widget.isTutorial,
                    isCaptureTutorial: _isCaptureTutorialScene,
                    // Keep the encounter Map action as the single cosmic exit.
                    showMapAction: true,
                    onPreRollShake: () {
                      _game.shake(
                        duration: const Duration(milliseconds: 800),
                        amplitude: 14,
                      );
                    },
                    // The harvest belongs to the scene: it plays on the wild
                    // component that is already standing there.
                    onHarvestInScene: (accent, task, profile) =>
                        _game.playHarvestOnEncounter(
                          accent: accent,
                          task: task,
                          profile: profile,
                        ),
                    onFusionInScene: (party, wild) =>
                        _game.playFusionOnEncounter(),
                    // Both turn to grains through the wait for the verdict,
                    // and run back into themselves if it goes against them.
                    onFusionCalibrating: _game.startFusionCalibration,
                    onFusionFailedInScene: (party, wild) =>
                        _game.recoilFusion(),
                    onPartyCreatureSelected: _onPartyCreatureSelected,
                    onClosedWithResult: (success) async {
                      final id = _usedSpawnPointId;

                      if (success && id != null) {
                        _game.clearWildAt(id);
                        _removeTransientSpawn(id);
                        if (!_isCosmicPlanetMode && !_usingSessionSceneSpawns) {
                          await _spawnService.removeSpawn(widget.sceneId, id);
                        }
                        _usedSpawnPointId = null;
                        _exitEncounter(clearSpawnId: id);
                        _syncSpawnsFromService();

                        if (_isCaptureTutorialScene && mounted) {
                          _announcePureWild();
                          if (!mounted) return;
                          await OpeningWildernessService.completeCaptureTutorial(
                            _db.settingsDao,
                          );
                          for (final sceneId
                              in OpeningWildernessService.coreScenes) {
                            await _spawnService.scheduleNextSpawnTime(
                              sceneId,
                              force: true,
                            );
                          }
                          // Except the one the hunt is about to send them
                          // to. Putting a timer on every biome included the
                          // next stop, so the tutorial ended by pointing at
                          // a region and making them wait for it — the
                          // queue advancing already spawns the one after,
                          // and this is the same courtesy for the first.
                          final firstStop =
                              await OpeningWildernessService.openShipHuntScene(
                                _db.settingsDao,
                              );
                          if (firstStop != null) {
                            await _spawnService.scheduleNextSpawnTime(
                              firstStop,
                              windowMin:
                                  OpeningWildernessService.huntSpawnDelay,
                              windowMax:
                                  OpeningWildernessService.huntSpawnDelay,
                              force: true,
                            );
                          }
                          if (!context.mounted) return;
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                          if (widget.onNavigateSection != null) {
                            Future.microtask(() {
                              if (mounted) {
                                widget.onNavigateSection!(
                                  NavSection.breed,
                                  breedInitialTab: 1,
                                );
                              }
                            });
                          }
                          return;
                        }

                        // Handle the first wilderness fusion tutorial after everything
                        if (!widget.isTutorial || !mounted) return;

                        // The encounter already said where the new
                        // specimen went; a second snack here repeated it.
                        final settingsDao = _db.settingsDao;
                        await OpeningWildernessService.advanceToCaptureTutorial(
                          settingsDao,
                          firstScene: widget.sceneId,
                        );
                        await settingsDao.setFieldTutorialCompleted();
                        await settingsDao.setNavLocked(false);

                        // Pop back with a result indicating tutorial completion
                        if (!context.mounted) return;
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
                      } else {
                        _exitEncounter();
                      }
                    },
                  ),
                // Back / leave button - hidden in tutorial and cosmic planets.
                if (!widget.isTutorial &&
                    !_isCaptureTutorialScene &&
                    !_isCosmicPlanetMode)
                  Positioned.fill(
                    child: WildernessControls(
                      party: widget.party,
                      leaveTooltip: 'Leave Scene',
                      leaveDialogTitle: 'LEAVE SCENE?',
                      leaveDialogBody: 'Any active encounters will be lost.',
                      leaveConfirmLabel: 'LEAVE',
                      leaveCancelLabel: 'CANCEL',
                      canLeave: () =>
                          !(_shipPresent && _shipSceneId == widget.sceneId),
                      onLeaveBlocked: _showShipBeckoning,
                      onLeave: () async {
                        if (!_isCosmicPlanetMode) {
                          await _db.delete(_db.activeSceneEntry).go();
                        }

                        if (!context.mounted) return;

                        VoidPortal.pop(context);
                      },
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

class _PoisonBiomePainter extends CustomPainter {
  final double phase;

  const _PoisonBiomePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2A0034), Color(0xFF130019), Color(0xFF050006)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final fogPulseA = 0.85 + 0.25 * sin(phase * pi * 2);
    final fogPulseB = 0.82 + 0.22 * sin(phase * pi * 2 + 1.8);

    final hazeA = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.28, -0.22),
        radius: 1.0,
        colors: [
          const Color(0xFFFF4FA2).withValues(alpha: 0.26 * fogPulseA),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, hazeA);

    final hazeB = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.45, -0.05),
        radius: 1.15,
        colors: [
          const Color(0xFFD65BFF).withValues(alpha: 0.18 * fogPulseB),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, hazeB);

    final swirlPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final center = Offset(size.width * 0.5, size.height * 0.78);
    for (var i = 0; i < 6; i++) {
      final r = size.width * (0.18 + i * 0.055);
      final arcRect = Rect.fromCircle(center: center, radius: r);
      swirlPaint
        ..strokeWidth = 1.5 + i * 0.25
        ..color = Color.lerp(
          const Color(0xFFFF65B5),
          const Color(0xFF8524A8),
          i / 6,
        )!.withValues(alpha: 0.16 - i * 0.02);
      canvas.drawArc(arcRect, pi * 0.98, pi * 0.55, false, swirlPaint);
    }

    final sporePaint = Paint()..style = PaintingStyle.fill;
    const spores = [
      (0.16, 0.16, 18.0, 0.22),
      (0.30, 0.22, 12.0, 0.20),
      (0.76, 0.24, 15.0, 0.18),
      (0.62, 0.14, 22.0, 0.16),
      (0.84, 0.34, 10.0, 0.15),
      (0.20, 0.40, 14.0, 0.14),
      (0.52, 0.30, 13.0, 0.14),
      (0.42, 0.12, 8.0, 0.16),
    ];
    for (var i = 0; i < spores.length; i++) {
      final (nx, ny, radius, alpha) = spores[i];
      final localPhase = phase * pi * 2 + i * 0.9;
      final driftX = sin(localPhase) * (5 + i * 0.6);
      final driftY = cos(localPhase * 0.75) * (4 + i * 0.5);
      final p = Offset(size.width * nx + driftX, size.height * ny + driftY);
      final twinkle = 0.8 + 0.35 * sin(localPhase * 1.4);
      final grad = RadialGradient(
        colors: [
          const Color(0xFFFF8BC7).withValues(alpha: alpha * twinkle),
          const Color(0xFFA137C8).withValues(alpha: alpha * 0.55 * twinkle),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: p, radius: radius * 2.5));
      sporePaint.shader = grad;
      canvas.drawCircle(p, radius * 2.5, sporePaint);
    }

    final mistPath = Path()
      ..moveTo(0, size.height * 0.70)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.62,
        size.width * 0.34,
        size.height * 0.69,
      )
      ..quadraticBezierTo(
        size.width * 0.53,
        size.height * 0.76,
        size.width * 0.72,
        size.height * 0.66,
      )
      ..quadraticBezierTo(
        size.width * 0.86,
        size.height * 0.60,
        size.width,
        size.height * 0.68,
      )
      ..lineTo(size.width, size.height * 0.90)
      ..lineTo(0, size.height * 0.90)
      ..close();
    final mistPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFEF66B9).withValues(alpha: 0.19 + 0.06 * fogPulseA),
          const Color(0xFF5A146B).withValues(alpha: 0.08 + 0.04 * fogPulseB),
          Colors.transparent,
        ],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(mistPath, mistPaint);

    final groundCenter = Offset(size.width * 0.5, size.height * 1.16);
    final groundRx = size.width * 0.88;
    final groundRy = size.height * 0.48;
    final groundRect = Rect.fromCenter(
      center: groundCenter,
      width: groundRx * 2,
      height: groundRy * 2,
    );
    final groundPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.62),
        radius: 1.0,
        colors: [
          const Color(0xFFFF7EC7).withValues(alpha: 0.56),
          const Color(0xFFC045BB).withValues(alpha: 0.62),
          const Color(0xFF5E1E71).withValues(alpha: 0.90),
          const Color(0xFF1B051E),
        ],
        stops: const [0.0, 0.26, 0.58, 1.0],
      ).createShader(groundRect);
    canvas.drawOval(groundRect, groundPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, size.width * 0.005)
      ..color = const Color(0xFFFFA6DF).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final rimRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.92),
      width: size.width * 0.96,
      height: size.height * 0.38,
    );
    canvas.drawArc(rimRect, pi * 1.02, pi * 0.96, false, rimPaint);

    final foregroundShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF1A0420).withValues(alpha: 0.35),
          const Color(0xFF060007).withValues(alpha: 0.72),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, foregroundShade);
  }

  @override
  bool shouldRepaint(covariant _PoisonBiomePainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _CosmicElementBiomePainter extends CustomPainter {
  final String? element;
  final double phase;

  const _CosmicElementBiomePainter({
    required this.element,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = phase * pi * 2;

    ({
      Color skyTop,
      Color skyBottom,
      Color glowA,
      Color glowB,
      Color groundLight,
      Color groundMid,
      Color groundDark,
      Color rim,
    })
    palette = switch (element) {
      'Fire' => (
        skyTop: const Color(0xFF3D1108),
        skyBottom: const Color(0xFF120503),
        glowA: const Color(0xFFFF7043),
        glowB: const Color(0xFFFFB74D),
        groundLight: const Color(0xFFD95A2C),
        groundMid: const Color(0xFF7C2A10),
        groundDark: const Color(0xFF2A0C05),
        rim: const Color(0xFFFFCC9C),
      ),
      'Lava' => (
        skyTop: const Color(0xFF4A1508),
        skyBottom: const Color(0xFF170603),
        glowA: const Color(0xFFFF8A65),
        glowB: const Color(0xFFFFAB40),
        groundLight: const Color(0xFFFF7043),
        groundMid: const Color(0xFF9E3A18),
        groundDark: const Color(0xFF2F1007),
        rim: const Color(0xFFFFD0A8),
      ),
      'Lightning' => (
        skyTop: const Color(0xFF2E2D11),
        skyBottom: const Color(0xFF0E0E06),
        glowA: const Color(0xFFFFFF8D),
        glowB: const Color(0xFFFFF176),
        groundLight: const Color(0xFFC9B85C),
        groundMid: const Color(0xFF6A5F2C),
        groundDark: const Color(0xFF1C1A0C),
        rim: const Color(0xFFFFF9B8),
      ),
      'Water' => (
        skyTop: const Color(0xFF0B2B56),
        skyBottom: const Color(0xFF071528),
        glowA: const Color(0xFF64B5F6),
        glowB: const Color(0xFF90CAF9),
        groundLight: const Color(0xFF4E8FCB),
        groundMid: const Color(0xFF245685),
        groundDark: const Color(0xFF0A223C),
        rim: const Color(0xFFBFE3FF),
      ),
      'Ice' => (
        skyTop: const Color(0xFF0D3845),
        skyBottom: const Color(0xFF07151A),
        glowA: const Color(0xFF80DEEA),
        glowB: const Color(0xFFE1F5FE),
        groundLight: const Color(0xFF93C9D6),
        groundMid: const Color(0xFF3F7A88),
        groundDark: const Color(0xFF123843),
        rim: const Color(0xFFD9F6FF),
      ),
      'Steam' => (
        skyTop: const Color(0xFF2E3840),
        skyBottom: const Color(0xFF101419),
        glowA: const Color(0xFFCFD8DC),
        glowB: const Color(0xFFECEFF1),
        groundLight: const Color(0xFFB0BEC5),
        groundMid: const Color(0xFF607D8B),
        groundDark: const Color(0xFF263238),
        rim: const Color(0xFFECEFF1),
      ),
      'Earth' => (
        skyTop: const Color(0xFF32261F),
        skyBottom: const Color(0xFF120D0A),
        glowA: const Color(0xFFA1887F),
        glowB: const Color(0xFFD7CCC8),
        groundLight: const Color(0xFF8D6E63),
        groundMid: const Color(0xFF5D4037),
        groundDark: const Color(0xFF2B1B16),
        rim: const Color(0xFFD7CCC8),
      ),
      'Mud' => (
        skyTop: const Color(0xFF2C201A),
        skyBottom: const Color(0xFF120C09),
        glowA: const Color(0xFF8D6E63),
        glowB: const Color(0xFFBCAAA4),
        groundLight: const Color(0xFF795548),
        groundMid: const Color(0xFF4E342E),
        groundDark: const Color(0xFF24140F),
        rim: const Color(0xFFC8B9B3),
      ),
      'Dust' => (
        skyTop: const Color(0xFF423523),
        skyBottom: const Color(0xFF181209),
        glowA: const Color(0xFFFFE0B2),
        glowB: const Color(0xFFFFCC80),
        groundLight: const Color(0xFFD7B07A),
        groundMid: const Color(0xFF8E6A3A),
        groundDark: const Color(0xFF352511),
        rim: const Color(0xFFFFE7BE),
      ),
      'Crystal' => (
        skyTop: const Color(0xFF053830),
        skyBottom: const Color(0xFF021411),
        glowA: const Color(0xFF80CBC4),
        glowB: const Color(0xFFB2DFDB),
        groundLight: const Color(0xFF4DB6AC),
        groundMid: const Color(0xFF00796B),
        groundDark: const Color(0xFF00332D),
        rim: const Color(0xFFC7F6F0),
      ),
      'Air' => (
        skyTop: const Color(0xFF0C3440),
        skyBottom: const Color(0xFF07141A),
        glowA: const Color(0xFFB3E5FC),
        glowB: const Color(0xFFE1F5FE),
        groundLight: const Color(0xFF88BCD2),
        groundMid: const Color(0xFF3A6C84),
        groundDark: const Color(0xFF153341),
        rim: const Color(0xFFDDF6FF),
      ),
      'Plant' => (
        skyTop: const Color(0xFF17381D),
        skyBottom: const Color(0xFF09130B),
        glowA: const Color(0xFFA5D6A7),
        glowB: const Color(0xFFC8E6C9),
        groundLight: const Color(0xFF66BB6A),
        groundMid: const Color(0xFF2E7D32),
        groundDark: const Color(0xFF113916),
        rim: const Color(0xFFD7F6D9),
      ),
      'Spirit' => (
        skyTop: const Color(0xFF171E42),
        skyBottom: const Color(0xFF090B18),
        glowA: const Color(0xFF9FA8DA),
        glowB: const Color(0xFFC5CAE9),
        groundLight: const Color(0xFF7986CB),
        groundMid: const Color(0xFF3949AB),
        groundDark: const Color(0xFF1A237E),
        rim: const Color(0xFFDDE2FF),
      ),
      'Dark' => (
        skyTop: const Color(0xFF1A1134),
        skyBottom: const Color(0xFF07050F),
        glowA: const Color(0xFF9575CD),
        glowB: const Color(0xFFB39DDB),
        groundLight: const Color(0xFF673AB7),
        groundMid: const Color(0xFF4527A0),
        groundDark: const Color(0xFF1A0C40),
        rim: const Color(0xFFD7CCFF),
      ),
      'Light' => (
        skyTop: const Color(0xFF4E4218),
        skyBottom: const Color(0xFF191407),
        glowA: const Color(0xFFFFFF9D),
        glowB: const Color(0xFFFFF176),
        groundLight: const Color(0xFFFBC02D),
        groundMid: const Color(0xFFAF8A1C),
        groundDark: const Color(0xFF4A380B),
        rim: const Color(0xFFFFF5BE),
      ),
      'Blood' => (
        skyTop: const Color(0xFF3A0D13),
        skyBottom: const Color(0xFF140406),
        glowA: const Color(0xFFEF9A9A),
        glowB: const Color(0xFFFFCDD2),
        groundLight: const Color(0xFFE57373),
        groundMid: const Color(0xFFC62828),
        groundDark: const Color(0xFF5A1118),
        rim: const Color(0xFFFFD0D5),
      ),
      _ => (
        skyTop: const Color(0xFF0B1226),
        skyBottom: const Color(0xFF030307),
        glowA: const Color(0xFF46B8FF),
        glowB: const Color(0xFF8B5CFF),
        groundLight: const Color(0xFF5E72A7),
        groundMid: const Color(0xFF283457),
        groundDark: const Color(0xFF0A0E1D),
        rim: const Color(0xFFAEC6FF),
      ),
    };

    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.skyTop, palette.skyBottom, palette.groundDark],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final glowA = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.28, -0.24),
        radius: 1.1,
        colors: [
          palette.glowA.withValues(alpha: 0.16 + 0.05 * sin(t)),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowA);

    final glowB = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.42, -0.05),
        radius: 1.2,
        colors: [
          palette.glowB.withValues(alpha: 0.14 + 0.05 * cos(t + 0.9)),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowB);

    final mist = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          palette.glowA.withValues(alpha: 0.08 + 0.03 * sin(t * 0.8)),
          palette.groundDark.withValues(alpha: 0.30),
        ],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(rect, mist);

    final motePaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 12; i++) {
      final p = t + i * 0.72;
      final x = size.width * (0.08 + (i % 6) * 0.17) + sin(p) * 11;
      final y = size.height * (0.22 + (i ~/ 6) * 0.42) + cos(p * 0.86) * 14;
      final r = 6.0 + (i % 3) * 2.0;
      motePaint.color = palette.rim.withValues(alpha: 0.05 + 0.03 * sin(p));
      canvas.drawCircle(Offset(x, y), r, motePaint);
    }

    final groundCenter = Offset(size.width * 0.5, size.height * 1.12);
    final groundRect = Rect.fromCenter(
      center: groundCenter,
      width: size.width * 1.72,
      height: size.height * 0.92,
    );
    final ground = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.62),
        radius: 1.0,
        colors: [palette.groundLight, palette.groundMid, palette.groundDark],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(groundRect);
    canvas.drawOval(groundRect, ground);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(2.0, size.width * 0.0046)
      ..color = palette.rim.withValues(alpha: 0.36)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final rimRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.90),
      width: size.width * 0.95,
      height: size.height * 0.34,
    );
    canvas.drawArc(rimRect, pi * 1.02, pi * 0.96, false, rim);
  }

  @override
  bool shouldRepaint(covariant _CosmicElementBiomePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.element != element;
}
