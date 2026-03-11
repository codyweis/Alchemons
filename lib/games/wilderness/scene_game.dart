import 'dart:math';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
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
    final isVoidStyleScene = scene.layers.every((l) => l.imagePath.isEmpty);
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

  final Map<SceneLayer, _FiniteLayer> _layers = {};
  final PositionComponent layersRoot = PositionComponent()..priority = -200;

  // Spawn-point anchors we position creatures at
  final Map<String, PositionComponent> _spawnPointComps = {};

  final Map<String, WildMonComponent> _wildBySpawnId = {};
  String? _currentEncounterSpawnId; // keep this to track which one is engaged
  _ShipBeaconComponent? _shipBeacon;
  String? _pendingShipSpawnId;
  VoidCallback? _pendingShipTap;

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

  // NEW: Hard limit for camera movement in Exploration Mode (based on worldWidth)
  double get _maxCamXExploration =>
      max(0.0, scene.worldWidth - (size.x / cam.viewfinder.zoom));

  // Smooth interpolation targets
  double _targetCameraX = 0;
  double _targetCameraY = 0;

  // Zoom state
  double _targetZoom = 1.0;
  final double minZoom = 0.6;
  final double maxZoom = 2.0;
  final double zoomEase = 20.0; // higher = snappier
  double? _pinchStartZoom;

  // Gesture feel
  double scrollSensitivity = 0.3;

  // Viewport height in root space (used for spawnPoint world coords)
  double _viewportH = 0;

  // Scene mode
  SceneMode _mode = SceneMode.exploration;
  SceneMode get mode => _mode;
  bool get _hasImageLayers => scene.layers.any((l) => l.imagePath.isNotEmpty);

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
    add(world);
    world.add(layersRoot);

    // Build parallax layers
    for (final layerDef in scene.layers) {
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
      placeShipBeaconAt(_pendingShipSpawnId!, onTap: _pendingShipTap!);
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
      if (!_wildBySpawnId.containsKey(id)) {
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
    final sp = scene.spawnPoints.firstWhere(
      (s) => s.id == spawnId,
      orElse: () => throw 'Unknown spawnId $spawnId',
    );
    final anchor = _spawnPointComps[spawnId];
    if (anchor == null) return;

    Creature? hydrated;
    if (wildVisualResolver != null) {
      hydrated = await wildVisualResolver!(speciesId, rarity);
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

    anchor.add(comp);
    _wildBySpawnId[spawnId] = comp;
  }

  void clearWildAt(String spawnId) {
    _wildBySpawnId.remove(spawnId)?.removeFromParent();
  }

  void placeShipBeaconAt(String spawnId, {required VoidCallback onTap}) {
    clearShipBeacon();

    final anchor = _spawnPointComps[spawnId];
    if (anchor == null) {
      _pendingShipSpawnId = spawnId;
      _pendingShipTap = onTap;
      return;
    }

    final comp = _ShipBeaconComponent(onTap: onTap)
      ..anchor = Anchor.center
      ..position = Vector2.zero()
      ..priority = 200;
    anchor.add(comp);
    _shipBeacon = comp;
    _pendingShipSpawnId = null;
    _pendingShipTap = null;
  }

  void clearShipBeacon() {
    _shipBeacon?.removeFromParent();
    _shipBeacon = null;
    _pendingShipSpawnId = null;
    _pendingShipTap = null;
  }

  // ── Rift portal ────────────────────────────────────────────────────────────

  /// Call once after initial setup. 10% chance to spawn a faction rift portal.
  /// [sceneId] restricts which factions may appear (e.g. 'valley' → earthen/arcane).
  void spawnRiftIfChance({required String sceneId}) {
    // Evict any lingering stale rift from previous sessions.
    if (_riftPortalComp != null && !_riftPortalComp!.isMounted) {
      _riftPortalComp = null;
    }
    if (_riftPortalComp != null) return; // already active
    if (_rng.nextDouble() > 0.05) return; // 5% chance

    final faction = RiftFactionExt.randomForScene(sceneId, _rng);
    if (faction == null) return; // no eligible factions for this biome

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

      final baseW = scene.worldWidth.toDouble();
      final baseH = _viewportH;

      final x = p.normalizedPos.dx * baseW;
      final y = p.normalizedPos.dy * baseH;

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

    final sp = scene.spawnPoints.firstWhere((s) => s.id == spawnId);

    final toHide = _wildBySpawnId.keys.where((id) => id != spawnId).toList();
    for (final id in toHide) {
      _wildBySpawnId[id]?.removeFromParent();
      _wildBySpawnId.remove(id);
    }

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
    final camX = ((wild.x - halfW) / (1.0 + parallaxFactor)).clamp(
      0.0,
      maxCamX,
    );
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
    const pairGap = 260.0;
    final minX = 110.0;
    final maxX = baseW - 110.0;
    if (wildX > baseW - edgeBand) {
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

    _partyCreature?.removeFromParent();
    _partyCreature =
        WildMonComponent(
            hydrated: creature,
            speciesId: creature.id,
            rarityLabel: '',
            desiredSize: _sizeForSpecies(sp.size, creature),
            flipX: faceRight,
            onTap: () {},
            resolver: speciesSpriteResolver,
          )
          ..anchor = Anchor.center
          ..priority = 80
          ..position = Vector2.zero();

    anchor.add(_partyCreature!);

    _reframeForBattle(sp, anchor.position);
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
    double camX = ((focusBiased.x - halfW) / (1.0 + parallaxFactor)).clamp(
      0.0,
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

      camX = ((focusBiased.x - loopHalfW) / (1.0 + parallaxFactor)).clamp(
        0.0,
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

    // Zoom back out to exploration view
    _targetZoom = 1.0;
    _targetCameraX = _cameraX;
    _targetCameraY = 0;

    // Remove party creature
    _partyCreature?.removeFromParent();
    _partyCreature = null;
    _lastPartySpeciesId = null;
    _lastPartySpawnMs = 0;

    // Re-sync exploration spawns after encounter cleanup.
    syncWildFromEncounters();
  }

  // ------------------------------------------------------------
  // Gesture handling
  // ------------------------------------------------------------

  @override
  void onScaleStart(ScaleStartInfo info) {
    // Disable gestures during encounter
    if (_mode == SceneMode.encounter) return;
    _pinchStartZoom = cam.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
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
      _cameraX = (_cameraX - (dx / zoomFactor) * effectiveScroll).clamp(
        0.0,
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
    _cameraX = _cameraX.clamp(0.0, horizontalLimit);

    // ✅ Do NOT clamp targets in encounter mode (they were computed at target zoom)
    if (!isEncounter) {
      _targetCameraX = _targetCameraX.clamp(0.0, horizontalLimit);
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
    _cameraX = _cameraX.clamp(0.0, _maxCamX);
    _targetCameraX = _targetCameraX.clamp(0.0, _maxCamX);

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
      buildForLayer(l);
    }

    _repositionSpawnPoints();
  }

  void _recomputeMaxCamBounds() {
    // How much world fits on screen at current zoom
    final inv = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final viewportW = size.x * inv;
    final viewportH = size.y * inv;

    double layerMaxCamX(_FiniteLayer layer, double pf) {
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

    _maxCamX = limits.isEmpty ? double.infinity : limits.reduce(min);

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

  void _updateParallaxLayers() {
    final invRootAndZoom = 1.0 / (layersRoot.scale.x * cam.viewfinder.zoom);
    final viewportW = size.x * invRootAndZoom;

    for (final l in _layers.values) {
      l.updateOffsetClamped(_cameraX, viewportW);
    }
  }

  void _repositionSpawnPoints() {
    for (final p in scene.spawnPoints) {
      final comp = _spawnPointComps[p.id];
      if (comp == null) continue;

      // ✅ Same coordinate system as above
      final baseW = scene.worldWidth.toDouble();
      final x = p.normalizedPos.dx * baseW;
      final y = p.normalizedPos.dy * _viewportH;
      comp.position.setValues(x, y);
    }
  }
}

// ------------------------------------------------------------
// WildMonComponent: shows a single creature at a spawn point.
// ------------------------------------------------------------
class WildMonComponent extends PositionComponent
    with TapCallbacks, HasGameReference<SceneGame> {
  final String speciesId;
  final String rarityLabel;
  final VoidCallback onTap;
  final Vector2 desiredSize;
  final bool flipX;

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
  _ShipBeaconComponent({required this.onTap})
    : super(size: Vector2(132, 132), anchor: Anchor.center);

  final VoidCallback onTap;
  double _elapsed = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final c = Offset(size.x * 0.5, size.y * 0.5);
    final pulse = 1.0 + 0.06 * sin(_elapsed * 3.6);
    final glowPulse = 0.78 + 0.22 * sin(_elapsed * 2.8);

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

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(pulse);

    // Engine glow
    final glowPaint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(const Offset(0, 24), 12, glowPaint);

    // Trail particles (same feel as cosmic default)
    final trailPaint = Paint()..color = const Color(0x4000BFFF);
    for (var i = 1; i <= 3; i++) {
      final wobble = sin(_elapsed * 8 + i * 1.5) * 3;
      canvas.drawCircle(
        Offset(wobble, 24.0 + i * 10),
        5.0 - i * 0.9,
        trailPaint,
      );
    }

    // Ship body
    final bodyPath = Path()
      ..moveTo(0, -30)
      ..lineTo(-16, 24)
      ..lineTo(0, 12)
      ..lineTo(16, 24)
      ..close();

    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(const Offset(0, -30), const Offset(0, 24), [
        const Color(0xFF80DEEA),
        const Color(0xFF0077B6),
      ]);
    canvas.drawPath(bodyPath, bodyPaint);

    final outlinePaint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(bodyPath, outlinePaint);

    canvas.drawCircle(
      const Offset(0, -8),
      5,
      Paint()..color = const Color(0xCC00E5FF),
    );

    canvas.restore();
  }
}

// Minimal finite parallax layer helper
// ------------------------------------------------------------
class _FiniteLayer {
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
  final double parallaxFactor;
  final double widthMul;

  final PositionComponent container;
  final List<SpriteComponent> _tiles = [];

  Vector2 _tileSize = Vector2.zero();
  double get tileWidth => _tileSize.x;
  double get tileHeight => _tileSize.y;
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

  void updateOffsetClamped(double cameraX, double viewportWidthRootSpace) {
    // Parallax scroll. clamp so we never expose beyond the last tile.
    final raw = -(cameraX * parallaxFactor);
    final minX = -(max(0.0, totalWidth - viewportWidthRootSpace));
    final clamped = raw.clamp(minX, 0.0);
    container.position = Vector2(clamped, 0);
  }
}
