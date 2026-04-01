// lib/screens/scenes/scene_page.dart
import 'dart:async';
import 'dart:math';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/arcane_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/screens/scenes/rift_portal_screen.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/opening_wilderness_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/background/daynight_filter.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/wilderness/wilderness_controls.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
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
  });

  @override
  State<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends State<ScenePage> with TickerProviderStateMixin {
  static final RegExp _poisonSpeciesPattern = RegExp(
    r'^(LET|PIP|MAN|HOR|MSK|WNG|KIN)13$',
  );
  late SceneGame _game;
  late EncounterService _encounters;
  bool _resolverHooked = false;
  bool _tutorialDialogShown = false;

  // Saved references
  late WildernessSpawnService _spawnService;
  late FactionService _factionService;
  late AlchemonsDatabase _db;
  late CreatureCatalog _repo;

  // Encounter state
  bool _inEncounter = false;
  Creature? _wildCreature;
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
      _usedSpawnPointId = spawnId;
      setState(() {
        _inEncounter = true;
        _wildCreature = hydrated as Creature;
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
    _factionService = context.read<FactionService>();
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
            await _ensureTutorialSpawn();
            if (_isCaptureTutorialScene) {
              await _ensureCaptureTutorialHarvester();
            }
            if (mounted) _syncSpawnsFromService();
          }

          if (widget.isTutorial && !_tutorialDialogShown && mounted) {
            _tutorialDialogShown = true;
            if (mounted) {
              await _showPortalDialog();
            }
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              await _showWelcomeDialog();
            }
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
            _game.spawnRiftIfChance(sceneId: widget.sceneId);
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
      typewriter: true,
      kind: LandscapeDialogKind.info,
      showIcon: false,
      primaryLabel: 'Continue',
    );
  }

  Future<void> _maybeShowFirstVisitWildernessStoryDialog() async {
    if (_isCosmicPlanetMode || !mounted) return;
    const eligibleScenes = {'valley', 'sky', 'swamp', 'volcano'};
    if (!eligibleScenes.contains(widget.sceneId)) return;

    // Only eligible after first-time planet-entry story has happened.
    const planetStorySeenKey = 'cosmic_planet_pathway_intro_seen_v1';
    final prefs = await SharedPreferences.getInstance();
    final planetStorySeen = prefs.getBool(planetStorySeenKey) ?? false;
    if (!planetStorySeen || !mounted) return;

    final settings = _db.settingsDao;
    const key = 'wilderness_post_planet_story_seen';
    final seen = (await settings.getSetting(key)) == '1';
    if (seen || !mounted) return;

    await LandscapeDialog.show(
      context,
      title: 'Self Deception',
      message: 'Does reality dictate beauty?',
      typewriter: true,
      kind: LandscapeDialogKind.info,
      showIcon: false,
      primaryLabel: 'Continue',
      barrierDismissible: false,
    );
    await settings.setSetting(key, '1');
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

  Future<void> _showPortalDialog() async {
    await LandscapeDialog.show(
      context,
      title: 'Ancient Portal',
      message:
          'This portal was created eons ago. Is this false perception? Beauty obstructs reality.',
      typewriter: true,
      kind: LandscapeDialogKind.info,
      icon: Icons.auto_awesome,
      primaryLabel: 'Continue',
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

  Future<void> _showCaptureTutorialDialog() async {
    await LandscapeDialog.show(
      context,
      title: 'Harvester Trial',
      message:
          'This wild Alchemon must be harvested, not fused. Open the harvester panel and use the issued device to capture the specimen.',
      typewriter: true,
      kind: LandscapeDialogKind.info,
      icon: Icons.catching_pokemon_rounded,
      primaryLabel: 'Begin Capture',
      barrierDismissible: false,
    );
  }

  Future<void> _showPureWildDialog() async {
    await LandscapeDialog.show(
      context,
      title: 'Pure Wild Specimen',
      message:
          'Wild Alchemons are pure by default. Harvest them for pure replicas, or fuse with them for different results.',
      typewriter: false,
      kind: LandscapeDialogKind.success,
      icon: Icons.auto_awesome_rounded,
      primaryLabel: 'Return to Cultivations',
      barrierDismissible: false,
    );
  }

  @override
  void dispose() {
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
    _maybeRestoreWaterParty();
    _spawnService.markSceneInactive(widget.sceneId);
    _spawnService.removeListener(_onSpawnServiceChanged);

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

      // If we've now visited all four and ship is not claimed, arm spawn in Valley.
      final visitedCount = set.where((s) => allowed.contains(s)).length;
      final existingShip = await settings.getSetting('cosmic_ship_scene');
      final claimed = (await settings.getSetting('cosmic_ship_claimed')) == '1';
      if (existingShip != null && existingShip != 'valley' && !claimed) {
        await settings.setSetting('cosmic_ship_scene', 'valley');
      }
      if (visitedCount >= 4 && existingShip == null && !claimed) {
        await settings.setSetting('cosmic_ship_scene', 'valley');
        if (mounted) {
          setState(() {
            _shipSceneId = 'valley';
            _shipPresent = widget.sceneId == 'valley';
          });
          await _syncShipBeaconPlacement();
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
    _game.shake(duration: const Duration(milliseconds: 900), amplitude: 18);

    await LandscapeDialog.show(
      context,
      title: 'The Cosmic Ship',
      message:
          '"Recognizing that the world is but an illusion, does not act as if it were real, so he escapes suffering."',
      typewriter: true,
      kind: LandscapeDialogKind.success,
      icon: Icons.rocket_launch_rounded,
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
        _shipSpawnId = null;
      });
      _game.clearShipBeacon();
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
      _game.clearShipBeacon();
      return;
    }

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
    _game.placeShipBeaconAt(spawnId, onTap: _onShipTapped);
  }

  Future<void> _maybeRestoreWaterParty() async {
    if (!(_factionService.isWater() && await _factionService.perk2Active())) {
      return;
    }

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

  // ── Rift portal ─────────────────────────────────────────────────────────────

  void _onRiftTapped(RiftFaction faction) {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 900),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, animation, secondary) => _RiftVoidPage(
          faction: faction,
          party: widget.party,
          onEnter: () async {
            Navigator.of(ctx).pop();
            unawaited(context.read<AudioController>().playPortalMusic());
            // Don't clear the rift yet — only clear it if the player
            // successfully breeds or catches inside the void.
            final success = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) =>
                    RiftPortalScreen(faction: faction, party: widget.party),
              ),
            );
            if (success == true) {
              _game.clearRift();
            }
            if (!mounted) return;
            if (_isCosmicPlanetMode) {
              unawaited(context.read<AudioController>().playPlanetMusic());
            } else {
              unawaited(
                context.read<AudioController>().playWildMusicForScene(
                  widget.sceneId,
                ),
              );
            }
          },
        ),
        transitionsBuilder: (ctx, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.18, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
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

    if (widget.sceneId == 'arcane') {
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

                    return DayNightFilter(
                      intensity: night ? 1.0 : 0.0,
                      tint: const Color(0xFF081028),
                      minLuma: 0.45,
                      child: game,
                    );
                  },
                ),
                if (!(widget.sceneId == 'arcane' && _inEncounter))
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
                    party: widget.party,
                    highlightPartyHUD: _showTutorialHighlight,
                    isTutorial: widget.isTutorial,
                    isCaptureTutorial: _isCaptureTutorialScene,
                    onPreRollShake: () {
                      _game.shake(
                        duration: const Duration(milliseconds: 800),
                        amplitude: 14,
                      );
                    },
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
                          await _showPureWildDialog();
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

                        await _showSuccessDialog();
                        if (!mounted) return;

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
                // Back / leave button - 🆕 Hidden in tutorial
                if (!widget.isTutorial && !_isCaptureTutorialScene)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: WildernessControls(
                          party: widget.party,
                          leaveTooltip: _isCosmicPlanetMode
                              ? 'Exit Planet'
                              : 'Leave Scene',
                          leaveDialogTitle: _isCosmicPlanetMode
                              ? 'EXIT PLANET?'
                              : 'LEAVE SCENE?',
                          leaveDialogBody: _isCosmicPlanetMode
                              ? 'This planet encounter will end and you will return to space.'
                              : 'Any active encounters will be lost.',
                          leaveConfirmLabel: _isCosmicPlanetMode
                              ? 'EXIT'
                              : 'LEAVE',
                          leaveCancelLabel: 'CANCEL',
                          onLeave: () async {
                            if (!_isCosmicPlanetMode) {
                              await _db.delete(_db.activeSceneEntry).go();
                            }

                            if (!context.mounted) return;

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
// ── Rift Void Page (full-screen mystical overlay) ────────────────────────────

class _RiftVoidPage extends StatefulWidget {
  final RiftFaction faction;
  final List<PartyMember> party;
  final VoidCallback onEnter;

  const _RiftVoidPage({
    required this.faction,
    required this.party,
    required this.onEnter,
  });

  @override
  State<_RiftVoidPage> createState() => _RiftVoidPageState();
}

class _RiftVoidPageState extends State<_RiftVoidPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  String? _feedback;
  bool _feedbackIsWarning = false;
  bool _confirming = false;

  // Current portal key quantity for this faction.
  Future<int>? _keyFuture;

  String get _portalKeyInvKey =>
      InvKeys.portalKeyForFaction(widget.faction.name);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keyFuture ??= _loadKeyQty();
  }

  Future<int> _loadKeyQty() async {
    final db = context.read<AlchemonsDatabase>();
    return db.inventoryDao.getItemQty(_portalKeyInvKey);
  }

  Future<void> _refreshKeyQty() async {
    final db = context.read<AlchemonsDatabase>();
    final qty = await db.inventoryDao.getItemQty(_portalKeyInvKey);
    if (mounted) setState(() => _keyFuture = Future.value(qty));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String get _essenceLabel => switch (widget.faction) {
    RiftFaction.volcanic => 'IGNEOUS RESONANCE',
    RiftFaction.oceanic => 'ABYSSAL RESONANCE',
    RiftFaction.verdant => 'SYLVAN RESONANCE',
    RiftFaction.earthen => 'LITHIC RESONANCE',
    RiftFaction.arcane => 'VOID RESONANCE',
  };

  String get _crypticHint => switch (widget.faction) {
    RiftFaction.volcanic =>
      'Those born of flame, ruin, or ancient blood may approach.',
    RiftFaction.oceanic => 'Those shaped by tide and the deep cold may answer.',
    RiftFaction.verdant =>
      'Those of wind, bloom, and radiance know the passage.',
    RiftFaction.earthen =>
      'Those carved from stone, clay, crystal, and dust may enter.',
    RiftFaction.arcane =>
      'Those steeped in shadow, spirit, storm, or venom are expected.',
  };

  @override
  Widget build(BuildContext context) {
    final color = widget.faction.primaryColor;
    final coreColor = widget.faction.coreColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final pulse = 0.85 + 0.15 * _pulseCtrl.value;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _VoidPainter(
                    color: color,
                    coreColor: coreColor,
                    pulse: pulse,
                    time: _pulseCtrl.value,
                  ),
                ),
              ),
              SafeArea(child: child!),
            ],
          );
        },
        child: _buildContent(color),
      ),
    );
  }

  Widget _buildContent(Color color) {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Left panel: lore ─────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE RIFT STIRS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${widget.faction.displayName.toUpperCase()} THRESHOLD',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(2),
                      color: color.withValues(alpha: 0.07),
                    ),
                    child: Text(
                      _essenceLabel,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _crypticHint,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color.withValues(alpha: 0.65),
                      fontSize: 10,
                      height: 1.55,
                      letterSpacing: 0.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            // ── Vertical divider ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 160,
                child: VerticalDivider(
                  color: color.withValues(alpha: 0.25),
                  thickness: 1,
                  width: 1,
                ),
              ),
            ),

            // ── Right panel: key check → vessel selection ─────────────────
            Expanded(child: _buildRightPanel(color)),
          ],
        ),
      ),
    );
  }

  // ── Gated right panel ────────────────────────────────────────────────────

  Widget _buildRightPanel(Color color) {
    return FutureBuilder<int>(
      future: _keyFuture,
      builder: (ctx, keySnap) {
        if (keySnap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 70,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white24,
              ),
            ),
          );
        }
        final keyQty = keySnap.data ?? 0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Key status chip ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(
                  color: keyQty > 0
                      ? color.withValues(alpha: 0.6)
                      : Colors.white24,
                ),
                borderRadius: BorderRadius.circular(2),
                color: keyQty > 0
                    ? color.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.04),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.vpn_key_rounded,
                    color: keyQty > 0 ? color : Colors.white30,
                    size: 11,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    keyQty > 0
                        ? '${widget.faction.displayName.toUpperCase()} KEY  ×$keyQty'
                        : 'NO PORTAL KEY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: keyQty > 0 ? color : Colors.white30,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (keyQty <= 0) ...[
              // ── No key: prompt to buy ────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(3),
                  color: Colors.white.withValues(alpha: 0.03),
                ),
                child: Text(
                  'You need a\n${widget.faction.displayName.toUpperCase()} PORTAL KEY\nto enter this rift.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white38,
                    fontSize: 10,
                    height: 1.6,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ] else if (!_confirming) ...[
              // ── Has key: enter prompt ────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(3),
                  color: color.withValues(alpha: 0.05),
                ),
                child: const Text(
                  'YOUR ENTIRE PARTY\nWILL ENTER THE VOID',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.7,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _handleEnterTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                    color: color.withValues(alpha: 0.18),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    'ENTER THE RIFT',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ] else ...[
              // ── Confirmation ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(3),
                  color: color.withValues(alpha: 0.08),
                ),
                child: Text(
                  'USE 1 ${widget.faction.displayName.toUpperCase()}\nPORTAL KEY?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: color,
                    fontSize: 11,
                    height: 1.7,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _confirming = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      child: const Text(
                        'BACK',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _handleConfirmEnter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 1.5),
                        borderRadius: BorderRadius.circular(2),
                        color: color.withValues(alpha: 0.2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        'ENTER',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),
            if (_feedback != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _feedbackIsWarning
                        ? const Color(0xFFE06060)
                        : const Color(0xFF88EE88),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _feedbackIsWarning
                          ? const Color(0xFFE06060)
                          : const Color(0xFF88EE88),
                      fontSize: 10,
                      height: 1.5,
                      letterSpacing: 0.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'STEP BACK FROM THE THRESHOLD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color.fromARGB(151, 255, 255, 255),
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleEnterTap() {
    setState(() {
      _confirming = true;
      _feedback = null;
    });
  }

  Future<void> _handleConfirmEnter() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    // Race-condition guard: re-check key quantity.
    final keyQty = await db.inventoryDao.getItemQty(_portalKeyInvKey);
    if (keyQty <= 0) {
      setState(() {
        _feedback = 'Your portal key has gone. Visit the Shop.';
        _feedbackIsWarning = true;
        _confirming = false;
      });
      await _refreshKeyQty();
      return;
    }
    // Consume one key and enter.
    await db.inventoryDao.addItemQty(_portalKeyInvKey, -1);
    if (!mounted) return;
    widget.onEnter();
  }
}

// ── Void background painter ───────────────────────────────────────────────────

class _VoidPainter extends CustomPainter {
  final Color color;
  final Color coreColor;
  final double pulse;
  final double time;

  const _VoidPainter({
    required this.color,
    required this.coreColor,
    required this.pulse,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.28);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          radius: 1.3,
          colors: [
            Color.lerp(coreColor, Colors.black, 0.2)!,
            const Color(0xFF04040F),
            Colors.black,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Offset.zero & size),
    );

    for (int i = 4; i >= 0; i--) {
      final r = 55.0 + i * 52.0 + 18 * (1 - pulse);
      canvas.drawCircle(
        center,
        r * pulse,
        Paint()
          ..color = color.withValues(alpha: (0.13 - i * 0.02) * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }

    const spokeCount = 8;
    final spokePaint = Paint()
      ..color = color.withValues(alpha: 0.05 * pulse)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < spokeCount; i++) {
      final angle = (i / spokeCount) * pi * 2 + time * 0.4;
      canvas.drawLine(
        center,
        Offset(center.dx + 320 * cos(angle), center.dy + 320 * sin(angle)),
        spokePaint,
      );
    }

    canvas.drawCircle(
      center,
      38 * pulse,
      Paint()
        ..color = color.withValues(alpha: 0.15 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
  }

  @override
  bool shouldRepaint(_VoidPainter old) => true;
}
