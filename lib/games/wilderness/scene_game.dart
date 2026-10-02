import 'dart:math';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/games/wilderness/creature_feet.dart';
import 'package:alchemons/games/wilderness/field/field_art.dart';
import 'package:alchemons/games/wilderness/harvest_field.dart';
import 'package:alchemons/games/wilderness/particle_fusion_effect.dart';
import 'package:alchemons/games/wilderness/wild_summon.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/rift_state.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/models/encounters/wild_spawn.dart';
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:alchemons/services/encounter_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/wilderness/creature_sprite_component.dart';
import 'package:alchemons/widgets/wilderness/tutorial_highlight.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

//KEEP THIS FOR INFO

// The key was understanding that parallax affects BOTH the layer offset AND the camera movement, so the formula is:
// screen_position = world_position - camera_position × (1 + parallax_factor)
// That's why parallax=1.0 creatures were going off-screen - they were being offset twice as much as expected!

/// Resolve a Flame SpriteAnimationComponent for a species,
/// sized to `desiredSize`. Return null to fall back to a blob.
typedef SpeciesSpriteResolver =
    Future<SpriteAnimationComponent?> Function(
      String speciesId,
      Vector2 desiredSize,
    );

/// Resolve a fully hydrated Creature (genes/nature/prismatic) for a spawn.
typedef WildVisualResolver =
    Future<Creature?> Function(String speciesId, EncounterRarity rarity);

enum SceneMode { exploration, encounter }

class SceneGame extends FlameGame with ScaleDetector {
  SceneGame({required this.scene, this.transparentBackground = false});

  final bool transparentBackground;

  @override
  Color backgroundColor() {
    final isVoidStyleScene =
        scene.art == null && scene.layers.every((l) => l.imagePath.isEmpty);
    return (transparentBackground || isVoidStyleScene)
        ? Colors.transparent
        : const Color(0xFF05060B);
  }

  bool isTutorialMode = false;
  void setTutorialMode(bool enabled) => isTutorialMode = enabled;

  bool showSpawnDebug = true; // toggle at runtime

  final SceneDefinition scene;
  final CameraComponent cam = CameraComponent();

  // Injected at runtime by ScenePage
  EncounterService? encounters;
  void attachEncounters(EncounterService svc) => encounters = svc;

  SpeciesSpriteResolver? speciesSpriteResolver;
  WildVisualResolver? wildVisualResolver;
  void Function(String spawnId, String speciesId, Creature? hydrated)?
  onStartEncounter;

  // Rift portal
  void Function(RiftFaction faction)? onRiftTapped;
  RiftPortalComponent? _riftPortalComp;

  // Internal state
  bool _initialized = false;
  final Random _rng = Random();

  // --- Shake state ---
  double _shakeTime = 0.0; // time remaining (seconds)
  double _shakeDuration = 0.0; // total duration (seconds)
  double _shakeAmplitude = 0.0; // max pixels of jitter at start
  final Vector2 _shakeOffset = Vector2.zero();

  World? _world;

  final Map<SceneLayer, _ParallaxLayer> _layers = {};

  /// A field drawn in code (see [SceneDefinition.art]), and its clock.
  FieldArt? _art;
  double _fieldTime = 0;

  /// The hour that lights the field: the phone's own clock, so the sky
  /// agrees with the encounter tables (night spawns run 20:00–05:00).
  double _fieldHour = 12;
  double _hourCheckedAt = -1;

  /// Pins the field's hour (0–24) instead of the clock, for previews.
  double? fieldHourOverride;

  /// The weather over the field, if any (see [FieldArt.weather]); it rolls
  /// in and clears over a few seconds — unless it is [WeatherKind.settled],
  /// which is there or not at once.
  WeatherKind? fieldWeather;
  double _weather = 0;

  /// Whether what the weather leaves behind is showing (see
  /// [FieldArt.aftermath]); it comes in slowly once the scene is open.
  bool fieldAftermath = false;
  double _aftermath = 0;

  /// The stage of the field's own cycle this visit (see [FieldArt.stage]).
  int fieldStage = 0;

  /// The field drawn in code, if this scene has one — for previews.
  @visibleForTesting
  FieldArt? get debugField => _art;

  /// Puts the weather and its aftermath fully in or out at once, for
  /// previews.
  @visibleForTesting
  void debugSettleWeather() {
    _weather = fieldWeather != null ? 1 : 0;
    _aftermath = fieldAftermath ? 1 : 0;
  }

  /// Recent fingers on the field, newest last (screen px).
  final List<FieldTouch> _touches = [];
  final PositionComponent layersRoot = PositionComponent()..priority = -200;

  // Spawn-point anchors we position creatures at
  final Map<String, PositionComponent> _spawnPointComps = {};

  final Map<String, WildMonComponent> _wildBySpawnId = {};
  final Map<String, int> _wildRenderVersionBySpawnId = {};
  String? _currentEncounterSpawnId; // keep this to track which one is engaged
  _ShipBeaconComponent? _shipBeacon;
  String? _pendingShipSpawnId;
  VoidCallback? _pendingShipTap;
  bool _pendingShipFlyIn = false;
  VoidCallback? _pendingShipCrash;

  // Party creature during encounter
  WildMonComponent? _partyCreature;
  String? _lastPartySpeciesId;
  int _lastPartySpawnMs = 0;
  int _lastEncounterTapMs = 0;

  // Camera state (in world coords)
  double _cameraX = 0;
  double _cameraY = 0;
  double _maxCamX = 0;
  double _maxCamY = 0;

  /// Public read-only access to the camera top-left world position.
  double get cameraX => _cameraX;
  double get cameraY => _cameraY;

  /// A field that wraps round (see [SceneDefinition.loop]).
  bool get _loops => scene.loop && _art != null;

  /// How far a layer's units run before it repeats, in a looping field.
  double _periodOf(SceneLayer id) {
    final pf = scene.layers
        .firstWhere((l) => l.id == id, orElse: () => scene.layers.first)
        .parallaxFactor;
    return scene.worldWidth * (1 + pf);
  }

  /// A spawn point's x on its layer, before any loop is taken into account.
  double _spawnBaseX(SpawnPoint p) =>
      p.normalizedPos.dx *
      (_loops ? _periodOf(p.anchor) : scene.worldWidth.toDouble());

  /// Camera x kept in bounds — except in a field that loops, which has none.
  double _clampCamX(double x, double limit) => _loops ? x : x.clamp(0.0, limit);

  /// The rift's x, and which loop of the field it is shown in.
  double? _riftBaseX;

  // NEW: Hard limit for camera movement in Exploration Mode (based on worldWidth)
  double get _maxCamXExploration =>
      max(0.0, scene.worldWidth - (size.x / cam.viewfinder.zoom));

  // Smooth interpolation targets
  double _targetCameraX = 0;
  double _targetCameraY = 0;

  // Zoom state
  double _targetZoom = 1.0;
  double get minZoom => _hasImageLayers ? 1.0 : 0.9;
  final double maxZoom = 2.0;
  final double zoomEase = 20.0; // higher = snappier
  double? _pinchStartZoom;

  // Gesture feel
  double scrollSensitivity = 0.5;

  // Viewport height in root space (used for spawnPoint world coords)
  double _viewportH = 0;

  // Scene mode
  SceneMode _mode = SceneMode.exploration;
  SceneMode get mode => _mode;
  bool get _hasImageLayers =>
      scene.art != null || scene.layers.any((l) => l.imagePath.isNotEmpty);

  double _zoomToFitBox({required double boxW, required double boxH}) {
    final root = layersRoot.scale.x;
    final zx = size.x / (root * boxW);
    final zy = size.y / (root * boxH);
    return math.min(zx, zy);
  }

  Vector2 _sizeForSpecies(Vector2 baseSize, Creature hydrated) {
    // Example: use your own data/model here instead of hardcoding
    const Map<String, double> speciesScale = {
      'let': 0.7,
      'pip': 0.9,
      'mane': 0.9,
      'horn': 1,
      'wing': 1.1,
      'kin': 1,
    };

    final scale =
        speciesScale.containsKey(hydrated.mutationFamily!.toLowerCase())
        ? speciesScale[hydrated.mutationFamily!.toLowerCase()]!
        : 1.0;
    return baseSize * scale;
  }

  /// Trigger a camera shake that eases out over [duration].
  /// [amplitude] is the pixel jitter at the start of the shake.
  void shake({
    Duration duration = const Duration(milliseconds: 700),
    double amplitude = 10,
  }) {
    _shakeDuration = duration.inMilliseconds / 1000.0;
    _shakeTime = _shakeDuration;
    _shakeAmplitude = amplitude;
  }

  // ------------------------------------------------------------
  // Lifecycle / setup
  // ------------------------------------------------------------

  void debugEncounterFrame(String spawnId) {
    final sp = scene.spawnPoints.firstWhere((s) => s.id == spawnId);
    final anchor = _spawnPointComps[spawnId];

    if (anchor == null) {
      debugPrint('⚠️  No anchor for $spawnId');
      return;
    }

    final baseW = scene.worldWidth.toDouble();
    final bp = sp.getBattlePos();

    // Where the creature actually is (accounting for parallax)
    final actualWild = anchor.position.clone();

    // Where we THINK it is
    final calculatedWild = Vector2(
      sp.normalizedPos.dx * baseW,
      sp.normalizedPos.dy * _viewportH,
    );

    final calculatedParty = Vector2(bp.dx * baseW, bp.dy * _viewportH);

    debugPrint('\n🐛 ENCOUNTER FRAME DEBUG for $spawnId:');
    debugPrint(
      '├─ Layer: ${sp.anchor} (parallax: ${scene.layers.firstWhere((l) => l.id == sp.anchor).parallaxFactor})',
    );
    debugPrint('├─ World size: ${baseW.toInt()} x ${_viewportH.toInt()}');
    debugPrint('├─ Viewport: ${size.x.toInt()} x ${size.y.toInt()}');
    debugPrint('├─ Root scale: ${layersRoot.scale.x}');
    debugPrint('│');
    debugPrint(
      '├─ Wild (calculated): (${calculatedWild.x.toStringAsFixed(1)}, ${calculatedWild.y.toStringAsFixed(1)})',
    );
    debugPrint(
      '├─ Wild (actual pos): (${actualWild.x.toStringAsFixed(1)}, ${actualWild.y.toStringAsFixed(1)})',
    );
    debugPrint(
      '├─ Difference: (${(actualWild.x - calculatedWild.x).toStringAsFixed(1)}, ${(actualWild.y - calculatedWild.y).toStringAsFixed(1)})',
    );
    debugPrint('│');
    debugPrint(
      '├─ Party (calculated): (${calculatedParty.x.toStringAsFixed(1)}, ${calculatedParty.y.toStringAsFixed(1)})',
    );
    debugPrint(
      '└─ Distance: ${(calculatedWild - calculatedParty).length.toStringAsFixed(1)}px\n',
    );
  }

  @override
  Future<void> onLoad() async {
    // Preload the layer art (skip empty paths — e.g. arcane uses pure black)
    final loadablePaths = scene.layers
        .map((l) => l.imagePath)
        .where((p) => p.isNotEmpty)
        .toList();
    if (loadablePaths.isNotEmpty) {
      await images.loadAll(loadablePaths);
    }

    final world = World()..priority = 0;
    _world = world;
    add(world);
    world.add(layersRoot);

    // Build parallax layers
    final art = _art = scene.art?.call();
    art?.layout(scene.spawnPoints, scene.worldWidth, loop: scene.loop);
    for (final layerDef in scene.layers) {
      if (art != null) {
        _layers[layerDef.id] = _ArtLayer(
          layersRoot,
          art,
          layerDef.id,
          priority: -100 + layerDef.id.index,
          parallaxFactor: layerDef.parallaxFactor,
        );
        continue;
      }
      if (layerDef.imagePath.isEmpty) continue; // skip empty (black backdrop)
      final sprite = Sprite(images.fromCache(layerDef.imagePath));
      final layer = _FiniteLayer(
        layersRoot,
        sprite,
        priority: -100 + layerDef.id.index,
        parallaxFactor: layerDef.parallaxFactor,
        widthMul: layerDef.widthMul,
      );
      _layers[layerDef.id] = layer;
    }

    // Camera setup
    if (art != null) {
      cam.backdrop = _FieldSkyComponent(art);
      cam.viewport.add(_FieldTapComponent());
    }
    cam
      ..world = world
      ..viewfinder.anchor = Anchor.center
      ..viewfinder.zoom = 1.0
      ..priority = 100;
    add(cam);

    _targetZoom = 1.0;

    // Layout and camera bounds for initial viewport
    _layoutLayersForScreen();
    _recomputeMaxCamBounds();

    _initialized = true;

    // Start at origin
    _cameraX = 0;
    _cameraY = 0;
    _targetCameraX = 0;
    _targetCameraY = 0;

    // Add spawn anchors
    _addSpawnPoints();

    // Reposition spawns using _viewportH (already set by _layoutLayersForScreen above)
    _repositionSpawnPoints();

    // Ship placement may be requested before spawn anchors are ready.
    if (_pendingShipSpawnId != null && _pendingShipTap != null) {
      placeShipBeaconAt(
        _pendingShipSpawnId!,
        onTap: _pendingShipTap!,
        flyIn: _pendingShipFlyIn,
        onCrashLanded: _pendingShipCrash,
      );
    }

    // Center camera initially
    cam.viewfinder.position = Vector2(size.x / 2, size.y / 2);
    _applyCamera();
    _updateParallaxLayers();

    await syncWildFromEncounters();
  }

  // ------------------------------------------------------------
  // Spawns
  // ------------------------------------------------------------

  Future<void> syncWildFromEncounters() async {
    final svc = encounters;
    if (svc == null) return;

    // desired spawns by id
    final desired = <String, WildSpawn>{
      for (final s in svc.spawns) s.spawnPointId: s,
    };

    if (_mode == SceneMode.encounter && _currentEncounterSpawnId != null) {
      desired.removeWhere((id, _) => id != _currentEncounterSpawnId);
    }

    // add/update
    for (final entry in desired.entries) {
      final id = entry.key;
      final s = entry.value;
      final existing = _wildBySpawnId[id];
      final needsRefresh =
          existing == null ||
          !existing.isMounted ||
          existing.speciesId != s.speciesId ||
          existing.rarityLabel != s.rarity.name;
      if (needsRefresh) {
        await _ensureWildAt(id, s.speciesId, s.rarity);
      }
    }

    // remove stale
    final toRemove = _wildBySpawnId.keys
        .where((id) => !desired.containsKey(id))
        .toList();
    for (final id in toRemove) {
      _wildBySpawnId[id]?.removeFromParent();
      _wildBySpawnId.remove(id);
    }
  }

  Future<void> _ensureWildAt(
    String spawnId,
    String speciesId,
    EncounterRarity rarity,
  ) async {
    final renderVersion = (_wildRenderVersionBySpawnId[spawnId] ?? 0) + 1;
    _wildRenderVersionBySpawnId[spawnId] = renderVersion;

    final sp = scene.spawnPoints.firstWhere(
      (s) => s.id == spawnId,
      orElse: () => throw 'Unknown spawnId $spawnId',
    );
    final anchor = _spawnPointComps[spawnId];
    if (anchor == null) return;

    // Keep the spawn anchor idempotent even if multiple syncs race or the
    // encounter at this spawn changes species/rarity while the old component
    // is still mounted.
    _wildBySpawnId.remove(spawnId)?.removeFromParent();

    Creature? hydrated;
    if (wildVisualResolver != null) {
      hydrated = await wildVisualResolver!(speciesId, rarity);
    }
    if (_wildRenderVersionBySpawnId[spawnId] != renderVersion) {
      return;
    }
    if (hydrated == null) {
      debugPrint(
        '⚠️ wildVisualResolver returned null for $speciesId at $spawnId',
      );
    }

    // 🔍 base logical size from the spawn point
    final baseSize = sp.size;

    // 🧬 adjust based on species (and optionally hydrated)
    final adjustedSize = hydrated != null
        ? _sizeForSpecies(baseSize, hydrated)
        : baseSize;

    final comp =
        WildMonComponent(
            hydrated: hydrated,
            speciesId: speciesId,
            rarityLabel: rarity.name,
            desiredSize: adjustedSize, // ⬅️ use adjusted size here
            onTap: () => _handleWildTap(spawnId, speciesId, hydrated),
            resolver: speciesSpriteResolver,
          )
          ..anchor = Anchor.center
          ..position = Vector2.zero();

    if (_wildRenderVersionBySpawnId[spawnId] != renderVersion) {
      return;
    }

    // Seat it on its perch by its own feet.
    _standDrop[spawnId] = _feetBelow(speciesId, hydrated, adjustedSize);
    anchor.position.y = _anchorY(sp, sp.normalizedPos.dy * _viewportH);

    anchor.add(comp);
    _wildBySpawnId[spawnId] = comp;
  }

  /// Push the camera in on whatever the encounter is looking at, and remember
  /// where it was so it can be handed back.
  double? _zoomBeforeHarvest;

  void pushInForHarvest() {
    _zoomBeforeHarvest ??= _targetZoom;
    _targetZoom = (_targetZoom * 1.26).clamp(minZoom, maxZoom);
  }

  void releaseHarvestPush() {
    final z = _zoomBeforeHarvest;
    if (z == null) return;
    _zoomBeforeHarvest = null;
    _targetZoom = z;
  }

  /// Play the harvest ON the creature that is standing in the scene.
  ///
  /// Nothing is pushed and nothing is duplicated: the field closes around the
  /// live [WildMonComponent] and drives its own transform, so the scene, the
  /// camera and the parallax keep running underneath. Completes with the
  /// task's result, and on a success the creature has already left the world.
  ///
  /// Falls back to running [task] alone if there is no creature to play on —
  /// a harvest must never be lost to a missing animation.
  Future<bool> playHarvestOnEncounter({
    required Color accent,
    required Future<bool> Function() task,
    HarvesterProfile? profile,
  }) async {
    final id = _currentEncounterSpawnId;
    final target = id == null ? null : _wildBySpawnId[id];
    final world = _world;
    if (target == null || !target.isMounted || world == null) {
      return task();
    }

    // A deployed party Alchemon makes the camera frame two creatures, which
    // leaves the wild one -- the one the harvest actually plays on -- small
    // and off to the side. Send it away and re-frame on the wild alone before
    // leaning in.
    if (_partyCreature != null && id != null) {
      dismissPartyCreature();
      _frameOnWild(id);
    }

    // The camera leans in while the sheet is getting out of the way, so the
    // two reads as one move rather than a cut to a different shot.
    pushInForHarvest();

    final dim = HarvestDim(fadeIn: 0.45);
    world.add(dim);
    final field = HarvestFieldEffect(
      target: target,
      accent: accent,
      task: task,
      profile: profile,
    );
    // Parented to the creature's own anchor, so it tracks the spawn point.
    (target.parent ?? world).add(field);

    final ok = await field.result;
    dim.release();
    releaseHarvestPush();
    if (ok && id != null) {
      _wildRenderVersionBySpawnId[id] =
          (_wildRenderVersionBySpawnId[id] ?? 0) + 1;
      _wildBySpawnId.remove(id);
    }
    return ok;
  }

  /// The fusion in particles, from the moment the catalyst is spent until
  /// it lands or falls apart.
  ParticleFusionEffect? _fusion;

  /// The party creature and the wild one, if both are standing.
  (WildMonComponent, WildMonComponent)? _fusionPair() {
    final id = _currentEncounterSpawnId;
    final wild = id == null ? null : _wildBySpawnId[id];
    final party = _partyCreature;
    if (wild == null ||
        party == null ||
        !wild.isMounted ||
        !party.isMounted ||
        _world == null) {
      return null;
    }
    return (party, wild);
  }

  static Color _accentOf(WildMonComponent c) {
    final types = c.hydrated?.types ?? const <String>[];
    return types.isEmpty
        ? const Color(0xFFE4C16A)
        : BreedConstants.getTypeColor(types.first);
  }

  ParticleFusionEffect? _startFusion() {
    final existing = _fusion;
    if (existing != null && existing.isMounted) return existing;
    final pair = _fusionPair();
    if (pair == null) return null;
    final (party, wild) = pair;
    final fx = ParticleFusionEffect(
      a: party,
      b: wild,
      accentA: _accentOf(party),
      accentB: _accentOf(wild),
    );
    (wild.parent ?? _world!).add(fx);
    return _fusion = fx;
  }

  /// The catalyst is spent and the roll is being made: both turn to grains
  /// where they stand while the verdict is waited on.
  void startFusionCalibration() => _startFusion()?.calibrate();

  /// The roll failed: the grains run back into the pair.
  Future<void> recoilFusion() async {
    final fx = _fusion;
    _fusion = null;
    if (fx != null && fx.isMounted) await fx.recoil();
  }

  /// Merge the party creature and the wild one, in the scene, in particles.
  ///
  /// Completes once the pair have become one and left the world, so the
  /// caller can hand over to the eruption-and-reveal with nothing left to
  /// duplicate.
  ///
  /// Answers with the SCREEN point the two met at — the fusion route
  /// defaults its core to the middle of the display, which is not where two
  /// creatures standing in a scene happen to come together — and what they
  /// were made of, so the eruption is made of it too. Null means there was
  /// no pair to play on and the caller should draw them itself.
  Future<FusionMergeHandoff?> playFusionOnEncounter() async {
    final id = _currentEncounterSpawnId;
    final fx = _startFusion();
    final world = _world;
    if (fx == null || id == null || world == null) return null;

    pushInForHarvest();
    final dim = HarvestDim(fadeIn: 0.4);
    world.add(dim);
    await fx.fuse();
    dim.release();
    final meeting = fx.meetingPoint;
    final grains = fx.specimens;
    fx.removeFromParent();
    _fusion = null;

    _wildRenderVersionBySpawnId[id] =
        (_wildRenderVersionBySpawnId[id] ?? 0) + 1;
    _wildBySpawnId.remove(id);
    _partyCreature = null;

    // World point → screen point, through the camera as it is RIGHT NOW —
    // before the push is released, or the answer describes a camera the
    // player is not looking through yet.
    final onScreen = meeting == null ? null : cam.localToGlobal(meeting);
    releaseHarvestPush();
    if (onScreen == null || grains == null) return null;
    return FusionMergeHandoff(
      at: Rect.fromCenter(
        center: Offset(onScreen.x, onScreen.y),
        width: 1,
        height: 1,
      ),
      grains: grains,
    );
  }

  void clearWildAt(String spawnId) {
    _wildRenderVersionBySpawnId[spawnId] =
        (_wildRenderVersionBySpawnId[spawnId] ?? 0) + 1;
    _wildBySpawnId.remove(spawnId)?.removeFromParent();
  }

  void placeShipBeaconAt(
    String spawnId, {
    required VoidCallback onTap,
    bool flyIn = false,
    VoidCallback? onCrashLanded,
  }) {
    clearShipBeacon();

    final anchor = _spawnPointComps[spawnId];
    if (anchor == null) {
      _pendingShipSpawnId = spawnId;
      _pendingShipTap = onTap;
      _pendingShipFlyIn = flyIn;
      _pendingShipCrash = onCrashLanded;
      return;
    }

    final comp =
        _ShipBeaconComponent(
            onTap: onTap,
            flyIn: flyIn,
            onCrashLanded: onCrashLanded,
          )
          ..anchor = Anchor.center
          ..position = Vector2.zero()
          ..priority = 200;
    anchor.add(comp);
    _shipBeacon = comp;
    _pendingShipSpawnId = null;
    _pendingShipTap = null;
    _pendingShipFlyIn = false;
    _pendingShipCrash = null;
  }

  void clearShipBeacon() {
    _shipBeacon?.removeFromParent();
    _shipBeacon = null;
    _pendingShipSpawnId = null;
    _pendingShipTap = null;
    _pendingShipFlyIn = false;
    _pendingShipCrash = null;
  }

  // ── Rift portal ────────────────────────────────────────────────────────────

  /// Roll for a rift in [sceneId]. Returns the faction to spawn, or null.
  ///
  /// Split from [spawnRift] so the caller can decide between rolling for a new
  /// rift and restoring one that is already pending from an earlier session —
  /// see PendingRift in models/rift_state.dart.
  RiftFaction? rollRiftFaction(String sceneId) {
    if (_rng.nextDouble() > kRiftSpawnChance) return null;
    return RiftFactionExt.randomForScene(sceneId, _rng);
  }

  /// Place the rift portal for [faction]. Safe to call when one is already up.
  void spawnRift(RiftFaction faction) {
    // Evict any lingering stale rift from previous sessions.
    if (_riftPortalComp != null && !_riftPortalComp!.isMounted) {
      _riftPortalComp = null;
    }
    if (_riftPortalComp != null) return; // already active

    // Normalised screen fractions where the portal should appear.
    final normX = 0.55 + _rng.nextDouble() * 0.20;
    final normY = 0.18 + _rng.nextDouble() * 0.12;

    _riftPortalComp = RiftPortalComponent(
      position: Vector2(
        _cameraX + normX * size.x / cam.viewfinder.zoom,
        _cameraY + normY * size.y / cam.viewfinder.zoom,
      ),
      faction: faction,
      radius: 30,
      onTap: () => onRiftTapped?.call(faction),
    );

    // Priority 999: renders above all background layers and creature/spawn
    // components so the portal is always in the foreground.
    _riftPortalComp!.priority = 999;
    _riftBaseX = _riftPortalComp!.position.x;
    layersRoot.add(_riftPortalComp!);
    debugPrint('✨ Rift portal spawned: ${faction.displayName}');
  }

  void clearRift() {
    _riftPortalComp?.removeFromParent();
    _riftPortalComp = null;
  }

  void _addSpawnPoints() {
    for (final p in scene.spawnPoints) {
      if (!p.enabled) continue;

      // Use the layer container if available, otherwise fall back to layersRoot
      // (e.g. arcane scene has no image layers — pure black backdrop).
      final parent = _layers[p.anchor]?.container ?? layersRoot;

      final baseH = _viewportH;

      final x = _spawnBaseX(p);
      final y = _anchorY(p, p.normalizedPos.dy * baseH);

      final anchor = PositionComponent(
        position: Vector2(x, y),
        size: Vector2.all(1),
        priority: 10,
        anchor: Anchor.center,
      );

      parent.add(anchor);
      _spawnPointComps[p.id] = anchor;
    }
  }

  /// How far below its centre the feet of the creature standing at each
  /// spawn are, so one on a perch is seated by its own sprite.
  final Map<String, double> _standDrop = {};

  /// How far below its centre a creature's feet are drawn at [size]: its
  /// sprite's own feet, scaled by its size gene.
  double _feetBelow(String speciesId, Creature? hydrated, Vector2 size) {
    final gene = hydrated?.spriteData != null
        ? visualsFromInstance(hydrated, null).scale
        : 1.0;
    return creatureFeetDrop(speciesId) * size.y * gene;
  }

  /// The anchor y for [p]: its own, or seated on the perch the field built.
  double _anchorY(SpawnPoint p, double authored) {
    final perch = _art?.perchFor(p.id);
    if (perch == null) return authored;
    return perch - (_standDrop[p.id] ?? p.size.y * 0.46);
  }

  // ------------------------------------------------------------
  // Encounter mode flow
  // ------------------------------------------------------------

  void _handleWildTap(String spawnId, String speciesId, Creature? hydrated) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastEncounterTapMs < 300) return;
    _lastEncounterTapMs = nowMs;

    // Guard against accidental re-entry while the current encounter is still
    // active (e.g. tap-through/duplicate tap after deploying party).
    if (_currentEncounterSpawnId == spawnId &&
        (_mode == SceneMode.encounter || _partyCreature != null)) {
      return;
    }
    if (_mode == SceneMode.encounter) return; // already in encounter
    _enterEncounterMode(spawnId);

    // 💡 PASS THE spawnId AS THE FIRST ARGUMENT
    onStartEncounter?.call(spawnId, speciesId, hydrated);
  }

  void _enterEncounterMode(String spawnId) {
    debugEncounterFrame(spawnId);
    _mode = SceneMode.encounter;
    _currentEncounterSpawnId = spawnId;

    final toHide = _wildBySpawnId.keys.where((id) => id != spawnId).toList();
    for (final id in toHide) {
      _wildBySpawnId[id]?.removeFromParent();
      _wildBySpawnId.remove(id);
    }

    _frameOnWild(spawnId);
  }

  /// Point the camera at the wild Alchemon alone, at encounter zoom.
  void _frameOnWild(String spawnId) {
    final sp = scene.spawnPoints.firstWhere((s) => s.id == spawnId);
    final wildAnchor = _spawnPointComps[spawnId];
    if (wildAnchor == null) {
      debugPrint('⚠️ No anchor found for $spawnId');
      return;
    }

    final wild = wildAnchor.position.clone();
    final layerDef = scene.layers.firstWhere((l) => l.id == sp.anchor);
    final parallaxFactor = layerDef.parallaxFactor;

    debugPrint(
      '🔍 Creature at world: (${wild.x}, ${wild.y}), parallax: $parallaxFactor',
    );

    const encounterZoom = 1.3; // Gentle zoom
    final root = layersRoot.scale.x;
    final worldHeight = _viewportH;

    final halfW = size.x / (2 * encounterZoom * root);
    final halfH = size.y / (2 * encounterZoom * root);

    final maxCamX = math.max(0.0, scene.worldWidth.toDouble() - 2 * halfW);
    final maxCamY = math.max(0.0, worldHeight - 2 * halfH);

    // Parallax offsets layer X only; Y stays in world-space camera coordinates.
    final camX = _clampCamX((wild.x - halfW) / (1.0 + parallaxFactor), maxCamX);
    final camY = (wild.y - halfH).clamp(0.0, maxCamY);

    _targetZoom = encounterZoom;
    _targetCameraX = camX;
    _targetCameraY = camY;

    debugPrint(
      '🎯 Encounter: wild=(${wild.x.toStringAsFixed(0)}, ${wild.y.toStringAsFixed(0)})',
    );
    debugPrint(
      '📐 Zoom: $encounterZoom, Camera: (${camX.toStringAsFixed(1)}, ${camY.toStringAsFixed(1)})',
    );

    // Debug: calculate actual screen position
    final screenX = wild.x - camX * (1.0 + parallaxFactor);
    final screenY = wild.y - camY;
    debugPrint(
      '   Expected screen pos: (${screenX.toStringAsFixed(0)}, ${screenY.toStringAsFixed(0)}) vs center: ($halfW, $halfH)',
    );
  }

  /// Send the deployed party Alchemon home, clearing the debounce with it so
  /// the same species can be redeployed immediately afterwards.
  void dismissPartyCreature() {
    _sendHome(_partyCreature);
    _partyCreature = null;
    _lastPartySpeciesId = null;
    _lastPartySpawnMs = 0;
  }

  void spawnPartyCreature(Creature creature) {
    if (_currentEncounterSpawnId == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_partyCreature != null &&
        _lastPartySpeciesId == creature.id &&
        (nowMs - _lastPartySpawnMs) < 250) {
      return;
    }
    _lastPartySpeciesId = creature.id;
    _lastPartySpawnMs = nowMs;

    final sp = scene.spawnPoints.firstWhere(
      (s) => s.id == _currentEncounterSpawnId!,
    );
    final parent = _layers[sp.anchor]?.container ?? layersRoot;

    final baseW = scene.worldWidth.toDouble();
    final battlePos = sp.getBattlePos();
    final rawX = battlePos.dx * baseW;
    final rawY = battlePos.dy * _viewportH;
    var x = rawX;
    var y = rawY;

    // Keep party placement away from hard scene edges so reframing can
    // reliably keep both creatures on screen for edge spawns.
    final wildX = _spawnPointComps[_currentEncounterSpawnId]?.position.x ?? x;
    const edgeBand = 220.0;
    const pairGap = kFieldPairGap;
    // A looping field has no edges: the partner stands a pace off the wild
    // one, on the side its battle position names.
    final minX = _loops ? -double.infinity : 110.0;
    final maxX = _loops ? double.infinity : baseW - 110.0;
    if (_loops) {
      x = wildX + sp.partnerSide * pairGap;
    } else if (wildX > baseW - edgeBand) {
      x = (wildX - pairGap).clamp(minX, maxX);
    } else if (wildX < edgeBand) {
      x = (wildX + pairGap).clamp(minX, maxX);
    }
    final signed = x >= wildX ? 1.0 : -1.0;
    final dx = (x - wildX).abs();
    const maxPairGap = 320.0;
    const minPairGap = 220.0;
    if (dx > maxPairGap) {
      x = (wildX + signed * maxPairGap).clamp(minX, maxX);
    } else if (dx < minPairGap) {
      x = (wildX + signed * minPairGap).clamp(minX, maxX);
    }
    y = y.clamp(90.0, _viewportH - 90.0);

    // Only a creature that can float is left in the air; anything else is
    // stood on the ground under where it would have hung.
    final partySize = _sizeForSpecies(sp.size, creature);
    final ground = _art?.groundAt(sp.anchor, x);
    if (ground != null && !speciesCanFloat(creature.id)) {
      final drop = _feetBelow(creature.id, creature, partySize);
      if (y + drop < ground.top) y = ground.rest - drop;
    }

    debugPrint('🎮 Spawning party at ($x, $y)');

    // Face toward the wild creature: flip right if party is to the left.
    final faceRight = x < wildX;

    final anchor = PositionComponent(
      position: Vector2(x, y),
      size: Vector2.all(1),
      priority: 60,
      anchor: Anchor.center,
    );

    parent.add(anchor);

    _sendHome(_partyCreature);
    _partyCreature =
        WildMonComponent(
            hydrated: creature,
            speciesId: creature.id,
            rarityLabel: '',
            desiredSize: partySize,
            flipX: faceRight,
            pulse: false,
            onTap: () {},
            resolver: speciesSpriteResolver,
          )
          ..anchor = Anchor.center
          ..priority = 80
          ..position = Vector2.zero();

    anchor.add(_partyCreature!);
    // It gathers out of grains of itself, as it does when summoned in space.
    anchor.add(
      WildSummon.gather(
        _partyCreature!,
        accent: _accentOf(_partyCreature!),
        mirror: faceRight,
      )..priority = 90,
    );

    _reframeForBattle(sp, anchor.position);
  }

  /// A party creature leaving: it comes apart into grains that drift off,
  /// then is gone. One the fusion has already taken leaves no trace.
  void _sendHome(WildMonComponent? c) {
    if (c == null || !c.isMounted) {
      c?.removeFromParent();
      return;
    }
    final parent = c.parent;
    if (parent == null || _fusion != null) {
      c.removeFromParent();
      return;
    }
    parent.add(
      WildSummon.scatter(
        c,
        accent: _accentOf(c),
        mirror: c.flipX,
        onDone: c.removeFromParent,
      )..priority = 90,
    );
  }

  void _reframeForBattle(SpawnPoint sp, Vector2 partyPos) {
    final wildAnchor = _spawnPointComps[_currentEncounterSpawnId];
    if (wildAnchor == null) return;

    final wild = wildAnchor.position.clone();
    final party = partyPos;

    // ✅ GET PARALLAX FACTOR (both creatures are on same layer)
    final layerDef = scene.layers.firstWhere((l) => l.id == sp.anchor);
    final parallaxFactor = layerDef.parallaxFactor;

    debugPrint(
      '🔄 Reframing: wild=(${wild.x.toStringAsFixed(0)}, ${wild.y.toStringAsFixed(0)}) '
      'party=(${party.x.toStringAsFixed(0)}, ${party.y.toStringAsFixed(0)}) parallax=$parallaxFactor',
    );

    final half = Vector2(sp.size.x * 0.5, sp.size.y * 0.5);

    final left = math.min(wild.x - half.x, party.x - half.x);
    final right = math.max(wild.x + half.x, party.x + half.x);
    final top = math.min(wild.y - half.y, party.y - half.y);
    final bottom = math.max(wild.y + half.y, party.y + half.y);

    const padX = 1.30;
    const padY = 1.35;
    const topPadding = 1.4;

    double boxW = (right - left) * padX;
    double boxH = (bottom - top) * padY * topPadding;

    final minBoxH = math.max(sp.size.y * 2.8, 220.0);
    final minBoxW = math.max(sp.size.x * 2.8, 300.0);
    boxH = math.max(boxH, minBoxH);
    boxW = math.max(boxW, minBoxW);

    final root = layersRoot.scale.x;
    double desiredZoom = _zoomToFitBox(boxW: boxW, boxH: boxH);

    final encounterMaxZoom = scene.encounterMaxZoom;
    final minEncounterZoom = scene.encounterMinZoom;
    desiredZoom = desiredZoom.clamp(minEncounterZoom, encounterMaxZoom);

    debugPrint(
      '📐 Battle zoom: ${desiredZoom.toStringAsFixed(2)} (box: ${boxW.toStringAsFixed(0)}x${boxH.toStringAsFixed(0)})',
    );

    final halfW = size.x / (2 * desiredZoom * root);
    final halfH = size.y / (2 * desiredZoom * root);

    final focusX = (left + right) * 0.5;
    final focusY = (top + bottom) * 0.5;

    final groundBias = scene.encounterGroundBias;
    final focusBiased = Vector2(focusX, focusY + groundBias);

    final maxCamX = math.max(0.0, scene.worldWidth.toDouble() - 2 * halfW);
    final maxCamY = math.max(0.0, _viewportH - 2 * halfH);

    // Parallax offsets layer X only; Y remains unscaled world camera.
    double camX = _clampCamX(
      (focusBiased.x - halfW) / (1.0 + parallaxFactor),
      maxCamX,
    );
    double camY = (focusBiased.y - halfH).clamp(0.0, maxCamY);

    // If creatures still end up near edge due camera clamp, widen framing.
    for (int i = 0; i < 3; i++) {
      final wildScreenX = wild.x - camX * (1.0 + parallaxFactor);
      final wildScreenY = wild.y - camY;
      final partyScreenX = party.x - camX * (1.0 + parallaxFactor);
      final partyScreenY = party.y - camY;

      final marginX = halfW * 0.22;
      final marginY = halfH * 0.18;
      final outOfFrame =
          wildScreenX < marginX ||
          wildScreenX > (2 * halfW - marginX) ||
          partyScreenX < marginX ||
          partyScreenX > (2 * halfW - marginX) ||
          wildScreenY < marginY ||
          wildScreenY > (2 * halfH - marginY) ||
          partyScreenY < marginY ||
          partyScreenY > (2 * halfH - marginY);

      if (!outOfFrame || desiredZoom <= minEncounterZoom + 0.0001) break;

      desiredZoom = (desiredZoom - 0.12).clamp(
        minEncounterZoom,
        encounterMaxZoom,
      );
      final loopHalfW = size.x / (2 * desiredZoom * root);
      final loopHalfH = size.y / (2 * desiredZoom * root);
      final loopMaxCamX = math.max(
        0.0,
        scene.worldWidth.toDouble() - 2 * loopHalfW,
      );
      final loopMaxCamY = math.max(0.0, _viewportH - 2 * loopHalfH);

      camX = _clampCamX(
        (focusBiased.x - loopHalfW) / (1.0 + parallaxFactor),
        loopMaxCamX,
      );
      camY = (focusBiased.y - loopHalfH).clamp(0.0, loopMaxCamY);
    }

    _targetZoom = desiredZoom;
    _targetCameraX = camX;
    _targetCameraY = camY;

    debugPrint(
      '📷 Camera target: (${camX.toStringAsFixed(1)}, ${camY.toStringAsFixed(1)}) zoom: $desiredZoom',
    );

    // ✅ DEBUG: Verify both creatures will be on screen
    final wildScreenX = wild.x - camX * (1.0 + parallaxFactor);
    final wildScreenY = wild.y - camY;
    final partyScreenX = party.x - camX * (1.0 + parallaxFactor);
    final partyScreenY = party.y - camY;

    debugPrint(
      '   Wild screen: (${wildScreenX.toStringAsFixed(0)}, ${wildScreenY.toStringAsFixed(0)})',
    );
    debugPrint(
      '   Party screen: (${partyScreenX.toStringAsFixed(0)}, ${partyScreenY.toStringAsFixed(0)})',
    );
    debugPrint(
      '   Viewport: ${(2 * halfW).toStringAsFixed(0)}x${(2 * halfH).toStringAsFixed(0)}',
    );
  }

  void exitEncounterMode() {
    _mode = SceneMode.exploration;
    _fusion?.removeFromParent();
    _fusion = null;

    // Zoom back out to exploration view
    _targetZoom = 1.0;
    _targetCameraX = _cameraX;
    _targetCameraY = 0;

    dismissPartyCreature();

    // Re-sync exploration spawns after encounter cleanup.
    syncWildFromEncounters();
  }

  // ------------------------------------------------------------
  // Gesture handling
  // ------------------------------------------------------------

  void _touch(Vector2 at, Vector2 moved) {
    if (_art == null) return;
    _touches.add(FieldTouch(at.x, at.y, moved.x, moved.y, _fieldTime));
    if (_touches.length > 48) _touches.removeAt(0);
  }

  /// A finger on the field at [x], [y] (screen px), moved by [dx], [dy] —
  /// what a drag does; for tests and anything else that strokes the grass.
  @visibleForTesting
  void debugTouch(double x, double y, double dx, double dy) =>
      _touch(Vector2(x, y), Vector2(dx, dy));

  @override
  void onScaleStart(ScaleStartInfo info) {
    // Disable gestures during encounter
    if (_mode == SceneMode.encounter) return;
    _pinchStartZoom = cam.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    _touch(info.eventPosition.widget, info.delta.global);
    if (_mode == SceneMode.encounter) return;

    // Pinch zoom
    final startZoom = _pinchStartZoom ?? cam.viewfinder.zoom;
    final globalScale = info.scale.global.x;
    _targetZoom = (startZoom * globalScale).clamp(minZoom, maxZoom);

    // Drag / pan
    final zoomFactor = cam.viewfinder.zoom;
    final effectiveScroll = scrollSensitivity * zoomFactor;

    final dx = info.delta.global.x;
    if (dx != 0) {
      _cameraX = _clampCamX(
        _cameraX - (dx / zoomFactor) * effectiveScroll,
        _maxCamXExploration, // <-- Use the strict limit here
      );
      _targetCameraX = _cameraX;
    }

    // Only allow vertical pan while zoomed in at all
    if (scene.allowVerticalPan && _targetZoom > minZoom) {
      final dy = info.delta.global.y;
      if (dy != 0) {
        _cameraY = (_cameraY - (dy / zoomFactor) * effectiveScroll).clamp(
          0.0,
          _maxCamY,
        );
        _targetCameraY = _cameraY;
      }
    }
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    if (_mode == SceneMode.encounter) return;
    _pinchStartZoom = null;
  }

  // ------------------------------------------------------------
  // Per-frame update
  // ------------------------------------------------------------

  // ------------------------------------------------------------
  // Fixed: don't over-clamp TARGETS in encounter mode while tweening
  // ------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);
    _fieldTime += dt;
    final art = _art;
    if (art != null) {
      if (_fieldTime - _hourCheckedAt > 1 || _hourCheckedAt < 0) {
        _hourCheckedAt = _fieldTime;
        final now = DateTime.now();
        _fieldHour = now.hour + now.minute / 60 + now.second / 3600;
      }
      while (_touches.isNotEmpty && _fieldTime - _touches.first.time > 1.5) {
        _touches.removeAt(0);
      }
      double ease(double v, bool on, double seconds) {
        final to = on ? 1.0 : 0.0;
        final next = v + (to - v) * (1 - exp(-dt / seconds));
        return (next - to).abs() < 1e-3 ? to : next;
      }

      // Weather rolls in and clears; a state the land is in (the Swamp
      // gone dry) is simply there.
      final settled = (fieldWeather ?? art.weatherKind)?.settled ?? false;
      _weather = settled
          ? (fieldWeather != null ? 1 : 0)
          : ease(_weather, fieldWeather != null, 1.6);
      // A rainbow comes slowly, a while after the scene opens.
      _aftermath = ease(_aftermath, fieldAftermath && _fieldTime > 1.5, 2.6);
      art
        ..weatherKind = fieldWeather ?? art.weatherKind
        ..weather = _weather
        ..aftermath = _aftermath
        ..stage = fieldStage
        ..prepare(fieldHourOverride ?? _fieldHour, time: _fieldTime);
    }

    // 1) Smoothly tween zoom toward target
    final currentZoom = cam.viewfinder.zoom;
    if ((currentZoom - _targetZoom).abs() > 0.0005) {
      final t = 1 - pow(1 / (1 + zoomEase), dt).toDouble();
      cam.viewfinder.zoom = currentZoom + (_targetZoom - currentZoom) * t;
      _recomputeMaxCamBounds(); // bounds grow as zoom increases
    }

    // 2) Choose horizontal limit depending on mode
    final isEncounter = (_mode == SceneMode.encounter);
    final horizontalLimit = isEncounter ? _maxCamX : _maxCamXExploration;

    // Clamp the ACTUAL camera position to current bounds
    _cameraX = _clampCamX(_cameraX, horizontalLimit);

    // ✅ Do NOT clamp targets in encounter mode (they were computed at target zoom)
    if (!isEncounter) {
      _targetCameraX = _clampCamX(_targetCameraX, horizontalLimit);
    }

    // A field that loops: the camera wraps round, which looks like nothing
    // at all — every layer repeats exactly once per world width. Held still
    // through an encounter, where the pair must stay put.
    if (_loops && !isEncounter) {
      final w = scene.worldWidth.toDouble();
      final k = (_cameraX / w).floor() * w;
      if (k != 0) {
        _cameraX -= k;
        _targetCameraX -= k;
      }
    }

    // 3) Vertical clamping: only clamp targets in exploration
    if (_mode == SceneMode.exploration) {
      if (scene.allowVerticalPan) {
        _cameraY = _cameraY.clamp(0.0, _maxCamY);
        _targetCameraY = _targetCameraY.clamp(0.0, _maxCamY);
      } else {
        _cameraY = 0.0;
        _targetCameraY = 0.0;
      }
    } else {
      // Encounter: allow target Y to be outside current bounds; only clamp current pos
      _cameraY = _cameraY.clamp(0.0, _maxCamY);
    }

    // 4) Smoothly tween camera toward targets
    const camSpeed = 5.0;
    if ((_cameraX - _targetCameraX).abs() > 0.5) {
      final t = 1 - pow(1 / (1 + camSpeed), dt).toDouble();
      _cameraX += (_targetCameraX - _cameraX) * t;
    }
    if ((_cameraY - _targetCameraY).abs() > 0.5) {
      final t = 1 - pow(1 / (1 + camSpeed), dt).toDouble();
      _cameraY += (_targetCameraY - _cameraY) * t;
    }

    // 5) Shake + apply
    if (_mode == SceneMode.encounter && _currentEncounterSpawnId != null) {
      for (final e in _wildBySpawnId.entries) {
        if (e.key != _currentEncounterSpawnId && e.value.isMounted) {
          e.value.removeFromParent();
        }
      }
    }

    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final t = (_shakeTime / _shakeDuration).clamp(0.0, 1.0);
      final falloff = 1 - (1 - t) * (1 - t) * (1 - t);
      final jx = (_rng.nextDouble() * 2 - 1) * _shakeAmplitude * falloff;
      final jy =
          (_rng.nextDouble() * 2 - 1) * (_shakeAmplitude * 0.6) * falloff;
      _shakeOffset.setValues(jx, jy);
    } else {
      if (!_shakeOffset.isZero()) _shakeOffset.setValues(0, 0);
    }

    _applyCamera();
    _updateParallaxLayers();
  }
  // ------------------------------------------------------------
  // Resize / relayout
  // ------------------------------------------------------------

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_initialized) return;

    _layoutLayersForScreen();
    _recomputeMaxCamBounds();

    // Same rules as update(): clamp X, but only clamp Y in exploration.
    _cameraX = _clampCamX(_cameraX, _maxCamX);
    _targetCameraX = _clampCamX(_targetCameraX, _maxCamX);

    if (_mode == SceneMode.exploration) {
      _cameraY = _cameraY.clamp(0.0, _maxCamY);
      _targetCameraY = _targetCameraY.clamp(0.0, _maxCamY);
    }

    _applyCamera();
    _updateParallaxLayers();
  }

  // ------------------------------------------------------------
  // Layout, camera math & parallax
  // ------------------------------------------------------------

  void _layoutLayersForScreen() {
    // Convert the current Flame game size into "root space"
    final invRootScale = 1.0 / layersRoot.scale.x;
    final viewportW = size.x * invRootScale;
    final viewportH = size.y * invRootScale;
    // Image-backed scenes use rendered visual height to prevent panning/spawns
    // below the map art. Void-style scenes keep configured world height.
    _viewportH = _hasImageLayers ? viewportH : scene.worldHeight.toDouble();

    final worldMaxCamX = max(0.0, scene.worldWidth - size.x);

    Vector2 heightFitTile(Sprite s) {
      final imgW = s.image.width.toDouble();
      final imgH = s.image.height.toDouble();
      final scale = viewportH / imgH;
      return Vector2(imgW * scale, imgH * scale);
    }

    void buildForArt(_ArtLayer layer) {
      // Wide enough for the furthest this layer can be scrolled: the camera
      // panned fully right at the closest zoom.
      final vwMin = viewportW / maxZoom;
      final span =
          max(0.0, scene.worldWidth - vwMin) * (1 + layer.parallaxFactor) +
          vwMin;
      layer.build(
        _loops
            ? Size(_periodOf(layer.id), viewportH)
            : Size(max(span, viewportW) + 64, viewportH),
        Size(viewportW, viewportH),
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio,
      );
    }

    void buildForLayer(_FiniteLayer layer) {
      final t = heightFitTile(layer.sprite);
      final tileW = t.x * layer.widthMul;

      // How wide this layer needs to be so we can't scroll past empty space
      final requiredW = viewportW + layer.parallaxFactor * worldMaxCamX;

      // +2 tiles for safety so there aren't seams at edges
      final tiles = max(3, (requiredW / max(1e-6, tileW)).ceil() + 2);
      layer.buildOrUpdate(Vector2(tileW, t.y), tiles);
    }

    for (final l in _layers.values) {
      switch (l) {
        case _FiniteLayer():
          buildForLayer(l);
        case _ArtLayer():
          buildForArt(l);
      }
    }

    _repositionSpawnPoints();
  }

  void _recomputeMaxCamBounds() {
    // How much world fits on screen at current zoom
    final inv = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final viewportW = size.x * inv;
    final viewportH = size.y * inv;

    double layerMaxCamX(_ParallaxLayer layer, double pf) {
      final exposed = layer.totalWidth - viewportW;
      if (pf == 0.0) {
        // Background layers with pf=0 should just never create gaps
        return exposed >= -1e-3 ? double.infinity : 0.0;
      }
      return max(0.0, exposed / pf);
    }

    // All the different parallax layers impose their own horizontal limits.
    // We take whichever is smallest (most restrictive) to avoid showing empty.
    final limits = <double>[];

    for (final ld in scene.layers) {
      final fl = _layers[ld.id];
      if (fl == null) continue;
      limits.add(layerMaxCamX(fl, ld.parallaxFactor));
    }

    _maxCamX = limits.isEmpty || _loops ? double.infinity : limits.reduce(min);

    // Fallback when there is no layer-derived horizontal limit:
    // - scenes with no image layers (e.g. poison/arcane),
    // - or scenes where all layer limits are effectively unbounded.
    if (_maxCamX == double.infinity) {
      _maxCamX = max(0.0, scene.worldWidth - (size.x / cam.viewfinder.zoom));
    }

    // Vertical clamp range is based on total visible content height.
    final contentHeight = _viewportH;
    _maxCamY = max(0.0, contentHeight - viewportH);
  }

  void _applyCamera() {
    // Convert cameraX/Y (top-left) into a viewfinder center
    final inv = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final vwWorld = size.x * inv;
    final vhWorld = size.y * inv;

    cam.viewfinder.position =
        Vector2(_cameraX + vwWorld / 2, _cameraY + vhWorld / 2) +
        _shakeOffset; // <-- add the shake here
  }

  /// Stands [c] on a spawn anchor, as a wild Alchemon would be; with
  /// [speciesId] and [size], seated on a perch by that sprite's feet.
  @visibleForTesting
  void debugStandAt(
    String spawnId,
    Component c, {
    String? speciesId,
    Vector2? size,
  }) {
    final anchor = _spawnPointComps[spawnId];
    if (anchor == null) return;
    if (speciesId != null && size != null) {
      _standDrop[spawnId] = _feetBelow(speciesId, null, size);
      final sp = scene.spawnPoints.firstWhere((s) => s.id == spawnId);
      anchor.position.y = _anchorY(sp, sp.normalizedPos.dy * _viewportH);
    }
    anchor.add(c);
  }

  /// Frames [spawnId] the way tapping a wild Alchemon there does.
  @visibleForTesting
  void debugFrameEncounter(String spawnId) => _enterEncounterMode(spawnId);

  /// The player's creature deployed into the encounter, if any.
  @visibleForTesting
  WildMonComponent? get debugPartyCreature => _partyCreature;

  /// Pans the camera straight to [x] (world units), no easing.
  @visibleForTesting
  void debugPanTo(double x) => _cameraX = _targetCameraX = x;

  /// What a layer whose container sits at [offsetX] can see this frame.
  FieldView _fieldViewFor(double offsetX) {
    final scale = layersRoot.scale.x * cam.viewfinder.zoom;
    final vw = size.x / scale, vh = size.y / scale;
    final left = _cameraX - offsetX;
    return FieldView(
      time: _fieldTime,
      hour: fieldHourOverride ?? _fieldHour,
      touches: _touches,
      left: left,
      right: left + vw,
      top: _cameraY,
      bottom: _cameraY + vh,
      zoom: scale,
      height: _viewportH,
    );
  }

  void _updateParallaxLayers() {
    final invRootAndZoom = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final viewportW = size.x * invRootAndZoom;

    for (final l in _layers.values) {
      l.updateOffsetClamped(_cameraX, viewportW, loop: _loops);
    }
    if (_loops && _mode == SceneMode.exploration) {
      _repositionSpawnPoints();
      _placeRift(viewportW);
    }
  }

  /// In a looping field each creature, and the rift, is shown in whichever
  /// loop of its layer is nearest the middle of the screen.
  double _nearestLoop(double baseX, SceneLayer layer, double viewportW) {
    final period = _periodOf(layer);
    final pf = period / scene.worldWidth - 1;
    final centre = _cameraX * (1 + pf) + viewportW / 2;
    return baseX + period * ((centre - baseX) / period).roundToDouble();
  }

  void _placeRift(double viewportW) {
    final rift = _riftPortalComp;
    final base = _riftBaseX;
    if (rift == null || base == null) return;
    final w = scene.worldWidth.toDouble();
    final centre = _cameraX + viewportW / 2;
    rift.position.x = base + w * ((centre - base) / w).roundToDouble();
  }

  void _repositionSpawnPoints() {
    final viewportW = size.x / (layersRoot.scale.x * cam.viewfinder.zoom);
    for (final p in scene.spawnPoints) {
      final comp = _spawnPointComps[p.id];
      if (comp == null) continue;

      // ✅ Same coordinate system as above
      final base = _spawnBaseX(p);
      final x = _loops ? _nearestLoop(base, p.anchor, viewportW) : base;
      final y = _anchorY(p, p.normalizedPos.dy * _viewportH);
      comp.position.setValues(x, y);
    }
  }
}

// ------------------------------------------------------------
// WildMonComponent: shows a single creature at a spawn point.
// ------------------------------------------------------------
class WildMonComponent extends PositionComponent
    with TapCallbacks, HasGameReference<SceneGame>, Veiled {
  final String speciesId;
  final String rarityLabel;
  final VoidCallback onTap;
  final Vector2 desiredSize;
  final bool flipX;

  /// Breathes gently to say it can be tapped. A wild creature does; the
  /// player's own, deployed into an encounter, does not.
  final bool pulse;

  final Creature? hydrated;
  final SpeciesSpriteResolver? resolver;

  WildMonComponent({
    required this.speciesId,
    required this.rarityLabel,
    required this.onTap,
    required this.desiredSize,
    this.hydrated,
    this.resolver,
    this.flipX = false,
    this.pulse = true,
    Vector2? position,
  }) : super(
         position: position ?? Vector2.zero(),
         anchor: Anchor.center,
         priority: 20,
       );

  @override
  Future<void> onLoad() async {
    size = desiredSize;

    if (hydrated?.spriteData != null) {
      final sheet = sheetFromCreature(hydrated!);
      final visuals = visualsFromInstance(hydrated!, null);

      final imagePath = sheet.path;
      try {
        await game.images.load(imagePath);
      } catch (e) {
        debugPrint('Failed to load sprite: $imagePath - $e');
        _addFallbackBlob();
        _addTapPulse();
        return;
      }

      // Add a soft backlight glow behind dark-type creatures so they're
      // visible on dark backgrounds (e.g. arcane scene).
      _maybeAddBacklight();

      add(
        CreatureSpriteComponent(
            sheet: sheet,
            visuals: visuals,
            desiredSize: size,
            variantFaction: visuals.variantFaction,
            alchemyEffect: visuals.alchemyEffect,
          )
          ..anchor = Anchor.center
          ..position = size / 2
          ..scale = flipX ? Vector2(-1, 1) : Vector2.all(1),
      );

      _addTapPulse();

      // 🆕 ADD THIS BLOCK AFTER _addTapPulse():
      // Add tutorial highlight if in tutorial mode
      if (game.isTutorialMode) {
        final highlight = TutorialCreatureHighlight(
          radius: size.x * 0.5,
          glowColor: Colors.amber,
          position: size / 2,
        );
        add(highlight);
        debugPrint('✨ Added tutorial highlight to wild creature');
      }

      return;
    }

    // 2) Ask external resolver for a sprite
    if (resolver != null) {
      final comp = await resolver!.call(speciesId, size);
      if (comp != null) {
        comp
          ..anchor = Anchor.center
          ..position = size / 2
          ..priority = 20;
        add(comp);
        _addTapPulse();
        return;
      }
    }

    // 3) Fallback debug blob
    final circle = CircleComponent(
      radius: size.x * 0.4,
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..color = Colors.amber.withValues(alpha: 0.9),
      priority: 20,
    );
    add(circle);

    add(
      TextComponent(
        text: speciesId,
        anchor: Anchor.center,
        position: size / 2,
        priority: 21,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    _addTapPulse();
  }

  void _addFallbackBlob() {
    final circle = CircleComponent(
      radius: size.x * 0.4,
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..color = Colors.amber.withValues(alpha: 0.9),
      priority: 20,
    );
    add(circle);

    add(
      TextComponent(
        text: speciesId,
        anchor: Anchor.center,
        position: size / 2,
        priority: 21,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _addTapPulse() {
    if (!pulse) return;
    add(
      ScaleEffect.to(
        Vector2.all(1.05),
        EffectController(
          duration: 0.5,
          reverseDuration: 0.5,
          infinite: true,
          curve: Curves.easeInOut,
          alternate: true,
        ),
      ),
    );
  }

  /// Adds a soft radial backlight behind the creature when its primary
  /// element is too dark to see — only in scenes with no backdrop imagery
  /// (e.g. the arcane void).
  void _maybeAddBacklight() {
    if (hydrated == null) return;
    if (game.transparentBackground) return;

    // Only apply in dark-backdrop scenes (all layers have empty imagePath)
    final hasDarkBackdrop = game.scene.layers.every((l) => l.imagePath.isEmpty);
    if (!hasDarkBackdrop) return;

    final types = hydrated!.types;
    if (types.isEmpty) return;

    // Dark-themed elements that need a backlight
    const darkElements = {'Dark', 'Spirit', 'Blood', 'Mud', 'Earth', 'Poison'};
    if (!darkElements.contains(types.first)) return;

    final radius = size.x * 0.6;
    add(
      _CreatureBacklightComponent(radius: radius, position: size / 2)
        ..priority = -2, // behind sprite and effects
    );
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();
}

/// Soft radial glow rendered behind dark creatures for visibility.
class _CreatureBacklightComponent extends PositionComponent {
  final double radius;
  late final Paint _paint;

  _CreatureBacklightComponent({required this.radius, super.position})
    : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    size = Vector2.all(radius * 2);
    _paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(radius, radius),
        radius,
        [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(radius, radius), radius, _paint);
  }
}

class _ShipBeaconComponent extends PositionComponent with TapCallbacks {
  _ShipBeaconComponent({
    required this.onTap,
    this.flyIn = false,
    this.onCrashLanded,
  }) : super(size: Vector2(132, 132), anchor: Anchor.center);

  final VoidCallback onTap;

  /// When true, the ship streaks in from above and crash-lands before it
  /// becomes tappable. When false, it simply renders at rest (restored state).
  final bool flyIn;

  /// Fired once, the moment the ship touches down (for the impact shake).
  final VoidCallback? onCrashLanded;

  static const double _entryDuration = 1.5;

  double _elapsed = 0.0;
  double _entryT = 0.0;
  double _postLand = 0.0;
  bool _landed = false;
  bool _crashFired = false;

  @override
  void onMount() {
    super.onMount();
    if (!flyIn) {
      _landed = true;
      _entryT = _entryDuration;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (flyIn && !_landed) {
      _entryT += dt;
      if (_entryT >= _entryDuration) {
        _entryT = _entryDuration;
        _landed = true;
        if (!_crashFired) {
          _crashFired = true;
          onCrashLanded?.call();
        }
      }
    } else if (_landed && _postLand < 1.3) {
      _postLand += dt;
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Ignore taps until the crash-landing cinematic finishes.
    if (!_landed) return;
    onTap();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final c = Offset(size.x * 0.5, size.y * 0.5);

    final p = flyIn ? (_entryT / _entryDuration).clamp(0.0, 1.0) : 1.0;
    final descending = p < 1.0;

    // Entry transform: dive in from the upper-right and straighten on landing.
    double dx = 0, dy = 0, tilt = 0;
    if (descending) {
      final eIn = p * p; // accelerate downward
      final eOut = 1 - (1 - p) * (1 - p); // ease horizontal drift
      dx = 150 * (1 - eOut);
      dy = -880 * (1 - eIn);
      tilt = -0.4 * (1 - p);
    }

    // Post-impact squash bounce.
    double bounceY = 0, sq = 0;
    if (flyIn && _landed && _postLand < 0.55) {
      final b = _postLand / 0.55;
      bounceY = -sin(b * pi) * 6 * (1 - b);
      sq = 0.18 * sin(b * pi) * (1 - b);
    }

    // Impact dust ring.
    if (flyIn && _landed && _postLand < 0.85) {
      final dp = _postLand / 0.85;
      final dustPaint = Paint()
        ..color = const Color(0xFFCFF3FF).withValues(alpha: 0.55 * (1 - dp))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * (1 - dp)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(Offset(c.dx, c.dy + 22), 22 + 92 * dp, dustPaint);
    }

    final glowPulse = 0.78 + 0.22 * sin(_elapsed * 2.8);

    // Idle beacon aura — only once the ship is fully landed.
    if (!descending) {
      final auraPaint = Paint()
        ..shader = ui.Gradient.radial(
          c,
          56,
          [
            const Color(0xFF5BEBFF).withValues(alpha: 0.46 * glowPulse),
            const Color(0xFF5BEBFF).withValues(alpha: 0.20 * glowPulse),
            Colors.transparent,
          ],
          const [0.0, 0.62, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(c, 56, auraPaint);

      final ringRadius = 42 + (2.5 * sin(_elapsed * 3.4));
      final ringPaint = Paint()
        ..color = const Color(0xFF7BF1FF).withValues(alpha: 0.58 * glowPulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(c, ringRadius, ringPaint);
    }

    canvas.save();
    canvas.translate(c.dx + dx, c.dy + dy + bounceY);
    canvas.rotate(tilt);
    final pulse = descending ? 1.0 : 1.0 + 0.06 * sin(_elapsed * 3.6);
    canvas.scale(pulse * (1 + sq), pulse * (1 - sq));

    // Re-entry streak trailing up behind the diving ship.
    if (descending) {
      final streakLen = 60 + 170 * p;
      final streakPaint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -38),
          Offset(0, -38 - streakLen),
          [
            const Color(0xFF9BF3FF).withValues(alpha: 0.6),
            const Color(0x005BEBFF),
          ],
        )
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(
        const Offset(0, -38),
        Offset(0, -38 - streakLen),
        streakPaint,
      );
    }

    final enginePulse = descending ? 1.0 : 0.85 + 0.15 * sin(_elapsed * 9);

    // Engine glow
    final glowPaint = Paint()
      ..color = const Color(0xAA00E5FF).withValues(alpha: 0.62 * enginePulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(const Offset(0, 28), 13, glowPaint);

    for (final x in const [-7.5, 7.5]) {
      canvas.drawCircle(
        Offset(x, 23),
        4.5,
        Paint()..color = const Color(0xCC8AF7FF),
      );
    }

    // Trail particles — idle hover wisps, suppressed during the dive.
    for (var i = 1; !descending && i <= 4; i++) {
      final wobble = sin(_elapsed * 8 + i * 1.35) * (2.8 + i * 0.25);
      final trailPaint = Paint()
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.24 - i * 0.04);
      canvas.drawCircle(
        Offset(wobble, 28.0 + i * 9),
        5.1 - i * 0.7,
        trailPaint,
      );
    }

    final wingPath = Path()
      ..moveTo(0, -34)
      ..lineTo(-8, -22)
      ..lineTo(-18, -8)
      ..lineTo(-24, 16)
      ..lineTo(-11, 12)
      ..lineTo(-5, 26)
      ..lineTo(0, 21)
      ..lineTo(5, 26)
      ..lineTo(11, 12)
      ..lineTo(24, 16)
      ..lineTo(18, -8)
      ..lineTo(8, -22)
      ..close();

    final fuselagePath = Path()
      ..moveTo(0, -38)
      ..lineTo(-5.5, -18)
      ..lineTo(-6.5, -4)
      ..lineTo(-4.2, 19)
      ..lineTo(0, 25)
      ..lineTo(4.2, 19)
      ..lineTo(6.5, -4)
      ..lineTo(5.5, -18)
      ..close();

    final wingPaint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, -34), const Offset(0, 26), [
        const Color(0xFF4FC3F7),
        const Color(0xFF0C5C86),
      ]);
    canvas.drawPath(wingPath, wingPaint);

    final fuselagePaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -38),
        const Offset(0, 25),
        [
          const Color(0xFFDDFBFF),
          const Color(0xFF90E8FF),
          const Color(0xFF0D79AB),
        ],
        const [0.0, 0.42, 1.0],
      );
    canvas.drawPath(fuselagePath, fuselagePaint);

    final canopyPath = Path()
      ..moveTo(0, -22)
      ..quadraticBezierTo(7, -18, 5.5, -5)
      ..quadraticBezierTo(0, 1, -5.5, -5)
      ..quadraticBezierTo(-7, -18, 0, -22)
      ..close();
    final canopyPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -22),
        const Offset(0, 1),
        [
          const Color(0xFFF6FEFF),
          const Color(0xFF6FE8FF),
          const Color(0xFF007EA7),
        ],
        const [0.0, 0.48, 1.0],
      );
    canvas.drawPath(canopyPath, canopyPaint);

    final intakePaint = Paint()
      ..color = const Color(0x6615334A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(-11, -5), const Offset(-15, 12), intakePaint);
    canvas.drawLine(const Offset(11, -5), const Offset(15, 12), intakePaint);

    final hullHighlight = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(0, -29), const Offset(0, 16), hullHighlight);

    final outlinePaint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(wingPath, outlinePaint);
    canvas.drawPath(fuselagePath, outlinePaint);

    canvas.drawCircle(
      const Offset(-13, 5),
      2.1,
      Paint()..color = const Color(0x99A8FFFF),
    );
    canvas.drawCircle(
      const Offset(13, 5),
      2.1,
      Paint()..color = const Color(0x9959D8FF),
    );

    canvas.drawCircle(
      const Offset(0, -8),
      5.5,
      Paint()..color = const Color(0xCC00E5FF),
    );

    canvas.restore();
  }
}

// Minimal finite parallax layer helper
// ------------------------------------------------------------
/// One parallax layer: a container the camera scrolls at its own rate, which
/// spawn anchors are added to.
sealed class _ParallaxLayer {
  PositionComponent get container;
  double get parallaxFactor;
  double get totalWidth;

  void updateOffsetClamped(
    double cameraX,
    double viewportWidthRootSpace, {
    bool loop = false,
  }) {
    // Parallax scroll. clamp so we never expose beyond the layer's end —
    // unless the layer loops, and has no end.
    final raw = -(cameraX * parallaxFactor);
    if (loop) {
      container.position = Vector2(raw, 0);
      return;
    }
    final minX = -(max(0.0, totalWidth - viewportWidthRootSpace));
    final clamped = raw.clamp(minX, 0.0);
    container.position = Vector2(clamped, 0);
  }
}

class _FiniteLayer extends _ParallaxLayer {
  _FiniteLayer(
    this.parent,
    this.sprite, {
    required this.priority,
    required this.parallaxFactor,
    required this.widthMul,
  }) : container = PositionComponent()
         ..priority = priority
         ..position = Vector2.zero();

  final PositionComponent parent;
  final Sprite sprite;
  final int priority;
  @override
  final double parallaxFactor;
  final double widthMul;

  @override
  final PositionComponent container;
  final List<SpriteComponent> _tiles = [];

  Vector2 _tileSize = Vector2.zero();
  double get tileWidth => _tileSize.x;
  double get tileHeight => _tileSize.y;
  @override
  double totalWidth = 0.0;

  void buildOrUpdate(Vector2 tileSize, int tilesNeeded) {
    final sameSize = (_tileSize - tileSize).length2 < 1e-6;
    if (sameSize && _tiles.length == tilesNeeded && container.isMounted) {
      return;
    }

    _tileSize = tileSize;
    if (!container.isMounted) parent.add(container);

    // grow
    while (_tiles.length < tilesNeeded) {
      final tile = SpriteComponent(
        sprite: sprite,
        size: tileSize.clone(),
        position: Vector2.zero(),
        priority: priority,
      )..paint.filterQuality = FilterQuality.high;

      container.add(tile);
      _tiles.add(tile);
    }

    // shrink
    while (_tiles.length > tilesNeeded) {
      _tiles.removeLast().removeFromParent();
    }

    // position horizontally in sequence
    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      if (!sameSize) {
        t.size = tileSize.clone();
      }
      t.position = Vector2(i * tileSize.x, 0);
    }

    totalWidth = _tiles.isEmpty
        ? 0
        : (_tiles.length - 1) * tileSize.x + tileSize.x;

    container.position = Vector2.zero();
  }
}

/// A layer drawn by the field's [FieldArt]: its still sheets baked into
/// images once per screen size, its live parts painted each frame — the back
/// pass under the creatures standing on it, the front pass over their feet.
class _ArtLayer extends _ParallaxLayer {
  _ArtLayer(
    this.parent,
    this.art,
    this.id, {
    required int priority,
    required this.parallaxFactor,
  }) : container = PositionComponent()..priority = priority;

  final PositionComponent parent;
  final FieldArt art;
  final SceneLayer id;
  @override
  final double parallaxFactor;
  @override
  final PositionComponent container;
  @override
  double totalWidth = 0;

  Size? _size;
  Size? _screen;
  _FieldSheetsComponent? _sheets;
  bool _liveMounted = false;

  void build(Size size, Size screen, double pixelRatio) {
    if (size == _size && screen == _screen) return;
    _size = size;
    _screen = screen;
    totalWidth = size.width;
    if (container.parent == null) parent.add(container);

    final baked = <_BakedSheet>[];
    for (final sheet in art.build(id, size, screen)) {
      final b = sheet.bounds;
      if (b.width <= 0 || b.height <= 0) continue;
      if (sheet.live != null) {
        baked.add(_BakedSheet(null, sheet));
        continue;
      }
      // Never past 2x (no one sees the difference in a backdrop) nor past
      // the widest texture every GPU can hold.
      final scale = min(
        min(pixelRatio, 2.0) * sheet.resolution,
        8000 / b.width,
      ).clamp(0.25, 4.0);
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..scale(scale)
        ..translate(-b.left, -b.top);
      sheet.paint(c);
      final picture = rec.endRecording();
      final image = picture.toImageSync(
        (b.width * scale).ceil(),
        (b.height * scale).ceil(),
      );
      picture.dispose();
      baked.add(_BakedSheet(image, sheet));
    }
    final sheets = _sheets ??= (_FieldSheetsComponent(this)..priority = -10);
    sheets.replace(baked);
    if (sheets.parent == null) container.add(sheets);

    if (!_liveMounted) {
      _liveMounted = true;
      if (art.hasLive(id, front: false)) {
        container.add(_FieldLiveComponent(this, front: false)..priority = -5);
      }
      // Over the creatures (10) and the party (60), under the rift (999).
      if (art.hasLive(id, front: true)) {
        container.add(_FieldLiveComponent(this, front: true)..priority = 70);
      }
    }
  }
}

class _BakedSheet {
  _BakedSheet(this.image, this.sheet);

  /// Null for a live sheet, which draws itself each frame.
  final ui.Image? image;
  final FieldSheet sheet;
  final Paint paint = Paint()..filterQuality = FilterQuality.medium;
}

/// Draws a layer's baked sheets: body sheets through the hour's colour
/// grade, light sheets in narrow columns each tinted with the light that
/// falls there — one atlas draw for the lot.
class _FieldSheetsComponent extends Component with HasGameReference<SceneGame> {
  _FieldSheetsComponent(this.layer);

  final _ArtLayer layer;
  List<_BakedSheet> _sheets = const [];

  static const _columns = 28;
  final Float32List _xforms = Float32List(_columns * 4);
  final Float32List _rects = Float32List(_columns * 4);
  final Int32List _colors = Int32List(_columns);

  void replace(List<_BakedSheet> sheets) {
    for (final s in _sheets) {
      s.image?.dispose();
    }
    _sheets = sheets;
  }

  @override
  void render(Canvas canvas) {
    final art = layer.art;
    final view = game._fieldViewFor(layer.container.position.x);
    // A looping field repeats each layer every [period]; a sheet is drawn at
    // whichever repeats of it are on screen.
    final period = game._loops ? layer.totalWidth : 0.0;
    for (final s in _sheets) {
      final sheet = s.sheet;
      final live = sheet.live;
      if (live != null) {
        live(canvas, view);
        continue;
      }
      final image = s.image!;
      final shown = sheet.opacity?.call() ?? 1.0;
      if (shown <= 0.004) continue;
      final b = sheet.bounds;
      final drift = sheet.drift == 0
          ? 0.0
          : (game._fieldTime * sheet.drift) % b.width;
      // Sheet copies: its own place, shifted by the drift (a drifting sheet
      // wraps on its own width), and by whole loops.
      final wrap = sheet.drift != 0 ? b.width : period;
      if (!sheet.light) {
        s.paint
          ..colorFilter = art.grade(sheet.grade)
          ..color = Color.fromRGBO(0, 0, 0, shown.clamp(0.0, 1.0));
      }
      for (var k = -1; k <= 1; k++) {
        if (k != 0 && wrap <= 0) continue;
        final shift = drift + k * wrap;
        if (b.right + shift < view.left || b.left + shift > view.right) {
          continue;
        }
        if (sheet.light) {
          _drawLight(canvas, s, art, view, shift, shown);
        } else {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            b.shift(Offset(shift, 0)),
            s.paint,
          );
        }
      }
      // A drifting sheet in a looping layer that is wider than its own wrap
      // never happens: clouds are built one loop wide.
    }
  }

  void _drawLight(
    Canvas canvas,
    _BakedSheet s,
    FieldArt art,
    FieldView v,
    double shift,
    double shown,
  ) {
    final image = s.image!;
    final b = s.sheet.bounds.shift(Offset(shift, 0));
    final left = max(b.left, v.left), right = min(b.right, v.right);
    if (right <= left) return;
    final scale = image.width / b.width;
    final step = (v.right - v.left) / (_columns - 2);
    var n = 0;
    var any = false;
    for (var x = left; x < right && n < _columns; x += step, n++) {
      final x1 = min(right, x + step);
      var color = art.lightAt(layer.id, (x + x1) / 2, v);
      if (shown < 1) color = color.withValues(alpha: color.a * shown);
      if (color.a > 0.004) any = true;
      _xforms
        ..[n * 4] = 1 / scale
        ..[n * 4 + 1] = 0
        ..[n * 4 + 2] = x
        ..[n * 4 + 3] = b.top;
      _rects
        ..[n * 4] = (x - b.left) * scale
        ..[n * 4 + 1] = 0
        ..[n * 4 + 2] = (x1 - b.left) * scale
        ..[n * 4 + 3] = image.height.toDouble();
      _colors[n] = color.toARGB32();
    }
    if (!any || n == 0) return;
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(_xforms, 0, n * 4),
      Float32List.sublistView(_rects, 0, n * 4),
      Int32List.sublistView(_colors, 0, n),
      BlendMode.modulate,
      null,
      s.paint,
    );
  }

  @override
  void onRemove() {
    replace(const []);
    super.onRemove();
  }
}

class _FieldLiveComponent extends Component with HasGameReference<SceneGame> {
  _FieldLiveComponent(this.layer, {required this.front});

  final _ArtLayer layer;
  final bool front;

  @override
  void render(Canvas canvas) => layer.art.paintLive(
    layer.id,
    canvas,
    game._fieldViewFor(layer.container.position.x),
    front: front,
  );
}

/// Any tap on a field drawn in code is a touch on it (a puff of grains from
/// the grass), and then goes on to whatever was tapped — a creature still
/// gets its tap. Drags arrive through the game's scale gesture instead.
class _FieldTapComponent extends Component
    with TapCallbacks, HasGameReference<SceneGame> {
  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapDown(TapDownEvent event) {
    game._touch(event.canvasPosition, Vector2.zero());
    event.continuePropagation = true;
  }
}

/// The field's sky, fixed to the screen behind every layer.
class _FieldSkyComponent extends Component with HasGameReference<SceneGame> {
  _FieldSkyComponent(this.art);

  final FieldArt art;

  @override
  void render(Canvas canvas) => art.paintSky(
    canvas,
    Size(game.size.x, game.size.y),
    game._fieldViewFor(0),
  );
}
