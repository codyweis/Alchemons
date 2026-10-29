// lib/screens/scenes/scene_page.dart
import 'dart:async';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/rift_state.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/pools/arcane_pool.dart';
import 'package:alchemons/models/encounters/pools/dunes_pool.dart';
import 'package:alchemons/models/encounters/pools/geode_pool.dart';
import 'package:alchemons/models/encounters/pools/tidal_pool.dart';
import 'package:alchemons/models/encounters/pools/sky_pool.dart';
import 'package:alchemons/models/encounters/pools/swamp_pool.dart';
import 'package:alchemons/models/encounters/pools/valley_pool.dart';
import 'package:alchemons/models/encounters/pools/volcano_pool.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:alchemons/screens/scenes/rift_threshold.dart';
import 'package:alchemons/services/opening_wilderness_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_spawn_service.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/background/daynight_filter.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/wilderness/mutation_meter.dart';
import 'package:alchemons/widgets/wilderness/wilderness_controls.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:alchemons/services/cosmic_memory_tutorial_service.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart' show Anchor;
import 'package:flame/game.dart';

import 'package:alchemons/models/inventory.dart' show InvKeys;
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/models/wilderness.dart'
    show PartyMember, WildEncounter;
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/games/wilderness/scene_game.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/web_ads.dart';
import 'package:alchemons/services/wildlife_generator.dart';

SceneEncounterTables Function(SceneDefinition) _tableBuilderForScene(
  String sceneId,
) {
  return switch (sceneId) {
    'sky' => skyEncounterPools,
    'volcano' => volcanoEncounterPools,
    'swamp' => swampEncounterPools,
    'arcane' => arcaneEncounterPools,
    'dunes' => dunesEncounterPools,
    'geode' => geodeEncounterPools,
    'tidal' => tidalEncounterPools,
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
  final void Function(NavSection section, {int? breedInitialTab})?
  onNavigateSection;

  const ScenePage({
    super.key,
    required this.scene,
    this.party = const [],
    required this.sceneId,
    this.isTutorial = false,
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
  late SceneGame _game;

  late final RevealWhenReady _revealWhenReady;
  late EncounterService _encounters;
  bool _resolverHooked = false;
  bool _tutorialDialogShown = false;

  // Saved references
  late WildernessSpawnService _spawnService;
  late AlchemonsDatabase _db;

  // Encounter state
  bool _inEncounter = false;
  Creature? _wildCreature;
  final Map<String, Creature> _preparedWildBySpawnId = <String, Creature>{};
  bool _showTutorialHighlight = false;
  bool _isCaptureTutorialScene = false;
  bool _riftSpawned = false;
  String? _shipSpawnId;
  bool _usingSessionSceneSpawns = false;
  bool _consumingSceneBatch = false;
  final Map<String, EncounterRoll> _sessionSceneSpawns = {};

  String? _usedSpawnPointId;
  // Ship discovery state
  bool _shipPresent = false;
  String? _shipSceneId;
  bool _shipBeaconPlaced = false;

  late final AnimationController _biomeAmbienceCtrl;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<AudioController>().playWildMusicForScene(widget.sceneId),
      );
    });

    _biomeAmbienceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _game = SceneGame(scene: widget.scene);

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
      tableBuilder: _tableBuilderForScene(widget.sceneId),
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

    if (!_initialized) {
      _initialized = true;

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

        // The mutation meter, the first time the field is entered with it.
        if (!widget.isTutorial &&
            !_isCaptureTutorialScene &&
            mounted) {
          await _maybeRevealMutationMeter();
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

    _syncSpawnsFromService();
  }

  Future<void> _ensureTutorialWildFusion() async {
    final qty = await _db.inventoryDao.getItemQty(InvKeys.wildFusion);
    if (qty < 1) {
      await _db.inventoryDao.addItemQty(InvKeys.wildFusion, 1);
    }
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
  /// Once, after the Mutation Meter node is unlocked: what the meter on the
  /// left edge is.
  Future<void> _maybeRevealMutationMeter() async {
    if (!context.read<ConstellationEffectsService>().hasMutationMeter()) return;
    if (await _db.settingsDao.hasSeenMutationMeterReveal()) return;
    await _db.settingsDao.setMutationMeterRevealSeen();
    if (!mounted) return;
    await showStoryDialog(
      context,
      primaryLabel: 'UNDERSTOOD',
      beats: const [
        StoryBeat(
          title: 'Mutation meter',
          message:
              'The mutation meter has been revealed. After each successful '
              'fuse, the meter fills and increases the chance of a '
              "mutation. When it's full, the next fuse mutates.",
        ),
      ],
    );
  }

  Future<void> _showFieldTutorialDialog() async {
    if (!mounted) return;
    await showStoryDialog(
      context,
      primaryLabel: 'BEGIN',
      beats: const [
        StoryBeat(
          title: 'The Wild',
          message: '',
          voice: "I remember this place. I don't remember creating it.",
        ),
        StoryBeat(
          title: 'Alchemy is Power',
          message:
              'Tap the wild Alchemon, then choose one of yours to fuse with it. '
              'Fusing with a wild Alchemon can produce rare mutations, which '
              'only happen in the wild.',
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
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    // Browser build only: leaving is a natural pause for an ad.
    WebAds.breakAfter('field');
    _revealWhenReady.dispose();
    try {
      unawaited(context.read<AudioController>().playHomeMusic());
    } catch (_) {}

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
    if (_usingSessionSceneSpawns || _consumingSceneBatch) return;
    _syncSpawnsFromService();
  }

  void _syncSpawnsFromService() {
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
    if (widget.isTutorial || _usingSessionSceneSpawns) {
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

  // Counts this visit to the wild, and brings the cosmic ship down into
  // this realm on the visit it is due (OpeningWildernessService).
  Future<void> _registerVisitedBiome() async {
    // feature flag check — proceed only if enabled
    if (!kEnableCosmicShip) return;
    try {
      // When it lands, the scene loads its state just after this and plays
      // the landing in front of the player.
      await OpeningWildernessService.registerWildVisit(
        _db.settingsDao,
        widget.sceneId,
        tutorial: widget.isTutorial,
      );
    } catch (e) {
      debugPrint('Error registering visited biome: $e');
    }
  }

  Future<void> _loadShipState() async {
    try {
      final settings = _db.settingsDao;
      final scene = await settings.getSetting('cosmic_ship_scene');
      final claimed = (await settings.getSetting('cosmic_ship_claimed')) == '1';
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
    final shouldShow = _shipPresent && _shipSceneId == widget.sceneId;
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
    final ours =
        pending != null &&
            pending.factionName == faction.name &&
            pending.sceneId == widget.sceneId
        ? pending
        : null;
    final from = _riftOrigin();
    await showRiftThreshold(
      context,
      faction: faction,
      from: from,
      closesIn: ours?.remainingLabel(DateTime.now().toUtc()),
      // The same rift holds the same species, however often it is opened.
      seed: ours?.spawnedUtc.millisecondsSinceEpoch,
      onEnter: (threshold, species) =>
          _enterRift(threshold, faction, species, from),
    );
  }

  /// Where the rift stands on the screen: its threshold grows out of it, and
  /// the way out of the rift opens on it.
  RiftOrigin? _riftOrigin() {
    final rift = _game.layersRoot.children
        .whereType<RiftPortalComponent>()
        .where((r) => r.isMounted)
        .firstOrNull;
    final box = _game.buildContext?.findRenderObject();
    if (rift == null || box is! RenderBox || !box.attached) return null;
    final c = _game.cam.localToGlobal(rift.absoluteCenter);
    final edge = _game.cam.localToGlobal(
      rift.absolutePositionOfAnchor(Anchor.centerRight),
    );
    // Its box is its disk's size and more; what a unit of it is on screen.
    final scale = (edge - c).length / (rift.size.x / 2);
    return RiftOrigin(
      centre: box.localToGlobal(Offset(c.x, c.y)),
      radius: rift.diskRadius * scale,
      core: rift.core,
      density: rift.grainCount / RiftVortexField.defaultGrains,
      grain: rift.grainDiameter * scale,
      hide: (hidden) => rift.hidden = hidden,
    );
  }

  /// The key has turned and the threshold has fallen to black: it falls
  /// into the rift, and leaving the rift comes back here through black that
  /// opens on where the rift was.
  Future<void> _enterRift(
    BuildContext thresholdContext,
    RiftFaction faction,
    Creature? species,
    RiftOrigin? from,
  ) async {
    unawaited(context.read<AudioController>().playPortalMusic());
    await enterRift(
      thresholdContext,
      faction: faction,
      species: species,
      party: widget.party,
      // The scene behind is landscape.
      returnTo: const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      from: from,
      // Cleared only once something was bred or caught inside — and while
      // the way out is still black, so it is gone before it can be seen.
      onReturn: (success) async {
        if (success == true) await _consumeRift();
      },
    );
    if (!mounted) return;
    unawaited(
      context.read<AudioController>().playWildMusicForScene(widget.sceneId),
    );
  }

  bool isNight(DateTime now) => now.hour >= 20 || now.hour < 5;

  List<Color>? _particlePaletteForScene() {
    return switch (widget.sceneId) {
      'arcane' => const [
        Color(0xFF6A1B9A),
        Color(0xFF3949AB),
        Color(0xFF00BCD4),
        Color(0xFF311B92),
      ],
      _ => null,
    };
  }

  Widget? _elementalBackdropForScene() {
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
                    fieldMutations: true,
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
                    onFusionSkip: _game.skipFusion,
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
                        if (!_usingSessionSceneSpawns) {
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
                // The mutation meter, on the left edge between Exit and
                // Items. Wilderness only, like mutations.
                if (!widget.isTutorial && !_isCaptureTutorialScene)
                  const Positioned.fill(child: MutationMeterHud()),
                // Back / leave button - hidden in the tutorial.
                if (!widget.isTutorial && !_isCaptureTutorialScene)
                  Positioned.fill(
                    child: WildernessControls(
                      party: widget.party,
                      leaveTooltip: 'Leave Scene',
                      leaveDialogTitle: 'LEAVE SCENE?',
                      leaveDialogBody: 'Any active encounters will be lost.',
                      leaveConfirmLabel: 'LEAVE',
                      leaveCancelLabel: 'STAY',
                      canLeave: () =>
                          !(_shipPresent && _shipSceneId == widget.sceneId),
                      onLeaveBlocked: _showShipBeckoning,
                      onLeave: () async {
                        await _db.delete(_db.activeSceneEntry).go();

                        if (!context.mounted) return;
                        // Let the confirmation finish closing: the field is
                        // pictured without it, and its dim would vanish.
                        await Future<void>.delayed(
                          const Duration(milliseconds: 160),
                        );
                        if (!context.mounted) return;

                        // Back into the realm's circle on the map, as sand.
                        await VoidPortal.leaveThroughSand<void>(context);
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

